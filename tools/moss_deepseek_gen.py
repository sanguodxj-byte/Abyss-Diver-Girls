# -*- coding: utf-8 -*-
"""
用 MOSS-Image 2.5D Anime + 像素画风 LoRA + DeepSeek 娘角色 LoRA 出一批立绘草稿。
提交到 ComfyUI 队列末尾，不打断进行中的 H3 批量任务。
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

UNET = "moss25d_int8.safetensors"
CLIP = "qwen35_int8.safetensors"
VAE = "flux2vae.safetensors"
PIXEL_LORA = "moss_pixelart_v03.safetensors"
CHAR_LORA = "deepseekchan_moss.safetensors"

W, H, STEPS, CFG = 1024, 1024, 50, 3.0

STYLE = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, clean grid-aligned pixels, "
    "distinct square pixels, upper body, bust shot, three-quarter view, dynamic angle, off-center, "
    "masterpiece, best quality, 1girl, solo"
)

CHAR = (
    "DeepseekChan, whale fin ears, blue whale tail, gradient hair, long hair, ahoge, blue eyes, "
    "navy blue maid dress, gold trim, frills, puffy sleeves, white apron, "
    "blue gemstone brooch, blue whale emblem, white thighhighs"
)

BACKDROP = "pure solid black background, pitch black minimalist background"

NEG = (
    "id photo, passport photo, mugshot, front view, symmetrical, rigid pose, stiff pose, "
    "standing at attention, perfect symmetry, centered headshot, formal portrait, glowing eyes, "
    "glowing pupils, 3d, realistic photo, photograph, dslr, blurry, anti-aliased, "
    "lowres, worst quality, bad anatomy, bad hands, extra digits, watermark, text, "
    "child, loli, underage"
)


def graph(seed: int, prompt: str, char_strength: float) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "11": {"class_type": "LoraLoader", "inputs": {
            "model": ["1", 0], "clip": ["2", 0], "lora_name": PIXEL_LORA,
            "strength_model": 1.0, "strength_clip": 1.0}},
        "12": {"class_type": "LoraLoader", "inputs": {
            "model": ["11", 0], "clip": ["11", 1], "lora_name": CHAR_LORA,
            "strength_model": char_strength, "strength_clip": char_strength}},
        "6": {"class_type": "SkipLayerGuidanceDiTSimple", "inputs": {
            "model": ["12", 0], "double_layers": "", "single_layers": "22",
            "start_percent": 0.0, "end_percent": 1.0}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": prompt}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEG}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": W, "height": H, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["7", 0],
            "seed": seed, "steps": STEPS, "cfg": CFG,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "deepseekchan_review"}},
    }


def submit(tag: str, seed: int, body: str, char_strength: float):
    prompt = "%s, %s, %s" % (STYLE, body, BACKDROP)
    payload = json.dumps({"prompt": graph(seed, prompt, char_strength), "client_id": "deepseek_review"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("[SUBMIT] %-10s seed=%d strength=%.2f -> %s" % (tag, seed, char_strength, resp.get("prompt_id")))
    return resp.get("prompt_id")


if __name__ == "__main__":
    tasks = [
        ("A", 8801001, CHAR, 0.85),
        ("B", 8801002, CHAR, 0.75),
        ("C", 8801003, CHAR + ", gentle smile, looking at viewer", 0.85),
        ("D", 8801004, CHAR + ", calm neutral expression, looking at viewer", 0.9),
    ]
    ids = {}
    for tag, seed, body, st in tasks:
        ids[tag] = submit(tag, seed, body, st)
    with open("D:/123/qianyuanshaonv/tools/deepseek_review_ids.json", "w", encoding="utf-8") as f:
        json.dump(ids, f, ensure_ascii=False, indent=2)
