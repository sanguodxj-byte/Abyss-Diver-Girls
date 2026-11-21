# -*- coding: utf-8 -*-
"""在活跃 Colab L4 实例上部署 MiniMax H3 权重并切换 ComfyUI 至正常显存卸载模式。"""

import os
import re
import subprocess
import time
import urllib.request

REV = "54472221d27c695fca9621b0c3ed52f06c4af707"
BASE = f"https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/{REV}"
M = "/content/ComfyUI/models"

FILES = [
    (f"{BASE}/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors",
     f"{M}/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors", 20000000000),
    (f"{BASE}/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors",
     f"{M}/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors", 15000000000),
    (f"{BASE}/vae/minimax_h3_video_vae_int8_convrot.safetensors",
     f"{M}/vae/minimax_h3_video_vae_int8_convrot.safetensors", 2700000000),
    (f"{BASE}/vae/minimax_h3_audio_vae_fp32.safetensors",
     f"{M}/vae/minimax_h3_audio_vae_fp32.safetensors", 500000000),
    (f"{BASE}/loras/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors",
     f"{M}/loras/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors", 1900000000),
]

for d in ["diffusion_models", "text_encoders", "vae", "loras"]:
    os.makedirs(f"{M}/{d}", exist_ok=True)


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


for url, dst, min_sz in FILES:
    name = os.path.basename(dst)
    if os.path.exists(dst) and os.path.getsize(dst) >= min_sz:
        log(f"Exists: {name}")
        continue
    log(f"Downloading {name} ...")
    cmd = ["aria2c", "-c", "-x", "16", "-s", "16", "-k", "4M",
           "--summary-interval=0", "--console-log-level=warn",
           "--dir", os.path.dirname(dst), "-o", name, url]
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        log(f"ERR {name}: {res.stderr[-300:]}")
        raise SystemExit(1)
    log(f"Done: {name} ({round(os.path.getsize(dst)/1e9, 2)} GB)")

log("Restarting ComfyUI without --highvram for 24GB L4 dynamic offload...")
subprocess.run("pkill -f '/content/ComfyUI/main.py' || true", shell=True, check=False)
time.sleep(2)
subprocess.Popen(
    ["python3", "/content/ComfyUI/main.py", "--listen", "127.0.0.1", "--port", "8188", "--disable-auto-launch"],
    stdout=open("/content/comfyui.log", "w"),
    stderr=subprocess.STDOUT,
    start_new_session=True,
)

for _ in range(45):
    time.sleep(1)
    try:
        with urllib.request.urlopen("http://127.0.0.1:8188/system_stats", timeout=3) as r:
            if r.status == 200:
                log("ComfyUI online (normal offload mode).")
                break
    except Exception:
        pass
else:
    log("ComfyUI failed to start! Tail:")
    print(open("/content/comfyui.log").read()[-1000:], flush=True)
    raise SystemExit(2)

# Verify cloudflared tunnel still running
cf_check = subprocess.run("pgrep -f cloudflared", shell=True, capture_output=True, text=True)
if not cf_check.stdout.strip():
    log("Restarting cloudflared...")
    subprocess.Popen(
        ["/usr/local/bin/cloudflared", "tunnel", "--url", "http://127.0.0.1:8188", "--logfile", "/content/cloudflared.log"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
    )
    time.sleep(5)
    urls = re.findall(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", open("/content/cloudflared.log").read())
    if urls:
        with open("/content/tunnel_url.txt", "w") as f:
            f.write(urls[-1])

log("TUNNEL=" + open("/content/tunnel_url.txt").read().strip())
log("H3 setup complete!")
