# -*- coding: utf-8 -*-
"""多画师串联（画师串）对比测试工具 — MOSS-Image 官方 @artist 语法与标准 Tag 序位。

遵循 MOSS-Image 官方 Tag 序位：
Quality -> Meta -> Year -> Character -> Artist (@a1, @a2, ...) -> General
测试 4 组不同风味的多画师串联配方，以奈绪（nao）为基准出图对比。
"""

import argparse
import json
import os
import sys
import time
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


ARTIST_STRINGS = {
    "tactical_heavy": {
        "label": "冷峻机能厚涂串",
        "artists": "@liduke, @neco, @lm7, @huke, @alchemaniac, @chuzenji",
        "style_tail": "anime coloring, 2d illustration, sharp lineart, tactical techwear aesthetic, deep dark shadows, striking contrast"
    },
    "crisp_luminous": {
        "label": "通透锐利高饱和串",
        "artists": "@ciloranko, @ask (askzy), @yoneyama mai, @mika pikazo, @rella",
        "style_tail": "anime coloring, 2d illustration, vibrant high-contrast colors, crisp fluid lineart, clear luminous eyes"
    },
    "youthful_gacha": {
        "label": "清透少女立绘串",
        "artists": "@torino aqua, @namie, @anmi, @hiten (hitenkei), @shiratama (shiratamaco)",
        "style_tail": "anime coloring, 2d illustration, cel shading, crisp clean linework, rich vivid colors, youthful delicate face"
    },
    "dark_cyber_blade": {
        "label": "暗黑刀锋机能串",
        "artists": "@redjuice, @oguchi, @lack, @miv4t, @toosaka asagi",
        "style_tail": "anime coloring, 2d illustration, sharp mechanical lineart, bold cinematic dark shadows, high contrast lighting"
    }
}

QUALITY_META_YEAR = "masterpiece, best quality, absurdres, highres, newest, year 2025, 1girl, solo"

NAO_GENERAL = (
    "16 years old cute anime girl, youthful delicate face, soft cheeks, "
    "long ash silver hair, soft wispy bangs, silver star-wing hair clips, "
    "pale muted crimson eyes, calm quiet kuudere gaze, "
    "jet black tactical techwear jacket with high collar, chest rig straps, vibrant silver wing sword emblem on chest, "
    "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, "
    "looking at viewer at eye level, off-center framing, "
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips, "
    "pure solid black background, pitch black minimalist background"
)

NEGATIVE_PROMPT = (
    "washed out, faded, pale colors, desaturated, low contrast, overexposed, hazy, foggy, white haze, milky, "
    "mature face, adult woman, tall mature female, long jaw, sharp angular chin, long horse face, "
    "sunken cheeks, aging, wrinkles, tired eyes, dark circles, milf, middle aged, older woman, "
    "pixel art, 16-bit, chunky pixels, pixelated, 3d, 3d render, realistic photo, photograph, dslr, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, makeup, "
    "id photo, passport photo, mugshot, front view, rigid pose, stiff pose, symmetrical, "
    "standing at attention, perfect symmetry, centered headshot, formal portrait, "
    "angry, fierce, scowl, glowing eyes, glowing pupils, laser eyes, bright red glare, "
    "lowres, worst quality, low quality, bad anatomy, bad hands, extra digits, fewer digits, "
    "extra limbs, watermark, text"
)


def build_graph(preset_key: str, seed: int):
    p = ARTIST_STRINGS[preset_key]
    positive = f"{QUALITY_META_YEAR}, {p['artists']}, {p['style_tail']}, {NAO_GENERAL}"

    g = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "moss_image_sft_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3.5_9b_w4a8_gptq.safetensors", "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae_small.safetensors"}},
        "6": {
            "class_type": "SkipLayerGuidanceDiTSimple",
            "inputs": {
                "model": ["1", 0],
                "double_layers": "",
                "single_layers": "22",
                "start_percent": 0.0,
                "end_percent": 1.0,
            }
        },
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": positive}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": NEGATIVE_PROMPT}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 832, "height": 1216, "batch_size": 1}},
        "8": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["6", 0],
                "positive": ["4", 0],
                "negative": ["5", 0],
                "latent_image": ["7", 0],
                "seed": seed,
                "steps": 45,
                "cfg": 3.5,
                "sampler_name": "euler",
                "scheduler": "sgm_uniform",
                "denoise": 1.0,
            }
        },
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": f"str_{preset_key}"}},
    }
    return g


def generate(preset_key: str, seed: int, out_path: str, timeout: int = 600):
    host = get_host()
    g = build_graph(preset_key, seed)
    client_id = str(uuid.uuid4())
    payload = json.dumps({"prompt": g, "client_id": client_id}).encode("utf-8")
    req = urllib.request.Request(f"{host}/prompt", data=payload, headers={"Content-Type": "application/json"})

    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            prompt_id = data.get("prompt_id")
    except Exception as e:
        print(f"Failed to submit: {e}", file=sys.stderr)
        return False

    print(f"[{preset_key}] Submitted prompt_id: {prompt_id}, seed: {seed}")
    deadline = time.time() + timeout
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
                        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
                        with open(out_path, "wb") as f:
                            f.write(img_data)
                        print(json.dumps({
                            "status": "success",
                            "preset": preset_key,
                            "file": os.path.abspath(out_path),
                            "seed": seed,
                            "seconds": round(time.time() - t0, 1),
                            "bytes": len(img_data)
                        }, ensure_ascii=False))
                        return True
        except Exception:
            continue
    return False


def main():
    parser = argparse.ArgumentParser(description="多画师串联对比测试")
    parser.add_argument("preset", choices=list(ARTIST_STRINGS.keys()) + ["all"])
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()

    targets = list(ARTIST_STRINGS.keys()) if args.preset == "all" else [args.preset]
    for k in targets:
        out = f"review\\奈绪_画师串_{k}.png"
        generate(k, args.seed, out)


if __name__ == "__main__":
    main()
