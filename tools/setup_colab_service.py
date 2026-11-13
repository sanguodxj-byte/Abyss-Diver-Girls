# -*- coding: utf-8 -*-
"""
Colab VM 服务一键启动脚本：
1. 校验 Google Drive 挂载
2. 确保 ComfyUI 与 cloudflared 就绪
3. 软链接 MOSS Image 与 MiniMax H3 模型权重至 /content/ComfyUI/models/
4. 启动 ComfyUI 进程（后台运行）
5. 启动 cloudflared 隧道并获取公网 URL，输出供本机更新 tools/art_host.txt
"""
import os, sys, time, re, subprocess, urllib.request, json

def sh(c, t=120):
    return subprocess.run(c, shell=True, capture_output=True, text=True, timeout=t).stdout.strip()

print("=== 1. 检查 Google Drive 挂载 ===")
drive_ready = os.path.ismount("/content/drive")
print("Drive 已挂载:", drive_ready)

drive_h3 = "/content/drive/MyDrive/MiniMax_H3"
drive_moss = "/content/drive/MyDrive/MOSS_动漫"
print("H3 目录存在:", os.path.exists(drive_h3))
print("MOSS 目录存在:", os.path.exists(drive_moss))

print("=== 2. 检查 ComfyUI 与依赖 ===")
os.chdir("/content")
if not os.path.exists("ComfyUI"):
    print("克隆 ComfyUI...")
    sh("git clone https://github.com/comfyanonymous/ComfyUI.git")
os.chdir("/content/ComfyUI")
sh("pip install -q -r requirements.txt")

if not os.path.exists("/usr/local/bin/cloudflared"):
    print("安装 cloudflared...")
    sh("curl -sSL -o /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x /usr/local/bin/cloudflared")

print("=== 3. 建立模型软链接 ===")
C = "/content/ComfyUI/models"
os.makedirs(f"{C}/diffusion_models", exist_ok=True)
os.makedirs(f"{C}/text_encoders", exist_ok=True)
os.makedirs(f"{C}/vae", exist_ok=True)
os.makedirs(f"{C}/loras", exist_ok=True)

# MiniMax H3 权重
if os.path.exists(drive_h3):
    for f in os.listdir(drive_h3):
        src = os.path.join(drive_h3, f)
        if "diffusion" in f or "fl2va" in f or "convrot" in f and "vae" not in f:
            dst = f"{C}/diffusion_models/{f}"
        elif "qwen" in f or "encoder" in f:
            dst = f"{C}/text_encoders/{f}"
        elif "vae" in f:
            dst = f"{C}/vae/{f}"
        elif "lora" in f.lower() or "turbo" in f.lower():
            dst = f"{C}/loras/{f}"
        else:
            dst = f"{C}/diffusion_models/{f}"
        if not os.path.exists(dst):
            os.symlink(src, dst)
            print(f"Linked H3: {f} -> {dst}")

# MOSS 权重
if os.path.exists(drive_moss):
    moss_map = {
        "底模_mossImage25DAnime_sftINT8_int8.safetensors": f"{C}/diffusion_models/moss25d_int8.safetensors",
        "组件_qwen35_int8.safetensors": f"{C}/text_encoders/qwen35_int8.safetensors",
        "组件_flux2vae.safetensors": f"{C}/vae/flux2vae.safetensors",
        "LoRA_moss_pixelart_v03.safetensors": f"{C}/loras/moss_pixelart_v03.safetensors"
    }
    for src_name, dst_path in moss_map.items():
        src = os.path.join(drive_moss, src_name)
        if os.path.exists(src) and not os.path.exists(dst_path):
            os.symlink(src, dst_path)
            print(f"Linked MOSS: {src_name} -> {dst_path}")

print("=== 4. 启动 ComfyUI 进程 ===")
if not drive_ready:
    print("RESULT=PREPARED_NO_DRIVE")
    print("依赖已装好，等待 Google Drive 挂载后再跑一次本脚本即可链接权重并开服。")
    sys.exit(0)

sh("pkill -f '[m]ain.py --listen' || true")
time.sleep(1)
sh("cd /content/ComfyUI && nohup python main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch > /content/comfy.log 2>&1 &")

comfy_ok = False
for _ in range(30):
    time.sleep(1)
    try:
        r = urllib.request.urlopen("http://127.0.0.1:8188/system_stats", timeout=3)
        if r.status == 200:
            comfy_ok = True
            print("ComfyUI 本地已就绪")
            break
    except Exception:
        pass

if not comfy_ok:
    print("ERR: ComfyUI 启动超时，最后日志:")
    print(sh("tail -n 30 /content/comfy.log"))
    sys.exit(2)

print("=== 5. 启动 cloudflared 隧道 ===")
sh("pkill -f 'cloudflared tunnel' || true")
time.sleep(1)
sh("nohup /usr/local/bin/cloudflared tunnel --url http://127.0.0.1:8188 --no-autoupdate > /content/cf.log 2>&1 &")

tunnel_url = None
for _ in range(25):
    time.sleep(1)
    log = sh("cat /content/cf.log 2>/dev/null")
    m = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", log)
    if m:
        tunnel_url = m.group(0)
        break

print("TUNNEL_URL=" + str(tunnel_url))

