"""
武器、命中、爆炸与冲撞落地的音效配方。
"""
import numpy as np
from sfx_dsp import (sfx, SR, ns, tt, white, pink, brown, lp, hp, bp, peak, reson, sweep, sine, harm, fm, saw_amps,
                     expdec, ad, env, ahr, sat, asym, crush, space, Mix)
from sfx_lib import (place, norm, att, thump, crack, burst, modal, clank, tick, rattle, scrape, servo, hiss, whoosh,
                     debris, tone, chime, roar, crackle, arc, slime, crunch, bubbles, bug_hiss, PLATE, BAR, TUBE, HEAVY)


def slaps(c, x, times, gains, cut=2500.0):
    """远处建筑反射回来的回声：低通后的延时副本。"""
    m = Mix()
    m.add(x)
    src_ = lp(x if x.ndim == 1 else x.mean(axis=1), cut)
    for t, g in zip(times, gains):
        m.add(src_, c.j(t, 0.1), g)
    return m.render()


# ---------------------------------------------------------------- 开火
@sfx("wpn_mg_fire", n=3, target=-15.0, dur=0.55, fout=0.04)
def mg_fire(c):
    v = c.v
    rng = c.rng
    tune = [1.0, 0.92, 1.08][v]
    m = Mix()
    m.add(crack(rng, 0.05, 0.006 * c.j(1.0, 0.1), 2200.0), 0.0, 0.75)
    m.add(burst(rng, 0.25, 0.028 * c.j(1.0, 0.1), 140.0 * tune, 2600.0 * tune, -3.0, 0.0006, 3.0), 0.0, 1.0)
    m.add(peak(burst(rng, 0.2, 0.02, 200.0, 900.0, -3.0, 0.0005), 260.0 * tune, 2.0, 6.0), 0.0, 0.7)
    m.add(thump(rng, 170.0 * tune, 58.0 * tune, 0.22, 0.045, 0.012, 2.5, 0.0), 0.0, 0.32)
    m.add(clank(rng, 1500.0 * tune, 0.018, PLATE, 0.09, 0.6, 0.2), c.r(0.022, 0.032), 0.16)
    m.add(tick(rng, c.r(3600, 5200), 0.004, 0.03), c.r(0.05, 0.07), 0.08)
    x = sat(m.render(), 1.6)
    x = slaps(c, x, [0.085, 0.16 + 0.02 * v], [0.12, 0.07], 2200.0)
    return space(x, "yard", 0.16, False, c.v)


@sfx("wpn_shotgun_fire", n=3, target=-12.5, dur=1.4, fout=0.15)
def shotgun_fire(c):
    v = c.v
    rng = c.rng
    tune = [1.0, 0.9, 1.06][v]
    m = Mix()
    m.add(crack(rng, 0.09, 0.012, 1600.0), 0.0, 0.85)
    m.add(burst(rng, 0.6, 0.075 * c.j(1.0, 0.1), 70.0 * tune, 1900.0 * tune, -3.0, 0.0008, 3.5), 0.0, 1.0)
    m.add(peak(burst(rng, 0.45, 0.06, 90.0, 600.0, -4.0, 0.001), 130.0 * tune, 1.5, 8.0), 0.0, 0.6)
    m.add(thump(rng, 125.0 * tune, 38.0 * tune, 0.6, 0.12, 0.022, 3.0, 0.0), 0.0, 0.42)
    m.add(hiss(rng, 0.4, 1500.0, 7000.0, 0.01, 0.03, 0.25, (2800.0, 5200.0)), 0.18, 0.08)
    m.add(clank(rng, 900.0 * tune, 0.05, PLATE, 0.3, 0.5, 0.4), c.r(0.24, 0.3), 0.18)
    for k in range(2):
        m.add(tick(rng, c.r(3000, 4200), 0.025, 0.12, 0.3), c.r(0.42, 0.5) + k * c.r(0.07, 0.11), 0.07 - 0.02 * k)
    x = sat(m.render(), 1.4)
    x = slaps(c, x, [0.21, 0.42 + 0.03 * v, 0.66], [0.2, 0.12, 0.06], 1800.0)
    return space(x, "valley", 0.24, False, c.v)


