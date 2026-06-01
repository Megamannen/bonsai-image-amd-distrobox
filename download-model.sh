#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [MODEL_DIR]

Downloads the three model files needed to run Bonsai with sd.cpp:
  - bonsai_image_4b-q1_0.gguf        (diffusion model, ~908 MB)
  - flux2_ae.safetensors             (VAE, ~336 MB)
  - Qwen_3_4b-imatrix-IQ4_XS.gguf    (text encoder, ~2.27 GB)

MODEL_DIR resolution (highest precedence first):
  1. positional argument
  2. BONSAI_MODEL_DIR environment variable
  3. default: \$HOME/ai/bonsai/models

If you choose a directory outside \$HOME/ai/bonsai/, you must also:
  - mount it into the container (edit volume= in distrobox.ini)
  - point the server at it (export BONSAI_MODEL_DIR before ./start-server.sh)
EOF
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

MODEL_DIR="${1:-${BONSAI_MODEL_DIR:-${HOME}/ai/bonsai/models}}"
mkdir -p "${MODEL_DIR}"
echo "Target directory: ${MODEL_DIR}"

# Format: "<target-filename>|<download-url>|<minimum-bytes>"
FILES=(
    "bonsai_image_4b-q1_0.gguf|https://huggingface.co/Green-Sky/bonsai-image-binary-4B-GGUF/resolve/main/bonsai_image_4b-q1_0.gguf|100000000"
    "flux2_ae.safetensors|https://huggingface.co/ai-toolkit/flux2_vae/resolve/main/ae.safetensors|100000000"
    "Qwen_3_4b-imatrix-IQ4_XS.gguf|https://huggingface.co/worstplayer/Z-Image_Qwen_3_4b_text_encoder_GGUF/resolve/main/Qwen_3_4b-imatrix-IQ4_XS.gguf|1000000000"
)

for entry in "${FILES[@]}"; do
    IFS='|' read -r name url minsize <<< "${entry}"
    target="${MODEL_DIR}/${name}"

    if [[ -f "${target}" ]] && [[ "$(stat -c%s "${target}")" -gt "${minsize}" ]]; then
        echo "Present: ${name} ($(stat -c%s "${target}") bytes)"
        continue
    fi

    echo "Downloading ${name}..."
    curl -fL --progress-bar -o "${target}.partial" "${url}"
    mv "${target}.partial" "${target}"
    echo "Done: ${name} ($(stat -c%s "${target}") bytes)"
done

echo
echo "All model files present in ${MODEL_DIR}"
