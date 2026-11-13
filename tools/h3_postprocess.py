# -*- coding: utf-8 -*-
"""H3 视频后处理：LAB-CDF 帧间校色抑制光照漂移，再转 Godot Theora .ogv。"""
import os
import subprocess
import sys
import tempfile

import cv2
import numpy as np


def lab_cdf_match(ref_lut_src, ref_lut_dst):
    """生成 LAB 三通道的 CDF 映射表。"""
    luts = []
    for ch in range(3):
        hist_src = np.bincount(ref_lut_src[:, ch].ravel(), minlength=256).astype(np.float64)
        hist_dst = np.bincount(ref_lut_dst[:, ch].ravel(), minlength=256).astype(np.float64)
        cdf_src = np.cumsum(hist_src) / max(hist_src.sum(), 1)
        cdf_dst = np.cumsum(hist_dst) / max(hist_dst.sum(), 1)
        lut = np.interp(cdf_src, cdf_dst, np.arange(256)).astype(np.uint8)
        luts.append(lut)
    return luts


def process(video_in: str, video_out: str):
    cap = cv2.VideoCapture(video_in)
    frames = []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        frames.append(f)
    cap.release()
    if not frames:
        print("NO_FRAMES")
        return

    # 以中间帧为基准：首帧→基准 建映射，之后各帧沿用同一映射（稳态校色，不逐帧漂移）
    mid = frames[len(frames) // 2]
    lab_mid = cv2.cvtColor(mid, cv2.COLOR_BGR2LAB)
    lab_first = cv2.cvtColor(frames[0], cv2.COLOR_BGR2LAB)
    luts = lab_cdf_match(lab_first, lab_mid)

    tmp_dir = tempfile.mkdtemp(prefix="dslab_")
    for i, f in enumerate(frames):
        lab = cv2.cvtColor(f, cv2.COLOR_BGR2LAB)
        for ch in range(3):
            lab[:, :, ch] = cv2.LUT(lab[:, :, ch], luts[ch])
        out = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)
        cv2.imwrite(os.path.join(tmp_dir, f"{i:05d}.png"), out)

    fps = 24
    silent_mp4 = os.path.join(tmp_dir, "silent.mp4")
    subprocess.run([
        "ffmpeg", "-y", "-v", "error", "-framerate", str(fps),
        "-i", os.path.join(tmp_dir, "%05d.png"), "-c:v", "libx264", "-crf", "14",
        "-pix_fmt", "yuv420p", silent_mp4], check=True)

    # 保留原视频音轨（H3 自带生成语音），若无音轨则 -map 0:a 自动忽略
    subprocess.run([
        "ffmpeg", "-y", "-v", "error", "-i", silent_mp4, "-i", video_in,
        "-map", "0:v:0", "-map", "1:a:0?", "-c:v", "libtheora", "-q:v", "7",
        "-c:a", "libvorbis", "-q:a", "5", video_out], check=True)
    print("SAVED", video_out, os.path.getsize(video_out), "bytes")


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else r"D:\123\qianyuanshaonv\assets\animations\deepseek_smile_h3_v2.mp4"
    dst = sys.argv[2] if len(sys.argv) > 2 else r"D:\123\qianyuanshaonv\assets\animations\deepseek_smile.ogv"
    process(src, dst)
