# -*- coding: utf-8 -*-
"""H3 微笑视频完成后：抽首帧/中帧/尾帧三帧拼图供审阅。"""
import subprocess
import sys

VID = r"D:\123\qianyuanshaonv\assets\animations\deepseek_smile.mp4"
OUT = r"D:\123\qianyuanshaonv\review\deepseek_smile_h3_frames.png"

if len(sys.argv) > 1:
    VID = sys.argv[1]

# 取总时长后抽 3 帧：0.5s / 2.5s / 4.5s
for i, t in enumerate(["0.5", "2.5", "4.5"]):
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", t, "-i", VID,
                    "-frames:v", "1", rf"D:\123\qianyuanshaonv\review\_ds_smile_f{i}.png"], check=True)

from PIL import Image
frames = [Image.open(rf"D:\123\qianyuanshaonv\review\_ds_smile_f{i}.png") for i in range(3)]
w, h = frames[0].size
sheet = Image.new("RGB", (w * 3 + 40, h + 20), (20, 20, 20))
for i, f in enumerate(frames):
    sheet.paste(f, (10 + i * (w + 10), 10))
sheet.save(OUT)
print("saved", OUT, sheet.size)
