# -*- coding: utf-8 -*-
"""画师风格串测试工具。

以奈绪（nao）为基准，注入不同商业插画师专属风格串：
  neco: 末世战术机能少女风（A-Z: / 重兵装型女子高生 原案画风）
  yoneyama: 米山舞风（动态光影、棱镜色散、穿透水感与前卫线条）
  fuzichoco: 藤原风（高密度细节、华美宝石眼眸、流光溢彩）
  redjuice: redjuice风（科幻机能美少女、锋利刀锋线条、沉着机械感）
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


ARTISTS = {
    "neco": (
        "by neco, heavy weapon girl, sleek tactical techwear, minimalist sharp lineart, "
        "high-tech tactical accessories, cool kuudere expression, sharp crisp silhouette, striking dark contrast"
    ),
    "yoneyama": (
        "by mai yoneyama, dynamic dramatic lighting, subtle chromatic aberration, expressive fluid lineart, "
        "luminous translucent highlights, refractive light, modern stylish anime key visual"
    ),
    "fuzichoco": (
        "by fuzichoco, intricate ornate details, jewel-like radiant eyes, prismatic refractions, "
        "delicate intricate highlights, rich texture layering"
    ),
    "redjuice": (
        "by redjuice, sharp mechanical lineart, dark techwear aesthetic, striking eye contrast, "
        "bold cinematic shadows, sleek cyberpunk sci-fi anime aesthetic"
    )
}

BASE_QUALITY = "masterpiece, best quality, absurdres, highres, anime coloring, 2d illustration, anime screencap"

LIP_CONSTRAINTS = "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips"

BACKDROP = "pure solid black background, pitch black minimalist background"

NEGATIVE_PROMPT = (
    "washed out, faded, pale colors, desaturated, low contrast, overexposed, hazy, foggy, white haze, milky, "
    "mature face, adult woman, tall mature female, long jaw, sharp angular chin, long horse face, "
    "sunken cheeks, aging, wrinkles, tired eyes, dark circles, milf, middle aged, older woman, "
    "pixel art, 16-bit, chunky pixels, pixelated, 3d, realistic photo, photograph, dslr, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, makeup, "
    "id photo, passport photo, mugshot, front view, rigid pose, stiff pose, symmetrical, "
    "standing at attention, perfect symmetry, centered headshot, formal portrait, "
    "angry, fierce, scowl, glowing eyes, glowing pupils, laser eyes, bright red glare, "
    "lowres, worst quality, low quality, bad anatomy, bad hands, extra digits, fewer digits, "
    "extra limbs, watermark, text"
)

NAO_BASE = (
    "1girl, solo, 16 years old cute anime girl, adorable kuudere, youthful delicate face, pretty soft teenage features, "
    "long ash silver hair, soft wispy bangs, silver star-wing hair clips, pale muted crimson eyes, calm gentle gaze, "
    "jet black tactical techwear jacket with high collar, small chest rig straps, vibrant silver wing sword emblem on chest, "
    "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, off-center framing"
)


def build_graph(artist_key: str, seed: int):
    artist_tag = ARTISTS[artist_key]
    positive = f"{BASE_QUALITY}, {artist_tag}, {NAO_BASE}, {LIP_CONSTRAINTS}, {BACKDROP}"

    # LoRA 仅保留 0.35 辅佐二次元大眼比例，让画师串深度主导风格
    g = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "moss_image_sft_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3.5_9b_w4a8_gptq.safetensors", "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae_small.safetensors"}},
        "11": {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["2", 0],
                "lora_name": "ba_style_moss_uma_v1_1000.safetensors",
                "strength_model": 0.32,
                "strength_clip": 0.32,
            }
        },
        "6": {
            "class_type": "SkipLayerGuidanceDiTSimple",
            "inputs": {
                "model": ["11", 0],
                "double_layers": "",
                "single_layers": "22",
                "start_percent": 0.0,
                "end_percent": 1.0,
            }
        },
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 1], "text": positive}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 1], "text": NEGATIVE_PROMPT}},
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
                "cfg": 3.3,
                "sampler_name": "euler",
                "scheduler": "sgm_uniform",
                "denoise": 1.0,
            }
        },
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": f"artist_{artist_key}"}},
    }
    return g


def generate(artist_key: str, seed: int, out_path: str, timeout: int = 600):
    host = get_host()
    g = build_graph(artist_key, seed)
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

    print(f"[{artist_key}] Submitted prompt_id: {prompt_id}, seed: {seed}")
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
                            "artist": artist_key,
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
    parser = argparse.ArgumentParser(description="画师风格串生成测试")
    parser.add_argument("artist", choices=list(ARTISTS.keys()) + ["all"])
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()

    targets = list(ARTISTS.keys()) if args.artist == "all" else [args.artist]
    for a in targets:
        out = f"review\\奈绪_画师风格_{a}.png"
        generate(a, args.seed, out)


if __name__ == "__main__":
    main()
