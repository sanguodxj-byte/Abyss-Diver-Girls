# -*- coding: utf-8 -*-
"""DeepSeek-chan 微笑表情双通道生成：MOSS 图生图（I2I 单帧）+ MiniMax H3 I2V（微笑动画）。

- 图生图：v7 立绘作输入，denoise 收敛只改表情，锁定角色与像素风
- H3：v7 立绘作首帧，4 步 Turbo LoRA，736x1280 竖版 9:16，124 帧 @24fps
"""
import json
import sys
import urllib.request

with open(r"D:\123\qianyuanshaonv\tools\art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

REF = "deepseek_ref.png"
PIXEL_LOCK = (
    "Maintain exact character identity, outfit, colors, face, and design stay the same. "
    "Chunky 16-bit pixel blocks, crisp pixel silhouette, no smoothing, no anti-aliasing. "
    "Pure solid black background preserved, camera locked, one continuous shot, no cuts, no on-screen text."
)
SMILE_I2I = (
    "DeepseekChan, DeepseekChan \\(maid dress\\), maid, maid headdress, ahoge, bright deep blue eyes, "
    "dark navy blue gradient long hair flowing down back, whale fin ears, single blue whale tail with starlight specks, "
    "navy blue dress, gold trim along every edge, frills, puffy juliet sleeves, white frilled apron, apron bow at back, "
    "back three-quarter view from behind, body and head angled together 45 degrees to the right towards front-right, "
    "right cheek edge and right ear visible past the hair, "
    "she breaks into a gentle warm smile seen from behind: corners of mouth lift slightly, eyes softly curved with quiet joy, cheeks slightly raised, "
    "lips expressed by a single thin line only, no color fill on lips, natural pale matte lips, "
    "slender maiden proportions, long slender legs, white thighhighs, black mary janes, "
    "masterpiece, best quality, distinct chunky 16-bit pixel art sprite, clean vibrant colors, crisp pixel edges, "
    "solid pure black background, no scene, no floor, clean standalone sprite"
)
NEG = (
    "front view, facing camera, full face visible, looking back at camera, 180 degree head turn, "
    "pure back view, faceless, no face, frown, sad expression, open mouth laughing, teeth, tongue, "
    "lipstick, lip gloss, glossy lips, colored lips, filled lips, shaded lips, lip shading, lip color fill, "
    "twin tails, short hair, dull colors, desaturated, muddy, monochrome, "
    "text, watermark, signature, blurry, realistic, 3d, gradient background, deformed, "
    "extra limbs, extra fingers, poor anatomy, multiple characters, noisy background"
)
SMILE_H3 = (
    "At 0.00 seconds, <Picture 1> is fully referenced. A 5-second 16-bit retro game pixel sprite animation "
    "rendered in chunky square pixel blocks: every frame is pixelated pixel art with crisp hard pixel edges, "
    "visible square pixel grid, no smoothing, no anti-aliasing, no soft shading, retro sprite look preserved in every frame. "
    "The character maintains the exact same three-quarter rear angle of <Picture 1> throughout the entire video: "
    "body and head are angled 45 degrees towards the right, keeping her right cheek contour and right whale fin ear visible. "
    "Strictly zero rotation: she neither turns forward toward the viewer nor turns away into a flat back view. "
    "Her head yaw, neck angle, and body orientation remain completely frozen at 45 degrees to the right for the full duration. "
    "Her body posture is completely still from head to shoes: standing firmly on both feet with white thighhighs "
    "and black mary janes shoes, no stepping, no walking, no arm or hand movement, no torso twisting. "
    "The only motion in the shot is subtle breathing with a gentle chest rise and fall, a very soft idle drift of her hair tips "
    "and her single starry blue whale tail swaying ever so slightly behind her. Her gentle smile is held steadily "
    "with her visible right cheek contour softly raised, lips remaining an uncolored single thin line. "
    "Full-body shot framed continuously from top to bottom, no zoom in, no close-up, constant camera distance. "
    "Maintain exact character identity, dark navy blue dress with gold trim, white apron and large back bow. "
    "Pure solid pitch black background with zero objects, no background scenery, no props, no scrolls, completely isolated sprite on solid black background. "
    "One continuous shot, no cuts, no on-screen text."
)

DIT = "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
TE = "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
VVAE = "minimax_h3_video_vae_int8_convrot.safetensors"
AVAE = "minimax_h3_audio_vae_fp32.safetensors"
H3LORA = "minimax_h3_fl2v_turbo_4step_v1.0_768p_comfyui_bf16.safetensors"


def moss_i2i_graph(seed: int) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "moss25d_int8.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen35_int8.safetensors", "type": "moss_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2vae.safetensors"}},
        "20": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": "moss_pixelart_v03.safetensors", "strength_model": 0.85}},
        "21": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["20", 0], "lora_name": "deepseekchan_moss.safetensors", "strength_model": 0.75}},
        "22": {"class_type": "SkipLayerGuidanceDiTSimple", "inputs": {"model": ["21", 0], "double_layers": "", "single_layers": "22", "start_percent": 0.0, "end_percent": 1.0}},
        "40": {"class_type": "LoadImage", "inputs": {"image": REF}},
        "41": {"class_type": "VAEEncode", "inputs": {"pixels": ["40", 0], "vae": ["3", 0]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": SMILE_I2I}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": NEG}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["22", 0], "seed": seed, "steps": 40, "cfg": 3.0,
            "sampler_name": "euler", "scheduler": "simple",
            "positive": ["5", 0], "negative": ["6", 0], "latent_image": ["41", 0], "denoise": 0.5}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "deepseek_i2i_smile"}},
    }


