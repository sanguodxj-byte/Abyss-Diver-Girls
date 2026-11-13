# -*- coding: utf-8 -*-
"""
14 岁胸像版重出：上一轮 6 张里有 3 张漂成整身，这一轮把画幅锁死到胸像。
"""
import json
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

UNET = "moss25d_int8.safetensors"
CLIP = "qwen35_int8.safetensors"
VAE = "flux2vae.safetensors"
PIXEL_LORA = "moss_pixelart_v03.safetensors"
CHAR_LORA = "deepseekchan_moss.safetensors"

STYLE = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, chunky pixel blocks, "
    "coarse visible pixel grid, clean grid-aligned pixels, distinct square pixels, "
    "extreme close-up portrait, tight crop at chest level, head and shoulders only, "
    "face large in frame, no torso below chest, three-quarter view, dynamic angle, off-center, "
    "masterpiece, best quality, 1girl, solo"
)

CHAR = (
    "DeepseekChan, 14 years old, young teenage girl, youthful face, rounder cheeks, petite, "
    "whale fin ears, gradient hair, long hair, ahoge, blue eyes, "
    "long navy blue maid dress, gold trim, frills, white apron, "
    "blue gemstone brooch, blue whale emblem"
)

BACKDROP = "pure solid black background, pitch black minimalist background"

NEG = (
    "full body, full figure, standing, wide shot, distant shot, small figure, "
    "dress hem, skirt hem, shoes, feet, legs, knees, waist visible, "
    "short skirt, miniskirt, microskirt, bare legs, thighhighs, zettai ryouiki, cleavage, "
    "mature female, adult woman, tall, voluptuous, "
    "id photo, passport photo, mugshot, front view, symmetrical, rigid pose, stiff pose, "
    "perfect symmetry, centered headshot, formal portrait, glowing eyes, "
    "3d, realistic photo, photograph, dslr, blurry, anti-aliased, "
    "lowres, worst quality, bad anatomy, bad hands, extra digits, watermark, text"
)

EXPR = {
    "neutral": "",
    "smile": ", gentle smile, looking at viewer",
    "serious": ", calm stern serious look, brow slightly furrowed, steady gaze at viewer",
    "surprised": ", brief surprised expression, eyes widened, mouth slightly open",
    "sad": ", quietly sad expression, gaze lowered, heavy eyelids",
    "tired": ", drowsy tired expression, eyelids half-lowered, weary look",
}


def graph(seed: int, prompt: str, strength: float) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "11": {"class_type": "LoraLoader", "inputs": {
            "model": ["1", 0], "clip": ["2", 0], "lora_name": PIXEL_LORA,
            "strength_model": 1.0, "strength_clip": 1.0}},
        "12": {"class_type": "LoraLoader", "inputs": {
            "model": ["11", 0], "clip": ["11", 1], "lora_name": CHAR_LORA,
            "strength_model": strength, "strength_clip": strength}},
        "6": {"class_type": "SkipLayerGuidanceDiTSimple", "inputs": {
            "model": ["12", 0], "double_layers": "", "single_layers": "22",
            "start_percent": 0.0, "end_percent": 1.0}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": prompt}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEG}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["7", 0],
            "seed": seed, "steps": 50, "cfg": 3.0,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "deepseekchan_age14_bust"}},
    }


if __name__ == "__main__":
    ids = {}
    seed = 8804000
    for name, extra in EXPR.items():
        seed += 1
        prompt = "%s, %s%s, %s" % (STYLE, CHAR, extra, BACKDROP)
        payload = json.dumps({"prompt": graph(seed, prompt, 0.85), "client_id": "deepseek_age14_bust"}).encode("utf-8")
        req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
        resp = json.load(urllib.request.urlopen(req, timeout=60))
        ids[name] = resp.get("prompt_id")
        print("[SUBMIT] %-10s -> %s" % (name, resp.get("prompt_id")))
    with open("D:/123/qianyuanshaonv/tools/deepseek_age14b_ids.json", "w", encoding="utf-8") as f:
        json.dump(ids, f, ensure_ascii=False, indent=2)
