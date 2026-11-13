# -*- coding: utf-8 -*-
"""
DeepSeek-chan 单条说话动作生成流水线：
- 严格遵循背侧 45 度视角（身体背对镜头、头与躯干同向朝右前 45 度，微露右侧脸颊与右鲸鳍耳，零回头、零转角）
- 16-bit 像素块风格硬边锁定、纯黑背景无杂物无卷轴
- 口型在右侧颜轮廓处自然开合，唇部严格无色填充单细线
- 生成完成后在 VM 侧执行 LAB-CDF 色彩校准并转码为 Godot 专用的 Theora (.ogv)
- 提取 0.5s / 2.5s / 4.5s 三帧拼图供单张审核交付
"""
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from PIL import Image

ROOT = r"D:\123\qianyuanshaonv"
ART_HOST_FILE = os.path.join(ROOT, "tools", "art_host.txt")
REF_NAME = "deepseek_ref.png"
PROXY = "http://127.0.0.1:7897"

DIT = "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
TE = "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
VVAE = "minimax_h3_video_vae_int8_convrot.safetensors"
AVAE = "minimax_h3_audio_vae_fp32.safetensors"
LORA = "minimax_h3_fl2v_turbo_4step_v1.0_768p_comfyui_bf16.safetensors"
WIDTH, HEIGHT, LENGTH, STEPS, FPS = 736, 1280, 124, 4, 24.0

VOICE = "soft bright young female voice, gentle teenage anime girl tone"

BASE_LOCK = (
    "At 0.00 seconds, <Picture 1> is fully referenced. A 5-second 16-bit retro game pixel sprite animation "
    "rendered in chunky square pixel blocks: every frame is pixelated pixel art with crisp hard pixel edges, "
    "visible square pixel grid, no smoothing, no anti-aliasing, no soft shading, retro sprite look preserved in every frame. "
    "The character maintains the exact same three-quarter rear angle of <Picture 1> throughout the entire video: "
    "body and head are angled 45 degrees towards the right, keeping her right cheek contour and right whale fin ear visible. "
    "Strictly zero rotation: she neither turns forward toward the viewer nor turns away into a flat back view. "
    "Her head yaw, neck angle, and body orientation remain completely frozen at 45 degrees to the right for the full duration. "
    "Her body posture is completely still from head to shoes: standing firmly on both feet with white thighhighs "
    "and black mary janes shoes, no stepping, no walking, no arm or hand movement, no torso twisting. "
    "The only motions in the shot are her speaking animation, subtle breathing with a gentle chest rise and fall, "
    "a very soft idle drift of her hair tips and her single starry blue whale tail swaying ever so slightly behind her. "
    "Full-body shot framed continuously from top to bottom, no zoom in, no close-up, constant camera distance. "
    "Maintain exact character identity, dark navy blue dress with gold trim, white apron and large back bow, "
    "her eyes are bright deep blue with a clear luminous blue iris. "
    "Pure solid pitch black background with zero objects, no background scenery, no props, no scrolls, completely isolated sprite on solid black background. "
    "One continuous shot, no cuts, no on-screen text."
)

ACTIONS = {
    "talk_neutral": (
        "her mouth distinctly opens and closes in profile along the right cheek edge in simple sprite mouth flapping, "
        "lips parting and closing with her lower jaw moving up and down, with a calm composed look directed toward the right wall."
    ),
    "talk_smile": (
        "her visible right cheek contour softly raised in a sweet gentle smile, "
        "her mouth distinctly opens and closes in profile along the right cheek edge in simple sprite mouth flapping, "
        "lips parting and closing with her lower jaw moving up and down as she happily talks towards the right wall."
    ),
    "talk_serious": (
        "her visible right brow slightly resolute, "
        "her mouth distinctly opens and closes with firm clipped motions in profile along the right cheek edge in simple sprite mouth flapping, "
        "lips parting and closing with her lower jaw moving up and down towards the right wall."
    ),
    "talk_sad": (
        "her gaze slightly lowered while staying directed toward the right wall, "
        "her mouth slowly opens and closes in profile along the right cheek edge in simple sprite mouth flapping, "
        "lips parting and closing with her lower jaw moving slowly up and down towards the right wall."
    ),
    "talk_tired": (
        "her eyelids slightly drooping, "
        "her mouth sluggishly opens and closes in profile along the right cheek edge in simple sprite mouth flapping, "
        "lips parting and closing with her lower jaw moving up and down towards the right wall."
    ),
    "talk_surprised": (
        "her visible right eye widening briefly, "
        "her mouth opening wide in surprise in profile along the right cheek edge before opening and closing in simple sprite mouth flapping, "
        "lips parting and closing with her lower jaw moving up and down."
    ),
    "talk_shy": (
        "a faint subtle warmth touching her visible right cheek, "
        "her mouth timidly opens and closes in profile along the right cheek edge in simple sprite mouth flapping, "
        "lips parting and closing with her lower jaw moving up and down towards the right wall."
    ),
}

SEEDS = {
    "talk_neutral": 20261121,
    "talk_smile": 20261121,
    "talk_serious": 20261121,
    "talk_sad": 20261121,
    "talk_tired": 20261121,
    "talk_surprised": 20261121,
    "talk_shy": 20261121,
}


def get_base_url():
    with open(ART_HOST_FILE, "r", encoding="utf-8") as f:
        return f.read().strip()


def get_opener():
    handler = urllib.request.ProxyHandler({"http": PROXY, "https": PROXY})
    return urllib.request.build_opener(handler)


