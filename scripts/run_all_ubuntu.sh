#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GS_DIR="$REPO_ROOT/third_party/gaussian-splatting"

DATASET_NAME="${DATASET_NAME:-my_scene}"
DATASET_DIR="${DATASET_DIR:-$REPO_ROOT/data/$DATASET_NAME}"
INPUT_DIR="$DATASET_DIR/input"
OUTPUT_ROOT="${OUTPUT_ROOT:-$REPO_ROOT/outputs/$DATASET_NAME}"
LOG_DIR="$OUTPUT_ROOT/_logs"

VIDEO_PATH="${VIDEO_PATH:-}"
IMAGE_DIR="${IMAGE_DIR:-}"
FPS="${FPS:-2}"
ITERATIONS="${ITERATIONS:-30000}"
RUN_SETUP="${RUN_SETUP:-1}"
RUN_COMPARISONS="${RUN_COMPARISONS:-0}"
COMPARISON_ITERATIONS="${COMPARISON_ITERATIONS:-7000}"
COLMAP_EXE="${COLMAP_EXE:-colmap}"
RESIZE="${RESIZE:-0}"
OVERWRITE_INPUT="${OVERWRITE_INPUT:-0}"
EXTRA_TRAIN_ARGS="${EXTRA_TRAIN_ARGS:-}"
DENSIFY_LOW_THRESHOLD="${DENSIFY_LOW_THRESHOLD:-0.0001}"
POS_LR_LOW="${POS_LR_LOW:-0.00008}"

usage() {
  cat <<'EOF'
Usage examples:

  # Full baseline run from a video. This also sets up the conda env by default.
  DATASET_NAME=my_scene VIDEO_PATH=/path/to/video.mp4 bash scripts/run_all_ubuntu.sh

  # Full baseline run from an existing image folder.
  DATASET_NAME=my_scene IMAGE_DIR=/path/to/images bash scripts/run_all_ubuntu.sh

  # Reuse existing data/<scene>/input and skip environment setup.
  DATASET_NAME=my_scene RUN_SETUP=0 bash scripts/run_all_ubuntu.sh

  # Run baseline plus three parameter-comparison runs for the report.
  DATASET_NAME=my_scene VIDEO_PATH=/path/to/video.mp4 RUN_COMPARISONS=1 bash scripts/run_all_ubuntu.sh

Important variables:
  DATASET_NAME           Scene name under data/ and outputs/. Default: my_scene
  VIDEO_PATH             Input video path. Optional if IMAGE_DIR or data/<scene>/input exists.
  IMAGE_DIR              Folder of input images. Optional if VIDEO_PATH or data/<scene>/input exists.
  FPS                    Video extraction FPS. Default: 2
  ITERATIONS             Baseline training iterations. Default: 30000
  RUN_SETUP              1 creates/updates env and CUDA extensions; 0 skips it. Default: 1
  RUN_COMPARISONS        1 runs iter_7000, densify_low, and pos_lr_low after baseline. Default: 0
  RESIZE                 1 passes --resize to convert.py. Default: 0
  OVERWRITE_INPUT        1 clears existing images in data/<scene>/input before copying/extracting. Default: 0
EOF
}

log() {
  printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"
}

require_command() {
  local cmd="$1"
  local message="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing command: $cmd" >&2
    echo "$message" >&2
    exit 1
  fi
}

count_input_images() {
  if [[ ! -d "$INPUT_DIR" ]]; then
    echo 0
    return
  fi
  find "$INPUT_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' \) \
    | wc -l
}

clear_input_images() {
  if [[ "$OVERWRITE_INPUT" == "1" && -d "$INPUT_DIR" ]]; then
    log "Clearing existing input images in $INPUT_DIR"
    find "$INPUT_DIR" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' \) \
      -delete
  fi
}

