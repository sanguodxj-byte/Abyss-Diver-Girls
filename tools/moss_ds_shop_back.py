# -*- coding: utf-8 -*-
"""
场景局部重绘：角色背对镜头、略俯视，朝卷帘门方向看。
python moss_ds_shop_back.py <seed>
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

SCENE = "shop_scene.png"
MASK = "shop_mask_sil.png"

PROMPT = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, fine pixel grid, "
    "clean grid-aligned pixels, distinct square pixels, crisp edges, "
    "one girl standing on the floor at the left side of the shop, "
    "seen from behind, her back to the camera, rear view, "
    "camera slightly above her, gentle high angle looking down at her back, "
    "her long gradient blue hair falls down her back, "
    "she is looking forward away from the camera, toward the closed metal roll-up shutter door, "
    "whole body visible from head to feet, small figure, "
    "arms relaxed at her sides, calm standing pose, "
    "DeepseekChan, 16 years old, teenage high school girl, small teenage build, "
    "fair pale skin, whale fin ears, long gradient blue hair, ahoge, "
    "lips expressed by a single thin line only, no color fill on lips, "
    "navy blue long maid dress with floor-length skirt reaching the ankles, "
    "gold trim, neat white frills at the hem, "
    "white apron straps crossing her back, blue whale emblem on the apron, "
    "black bodice with gold clasp, white ruffled cuffs, "
    "blue gemstone brooch at the collar, one single blue whale tail behind her, "
    "white tights, dark shoes, soft shadow under her feet, "
    "masterpiece, best quality, sharp details"
)

NEG = (
    "face visible, front view, facing camera, looking at viewer, eye contact, frontal face, "
    "head cut off, cropped head, cropped legs, half body, "
    "two tails, multiple tails, extra fins, "
    "chibi, super deformed, big head, short limbs, oversized head, "
    "tilted body, leaning, crooked figure, "
    "short skirt, miniskirt, bare legs, "
    "missing apron, outfit redesign, "
    "lipstick, lip gloss, glossy lips, colored lips, red lips, pink lips, makeup, "
    "blurry, muddy, smeared, soft edges, smudged pixels, "
    "3d, realistic photo, "
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
            "strength_model": 0.9, "strength_clip": 0.9}},
        "12": {"class_type": "LoraLoader", "inputs": {
            "model": ["11", 0], "clip": ["11", 1], "lora_name": "deepseekchan_moss.safetensors",
            "strength_model": 0.7, "strength_clip": 0.7}},
        "6": {"class_type": "SkipLayerGuidanceDiTSimple", "inputs": {
            "model": ["12", 0], "double_layers": "", "single_layers": "22",
            "start_percent": 0.0, "end_percent": 1.0}},
        "20": {"class_type": "LoadImage", "inputs": {"image": SCENE}},
        "22": {"class_type": "LoadImage", "inputs": {"image": MASK}},
        "30": {"class_type": "ImageToMask", "inputs": {"image": ["22", 0], "channel": "red"}},
        "21": {"class_type": "VAEEncodeForInpaint", "inputs": {
            "pixels": ["20", 0], "vae": ["3", 0], "mask": ["30", 0], "grow_mask_by": 4}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": PROMPT}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEG}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["21", 0],
            "seed": seed, "steps": 50, "cfg": 3.5,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "shop_back"}},
    }


if __name__ == "__main__":
    seed = int(sys.argv[1])
    payload = json.dumps({"prompt": graph(seed), "client_id": "shop_back"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("PROMPT_ID=" + str(resp.get("prompt_id")))
