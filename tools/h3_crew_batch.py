# -*- coding: utf-8 -*-
"""
批量生成主角团（胡桃 kurumi、莉娜 lina、米娅 laojiao）的 MiniMax H3 视频动画。
- 4 步 Turbo LoRA，768x768，124 帧 @ 24fps
- 严格遵循 MiniMax H3 提示词规范（无负向提示词、首帧引导、像素硬边缘与设计锁）
- 支持断点续跑：已存在的文件自动跳过
"""
import os
import json
import urllib.request
import urllib.parse
import sys

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

DIT = "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
TE = "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
VVAE = "minimax_h3_video_vae_int8_convrot.safetensors"
AVAE = "minimax_h3_audio_vae_fp32.safetensors"
LORA = "minimax_h3_fl2v_turbo_4step_v1.0_768p_comfyui_bf16.safetensors"
WIDTH, HEIGHT, LENGTH, STEPS, FPS = 768, 768, 124, 4, 24.0

CHARS = {
    "kurumi": {
        "ref": "kurumi_ref.png",
        "s": "she", "p": "her", "S": "She", "P": "Her",
        "voice": "energetic feisty young female voice, clear bright adolescent anime girl tone",
        "seed_base": 7500100,
        # 已有 4 个：idle, smile, serious, surprised
        "jobs": [
            "sad", "tired",
            "talk_neutral", "talk_happy", "talk_angry", "talk_sad", "talk_surprised", "talk_tired", "talk_shy"
        ]
    },
    "lina": {
        "ref": "lina_ref.png",
        "s": "she", "p": "her", "S": "She", "P": "Her",
        "voice": "disciplined mature crisp young female voice, polite military cadet tone",
        "seed_base": 7600100,
        "jobs": [
            "idle", "smile", "serious", "surprised", "sad", "tired",
            "talk_neutral", "talk_happy", "talk_angry", "talk_sad", "talk_surprised", "talk_tired", "talk_shy"
        ]
    },
    "laojiao": {
        "ref": "mia_ref.png",
        "s": "she", "p": "her", "S": "She", "P": "Her",
        "voice": "drowsy sleepy low young female voice, relaxed mechanic girl drawl",
        "seed_base": 7700100,
        "jobs": [
            "idle", "smile", "serious", "surprised", "sad", "tired",
            "talk_neutral", "talk_happy", "talk_angry", "talk_sad", "talk_surprised", "talk_tired", "talk_shy"
        ]
    }
}

IDLE = (
    "The character holds a calm neutral expression with a relaxed posture, breathing gently "
    "with a subtle chest rise and fall. {S} blinks once naturally and keeps quiet steady eye "
    "contact with the viewer. {P} mouth stays closed and relaxed."
)
SMILE = (
    "{P} neutral expression slowly softens into a gentle warm smile: the corners of {p} mouth "
    "lift slightly, {p} eyes soften, and {s} holds the smile. {S} blinks once naturally."
)
SERIOUS = (
    "{P} expression settles into a calm stern serious look: {p} brow furrows slightly, {p} "
    "gaze turns steady and firm toward the viewer, and {s} holds that resolute stare. {S} "
    "blinks once."
)
SURPRISED = (
    "{S} reacts with a brief surprised expression: {p} eyes widen and {p} mouth opens "
    "slightly as if caught off guard, then {s} settles back to a calm neutral face. {S} "
    "leans back a tiny bit during the surprise."
)
SAD = (
    "{P} expression turns quietly sad: {p} gaze lowers, {p} eyelids grow heavy with melancholy, "
    "and {s} gives one small slow sigh, staying still otherwise."
)
TIRED = (
    "{S} looks drowsy and tired: {p} eyelids half-lower, {s} gives a small weary exhale, and "
    "{p} shoulders slacken slightly as {s} settles into a rested, sleepy posture."
)

