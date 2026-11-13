# -*- coding: utf-8 -*-
"""
9:16 竖版全身，直接文生图。图生图改画幅会让模型按半身参考瞎推比例，改回文生图。
python moss_deepseek_full916_t2i.py <seed> <denoise 忽略，固定 1.0>
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

W, H = 864, 1536

PROMPT = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, chunky pixel blocks, "
    "clean grid-aligned pixels, distinct square pixels, "
    "vertical full body portrait, standing upright and straight, figure perfectly vertical, "
    "whole body visible from head to feet, centered on the vertical axis, "
    "eight head proportions, slender teenage build, normal body proportions, "
    "bright color palette, high-key lighting, light airy tones, "
    "masterpiece, best quality, 1girl, solo, "
    "DeepseekChan, 16 years old, teenage high school girl, "
    "delicate beautiful face, refined facial features, bright expressive eyes, "
    "fair pale skin, porcelain complexion, "
    "lips expressed by a single thin line only, lip line only, no color fill on lips, "
    "navy blue long maid dress with floor-length skirt reaching the ankles, "
    "gold trim, white frills at the hem, white apron with blue whale emblem, "
    "black bodice with gold clasp, white ruffled cuffs, "
    "blue gemstone brooch at the collar, whale fin ears, gradient hair, long hair, ahoge, "
    "blue whale tail behind her lower body, white tights, simple dark shoes, "
    "arms relaxed at her sides, calm neutral expression, "
    "pure solid black background, pitch black minimalist background"
)

NEG = (
    "chibi, super deformed, big head, short limbs, tiny body, oversized head, "
    "child proportions, toddler proportions, "
    "tilted body, leaning, diagonal pose, crooked figure, off-center, rotated body, "
    "close-up, bust shot, cropped body, cut off legs, half body, portrait crop, "
    "short skirt, miniskirt, knee length skirt, bare legs, "
    "missing apron, outfit redesign, different collar, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, makeup, "
    "mature face, adult facial proportions, sharp jawline, angular face, "
    "heavy eyebrows, thick eyebrows, tanned skin, dark skin, "
    "dark heavy shadows, murky colors, gloomy, "
    "3d, realistic photo, blurry, anti-aliased, "
    "lowres, worst quality, bad anatomy, extra hands, extra digits, extra limbs, "
    "watermark, text"
)


def graph(seed: int) -> dict:
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
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": W, "height": H, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["7", 0],
            "seed": seed, "steps": 50, "cfg": 3.0,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "deepseekchan_t2i916"}},
    }


if __name__ == "__main__":
    seed = int(sys.argv[1])
    payload = json.dumps({"prompt": graph(seed), "client_id": "ds_t2i916"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("PROMPT_ID=" + str(resp.get("prompt_id")))
