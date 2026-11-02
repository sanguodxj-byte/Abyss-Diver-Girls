#!/usr/bin/env python3
"""
一键重建全部音效：把三处清单合成一张表——scripts\\audio\\audio_registry.gd 的核心 SFX、data\\ext 各文件的 SFX、
以及本文件 LOCAL 里按命名约定使用、没有登记进任何清单的 id（新装备与新地图事件），
按 sfx_*.py 里登记的配方逐个变体合成，统一响度与峰值后写成 44.1 kHz 16 bit wav，
文件名与清单里 files 列出的完全一致，输出到 assets\\audio\\sfx。
按世界位置定位的音效（d3）输出单声道，其余单次音效输出立体声，循环音效一律单声道且首尾无缝。
用法：
  python tools\\sfx_build.py              重建全部
  python tools\\sfx_build.py wpn_ hit_    只重建 id 以这些前缀开头（或等于它）的音效
"""
import os
import re
import sys
import time
from multiprocessing import Pool

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)

import sfx_dsp as D  # noqa: E402
import sfx_weapons  # noqa: E402,F401
import sfx_mech  # noqa: E402,F401
import sfx_bugs  # noqa: E402,F401
import sfx_world  # noqa: E402,F401
import sfx_ui  # noqa: E402,F401
import sfx_content_gear  # noqa: E402,F401
import sfx_content_bugs  # noqa: E402,F401
import sfx_content_boss  # noqa: E402,F401

REGISTRY = os.path.join(ROOT, "scripts", "audio", "audio_registry.gd")
EXT_DIR = os.path.join(ROOT, "data", "ext")
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
ENTRY = re.compile(r'^\s*"([a-z0-9_]+)":\s*\{"files":\s*\[([^\]]*)\](.*)\},?\s*$')

## 没有登记进任何清单、只按命名约定播放的 id：files 为实际输出文件名，
## d3 为真时输出单声道并用世界坐标定位。新装备与新地图事件的音效走这里。
LOCAL = {
	"wpn_railgun_charge": (["wpn_railgun_charge.wav"], True),
	"wpn_railgun_fire": (["wpn_railgun_fire_01.wav", "wpn_railgun_fire_02.wav", "wpn_railgun_fire_03.wav"], True),
	"wpn_arc_fire": (["wpn_arc_fire_01.wav", "wpn_arc_fire_02.wav", "wpn_arc_fire_03.wav"], True),
	"wpn_mortar_fire": (["wpn_mortar_fire_01.wav", "wpn_mortar_fire_02.wav"], True),
	"wpn_drill_ignite": (["wpn_drill_ignite.wav"], True),
	"wpn_drill_loop": (["wpn_drill_loop.wav"], True),
	"wpn_plasma_fire": (["wpn_plasma_fire_01.wav", "wpn_plasma_fire_02.wav"], True),
	"wpn_drone_fire": (["wpn_drone_fire_01.wav", "wpn_drone_fire_02.wav", "wpn_drone_fire_03.wav"], True),
	"drone_deploy": (["drone_deploy.wav"], True),
	"decoy_deploy": (["decoy_deploy.wav"], True),
	"decoy_off": (["decoy_off.wav"], True),
	"flare_ignite": (["flare_ignite.wav"], True),
	"energy_cell_plug": (["energy_cell_plug.wav"], True),
	"web_pulse": (["web_pulse_01.wav", "web_pulse_02.wav"], True),
	"supply_drop_land": (["supply_drop_land_01.wav", "supply_drop_land_02.wav"], True),
	"cargo_crash": (["cargo_crash.wav"], True),
	"distress_beacon": (["distress_beacon.wav"], True),
	"relay_unlock": (["relay_unlock.wav"], True),
	"archive_pickup": (["archive_pickup.wav"], True),
	"sandstorm_start": (["sandstorm_start.wav"], True),
	"sandstorm_end": (["sandstorm_end.wav"], True),
	"weather_rain_loop": (["weather_rain_loop.wav"], True),
}


def _d3_of(rest, d3_default):
    m = re.search(r'"d3":\s*(true|false)', rest)
    return (m.group(1) == "true") if m else d3_default


def read_registry(path=REGISTRY):
    """返回 (条目列表, 前缀默认 d3)：条目为 (id, [文件名], d3)。"""
    text = open(path, encoding="utf-8").read()
    pref = {}
    blk = re.search(r"const PREFIX := \{(.*?)\n\}", text, re.S)
    for m in re.finditer(r'"([a-z0-9_]+)":\s*\{([^}]*)\}', blk.group(1)):
        d = re.search(r'"d3":\s*(true|false)', m.group(2))
        if d:
            pref[m.group(1)] = d.group(1) == "true"
    sfx_blk = re.search(r"const SFX := \{(.*?)\n\}", text, re.S).group(1)
    items = []
    for line in sfx_blk.splitlines():
        m = ENTRY.match(line)
        if not m:
            continue
        sid = m.group(1)
        files = re.findall(r'"([^"]+)"', m.group(2))
        best = max([p for p in pref if sid.startswith(p)], key=len, default="")
        items.append((sid, files, _d3_of(m.group(3), pref.get(best, True))))
    return items


