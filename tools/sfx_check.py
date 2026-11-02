#!/usr/bin/env python3
"""
音效技术检查：逐个读取清单登记的 wav，检查格式（44.1 kHz、16 bit）、时长、峰值与真峰值、削波采样数、
首尾采样与尾部残余、直流偏移、起音延迟、循环接缝，以及同一 id 各变体之间的波形相关度；
不合格项打印在最后。加 --timbre 时打印每个 id 的音色数值表；加 --sheets 时另画频谱总览图到 review\\sfx_spec_<分组>.png。
用法：python tools\\sfx_check.py [--timbre] [--sheets]
"""
import os
import sys

import numpy as np
from scipy.io import wavfile
from scipy import signal as sps

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
import sfx_build as B  # noqa: E402
import sfx_dsp as D  # noqa: E402

REVIEW = os.path.join(B.ROOT, "review")
## 需要即时响应的音效：从文件开头到达到峰值一半的时间不得超过 60 毫秒
QUICK = ("wpn_mg_fire", "wpn_shotgun_fire", "wpn_laser_fire", "wpn_flamer_ignite", "wpn_railgun_fire",
         "wpn_arc_fire", "wpn_mortar_fire", "wpn_plasma_fire", "wpn_drone_fire", "hit_", "ui_", "explosion",
         "shield_hit", "skill_denied", "use_denied", "cargo_full", "wpn_empty", "mech_hurt", "step_", "story_text")
GROUPS = [("weapons", ("wpn_",)), ("impact", ("hit_", "explosion", "mech_slam", "mech_land", "step_", "legs_")),
          ("skills", ("skill_", "shield_")), ("mech", ("mech_", "energy_", "use_")),
          ("bugs", ("bug_", "nest_")), ("loot", ("loot_", "cargo_")),
          ("raid", ("drop_", "extract_", "transport_")), ("ui", ("ui_", "hub_", "shop_", "request_")),
          ("boss", ("boss_",)), ("content", ("grow_", "story_", "comm_", "supply_", "distress_", "relay_",
                                             "archive_", "sandstorm_", "weather_", "drone_", "decoy_",
                                             "flare_", "web_", "energy_cell"))]


def read(path):
    sr, q = wavfile.read(path)
    return sr, q, q.astype(np.float64) / 32768.0


def xcorr_max(a, b):
    a = a - a.mean()
    b = b - b.mean()
    na, nb = np.sqrt(np.sum(a * a)), np.sqrt(np.sum(b * b))
    if na == 0 or nb == 0:
        return 1.0
    return float(np.max(np.abs(sps.fftconvolve(a, b[::-1]))) / (na * nb))


def check():
    items = B.read_all()
    bad = []
    rows = []
    for sid, files, d3 in items:
        rc = D.RECIPES.get(sid, {})
        monos = []
        for fn in files:
            p = os.path.join(B.OUT, fn)
            if not os.path.exists(p):
                bad.append("%s 不存在" % fn)
                continue
            sr, q, x = read(p)
            ch = 1 if x.ndim == 1 else x.shape[1]
            m = x if ch == 1 else x.mean(axis=1)
            monos.append(m)
            qm = q if ch == 1 else q.max(axis=1)
            dur = len(x) / sr
            pk = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
            tp = D.true_peak_db(x)
            clip = int(np.sum(np.abs(q.astype(np.int32)) >= 32767))
            dc = float(np.mean(m))
            loop = bool(rc.get("loop"))
            e = np.abs(m)
            onset = float(np.argmax(e >= 0.5 * e.max()) / sr)
            tail = 20 * np.log10(np.sqrt(np.mean(m[-ns(0.005):] ** 2)) + 1e-12) - pk
            seam = D.seam_ratio(x) if loop else None
            row = (fn, sr, q.dtype.name, ch, dur, pk, tp, clip, int(np.abs(qm[0])), int(np.abs(qm[-1])), tail, dc, onset, seam)
            rows.append(row)
            if sr != 44100 or q.dtype != np.int16:
                bad.append("%s 格式 %d Hz %s" % (fn, sr, q.dtype.name))
            if ch != (1 if (d3 or loop) else 2):
                bad.append("%s 声道数 %d 与定位方式不符" % (fn, ch))
            if pk > -0.9 or tp > -0.5:
                bad.append("%s 峰值 %.2f dBFS / 真峰值 %.2f dBTP 过高" % (fn, pk, tp))
            if clip:
                bad.append("%s 有 %d 个满幅采样" % (fn, clip))
            if abs(dc) > 0.002:
                bad.append("%s 直流偏移 %.4f" % (fn, dc))
            if not loop and (row[8] != 0 or row[9] != 0 or tail > -40.0):
                bad.append("%s 首尾未归零（首 %d、尾 %d、尾部 5ms %.1f dB）" % (fn, row[8], row[9], tail))
            if loop and seam > 1.5:
                bad.append("%s 循环接缝跳变比 %.2f" % (fn, seam))
            if loop and abs(m[0]) > 0.05 * np.max(np.abs(m)):
                bad.append("%s 循环起点采样为峰值的 %.3f，起播会从波形中途开始" % (fn, abs(m[0]) / np.max(np.abs(m))))
            if rc.get("dur") and dur > rc["dur"] + 0.001:
                bad.append("%s 时长 %.3f 超过 %.3f" % (fn, dur, rc["dur"]))
            if sid.startswith(QUICK) and onset > 0.06:
                bad.append("%s 起音延迟 %.3f 秒" % (fn, onset))
        for i in range(len(monos)):
            for j in range(i + 1, len(monos)):
                r = xcorr_max(monos[i], monos[j])
                if r > 0.9:
                    bad.append("%s 变体 %d 与 %d 波形相关度 %.2f" % (sid, i + 1, j + 1, r))
    return rows, bad


