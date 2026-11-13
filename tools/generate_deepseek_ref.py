# -*- coding: utf-8 -*-
import json
import urllib.request
import os
import sys

BASE_URL_FILE = r"D:\123\qianyuanshaonv\tools\art_host.txt"

def get_base_url():
    with open(BASE_URL_FILE, "r", encoding="utf-8") as f:
        return f.read().strip()

def build_deepseek_graph(seed=20261104, width=720, height=1280):
    positive_prompt = (
        "DeepseekChan, DeepseekChan \\(maid dress\\), maid, maid headdress, ahoge, bright deep blue eyes, "
        "dark navy blue gradient long hair flowing down back, long hair, "
        "whale fin ears on head, a single blue whale tail with subtle starlight specks curving out behind, "
        "navy blue dress, rich vibrant navy blue fabric, gold trim along every edge, frills, puffy juliet sleeves, "
        "white frilled apron over dress with white apron bow tied at the back of waist, blue gemstone brooch at collar, "
        "back three-quarter view seen from behind, character facing away from the viewer, "
        "body and head angled together in unison 45 degrees to the right towards the front-right, "
        "back of head and back of dress mostly visible, the right edge of her face partially visible from behind, "
        "right cheek line, right ear and whale fin ear visible past the hair, subtle glimpse of her right side profile, head not turned back towards camera, "
        "slender elegant maiden proportions, tall slender graceful figure, long slender legs, "
        "white thighhighs on legs, black mary janes shoes with ankle straps standing neatly on ground, "
        "full body standing from head to feet, complete full-length view showing head to shoes, "
        "lips expressed by a single thin line only, no color fill on lips, lip line only, natural pale matte lips, "
        "masterpiece, best quality, distinct chunky 16-bit pixel art sprite, clean vibrant colors, crisp pixel edges, "
        "solid pure black background, completely isolated on solid black background, no scene, no floor, clean standalone sprite"
    )

    negative_prompt = (
        "front view, facing camera, facing viewer, looking at camera, looking back at camera, head turned backwards, 180 degree head turn, looking over shoulder, both eyes visible, full face visible, "
        "pure back view, face completely hidden, faceless, no face visible, zero face, back of head only, headless, "
        "facing left, looking left, facing screen-left, oriented towards left, turned to the left, "
        "short legs, stubby legs, thick legs, chubby legs, dwarf proportions, chibified, chibi, short stature, "
        "cropped legs, missing legs, cut off feet, missing feet, cut off at bottom, out of frame, partial body, cropped body, "
        "twisted neck, broken spine, awkward pose, twin tails, twintails, pigtails, short hair, "
        "dull colors, desaturated, washed out, dark and muddy, greyish, monochrome, "
        "text, watermark, signature, speech bubble, blurry, realistic, 3d, gradient background, photorealistic, deformed, "
        "extra limbs, extra arms, extra fingers, poor anatomy, bad hands, multiple characters, messy lines, noisy background, "
        "lipstick, lip gloss, glossy lips, shiny lips, colored lips, red lips, pink lips, filled lips, shaded lips, lip shading, lip color fill"
    )

    graph = {
        "1": {
            "class_type": "UNETLoader",
            "inputs": {
                "unet_name": "moss25d_int8.safetensors",
                "weight_dtype": "default"
            }
        },
        "2": {
            "class_type": "CLIPLoader",
            "inputs": {
                "clip_name": "qwen35_int8.safetensors",
                "type": "moss_image",
                "device": "default"
            }
        },
        "3": {
            "class_type": "VAELoader",
            "inputs": {
                "vae_name": "flux2vae.safetensors"
            }
        },
        "20": {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {
                "model": ["1", 0],
                "lora_name": "moss_pixelart_v03.safetensors",
                "strength_model": 0.85
            }
        },
        "21": {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {
                "model": ["20", 0],
                "lora_name": "deepseekchan_moss.safetensors",
                "strength_model": 0.75
            }
        },
        "22": {
            "class_type": "SkipLayerGuidanceDiTSimple",
            "inputs": {
                "model": ["21", 0],
                "double_layers": "",
                "single_layers": "22",
                "start_percent": 0.0,
                "end_percent": 1.0
            }
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["2", 0],
                "text": positive_prompt
            }
        },
        "6": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["2", 0],
                "text": negative_prompt
            }
        },
        "7": {
            "class_type": "EmptyFlux2LatentImage",
            "inputs": {
                "width": width,
                "height": height,
                "batch_size": 1
            }
        },
        "8": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["22", 0],
                "seed": seed,
                "steps": 40,
                "cfg": 3.0,
                "sampler_name": "euler",
                "scheduler": "simple",
                "positive": ["5", 0],
                "negative": ["6", 0],
                "latent_image": ["7", 0],
                "denoise": 1.0
            }
        },
        "9": {
            "class_type": "VAEDecode",
            "inputs": {
                "samples": ["8", 0],
                "vae": ["3", 0]
            }
        },
        "10": {
            "class_type": "SaveImage",
            "inputs": {
                "images": ["9", 0],
                "filename_prefix": "deepseek_single_ref"
            }
        }
    }
    return graph

def submit_single_job(seed=20261104):
    base = get_base_url()
    graph = build_deepseek_graph(seed=seed)
    payload = json.dumps({"prompt": graph, "client_id": "deepseek_single_sub"}).encode("utf-8")
    req = urllib.request.Request(base + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            resp = json.loads(r.read().decode())
            pid = resp.get("prompt_id")
            print(f"PROMPT_ID:{pid}")
            return pid
    except Exception as e:
        print(f"ERROR:{e}", file=sys.stderr)
        return None

if __name__ == "__main__":
    s = int(sys.argv[1]) if len(sys.argv) > 1 else 20261104
    submit_single_job(s)
