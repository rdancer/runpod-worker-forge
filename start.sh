#!/usr/bin/env bash

forge_log=/workspace/logs/forge.log
export TZ=Europe/London
FATAL_ERRORS=(
  # Make sure to break the strings "L""ike this" else when we cat this file to the logs, it will match!
  "R""untimeError: Unexpected error from cudaGetDeviceCount(). Did you run some cuda functions before calling NumCudaDevices() that might have already set an error? Error 804: forward compatibility was attempted on non supported HW"
)

# XXX We should take the same worker ID that shows in the runpod UI, it's some kind of a hexadecimal string
WORKER_ID=${RANDOM:0:1}${RANDOM}
export WORKER_ID


my_reboot() {
  # Wait for logs to synchronise before rebooting
  (sync) || true
  for i in 5 4 3 2 1; do
    timestamp="$(my_date)"
    echo "[$WORKER_ID] Rebooting in $i seconds"
    echo "$timestamp [$WORKER_ID] Rebooting in $i seconds" >> "$forge_log"
    sleep 1
  done
  echo "[$WORKER_ID] Rebooting now"
  echo "$timestamp [$WORKER_ID] Rebooting now" >> "$forge_log"
  (sync) || true
  sleep 1 # Let the last log message flush to the log file
  /reboot.sh
}

export time_zone="$(date +'%z')" # +0123
my_date() {
  timestamp="$(date +'%Y-%m-%d %H:%M:%S.%3N')"
  # Truncate nanoseconds to milliseconds and add timezone if known
  timestamp="${timestamp:0:23}"
  echo "${timestamp} ${time_zone}"
}

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
    timestamp="$(my_date)"
    message="Rebooting due to fatal error"
    printf '\n[%s] %s: %s\n' "$WORKER_ID" "$message" "$line"
    printf '\n%s [%s] %s: %s\n' "$timestamp" "$WORKER_ID" "$message" "$line" >> "$forge_log"
    my_reboot
  fi
}

my_logger() {
  # Forces runpod log viewer to show leading spaces -- very useful for stack traces
  zero_width_space="$(echo -ne "\xE2\x80\x8B")"
  do_not_ignore_leading_whitespace= #"$zero_width_space" # Actually we don't need it, as long as we lead with the $WORKER_ID -- and it creates garbage in the runpod UI log viewer (the React one, not the terminal-like one)
  log_file="$1"

  # Make sure we never block ever
  # The default size is 64kB on Linux, which is easily insufficient for some of the base64-encoded images that we love to log
  while IFS='' read -r line; do
    # Print the log to stdout and the log file
    timestamp="$(my_date)"
    printf '%s[%s] %s\n' "$do_not_ignore_leading_whitespace" "$WORKER_ID" "$line"
    printf '%s [%s] %s\n' "$timestamp" "$WORKER_ID" "$line" >> "$log_file"
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
