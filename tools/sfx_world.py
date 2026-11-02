"""
搜刮、货舱、空投、撤离与运输机的音效配方。
"""
import numpy as np
from sfx_dsp import (sfx, SR, ns, tt, white, pink, brown, smooth_noise, lp, hp, bp, peak, reson, sweep, sine, harm,
                     fm, saw_amps, expdec, ad, env, ahr, sat, space, Mix)
from sfx_lib import (place, norm, att, thump, crack, burst, modal, clank, tick, rattle, scrape, servo, hiss, whoosh,
                     debris, tone, chime, roar, turbine, arc, buzz, slime, crunch, bubbles, voice, PLATE, BAR, TUBE,
                     HEAVY, BELL)


def rustle(rng, dur=0.4, rate=120.0, lo=2000.0, hi=10000.0):
    """塑料布与包装的窸窣声：密集的高频噪声颗粒。"""
    n = ns(dur)
    out = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= dur - 0.02:
            break
        place(out, burst(rng, 0.012, rng.uniform(0.001, 0.004), lo, hi, 0.0, 0.0005), t, rng.uniform(0.2, 1.0))
    return norm(out) * ahr(n, 0.03, dur * 0.5, dur * 0.45)


def creak(rng, dur=0.35, f0=500.0, f1=700.0, grit=35.0):
    """铰链吱呀：基频缓慢滑动的锯齿声，按粘滑颗粒断续发声。"""
    n = ns(dur)
    f = np.geomspace(f0, f1, n)
    x = harm(f, saw_amps(16, 1.2))
    g = np.clip(np.abs(smooth_noise(n, rng, grit)) * 2.5, 0, 1) ** 1.5
    return norm(lp(x * g, 4000.0)) * ahr(n, 0.02, dur * 0.6, dur * 0.35)