@sfx("wpn_flamer_ignite", n=1, target=-15.0, dur=0.9, fout=0.12)
def flamer_ignite(c):
    rng = c.rng
    n = ns(0.9)
    m = Mix(0.9)
    m.add(tick(rng, 4200.0, 0.003, 0.03, 0.9), 0.0, 0.5)
    m.add(arc(rng, 0.06, 2500.0, 2000.0, 0.0, 0.3, 8), 0.004, 0.25)
    m.add(tick(rng, 3600.0, 0.003, 0.03, 0.9), 0.045, 0.4)
    m.add(thump(rng, 95.0, 40.0, 0.45, 0.12, 0.05, 1.6, 0.2), 0.05, 1.0)
    m.add(whoosh(rng, 0.6, 250.0, 2600.0, 0.35, 0.9, -3.0), 0.05, 0.7)
    body = roar(rng, n, 90.0, 3200.0, 16.0, 0.45) * env([(0, 0), (0.08, 0.2), (0.22, 1.0), (0.55, 0.55), (0.9, 0.0)], n)
    m.add(body, 0.0, 0.8)
    m.add(crackle(rng, n, 30.0, 1500.0, 7000.0) * env([(0, 0), (0.15, 0), (0.3, 1), (0.9, 0.2)], n), 0.0, 0.2)
    x = sat(m.render(), 1.3)
    return space(x, "yard", 0.18, False, c.v)


@sfx("wpn_flamer_loop", n=1, target=-17.0, loop=2.0, reps=4)
def flamer_loop(c):
    rng = c.rng
    n = c.total
    p = c.period
    low = roar(rng, n, 50.0, 260.0, 6.0, 0.35, -6.0, p)
    mid = roar(rng, n, 220.0, 2600.0, 18.0, 0.55, -3.0, p)
    jet = hp(roar(rng, n, 2500.0, 11000.0, 30.0, 0.3, 0.0, p), 2500.0)
    crk = crackle(rng, n, 22.0, 1500.0, 7500.0, p)
    x = 0.55 * norm(low) + 0.85 * norm(mid) + 0.18 * norm(jet) + 0.22 * crk
    x = sat(norm(x), 1.2)
    return space(x, "yard", 0.14, False, 0)


@sfx("wpn_laser_fire", n=3, target=-15.5, dur=0.75, fout=0.08)
def laser_fire(c):
    v = c.v
    rng = c.rng
    tune = [1.0, 0.88, 1.12][v]
    ratio = [1.5, 2.0, 1.414][v]
    m = Mix()
    n0 = ns(0.04)
    pre = sine(np.geomspace(900.0, 4200.0, n0) * tune) * np.linspace(0.0, 1.0, n0) ** 2
    m.add(pre, 0.0, 0.3)
    n1 = ns(0.32)
    t1 = tt(n1)
    fc = (520.0 + 2900.0 * np.exp(-t1 / 0.045)) * tune
    zap = fm(fc, ratio, 4.5 * np.exp(-t1 / 0.06) + 0.3) * expdec(n1, 0.075)
    m.add(att(zap), 0.035, 0.9)
    m.add(burst(rng, 0.05, 0.007, 3000.0, 14000.0, 0.0, 0.0003), 0.035, 0.45)
    m.add(thump(rng, 210.0 * tune, 85.0, 0.14, 0.035, 0.012, 1.2, 0.0), 0.035, 0.4)
    n2 = ns(0.4)
    t2 = tt(n2)
    wh = sine((3800.0 + 900.0 * t2 / 0.4) * tune) * (0.6 + 0.4 * np.sin(2 * np.pi * 34.0 * t2)) * ad(n2, 0.05, 0.12)
    m.add(wh, 0.09, 0.07)
    return space(m.render(), "yard", 0.18, False, c.v)