prepare_input_images() {
  mkdir -p "$INPUT_DIR" "$LOG_DIR"

  if [[ -n "$VIDEO_PATH" ]]; then
    if [[ ! -f "$VIDEO_PATH" ]]; then
      echo "VIDEO_PATH does not exist: $VIDEO_PATH" >&2
      exit 1
    fi
    require_command ffmpeg "Install FFmpeg, for example: sudo apt install -y ffmpeg"
    clear_input_images
    log "Extracting frames from $VIDEO_PATH at fps=$FPS"
    ffmpeg -y -i "$VIDEO_PATH" -vf "fps=$FPS" "$INPUT_DIR/%06d.jpg" 2>&1 | tee "$LOG_DIR/00_ffmpeg.log"
  elif [[ -n "$IMAGE_DIR" ]]; then
    if [[ ! -d "$IMAGE_DIR" ]]; then
      echo "IMAGE_DIR does not exist: $IMAGE_DIR" >&2
      exit 1
    fi
    clear_input_images
    log "Copying images from $IMAGE_DIR to $INPUT_DIR"
    local copied=0
    while IFS= read -r -d '' image_path; do
      cp "$image_path" "$INPUT_DIR/"
      copied=$((copied + 1))
    done < <(find "$IMAGE_DIR" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' \) \
      -print0)
    echo "Copied $copied images." | tee "$LOG_DIR/00_copy_images.log"
  else
    log "No VIDEO_PATH or IMAGE_DIR set; trying existing $INPUT_DIR"
  fi

  local image_count
  image_count="$(count_input_images)"
  if [[ "$image_count" -eq 0 ]]; then
    echo "No input images found in $INPUT_DIR." >&2
    usage >&2
    exit 1
  fi
  log "Input image count: $image_count"
}

setup_environment() {
  cd "$REPO_ROOT"
  require_command git "Install Git, for example: sudo apt install -y git"

  if [[ "$RUN_SETUP" == "1" ]]; then
    log "Setting up gaussian_splatting environment and CUDA extensions"
    bash scripts/setup_gaussian_splatting_ubuntu.sh 2>&1 | tee "$LOG_DIR/01_setup.log"
  else
    log "Skipping environment setup because RUN_SETUP=0"
  fi

  require_command conda "Install Miniconda or load the server's conda module first."
  # shellcheck source=/dev/null
  source "$(conda info --base)/etc/profile.d/conda.sh"
  conda activate gaussian_splatting

  if ! command -v "$COLMAP_EXE" >/dev/null 2>&1; then
    echo "COLMAP executable not found: $COLMAP_EXE" >&2
    echo "Install it with apt/conda or set COLMAP_EXE=/absolute/path/to/colmap." >&2
    exit 1
  fi

  log "Environment check"
  python - <<'PY' 2>&1 | tee "$LOG_DIR/02_env_check.log"
import torch
print("torch:", torch.__version__)
print("torch cuda:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
import diff_gaussian_rasterization
import simple_knn._C
import fused_ssim
print("3DGS extensions import OK")
PY
}

convert_dataset() {
  log "Running COLMAP conversion"
  cd "$GS_DIR"
  local convert_args=(-s "$DATASET_DIR" --colmap_executable "$COLMAP_EXE")
  if [[ "$RESIZE" == "1" ]]; then
    convert_args+=(--resize)
  fi
  python convert.py "${convert_args[@]}" 2>&1 | tee "$LOG_DIR/03_convert.log"

  local sparse_dir="$DATASET_DIR/sparse/0"
  for file in cameras.bin images.bin points3D.bin; do
    if [[ ! -f "$sparse_dir/$file" ]]; then
      echo "COLMAP conversion did not produce $sparse_dir/$file" >&2
      exit 1
    fi
  done
}

train_render_metrics() {
  local run_id="$1"
  local iterations="$2"
  shift 2

  local model_dir="$OUTPUT_ROOT/$run_id"
  mkdir -p "$model_dir"
  cd "$GS_DIR"

  log "Training run: $run_id"
  python train.py \
    -s "$DATASET_DIR" \
    -m "$model_dir" \
    --eval \
    --iterations "$iterations" \
    "$@" 2>&1 | tee "$LOG_DIR/04_${run_id}_train.log"

  log "Rendering run: $run_id"
  python render.py -m "$model_dir" 2>&1 | tee "$LOG_DIR/05_${run_id}_render.log"

  log "Metrics run: $run_id"
  python metrics.py -m "$model_dir" 2>&1 | tee "$LOG_DIR/06_${run_id}_metrics.log"
}

write_summary() {
  local summary="$OUTPUT_ROOT/RUN_SUMMARY.md"
  cat > "$summary" <<EOF
# 3DGS Run Summary

- Dataset: \`$DATASET_NAME\`
- Dataset directory: \`$DATASET_DIR\`
- Output directory: \`$OUTPUT_ROOT\`
- Input images: \`$(count_input_images)\`
- Baseline iterations: \`$ITERATIONS\`
- Run comparisons: \`$RUN_COMPARISONS\`
- Logs: \`$LOG_DIR\`

## Important outputs

- Baseline model: \`$OUTPUT_ROOT/baseline\`
- Baseline point cloud: \`$OUTPUT_ROOT/baseline/point_cloud/iteration_${ITERATIONS}/point_cloud.ply\`
- SuperSplat: https://superspl.at/editor

## Reproduce command

\`\`\`bash
DATASET_NAME=$DATASET_NAME \\
VIDEO_PATH=$VIDEO_PATH \\
IMAGE_DIR=$IMAGE_DIR \\
FPS=$FPS \\
ITERATIONS=$ITERATIONS \\
RUN_SETUP=$RUN_SETUP \\
RUN_COMPARISONS=$RUN_COMPARISONS \\
bash scripts/run_all_ubuntu.sh
\`\`\`
EOF
  log "Summary written to $summary"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

mkdir -p "$LOG_DIR"

log "Starting 3DGS full pipeline"
prepare_input_images
setup_environment
convert_dataset

# shellcheck disable=SC2206
EXTRA_ARGS=($EXTRA_TRAIN_ARGS)
train_render_metrics "baseline" "$ITERATIONS" "${EXTRA_ARGS[@]}"

if [[ "$RUN_COMPARISONS" == "1" ]]; then
  train_render_metrics "iter_${COMPARISON_ITERATIONS}" "$COMPARISON_ITERATIONS"
  train_render_metrics "densify_low" "$ITERATIONS" --densify_grad_threshold "$DENSIFY_LOW_THRESHOLD"
  train_render_metrics "pos_lr_low" "$ITERATIONS" --position_lr_init "$POS_LR_LOW"
fi

write_summary
log "Done"
