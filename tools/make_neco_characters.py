# -*- coding: utf-8 -*-
"""潜渊少女 neco 风格角色人设图生成器。

采用画师 neco 标志性的末世重兵装机能美学：
极简锐利墨线、高科技战术配件、深沉纯黑机能对比、克制淡然神情与 16-19 岁少女比例。
"""

import argparse
import json
import os
import random
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


NECO_STYLE_PREFIX = (
    "masterpiece, best quality, absurdres, highres, by neco, heavy weapon girl, sleek tactical techwear, "
    "minimalist sharp lineart, high-tech tactical accessories, sharp crisp silhouette, striking dark contrast, "
    "youthful teenage anime girl, delicate soft cheeks, slender young girl body, 2d illustration, anime screencap"
)

LIP_CONSTRAINTS = (
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips"
)

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

CHARACTERS = {
    "rei": {
        "name": "零",
        "desc": (
            "1girl, solo, 17 years old cute anime girl, silver-white straight bob hair, bangs covering one eye, "
            "sharp deep ice blue eyes, quiet calm gaze, high-collar tactical suit, "
            "dark forest green camouflage capelet over shoulders, rangefinder on chest, polished silver dog tags, "
            "black fingerless tactical gloves"
        ),
        "pose": "upper body, bust shot, quiet deadpan stare, slight 3/4 turn, asymmetrical shoulders, looking at viewer, hand touching capelet strap"
    },
    "mia": {
        "name": "米娅",
        "desc": (
            "1girl, solo, 17 years old cute anime mechanic girl, light flaxen golden curly short hair, "
            "head-mounted brass mechanic goggles, brilliant amber golden eyes, calm pleasant smile, "
            "white tank top, deep indigo denim work overalls with utility tools in pockets, subtle cute grease smudge on cheek"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level"
    },
    "kurumi": {
        "name": "胡桃",
        "desc": (
            "1girl, solo, 16 years old cute anime girl, rich chestnut brown twin tails with vivid yellow cable ties, "
            "sharp vibrant emerald green eyes, small bandage on nose bridge, protective yellow goggles on head, "
            "vibrant safety orange and dark tactical grey fireproof overalls, black tactical undershirt"
        ),
        "pose": "upper body, bust shot, energetic slight smirk, tilted head, lively gaze at viewer, casual natural bust posture"
    },
    "lina": {
        "name": "莉娜",
        "desc": (
            "1girl, solo, 18 years old cute anime girl, airship bridge tactician, golden blonde bob hair, "
            "deep sapphire blue eyes, thin-rimmed silver glasses, calm intellectual expression, "
            "dark navy blue bridge officer shirt with gold trim, dark military capelet over shoulders, "
            "single-ear comms headset, silver clipboard in hand"
        ),
        "pose": "upper body, bust shot, calm intellectual expression, slight side glance at viewer, hand adjusting glasses gracefully"
    },
    "ajin": {
        "name": "阿堇",
        "desc": (
            "1girl, solo, 19 years old youthful anime girl, pretty ship cook girl, "
            "deep burgundy red hair tied in a loose bun, carved wooden hairpin, warm amber brown eyes, gentle sweet smile, "
            "warm cream knit turtleneck sweater, rich dark brown canvas tactical chef apron with rolled sleeves"
        ),
        "pose": "upper body, bust shot, warm gentle smile, relaxed shoulders, slight tilt, looking warmly at viewer"
    },
    "xiaoman": {
        "name": "小满",
        "desc": (
            "1girl, solo, 17 years old cute anime girl, tomboyish ace pilot, "
            "deep teal-cyan wolf-cut short hair, sharp golden eyes, cool confident smirk, "
            "sand-colored flight suit, rich dark brown shearling leather bomber jacket with airship patch, vivid orange aviator neck scarf"
        ),
        "pose": "upper body, bust shot, playful confident smirk, head tilted back slightly, dynamic angle looking at viewer"
    },
    "shiori": {
        "name": "诗织",
        "desc": (
            "1girl, solo, 17 years old cute anime girl, delicate melancholic teenage researcher, "
            "silky snow-white long hair, glowing vivid amethyst purple eyes, quiet thoughtful gaze, "
            "crisp white lab coat with charred scorched edges, dark charcoal grey techwear radiation suit, "
            "silver ID badge at collar, iridescent mechanical beetle on shoulder"
        ),
        "pose": "upper body, bust shot, weary calm gaze, quiet melancholic expression, slight off-center framing looking toward viewer"
    }
}


def build_graph(char_key: str, seed: int):
    c = CHARACTERS[char_key]
    width, height = 832, 1216
    positive = f"{NECO_STYLE_PREFIX}, {c['desc']}, {c['pose']}, {LIP_CONSTRAINTS}, {BACKDROP}"

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
                "cfg": 3.3,
                "sampler_name": "euler",
                "scheduler": "sgm_uniform",
                "denoise": 1.0,
            }
        },
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": f"neco_{char_key}"}},
    }
    return g


def generate(char_key: str, seed: int, out_path: str, timeout: int = 600):
    host = get_host()
    g = build_graph(char_key, seed)
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

    print(f"[{char_key}] Submitted prompt_id: {prompt_id}, seed: {seed}")
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
                            "char": char_key,
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
    parser = argparse.ArgumentParser(description="生成 neco 画风角色人设图")
    parser.add_argument("character", choices=list(CHARACTERS.keys()) + ["all"])
    parser.add_argument("--seed", type=int, default=2026)
    parser.add_argument("--out", help="输出路径")
    args = parser.parse_args()

    targets = list(CHARACTERS.keys()) if args.character == "all" else [args.character]
    for c in targets:
        if args.out and len(targets) == 1:
            out_file = args.out
        else:
            name_cn = CHARACTERS[c]["name"]
            out_file = f"review\\{name_cn}_neco风格.png"
        ok = generate(c, args.seed, out_file)
        if not ok:
            print(f"Failed to generate {c}", file=sys.stderr)


if __name__ == "__main__":
    main()