TALK_NEUTRAL = (
    "{S} speaks to the viewer in a natural calm {voice}, saying one short clear sentence "
    "in Japanese. {P} mouth opens and closes naturally with the speech, teeth visible slightly. "
    "{S} blinks once naturally and holds steady eye contact with the viewer."
)
TALK_HAPPY = (
    "{S} speaks to the viewer in a warm cheerful {voice}, a light happy smile on {p} face. "
    "{P} mouth moves naturally with bright lively speech, eyes curving slightly with joy, "
    "and {s} gives a small cheerful nod."
)
TALK_ANGRY = (
    "{S} speaks to the viewer in a low firm irritated {voice}. The brow lowers, jaw tightens, "
    "mouth corners press level, and {p} mouth moves with short clipped speech while {s} "
    "glares sharply at the viewer."
)
TALK_SAD = (
    "{S} speaks to the viewer in a soft sorrowful {voice}. {P} gaze stays lowered, eyelids heavy, "
    "and {p} mouth moves slowly with quiet broken speech."
)
TALK_SURPRISED = (
    "{S} speaks to the viewer in a startled slightly raised {voice}. {P} eyes are wide and "
    "the brows lifted, {p} mouth moving quickly as if blurting something out in surprise."
)
TALK_TIRED = (
    "{S} speaks to the viewer in a slow weary low {voice}. {P} eyelids are half-lowered and "
    "{p} mouth moves sluggishly with sleepy speech, followed by a small weary exhale."
)
TALK_SHY = (
    "{S} speaks to the viewer in a small hesitant hushed {voice}. A faint blush warms the cheeks, "
    "{p} eyes glance slightly away and then back, {p} mouth moving timidly before {s} lowers "
    "{p} gaze shyly."
)

NON_TALK = {"idle": IDLE, "smile": SMILE, "serious": SERIOUS, "surprised": SURPRISED, "sad": SAD, "tired": TIRED}
TALK = {
    "talk_neutral": TALK_NEUTRAL, "talk_happy": TALK_HAPPY, "talk_angry": TALK_ANGRY,
    "talk_sad": TALK_SAD, "talk_surprised": TALK_SURPRISED, "talk_tired": TALK_TIRED,
    "talk_shy": TALK_SHY
}

PIXEL_LOCK = (
    "Maintain exact physical pixel grid alignment, distinct square pixel blocks, crisp pixel "
    "silhouette, no smoothing, no anti-aliasing, no 3D effects, no bilinear filtering. "
    "{P} outfit, colors, face, and character design stay exactly the same throughout. "
    "The camera stays completely still, locked-down static shot. "
    "Pure solid black background preserved. One continuous shot, no cuts, no on-screen text."
)


def build_graph(char: str, job: str, seed: int) -> dict:
    c = CHARS[char]
    body = (NON_TALK if job in NON_TALK else TALK)[job]
    body = body.format(**c).replace("{voice}", c["voice"])
    prompt = (
        "At 0.00 seconds, <Picture 1> is fully referenced. A 5-second 16-bit modern indie "
        "game pixel sprite animation. " + body + " " + PIXEL_LOCK.format(**c)
    )
    return {
        "114": {"class_type": "LoadImage", "inputs": {"image": c["ref"]}},
        "6": {"class_type": "UNETLoader", "inputs": {"unet_name": DIT, "weight_dtype": "default"}},
        "13": {"class_type": "CLIPLoader", "inputs": {"clip_name": TE, "type": "minimax"}},
        "11": {"class_type": "VAELoader", "inputs": {"vae_name": VVAE}},
        "24": {"class_type": "VAELoader", "inputs": {"vae_name": AVAE}},
        "104": {"class_type": "MiniMaxH3ImageToVideo", "inputs": {
            "clip": ["13", 0], "vae": ["11", 0], "first_frame": ["114", 0],
            "prompt": prompt, "width": WIDTH, "height": HEIGHT, "length": LENGTH}},
        "121": {"class_type": "LoraLoaderModelOnly", "inputs": {
            "model": ["6", 0], "lora_name": LORA, "strength_model": 1.0}},
        "16": {"class_type": "BasicGuider", "inputs": {"model": ["121", 0], "conditioning": ["104", 0]}},
        "9": {"class_type": "BasicScheduler", "inputs": {
            "model": ["121", 0], "scheduler": "simple", "steps": STEPS, "denoise": 1.0}},
        "17": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
        "15": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "14": {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["15", 0], "guider": ["16", 0], "sampler": ["17", 0],
            "sigmas": ["9", 0], "latent_image": ["104", 1]}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["14", 0], "vae": ["11", 0]}},
        "23": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["14", 0], "vae": ["24", 0]}},
        "91": {"class_type": "CreateVideo", "inputs": {
            "images": ["10", 0], "audio": ["23", 0], "fps": FPS}},
        "92": {"class_type": "SaveVideo", "inputs": {
            "video": ["91", 0], "filename_prefix": "video/%s_%s" % (char, job),
            "format": "auto", "codec": "auto"}},
    }


