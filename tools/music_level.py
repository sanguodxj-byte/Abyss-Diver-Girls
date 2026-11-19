"""按曲目单的响度目标校正每一首，并用限幅器兜住真峰。

单遍 loudnorm 的结果会和目标差 1 到 2 dB，这里按实测值补一次增益，
再用 alimiter 把真峰压到 -1.5 dBFS，最后复测打印。

用法：python tools\\music_level.py
"""

import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "audio", "music")

# 曲目单里的目标响度（除 boss 外均为带长留白的低存在感平缓铺底）
TARGET = {
    "menu": -27, "hangar": -27,
    "greyport_explore": -28, "ironbelt_explore": -28, "dustfield_explore": -28,
    "redlake_explore": -28, "canyon_explore": -28, "abyss_maw_explore": -28,
    "combat": -25, "extract": -25,
    "result_success": -26, "result_fail": -27,
    "boss": -18,
}


def measure(path):
    p = subprocess.run(["ffmpeg", "-i", path, "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
                       capture_output=True, text=True, errors="replace")
    vals = re.findall(r"I:\s*(-?\d+\.\d+)\s*LUFS", p.stderr)
    return float(vals[-1]) if vals else None


def apply_gain(path, delta_db):
    tmp = path + ".lvl.ogg"
    # -1.5 dBFS = 0.841，先加增益再限幅
    af = "volume=%.2fdB,alimiter=limit=0.841:level=false" % delta_db
    proc = subprocess.run(["ffmpeg", "-y", "-i", path, "-af", af, "-c:a", "libvorbis", "-q:a", "6", tmp],
                          capture_output=True, text=True, errors="replace")
    if proc.returncode != 0 or not os.path.exists(tmp):
        raise RuntimeError("处理失败：" + (proc.stderr or "")[-200:])
    os.replace(tmp, path)


def main():
    bad = 0
    for f in sorted(glob.glob(os.path.join(MUSIC, "*.ogg"))):
        cue = os.path.basename(f)[:-4]
        target = TARGET.get(cue)
        now = measure(f)
        if target is None or now is None:
            print("%-20s 跳过（没有目标或测不到）" % cue)
            continue
        delta = target - now
        if abs(delta) >= 0.5:
            apply_gain(f, delta)
            after = measure(f)
        else:
            after = now
        ok = after is not None and abs(after - target) <= 1.0
        if not ok:
            bad += 1
        print("%-20s 原 %6.1f → 目标 %d → 现 %s %s" % (cue, now, target,
                                                     ("%.1f" % after) if after is not None else "?", "OK" if ok else "偏差仍大"))
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
