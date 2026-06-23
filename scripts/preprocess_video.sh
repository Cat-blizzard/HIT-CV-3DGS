#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <video_path> <scene_name> [fps]" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIDEO_PATH="$1"
SCENE_NAME="$2"
FPS="${3:-2}"
OUT_DIR="$REPO_ROOT/data/$SCENE_NAME/input"

mkdir -p "$OUT_DIR"
ffmpeg -y -i "$VIDEO_PATH" -vf "fps=$FPS" "$OUT_DIR/%06d.jpg"

echo "Frames written to $OUT_DIR"
