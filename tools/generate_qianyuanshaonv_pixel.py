"""潜渊少女现代独立游戏像素风角色立绘生成器。

基于 MOSS-Image 2.5D DiT、Qwen3.5 文本编码器与 MOSS Pixel Art LoRA，
输出标准 16-bit 独立游戏对齐像素精灵图，使用纯黑背景与非对称微动态构图。
"""

import argparse
import json
import os
import random
import shutil
import sys
import time
import urllib.request

COMFY_HOST = os.environ.get("COMFY_HOST", "http://127.0.0.1:8188")
DRIVE_OUTPUT_DIR = "/content/drive/MyDrive/MOSS_动漫"

STYLE_PREFIX = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, "
    "clean grid-aligned pixels, distinct square pixels, "
    "upper body, bust shot, three-quarter view, dynamic angle, off-center"
)

STYLE_SUFFIX = "pure solid black background, pitch black minimalist background"

NEGATIVE_STYLE = (
    "id photo, passport photo, mugshot, front view, symmetrical, rigid pose, stiff pose, "
    "standing at attention, perfect symmetry, centered headshot, formal portrait, "
    "angry, fierce, scowl, glowing eyes, glowing pupils, laser eyes, bright red glare, "
    "smile, grinning, open mouth, laughing, full body, lower body, legs, "
    "complex background, city, street, neon, smooth, vector, 3d, realistic photo, "
    "blurry, anti-aliased, dslr, painting, gradient"
)

CHARACTERS = {
    "nao": {
        "name": "奈绪 (nao)",
        "lookTags": (
            "1girl, solo, cute anime girl, adorable kuudere, long ash silver hair, "
            "soft wispy bangs, delicate hair clips, pale muted crimson eyes, soft pale red pupils, non-glowing natural eyes, "
            "black tactical techwear jacket with collar, small chest rig straps, wing emblem on chest"
        ),
        "default_pose": "body and face naturally aligned facing slightly to the right, looking at viewer at eye level, calm quiet gaze"
    },
    "mia": {
        "name": "米娅 (mia)",
        "lookTags": (
            "1girl, solo, cute anime mechanic girl, light flaxen curly short hair, "
            "goggles on head, golden eyes, work overalls, white tank top, smudge on cheek"        ),
        "default_pose": "body and face naturally aligned facing slightly to the right, looking at viewer at eye level, cheerful energetic gaze"
    },
    "rei": {
        "name": "零 (rei)",
        "lookTags": (
            "1girl, solo, silver-white hair, bob cut, straight bob hair, bangs covering one eye, "
            "ice blue eyes, tall slender, high-collar tactical suit, dark green camouflage capelet, "
            "rangefinder on chest, fingerless gloves, dog tags"
        ),
        "default_pose": "quiet deadpan stare, slight 3/4 turn, asymmetrical shoulders, looking at viewer, hand touching capelet strap"
    },
    "kurumi": {
        "name": "胡桃 (kurumi)",
        "lookTags": (
            "1girl, solo, chestnut brown twin tails, yellow cable ties, bright green eyes, "
            "nose bandage, petite 152cm, orange and grey fireproof overalls, black long sleeves, "
            "goggles on head"
        ),
        "default_pose": "energetic slight smirk, tilted head, lively gaze at viewer, casual natural bust posture"
    },
    "lina": {
        "name": "莉娜 (lina)",
        "lookTags": (
            "1girl, solo, blonde bob hair, sea blue eyes, thin-rimmed glasses, "
            "navy bridge officer shirt, dark grey trousers, military capelet over shoulders, "
            "single-ear comms headset, metal clipboard"
        ),
        "default_pose": "calm intellectual expression, slight side glance at viewer, hand adjusting glasses"
    },
    "ajin": {
        "name": "阿堇 (ajin)",
        "lookTags": (
            "1girl, solo, burgundy hair in loose bun, wooden hairpin, warm brown eyes, "
            "gentle smile, 166cm, cream turtleneck sweater, khaki trousers, thick canvas chef apron, "
            "rolled sleeves, ladle"
        ),
        "default_pose": "warm gentle smile, relaxed shoulders, slight tilt, looking warmly at viewer"
    },
    "xiaoman": {
        "name": "小满 (xiaoman)",
        "lookTags": (
            "1girl, solo, messy dark teal wolf-cut short hair, golden eyes, smirk, "
            "160cm, sand-colored flight suit, brown shearling leather flight jacket, "
            "aviator helmet with goggles, orange scarf"
        ),
        "default_pose": "playful smirk, head tilted back slightly, confident dynamic angle looking at viewer"
    },
    "captain": {
        "name": "舰长 (captain)",
        "lookTags": (
            "1girl, solo, mature woman, long black hair in low ponytail, silver streaks, "
            "dark grey eyes, tall 172cm, charcoal double-breasted captain coat, silver epaulets, "
            "black gloves, wooden cane"
        ),
        "default_pose": "dignified sharp stare, commanding 3/4 posture, one gloved hand resting on cane handle"
    },
    "shiori": {
        "name": "诗织 (shiori)",
        "lookTags": (
            "1girl, solo, long pale white hair, purple eyes, slender 164cm, "
            "tattered white lab coat over dark grey radiation suit, scorched metal ID badge at collar, "
            "small mechanical beetle on shoulder"
        ),
        "default_pose": "weary calm gaze, quiet melancholic expression, slight off-center framing looking toward viewer"
    }
}


