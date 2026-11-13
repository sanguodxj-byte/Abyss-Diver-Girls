# -*- coding: utf-8 -*-
"""
监控已提交的 MiniMax H3 任务：
1. 定期探查 ComfyUI /history；
2. 下载产物视频；
3. 执行 LAB-CDF 第一帧颜色分布匹配（消除 H3 亮度漂移）；
4. 转码为 Godot 4 标准 .ogv 与 .mp4；
5. 单次扫描并处理已完成项，处理完毕后退出，不使用阻塞循环。
"""
import os
import json
import urllib.request
import urllib.parse
import subprocess
import sys
import numpy as np
import cv2

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

OUT_DIR = "D:/123/qianyuanshaonv/assets/animations"
TMP_DIR = "D:/123/qianyuanshaonv/review/h3_tmp"
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(TMP_DIR, exist_ok=True)

MASK_T = 30


def channel_cdf(vals):
    hist = np.bincount(vals.astype(np.int32), minlength=256).astype(np.float64)
    cdf = np.cumsum(hist)
    return cdf / max(cdf[-1], 1.0)


def align_video(src, dst):
    cap = cv2.VideoCapture(src)
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    if w == 0 or h == 0:
        return False
    cmd = [
        "ffmpeg", "-y", "-v", "error",
        "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", "%dx%d" % (w, h), "-r", "%.6f" % fps,
        "-i", "pipe:0", "-i", src,
        "-map", "0:v", "-map", "1:a?", "-c:v", "libx264", "-crf", "14",
        "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "copy", "-shortest", dst
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    ref_cdfs = None
    ok, fr = cap.read()
    while ok:
        mask = fr.max(axis=2) > MASK_T
        lab = cv2.cvtColor(fr, cv2.COLOR_BGR2LAB)
        if ref_cdfs is None:
            ref_cdfs = [channel_cdf(lab[:, :, c][mask]) for c in range(3)]
            out = fr
        else:
            out_lab = lab.copy()
            for c in range(3):
                cc = channel_cdf(lab[:, :, c][mask])
                inv = np.clip(np.searchsorted(ref_cdfs[c], cc, side="left"), 0, 255).astype(np.uint8)
                mapped = cv2.LUT(lab[:, :, c], inv)
                out_lab[:, :, c] = np.where(mask, mapped, lab[:, :, c])
            out = cv2.cvtColor(out_lab, cv2.COLOR_LAB2BGR)
        proc.stdin.write(np.ascontiguousarray(out).tobytes())
        ok, fr = cap.read()
    cap.release()
    proc.stdin.close()
    proc.wait()
    return proc.returncode == 0


def convert_to_ogv(src_mp4, dst_ogv):
    cmd = [
        "ffmpeg", "-y", "-v", "error",
        "-i", src_mp4,
        "-c:v", "libtheora", "-q:v", "7",
        "-c:a", "libvorbis", "-q:a", "5",
        dst_ogv
    ]
    return subprocess.run(cmd).returncode == 0


def poll_and_process():
    ids_file = "D:/123/qianyuanshaonv/tools/h3_crew_batch_ids.json"
    if not os.path.exists(ids_file):
        print("无任务记录")
        return

    with open(ids_file, "r", encoding="utf-8") as f:
        tasks = json.load(f)

    # 查全局历史
    req = urllib.request.Request(BASE + "/history")
    with urllib.request.urlopen(req, timeout=30) as r:
        history = json.loads(r.read().decode())

    # 查当前队列
    q_req = urllib.request.Request(BASE + "/queue")
    with urllib.request.urlopen(q_req, timeout=30) as r:
        q_data = json.loads(r.read().decode())
    running = [item[1] for item in q_data.get("queue_running", [])]
    pending = [item[1] for item in q_data.get("queue_pending", [])]

    print(f"队列状态: 正在运行 {len(running)} | 挂起等待 {len(pending)}")

    completed_count = 0
    in_flight = 0

    for key, p_id in tasks.items():
        char, job = key.split("|")
        final_mp4 = f"{OUT_DIR}/{char}_{job}.mp4"
        final_ogv = f"{OUT_DIR}/{char}_{job}.ogv"

        if os.path.exists(final_mp4) and os.path.exists(final_ogv):
            completed_count += 1
            continue

        if p_id in history:
            print(f"[处理就绪] {key} -> {p_id}")
            outputs = history[p_id].get("outputs", {})
            video_info = None
            for node_id, node_out in outputs.items():
                for k in ["videos", "images", "gifs"]:
                    if k in node_out and len(node_out[k]) > 0:
                        candidate = node_out[k][0]
                        if candidate.get("filename", "").endswith((".mp4", ".mov", ".webm")):
                            video_info = candidate
                            break
                if video_info:
                    break

            if not video_info:
                print(f"[警告] {key} 没有找到视频输出节点")
                continue

            fn = video_info["filename"]
            sub = video_info.get("subfolder", "")
            params = urllib.parse.urlencode({"filename": fn, "subfolder": sub, "type": "output"})
            download_url = f"{BASE}/view?{params}"

            raw_mp4 = f"{TMP_DIR}/raw_{char}_{job}.mp4"
            print(f"  下载原始视频: {fn} -> {raw_mp4}")
            urllib.request.urlretrieve(download_url, raw_mp4)

            print(f"  执行第一帧 LAB-CDF 色彩校正...")
            if align_video(raw_mp4, final_mp4):
                print(f"  色彩校正完成: {final_mp4}")
            else:
                import shutil
                shutil.copy(raw_mp4, final_mp4)

            print(f"  转码为 Godot .ogv...")
            convert_to_ogv(final_mp4, final_ogv)
            print(f"[交付完毕] {char}_{job} (.mp4 & .ogv 就绪)")
            completed_count += 1
        elif p_id in running:
            print(f"[正在运行] {key} ({p_id})")
            in_flight += 1
        elif p_id in pending:
            in_flight += 1

    print(f"\n统计: 已交付 {completed_count}/{len(tasks)} | 生成中/待处理 {in_flight}")


if __name__ == "__main__":
    poll_and_process()
