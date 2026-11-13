# -*- coding: utf-8 -*-
"""
9:16 全身，角色站在画面左侧，视线朝右（朝卷帘门方向）。
python moss_deepseek_left916.py <seed> <pixel_lora 强度>
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

W, H = 1152, 2048

PROMPT = (
    "pixel art, 16-bit pixel art, modern indie game pixel sprite, fine pixel grid, "
    "clean grid-aligned pixels, distinct square pixels, crisp edges, "
    "vertical full body portrait, standing upright, whole body visible from head to feet, "
    "the character is placed on the left side of the frame, left third of the canvas, "
    "large empty space on the right side of the frame, "
    "body turned three-quarter toward the right, head turned to the right, "
    "looking toward the right side of the frame, eyes directed to the right, "
    "as if looking at a closed metal roll-up shutter door on the right, "
    "eight head proportions, slender teenage build, normal body proportions, "
    "highly detailed face, delicate beautiful face, refined facial features, "
    "bright color palette, high-key lighting, light airy tones, clear bright highlights, "
    "masterpiece, best quality, very aesthetic, sharp details, 1girl, solo, "
    "DeepseekChan, 16 years old, teenage high school girl, "
    "bright expressive eyes, fair pale skin, porcelain complexion, "
    "lips expressed by a single thin line only, lip line only, no color fill on lips, "
    "navy blue long maid dress with floor-length skirt reaching the ankles, "
    "gold trim, neat white frills at the hem, white apron with blue whale emblem, "
    "black bodice with gold clasp, white ruffled cuffs, "
    "blue gemstone brooch at the collar, whale fin ears, gradient hair, long hair, ahoge, "
    "one single blue whale tail behind her lower body, white tights, simple dark shoes, "
    "calm neutral expression with quiet attention, "
    "pure solid black background, pitch black minimalist background"
)

NEG = (
    "centered figure, middle of frame, right side of frame, facing left, looking left, "
    "looking at viewer, front view, facing camera, "
    "blurry, muddy, smeared, low detail, soft edges, smudged pixels, noisy pixels, "
    "two tails, multiple tails, extra fins, duplicate tail, "
    "chibi, super deformed, big head, short limbs, tiny body, "
    "tilted body, leaning, diagonal pose, crooked figure, "
    "close-up, bust shot, cropped body, cut off legs, half body, "
    "short skirt, miniskirt, knee length skirt, bare legs, "
    "missing apron, outfit redesign, different collar, "
    "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, "
    "filled lips, painted lips, shaded lips, lip shading, lip color fill, makeup, "
    "mature face, adult facial proportions, sharp jawline, angular face, "
    "heavy eyebrows, thick eyebrows, tanned skin, dark skin, "
    "dark heavy shadows, murky colors, gloomy, "
    "3d, realistic photo, "
    "lowres, worst quality, bad anatomy, extra hands, extra digits, extra limbs, "
    "watermark, text"
)


def graph(seed: int, strength: float) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "moss25d_int8.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen35_int8.safetensors", "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2vae.safetensors"}},
        "11": {"class_type": "LoraLoader", "inputs": {
            "model": ["1", 0], "clip": ["2", 0], "lora_name": "moss_pixelart_v03.safetensors",
            "strength_model": strength, "strength_clip": strength}},
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
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "deepseekchan_left916"}},
    }


if __name__ == "__main__":
    seed = int(sys.argv[1])
    strength = float(sys.argv[2])
    payload = json.dumps({"prompt": graph(seed, strength), "client_id": "ds_left916"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("PROMPT_ID=" + str(resp.get("prompt_id")))
