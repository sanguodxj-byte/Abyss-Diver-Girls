"""修复循环曲的首尾接缝：把结尾一段交叉淡入到开头，消掉循环断点。

做法：解码成 wav → 取最后 fade 秒与开头 fade 秒做交叉淡化 → 去掉结尾那段 → 重新编码成 ogg。
只对需要循环的曲子用；一次性曲目（结算成功/失败）不要处理。

用法：python tools\\music_loopfix.py <槽 id> [槽 id ...] [--fade 2.0]
"""

import argparse
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "audio", "music")


def decode(src, dst):
    subprocess.run(["ffmpeg", "-y", "-i", src, "-ac", "2", "-ar", "44100", "-c:a", "pcm_s16le", dst],
                   capture_output=True, timeout=600)


def encode(src, dst):
    tmp = dst + ".tmp.ogg"
    proc = subprocess.run(["ffmpeg", "-y", "-i", src, "-c:a", "libvorbis", "-q:a", "6", tmp],
                          capture_output=True, timeout=600)
    if proc.returncode != 0 or not os.path.exists(tmp):
        raise RuntimeError("编码失败：" + (proc.stderr or b"")[-200:].decode("utf-8", "replace"))
    os.replace(tmp, dst)


def loopfix(path, fade_s, trim_s):
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "in.wav")
        out = os.path.join(td, "out.wav")
        decode(path, wav)
        with wave.open(wav, "rb") as w:
            ch, sr, n = w.getnchannels(), w.getframerate(), w.getnframes()
            raw = w.readframes(n)
        data = np.frombuffer(raw, dtype=np.int16).reshape(-1, ch).astype(np.float64)
        # 先裁掉前奏，让循环从头就落在主律动上
        skip = int(trim_s * sr)
        if skip > 0:
            if skip * 2 >= len(data):
                raise RuntimeError("裁切长度超过文件一半")
            data = data[skip:]
        fade = int(fade_s * sr)
        if fade <= 0 or fade * 2 >= len(data):
            raise RuntimeError("文件太短，无法做 %.1f 秒交叉淡化" % fade_s)
        head = data[:fade].copy()
        tail = data[-fade:]
        t = np.linspace(0.0, 1.0, fade, endpoint=False)[:, None]
        blended = head * t + tail * (1.0 - t)
        data = np.concatenate([blended, data[fade:-fade]])
        data = np.clip(data, -32768, 32767).astype(np.int16)
        with wave.open(out, "wb") as w:
            w.setnchannels(ch)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(data.tobytes())
        encode(out, path)


def main(argv):
    ap = argparse.ArgumentParser(description="修复循环曲首尾接缝")
    ap.add_argument("ids", nargs="+")
    ap.add_argument("--fade", type=float, default=2.0)
    ap.add_argument("--trim", type=float, default=0.0, help="先裁掉开头这么多秒的前奏")
    a = ap.parse_args(argv)
    for cue in a.ids:
        p = os.path.join(MUSIC, cue + ".ogg")
        if not os.path.exists(p):
            print("缺文件", cue)
            continue
        before = os.path.getsize(p)
        loopfix(p, a.fade, a.trim)
        print("已处理", cue, "裁前奏 %.1fs" % a.trim, "淡化 %.1fs" % a.fade,
              "%d KB → %d KB" % (before // 1024, os.path.getsize(p) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
