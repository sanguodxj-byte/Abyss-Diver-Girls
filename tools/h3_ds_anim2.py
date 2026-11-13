# -*- coding: utf-8 -*-
"""
表情衔接动画（超短）：33 帧 @24fps。
只做嘴线与眉眼的细微变化，眼睛全程睁开，不出现眨眼。
python h3_ds_anim2.py <任务名> <种子>
"""
import json
import sys
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

DIT = "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
TE = "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
VVAE = "minimax_h3_video_vae_int8_convrot.safetensors"
AVAE = "minimax_h3_audio_vae_fp32.safetensors"
LORA = "minimax_h3_fl2v_turbo_4step_v1.0_768p_comfyui_bf16.safetensors"

REF = "ds_ref.png"
LENGTH = 33

LOCK = (
    "Maintain exact physical pixel grid alignment, distinct square pixel blocks, crisp pixel "
    "silhouette, no smoothing, no anti-aliasing, no 3D effects, no bilinear filtering. "
    "Her outfit, colors, face, hair and character design stay exactly the same throughout. "
    "The camera stays completely still, locked-down static shot. "
    "Pure solid black background preserved. One continuous shot, no cuts, no on-screen text."
)

NO_BLINK = (
    " Both eyes stay fully open the entire time; there is no blink, no squint, no eyelid closing."
)

TRANS = {
    "to_smile": (
        "Her neutral face shifts into a gentle smile: only the mouth line curves smoothly upward "
        "and the lower eyelids soften slightly. The change is small and gradual." + NO_BLINK
    ),
    "to_serious": (
        "Her neutral face tightens into a calm serious look: the brow lowers slightly, the eyes "
        "turn steady and firm, and the mouth line straightens. The change is small and gradual." + NO_BLINK
    ),
    "to_surprised": (
        "Her neutral face shifts into a brief surprised look: both eyes widen a little, the brows "
        "lift, and the mouth line opens slightly. The change is small and gradual." + NO_BLINK
    ),
    "to_sad": (
        "Her neutral face sinks into a quiet sad look: the gaze lowers slightly, the eyelids grow "
        "a little heavy, and the mouth line bends slightly down. The change is small and gradual."
    ),
    "to_tired": (
        "Her neutral face slackens into a drowsy look: the eyelids lower partway, the mouth line "
        "goes loose and flat, and her shoulders sink a little. The change is small and gradual."
    ),
}


def graph(job: str, seed: int) -> dict:
    prompt = (
        "At 0.00 seconds, <Picture 1> is fully referenced. A very short 16-bit modern indie game "
        "pixel sprite expression transition. " + TRANS[job] + " No head movement, no camera "
        "movement, no body movement. " + LOCK
    )
    return {
        "114": {"class_type": "LoadImage", "inputs": {"image": REF}},
        "6": {"class_type": "UNETLoader", "inputs": {"unet_name": DIT, "weight_dtype": "default"}},
        "13": {"class_type": "CLIPLoader", "inputs": {"clip_name": TE, "type": "minimax"}},
        "11": {"class_type": "VAELoader", "inputs": {"vae_name": VVAE}},
        "24": {"class_type": "VAELoader", "inputs": {"vae_name": AVAE}},
        "104": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {
            "clip": ["13", 0], "vae": ["11", 0], "first_frame": ["114", 0],
            "prompt": prompt, "width": 768, "height": 768, "length": LENGTH}},
        "121": {"class_type": "LoraLoaderModelOnly", "inputs": {
            "model": ["6", 0], "lora_name": LORA, "strength_model": 1.0}},
        "16": {"class_type": "BasicGuider", "inputs": {"model": ["121", 0], "conditioning": ["104", 0]}},
        "9": {"class_type": "BasicScheduler", "inputs": {
            "model": ["121", 0], "scheduler": "simple", "steps": 4, "denoise": 1.0}},
        "17": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
        "15": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "14": {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["15", 0], "guider": ["16", 0], "sampler": ["17", 0],
            "sigmas": ["9", 0], "latent_image": ["104", 1]}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["14", 0], "vae": ["11", 0]}},
        "23": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["14", 0], "vae": ["24", 0]}},
        "91": {"class_type": "CreateVideo", "inputs": {"images": ["10", 0], "audio": ["23", 0], "fps": 24.0}},
        "92": {"class_type": "SaveVideo", "inputs": {
            "video": ["91", 0], "filename_prefix": "video/ds_short_%s" % job,
            "format": "auto", "codec": "auto"}},
    }


if __name__ == "__main__":
    job = sys.argv[1]
    seed = int(sys.argv[2])
    payload = json.dumps({"prompt": graph(job, seed), "client_id": "ds_short"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("%s PROMPT_ID=%s" % (job, resp.get("prompt_id")))
