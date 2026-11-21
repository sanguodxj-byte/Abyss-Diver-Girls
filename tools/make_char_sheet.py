# -*- coding: utf-8 -*-
"""潜渊少女角色人设图生成工具 (MOSS-Image + LoRA)。

模式说明：
  bust: 3/4 构图半身胸像立绘（细化五官、发型、鲸鱼鳍耳与女仆装细节）
  full: 全身立绘设定图（完整头顶到裙摆脚部，展示鲸鱼尾与长裙女仆装结构）
  close: 面部特写设定图

用法示例：
  python tools\\make_char_sheet.py bust --seed 42 --out review\\char_bust_42.png
  python tools\\make_char_sheet.py full --seed 108 --out review\\char_full_108.png
  python tools\\make_char_sheet.py bust --anime-style --seed 77 --out review\\char_anime_77.png
"""

import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request
import uuid

HOST_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_host.txt")


def get_host():
    env = os.environ.get("ART_COMFY_HOST", "").strip()
    if env:
        return env.rstrip("/")
    if os.path.exists(HOST_FILE):
        try:
            with open(HOST_FILE, "r", encoding="utf-8") as f:
                h = f.read().strip()
                if h:
                    return h.rstrip("/")
        except OSError:
            pass
    return "http://127.0.0.1:8188"


# 提示词构件（严格遵循铁律：自然淡唇色、细单线、无唇彩/口红高光）
BASE_QUALITY = (
    "masterpiece, best quality, absurdres, highres, 1girl, solo"
)

LIP_CONSTRAINTS = (
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips"
)

CHARACTER_BASE = (
    "DeepseekChan, 16 years old, delicate and refined teenage girl face, porcelain pale skin, "
    "gradient long hair, ahoge, whale fin ears, bright expressive blue eyes, "
    "navy blue long maid dress, floor-length skirt, gold trim, white frills, "
    "white apron with blue whale emblem, black bodice with gold clasp, white ruffled cuffs, "
    "blue gemstone brooch at the collar, blue whale tail behind her"
)

BACKDROP = "pure solid black background, pitch black minimalist background"

# 统一硬门禁负面提示词
NEGATIVE_PROMPT = (
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, makeup, "
    "short skirt, miniskirt, microskirt, bare legs, cleavage, "
    "mature face, adult woman, tall, voluptuous, aged, "
    "id photo, passport photo, mugshot, front view, rigid pose, stiff pose, "
    "perfect symmetry, centered headshot, formal portrait, glowing eyes, glowing pupils, "
    "3d, realistic photo, photograph, dslr, blurry, anti-aliased, "
    "lowres, worst quality, low quality, bad anatomy, bad hands, extra digits, fewer digits, "
    "extra limbs, watermark, text"
)


