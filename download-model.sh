#!/usr/bin/env bash
set -euo pipefail

MODEL_DIR="${HOME}/ai/bonsai/models"
MODEL_FILE="bonsai_image_4b-q1_0.gguf"
MODEL_URL="https://huggingface.co/Green-Sky/bonsai-image-binary-4B-GGUF/resolve/main/${MODEL_FILE}"
TARGET="${MODEL_DIR}/${MODEL_FILE}"

mkdir -p "${MODEL_DIR}"

if [[ -f "${TARGET}" ]] && [[ "$(stat -c%s "${TARGET}")" -gt 100000000 ]]; then
    echo "Model already present: ${TARGET}"
    echo "Size: $(stat -c%s "${TARGET}") bytes"
    exit 0
fi

echo "Downloading ${MODEL_FILE}..."
curl -fL --progress-bar -o "${TARGET}.partial" "${MODEL_URL}"
mv "${TARGET}.partial" "${TARGET}"

echo "Done: ${TARGET}"
echo "Size: $(stat -c%s "${TARGET}") bytes"