def live_prompt_ids() -> set:
    """ComfyUI 实例重启后队列会整体丢失，只有仍在队列或历史里的 prompt_id 才算有效。"""
    live = set()
    try:
        with urllib.request.urlopen(BASE + "/queue", timeout=30) as r:
            q = json.loads(r.read().decode())
        for item in q.get("queue_running", []) + q.get("queue_pending", []):
            live.add(item[1])
    except Exception:
        pass
    try:
        with urllib.request.urlopen(BASE + "/history", timeout=30) as r:
            live.update(json.loads(r.read().decode()).keys())
    except Exception:
        pass
    return live


def submit_batch(target_chars=None, limit_per_char=None):
    ids_file = "D:/123/qianyuanshaonv/tools/h3_crew_batch_ids.json"
    submitted = {}
    if os.path.exists(ids_file):
        with open(ids_file, "r", encoding="utf-8") as f:
            submitted = json.load(f)

    out_dir = "D:/123/qianyuanshaonv/assets/animations"
    os.makedirs(out_dir, exist_ok=True)

    live = live_prompt_ids()
    print(f"服务端仍存活的任务: {len(live)} 个")

    chars_to_run = target_chars or list(CHARS.keys())
    new_jobs = 0

    for char in chars_to_run:
        c = CHARS[char]
        jobs = c["jobs"]
        if limit_per_char:
            jobs = jobs[:limit_per_char]
        for i, job in enumerate(jobs):
            target_mp4 = f"{out_dir}/{char}_{job}.mp4"
            target_ogv = f"{out_dir}/{char}_{job}.ogv"
            if os.path.exists(target_mp4) and os.path.exists(target_ogv):
                continue
            key = f"{char}|{job}"
            if submitted.get(key) in live:
                continue

            seed = c["seed_base"] + i
            graph = build_graph(char, job, seed)
            payload = json.dumps({"prompt": graph, "client_id": "crew_anim_gen"}).encode("utf-8")
            req = urllib.request.Request(BASE + "/prompt", data=payload, headers={"Content-Type": "application/json"})
            try:
                resp = json.load(urllib.request.urlopen(req, timeout=60))
                p_id = resp.get("prompt_id")
                submitted[key] = p_id
                new_jobs += 1
                print(f"[SUBMIT] {char:8s} {job:16s} -> prompt_id: {p_id}")
            except Exception as e:
                print(f"[ERROR] {char} {job}: {e}")

    with open(ids_file, "w", encoding="utf-8") as f:
        json.dump(submitted, f, ensure_ascii=False, indent=2)
    print(f"总计提交新增任务: {new_jobs} 个，累计追踪任务: {len(submitted)} 个")


if __name__ == "__main__":
    chars = sys.argv[1].split(",") if len(sys.argv) > 1 else None
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else None
    submit_batch(chars, limit)
