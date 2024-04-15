#!/usr/bin/env bash
echo "Deleting Stable Diffusion WebUI Forge"
rm -rf /workspace/stable-diffusion-webui-forge

echo "Deleting venv"
rm -rf /workspace/venv

echo "Cloning Stable Diffusion WebUI Forge repo to /workspace"
cd /workspace
git clone --depth=1 https://github.com/lllyasviel/stable-diffusion-webui-forge.git

echo "Installing Ubuntu updates"
apt update
apt -y upgrade

echo "Installing TCMalloc"
# Either google-perftools or libtcmalloc-minimal4 should do the trick
# apt install google-perftools
apt install libtcmalloc-minimal4

echo "Creating and activating venv"
cd stable-diffusion-webui-forge
python3 -m venv /workspace/venv
source /workspace/venv/bin/activate

echo "Installing Torch"
pip3 install --no-cache-dir torch==2.1.2 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

echo "Installing xformers"
pip3 install --no-cache-dir xformers==0.0.23.post1

echo "Installing Stable Diffusion WebUI Forge"
wget https://raw.githubusercontent.com/ashleykleynhans/runpod-worker-forge/main/install-forge.py
python3 -m install-forge --skip-torch-cuda-test

echo "Cloning the ReActor extension repo"
git clone https://github.com/Gourieff/sd-webui-reactor.git extensions/sd-webui-reactor

echo "Installing dependencies for ReActor"
cd /workspace/stable-diffusion-webui-forge/extensions/sd-webui-reactor
git checkout v0.6.1
pip3 install -r requirements.txt
pip3 install onnxruntime-gpu

echo "Installing the model for ReActor"
mkdir -p /workspace/stable-diffusion-webui-forge/models/insightface
cd /workspace/stable-diffusion-webui-forge/models/insightface
wget https://github.com/facefusion/facefusion-assets/releases/download/models/inswapper_128.onnx

echo "Configuring ReActor to use the GPU instead of CPU"
echo "CUDA" > /workspace/stable-diffusion-webui-forge/extensions/sd-webui-reactor/last_device.txt

echo "Installing RunPod Serverless dependencies"
cd /workspace/stable-diffusion-webui-forge
pip3 install huggingface_hub runpod

echo "Downloading Deliberate v2 model"
cd /workspace/stable-diffusion-webui-forge/models/Stable-diffusion
wget -O deliberate_v2.safetensors https://huggingface.co/XpucT/Deliberate/resolve/main/Deliberate_v2.safetensors

echo "Downloading SDXL base model"
wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

echo "Downloading SDXL Refiner"
wget https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors

echo "Downloading SD 1.5 VAE"
cd /workspace/stable-diffusion-webui-forge/models/VAE
wget https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors

echo "Downloading SDXL VAE"
wget https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors

echo "Downloading SD 1.5 ControlNet models"
mkdir -p /workspace/stable-diffusion-webui-forge/models/ControlNet
cd /workspace/stable-diffusion-webui-forge/models/ControlNet
wget https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth
wget https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth
wget https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth.pth
wget https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_inpaint.pth
wget https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_lineart.pth
wget https://huggingface.co/ioclab/ioc-controlnet/resolve/main/models/control_v1p_sd15_brightness.safetensors
wget https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1e_sd15_tile.pth

echo "Downloading SDXL ControlNet models"
wget https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/diffusers_xl_canny_full.safetensors

echo "Downloading InstantID ControlNet models"
wget -O ip-adapter_instant_id_sdxl.bin "https://huggingface.co/InstantX/InstantID/resolve/main/ip-adapter.bin?download=true"
wget -O control_instant_id_sdxl.safetensors "https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors?download=true"

echo "Downloading Upscalers"
mkdir -p /workspace/stable-diffusion-webui-forge/models/ESRGAN
cd /workspace/stable-diffusion-webui-forge/models/ESRGAN
wget https://huggingface.co/ashleykleynhans/upscalers/resolve/main/4x-UltraSharp.pth
wget https://huggingface.co/ashleykleynhans/upscalers/resolve/main/lollypop.pth

echo "Creating log directory"
mkdir -p /workspace/logs

echo "Installing config files"
cd /workspace/stable-diffusion-webui-forge
rm webui-user.sh config.json ui-config.json
wget https://raw.githubusercontent.com/ashleykleynhans/runpod-worker-forge/main/webui-user.sh
wget https://raw.githubusercontent.com/ashleykleynhans/runpod-worker-forge/main/config.json
wget https://raw.githubusercontent.com/ashleykleynhans/runpod-worker-forge/main/ui-config.json

echo "Starting Stable Diffusion WebUI Forge"
deactivate
export HF_HOME="/workspace"
cd /workspace/stable-diffusion-webui-forge
./webui.sh -f