# ---------------------------------------------------------------- 换弹（时长短于各武器的换弹时间，结束后由 wpn_reload_done 收尾）
@sfx("wpn_mg_reload", n=1, target=-19.0, dur=1.75, fout=0.06)
def mg_reload(c):
    rng = c.rng
    m = Mix(1.75)
    m.add(clank(rng, 1250.0, 0.03, PLATE, 0.15, 0.7, 0.3), 0.0, 0.7)
    m.add(tick(rng, 3800.0, 0.004, 0.03), 0.045, 0.4)
    m.add(servo(rng, 0.35, 380.0, 820.0, 0.12, 0.1, 6.0, 0.25), 0.07, 0.35)
    m.add(scrape(rng, 0.28, 900.0, 4200.0, 50.0, [2100.0, 3300.0], 35.0), 0.1, 0.25)
    m.add(clank(rng, 330.0, 0.09, HEAVY, 0.5, 0.6, 0.8), 0.48, 0.75)
    m.add(thump(rng, 140.0, 70.0, 0.25, 0.05, 0.02, 1.4, 0.3), 0.48, 0.6)
    m.add(rattle(rng, 0.3, 50.0, 1500.0, 4500.0, 0.08), 0.5, 0.2)
    m.add(servo(rng, 0.42, 420.0, 900.0, 0.15, 0.12, 6.0, 0.25), 0.82, 0.35)
    m.add(scrape(rng, 0.3, 800.0, 3800.0, 45.0, [1800.0, 2900.0], 30.0), 0.86, 0.22)
    m.add(clank(rng, 980.0, 0.05, PLATE, 0.25, 0.8, 0.5), 1.27, 0.9)
    m.add(thump(rng, 160.0, 80.0, 0.2, 0.04, 0.015, 1.5, 0.2), 1.27, 0.5)
    m.add(tick(rng, 4200.0, 0.004, 0.03), 1.33, 0.35)
    m.add(rattle(rng, 0.22, 80.0, 2500.0, 6000.0, 0.06, 0.003), 1.4, 0.3)
    m.add(clank(rng, 1600.0, 0.025, PLATE, 0.12, 0.8, 0.3), 1.52, 0.6)
    return space(m.render(), "yard", 0.12, False, 0)


@sfx("wpn_shotgun_reload", n=1, target=-19.0, dur=2.15, fout=0.06)
def shotgun_reload(c):
    rng = c.rng
    m = Mix(2.15)
    m.add(hiss(rng, 0.35, 1800.0, 9000.0, 0.004, 0.04, 0.25, (3000.0, 5600.0), 4.0, 0.5), 0.0, 0.3)
    m.add(clank(rng, 720.0, 0.06, HEAVY, 0.3, 0.7, 0.6), 0.03, 0.85)
    m.add(servo(rng, 0.3, 300.0, 640.0, 0.1, 0.1, 5.0, 0.2), 0.08, 0.25)
    for t0 in (0.4, 0.52):
        m.add(whoosh(rng, 0.12, 900.0, 3000.0, 0.3, 1.2, -3.0), t0, 0.15)
        tb = t0 + c.r(0.2, 0.26)
        for b in range(3):
            m.add(tick(rng, c.r(2400, 3400), 0.02, 0.1, 0.3), tb, 0.3 * (0.55 ** b))
            tb += c.r(0.07, 0.12) * (0.75 ** b)
    for t0 in (1.05, 1.38):
        m.add(scrape(rng, 0.12, 700.0, 3000.0, 60.0, None), t0, 0.15)
        m.add(clank(rng, 1100.0, 0.02, PLATE, 0.1, 0.8, 0.4), t0 + 0.1, 0.55)
        m.add(thump(rng, 180.0, 110.0, 0.12, 0.025, 0.01, 1.2, 0.2), t0 + 0.1, 0.3)
    m.add(servo(rng, 0.3, 320.0, 700.0, 0.1, 0.08, 5.0, 0.2), 1.62, 0.3)
    m.add(clank(rng, 560.0, 0.07, HEAVY, 0.35, 0.8, 0.7), 1.86, 1.0)
    m.add(thump(rng, 130.0, 60.0, 0.25, 0.06, 0.02, 1.8, 0.3), 1.86, 0.65)
    m.add(tick(rng, 3900.0, 0.004, 0.03), 1.93, 0.3)
    return space(m.render(), "yard", 0.12, False, 0)


