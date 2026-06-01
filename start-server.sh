#!/usr/bin/env bash
set -euo pipefail

MODEL_DIR="${HOME}/ai/bonsai/models"
DIFFUSION="${MODEL_DIR}/bonsai_image_4b-q1_0.gguf"
VAE="${MODEL_DIR}/flux2_ae.safetensors"
LLM="${MODEL_DIR}/Qwen_3_4b-imatrix-IQ4_XS.gguf"
PORT="${BONSAI_PORT:-1234}"

for f in "${DIFFUSION}" "${VAE}" "${LLM}"; do
    if [[ ! -f "${f}" ]]; then
        echo "Missing model file: ${f}" >&2
        echo "Run ./download-model.sh first." >&2
        exit 1
    fi
done

echo "Starting sd-server inside bonsai-image container..."
echo "Open http://localhost:${PORT} in your browser."
echo "Press Ctrl+C to stop."

exec distrobox enter bonsai-image -- \
    sd-server \
        --listen-ip 127.0.0.1 \
        --listen-port "${PORT}" \
        --diffusion-model "${DIFFUSION}" \
        --vae "${VAE}" \
        --llm "${LLM}" \
        --backend diffusion=vulkan0
