# bonsai-amd-distrobox

Run the [Bonsai](https://huggingface.co/prism-ml/bonsai-image-binary-4B-mlx-1bit)
image-generation model on AMD GPUs via
[`stable-diffusion.cpp`](https://github.com/leejet/stable-diffusion.cpp)'s
Vulkan backend, inside a distrobox. The sd.cpp embedded web UI is reachable
from your host browser at `http://localhost:1234`.

Tested on a Radeon RX 9070 XT (RDNA 4, gfx1201) on Bazzite. Should work on any
recent AMD GPU with Mesa RADV Vulkan support.

## Requirements

- An AMD GPU with Vulkan support.
- `podman` and `distrobox` installed on the host.
- ~3 GB of disk for the container image and ~3.5 GB for the model files.

## Setup

```bash
git clone <repo-url> ~/repos/bonsai-amd-distrobox
cd ~/repos/bonsai-amd-distrobox

# 1. Build the container image (5–15 min, one-time)
podman build -t bonsai-amd-distrobox:latest .

# 2. Make sure the default directories exist
mkdir -p ~/ai/bonsai

# 3. Create the distrobox container
distrobox assemble create --file distrobox.ini

# 4. Download the three model files (~3.5 GB total, one-time, idempotent).
#    Defaults to ~/ai/bonsai/models. To use a different path:
#      ./download-model.sh /path/to/models
#    or set BONSAI_MODEL_DIR (read by both this script and start-server.sh).
./download-model.sh

# 5. Start the server
./start-server.sh
```

Then open `http://localhost:1234` in your browser.

Generated images are saved on the host at `~/ai/bonsai/outputs/`. Model weights
live at `~/ai/bonsai/models/`.

## Recommended generation settings

Bonsai is FLUX.2-klein-4B distilled. Use the settings the model author publishes:

| Setting | Value | Why |
|---|---|---|
| **Steps** | **4** | Distilled model — more steps don't improve quality and can hurt. |
| **CFG / Guidance** | **1.0** | Distilled model has guidance baked in. |
| **Shift** (flow shift) | **3.0** | Flow-matching shift parameter the model was trained with. |
| **Sampler** | **euler** | FLUX.2 default. |
| **Scheduler** | **default** (= `discrete`) | What the upstream FLUX.2 examples use. |
| **Resolution** | **1024 × 1024** native, or 512 × 512 for fast previews | Aspect ratios must be multiples of 32 (e.g., 832×1248). |
| **Negative prompt** | leave empty | No effect at CFG = 1.0. |

### VAE tiling (REQUIRED for 1024×1024 on AMD/Vulkan)

The FLUX.2-klein VAE decode step asks for an ~8.5 GiB single buffer at
1024×1024 latents, which **exceeds the per-allocation limit on Vulkan** and
fails with `ErrorOutOfDeviceMemory`. See sd.cpp issues
[#1220](https://github.com/leejet/stable-diffusion.cpp/issues/1220) and
[#1275](https://github.com/leejet/stable-diffusion.cpp/issues/1275). VAE tiling
decodes the latent in smaller chunks and avoids the limit entirely.

In the web UI, find the **VAE tiling** controls (under generation settings) and
set:

| Setting | Value |
|---|---|
| Enabled | **on** |
| Tile size X / Y | **32 × 32** (latent units; ≈512 image-pixels per tile for FLUX.2) |
| Target overlap | **0.5** (50% — hides seams) |

If you only generate at 512×512 or 768×768, you can leave tiling off — those
resolutions fit without it.

## Storing models elsewhere

By default both `download-model.sh` and `start-server.sh` look at
`~/ai/bonsai/models/`. To use a different location, either pass it as an
argument to `download-model.sh` or set `BONSAI_MODEL_DIR`:

```bash
export BONSAI_MODEL_DIR=/data/ai-models/bonsai
./download-model.sh                # downloads there
./start-server.sh                  # reads from there
```

**If your model directory is outside `~/ai/bonsai/`**, you must also mount it
into the container so `sd-server` can read the files. Edit `distrobox.ini` and
add a second `volume=` line (or replace the existing one) pointing at your
chosen path, then recreate the container:

```ini
volume="/data/ai-models/bonsai:/data/ai-models/bonsai"
```

```bash
distrobox rm -f bonsai-image
distrobox assemble create --file distrobox.ini
```

Paths under `$HOME` are mounted automatically by distrobox, so a custom path
inside your home directory doesn't need the manual mount.

## Layout

```
bonsai-amd-distrobox/
├── Containerfile        # Ubuntu 24.04 + Vulkan + pinned sd.cpp build (frontend embedded)
├── distrobox.ini        # Assemble manifest; creates "bonsai-image" container
├── download-model.sh    # Fetches diffusion model + VAE + text encoder
├── start-server.sh      # Launches sd-server inside the container
└── README.md
```

Models on the host:

```
~/ai/bonsai/
├── models/
│   ├── bonsai_image_4b-q1_0.gguf            # diffusion model     (~908 MB, Green-Sky)
│   ├── flux2_ae.safetensors                  # VAE                 (~336 MB, ai-toolkit)
│   └── Qwen_3_4b-imatrix-IQ4_XS.gguf         # text encoder        (~2.27 GB, worstplayer)
└── outputs/                                  # generated PNGs
```

## Troubleshooting

- **`vulkaninfo --summary` shows no GPU inside the container.**
  Confirm the device nodes are exposed:
  ```bash
  distrobox enter bonsai-image -- ls -la /dev/dri
  ```
  Should show `card*` and `renderD*`. If missing, your host may need extra GPU
  passthrough setup for distrobox.

- **Server starts, browser shows a white page (tab title loads).**
  The container image must be built with `-DSD_SERVER_BUILD_FRONTEND=ON` so the
  Vue web UI is embedded into the `sd-server` binary. If you customized the
  Containerfile and dropped that flag, the UI won't render. The default
  Containerfile here keeps it on.

- **Image generation fails with `vae alloc compute buffer failed` /
  `ErrorOutOfDeviceMemory` at 1024×1024.** Enable VAE tiling in the UI (see
  above). Alternatively, generate at 512×512 / 768×768.

- **The diffusion step itself OOMs (not the VAE).** Your card has less VRAM
  than the loaded model needs (~4.4 GiB). Try reducing resolution or pass
  `--offload-to-cpu` to `sd-server` in `start-server.sh`.

- **Generations very slow.** Check that `--backend diffusion=vulkan0` is
  selecting the right device — `distrobox enter bonsai-image -- vulkaninfo
  --summary` should list your AMD card as `vulkan0`. The Mesa software
  fallback (`llvmpipe`) is usually listed second.

## Notes

- The sd.cpp upstream commit is pinned in `Containerfile` (see `SDCPP_REF` arg).
  Bump it manually when you want updates.
- The container image bundles Node 20 + pnpm only to build the web frontend
  during `podman build`. They are not used at runtime.
- The model files are downloaded once and stored on the host (under
  `~/ai/bonsai/models/`), so they persist if you destroy and recreate the
  container.