@sfx("wpn_flamer_reload", n=1, target=-19.0, dur=2.35, fout=0.06)
def flamer_reload(c):
    rng = c.rng
    m = Mix(2.35)
    m.add(tick(rng, 2600.0, 0.006, 0.04), 0.0, 0.5)
    m.add(hiss(rng, 0.4, 1200.0, 7000.0, 0.003, 0.05, 0.3, (2400.0, 4400.0), 4.0, 0.6), 0.02, 0.35)
    m.add(clank(rng, 820.0, 0.05, PLATE, 0.25, 0.7, 0.5), 0.3, 0.7)
    m.add(servo(rng, 0.4, 260.0, 520.0, 0.12, 0.12, 5.0, 0.2), 0.36, 0.25)
    m.add(scrape(rng, 0.35, 500.0, 2800.0, 35.0, [1300.0, 2100.0], 25.0), 0.42, 0.25)
    m.add(modal(rng, 210.0, TUBE, 0.25, 0.9, 0.03, 0.8, 0.4), 0.82, 0.7)
    m.add(thump(rng, 120.0, 65.0, 0.3, 0.06, 0.02, 1.4, 0.3), 0.82, 0.5)
    m.add(modal(rng, 230.0, TUBE, 0.15, 0.6, 0.03, 0.8, 0.4), 1.0, 0.25)
    m.add(servo(rng, 0.45, 280.0, 560.0, 0.15, 0.12, 5.0, 0.2), 1.12, 0.25)
    n = ns(0.55)
    slosh = sweep(pink(n, rng), "bp", 520.0 * (1.0 + 0.5 * np.sin(2 * np.pi * 4.5 * tt(n))), 2.5) * ahr(n, 0.08, 0.2, 0.25)
    m.add(norm(slosh), 1.2, 0.3)
    m.add(bubbles(rng, 0.45, 25.0, 250.0, 900.0, 0.15), 1.25, 0.18)
    m.add(clank(rng, 520.0, 0.08, HEAVY, 0.4, 0.7, 0.7), 1.62, 1.0)
    m.add(thump(rng, 140.0, 70.0, 0.25, 0.05, 0.02, 1.5, 0.3), 1.62, 0.6)
    for t0 in (1.8, 1.9):
        m.add(clank(rng, 1150.0, 0.025, PLATE, 0.12, 0.8, 0.3), t0, 0.5)
    m.add(hiss(rng, 0.35, 900.0, 6000.0, 0.15, 0.05, 0.1, (2000.0, 3600.0), 4.0), 1.98, 0.3)
    m.add(burst(rng, 0.08, 0.02, 1500.0, 7000.0, 0.0, 0.002), 2.2, 0.3)
    return space(m.render(), "yard", 0.12, False, 0)


@sfx("wpn_laser_reload", n=1, target=-19.5, dur=1.95, fout=0.06)
def laser_reload(c):
    rng = c.rng
    m = Mix(1.95)
    m.add(arc(rng, 0.08, 900.0, 2500.0, 0.0, 0.5, 7), 0.0, 0.35)
    m.add(clank(rng, 1300.0, 0.03, PLATE, 0.15, 0.6, 0.4), 0.02, 0.6)
    n = ns(0.45)
    m.add(tone(np.geomspace(2600.0, 380.0, n), 0.45, "tri", 0.15), 0.05, 0.25)
    m.add(thump(rng, 200.0, 90.0, 0.15, 0.03, 0.01, 1.2, 0.3), 0.18, 0.4)
    m.add(clank(rng, 700.0, 0.04, TUBE, 0.25, 0.6, 0.5), 0.55, 0.6)
    m.add(tick(rng, 2600.0, 0.01, 0.05), 0.62, 0.25)
    m.add(servo(rng, 0.4, 420.0, 950.0, 0.13, 0.1, 6.0, 0.2), 0.78, 0.25)
    m.add(clank(rng, 1500.0, 0.025, PLATE, 0.12, 0.8, 0.3), 1.15, 0.8)
    m.add(tick(rng, 4400.0, 0.004, 0.03), 1.2, 0.4)
    n2 = ns(0.7)
    t2 = tt(n2)
    f2 = 300.0 * (3600.0 / 300.0) ** ((t2 / 0.7) ** 0.8)
    ch = (sine(f2) + 0.25 * sine(2.0 * f2)) * (1.0 + 0.3 * np.sin(2 * np.pi * np.cumsum(8.0 + 30.0 * t2 / 0.7) / SR))
    ch *= env([(0, 0.0), (0.05, 0.25), (0.62, 1.0), (0.7, 0.0)], n2)
    m.add(norm(ch), 1.22, 0.18)
    m.add(tone(2800.0, 0.12, "sine", 0.04), 1.78, 0.2)
    return space(m.render(), "yard", 0.12, False, 0)


