# -*- coding: utf-8 -*-
"""
背面全身立绘：纯黑背景独立出图，不做任何遮罩与场景合成。
python moss_ds_back_sprite.py <seed>
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

W, H = 864, 1536

PROMPT = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, fine pixel grid, "
    "clean grid-aligned pixels, distinct square pixels, crisp edges, "
    "vertical full body sprite, character seen from behind, rear view, back to the camera, "
    "camera slightly above, gentle high angle looking down at her back, "
    "whole body visible from head to feet, standing upright, centered, "
    "both arms hanging down relaxed at her sides, hands at her hips level, "
    "her long gradient blue hair falls down her back, ahoge sticking up, "
    "whale fin ears at both sides of her head, "
    "navy blue long maid dress with floor-length skirt reaching the ankles, "
    "gold trim, neat white frills at the hem, "
    "white apron straps crossing her back, black bodice with gold clasp, "
    "white ruffled cuffs, one single blue whale tail hanging down behind her legs, "
    "white tights, simple dark shoes, "
    "seven head proportions, slender teenage build, normal body proportions, "
    "bright color palette, high-key lighting, light airy tones, sharp details, "
    "masterpiece, best quality, 1girl, solo, "
    "DeepseekChan, 16 years old, teenage high school girl, fair pale skin, "
    "pure solid black background, pitch black minimalist background"
)

NEG = (
    "face visible, front view, facing camera, looking at viewer, eye contact, "
    "raised arm, arm on wall, hand touching wall, waving, arms up, "
    "two tails, multiple tails, extra fins, tail on the side, "
    "head cut off, cropped head, cropped legs, half body, cut off feet, "
    "chibi, super deformed, big head, short limbs, oversized head, "
    "tilted body, leaning, crooked figure, off balance, "
    "short skirt, miniskirt, bare legs, "
    "missing apron, outfit redesign, "
    "lipstick, lip gloss, glossy lips, colored lips, red lips, pink lips, makeup, "
    "blurry, muddy, smeared, soft edges, smudged pixels, "
    "3d, realistic photo, "
    "lowres, worst quality, bad anatomy, extra hands, extra digits, extra limbs, "
    "watermark, text, scene background, room interior"
)


def graph(seed: int) -> dict:
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
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": PROMPT}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEG}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": W, "height": H, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["7", 0],
            "seed": seed, "steps": 50, "cfg": 3.0,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "ds_back_sprite"}},
    }


if __name__ == "__main__":
    seed = int(sys.argv[1])
    payload = json.dumps({"prompt": graph(seed), "client_id": "ds_back_sprite"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("PROMPT_ID=" + str(resp.get("prompt_id")))
