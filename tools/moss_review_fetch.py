# -*- coding: utf-8 -*-
"""
下载 MOSS 审核图：按 prompt_id 从 /history 取产物，落到 review\\ 目录。
"""
import json
import os
import urllib.parse
import urllib.request

with open("D:/123/qianyuanshaonv/tools/art_host.txt", "r", encoding="utf-8") as f:
    BASE = f.read().strip()

IDS = "D:/123/qianyuanshaonv/tools/deepseek_review_ids.json"
OUT = "D:/123/qianyuanshaonv/review"
os.makedirs(OUT, exist_ok=True)

with open(IDS, "r", encoding="utf-8") as f:
    ids = json.load(f)

with urllib.request.urlopen(BASE + "/history", timeout=30) as r:
    history = json.loads(r.read().decode())

ready = 0
for tag, pid in ids.items():
    dst = os.path.join(OUT, "deepseekchan_%s.png" % tag)
    if os.path.exists(dst):
        ready += 1
        continue
    if pid not in history:
        print("[等待] %s" % tag)
        continue
    outs = history[pid].get("outputs", {})
    info = None
    for node_out in outs.values():
        for img in node_out.get("images", []):
            if img.get("filename", "").endswith(".png"):
                info = img
                break
        if info:
            break
    if not info:
        print("[无产物] %s" % tag)
        continue
    params = urllib.parse.urlencode({
        "filename": info["filename"],
        "subfolder": info.get("subfolder", ""),
        "type": info.get("type", "output"),
    })
    urllib.request.urlretrieve(BASE + "/view?" + params, dst)
    print("[下载] %s -> %s" % (tag, dst))
    ready += 1

print("就绪 %d/%d" % (ready, len(ids)))
