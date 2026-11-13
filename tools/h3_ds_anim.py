# -*- coding: utf-8 -*-
"""
DeepSeek 娘 H3 动画单条出片。
python h3_ds_anim.py <任务名> <帧数> <提示词文件后缀>
任务名决定构图与动作，帧数决定时长（24fps）。
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
VOICE = "soft bright young female voice, gentle teenage anime girl tone"

LOCK = (
    "Maintain exact physical pixel grid alignment, distinct square pixel blocks, crisp pixel "
    "silhouette, no smoothing, no anti-aliasing, no 3D effects, no bilinear filtering. "
    "Her outfit, colors, face, hair and character design stay exactly the same throughout. "
    "The camera stays completely still, locked-down static shot. "
    "Pure solid black background preserved. One continuous shot, no cuts, no on-screen text."
)

# 表情衔接：从当前中性脸过渡到目标表情，幅度小、时间短
TRANS = {
    "to_smile": (
        "At 0.00 seconds, <Picture 1> is fully referenced. A very short pixel sprite expression "
        "transition. Her neutral face gradually relaxes into a gentle warm smile: the mouth line "
        "curves smoothly upward, the eye shape softens with warmth, and she blinks once as the "
        "smile settles. The motion is slow and subtle, no head movement."
    ),
    "to_serious": (
        "At 0.00 seconds, <Picture 1> is fully referenced. A very short pixel sprite expression "
        "transition. Her neutral face tightens into a calm serious look: the brow lowers slightly, "
        "the eyes narrow a little and turn steady and firm, the mouth line straightens, and she "
        "holds that resolute stare. No head movement."
    ),
    "to_surprised": (
        "At 0.00 seconds, <Picture 1> is fully referenced. A very short pixel sprite expression "
        "transition. Her neutral face snaps into a brief surprised expression: both eyes widen, "
        "the brows lift, the mouth line opens slightly, then she settles a touch. No head movement."
    ),
    "to_sad": (
        "At 0.00 seconds, <Picture 1> is fully referenced. A very short pixel sprite expression "
        "transition. Her neutral face sinks into a quiet sad look: the gaze lowers, the eyelids grow "
        "heavy, the mouth line bends slightly down, and she gives one small slow breath. "
        "No head movement."
    ),
    "to_tired": (
        "At 0.00 seconds, <Picture 1> is fully referenced. A very short pixel sprite expression "
        "transition. Her neutral face slackens into a drowsy tired look: the eyelids half-lower, "
        "the mouth line goes loose and flat, her shoulders sink slightly, and she exhales quietly."
    ),
}

# 说话：每个状态一段口型动画
TALK = {
    "talk_neutral": (
        "At 0.00 seconds, <Picture 1> is fully referenced. She speaks to the viewer in a calm "
        "neutral " + VOICE + ", saying one short clear sentence in Japanese. Her mouth line opens "
        "and closes naturally with the speech, the jaw moves subtly, and she blinks once while "
        "holding steady eye contact."
    ),
    "talk_smile": (
        "At 0.00 seconds, <Picture 1> is fully referenced. She speaks to the viewer in a warm "
        "cheerful " + VOICE + ", a light happy smile on her face. Her mouth moves naturally with "
        "bright lively speech, the eye shape curves with joy, and she gives a small cheerful nod."
    ),
    "talk_serious": (
        "At 0.00 seconds, <Picture 1> is fully referenced. She speaks to the viewer in a low firm "
        + VOICE + ". The brow lowers, the jaw tightens, the mouth line moves with short clipped "
        "speech while she keeps a sharp steady gaze on the viewer."
    ),
    "talk_sad": (
        "At 0.00 seconds, <Picture 1> is fully referenced. She speaks to the viewer in a soft "
        "sorrowful " + VOICE + ". Her gaze stays lowered, the eyelids are heavy, and her mouth "
        "moves slowly with quiet broken speech."
    ),
    "talk_tired": (
        "At 0.00 seconds, <Picture 1> is fully referenced. She speaks to the viewer in a slow weary "
        "low " + VOICE + ". Her eyelids are half-lowered and her mouth moves sluggishly with sleepy "
        "speech, followed by a small weary exhale."
    ),
}

ALL = dict(TRANS)
ALL.update(TALK)


def graph(job: str, length: int, seed: int) -> dict:
    body = ALL[job]
    prompt = ("A short 5-second 16-bit modern indie game pixel sprite animation. "
              + body + " " + LOCK)
    return {
        "114": {"class_type": "LoadImage", "inputs": {"image": REF}},
        "6": {"class_type": "UNETLoader", "inputs": {"unet_name": DIT, "weight_dtype": "default"}},
        "13": {"class_type": "CLIPLoader", "inputs": {"clip_name": TE, "type": "minimax"}},
        "11": {"class_type": "VAELoader", "inputs": {"vae_name": VVAE}},
        "24": {"class_type": "VAELoader", "inputs": {"vae_name": AVAE}},
        "104": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {
            "clip": ["13", 0], "vae": ["11", 0], "first_frame": ["114", 0],
            "prompt": prompt, "width": 768, "height": 768, "length": length}},
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
            "video": ["91", 0], "filename_prefix": "video/ds_%s" % job,
            "format": "auto", "codec": "auto"}},
    }


if __name__ == "__main__":
    job = sys.argv[1]
    length = int(sys.argv[2])
    seed = int(sys.argv[3])
    payload = json.dumps({"prompt": graph(job, length, seed), "client_id": "ds_anim"}).encode("utf-8")
    req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    print("%s PROMPT_ID=%s" % (job, resp.get("prompt_id")))
