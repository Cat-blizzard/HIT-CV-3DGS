#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GS_DIR="$REPO_ROOT/third_party/gaussian-splatting"

cd "$REPO_ROOT"

git submodule update --init third_party/gaussian-splatting third_party/colmap third_party/gsplat
git -C "$GS_DIR" submodule update --init --recursive \
  submodules/diff-gaussian-rasterization \
  submodules/simple-knn \
  submodules/fused-ssim

if ! command -v conda >/dev/null 2>&1; then
  echo "conda not found. Install Miniconda or load the server's conda module first." >&2
  exit 1
fi

source "$(conda info --base)/etc/profile.d/conda.sh"

if conda env list | awk '{print $1}' | grep -qx "gaussian_splatting"; then
  conda env update -n gaussian_splatting -f "$REPO_ROOT/environment/gaussian_splatting_ubuntu.yml"
else
  conda env create -f "$REPO_ROOT/environment/gaussian_splatting_ubuntu.yml"
fi

conda activate gaussian_splatting

cd "$GS_DIR"
python -m pip install --upgrade pip
python -m pip install submodules/diff-gaussian-rasterization
python -m pip install submodules/simple-knn
python -m pip install submodules/fused-ssim

python - <<'PY'
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
