# -*- coding: utf-8 -*-
"""
整图重绘：不遮罩，直接把场景图整体喂给 MOSS，中等降噪让场景保留、人物加进左侧。
python moss_ds_shop_i2i.py <seed> <denoise>
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

SCENE = "shop_scene.png"

PROMPT = (
    "16-bit pixel art shop interior of a small underground second-hand store, "
    "closed metal roll-up shutter door in the middle of the back wall, "
    "long counter across the middle filled with junk parts, tools, food cans, "
    "wall-mounted meters, old monitors, cables, a poster on the right wall, "
    "a girl standing on the floor at the left side of the shop, "
    "small figure, whole body visible, standing upright, "
    "seen from the front in a three-quarter view, face clearly visible, "
    "head turned to the right, looking toward the closed roll-up shutter door, "
    "calm neutral expression, arms relaxed at her sides, "
    "DeepseekChan, 16 years old, teenage high school girl, "
    "whale fin ears, gradient blue hair, long hair, ahoge, bright blue eyes, "
    "fair pale skin, lips expressed by a single thin line only, "
    "navy blue long maid dress with floor-length skirt, gold trim, white frills, "
    "white apron with blue whale emblem, black bodice, blue gemstone brooch, "
    "one blue whale tail behind her lower body, white tights, dark shoes, "
    "pixel art, crisp pixel grid, distinct square pixels, no smoothing, "
    "masterpiece, best quality"
)

NEG = (
    "blurry, muddy, smeared, low detail, soft edges, smudged pixels, "
    "head cut off, cropped head, back view, facing away, "
    "two tails, multiple tails, extra fins, "
    "chibi, super deformed, big head, short limbs, oversized head, "
    "tilted body, leaning, crooked figure, "
    "short skirt, miniskirt, bare legs, "
    "lipstick, lip gloss, glossy lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, makeup, "
    "3d, realistic photo, "
    "lowres, worst quality, bad anatomy, extra hands, extra digits, extra limbs, "
    "watermark"
)


def graph(seed: int, denoise: float) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "moss25d_int8.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen35_int8.safetensors", "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2vae.safetensors"}},
        "11": {"class_type": "LoraLoader", "inputs": {
            "model": ["1", 0], "clip": ["2", 0], "lora_name": "moss_pixelart_v03.safetensors",
            "strength_model": 0.9, "strength_clip": 0.9}},
        "12": {"class_type": "LoraLoader", "inputs": {
            "model": ["11", 0], "clip": ["11", 1], "lora_name": "deepseekchan_moss.safetensors",
            "strength_model": 0.7, "strength_clip": 0.7}},
        "6": {"class_type": "SkipLayerGuidanceDiTSimple", "inputs": {
            "model": ["12", 0], "double_layers": "", "single_layers": "22",
            "start_percent": 0.0, "end_percent": 1.0}},
        "20": {"class_type": "LoadImage", "inputs": {"image": SCENE}},
        "21": {"class_type": "VAEEncode", "inputs": {"pixels": ["20", 0], "vae": ["3", 0]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": PROMPT}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEG}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["21", 0],
            "seed": seed, "steps": 50, "cfg": 3.5,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": denoise}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "shop_i2i"}},
    }


if __name__ == "__main__":
    seed = int(sys.argv[1])
    denoise = float(sys.argv[2])
    payload = json.dumps({"prompt": graph(seed, denoise), "client_id": "shop_i2i"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("PROMPT_ID=" + str(resp.get("prompt_id")))
