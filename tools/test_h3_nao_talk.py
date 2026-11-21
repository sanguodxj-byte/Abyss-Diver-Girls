# -*- coding: utf-8 -*-
"""使用 MiniMax H3 (8-step Lightning LoRA) 对 3 号画风亚人立绘测试说话动画。"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid

ROOT = r"D:\123\qianyuanshaonv"
HOST_FILE = os.path.join(ROOT, "tools", "art_host.txt")

DIT = "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
TE = "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
VVAE = "minimax_h3_video_vae_int8_convrot.safetensors"
AVAE = "minimax_h3_audio_vae_fp32.safetensors"
LORA = "minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors"


def get_host():
    with open(HOST_FILE, "r", encoding="utf-8") as f:
        return f.read().strip().rstrip("/")


def upload_image(host: str, local_path: str, remote_name: str):
    cmd = [
        "curl", "-s", "-m", "60", "-X", "POST", f"{host}/upload/image",
        "-F", f"image=@{local_path};filename={remote_name}",
        "-F", "overwrite=true",
        "-F", "type=input",
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    print(f"[upload] {remote_name} -> {res.stdout.strip()}", flush=True)


def build_graph(remote_img: str, prompt: str, width: int, height: int, length: int, steps: int, seed: int, prefix: str):
    return {
        "1": {"class_type": "LoadImage", "inputs": {"image": remote_img}},
        "10": {"class_type": "UNETLoader", "inputs": {"unet_name": DIT, "weight_dtype": "default"}},
        "11": {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {"model": ["10", 0], "lora_name": LORA, "strength_model": 1.0},
        },
        "12": {"class_type": "CLIPLoader", "inputs": {"clip_name": TE, "type": "minimax", "device": "default"}},
        "13": {"class_type": "VAELoader", "inputs": {"vae_name": VVAE}},
        "14": {"class_type": "VAELoader", "inputs": {"vae_name": AVAE}},
        "20": {
            "class_type": "MiniMaxH3ImageToVideo",
            "inputs": {
                "clip": ["12", 0],
                "vae": ["13", 0],
                "first_frame": ["1", 0],
                "prompt": prompt,
                "width": width,
                "height": height,
                "length": length,
            },
        },
        "21": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "res_multistep"}},
        "22": {
            "class_type": "BasicScheduler",
            "inputs": {"model": ["11", 0], "scheduler": "simple", "steps": steps, "denoise": 1.0},
        },
        "23": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "24": {"class_type": "BasicGuider", "inputs": {"model": ["11", 0], "conditioning": ["20", 0]}},
        "25": {
            "class_type": "SamplerCustomAdvanced",
            "inputs": {
                "noise": ["23", 0],
                "guider": ["24", 0],
                "sampler": ["21", 0],
                "sigmas": ["22", 0],
                "latent_image": ["20", 1],
            },
        },
        "26": {"class_type": "VAEDecode", "inputs": {"samples": ["25", 0], "vae": ["13", 0]}},
        "27": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["25", 0], "vae": ["14", 0]}},
        "28": {"class_type": "CreateVideo", "inputs": {"images": ["26", 0], "fps": 24.0, "audio": ["27", 0]}},
        "29": {
            "class_type": "SaveVideo",
            "inputs": {"video": ["28", 0], "filename_prefix": prefix, "format": "auto", "codec": "auto"},
        },
    }


def make_contact_sheet(mp4_path: str, png_path: str):
    cmd = [
        "ffmpeg", "-y", "-v", "error", "-i", mp4_path,
        "-vf", "fps=1.2,scale=320:-1,tile=6x1",
        "-frames:v", "1", png_path,
    ]
    subprocess.run(cmd, check=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", default=os.path.join(ROOT, "review", "奈绪_3号画风_亚人版.png"))
    parser.add_argument("--out", default=os.path.join(ROOT, "review", "奈绪_H3说话测试.mp4"))
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=928)
    parser.add_argument("--length", type=int, default=124)
    parser.add_argument("--steps", type=int, default=8)
    parser.add_argument("--seed", type=int, default=20261121)
    args = parser.parse_args()

    host = get_host()
    remote_name = "h3_nao_ref.png"
    upload_image(host, args.image, remote_name)

    prompt = (
        "At 0.00 seconds, <Picture 1> is fully referenced. "
        "A 5-second 2D anime character dialogue animation. "
        "She speaks directly to the viewer in a calm, quiet, soft young female Japanese voice, saying one clear short sentence in Japanese. "
        "Her mouth opens and closes naturally and cleanly in sync with her calm speech. "
        "She blinks once naturally, breathes gently with a subtle chest rise and fall, and her rabbit ears and hair strands shift very slightly with her quiet cadence. "
        "Maintain exact 2D painterly anime illustration style, dry matte brushwork, crisp ink lineart, muted dark military palette, and flat 2D shading with no 3D rendering and no plastic sheen. "
        "Her outfit, silver hair, rabbit ears, muted crimson eyes, face, and character design stay exactly the same throughout. "
        "The camera stays completely still, locked-down static tripod shot. Pure solid pitch black background preserved. "
        "One continuous shot, no cuts, no morphing transitions, no on-screen text."
    )

    graph = build_graph(remote_name, prompt, args.width, args.height, args.length, args.steps, args.seed, "video/nao_talk_test")
    payload = json.dumps({"prompt": graph, "client_id": str(uuid.uuid4())}).encode("utf-8")
    req = urllib.request.Request(f"{host}/prompt", data=payload, headers={"Content-Type": "application/json"})

    t0 = time.time()
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        prompt_id = data["prompt_id"]
    print(f"[submit] prompt_id={prompt_id}, {args.width}x{args.height}, {args.length}f, {args.steps}steps", flush=True)

    deadline = time.time() + 1200
    while time.time() < deadline:
        time.sleep(5)
        try:
            with urllib.request.urlopen(f"{host}/history/{prompt_id}", timeout=15) as r:
                hist = json.loads(r.read().decode("utf-8")).get(prompt_id, {})
            if not hist:
                continue
            status = hist.get("status", {})
            if status.get("status_str") == "error":
                print("[error]", json.dumps(status, ensure_ascii=False), file=sys.stderr, flush=True)
                sys.exit(1)
            outputs = hist.get("outputs", {})
            if outputs:
                vids = []
                for v in outputs.values():
                    vids.extend(v.get("images", []))
                    vids.extend(v.get("gifs", []))
                    vids.extend(v.get("videos", []))
                if vids:
                    item = vids[0]
                    qs = urllib.parse.urlencode({
                        "filename": item["filename"],
                        "subfolder": item.get("subfolder", ""),
                        "type": item.get("type", "output"),
                    })
                    url = f"{host}/view?{qs}"
                    raw = urllib.request.urlopen(url, timeout=180).read()
                    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
                    with open(args.out, "wb") as f:
                        f.write(raw)
                    sheet = os.path.splitext(args.out)[0] + "_关键帧.png"
                    make_contact_sheet(args.out, sheet)
                    print(json.dumps({
                        "status": "success",
                        "video": os.path.abspath(args.out),
                        "sheet": os.path.abspath(sheet),
                        "seconds": round(time.time() - t0, 1),
                        "bytes": len(raw),
                    }, ensure_ascii=False), flush=True)
                    return
        except Exception as e:
            print(f"[poll-warn] {e}", flush=True)
    print("Timed out waiting for H3 video", file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