def ns(sec):
    return int(round(sec * 44100))


BANDS = [("<150", 20.0, 150.0), ("150-600", 150.0, 600.0), ("600-2k", 600.0, 2000.0), ("2k-6k", 2000.0, 6000.0),
         (">6k", 6000.0, 22050.0)]


def descriptor(m, sr):
    """音色数值：频谱质心（Hz）、五个频段的能量占比（%）、高于峰值 -20 dB 的有效时长（秒）。"""
    f, p = sps.welch(m, sr, nperseg=min(4096, len(m)))
    tot = np.sum(p) + 1e-20
    cen = float(np.sum(f * p) / tot)
    bands = [100.0 * float(np.sum(p[(f >= lo) & (f < hi)]) / tot) for _, lo, hi in BANDS]
    e = np.sqrt(np.convolve(m ** 2, np.ones(441) / 441.0, "same"))
    eff = float(np.sum(e > e.max() * 0.1) / sr)
    return cen, bands, eff


def timbre():
    """每个 id 的音色数值（各变体平均）与变体之间的最大波形相关度，用来核对武器、虫种之间与同一 id 变体之间的差别。"""
    print("%-22s %7s %6s %6s %6s %6s %6s %6s %6s" % ("id", "质心Hz", BANDS[0][0], BANDS[1][0], BANDS[2][0],
                                                     BANDS[3][0], BANDS[4][0], "有效s", "变体相关"))
    for sid, files, d3 in B.read_all():
        ds, monos = [], []
        for fn in files:
            sr, q, x = read(os.path.join(B.OUT, fn))
            m = x if x.ndim == 1 else x.mean(axis=1)
            monos.append(m)
            ds.append(descriptor(m, sr))
        cen = np.mean([d[0] for d in ds])
        bands = np.mean([d[1] for d in ds], axis=0)
        eff = np.mean([d[2] for d in ds])
        rs = [xcorr_max(monos[i], monos[j]) for i in range(len(monos)) for j in range(i + 1, len(monos))]
        print("%-22s %7.0f %6.1f %6.1f %6.1f %6.1f %6.1f %6.3f %6s" % (sid, cen, *bands, eff,
                                                                     "%.2f" % max(rs) if rs else "-"))


def sheets(rows):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from PIL import Image
    os.makedirs(REVIEW, exist_ok=True)
    for old in os.listdir(REVIEW):
        if old.startswith("sfx_spec_") and old.endswith(".png"):
            os.remove(os.path.join(REVIEW, old))
    names = [r[0] for r in rows]
    for gname, prefs in GROUPS:
        sel = [n for n in names if n.startswith(prefs)]
        if gname == "mech":
            sel = [n for n in sel if not n.startswith(("mech_slam", "mech_land"))]
        for part in range(0, len(sel), 24):
            chunk = sel[part:part + 24]
            cols = 4
            rws = -(-len(chunk) // cols)
            fig, axs = plt.subplots(rws, cols, figsize=(cols * 4.2, rws * 2.3), dpi=72, squeeze=False)
            for ax in axs.flat:
                ax.axis("off")
            for k, fn in enumerate(chunk):
                sr, q, x = read(os.path.join(B.OUT, fn))
                m = x if x.ndim == 1 else x.mean(axis=1)
                ax = axs.flat[k]
                ax.axis("on")
                f, t, s = sps.spectrogram(m, sr, nperseg=1024, noverlap=896)
                ax.pcolormesh(t, f, 10 * np.log10(s + 1e-12), shading="auto", cmap="magma", vmin=-120, vmax=-30)
                ax.set_yscale("symlog", linthresh=200)
                ax.set_ylim(30, 20000)
                ax.set_xlim(0, len(m) / sr)
                tw = np.arange(len(m)) / sr
                ax2 = ax.twinx()
                ax2.plot(tw, m, color="cyan", lw=0.3, alpha=0.6)
                ax2.set_ylim(-1, 1)
                ax2.set_yticks([])
                ax.set_title(fn, fontsize=8)
                ax.tick_params(labelsize=6)
            fig.tight_layout()
            suffix = "" if len(sel) <= 24 else "_%d" % (part // 24 + 1)
            out = os.path.join(REVIEW, "sfx_spec_%s%s.png" % (gname, suffix))
            fig.savefig(out)
            plt.close(fig)
            Image.open(out).convert("RGB").save(out)


def main(argv):
    rows, bad = check()
    print("%-30s %5s %2s %6s %6s %6s %4s %5s %5s" % ("文件", "Hz", "声道", "时长", "峰值", "真峰", "削波", "起音", "接缝"))
    for r in rows:
        print("%-32s %5d %2d %6.3f %6.2f %6.2f %4d %5.3f %5s" % (r[0], r[1], r[3], r[4], r[5], r[6], r[7], r[12],
                                                              "-" if r[13] is None else "%.2f" % r[13]))
    print("[sfx_check] 检查 %d 个文件，不合格 %d 项" % (len(rows), len(bad)))
    for b in bad:
        print("[sfx_check] 不合格 %s" % b)
    if "--timbre" in argv:
        timbre()
    if "--sheets" in argv:
        sheets(rows)
        print("[sfx_check] 频谱总览图已写入 review")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
