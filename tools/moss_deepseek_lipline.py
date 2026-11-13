# -*- coding: utf-8 -*-
"""
单张出图：DeepSeek 娘 16 岁胸像，中性表情。
唇部只用线条表现，禁止任何颜色填充与阴影。
"""
import json
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

PROMPT = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, chunky pixel blocks, "
    "clean grid-aligned pixels, distinct square pixels, "
    "close-up bust shot, head and shoulders, face large in frame, "
    "three-quarter view, body angled three-quarter, head turned to the right, "
    "looking toward the right side of the frame, "
    "bright color palette, high-key lighting, light airy tones, clear bright highlights, "
    "masterpiece, best quality, 1girl, solo, "
    "DeepseekChan, 16 years old, teenage high school girl, youthful teenage face, "
    "soft jawline, graceful slim cheeks, large expressive eyes, soft thin eyebrows, small nose, "
    "fair pale skin, porcelain complexion, "
    "lips expressed by a single thin line only, lip line only, no color fill on lips, "
    "no lip shading, no lip highlight, bare lips, no makeup, bare face, "
    "thin single dark pixel line for the mouth, "
    "whale fin ears, gradient hair, long hair, ahoge, blue eyes, "
    "long navy blue maid dress, gold trim, frills, white apron, "
    "blue gemstone brooch, blue whale emblem, "
    "pure solid black background, pitch black minimalist background"
)

NEG = (
    "lipstick, lipstick, lip gloss, lip gloss, glossy lips, glossy lips, shiny lips, "
    "wet lips, wet lips, colored lips, red lips, pink lips, peach lips, coral lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, lip color, "
    "lip tint, lip balm, lip highlight, lip gloss reflection, lip volume, plump lips, "
    "makeup, cosmetics, blush on lips, "
    "mature face, adult facial proportions, sharp jawline, angular face, "
    "heavy eyebrows, thick eyebrows, narrow eyes, small eyes, "
    "aged face, wrinkles, nasolabial folds, thirty years old, "
    "tanned skin, dark skin, ruddy complexion, "
    "dark heavy shadows, murky colors, low key lighting, gloomy, "
    "front view, facing left, looking left, "
    "full body, full figure, standing, wide shot, small figure, "
    "dress hem, shoes, feet, legs, knees, waist visible, "
    "short skirt, miniskirt, bare legs, thighhighs, cleavage, voluptuous, "
    "id photo, passport photo, mugshot, symmetrical, rigid pose, stiff pose, "
    "centered headshot, formal portrait, glowing eyes, "
    "3d, realistic photo, photograph, dslr, blurry, anti-aliased, "
    "lowres, worst quality, bad anatomy, bad hands, extra digits, watermark, text"
)

SEED = 8809101


def graph() -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "moss25d_int8.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen35_int8.safetensors", "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2vae.safetensors"}},
        "11": {"class_type": "LoraLoader", "inputs": {
            "model": ["1", 0], "clip": ["2", 0], "lora_name": "moss_pixelart_v03.safetensors",
            "strength_model": 1.0, "strength_clip": 1.0}},
        "12": {"class_type": "LoraLoader", "inputs": {
            "model": ["11", 0], "clip": ["11", 1], "lora_name": "deepseekchan_moss.safetensors",
            "strength_model": 0.7, "strength_clip": 0.7}},
        "6": {"class_type": "SkipLayerGuidanceDiTSimple", "inputs": {
            "model": ["12", 0], "double_layers": "", "single_layers": "22",
            "start_percent": 0.0, "end_percent": 1.0}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": PROMPT}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEG}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["7", 0],
            "seed": SEED, "steps": 50, "cfg": 3.0,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "deepseekchan_lip_line"}},
    }


if __name__ == "__main__":
    payload = json.dumps({"prompt": graph(), "client_id": "deepseek_lipline"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("PROMPT_ID=" + str(resp.get("prompt_id")))
