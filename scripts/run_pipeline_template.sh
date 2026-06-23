#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GS_DIR="$REPO_ROOT/third_party/gaussian-splatting"

DATASET_NAME="${DATASET_NAME:-my_scene}"
DATASET_DIR="${DATASET_DIR:-$REPO_ROOT/data/$DATASET_NAME}"
INPUT_DIR="$DATASET_DIR/input"
MODEL_NAME="${MODEL_NAME:-baseline}"
MODEL_DIR="${MODEL_DIR:-$REPO_ROOT/outputs/$DATASET_NAME/$MODEL_NAME}"

VIDEO_PATH="${VIDEO_PATH:-}"
FPS="${FPS:-2}"
ITERATIONS="${ITERATIONS:-30000}"
COLMAP_EXE="${COLMAP_EXE:-colmap}"
RESIZE="${RESIZE:-0}"
EXTRA_TRAIN_ARGS="${EXTRA_TRAIN_ARGS:-}"

mkdir -p "$INPUT_DIR" "$MODEL_DIR"

if [[ -n "$VIDEO_PATH" ]]; then
  ffmpeg -y -i "$VIDEO_PATH" -vf "fps=$FPS" "$INPUT_DIR/%06d.jpg"
fi

cd "$GS_DIR"

CONVERT_ARGS=(-s "$DATASET_DIR" --colmap_executable "$COLMAP_EXE")
if [[ "$RESIZE" == "1" ]]; then
  CONVERT_ARGS+=(--resize)
fi
python convert.py "${CONVERT_ARGS[@]}"

read -r -a EXTRA_ARGS <<< "$EXTRA_TRAIN_ARGS"
python train.py \
  -s "$DATASET_DIR" \
  -m "$MODEL_DIR" \
  --eval \
  --iterations "$ITERATIONS" \
  "${EXTRA_ARGS[@]}"

python render.py -m "$MODEL_DIR"
python metrics.py -m "$MODEL_DIR"

echo "Done. Model directory: $MODEL_DIR"