# ---------------------------------------------------------------- 打开容器
@sfx("loot_open", n=2, target=-19.0, dur=0.9, fout=0.08)
def loot_open(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(tick(rng, [2600.0, 2300.0][v], 0.006, 0.04), 0.0, 0.5, -0.2)
    m.add(creak(rng, 0.35, [480.0, 420.0][v], [640.0, 520.0][v]), 0.06, 0.25, 0.2)
    m.add(clank(rng, [520.0, 600.0][v], 0.05, PLATE, 0.3, 0.6, 0.6), 0.36, 0.5)
    m.add(debris(rng, 0.3, 30.0, 0.1, 1500.0, 4000.0, 0.2), 0.38, 0.12)
    return space(m.render(c.stereo), "yard", 0.12, c.stereo, v)


@sfx("loot_open_supply", n=1, target=-19.0, dur=0.9, fout=0.08)
def loot_open_supply(c):
    rng = c.rng
    m = Mix()
    m.add(tick(rng, 1800.0, 0.008, 0.05, 0.7), 0.0, 0.5, -0.3)
    m.add(tick(rng, 1700.0, 0.008, 0.05, 0.7), 0.07, 0.5, 0.3)
    m.add(burst(rng, 0.12, 0.03, 1500.0, 9000.0, 0.0, 0.003), 0.12, 0.2)
    m.add(thump(rng, 220.0, 140.0, 0.12, 0.03, 0.01, 1.0, 0.3), 0.2, 0.35)
    m.add(rustle(rng, 0.45, 110.0), 0.25, 0.4, 0.2)
    return space(m.render(c.stereo), "yard", 0.1, c.stereo, 0)


@sfx("loot_open_tool", n=1, target=-18.5, dur=1.0, fout=0.1)
def loot_open_tool(c):
    rng = c.rng
    m = Mix()
    m.add(clank(rng, 1500.0, 0.02, PLATE, 0.1, 0.8, 0.3), 0.0, 0.5, -0.3)
    m.add(clank(rng, 1400.0, 0.02, PLATE, 0.1, 0.8, 0.3), 0.06, 0.5, 0.3)
    m.add(creak(rng, 0.25, 700.0, 900.0, 45.0), 0.12, 0.18)
    m.add(clank(rng, 700.0, 0.06, PLATE, 0.3, 0.5, 0.5), 0.34, 0.5)
    m.add(rattle(rng, 0.5, 70.0, 1500.0, 6000.0, 0.15, 0.006), 0.36, 0.55, 0.15)
    return space(m.render(c.stereo), "yard", 0.12, c.stereo, 0)


@sfx("loot_open_military", n=1, target=-18.0, dur=1.3, fout=0.12)
def loot_open_military(c):
    rng = c.rng
    m = Mix(1.3)
    m.add(clank(rng, 540.0, 0.05, HEAVY, 0.3, 0.8, 0.7), 0.0, 0.8, -0.2)
    m.add(clank(rng, 600.0, 0.05, HEAVY, 0.3, 0.8, 0.7), 0.1, 0.7, 0.2)
    m.add(hiss(rng, 0.4, 1500.0, 9000.0, 0.004, 0.06, 0.28, (3000.0, 5600.0), 4.0, 0.5), 0.17, 0.45)
    m.add(servo(rng, 0.5, 220.0, 420.0, 0.15, 0.15, 5.0, 0.2), 0.25, 0.3)
    m.add(creak(rng, 0.4, 300.0, 380.0, 25.0), 0.3, 0.2)
    m.add(clank(rng, 380.0, 0.08, HEAVY, 0.5, 0.6, 0.8), 0.78, 0.7)
    m.add(thump(rng, 140.0, 70.0, 0.25, 0.05, 0.02, 1.4, 0.3), 0.78, 0.5)
    return space(m.render(c.stereo), "yard", 0.14, c.stereo, 0)


@sfx("loot_open_safe", n=1, target=-18.0, dur=1.5, fout=0.12)
def loot_open_safe(c):
    rng = c.rng
    m = Mix(1.5)
    m.add(scrape(rng, 0.5, 600.0, 4000.0, 30.0, [1100.0, 1700.0, 2600.0], 30.0,
                 [(0, 0), (0.05, 0.6), (0.45, 1.0), (0.5, 0.0)]), 0.0, 0.5, -0.2)
    m.add(creak(rng, 0.45, 260.0, 340.0, 20.0), 0.05, 0.3)
    m.add(crack(rng, 0.06, 0.008, 1500.0), 0.5, 0.6)
    m.add(clank(rng, 620.0, 0.08, HEAVY, 0.4, 0.9, 0.7), 0.5, 0.9)
    m.add(thump(rng, 160.0, 70.0, 0.2, 0.05, 0.015, 1.4, 0.3), 0.5, 0.5)
    m.add(creak(rng, 0.4, 220.0, 260.0, 30.0), 0.62, 0.25, 0.3)
    for k in range(4):
        m.add(modal(rng, c.r(2800.0, 3600.0), BAR, 0.08, 0.3, 0.02, 0.8, 0.6), 0.75 + 0.07 * k + c.r(0, 0.03),
              0.18, c.r(-0.4, 0.4))
    return space(m.render(c.stereo), "yard", 0.14, c.stereo, 0)


@sfx("loot_open_bug", n=1, target=-18.5, dur=1.0, fout=0.1)
def loot_open_bug(c):
    rng = c.rng
    m = Mix()
    m.add(slime(rng, 0.25, 2200.0, 300.0, 1.8, 0.07, 0.5), 0.0, 0.8, -0.2)
    m.add(crunch(rng, 0.12, 30, 0.04, 1200.0, 8000.0, 0.4, 380.0), 0.06, 0.6)
    m.add(slime(rng, 0.3, 1600.0, 400.0, 2.5, 0.1, 0.3), 0.25, 0.6, 0.3)
    m.add(bubbles(rng, 0.4, 25.0, 400.0, 1400.0, 0.2), 0.35, 0.2)
    m.add(tick(rng, 1300.0, 0.012, 0.06, 0.2), 0.7, 0.2)
    return space(m.render(c.stereo), "yard", 0.1, c.stereo, 0)


@sfx("loot_open_nest", n=1, target=-18.5, dur=1.2, fout=0.12)
def loot_open_nest(c):
    rng = c.rng
    m = Mix(1.2)
    m.add(slime(rng, 0.35, 1800.0, 200.0, 1.5, 0.1, 0.7), 0.0, 0.8)
    m.add(crunch(rng, 0.2, 40, 0.06, 900.0, 7000.0, 0.5, 300.0), 0.05, 0.6, -0.2)
    m.add(debris(rng, 0.4, 30.0, 0.15, 700.0, 3500.0, 0.4), 0.1, 0.3, 0.3)
    m.add(voice(rng, 0.25, [(0, 1300.0), (1.0, 700.0)], 0.04, (0.05, 25.0), 0.6, 60.0, ((2600.0, 6.0), (4800.0, 7.0)),
                0.3, "pulse", 0.2, 1.5, 0.0, [(0, 0), (0.02, 1.0), (0.25, 0.0)]), 0.45, 0.15, 0.4)
    m.add(bubbles(rng, 0.6, 20.0, 200.0, 800.0, 0.15), 0.3, 0.2)
    return space(m.render(c.stereo), "nest", 0.14, c.stereo, 0)


# ---------------------------------------------------------------- 物品显现与转移（每件间隔 0.55 秒）
@sfx("loot_reveal", n=3, target=-23.0, dur=0.4, fout=0.05)
def loot_reveal(c):
    rng = c.rng
    v = c.v
    f = [1174.7, 1318.5, 1396.9][v]
    m = Mix()
    m.add(burst(rng, 0.03, 0.006, 3000.0, 10000.0, 0.0, 0.001), 0.0, 0.2)
    m.add(tone(f, 0.08, "tri", 0.035, bright=7000.0), 0.0, 0.6)
    m.add(tone(f * 1.5, 0.12, "sine", 0.05), 0.04, 0.35)
    return space(m.render(c.stereo), "ui", 0.2, c.stereo, v)


@sfx("loot_reveal_rare", n=1, target=-17.5, dur=1.3, fout=0.2)
def loot_reveal_rare(c):
    rng = c.rng
    m = Mix(1.3)
    m.add(whoosh(rng, 0.3, 1500.0, 9000.0, 0.85, 1.5, 0.0), 0.0, 0.3)
    for k, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0]):
        m.add(chime(f, 0.8, 0.3, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.12), (4.07, 0.06))), 0.22 + 0.06 * k, 0.4, -0.45 + 0.3 * k)
    n = ns(1.0)
    sh = sum(np.sin(2 * np.pi * f * tt(n)) for f in (3136.0, 3140.5, 4186.0))
    m.add(norm(sh) * ad(n, 0.05, 0.3) * (0.7 + 0.3 * np.sin(2 * np.pi * 9.0 * tt(n))), 0.3, 0.12)
    m.add(thump(rng, 140.0, 80.0, 0.3, 0.08, 0.02, 1.0, 0.0), 0.22, 0.3)
    return space(m.render(c.stereo), "hangar", 0.18, c.stereo, 0)