def api_request(endpoint, payload=None, timeout=60):
    url = COMFY_HOST.rstrip("/") + endpoint
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {"Content-Type": "application/json"}
    req = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def build_workflow(positive_text, negative_text, seed, prefix="abyss_pixel"):
    return {
        "1": {
            "class_type": "UNETLoader",
            "inputs": {
                "unet_name": "moss25d_int8.safetensors",
                "weight_dtype": "default"
            }
        },
        "2": {
            "class_type": "CLIPLoader",
            "inputs": {
                "clip_name": "qwen35_int8.safetensors",
                "type": "moss_image",
                "device": "default"
            }
        },
        "3": {
            "class_type": "VAELoader",
            "inputs": {
                "vae_name": "flux2vae.safetensors"
            }
        },
        "11": {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["2", 0],
                "lora_name": "moss_pixelart_v03.safetensors",
                "strength_model": 1.0,
                "strength_clip": 1.0
            }
        },
        "6": {
            "class_type": "SkipLayerGuidanceDiTSimple",
            "inputs": {
                "model": ["11", 0],
                "double_layers": "",
                "single_layers": "22",
                "start_percent": 0.0,
                "end_percent": 1.0
            }
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["11", 1],
                "text": positive_text
            }
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["11", 1],
                "text": negative_text
            }
        },
        "7": {
            "class_type": "EmptySD3LatentImage",
            "inputs": {
                "width": 1024,
                "height": 1024,
                "batch_size": 1
            }
        },
        "8": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["6", 0],
                "positive": ["4", 0],
                "negative": ["5", 0],
                "latent_image": ["7", 0],
                "seed": seed,
                "steps": 50,
                "cfg": 3.4,
                "sampler_name": "euler",
                "scheduler": "sgm_uniform",
                "denoise": 1.0
            }
        },
        "9": {
            "class_type": "VAEDecode",
            "inputs": {
                "samples": ["8", 0],
                "vae": ["3", 0]
            }
        },
        "10": {
            "class_type": "SaveImage",
            "inputs": {
                "images": ["9", 0],
                "filename_prefix": prefix
            }
        }
    }


def generate_character(char_id, custom_pose=None, seed=-1, count=1):
    char_info = CHARACTERS.get(char_id.lower())
    if not char_info:
        raise ValueError(f"未知角色 ID: {char_id}，可用角色: {list(CHARACTERS.keys())}")

    pose_text = custom_pose if custom_pose else char_info["default_pose"]
    pos_prompt = f"{STYLE_PREFIX}, {char_info['lookTags']}, {pose_text}, {STYLE_SUFFIX}"
    neg_prompt = NEGATIVE_STYLE

    results = []
    for i in range(count):
        actual_seed = seed if seed >= 0 else random.randint(1, 2147483647)
        prefix = f"abyss_pixel_{char_id}"
        wf = build_workflow(pos_prompt, neg_prompt, actual_seed, prefix)

        res = api_request("/prompt", {"prompt": wf, "client_id": "abyss-generator"})
        pid = res["prompt_id"]
        print(f"[{char_id}] 任务已提交: {pid} (种子: {actual_seed})")

        while True:
            q = api_request("/queue")
            running = len(q.get("queue_running", []))
            pending = len(q.get("queue_pending", []))
            if running == 0 and pending == 0:
                break
            time.sleep(3)

        hist = api_request(f"/history/{pid}")
        outputs = hist.get(pid, {}).get("outputs", {})
        for _, out in outputs.items():
            for img in out.get("images", []):
                fn = img["filename"]
                src_path = os.path.join("/content/ComfyUI/output", fn)
                if os.path.exists(DRIVE_OUTPUT_DIR) and os.path.exists(src_path):
                    dst_path = os.path.join(DRIVE_OUTPUT_DIR, fn)
                    shutil.copy(src_path, dst_path)
                    print(f"[{char_id}] 同步保存至云盘: {dst_path}")
                results.append({"filename": fn, "seed": actual_seed, "character": char_id})

    return results


def main():
    parser = argparse.ArgumentParser(description="潜渊少女现代独立游戏像素风角色立绘生成器")
    parser.add_argument("--character", "-c", required=True, choices=list(CHARACTERS.keys()) + ["all"],
                        help="角色标识 (nao, rei, kurumi, lina, laojiao, ajin, xiaoman, captain, shiori, all)")
    parser.add_argument("--pose", "-p", default=None, help="覆盖角色的默认动作与表情提示词")
    parser.add_argument("--seed", "-s", type=int, default=-1, help="随机种子，默认 -1 随机")
    parser.add_argument("--count", "-n", type=int, default=1, help="每个角色生成张数")
    args = parser.parse_args()

    chars_to_run = list(CHARACTERS.keys()) if args.character == "all" else [args.character]
    total_results = []
    for cid in chars_to_run:
        res = generate_character(cid, args.pose, args.seed, args.count)
        total_results.extend(res)

    print(json.dumps(total_results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