def build_graph(action: str, seed: int) -> dict:
    motion = ACTIONS[action]
    prompt = (
        "At 0.00 seconds, <Picture 1> is fully referenced. A 5-second 16-bit retro game pixel sprite animation "
        "rendered in chunky square pixel blocks: every frame is pixelated pixel art with crisp hard pixel edges, "
        "visible square pixel grid, no smoothing, no anti-aliasing, no soft shading, retro sprite look preserved in every frame. "
        "Strictly locked-down wide full-body framing from head to shoes throughout all 124 frames: "
        "the character shoes, feet, and entire full body remain continuously visible from top to bottom, "
        "strictly zero camera zoom, strictly zero close-up cuts, strictly zero camera motion. "
        "The character maintains the exact same three-quarter rear angle of <Picture 1> throughout the entire video: "
        "body and head are angled 45 degrees towards the right, keeping her right cheek contour and right whale fin ear visible. "
        "Strictly zero rotation, strictly zero turning toward camera: she neither turns forward toward the viewer nor turns away into a flat back view. "
        "Her head yaw, neck angle, and body orientation remain completely frozen at 45 degrees to the right for the full duration. "
        "The back of her head, back of dress, and back apron bow remain facing the camera continuously with zero angle change. "
        "Her body posture is completely still from head to shoes: standing firmly on both feet with white thighhighs "
        "and black mary janes shoes, no stepping, no walking, no arm or hand movement, no torso twisting. "
        "The only motion in the shot is subtle breathing with a gentle chest rise and fall, a very soft idle drift of her hair tips, "
        "her single starry blue whale tail swaying ever so slightly behind her, and " + motion + " "
        "Lips remain an uncolored single thin line with zero lipstick. "
        "Full-body shot framed continuously from top to bottom with feet on the ground, no zoom in, no close-up, constant camera distance. "
        "Maintain exact character identity, dark navy blue dress with gold trim, white apron and large back bow. "
        "Pure solid pitch black background with zero objects, no background scenery, no props, no scrolls, completely isolated sprite on solid black background. "
        "One continuous shot, no cuts, no on-screen text."
    )
    return {
        "114": {"class_type": "LoadImage", "inputs": {"image": REF_NAME}},
        "6": {"class_type": "UNETLoader", "inputs": {"unet_name": DIT, "weight_dtype": "default"}},
        "13": {"class_type": "CLIPLoader", "inputs": {"clip_name": TE, "type": "minimax"}},
        "11": {"class_type": "VAELoader", "inputs": {"vae_name": VVAE}},
        "24": {"class_type": "VAELoader", "inputs": {"vae_name": AVAE}},
        "104": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {
            "clip": ["13", 0], "vae": ["11", 0], "first_frame": ["114", 0],
            "prompt": prompt, "width": WIDTH, "height": HEIGHT, "length": LENGTH}},
        "121": {"class_type": "LoraLoaderModelOnly", "inputs": {
            "model": ["6", 0], "lora_name": LORA, "strength_model": 1.0}},
        "16": {"class_type": "BasicGuider", "inputs": {"model": ["121", 0], "conditioning": ["104", 0]}},
        "9": {"class_type": "BasicScheduler", "inputs": {
            "model": ["121", 0], "scheduler": "simple", "steps": STEPS, "denoise": 1.0}},
        "17": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
        "15": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "14": {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["15", 0], "guider": ["16", 0], "sampler": ["17", 0],
            "sigmas": ["9", 0], "latent_image": ["104", 1]}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["14", 0], "vae": ["11", 0]}},
        "23": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["14", 0], "vae": ["24", 0]}},
        "91": {"class_type": "CreateVideo", "inputs": {
            "images": ["10", 0], "audio": ["23", 0], "fps": FPS}},
        "92": {"class_type": "SaveVideo", "inputs": {
            "video": ["91", 0], "filename_prefix": f"video/deepseek_{action}",
            "format": "auto", "codec": "auto"}},
    }


def submit_action(action: str, seed: int = None):
    if action not in ACTIONS:
        print(f"Unknown action: {action}. Available: {list(ACTIONS.keys())}")
        sys.exit(1)
    if seed is None:
        seed = SEEDS[action]

    base = get_base_url()
    graph = build_graph(action, seed)
    payload_str = json.dumps({"prompt": graph, "client_id": f"ds_talk_{action}"})

    tmp_json = os.path.join(ROOT, "review", f"_temp_{action}_prompt.json")
    with open(tmp_json, "w", encoding="utf-8") as f:
        f.write(payload_str)

    # 优先使用 curl 发送，稳健耐穿透
    cmd = [
        "curl", "-s", "-m", "30", "-x", PROXY,
        "-X", "POST", f"{base}/prompt",
        "-H", "Content-Type: application/json",
        "-d", f"@{tmp_json}"
    ]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode == 0 and "prompt_id" in p.stdout:
        resp = json.loads(p.stdout)
        pid = resp.get("prompt_id")
        print(f"SUBMITTED: action={action}, seed={seed}, prompt_id={pid}")
        return pid

    # 降级尝试 Python 原生
    print("Curl submit failed, trying python opener...")
    opener = get_opener()
    req = urllib.request.Request(f"{base}/prompt", data=payload_str.encode("utf-8"), headers={"Content-Type": "application/json"})
    with opener.open(req, timeout=30) as r:
        resp = json.loads(r.read().decode())
        pid = resp.get("prompt_id")
        print(f"SUBMITTED: action={action}, seed={seed}, prompt_id={pid}")
        return pid


if __name__ == "__main__":
    act = sys.argv[1] if len(sys.argv) > 1 else "talk_neutral"
    s = int(sys.argv[2]) if len(sys.argv) > 2 else None
    submit_action(act, s)
