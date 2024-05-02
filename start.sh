#!/usr/bin/env bash

forge_log=/workspace/logs/forge.log
export TZ=Europe/London
FATAL_ERRORS=(
  "RuntimeError: Unexpected error from cudaGetDeviceCount(). Did you run some cuda functions before calling NumCudaDevices() that might have already set an error? Error 804: forward compatibility was attempted on non supported HW"
)

maybe_reboot() {
  found=false
  for item in "${FATAL_ERRORS[@]}"; do
    case "$line" in
      *"$item"*)
        found=true
        break
        ;;
    esac
  done
  if [ "$found" = true ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S.%3N') Rebooting due to fatal error: $line" | tee -a "$forge_log"
    sleep 5 # wait for logs to synchronise before rebooting
    reboot
  fi
}



my_logger() {
  # Forces runpod log viewer to show leading spaces -- very useful for stack traces
  zero_width_space="$(echo -ne "\xE2\x80\x8B")"
  log_file="$1"

  # Print the log to stdout and the log file
  while IFS='' read -r line; do
    timestamp="$(date +'%Y-%m-%d %H:%M:%S.%3N')"
    printf '%s%s\n' "$zero_width_space" "$line"
    printf '%s %s\n' "$timestamp" "$line" >> "$log_file"
    maybe_reboot "$line"
  done
}

echo "Initialising new Forge Worker"

echo "Symlinking files from Network Volume"
rm -rf /workspace && \
  ln -s /runpod-volume /workspace

echo "Docker image version: ${IMAGE_VERSION}"

if [ -f "/workspace/venv/bin/activate" ]; then
    echo "Starting Stable Diffusion WebUI Forge API"
    source /workspace/venv/bin/activate
    echo Python3 is `which python3`
    TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
    export LD_PRELOAD="${TCMALLOC}"
    export PYTHONUNBUFFERED=true
    export HF_HOME="/workspace"
    python3 /workspace/stable-diffusion-webui-forge/webui.py \
      --xformers \
      --no-half-vae \
      --skip-python-version-check \
      --skip-torch-cuda-test \
      --skip-install \
      --lowram \
      --opt-sdp-attention \
      --disable-safe-unpickle \
      --port 3000 \
      --share \
      --api \
      --nowebui \
      --skip-version-check \
      --no-hashing \
      --no-download-sd-model \
      2>&1 \
      | my_logger "$forge_log" \
      &
    deactivate
else
    echo "ERROR: The Python Virtual Environment (/workspace/venv/bin/activate) could not be activated"
    echo "1. Ensure that you have followed the instructions at: https://github.com/ashleykleynhans/runpod-worker-forge/blob/main/docs/installing.md"
    echo "2. Ensure that you have used the Pytorch image for the installation and NOT a Stable Diffusion image."
    echo "3. Ensure that you have attached your Network Volume to your endpoint."
    echo "4. Ensure that you didn't assign any other invalid regions to your endpoint."
fi

echo "Starting RunPod Handler"
python3 -u /rp_handler.py
