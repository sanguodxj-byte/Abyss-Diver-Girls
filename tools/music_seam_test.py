"""循环接缝专项听审：把某首曲子的结尾 12 秒与开头 12 秒拼起来，让 gemini-3.8 只听接缝。

用法：python tools\\music_seam_test.py <槽 id> [槽 id ...]
不给 id 时测全部循环曲。
"""

import base64
import json
import os
import re
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "audio", "music")
TMP = os.path.join(os.environ.get("TEMP", "."), "abyss_seam")
CONFIG = r"D:\CLIProxyAPI\bin\config.yaml"
MODEL = "gemini-3.8-flash-high"

LOOPS = ["menu", "hangar", "greyport_explore", "ironbelt_explore", "dustfield_explore",
         "redlake_explore", "canyon_explore", "combat", "boss", "extract"]


def api_key():
    text = open(CONFIG, encoding="utf-8", errors="replace").read()
    m = re.search(r'api-keys:\s*\n\s*-\s*"?([^"\n]+)"?', text)
    if not m:
        raise RuntimeError("config.yaml 里没找到 api-keys")
    return m.group(1).strip()


def build_seam(cue):
    src = os.path.join(MUSIC, cue + ".ogg")
    os.makedirs(TMP, exist_ok=True)
    tail = os.path.join(TMP, cue + "_tail.mp3")
    head = os.path.join(TMP, cue + "_head.mp3")
    out = os.path.join(TMP, cue + "_seam.mp3")
    subprocess.run(["ffmpeg", "-y", "-sseof", "-12", "-i", src, "-t", "12", "-c:a", "libmp3lame", "-b:a", "96k", "-ac", "1", tail], capture_output=True, timeout=300)
    subprocess.run(["ffmpeg", "-y", "-i", src, "-t", "12", "-c:a", "libmp3lame", "-b:a", "96k", "-ac", "1", head], capture_output=True, timeout=300)
    listing = os.path.join(TMP, "list.txt")
    with open(listing, "w", encoding="utf-8") as f:
        f.write("file '%s'\nfile '%s'\n" % (tail.replace("\\", "/"), head.replace("\\", "/")))
    subprocess.run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-c:a", "libmp3lame", "-b:a", "96k", out], capture_output=True, timeout=300)
    return out


def ask(key, path):
    b64 = base64.b64encode(open(path, "rb").read()).decode()
    prompt = ("这是一段循环播放的游戏背景音乐。前 12 秒是原曲结尾，后 12 秒是原曲开头，"
              "两段在第 12 秒处拼接，这个拼接点就是游戏里循环回开头的接缝。只听拼接点附近，用中文回答：\n"
              "1. 拼接点平滑吗？有没有爆音、咔哒声或音量跳变？\n"
              "2. 乐句衔接自然吗？会不会像被剪断或突然重新开始？\n"
              "3. 1 到 10 分给这个接缝打几分？一句话理由。")
    body = {"model": MODEL, "messages": [{"role": "user", "content": [
        {"type": "text", "text": prompt},
        {"type": "input_audio", "input_audio": {"data": b64, "format": "mp3"}},
    ]}], "max_completion_tokens": 400}
    req = urllib.request.Request("http://127.0.0.1:8317/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + key}, method="POST")
    with urllib.request.urlopen(req, timeout=240) as r:
        return json.load(r)["choices"][0]["message"]["content"]


def main(argv):
    key = api_key()
    for cue in (argv or LOOPS):
        src = os.path.join(MUSIC, cue + ".ogg")
        if not os.path.exists(src):
            print("缺文件", cue, flush=True)
            continue
        try:
            print("=== %s\n%s\n" % (cue, ask(key, build_seam(cue))), flush=True)
        except Exception as e:
            print("=== %s 失败 %r" % (cue, e), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
