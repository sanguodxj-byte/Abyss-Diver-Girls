# -*- coding: utf-8 -*-
"""
场景局部重绘 v3：遮罩加宽抬高，人物完整落在遮罩内，头顶留出空白，正面朝右。
python moss_ds_shop_inpaint3.py <seed>
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

SCENE = "shop_scene.png"
MASK = "shop_mask3.png"

PROMPT = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, fine pixel grid, "
    "clean grid-aligned pixels, distinct square pixels, crisp edges, "
    "one small girl standing on the floor at the left side of the shop, "
    "small short figure, much shorter than the walls, "
    "there is clear empty wall space above the top of her head, "
    "her whole body including the top of her head fits inside the frame, "
    "seen from the front in a three-quarter front view, her face clearly visible, "
    "body turned three-quarter toward the right, head turned to the right, "
    "looking toward the closed metal roll-up shutter door on the right, "
    "calm neutral expression, arms relaxed at her sides, "
    "six head proportions, small teenage build, "
    "delicate beautiful face, refined facial features, "
    "bright color palette, high-key lighting, light airy tones, "
    "masterpiece, best quality, very aesthetic, sharp details, 1girl, solo, "
    "DeepseekChan, 16 years old, teenage high school girl, "
    "bright expressive eyes, fair pale skin, porcelain complexion, "
    "lips expressed by a single thin line only, lip line only, no color fill on lips, "
    "navy blue long maid dress with floor-length skirt reaching the ankles, "
    "gold trim, neat white frills at the hem, white apron with blue whale emblem, "
    "black bodice with gold clasp, white ruffled cuffs, "
    "blue gemstone brooch at the collar, whale fin ears, gradient hair, long hair, ahoge, "
    "one single blue whale tail behind her lower body, white tights, simple dark shoes, "
    "standing on the metal floor of the shop, soft shadow under her feet"
)

NEG = (
    "head cut off, cropped head, missing head, top of head cut, "
    "back view, seen from behind, facing away, faceless, "
    "too tall, oversized figure, giant, head touching top edge, head reaching ceiling, "
    "blurry, muddy, smeared, low detail, soft edges, smudged pixels, "
    "two tails, multiple tails, extra fins, duplicate tail, "
    "chibi, super deformed, big head, short limbs, "
    "tilted body, leaning, diagonal pose, crooked figure, "
    "close-up, bust shot, cropped body, cut off legs, half body, "
    "short skirt, miniskirt, bare legs, "
    "missing apron, outfit redesign, different collar, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, makeup, "
    "mature face, adult facial proportions, sharp jawline, angular face, "
    "heavy eyebrows, thick eyebrows, tanned skin, dark skin, "
    "3d, realistic photo, "
    "lowres, worst quality, bad anatomy, extra hands, extra digits, extra limbs, "
    "watermark, text, speech bubble, ui overlay"
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
            "pixels": ["20", 0], "vae": ["3", 0], "mask": ["30", 0], "grow_mask_by": 8}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": PROMPT}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["12", 1], "text": NEG}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["6", 0], "positive": ["4", 0], "negative": ["5", 0], "latent_image": ["21", 0],
            "seed": seed, "steps": 50, "cfg": 3.5,
            "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "shop_inpaint3"}},
    }


if __name__ == "__main__":
    seed = int(sys.argv[1])
    payload = json.dumps({"prompt": graph(seed), "client_id": "shop_inpaint3"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("PROMPT_ID=" + str(resp.get("prompt_id")))
