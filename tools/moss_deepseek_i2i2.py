# -*- coding: utf-8 -*-
"""
图生图单张（可指定底图）：python moss_deepseek_i2i2.py <底图> <表情> <种子> <denoise>
底图已存在于 ComfyUI input 目录。
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

STYLE = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, chunky pixel blocks, "
    "clean grid-aligned pixels, distinct square pixels, "
    "close-up bust shot, head and shoulders, face large in frame, "
    "three-quarter view, body angled three-quarter, head turned to the right, "
    "bright color palette, high-key lighting, light airy tones, "
    "masterpiece, best quality, 1girl, solo, "
    "DeepseekChan, 16 years old, teenage high school girl, "
    "delicate beautiful face, refined facial features, bright expressive eyes, "
    "fair pale skin, porcelain complexion, "
    "lips expressed by a single thin line only, lip line only, no color fill on lips, "
    "keep the exact same outfit, same navy blue maid dress, same gold trim, "
    "same frills, same white apron with blue whale emblem, same blue gemstone brooch, "
    "same whale fin ears, same gradient hair, same ahoge, "
    "pure solid black background"
)

NEG = (
    "different outfit, changed clothes, different dress, different collar, "
    "different brooch, different apron, missing apron, outfit redesign, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, "
    "lip tint, lip highlight, plump lips, makeup, cosmetics, "
    "mature face, adult facial proportions, sharp jawline, angular face, "
    "heavy eyebrows, thick eyebrows, narrow eyes, "
    "aged face, wrinkles, thirty years old, "
    "tanned skin, dark skin, "
    "dark heavy shadows, murky colors, gloomy, "
    "front view, facing left, "
    "full body, wide shot, small figure, "
    "short skirt, bare legs, thighhighs, cleavage, "
    "3d, realistic photo, blurry, anti-aliased, "
    "lowres, worst quality, bad anatomy, extra digits, watermark, text"
)

EXPR = {
    "neutral": ", calm composed neutral expression, mouth line straight and level, "
               "serene steady gaze toward the right, relaxed face",
    "smile": ", warm natural smile reaching the eyes, mouth line smoothly curved upward, "
             "eyes softly curved with gentle warmth, looking to the right",
}


def graph(base_img: str, seed: int, name: str, denoise: float) -> dict:
    prompt = "%s%s" % (STYLE, EXPR[name])
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
        "20": {"class_type": "LoadImage", "inputs": {"image": base_img}},
        "21": {"class_type": "VAEEncode", "inputs": {"pixels": ["20", 0], "vae": ["3", 0]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": prompt}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEG}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["21", 0],
            "seed": seed, "steps": 50, "cfg": 3.0,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": denoise}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "deepseekchan_i2i2_%s" % name}},
    }


if __name__ == "__main__":
    base_img = sys.argv[1]
    name = sys.argv[2]
    seed = int(sys.argv[3])
    denoise = float(sys.argv[4])
    payload = json.dumps({"prompt": graph(base_img, seed, name, denoise), "client_id": "deepseek_i2i2"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("%s PROMPT_ID=%s" % (name, resp.get("prompt_id")))