def ext_ids():
    """data\\ext 各文件 SFX 常量里单行登记的 id（只用于列出缺配方的条目）。"""
    out = []
    if not os.path.isdir(EXT_DIR):
        return out
    for fn in sorted(os.listdir(EXT_DIR)):
        if fn.endswith(".gd"):
            for line in open(os.path.join(EXT_DIR, fn), encoding="utf-8"):
                m = ENTRY.match(line)
                if m:
                    out.append(m.group(1))
    return out


def read_ext():
    """data\\ext 各文件 SFX 表里的条目：内容扩展（敌人、Boss、局外成长、剧情）在这里登记音效。
    没有写 d3 的条目按世界坐标定位（单声道），写明 "d3": false 的按 2D（立体声）。"""
    out = []
    if not os.path.isdir(EXT_DIR):
        return out
    for fn in sorted(os.listdir(EXT_DIR)):
        if not fn.endswith(".gd"):
            continue
        text = open(os.path.join(EXT_DIR, fn), encoding="utf-8").read()
        m = re.search(r"const SFX := \{(.*?)\n\}", text, re.S)
        if not m:
            continue
        for line in m.group(1).splitlines():
            e = ENTRY.match(line)
            if not e:
                continue
            out.append((e.group(1), re.findall(r'"([^"]+)"', e.group(2)), _d3_of(e.group(3), True)))
    return out


def read_all():
    """核心清单 + data\\ext 扩展 + LOCAL 未登记 id 的合并结果；同 id 以先出现的为准。"""
    out = []
    seen = set()
    for src in (read_registry(), read_ext()):
        for sid, files, d3 in src:
            if sid in seen:
                continue
            seen.add(sid)
            out.append((sid, files, d3))
    for sid in sorted(LOCAL):
        files, d3 = LOCAL[sid]
        if sid in seen:
            continue
        seen.add(sid)
        out.append((sid, list(files), d3))
    return out


def render(sid, v, stereo):
    rc = D.RECIPES[sid]
    ctx = D.Ctx(sid, v, stereo and not rc["loop"], rc["loop"], rc["reps"])
    x = np.asarray(rc["fn"](ctx), float)
    if not np.all(np.isfinite(x)):
        raise ValueError("%s_%d 输出含非有限值" % (sid, v))
    if rc["loop"]:
        z, st = D.master_loop(x, ctx.period, ctx.reps, rc["target"], max_gr=rc["max_gr"], hpf=rc["hpf"])
        st["seam"] = D.seam_ratio(z)
    else:
        z, st = D.master(x, rc["target"], max_gr=rc["max_gr"], hpf=rc["hpf"], fin=rc["fin"], fout=rc["fout"], dur=rc["dur"])
    st["peak"] = 20.0 * np.log10(np.max(np.abs(z)) + 1e-12)
    st["tp"] = D.true_peak_db(z)
    st["ch"] = 1 if z.ndim == 1 else 2
    return z, st


def _job(args):
    sid, v, fname, stereo = args
    t0 = time.time()
    z, st = render(sid, v, stereo)
    D.write_wav(os.path.join(OUT, fname), z)
    st["sec"] = time.time() - t0
    return fname, sid, {k: float(val) for k, val in st.items()}


def main(argv):
    items = read_all()
    sel = [a for a in argv if not a.startswith("-")]
    missing = []
    jobs = []
    for sid, files, d3 in items:
        if sel and not any(sid == s or sid.startswith(s) for s in sel):
            continue
        rc = D.RECIPES.get(sid)
        if rc is None:
            missing.append("%s（没有配方）" % sid)
            continue
        if rc["n"] != len(files):
            missing.append("%s（配方 %d 个变体，清单 %d 个文件）" % (sid, rc["n"], len(files)))
            continue
        for v, fname in enumerate(files):
            jobs.append((sid, v, fname, not d3))
    os.makedirs(OUT, exist_ok=True)
    t0 = time.time()
    with Pool(max(1, (os.cpu_count() or 2) - 1)) as pool:
        res = pool.map(_job, jobs, chunksize=1)
    print("%-30s %2s %6s %7s %7s %6s %6s %5s %5s" % ("文件", "声道", "时长", "响度", "目标", "峰值", "真峰", "压缩", "接缝"))
    for fname, sid, st in sorted(res):
        seam = "%.2f" % st["seam"] if "seam" in st else "-"
        print("%-32s %2d %6.3f %7.2f %7.1f %6.2f %6.2f %5.1f %5s" % (
            fname, st["ch"], st["dur"], st["lufs"], D.RECIPES[sid]["target"], st["peak"], st["tp"], st["gr"], seam))
    extra = [i for i in ext_ids() if i not in D.RECIPES]
    print("[sfx_build] 写出 %d 个文件，用时 %.1f 秒" % (len(res), time.time() - t0))
    for m in missing:
        print("[sfx_build] 未生成 %s" % m)
    for i in extra:
        print("[sfx_build] 扩展登记的 %s 没有配方" % i)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