def h3_smile_graph(seed: int) -> dict:
    return {
        "114": {"class_type": "LoadImage", "inputs": {"image": REF}},
        "6": {"class_type": "UNETLoader", "inputs": {"unet_name": DIT, "weight_dtype": "default"}},
        "13": {"class_type": "CLIPLoader", "inputs": {"clip_name": TE, "type": "minimax"}},
        "11": {"class_type": "VAELoader", "inputs": {"vae_name": VVAE}},
        "24": {"class_type": "VAELoader", "inputs": {"vae_name": AVAE}},
        "104": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {
            "clip": ["13", 0], "vae": ["11", 0], "first_frame": ["114", 0],
            "prompt": SMILE_H3, "width": 736, "height": 1280, "length": 124}},
        "121": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["6", 0], "lora_name": H3LORA, "strength_model": 1.0}},
        "16": {"class_type": "BasicGuider", "inputs": {"model": ["121", 0], "conditioning": ["104", 0]}},
        "9": {"class_type": "BasicScheduler", "inputs": {"model": ["121", 0], "scheduler": "simple", "steps": 4, "denoise": 1.0}},
        "17": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
        "15": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "14": {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["15", 0], "guider": ["16", 0], "sampler": ["17", 0], "sigmas": ["9", 0], "latent_image": ["104", 1]}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["14", 0], "vae": ["11", 0]}},
        "23": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["14", 0], "vae": ["24", 0]}},
        "91": {"class_type": "CreateVideo", "inputs": {"images": ["10", 0], "audio": ["23", 0], "fps": 24.0}},
        "92": {"class_type": "SaveVideo", "inputs": {"video": ["91", 0], "filename_prefix": "video/deepseek_smile_h3", "format": "auto", "codec": "auto"}},
    }


def submit(graph: dict, client: str) -> str:
    payload = json.dumps({"prompt": graph, "client_id": client}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        pid = json.loads(r.read().decode()).get("prompt_id")
    return pid


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "both"
    i2i_seed = 20261112
    h3_seed = 20261114
    if mode in ("both", "i2i"):
        p1 = submit(moss_i2i_graph(i2i_seed), "deepseek_smile_i2i")
        print(f"I2I_PROMPT_ID:{p1}")
    if mode in ("both", "h3"):
        p2 = submit(h3_smile_graph(h3_seed), "deepseek_smile_h3")
        print(f"H3_PROMPT_ID:{p2}")
