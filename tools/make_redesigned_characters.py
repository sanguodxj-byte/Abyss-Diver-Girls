# -*- coding: utf-8 -*-
"""《潜渊少女》全员 11 位角色军武厚涂亚人（明日方舟式动物特征）重设生成器。

画风锁定（3 号干练厚涂军武原画风）：
- 画师串：@liduke, @lm7, @neco, @chuzenji, @alchemaniac
- 渲染词：2d illustration, painterly brushwork, dry matte texture, crisp ink lineart,
  muted gritty color palette, hard directional shadows, subtle rim light
- 采样：euler / sgm_uniform / 50 steps / CFG 3.0 / SLG single_layers="22"
- 全员配备不重复的克制动物特征（主角奈绪为兔耳）。
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


QUALITY_META_YEAR = "masterpiece, best quality, absurdres, highres, newest, year 2025, 1girl, solo"

STYLE_3_ARTISTS = "@liduke, @lm7, @neco, @chuzenji, @alchemaniac"

STYLE_3_GENERAL = (
    "2d illustration, painterly brushwork, dry matte texture, crisp ink lineart, "
    "muted gritty color palette, hard directional shadows, subtle rim light"
)

LIP_CONSTRAINTS = (
    "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips"
)

BACKDROP = "pure solid black background, pitch black minimalist background"

BASE_NEGATIVE = (
    "airbrushed, plastic skin, glossy, soft gradient shading, generic moe, pastel, washed out, faded, overexposed, hazy, "
    "glowing eyes, glowing pupils, neon eyes, laser eyes, shiny plastic, glossy leather, latex, bodysuit, plugsuit, "
    "overly detailed armor, excessive straps, cluttered buckles, cluttered accessories, tactical greebles, messy details, "
    "off-shoulder, bare shoulders, cleavage, heavy blush, grey skin, blue skin, "
    "evening gown, ballgown, maid outfit, casual sweater, kimono, cheongsam, lab coat, apron, overalls, "
    "mature face, adult woman, tall mature female, long jaw, sharp angular chin, long horse face, "
    "sunken cheeks, aging, wrinkles, dark circles, milf, middle aged, older woman, "
    "pixel art, 16-bit, chunky pixels, pixelated, 3d, 3d render, realistic photo, photograph, dslr, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, makeup, "
    "id photo, passport photo, mugshot, front view, rigid pose, stiff pose, symmetrical, "
    "standing at attention, perfect symmetry, centered headshot, formal portrait, "
    "lowres, worst quality, low quality, bad anatomy, bad hands, extra digits, fewer digits, "
    "extra limbs, extra ears, four ears, watermark, text"
)

CHARACTERS = {
    "nao": {
        "name": "奈绪",
        "trait": "雪兔·兔耳",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall slender ash-silver rabbit ears on top of head with subtle dark inner ear fur and one ear tip gently angled back, "
            "long ash-silver hair, soft wispy bangs, small silver star-wing hair clip, "
            "pale muted crimson eyes, calm quiet kuudere gaze, "
            "matte jet-black high-collar military tactical jacket worn cleanly on both shoulders, "
            "neat black chest rig straps, crisp silver wing-sword emblem on sleeve"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "brown hair, blue coat, human ears visible, bunny girl suit, headband, fake ears, headband ears"
    },
    "rei": {
        "name": "零",
        "trait": "极地狼·狼耳",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "pointed alert midnight-indigo wolf ears on top of head with pale grey inner fur, "
            "sleek midnight-indigo asymmetric bob hair with crisp bangs, "
            "calm muted pale blue eyes, quiet detached gaze, "
            "matte charcoal-grey high-collar military field parka with hood down and clean white inner collar trim, "
            "single simple black shoulder comms strap, tiny silver ID pin on collar"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the left, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "silver hair, white hair, camouflage, eyepatch, glowing visor, ear crystal, human ears visible, headband"
    },
    "kurumi": {
        "name": "胡桃",
        "trait": "赤狐·狐耳",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall fluffy copper-brown fox ears on top of head with dark charcoal ear tips and pale cream inner fur, "
            "natural copper-brown messy wolf-cut hair tied in a side ponytail with a thin matte black hairclip, "
            "natural muted olive-amber anime eyes, calm steady expression, "
            "matte dark-olive high-collar military field jacket worn fully on both shoulders over a plain charcoal turtleneck, "
            "single neat muted-orange chest strap, small silver compass emblem on sleeve"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "overalls, denim, bandage on nose, twin tails, welding goggles, hard hat, neon orange, neon green eyes, choker, human ears visible, headband"
    },
    "lina": {
        "name": "莉娜",
        "trait": "角鸮·冠羽耳簇",
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "a pair of sculpted plush horned-owl feathered ear-tufts (plumicorns) made of layered ivory-white and warm golden-brown bird feathers rising naturally from the upper sides of her head through her hair, "
            "natural honey-blonde wavy shoulder-length hair with subtle feather-layered tips tied neatly with a dark navy ribbon, "
            "calm muted violet-blue anime eyes, composed earnest gaze, "
            "tailored matte midnight-navy military officer field coat worn cleanly over a crisp ivory tactical shirt and plain dark tie, "
            "small clean silver wing lapel pin"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "ear wings, wing on ear, small wing on head, hairclip wing, feather barrette, glasses, spectacles, microphone, headset, military cap, peaked cap, ruffles, angel halo, cat ears, fox ears"
    },
    "mia": {
        "name": "米娅",
        "trait": "垂耳猫·猫耳",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "relaxed slightly lowered dark wine-red cat ears with soft dark inner fur, "
            "dark wine-red slightly tousled hair tied in neat low twin buns with thin matte-bronze hairpins, "
            "drowsy half-lidded muted warm amber eyes, quiet sleepy expression, "
            "matte charcoal-black high-collar military field jacket worn cleanly on both shoulders over a plain dark-crimson utility vest and black turtleneck, "
            "small neat silver wing-gear patch on sleeve"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the left, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "welding mask, goggles, overalls, denim, grease, wrench, hard hat, corset, choker, collarbone exposed, human ears visible, headband"
    },
    "ajin": {
        "name": "阿堇",
        "trait": "森鹿·鹿角鹿耳",
        "desc": (
            "18 years old cute anime girl, youthful delicate face, "
            "small delicate dark-wooden branched deer antlers rising cleanly from her hair and slender dark deer ears angled gently outward, "
            "soft black long straight hair in a neat half-up braid with a plain dark hairpin, "
            "gentle muted amber-brown eyes, calm composed expression, "
            "matte dark-taupe high-collar military greatcoat draped cleanly over a tidy black tactical shirt with one simple brass collar clasp"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the left, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "apron, chef hat, kitchen utensils, maid outfit, sweater, cheongsam, frog buttons, giant antlers, human ears visible"
    },
    "xiaoman": {
        "name": "小满",
        "trait": "暗猞猁·簇毛耳",
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "sharp sleek jet-black lynx ears on top of head with distinct thin dark ear tufts and muted teal inner fur tint, "
            "jet-black short bob hair with subtle dark teal-green inner streaks, "
            "sharp natural golden-brown anime eyes, cool calm slight smirk, "
            "matte dark-teal sleeveless tactical utility vest worn cleanly over a plain black long-sleeve turtleneck, "
            "simple black leather shoulder strap"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "bomber jacket, leather jacket, fur collar, orange scarf, pilot goggles, shell earrings, human ears visible, headband"
    },
    "shiori": {
        "name": "诗织",
        "trait": "银角盘羊·羊角",
        "desc": (
            "17 years old cute anime girl, youthful delicate face, "
            "slender curved pale silver-grey ram horns swept neatly back from temples and soft drooping pale-grey caprine ears, "
            "pale lavender-grey long straight hair with two thin side braids, "
            "quiet muted violet anime eyes, calm thoughtful gaze, "
            "matte dark-charcoal hooded military rain-poncho coat with hood down over a plain black high-collar shirt, "
            "one small dark metallic beetle brooch pinned cleanly on lapel"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the left, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "white coat, lab coat, glasses, ID badge, clipboard, glowing vials, shoulder armor, giant demon horns"
    },
    "karasu": {
        "name": "鸦",
        "trait": "渡鸦·冠羽与收拢鸦翼",
        "desc": (
            "18 years old cute anime girl, youthful delicate face, "
            "long sleek swept-back dark-charcoal avian head-plume feathers with crisp pale silver-grey and muted crimson-tipped barbs emerging naturally from the upper crown of her hair, "
            "real layered folded dark slate-grey and black raven wings rising neatly behind her shoulders catching crisp cool rim light along the feather edges, "
            "jet-black straight hime-cut hair framing her cheeks, "
            "calm dark ruby-brown anime eyes, stoic composed expression, "
            "tailored matte-black military trench coat with clean single-layer shoulder cape and a simple dark-crimson cord clasp"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "ear wings, wing on ear, feather glued on ear, feather hairclip, apron, blacksmith, hammer, ammo belt, bullet belt, spiky armor, pauldrons, cat ears"
    },
    "nihong": {
        "name": "霓虹",
        "trait": "狞猫·黑簇长耳",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "tall alert dark slate-grey caracal ears on top of head with fine black tufted tips, "
            "dark slate-grey messy short wolf-cut hair with a pale silver front lock and plain black hairclips, "
            "subtle heterochromatic muted-blue and muted-violet anime eyes, relaxed playful slight smirk, "
            "matte dark-grey hooded military anorak jacket with subtle thin cyan zipper trim over a plain white high-collar tee, "
            "tiny matte-black collar comms clip"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the left, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "large headphones, gaming headset, bulky headset, tangled cables, neon glow, human ears visible, headband"
    },
    "gin": {
        "name": "银",
        "trait": "黑龙·细龙角",
        "desc": (
            "16 years old cute anime girl, youthful delicate face, "
            "slender swept-back dark-obsidian dragon horns with subtle muted burgundy ridges emerging cleanly from her hair, "
            "cool pale silver-grey chin-length bob with clean straight bangs, "
            "calm muted burgundy anime eyes, composed cool expression, "
            "tailored matte-black military peacoat with subtle dark-wine collar lining over a plain dark high-collar shirt"
        ),
        "pose": "upper body, bust shot, three-quarter view, body and face naturally aligned facing slightly to the right, looking at viewer at eye level, off-center framing, hands out of frame",
        "extra_neg": "monocle, brass goggles, top hat, steampunk gears, red velvet vest, ruffled jabot, giant demon horns"
    }
}


def build_graph(char_key: str, seed: int):
    c = CHARACTERS[char_key]
    positive = (
        f"{QUALITY_META_YEAR}, {STYLE_3_ARTISTS}, {STYLE_3_GENERAL}, "
        f"{c['desc']}, {c['pose']}, {LIP_CONSTRAINTS}, {BACKDROP}"
    )
    negative = f"{BASE_NEGATIVE}, {c['extra_neg']}"

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
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": f"ak_{char_key}"}},
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
        print(f"Failed to submit {char_key}: {e}", file=sys.stderr, flush=True)
        return False

    print(f"[{char_key}] Submitted prompt_id: {prompt_id}, seed: {seed}", flush=True)
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
                        }, ensure_ascii=False), flush=True)
                        return True
        except Exception:
            continue
    return False


def main():
    parser = argparse.ArgumentParser(description="生成全员 11 位军武厚涂亚人（明日方舟式动物特征）立绘")
    parser.add_argument("characters", nargs="+", choices=list(CHARACTERS.keys()) + ["all"])
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()

    targets = list(CHARACTERS.keys()) if "all" in args.characters else args.characters
    for idx, c in enumerate(targets):
        name_cn = CHARACTERS[c]["name"]
        out_file = f"review\\{name_cn}_3号画风_亚人版.png"
        char_seed = args.seed + idx * 17 if len(targets) > 1 else args.seed
        ok = generate(c, char_seed, out_file)
        if not ok:
            print(f"Failed to generate {c}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()