@sfx("wpn_reload_done", n=2, target=-18.0, dur=0.4, fout=0.04)
def reload_done(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(clank(rng, [880.0, 1040.0][v], 0.035, PLATE, 0.2, 0.8, 0.5), 0.0, 1.0)
    m.add(crack(rng, 0.03, 0.003, 3000.0), 0.0, 0.3)
    f1, f2 = [(1760.0, 2350.0), (1980.0, 2640.0)][v]
    m.add(tone(f1, 0.05, "sine", 0.02), 0.07, 0.22)
    m.add(tone(f2, 0.07, "sine", 0.03), 0.12, 0.22)
    return space(m.render(), "yard", 0.1, False, v)


@sfx("wpn_empty", n=2, target=-19.0, dur=0.35, fout=0.03)
def empty(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(clank(rng, [1350.0, 1180.0][v], 0.012, PLATE, 0.06, 1.0, 0.3), 0.0, 0.8)
    m.add(thump(rng, 260.0, 160.0, 0.06, 0.012, 0.01, 0.8, 0.2), 0.0, 0.5)
    m.add(servo(rng, 0.26, [640.0, 580.0][v], [230.0, 200.0][v], 0.22, 0.001, 5.0, 0.15), 0.03, 0.28)
    m.add(tick(rng, 3200.0, 0.003, 0.02), 0.11, 0.25)
    return space(m.render(), "yard", 0.08, False, v)


# ---------------------------------------------------------------- 命中与爆炸
@sfx("hit_metal", n=4, target=-17.5, dur=0.9, fout=0.05)
def hit_metal(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(crack(rng, 0.04, 0.004, 2500.0), 0.0, 0.7)
    if v == 0:
        m.add(clank(rng, 1700.0, 0.03, PLATE, 0.15, 0.7, 0.2), 0.0, 0.6)
        n = ns(0.45)
        t = tt(n)
        f = 3400.0 * (1.0 - 0.45 * (t / 0.45) ** 0.7) * (1.0 + 0.012 * np.sin(2 * np.pi * 23.0 * t))
        m.add(sine(f) * ad(n, 0.01, 0.12), 0.012, 0.35)
    elif v == 1:
        m.add(clank(rng, 520.0, 0.06, HEAVY, 0.35, 0.6, 0.8), 0.0, 0.9)
        m.add(thump(rng, 200.0, 90.0, 0.15, 0.03, 0.01, 1.5, 0.3), 0.0, 0.5)
        m.add(debris(rng, 0.4, 35.0, 0.12, 1500.0, 5000.0, 0.1), 0.02, 0.2)
    elif v == 2:
        m.add(burst(rng, 0.12, 0.018, 500.0, 6000.0, -3.0, 0.0004), 0.0, 0.8)
        m.add(thump(rng, 240.0, 120.0, 0.08, 0.018, 0.008, 1.2, 0.2), 0.0, 0.4)
        m.add(debris(rng, 0.45, 60.0, 0.1, 1200.0, 6000.0, 0.15), 0.01, 0.4)
        m.add(burst(rng, 0.35, 0.09, 800.0, 6000.0, -3.0, 0.02), 0.02, 0.15)
    else:
        m.add(modal(rng, 2400.0, BAR, 0.28, 0.8, 0.01, 0.9, 0.5), 0.0, 0.5)
        m.add(clank(rng, 1200.0, 0.02, PLATE, 0.1, 0.6, 0.3), 0.0, 0.5)
    return space(sat(m.render(), 1.2), "yard", 0.14, False, v)


@sfx("hit_chitin", n=4, target=-17.5, dur=0.6, fout=0.05)
def hit_chitin(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(crunch(rng, 0.14, [40, 30, 50, 36][v], 0.045, 1200.0, 9000.0, 0.5, [420.0, 360.0, 480.0, 320.0][v]), 0.0, 1.0)
    m.add(slime(rng, 0.22, [3200.0, 2600.0, 3600.0, 2400.0][v], 350.0, 2.0, 0.06, 0.5), 0.008, 0.7)
    m.add(thump(rng, 160.0, 80.0, 0.12, 0.025, 0.01, 1.4, 0.0), 0.0, 0.45)
    if v in (1, 3):
        for k in range(2):
            m.add(bubbles(rng, 0.1, 40.0, 900.0, 2200.0, 0.2), 0.12 + 0.07 * k, 0.15)
    if v == 2:
        m.add(crack(rng, 0.05, 0.006, 3000.0), 0.03, 0.4)
    return space(sat(m.render(), 1.3), "yard", 0.1, False, v)


@sfx("hit_spit", n=2, target=-18.0, dur=0.9, fout=0.12)
def hit_spit(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(slime(rng, 0.3, [2800.0, 2200.0][v], 250.0, 1.6, 0.09, 0.6), 0.0, 1.0)
    m.add(thump(rng, 130.0, 70.0, 0.15, 0.03, 0.012, 1.2, 0.0), 0.0, 0.35)
    for k in range(int(c.r(4, 7))):
        m.add(slime(rng, 0.07, c.r(2500, 4500), c.r(600, 1200), 3.0, 0.015, 0.2), c.r(0.03, 0.2), c.r(0.15, 0.35))
    n = ns(0.75)
    sz = 0.6 * hiss(rng, 0.75, 2200.0, 11000.0, 0.06, 0.15, 0.5, (4200.0, 7400.0), 3.0)
    sz = sz + 0.5 * crackle(rng, n, 120.0, 2500.0, 9000.0) * ahr(n, 0.05, 0.2, 0.45)
    m.add(sz, 0.04, 0.45)
    m.add(bubbles(rng, 0.5, 30.0, 700.0, 2400.0, 0.25), 0.06, 0.14)
    return space(m.render(), "yard", 0.08, False, v)


@sfx("explosion", n=3, target=-11.5, dur=3.2, fout=0.4)
def explosion(c):
    rng = c.rng
    v = c.v
    big = [1.0, 1.15, 0.9][v]
    m = Mix()
    m.add(crack(rng, 0.12, 0.012, 1200.0), 0.0, 0.8)
    m.add(thump(rng, 95.0 / big, 27.0, 1.6, 0.4 * big, 0.06, 2.0, 0.0), 0.0, 0.55)
    n = ns(2.4)
    t = tt(n)
    body = pink(n, rng) * ad(n, 0.004, 0.35 * big) * (1.0 + 0.3 * (np.abs(lp(white(n, rng), 30.0)) * 10.0).clip(0, 1))
    body = sweep(sat(norm(body), 2.5), "lp", 300.0 + 6000.0 * np.exp(-t / (0.18 * big)), 0.8)
    m.add(norm(body), 0.0, 0.9)
    m.add(norm(lp(brown(n, rng), 120.0)) * ad(n, 0.05, 0.9 * big), 0.0, 0.3)
    if v == 1:
        m.add(debris(rng, 2.2, 40.0, 0.7, 500.0, 3500.0, 0.5), 0.1, 0.35)
    elif v == 2:
        m.add(debris(rng, 1.8, 50.0, 0.5, 1500.0, 6000.0, 0.1), 0.08, 0.3)
        m.add(rattle(rng, 0.6, 50.0, 2000.0, 6000.0, 0.2), 0.12, 0.15)
    else:
        m.add(debris(rng, 2.0, 35.0, 0.6, 800.0, 5000.0, 0.3), 0.1, 0.3)
    x = sat(m.render(), 1.6)
    x = slaps(c, x, [0.33 + 0.05 * v, 0.68, 1.05], [0.22, 0.13, 0.07], 1500.0)
    return space(x, "valley", 0.32, False, v)


@sfx("mech_slam", n=2, target=-12.5, dur=1.6, fout=0.2)
def mech_slam(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(thump(rng, [110.0, 95.0][v], 32.0, 0.9, 0.22, 0.04, 2.5, 0.4), 0.0, 0.4)
    m.add(crunch(rng, 0.3, 60, 0.12, 400.0, 6000.0, 0.6, 250.0), 0.0, 0.8)
    m.add(debris(rng, 1.0, 45.0, 0.3, 500.0, 4000.0, 0.5), 0.03, 0.4)
    m.add(clank(rng, [420.0, 360.0][v], 0.1, HEAVY, 0.6, 0.5, 0.8), 0.01, 0.55)
    m.add(whoosh(rng, 0.9, 200.0, 1200.0, 0.2, 0.8, -4.0), 0.02, 0.4)
    m.add(rattle(rng, 0.35, 60.0, 1800.0, 5000.0, 0.1), 0.05, 0.2)
    x = sat(m.render(), 1.5)
    return space(x, "valley", 0.22, False, v)