@sfx("loot_take", n=2, target=-21.5, dur=0.4, fout=0.04)
def loot_take(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(whoosh(rng, 0.14, [900.0, 1100.0][v], 3800.0, 0.6, 1.5, -3.0), 0.0, 0.4, -0.3)
    m.add(thump(rng, [200.0, 230.0][v], 120.0, 0.12, 0.025, 0.01, 1.0, 0.3), 0.12, 0.6, 0.2)
    m.add(tick(rng, [2200.0, 2500.0][v], 0.008, 0.05, 0.5), 0.125, 0.35, 0.2)
    return space(m.render(c.stereo), "ui", 0.2, c.stereo, v)


@sfx("loot_put", n=1, target=-22.0, dur=0.4, fout=0.04)
def loot_put(c):
    rng = c.rng
    m = Mix()
    m.add(whoosh(rng, 0.14, 3000.0, 900.0, 0.4, 1.5, -3.0), 0.0, 0.4, 0.3)
    m.add(thump(rng, 180.0, 110.0, 0.12, 0.03, 0.01, 1.0, 0.3), 0.11, 0.55, -0.2)
    m.add(tick(rng, 1900.0, 0.01, 0.05, 0.5), 0.115, 0.3, -0.2)
    return space(m.render(c.stereo), "ui", 0.2, c.stereo, 0)


@sfx("loot_close", n=1, target=-20.0, dur=0.5, fout=0.05)
def loot_close(c):
    rng = c.rng
    m = Mix()
    m.add(whoosh(rng, 0.16, 2500.0, 600.0, 0.5, 1.2, -3.0), 0.0, 0.3)
    m.add(clank(rng, 480.0, 0.04, PLATE, 0.25, 0.6, 0.7), 0.13, 0.6)
    m.add(thump(rng, 160.0, 90.0, 0.15, 0.04, 0.012, 1.2, 0.3), 0.13, 0.45)
    m.add(tick(rng, 2300.0, 0.006, 0.04), 0.2, 0.3)
    return space(m.render(c.stereo), "yard", 0.1, c.stereo, 0)


@sfx("cargo_full", n=1, target=-19.5, dur=0.45, fout=0.04)
def cargo_full(c):
    rng = c.rng
    m = Mix()
    m.add(thump(rng, 170.0, 100.0, 0.15, 0.035, 0.01, 1.4, 0.4), 0.0, 0.7)
    m.add(clank(rng, 330.0, 0.03, HEAVY, 0.15, 0.6, 0.6), 0.0, 0.4)
    m.add(buzz(196.0, 0.22, (2, 0.6), 1400.0), 0.05, 0.4)
    return space(m.render(c.stereo), "cockpit", 0.15, c.stereo, 0)


@sfx("cargo_overload", n=1, target=-17.5, dur=1.4, fout=0.15)
def cargo_overload(c):
    rng = c.rng
    m = Mix(1.4)
    n = ns(0.9)
    t = tt(n)
    groan = harm(np.geomspace(150.0, 95.0, n) * (1.0 + 0.02 * smooth_noise(n, rng, 6.0)), saw_amps(30, 1.1))
    groan *= np.clip(np.abs(smooth_noise(n, rng, 14.0)) * 2.5, 0.2, 1.0)
    m.add(norm(lp(groan, 1500.0)) * ahr(n, 0.08, 0.5, 0.3), 0.0, 0.5)
    m.add(creak(rng, 0.6, 210.0, 170.0, 18.0), 0.1, 0.4, 0.3)
    m.add(hiss(rng, 0.5, 1500.0, 7000.0, 0.03, 0.1, 0.35, (2600.0, 4800.0), 4.0, 0.4), 0.2, 0.25, -0.3)
    m.add(clank(rng, 260.0, 0.1, HEAVY, 0.5, 0.6, 0.8), 0.55, 0.45)
    m.add(tone(740.0, 0.14, "square", None, 0.005, bright=3000.0), 0.85, 0.3)
    m.add(tone(740.0, 0.14, "square", None, 0.005, bright=3000.0), 1.05, 0.3)
    return space(m.render(c.stereo), "cockpit", 0.22, c.stereo, 0)


# ---------------------------------------------------------------- 空投（坠落 0.8 秒后反推点火，再 0.6 秒着陆）
@sfx("drop_fall", n=1, target=-15.0, dur=1.5, fout=0.12)
def drop_fall(c):
    rng = c.rng
    n = ns(1.5)
    t = tt(n)
    m = Mix(1.5)
    wind = sweep(pink(n, rng), "bp", 400.0 + 2600.0 * np.clip(t / 0.8, 0, 1) ** 1.5, 0.8)
    wind *= (1.0 + 0.3 * smooth_noise(n, rng, 9.0)) * env([(0, 0.15), (0.8, 1.0), (1.2, 0.55), (1.5, 0.0)], n)
    m.add(norm(wind), 0.0, 0.9)
    m.add(norm(lp(brown(n, rng), 140.0)) * env([(0, 0.2), (0.8, 1.0), (1.5, 0.0)], n), 0.0, 0.5)
    m.add(rattle(rng, 1.3, 70.0, 1200.0, 4500.0, 1.5, 0.005) * env([(0, 0.3), (0.8, 1.0), (1.3, 0.2)], ns(1.3)), 0.05, 0.25)
    m.add(tone(np.geomspace(700.0, 1500.0, ns(1.2)), 1.2, "sine", None, 0.2) * 0.5, 0.0, 0.08)
    return space(m.render(c.stereo), "valley", 0.15, c.stereo, 0)


@sfx("drop_retro", n=1, target=-13.0, dur=1.0, fout=0.25)
def drop_retro(c):
    rng = c.rng
    m = Mix(1.0)
    m.add(crack(rng, 0.08, 0.01, 1200.0), 0.0, 0.6)
    m.add(thump(rng, 110.0, 50.0, 0.3, 0.07, 0.02, 2.0, 0.4), 0.0, 0.7)
    n = ns(0.85)
    body = roar(rng, n, 70.0, 4500.0, 18.0, 0.45, -2.5) * env([(0, 0), (0.01, 1.0), (0.6, 0.95), (0.85, 0.0)], n)
    m.add(sat(norm(body), 1.8), 0.0, 1.0)
    m.add(norm(lp(brown(n, rng), 120.0)) * env([(0, 0), (0.05, 1.0), (0.6, 1.0), (0.85, 0.0)], n), 0.0, 0.5)
    m.add(hiss(rng, 0.7, 4000.0, 14000.0, 0.01, 0.4, 0.25, (6000.0, 9000.0), 3.0), 0.0, 0.2)
    return space(m.render(c.stereo), "valley", 0.2, c.stereo, 0)


@sfx("drop_impact", n=1, target=-12.5, dur=3.0, fout=0.4)
def drop_impact(c):
    rng = c.rng
    m = Mix(3.0)
    m.add(thump(rng, 75.0, 25.0, 1.6, 0.4, 0.06, 2.6, 0.5), 0.0, 0.6)
    m.add(crack(rng, 0.12, 0.014, 1000.0), 0.0, 0.7)
    m.add(crunch(rng, 0.5, 110, 0.2, 300.0, 6000.0, 0.8, 180.0), 0.0, 0.9)
    m.add(clank(rng, 280.0, 0.15, HEAVY, 0.9, 0.6, 0.9), 0.008, 0.6, -0.3)
    m.add(clank(rng, 410.0, 0.1, HEAVY, 0.6, 0.6, 0.7), 0.05, 0.4, 0.4)
    m.add(rattle(rng, 0.6, 60.0, 1500.0, 5000.0, 0.15), 0.03, 0.3)
    m.add(whoosh(rng, 1.4, 150.0, 900.0, 0.12, 0.7, -4.0), 0.02, 0.6, -0.5)
    m.add(whoosh(rng, 1.4, 160.0, 950.0, 0.12, 0.7, -4.0), 0.02, 0.6, 0.5)
    m.add(debris(rng, 2.4, 40.0, 0.8, 400.0, 4000.0, 0.5), 0.15, 0.4, -0.3)
    m.add(debris(rng, 2.4, 40.0, 0.8, 400.0, 4000.0, 0.5), 0.2, 0.4, 0.3)
    x = sat(m.render(c.stereo), 1.6)
    return space(x, "valley", 0.3, c.stereo, 0)


# ---------------------------------------------------------------- 撤离
@sfx("extract_start", n=1, target=-17.0, dur=0.9, fout=0.15)
def extract_start(c):
    rng = c.rng
    m = Mix(0.9)
    m.add(tick(rng, 2600.0, 0.006, 0.04), 0.0, 0.4)
    m.add(tone(880.0, 0.12, "tri", 0.06, bright=7000.0), 0.02, 0.5)
    m.add(tone(1318.5, 0.25, "tri", 0.12, bright=7000.0), 0.14, 0.5)
    n = ns(0.7)
    pad = sum(np.sin(2 * np.pi * f * tt(n)) for f in (659.3, 661.0, 987.8))
    m.add(norm(pad) * env([(0, 0), (0.25, 1.0), (0.7, 0.0)], n), 0.1, 0.18)
    return space(m.render(c.stereo), "cockpit", 0.2, c.stereo, 0)


@sfx("extract_cancel", n=1, target=-18.0, dur=0.6, fout=0.08)
def extract_cancel(c):
    rng = c.rng
    m = Mix()
    m.add(tone(1318.5, 0.1, "tri", 0.05, bright=6000.0), 0.0, 0.5)
    m.add(tone(784.0, 0.22, "tri", 0.1, bright=6000.0), 0.11, 0.5)
    n = ns(0.12)
    m.add(norm(bp(white(n, rng), 1500.0, 6000.0)) * ahr(n, 0.003, 0.08, 0.03), 0.3, 0.2, 0.3)
    m.add(tick(rng, 1800.0, 0.005, 0.03), 0.42, 0.2)
    return space(m.render(c.stereo), "cockpit", 0.2, c.stereo, 0)


@sfx("extract_success", n=1, target=-15.5, dur=2.2, fout=0.35)
def extract_success(c):
    rng = c.rng
    m = Mix(2.2)
    for k, f in enumerate([784.0, 987.8, 1174.7, 1568.0]):
        m.add(chime(f, 1.2, 0.45, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.1))), 0.08 * k, 0.4, -0.3 + 0.2 * k)
    n = ns(1.8)
    pad = sum(np.sin(2 * np.pi * f * tt(n)) for f in (392.0, 393.2, 493.9, 587.3))
    m.add(norm(pad) * env([(0, 0), (0.4, 1.0), (1.0, 0.7), (1.8, 0.0)], n), 0.05, 0.25)
    m.add(clank(rng, 420.0, 0.08, HEAVY, 0.5, 0.6, 0.8), 0.55, 0.45)
    m.add(hiss(rng, 0.6, 1500.0, 8000.0, 0.01, 0.1, 0.4, (2800.0, 5200.0), 4.0, 0.5), 0.6, 0.25, 0.3)
    n2 = ns(0.15)
    m.add(norm(bp(white(n2, rng), 1500.0, 5000.0)) * ahr(n2, 0.003, 0.1, 0.04), 1.3, 0.12, -0.3)
    m.add(tone(1760.0, 0.1, "sine", 0.05), 1.42, 0.2, -0.3)
    return space(m.render(c.stereo), "valley", 0.2, c.stereo, 0)


