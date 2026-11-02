"""让 gemini-3.8 逐首听配乐并给出评价。

做法：从每首 ogg 取 30 秒转成 mp3，把音频直接喂给本机转发服务上的 gemini-3.8-flash-high，
要它回答速度、调性、主奏乐器、动机、情绪与评分，最后汇总打印。

转发服务地址与密钥取自 D:\\CLIProxyAPI\\bin\\config.yaml，只在内存里使用，不打印、不落盘。
用法：python tools\\music_judge.py [槽 id ...]
"""

import base64
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "audio", "music")
TMP = os.path.join(os.environ.get("TEMP", "."), "abyss_music_judge")
CONFIG = r"D:\CLIProxyAPI\bin\config.yaml"
ENDPOINT = "http://127.0.0.1:8317/v1/chat/completions"
MODEL = "gemini-3.8-flash-high"

CUES = {
    "menu": ("主菜单", "温暖、有归属感，D 大调，约 72 BPM，毛毡钢琴奏五音动机，几乎无鼓"),
    "hangar": ("飞空艇机库", "温暖安全，D 大调，约 78 BPM，钢片琴与圆润贝斯"),
    "greyport_explore": ("灰港市探索", "升 F 小调，压抑空旷，无鼓无终止式"),
    "ironbelt_explore": ("铁锈工业带探索", "C 小调，冷峻，工业机械质感"),
    "dustfield_explore": ("尘土平原探索", "D 小调，空旷荒凉，风与稀疏拨弦"),
    "redlake_explore": ("赤湖新区探索", "升 G 小调，水感回声，平静而不安"),
    "canyon_explore": ("裂谷矿区探索", "E 小调，幽闭压迫，低频嗡鸣"),
    "combat": ("战斗中", "E 持续低音，推进鼓组，紧张，可无缝循环"),
    "boss": ("Boss 战", "升 C 弗里吉亚，失真低铜管，压迫感"),
    "extract": ("撤离读条", "急促十六分音符，紧张短循环"),
    "result_success": ("结算成功", "D 大调弦乐，希望与收束感，不循环"),
    "result_fail": ("结算失败", "音乐盒放慢截断，哀而不煽，不循环"),
}


def api_key():
    text = open(CONFIG, encoding="utf-8", errors="replace").read()
    m = re.search(r'api-keys:\s*\n\s*-\s*"?([^"\n]+)"?', text)
    if not m:
        raise RuntimeError("config.yaml 里没找到 api-keys")
    return m.group(1).strip()


def excerpt(src, dst, seconds=30):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-ss", "0", "-t", str(seconds), "-i", src,
                    "-c:a", "libmp3lame", "-b:a", "96k", "-ac", "1", dst],
                   capture_output=True, timeout=300)
    return os.path.exists(dst) and os.path.getsize(dst) > 1000


def judge(key, audio_b64, cue_desc, want):
    ask = ("这是一首游戏背景音乐的片段。设计意图是：%s。请仔细听后用中文回答，每项一行：\n"
           "1. 速度大约多少 BPM\n2. 大调还是小调\n3. 主奏乐器\n4. 有没有反复出现的五音动机\n"
           "5. 情绪描述，以及是否符合设计意图\n6. 1 到 10 分打几分，理由一句话\n"
           "7. 循环使用时首尾有没有明显断点或爆音" % want)
    body = {"model": MODEL, "messages": [{"role": "user", "content": [
        {"type": "text", "text": ask},
        {"type": "input_audio", "input_audio": {"data": audio_b64, "format": "mp3"}},
    ]}], "max_completion_tokens": 700}
    req = urllib.request.Request(ENDPOINT, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + key}, method="POST")
    with urllib.request.urlopen(req, timeout=240) as r:
        return json.load(r)["choices"][0]["message"]["content"]


def main(argv):
    key = api_key()
    want_ids = argv or list(CUES.keys())
    report = {}
    for cue in want_ids:
        src = os.path.join(MUSIC, cue + ".ogg")
        if not os.path.exists(src):
            print("缺文件", cue, flush=True)
            continue
        dst = os.path.join(TMP, cue + "_30.mp3")
        if not excerpt(src, dst):
            print("转码失败", cue, flush=True)
            continue
        b64 = base64.b64encode(open(dst, "rb").read()).decode()
        label, want = CUES.get(cue, (cue, ""))
        try:
            text = judge(key, b64, label, want)
            report[cue] = text
            print("=== %s（%s）\n%s\n" % (cue, label, text), flush=True)
        except urllib.error.HTTPError as e:
            print("=== %s 请求失败 HTTP %s %s" % (cue, e.code, e.read()[:200].decode("utf-8", "replace")), flush=True)
        except Exception as e:
            print("=== %s 失败 %r" % (cue, e)[:200], flush=True)
    print(json.dumps({"judged": list(report.keys())}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
