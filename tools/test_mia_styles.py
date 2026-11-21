# -*- coding: utf-8 -*-
"""针对米娅进行 4 组去 AI 味画风横向对比测试（固定角色与服饰，只变画风与采样参数）。"""

import json
import os
import sys
import time
import urllib.request
import uuid

HOST_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_host.txt")


def get_host():
    with open(HOST_FILE, "r", encoding="utf-8") as f:
        return f.read().strip().rstrip("/")


QUALITY_META_YEAR = "masterpiece, best quality, absurdres, highres, newest, year 2025, 1girl, solo"

MIA_CHAR = (
    "16 years old cute anime girl, youthful delicate face, "
    "dark wine-red slightly tousled hair tied in neat low twin buns with thin matte-bronze hairpins, "
    "drowsy half-lidded muted warm amber eyes, quiet sleepy expression, "
    "matte charcoal-black high-collar military field jacket worn cleanly on both shoulders over a plain dark-crimson utility vest and black turtleneck, "
    "small neat silver wing-gear patch on sleeve, "
    "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the left, "
    "looking at viewer at eye level, off-center framing, "
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips, "
    "pure solid black background, pitch black minimalist background"
)

COMMON_NEG = (
    "glowing eyes, glowing pupils, neon eyes, laser eyes, shiny plastic, glossy leather, latex, bodysuit, plugsuit, "
    "overly detailed armor, excessive straps, cluttered buckles, tactical greebles, off-shoulder, bare shoulders, cleavage, "
    "mature face, adult woman, long jaw, sharp angular chin, aging, wrinkles, milf, "
    "pixel art, 3d, 3d render, realistic photo, photograph, dslr, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, filled lips, painted lips, lip shading, makeup, "
    "id photo, front view, rigid pose, symmetrical, centered headshot, "
    "lowres, worst quality, low quality, bad anatomy, bad hands, watermark, text"
)

STYLES = {
    "s4_restore": {
        "label": "4号画师串原配方(CFG3.0)",
        "artists": "@redjuice, @oguchi, @lack, @miv4t, @toosaka asagi",
        "style": "anime coloring, 2d illustration, sharp mechanical lineart, bold cinematic dark shadows, high contrast lighting",
        "neg": "washed out, faded, pale colors, overexposed, hazy"
    },
    "painterly_tactical": {
        "label": "干练厚涂军武原画风",
        "artists": "@liduke, @lm7, @neco, @chuzenji, @alchemaniac",
        "style": "2d illustration, painterly brushwork, dry matte texture, crisp ink lineart, muted gritty color palette, hard directional shadows, subtle rim light",
        "neg": "airbrushed, plastic skin, glossy, soft gradient shading, generic moe, pastel, washed out"
    },
    "hard_cel_ink": {
        "label": "硬朗墨线赛璐璐风",
        "artists": "@yoneyama mai, @huke, @oguchi, @lack, @rei (sanbonzakura)",
        "style": "2d illustration, hard cel shading, sharp ink linework, graphic shadow shapes, dry matte finish, crisp angular folds, high contrast",
        "neg": "airbrushed, soft gradient shading, plastic sheen, 3d shading, glossy highlights, blurry shadows"
    },
    "ba_genga_clean": {
        "label": "二游主美手绘平涂风",
        "artists": "@hwansang, @doremi (doremifa), @mx2j, @ask (askzy), @neco",
        "style": "2d illustration, clean anime key visual, crisp thin lineart, clean flat cel coloring, subtle natural shadows, understated matte finish",
        "neg": "halo, angel halo, airbrushed, plastic sheen, heavy 3d rendering, shiny skin, glossy"
    },
    "ba_lora_65": {
        "label": "蔚蓝档案LoRA融合画师串(0.65)",
        "artists": "@ba nai, blue archive style, @hwansang, @doremi (doremifa), @mx2j, @neco",
        "style": "2d illustration, clean crisp anime lineart, vibrant clear cel coloring, soft natural shadows, modern character concept art",
        "neg": "halo, angel halo, pastel, washed out, airbrushed, plastic sheen, shiny skin, heavy 3d rendering",
        "lora": "ba_style_moss_uma_v1_1000.safetensors",
        "lora_strength": 0.65,
        "seed": 4096
    },
    "ink_wash_concept": {
        "label": "日系设定集钢笔淡彩厚涂风",
        "artists": "@toi8, @loundraw, @yoneyama mai, @neco, @huke",
        "style": "2d illustration, concept art, expressive ink lineart, dry painterly brushwork, muted realistic palette, textured shading, crisp cast shadows",
        "neg": "airbrushed, smooth plastic skin, glossy, neon, soft gradient shading, generic moe",
        "seed": 4096
    },
}