# ---------------------------------------------------------------- 运输机（3D 单声道）
@sfx("transport_arrive", n=1, target=-14.0, dur=3.2, fout=0.4)
def transport_arrive(c):
    rng = c.rng
    n = ns(3.2)
    t = tt(n)
    m = Mix(3.2)
    fr = 62.0 * (1.0 - 0.18 * np.clip(t / 2.5, 0, 1)) * (1.0 + 0.04 * np.exp(-t / 0.6))
    tb = turbine(rng, n, fr, 13, 0.45, 0.8)
    chop = 1.0 + 0.35 * np.sin(2 * np.pi * np.cumsum(fr * 0.25) / SR)
    m.add(tb * chop * env([(0, 0.0), (0.6, 0.9), (2.4, 1.0), (3.2, 0.55)], n), 0.0, 1.0)
    m.add(norm(lp(brown(n, rng), 150.0)) * env([(0, 0), (1.0, 1.0), (3.2, 0.6)], n), 0.0, 0.5)
    m.add(clank(rng, 380.0, 0.08, HEAVY, 0.5, 0.6, 0.8), 2.5, 0.45)
    m.add(thump(rng, 110.0, 50.0, 0.3, 0.07, 0.02, 1.8, 0.3), 2.5, 0.4)
    m.add(hiss(rng, 0.5, 1500.0, 8000.0, 0.01, 0.1, 0.35, (2800.0, 5200.0), 4.0, 0.5), 2.55, 0.25)
    return space(m.render(), "valley", 0.2, False, 0)


