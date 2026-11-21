# -*- coding: utf-8 -*-
"""潜渊少女二次元动漫角色人设图生成器 (浓郁色彩与高对比度画风版)。

针对颜色偏淡与泛白问题进行全面升级：
1. 降低蔚蓝档案 LoRA 权重至 0.38（仅保留五官比例，消除其泛白滤镜）
2. 注入高对比度、浓郁饱和度动漫上色画风提示词（vibrant anime coloring, rich deep contrast, bold clean lineart）
3. 负向全面压制 faded, washed out, pale colors, hazy, milky 等褪色特征
4. 严格保持 16-19 岁青春少女面容与无唇彩细单线铁律。
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


# 强对比、高饱和、浓郁鲜明的纯正二次元动漫插画画风提示词
STYLE_PROMPT = (
    "masterpiece, best quality, absurdres, highres, anime style, vibrant anime coloring, "
    "rich vivid colors, high contrast, deep rich shadows, bold clean lineart, colorful anime key visual, "
    "dynamic anime lighting, beautiful delicate anime girl, youthful teenage face, cute soft cheeks, "
    "youthful teenage charm, slender young girl body"
)

LIP_CONSTRAINTS = (
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips"
)

BACKDROP = "pure solid black background, pitch black minimalist background"

# 强力压制褪色、泛白、低对比度、白雾灰蒙感
NEGATIVE_PROMPT = (
    "washed out, faded, pale colors, desaturated, low contrast, overexposed, hazy, foggy, white haze, milky, "
    "dull colors, grayscale, monochrome, flat lighting, dim, muddy colors, "
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
    "nao": {
        "name": "奈绪",
        "age": 16,
        "desc": (
            "1girl, solo, 16 years old cute anime girl, adorable kuudere, youthful delicate face, pretty soft teenage features, "
            "long ash silver hair, soft wispy bangs, silver star-wing hair clips, pale muted crimson eyes, calm gentle gaze, "
            "jet black tactical techwear jacket with high collar, small chest rig straps, vibrant silver wing sword emblem on chest"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, off-center framing"
    },
    "rei": {
        "name": "零",
        "age": 17,
        "desc": (
            "1girl, solo, 17 years old cute anime girl, slender teenage tactical girl, youthful pretty face, "
            "silver-white straight bob hair, bangs covering one eye, deep vivid ice blue eyes, quiet calm gaze, "
            "jet black high-collar tactical suit, rich dark forest green camouflage capelet over shoulders, "
            "rangefinder on chest, polished silver dog tags, black fingerless tactical gloves"
        ),
        "pose": "upper body, bust shot, quiet calm stare, slight 3/4 turn, asymmetrical shoulders, looking at viewer, hand touching capelet strap"
    },
    "mia": {
        "name": "米娅",
        "age": 17,
        "desc": (
            "1girl, solo, 17 years old cute anime mechanic girl, youthful face, light flaxen golden curly short hair, "
            "head-mounted mechanic goggles with brass rims, brilliant amber golden eyes, cheerful radiant smile, "
            "clean white tank top, deep indigo denim work overalls with yellow accents, cute grease smudge on cheek"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, cheerful energetic gaze"
    },
    "kurumi": {
        "name": "胡桃",
        "age": 16,
        "desc": (
            "1girl, solo, 16 years old cute anime girl, youthful cheerful teenage girl, "
            "rich chestnut brown twin tails with vivid yellow cable ties, bright vibrant emerald green eyes, "
            "small bandage on nose bridge, protective yellow goggles on head, "
            "vibrant safety orange and dark grey fireproof overalls, black long sleeve undershirt"
        ),
        "pose": "upper body, bust shot, energetic slight smirk, tilted head, lively gaze at viewer, casual natural bust posture"
    },
    "lina": {
        "name": "莉娜",
        "age": 18,
        "desc": (
            "1girl, solo, 18 years old cute anime girl, youthful student tactician, delicate pretty face, "
            "radiant golden blonde bob hair, deep rich sapphire blue eyes, thin-rimmed silver glasses, intellectual calm expression, "
            "rich navy blue bridge officer shirt with gold trim, dark military capelet over shoulders, single-ear comms headset, silver clipboard"
        ),
        "pose": "upper body, bust shot, calm intellectual expression, slight side glance at viewer, hand adjusting glasses gracefully"
    },
    "ajin": {
        "name": "阿堇",
        "age": 19,
        "desc": (
            "1girl, solo, 19 years old youthful anime girl, pretty ship cook girl, youthful soft face, "
            "deep burgundy red hair tied in a loose bun, carved wooden hairpin, warm amber brown eyes, gentle sweet smile, "
            "warm cream knit turtleneck sweater, rich dark brown canvas chef apron with rolled sleeves"
        ),
        "pose": "upper body, bust shot, warm gentle smile, relaxed shoulders, slight tilt, looking warmly at viewer"
    },
    "xiaoman": {
        "name": "小满",
        "age": 17,
        "desc": (
            "1girl, solo, 17 years old cute anime girl, tomboyish teenage pilot, youthful face, "
            "deep teal-cyan wolf-cut short hair, brilliant golden eyes, playful confident smirk, "
            "sand-colored flight suit, rich dark brown shearling leather bomber jacket with yellow airship patch, vivid orange aviator neck scarf"
        ),
        "pose": "upper body, bust shot, playful confident smirk, head tilted back slightly, dynamic angle looking at viewer"
    },
    "shiori": {
        "name": "诗织",
        "age": 17,
        "desc": (
            "1girl, solo, 17 years old cute anime girl, delicate melancholic teenage researcher, youthful face, "
            "silky snow-white long hair, glowing vivid amethyst purple eyes, quiet thoughtful expression, "
            "crisp white lab coat with charred scorched edges, dark charcoal grey techwear radiation suit, silver ID badge at collar, "
            "iridescent mechanical beetle on shoulder"
        ),
        "pose": "upper body, bust shot, weary calm gaze, quiet melancholic expression, slight off-center framing looking toward viewer"
    }
}


def build_graph(char_key: str, seed: int):
    c = CHARACTERS[char_key]
    width, height = 832, 1216
    positive = f"{STYLE_PROMPT}, {c['desc']}, {c['pose']}, {LIP_CONSTRAINTS}, {BACKDROP}"

    # LoRA 权重收敛至 0.38：消除其自带的泛白马卡龙滤镜，全面释放底模的深邃高饱和与强对比度表现力
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
                "strength_model": 0.38,
                "strength_clip": 0.38,
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
                "cfg": 3.2,
                "sampler_name": "euler",
                "scheduler": "sgm_uniform",
                "denoise": 1.0,
            }
        },
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": f"vivid_{char_key}"}},
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
        print(f"Failed to submit to {host}: {e}", file=sys.stderr)
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
    print(f"[{char_key}] Timeout waiting for output", file=sys.stderr)
    return False


def main():
    parser = argparse.ArgumentParser(description="生成高饱和浓郁色彩二次元人设图")
    parser.add_argument("character", choices=list(CHARACTERS.keys()) + ["all"])
    parser.add_argument("--seed", type=int, default=-1)
    parser.add_argument("--out", help="输出路径")
    args = parser.parse_args()

    targets = list(CHARACTERS.keys()) if args.character == "all" else [args.character]
    for c in targets:
        s = args.seed if args.seed >= 0 else random.randint(1000, 2147483647)
        if args.out and len(targets) == 1:
            out_file = args.out
        else:
            name_cn = CHARACTERS[c]["name"]
            out_file = f"review\\{name_cn}_浓郁色彩人设.png"
        ok = generate(c, s, out_file)
        if not ok:
            print(f"Failed to generate {c}", file=sys.stderr)


if __name__ == "__main__":
    main()