def run_one(style_key: str, seed: int = 2026):
    s = STYLES[style_key]
    seed = s.get("seed", seed)
    host = get_host()
    positive = f"{QUALITY_META_YEAR}, {s['artists']}, {s['style']}, {MIA_CHAR}"
    negative = f"{COMMON_NEG}, {s['neg']}"

    g = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "moss_image_sft_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3.5_9b_w4a8_gptq.safetensors", "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae_small.safetensors"}},
        "6": {"class_type": "SkipLayerGuidanceDiTSimple", "inputs": {"model": ["1", 0], "double_layers": "", "single_layers": "22", "start_percent": 0.0, "end_percent": 1.0}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": positive}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": negative}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 832, "height": 1216, "batch_size": 1}},
        "8": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["6", 0],
                "positive": ["4", 0],
                "negative": ["5", 0],
                "latent_image": ["7", 0],
                "seed": seed,
                "steps": 50,
                "cfg": 3.0,
                "sampler_name": "euler",
                "scheduler": "sgm_uniform",
                "denoise": 1.0,
            }
        },
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": f"miastyle_{style_key}"}},
    }
    if s.get("lora"):
        g["11"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["2", 0],
                "lora_name": s["lora"],
                "strength_model": s.get("lora_strength", 0.65),
                "strength_clip": s.get("lora_strength", 0.65),
            }
        }
        g["6"]["inputs"]["model"] = ["11", 0]
        g["4"]["inputs"]["clip"] = ["11", 1]
        g["5"]["inputs"]["clip"] = ["11", 1]

    payload = json.dumps({"prompt": g, "client_id": str(uuid.uuid4())}).encode("utf-8")
    req = urllib.request.Request(f"{host}/prompt", data=payload, headers={"Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=30) as resp:
        prompt_id = json.loads(resp.read().decode("utf-8"))["prompt_id"]
    print(f"[{style_key}] submitted {prompt_id}", flush=True)

    deadline = time.time() + 400
    while time.time() < deadline:
        time.sleep(3)
        try:
            with urllib.request.urlopen(f"{host}/history/{prompt_id}", timeout=10) as r:
                hist = json.loads(r.read().decode("utf-8")).get(prompt_id, {})
                outputs = hist.get("outputs", {})
                if outputs:
                    imgs = [i for v in outputs.values() for i in v.get("images", [])]
                    if imgs:
                        im = imgs[0]
                        url = f"{host}/view?filename={im['filename']}&subfolder={im.get('subfolder','')}&type={im.get('type','output')}"
                        data = urllib.request.urlopen(url, timeout=60).read()
                        out_path = os.path.join("review", f"米娅_画风测试_{style_key}.png")
                        os.makedirs("review", exist_ok=True)
                        with open(out_path, "wb") as f:
                            f.write(data)
                        print(f"[{style_key}] saved {out_path} ({round(time.time()-t0,1)}s)", flush=True)
                        return True
        except Exception:
            continue
    return False


if __name__ == "__main__":
    keys = sys.argv[1:] if len(sys.argv) > 1 else list(STYLES.keys())
    for k in keys:
        run_one(k)