@sfx("transport_idle_loop", n=1, target=-19.0, loop=4.0, reps=4)
def transport_idle_loop(c):
    rng = c.rng
    p = c.period
    n = c.total
    fr = c.qf(50.0)
    tb = turbine(rng, n, fr, 13, 0.35, 0.6, 60.0, 6000.0, p)
    chop = 1.0 + 0.25 * np.sin(2 * np.pi * c.qf(fr * 0.25) * np.arange(n) / SR)
    rum = lp(np.tile(brown(p, rng), c.reps), 140.0) * (1.0 + 0.2 * c.plfo(1.0))
    x = 0.9 * norm(tb * chop) + 0.4 * norm(rum)
    return space(x, "yard", 0.15, False, 0)


@sfx("transport_depart", n=1, target=-14.0, dur=3.4, fout=0.6)
def transport_depart(c):
    rng = c.rng
    n = ns(3.4)
    t = tt(n)
    m = Mix(3.4)
    fr = 50.0 * (1.0 + 0.7 * np.clip(t / 1.4, 0, 1) ** 1.3) * (1.0 + 0.05 * np.clip((t - 1.4) / 2.0, 0, 1))
    tb = turbine(rng, n, fr, 13, 0.5, 0.9)
    chop = 1.0 + 0.3 * np.sin(2 * np.pi * np.cumsum(fr * 0.25) / SR)
    m.add(tb * chop * env([(0, 0.5), (1.2, 1.0), (2.0, 0.85), (3.4, 0.0)], n, True), 0.0, 1.0)
    m.add(norm(lp(brown(n, rng), 160.0)) * env([(0, 0.4), (1.2, 1.0), (3.4, 0.0)], n), 0.0, 0.5)
    m.add(hiss(rng, 0.5, 1500.0, 8000.0, 0.01, 0.1, 0.35, (2800.0, 5200.0), 4.0, 0.5), 0.05, 0.2)
    m.add(clank(rng, 420.0, 0.06, HEAVY, 0.4, 0.6, 0.7), 1.3, 0.3)
    return space(m.render(), "valley", 0.22, False, 0)
