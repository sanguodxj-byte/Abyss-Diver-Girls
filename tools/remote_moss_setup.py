import os
import subprocess
import sys
import time
import re

LOG_FILE = "/content/setup.log"

def log(msg):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}"
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    print(line, flush=True)

log("Starting remote setup for MOSS-Image...")

subprocess.run(["apt-get", "update", "-qq"], stdout=subprocess.DEVNULL, check=False)
subprocess.run(["apt-get", "install", "-y", "-qq", "aria2"], stdout=subprocess.DEVNULL, check=False)

if not os.path.exists("/usr/local/bin/cloudflared"):
    subprocess.run(["wget", "-q", "-nc", "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64", "-O", "/usr/local/bin/cloudflared"], check=False)
    subprocess.run(["chmod", "+x", "/usr/local/bin/cloudflared"], check=False)

if not os.path.exists("/content/ComfyUI"):
    subprocess.run(["git", "clone", "https://github.com/comfyanonymous/ComfyUI.git", "/content/ComfyUI"], check=False)

subprocess.run([sys.executable, "-m", "pip", "install", "-q", "-r", "/content/ComfyUI/requirements.txt"], check=False)

os.makedirs("/content/ComfyUI/models/diffusion_models", exist_ok=True)
os.makedirs("/content/ComfyUI/models/text_encoders", exist_ok=True)
os.makedirs("/content/ComfyUI/models/vae", exist_ok=True)
os.makedirs("/content/ComfyUI/models/loras", exist_ok=True)

def aria_download(url, target, symlink=None):
    if os.path.exists(target) and os.path.getsize(target) > 1000000:
        log(f"Exists: {os.path.basename(target)}")
    else:
        log(f"Downloading {os.path.basename(target)} ...")
        d = os.path.dirname(target)
        b = os.path.basename(target)
        cmd = ["aria2c", "-c", "-x", "8", "-s", "8", "-k", "2M", "--dir", d, "-o", b, url]
        res = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if res.returncode == 0:
            log(f"Done: {b}")
        else:
            log(f"Error {b}: {res.stderr[-200:]}")
    if symlink and not os.path.exists(symlink):
        try:
            os.symlink(target, symlink)
        except Exception:
            pass

moss_files = [
    ("https://huggingface.co/Comfy-Org/MOSS-Image/resolve/main/diffusion_models/moss_image_sft_int8_convrot.safetensors",
     "/content/ComfyUI/models/diffusion_models/moss_image_sft_int8_convrot.safetensors",
     "/content/ComfyUI/models/diffusion_models/moss25d_int8.safetensors"),
    ("https://huggingface.co/Comfy-Org/MOSS-Image/resolve/main/text_encoders/qwen3.5_9b_w4a8_gptq.safetensors",
     "/content/ComfyUI/models/text_encoders/qwen3.5_9b_w4a8_gptq.safetensors",
     "/content/ComfyUI/models/text_encoders/qwen35_int8.safetensors"),
    ("https://huggingface.co/Comfy-Org/MOSS-Image/resolve/main/vae/flux2-vae_small.safetensors",
     "/content/ComfyUI/models/vae/flux2-vae_small.safetensors",
     "/content/ComfyUI/models/vae/flux2vae.safetensors"),
    ("https://huggingface.co/mossloras/moss-image-lora-archive/resolve/main/2026-10-19/MOSS-Image/2284180_%E8%94%9A%E8%93%9D%E6%A1%A3%E6%A1%88%E9%A3%8E%E6%A0%BC-blue-archive-style--style--anima-ill-krea2/3415234/ba_style_moss_uma_v1_1000.safetensors",
     "/content/ComfyUI/models/loras/ba_style_moss_uma_v1_1000.safetensors", None),
    ("https://huggingface.co/mossloras/moss-image-lora-archive/resolve/main/2026-10-19/MOSS-Image/2947136_%E9%B2%B8%E9%B1%BC%E5%A8%98-DeepSeek-Whalegirl/3416365/moss-%E9%B2%B8%E9%B1%BC%E5%A8%98.safetensors",
     "/content/ComfyUI/models/loras/deepseekchan_moss.safetensors", None),
    ("https://huggingface.co/ProbablyHumanAB/moss-pixelart-v.0.3/resolve/main/moss-pixelart-v.0.3.safetensors",
     "/content/ComfyUI/models/loras/moss_pixelart_v03.safetensors", None),
]

for url, target, sym in moss_files:
    aria_download(url, target, sym)

log("MOSS-Image ready! Launching services...")

subprocess.Popen(["python3", "/content/ComfyUI/main.py", "--listen", "127.0.0.1", "--port", "8188", "--highvram"],
                 stdout=open("/content/comfyui.log", "w"), stderr=subprocess.STDOUT, start_new_session=True)

subprocess.Popen(["/usr/local/bin/cloudflared", "tunnel", "--url", "http://127.0.0.1:8188", "--logfile", "/content/cloudflared.log"],
                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

time.sleep(3)
for _ in range(15):
    time.sleep(1)
    if os.path.exists("/content/cloudflared.log"):
        with open("/content/cloudflared.log", "r") as f:
            urls = re.findall(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", f.read())
            if urls:
                with open("/content/tunnel_url.txt", "w") as out:
                    out.write(urls[-1])
                log(f"Tunnel online: {urls[-1]}")
                break

log("All setup complete!")