def build_workflow_graph(mode: str, seed: int, anime_style: bool = False, expr: str = "neutral"):
    expr_text = ""
    if expr == "smile":
        expr_text = ", gentle subtle smile, calm pleasant expression"
    elif expr == "serious":
        expr_text = ", calm stern serious look, brow slightly furrowed, steady gaze"
    elif expr == "surprised":
        expr_text = ", brief surprised expression, eyes slightly widened"

    if mode == "bust":
        width, height = 832, 1216
        composition = (
            "close-up bust shot, upper body, head and shoulders, face large in frame, "
            "three-quarter view, dynamic angle, off-center"
        )
    elif mode == "close":
        width, height = 1024, 1024
        composition = (
            "face close-up portrait, head and shoulders, dynamic angle, three-quarter view"
        )
    else:  # full
        width, height = 832, 1216
        composition = (
            "full body shot, whole figure visible from head to feet, standing straight, "
            "complete silhouette showing full length maid skirt and whale tail"
        )

    if anime_style:
        style_prompt = "anime coloring, cel shading, 2d illustration, clean lineart, anime screencap, vibrant clean colors"
        primary_lora = "ba_style_moss_uma_v1_1000.safetensors"
        primary_weight = 0.8
    else:
        style_prompt = (
            "pixel art, 16-bit pixel art, modern indie game pixel sprite, chunky pixel blocks, "
            "coarse visible pixel grid, clean grid-aligned pixels, distinct square pixels"
        )
        primary_lora = "moss_pixelart_v03.safetensors"
        primary_weight = 1.0

    full_prompt = f"{BASE_QUALITY}, {style_prompt}, {composition}, {CHARACTER_BASE}, {LIP_CONSTRAINTS}{expr_text}, {BACKDROP}"

    g = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "moss_image_sft_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3.5_9b_w4a8_gptq.safetensors", "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae_small.safetensors"}},
        "11": {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["2", 0],
                "lora_name": primary_lora,
                "strength_model": primary_weight,
                "strength_clip": primary_weight,
            }
        },
        "12": {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["11", 0],
                "clip": ["11", 1],
                "lora_name": "deepseekchan_moss.safetensors",
                "strength_model": 0.75,
                "strength_clip": 0.75,
            }
        },
        "6": {
            "class_type": "SkipLayerGuidanceDiTSimple",
            "inputs": {
                "model": ["12", 0],
                "double_layers": "",
                "single_layers": "22",
                "start_percent": 0.0,
                "end_percent": 1.0,
            }
        },
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": full_prompt}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEGATIVE_PROMPT}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "8": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["6", 0],
                "positive": ["4", 0],
                "negative": ["5", 0],
                "latent_image": ["7", 0],
                "seed": seed,
                "steps": 45,
                "cfg": 3.0,
                "sampler_name": "euler",
                "scheduler": "sgm_uniform",
                "denoise": 1.0,
            }
        },
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": f"char_{mode}"}},
    }
    return g, full_prompt


def main():
    parser = argparse.ArgumentParser(description="潜渊少女角色人设图生成")
    parser.add_argument("mode", choices=["bust", "full", "close"], default="bust", nargs="?")
    parser.add_argument("--seed", type=int, default=-1)
    parser.add_argument("--out", required=True, help="输出本地文件路径")
    parser.add_argument("--anime-style", action="store_true", help="启用蔚蓝档案二次元萌系动漫风格代替像素立绘")
    parser.add_argument("--expr", choices=["neutral", "smile", "serious", "surprised"], default="neutral")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()

    host = get_host()
    seed = args.seed if args.seed >= 0 else random.randint(1000, 2147483647)
    graph, prompt_text = build_workflow_graph(args.mode, seed, args.anime_style, args.expr)

    client_id = str(uuid.uuid4())
    payload = json.dumps({"prompt": graph, "client_id": client_id}).encode("utf-8")
    req = urllib.request.Request(f"{host}/prompt", data=payload, headers={"Content-Type": "application/json"})

    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            prompt_id = data.get("prompt_id")
    except Exception as e:
        print(f"Error submitting to {host}: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Submitted task prompt_id: {prompt_id}, seed: {seed}")
    # 等待产物
    deadline = time.time() + args.timeout
    while time.time() < deadline:
        time.sleep(3)
        try:
            h_req = urllib.request.Request(f"{host}/history/{prompt_id}")
            with urllib.request.urlopen(h_req, timeout=10) as h_resp:
                hist = json.loads(h_resp.read().decode("utf-8")).get(prompt_id, {})
                status = hist.get("status", {})
                if status.get("status_str") == "error":
                    raise RuntimeError("Remote error: " + json.dumps(status))
                outputs = hist.get("outputs", {})
                if outputs:
                    images = []
                    for v in outputs.values():
                        images.extend(v.get("images", []))
                    if images:
                        target_img = images[0]
                        view_url = f"{host}/view?filename={target_img['filename']}&subfolder={target_img.get('subfolder', '')}&type={target_img.get('type', 'output')}"
                        img_data = urllib.request.urlopen(view_url, timeout=60).read()
                        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
                        with open(args.out, "wb") as f:
                            f.write(img_data)
                        print(json.dumps({
                            "status": "success",
                            "file": os.path.abspath(args.out),
                            "seed": seed,
                            "mode": args.mode,
                            "seconds": round(time.time() - t0, 1),
                            "bytes": len(img_data)
                        }))
                        return
        except Exception:
            continue

    print(f"Timed out after {args.timeout} seconds", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
