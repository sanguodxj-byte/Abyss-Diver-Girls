"""
机甲底盘、落地、技能、护盾、机甲状态、能源与消耗品的音效配方。
"""
import numpy as np
from sfx_dsp import (sfx, SR, ns, tt, white, pink, brown, lp, hp, bp, peak, reson, sweep, sine, harm, fm, saw_amps,
                     square_amps, expdec, ad, env, ahr, sat, crush, space, Mix)
from sfx_lib import (place, norm, att, fold, thump, crack, burst, modal, clank, tick, rattle, scrape, servo, hiss,
                     whoosh, debris, tone, chime, roar, crackle, turbine, engine, arc, buzz, crunch, PLATE, BAR, TUBE,
                     HEAVY, BELL)


# ---------------------------------------------------------------- 底盘
@sfx("step_biped", n=4, target=-17.0, dur=0.6, fout=0.06)
def step_biped(c):
    """四个变体的落脚方式不同：整足踏地、脚跟脚尖两段着地、沉重拖擦、金属件碰响。"""
    rng = c.rng
    v = c.v
    m = Mix()
    if v == 0:
        m.add(thump(rng, 88.0, 42.0, 0.4, 0.09, 0.025, 2.2, 0.35), 0.0, 0.4)
        m.add(crunch(rng, 0.12, 30, 0.04, 600.0, 6000.0, 0.3, 250.0), 0.0, 0.75)
        m.add(clank(rng, 480.0, 0.05, HEAVY, 0.3, 0.5, 0.6), 0.004, 0.55)
    elif v == 1:
        m.add(thump(rng, 105.0, 52.0, 0.25, 0.05, 0.015, 1.8, 0.4), 0.0, 0.3)
        m.add(thump(rng, 82.0, 40.0, 0.4, 0.09, 0.025, 2.2, 0.3), 0.042, 0.4)
        m.add(clank(rng, 530.0, 0.05, HEAVY, 0.3, 0.5, 0.6), 0.044, 0.6)
        m.add(crunch(rng, 0.1, 22, 0.03, 700.0, 6000.0, 0.3, 260.0), 0.04, 0.6)
    elif v == 2:
        m.add(thump(rng, 74.0, 34.0, 0.5, 0.13, 0.035, 2.6, 0.3), 0.0, 0.4)
        m.add(crunch(rng, 0.2, 50, 0.07, 400.0, 5000.0, 0.5, 200.0), 0.0, 0.85)
        m.add(scrape(rng, 0.16, 300.0, 2500.0, 40.0, None, 30.0, [(0, 0), (0.02, 1.0), (0.16, 0.0)]), 0.03, 0.3)
        m.add(clank(rng, 420.0, 0.06, HEAVY, 0.3, 0.5, 0.6), 0.004, 0.45)
    else:
        m.add(thump(rng, 112.0, 55.0, 0.3, 0.065, 0.018, 2.0, 0.4), 0.0, 0.42)
        m.add(clank(rng, 610.0, 0.07, PLATE, 0.4, 0.7, 0.4), 0.002, 0.7)
        m.add(rattle(rng, 0.22, 60.0, 1500.0, 4500.0, 0.06), 0.02, 0.25)
        m.add(crunch(rng, 0.08, 15, 0.03, 900.0, 6000.0, 0.2, 300.0), 0.0, 0.3)
    m.add(hiss(rng, 0.22, 2500.0, 9000.0, 0.005, 0.02, 0.15, (3600.0, 6000.0), 4.0, 0.4), 0.035, [0.07, 0.05, 0.06, 0.12][v])
    m.add(servo(rng, 0.16, [520.0, 560.0, 480.0, 600.0][v], 380.0, 0.15, 0.01, 5.0, 0.2), 0.05, 0.06)
    m.add(debris(rng, 0.3, 30.0, 0.08, 1500.0, 5000.0, 0.1), 0.01, 0.12)
    return space(sat(m.render(), 1.3), "yard", 0.12, False, v)


@sfx("step_quad", n=4, target=-18.0, dur=0.45, fout=0.05)
def step_quad(c):
    """四足落地：轻快的爪尖着地，变体分别为单点、爪尖加足垫两段、偏沉、偏金属。"""
    rng = c.rng
    v = c.v
    m = Mix()
    if v == 1:
        m.add(tick(rng, 2800.0, 0.006, 0.04, 0.6), 0.0, 0.45)
        m.add(thump(rng, 140.0, 66.0, 0.25, 0.05, 0.015, 1.8, 0.4), 0.024, 0.45)
        m.add(clank(rng, 1300.0, 0.025, PLATE, 0.15, 0.7, 0.3), 0.024, 0.5)
    elif v == 2:
        m.add(thump(rng, 112.0, 50.0, 0.3, 0.07, 0.02, 2.0, 0.3), 0.0, 0.5)
        m.add(crunch(rng, 0.12, 30, 0.04, 700.0, 6000.0, 0.4, 240.0), 0.0, 0.5)
        m.add(clank(rng, 1000.0, 0.025, PLATE, 0.15, 0.7, 0.3), 0.0, 0.3)
    elif v == 3:
        m.add(thump(rng, 150.0, 72.0, 0.2, 0.04, 0.012, 1.6, 0.4), 0.0, 0.32)
        m.add(clank(rng, 1250.0, 0.045, PLATE, 0.25, 0.7, 0.3), 0.0, 0.8)
        m.add(modal(rng, 2300.0, BAR, 0.06, 0.25, 0.02, 0.8, 0.6), 0.003, 0.25)
    else:
        m.add(thump(rng, 130.0, 60.0, 0.25, 0.05, 0.015, 1.8, 0.4), 0.0, 0.45)
        m.add(clank(rng, 1150.0, 0.025, PLATE, 0.15, 0.7, 0.3), 0.0, 0.55)
    m.add(crunch(rng, 0.08, 18, 0.025, 1000.0, 7000.0, 0.2, 300.0), 0.002, 0.3)
    f0 = [700.0, 760.0, 650.0, 820.0][v]
    m.add(servo(rng, 0.12, f0, f0 * 1.35, 0.08, 0.03, 4.0, 0.2), 0.025, [0.12, 0.1, 0.08, 0.2][v])
    m.add(tick(rng, c.r(3500, 5000), 0.003, 0.02), 0.06, 0.15)
    return space(sat(m.render(), 1.2), "yard", 0.1, False, v)


@sfx("legs_tread_loop", n=1, target=-19.0, loop=2.0, reps=4)
def tread_loop(c):
    rng = c.rng
    p = c.period
    n = c.total
    beats = 28
    one = np.zeros(p + ns(0.3))
    for k in range(beats):
        t0 = (k + 0.18 * rng.uniform(-1, 1)) * c.loop / beats % c.loop
        g = rng.uniform(0.5, 1.0) * (1.4 if k % 7 == 0 else 1.0)
        place(one, clank(rng, rng.uniform(650.0, 950.0), 0.02, PLATE, 0.12, 0.8, 0.4), t0, g)
        place(one, burst(rng, 0.05, 0.01, 300.0, 3000.0, -3.0, 0.001), t0, 0.5 * g)
    clat = np.tile(fold(one, p), c.reps)
    eng = engine(rng, n, c.qf(46.0), 0.2, 420.0, 0.5, p)
    rum = lp(np.tile(brown(p, rng), c.reps), 160.0) * (1.0 + 0.3 * c.plfo(4.0))
    sq = reson(np.tile(white(p, rng), c.reps), 1650.0, 40.0) * np.clip(c.plfo(0.8) + 0.2, 0.0, 1.0)
    gr = np.zeros(p + ns(0.2))
    for _ in range(14):
        place(gr, burst(rng, 0.08, 0.015, 500.0, 5000.0, -3.0, 0.002), rng.uniform(0, c.loop), rng.uniform(0.2, 0.6))
    grav = np.tile(fold(gr, p), c.reps)
    x = 0.8 * norm(clat) + 0.45 * norm(eng) + 0.25 * norm(rum) + 0.08 * norm(sq) + 0.3 * norm(grav)
    return space(sat(norm(x), 1.3), "yard", 0.1, False, 0)


@sfx("legs_hover_loop", n=1, target=-20.0, loop=3.0, reps=4)
def hover_loop(c):
    rng = c.rng
    p = c.period
    n = c.total
    t = np.arange(n) / SR
    f1 = c.qf(96.0)
    f2 = f1 + 2.0 / c.loop
    hum = harm(np.full(n, f1), [1.0, 0.55, 0.3, 0.2, 0.12, 0.08]) + 0.7 * harm(np.full(n, f2), [1.0, 0.5, 0.25])
    wh = (np.sin(2 * np.pi * c.qf(2400.0) * t) + 0.5 * np.sin(2 * np.pi * c.qf(3610.0) * t)) * (0.7 + 0.3 * c.plfo(1.5))
    thr = sweep(np.tile(pink(p, rng), c.reps), "bp", 700.0 * (1.0 + 0.25 * c.plfo(0.7)), 0.9)
    air = hp(np.tile(white(p, rng), c.reps), 5000.0) * (0.8 + 0.2 * c.plfo(2.0))
    x = 0.8 * norm(hum) + 0.18 * norm(wh) + 0.55 * norm(thr) + 0.12 * norm(air)
    return space(norm(x), "yard", 0.1, False, 0)


@sfx("mech_land", n=2, target=-15.0, dur=1.0, fout=0.1)
def mech_land(c):
    """变体 1 整机一次砸地；变体 2 先单脚触地、再整机压实，两段着地。"""
    rng = c.rng
    v = c.v
    m = Mix()
    if v == 0:
        m.add(thump(rng, 100.0, 38.0, 0.6, 0.15, 0.03, 2.4, 0.4), 0.0, 0.36)
        m.add(clank(rng, 400.0, 0.08, HEAVY, 0.5, 0.6, 0.8), 0.005, 0.6)
    else:
        m.add(thump(rng, 125.0, 55.0, 0.3, 0.06, 0.02, 2.0, 0.4), 0.0, 0.28)
        m.add(clank(rng, 560.0, 0.05, PLATE, 0.3, 0.6, 0.5), 0.0, 0.4)
        m.add(thump(rng, 84.0, 34.0, 0.6, 0.16, 0.035, 2.6, 0.3), 0.075, 0.36)
        m.add(clank(rng, 380.0, 0.09, HEAVY, 0.5, 0.6, 0.8), 0.078, 0.5)
    m.add(hiss(rng, 0.45, 1500.0, 8000.0, 0.005, 0.05, 0.3, (2800.0, 5200.0), 4.0, 0.5), 0.03, 0.2)
    m.add(crunch(rng, 0.2, 40, 0.06, 500.0, 6000.0, 0.4, 260.0), 0.0, 0.75)
    m.add(rattle(rng, 0.3, 50.0, 1500.0, 4500.0, 0.08), 0.03, 0.2)
    m.add(servo(rng, 0.3, 300.0, 520.0, 0.1, 0.12, 5.0, 0.2), 0.12, 0.12)
    return space(sat(m.render(), 1.4), "yard", 0.15, False, v)


# ---------------------------------------------------------------- 位移技能（冷却 0.9 至 4 秒，时长不超过冷却）
@sfx("skill_dash", n=2, target=-15.0, dur=0.75, fout=0.1)
def skill_dash(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(crack(rng, 0.05, 0.008, 1500.0), 0.0, 0.5)
    m.add(thump(rng, [120.0, 105.0][v], 55.0, 0.25, 0.05, 0.02, 1.6, 0.4), 0.0, 0.6)
    n = ns(0.6)
    t = tt(n)
    jet = sweep(pink(n, rng), "lp", 900.0 + 7000.0 * np.exp(-t / 0.18), 0.7)
    m.add(sat(norm(jet) * ad(n, 0.006, 0.16), 1.5), 0.0, 0.9)
    m.add(tone(np.geomspace([2400.0, 2100.0][v], 900.0, n), 0.6, "saw", 0.15, bright=5000.0), 0.01, 0.12)
    m.add(whoosh(rng, 0.45, 300.0, 2200.0, 0.3, 1.0, -3.0), 0.03, 0.4)
    return space(m.render(), "yard", 0.15, False, v)


@sfx("skill_ram", n=1, target=-14.5, dur=1.2, fout=0.12)
def skill_ram(c):
    rng = c.rng
    n = ns(1.0)
    t = tt(n)
    m = Mix()
    f = 42.0 + 50.0 * (1.0 - np.exp(-t / 0.25))
    m.add(sat(engine(rng, n, f, 0.25, 600.0, 0.6) * ahr(n, 0.03, 0.55, 0.4), 2.0), 0.0, 1.0)
    one = np.zeros(n)
    tk = 0.04
    while tk < 0.9:
        place(one, clank(rng, rng.uniform(650.0, 950.0), 0.02, PLATE, 0.1, 0.8, 0.4), tk, 0.8 * (1.0 - tk))
        tk += 0.09 * np.exp(-tk * 2.2) + 0.035
    m.add(one, 0.0, 0.5)
    m.add(whoosh(rng, 0.8, 120.0, 900.0, 0.5, 0.8, -4.0), 0.05, 0.5)
    m.add(hiss(rng, 0.3, 2000.0, 9000.0, 0.004, 0.03, 0.2, (3500.0, 6000.0), 4.0, 0.3), 0.0, 0.2)
    return space(sat(m.render(), 1.3), "yard", 0.14, False, 0)


@sfx("skill_leap", n=1, target=-15.0, dur=0.9, fout=0.1)
def skill_leap(c):
    rng = c.rng
    m = Mix()
    m.add(hiss(rng, 0.35, 1500.0, 9000.0, 0.003, 0.05, 0.25, (3000.0, 5400.0), 4.0, 0.5), 0.0, 0.6)
    m.add(thump(rng, 110.0, 55.0, 0.3, 0.06, 0.02, 1.8, 0.3), 0.0, 0.8)
    for k in range(4):
        f0 = c.r(650.0, 850.0)
        m.add(servo(rng, 0.14, f0, f0 * 1.5, 0.08, 0.03, 4.0, 0.25), 0.01 + 0.025 * k, 0.18)
    m.add(whoosh(rng, 0.6, 300.0, 2600.0, 0.55, 1.2, -3.0), 0.05, 0.5)
    m.add(modal(rng, 520.0, BAR, 0.12, 0.5, 0.02, 0.8, 0.5), 0.02, 0.2)
    return space(m.render(), "yard", 0.14, False, 0)


@sfx("skill_blink", n=2, target=-15.5, dur=1.0, fout=0.12)
def skill_blink(c):
    rng = c.rng
    v = c.v
    m = Mix()
    n0 = ns(0.12)
    sw = sweep(white(n0, rng), "bp", np.geomspace(800.0, 6000.0, n0), 2.0) * np.linspace(0.0, 1.0, n0) ** 2
    m.add(norm(sw), 0.0, 0.5)
    n1 = ns(0.5)
    t1 = tt(n1)
    fc = 300.0 + [2700.0, 2200.0][v] * np.exp(-t1 / 0.07)
    z = fm(fc, [1.41, 2.5][v], 6.0 * np.exp(-t1 / 0.1) + 0.5) * expdec(n1, 0.12)
    m.add(att(z), 0.12, 0.8)
    m.add(burst(rng, 0.08, 0.012, 2500.0, 12000.0, 0.0, 0.0005), 0.12, 0.5)
    m.add(thump(rng, 160.0, 70.0, 0.15, 0.03, 0.01, 1.2, 0.0), 0.12, 0.4)
    n2 = ns(0.6)
    sh = sum(np.sin(2 * np.pi * f * tt(n2) * (1 + 0.004 * k)) for k, f in enumerate([1200.0, 1800.0, 2400.0, 3010.0]))
    m.add(norm(sh) * ad(n2, 0.02, 0.18) * (0.7 + 0.3 * np.sin(2 * np.pi * 11.0 * tt(n2))), 0.15, 0.18)
    return space(m.render(), "yard", 0.2, False, v)


# ---------------------------------------------------------------- 背部与躯干、动力炉技能
@sfx("skill_missile", n=1, target=-14.0, dur=2.0, fout=0.3)
def skill_missile(c):
    rng = c.rng
    m = Mix(2.0)
    m.add(clank(rng, 600.0, 0.05, HEAVY, 0.3, 0.7, 0.6), 0.0, 0.5)
    m.add(hiss(rng, 0.2, 2000.0, 9000.0, 0.003, 0.02, 0.15, (3500.0, 6000.0), 4.0), 0.0, 0.3)
    for k in range(6):
        t0 = 0.07 + 0.085 * k + c.r(-0.012, 0.012)
        m.add(thump(rng, c.r(150.0, 190.0), 70.0, 0.2, 0.035, 0.012, 1.8, 0.4), t0, 0.55)
        m.add(crack(rng, 0.05, 0.006, 1800.0), t0, 0.35)
        m.add(whoosh(rng, 0.55, c.r(500.0, 700.0), c.r(2500.0, 3500.0), 0.25, 1.4, -2.0), t0 + 0.01, 0.45, c.r(-0.6, 0.6))
    n = ns(1.6)
    m.add(roar(rng, n, 200.0, 4000.0, 20.0, 0.4) * ahr(n, 0.2, 0.4, 0.95), 0.12, 0.35)
    return space(sat(m.render(), 1.3), "yard", 0.22, False, 0)


@sfx("skill_shield", n=1, target=-16.0, dur=1.7, fout=0.3)
def skill_shield(c):
    rng = c.rng
    m = Mix(1.7)
    n = ns(0.5)
    t = tt(n)
    up = fm(220.0 * (1.0 + t / 0.5), 2.0, 2.5 * (1.0 - t / 0.5) + 0.5) * (t / 0.5) ** 1.5
    m.add(up, 0.0, 0.5)
    m.add(thump(rng, 140.0, 60.0, 0.4, 0.1, 0.03, 1.2, 0.0), 0.45, 0.6)
    m.add(chime(880.0, 0.9, 0.35, ((1.0, 1.0), (1.5, 0.5), (2.0, 0.4), (3.0, 0.2))), 0.45, 0.35)
    m.add(arc(rng, 0.25, 500.0, 3000.0, 0.0, 0.6, 8), 0.45, 0.12)
    n2 = ns(1.2)
    t2 = tt(n2)
    hum = sine(np.full(n2, 220.0)) + 0.6 * sine(np.full(n2, 221.5)) + 0.3 * sine(np.full(n2, 440.0))
    m.add(norm(hum) * ad(n2, 0.05, 0.45), 0.48, 0.3)
    return space(m.render(), "yard", 0.18, False, 0)


@sfx("skill_decoy", n=1, target=-16.0, dur=1.6, fout=0.2)
def skill_decoy(c):
    rng = c.rng
    m = Mix(1.6)
    m.add(thump(rng, 220.0, 120.0, 0.15, 0.03, 0.01, 1.4, 0.5), 0.0, 0.6)
    m.add(hiss(rng, 0.15, 2000.0, 9000.0, 0.002, 0.01, 0.1, (3500.0, 6000.0), 4.0), 0.0, 0.3)
    n = ns(1.1)
    t = tt(n)
    fb = 180.0 * (1.08 - 0.16 * t / 1.1)
    prop = harm(fb, saw_amps(30, 1.1)) * (1.0 + 0.3 * np.sin(2 * np.pi * phase_of(fb * 0.5)))
    m.add(lp(norm(prop), 3500.0) * env([(0, 0), (0.05, 1.0), (0.6, 0.6), (1.1, 0.0)], n), 0.03, 0.4)
    for k in range(3):
        m.add(tone(1760.0, 0.06, "sine", 0.03), 0.4 + 0.3 * k, 0.4 * (0.75 ** k))
    return space(m.render(), "yard", 0.2, False, 0)


def phase_of(f):
    return np.concatenate([[0.0], np.cumsum(f[:-1])]) / SR


@sfx("skill_overdrive", n=1, target=-15.0, dur=1.6, fout=0.25)
def skill_overdrive(c):
    rng = c.rng
    m = Mix(1.6)
    m.add(clank(rng, 380.0, 0.08, HEAVY, 0.4, 0.8, 0.8), 0.0, 0.8)
    m.add(arc(rng, 0.15, 900.0, 2000.0, 0.0, 0.5, 7), 0.0, 0.3)
    n = ns(0.9)
    t = tt(n)
    f = 250.0 * (3200.0 / 250.0) ** ((t / 0.9) ** 0.6)
    m.add(tone(f, 0.9, "saw", None, 0.02, bright=6000.0) * env([(0, 0.2), (0.8, 1.0), (0.9, 0.0)], n), 0.02, 0.4)
    ns_ = ns(1.4)
    t2 = tt(ns_)
    bass = harm(np.full(ns_, 55.0), saw_amps(40))
    bass = sweep(bass, "lp", 150.0 + 1600.0 * np.clip(t2 / 0.7, 0, 1), 1.5)
    m.add(norm(bass) * env([(0, 0), (0.1, 0.6), (0.7, 1.0), (1.4, 0.0)], ns_), 0.02, 0.6)
    m.add(clank(rng, 500.0, 0.06, HEAVY, 0.3, 0.6, 0.7), 0.88, 0.6)
    m.add(thump(rng, 120.0, 55.0, 0.3, 0.07, 0.02, 1.8, 0.2), 0.88, 0.6)
    return space(sat(m.render(), 1.6), "yard", 0.15, False, 0)


@sfx("skill_quake", n=1, target=-13.5, dur=1.3, fout=0.2)
def skill_quake(c):
    """与 explosion 同时触发：这里只有机体砸地的液压与结构声，爆炸由 explosion 负责。"""
    rng = c.rng
    m = Mix(1.3)
    m.add(hiss(rng, 0.25, 1500.0, 8000.0, 0.004, 0.03, 0.18, (2800.0, 5200.0), 4.0, 0.5), 0.0, 0.4)
    m.add(thump(rng, 80.0, 28.0, 0.8, 0.22, 0.05, 2.6, 0.4), 0.0, 0.38)
    m.add(crunch(rng, 0.5, 80, 0.2, 300.0, 5000.0, 0.7, 200.0), 0.0, 0.8)
    m.add(clank(rng, 300.0, 0.12, HEAVY, 0.7, 0.6, 0.9), 0.0, 0.5)
    m.add(debris(rng, 1.1, 40.0, 0.35, 400.0, 3500.0, 0.6), 0.05, 0.35)
    return space(sat(m.render(), 1.6), "valley", 0.2, False, 0)


@sfx("skill_charge", n=1, target=-16.0, dur=1.6, fout=0.2)
def skill_charge(c):
    rng = c.rng
    m = Mix(1.6)
    m.add(clank(rng, 700.0, 0.04, PLATE, 0.2, 0.8, 0.5), 0.0, 0.6)
    n = ns(1.1)
    t = tt(n)
    f = 180.0 * (4200.0 / 180.0) ** ((t / 1.1) ** 1.3)
    am = 1.0 + 0.35 * np.sin(2 * np.pi * phase_of(6.0 + 50.0 * t / 1.1))
    w = (sine(f) + 0.3 * sine(2.0 * f) + 0.15 * sine(3.0 * f)) * am
    m.add(norm(w) * env([(0, 0.1), (1.0, 1.0), (1.1, 0.0)], n), 0.03, 0.4)
    m.add(arc(rng, 1.0, 300.0, 2500.0, 0.0, 0.8, 8) * env([(0, 0.2), (0.9, 1.0), (1.0, 0.0)], ns(1.0)), 0.08, 0.1)
    m.add(chime(1568.0, 0.4, 0.15), 1.12, 0.3)
    m.add(chime(2093.0, 0.45, 0.18), 1.2, 0.3)
    m.add(thump(rng, 160.0, 80.0, 0.2, 0.04, 0.01, 1.2, 0.0), 1.12, 0.3)
    return space(m.render(), "yard", 0.16, False, 0)


@sfx("skill_vent", n=1, target=-14.0, dur=1.8, fout=0.3)
def skill_vent(c):
    """与 explosion 同时触发：高压蒸汽泄放与阀门，热浪的爆裂由 explosion 负责。"""
    rng = c.rng
    m = Mix(1.8)
    m.add(clank(rng, 480.0, 0.06, HEAVY, 0.3, 0.8, 0.7), 0.0, 0.7)
    n = ns(1.5)
    st = hiss(rng, 1.5, 700.0, 12000.0, 0.008, 0.25, 1.1, (2600.0, 4800.0, 7600.0), 3.0, 0.55)
    m.add(sat(st, 1.4), 0.0, 1.0)
    m.add(roar(rng, n, 80.0, 900.0, 10.0, 0.4, -4.0) * ad(n, 0.01, 0.45), 0.0, 0.6)
    for k in range(5):
        m.add(tick(rng, c.r(2500, 4500), 0.008, 0.04), 0.9 + c.r(0.0, 0.8), 0.15)
    return space(m.render(), "yard", 0.18, False, 0)


@sfx("skill_repair", n=1, target=-17.0, dur=2.0, fout=0.3)
def skill_repair(c):
    rng = c.rng
    m = Mix(2.0)
    m.add(whoosh(rng, 0.35, 300.0, 1800.0, 0.6, 1.0, -3.0), 0.0, 0.4)
    for k, f in enumerate([1318.5, 1661.2, 1975.5]):
        m.add(chime(f, 0.5, 0.2), 0.05 + 0.07 * k, 0.3)
    n = ns(1.8)
    tw = np.zeros(n)
    tk = 0.1
    while tk < 1.7:
        place(tw, tick(rng, c.r(4000, 9000), 0.004, 0.02, 0.2), tk, c.r(0.3, 1.0) * (1.0 - tk / 1.8))
        tk += rng.exponential(1.0 / 45.0)
    m.add(tw, 0.0, 0.25)
    m.add(arc(rng, 1.5, 250.0, 3500.0, 0.0, 0.9, 8) * ahr(ns(1.5), 0.1, 0.8, 0.6), 0.15, 0.08)
    m.add(servo(rng, 1.2, 500.0, 900.0, 0.3, 0.4, 6.0, 0.2), 0.2, 0.12)
    return space(m.render(), "yard", 0.18, False, 0)


@sfx("skill_denied", n=1, target=-20.0, dur=0.32, fout=0.02)
def skill_denied(c):
    rng = c.rng
    m = Mix()
    m.add(tick(rng, 2200.0, 0.004, 0.03), 0.0, 0.4)
    m.add(buzz(140.0, 0.26, (2, 0.62), 1500.0), 0.004, 0.7)
    m.add(arc(rng, 0.08, 800.0, 2500.0, 0.0, 0.3, 7), 0.004, 0.12)
    return space(m.render(c.stereo), "cockpit", 0.15, c.stereo, 0)


@sfx("shield_hit", n=3, target=-17.0, dur=0.7, fout=0.08)
def shield_hit(c):
    rng = c.rng
    v = c.v
    m = Mix()
    n = ns(0.4)
    t = tt(n)
    f = [880.0, 1046.0, 784.0][v] * (1.0 + 0.6 * np.exp(-t / 0.02))
    m.add(fm(f, [3.5, 2.76, 4.2][v], 3.0 * np.exp(-t / 0.05) + 0.3) * expdec(n, 0.1), 0.0, 0.6)
    m.add(arc(rng, 0.1, 1500.0, 2500.0, 0.0, 0.3, 8), 0.0, 0.3)
    m.add(crack(rng, 0.04, 0.005, 2000.0), 0.0, 0.4)
    m.add(thump(rng, 180.0, 90.0, 0.12, 0.03, 0.01, 1.0, 0.0), 0.0, 0.35)
    n2 = ns(0.5)
    sh = np.sin(2 * np.pi * 2200.0 * tt(n2)) + np.sin(2 * np.pi * 2213.0 * tt(n2))
    m.add(norm(sh) * ad(n2, 0.01, 0.15), 0.01, 0.12)
    return space(m.render(), "yard", 0.15, False, v)


@sfx("shield_down", n=1, target=-17.0, dur=1.2, fout=0.2)
def shield_down(c):
    rng = c.rng
    m = Mix(1.2)
    n = ns(0.9)
    t = tt(n)
    f = 880.0 * (110.0 / 880.0) ** ((t / 0.9) ** 0.8)
    pad = fm(f, 2.0, 1.5 + t / 0.9 * 2.0) * (1.0 - t / 0.9) ** 1.3
    m.add(pad * (0.75 + 0.25 * np.sin(2 * np.pi * phase_of(14.0 + 10.0 * t / 0.9))), 0.0, 0.6)
    m.add(arc(rng, 0.7, 400.0, 2500.0, 0.0, 0.9, 7) * env([(0, 0.2), (0.4, 1.0), (0.7, 0.0)], ns(0.7)), 0.1, 0.25)
    m.add(burst(rng, 0.1, 0.02, 1500.0, 8000.0, -3.0, 0.002), 0.85, 0.35)
    m.add(thump(rng, 120.0, 60.0, 0.2, 0.05, 0.02, 1.0, 0.0), 0.85, 0.35)
    return space(m.render(), "yard", 0.16, False, 0)


# ---------------------------------------------------------------- 机甲状态（驾驶舱视角，2D 立体声）
@sfx("mech_hurt", n=3, target=-16.0, dur=0.7, fout=0.08)
def mech_hurt(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(thump(rng, [150.0, 130.0, 170.0][v], 60.0, 0.3, 0.06, 0.02, 2.2, 0.5), 0.0, 0.5)
    m.add(crack(rng, 0.05, 0.006, 1500.0), 0.0, 0.4)
    m.add(modal(rng, [240.0, 210.0, 280.0][v], HEAVY, 0.1, 0.5, 0.03, 0.6, 0.5), 0.0, 0.5)
    m.add(rattle(rng, 0.3, 60.0, 1500.0, 4500.0, 0.07), 0.02, 0.25, c.r(-0.5, 0.5))
    if v == 1:
        m.add(crunch(rng, 0.15, 40, 0.05, 1000.0, 7000.0, 0.3, 400.0), 0.0, 0.4)
        m.add(arc(rng, 0.12, 900.0, 3000.0, 0.0, 0.5, 7), 0.04, 0.15, 0.4)
    elif v == 2:
        m.add(scrape(rng, 0.25, 900.0, 4500.0, 50.0, [2100.0, 3300.0], 30.0), 0.02, 0.2, -0.3)
    else:
        m.add(clank(rng, 620.0, 0.06, PLATE, 0.3, 0.6, 0.5), 0.0, 0.4)
    return space(sat(m.render(c.stereo), 1.4), "cockpit", 0.2, c.stereo, v)


@sfx("mech_part_lost", n=1, target=-14.5, dur=1.3, fout=0.15)
def mech_part_lost(c):
    rng = c.rng
    m = Mix(1.3)
    m.add(thump(rng, 120.0, 45.0, 0.5, 0.12, 0.03, 2.4, 0.5), 0.0, 0.5)
    m.add(crunch(rng, 0.3, 70, 0.1, 600.0, 8000.0, 0.5, 300.0), 0.0, 0.6)
    m.add(scrape(rng, 0.5, 700.0, 5000.0, 60.0, [1500.0, 2400.0, 3600.0], 25.0,
                 [(0, 0), (0.03, 1.0), (0.35, 0.6), (0.5, 0.0)]), 0.02, 0.5, 0.3)
    m.add(arc(rng, 0.25, 900.0, 2500.0, 0.0, 0.6, 7), 0.05, 0.3, -0.4)
    m.add(debris(rng, 0.9, 35.0, 0.3, 800.0, 5000.0, 0.4), 0.06, 0.3, 0.5)
    m.add(tone(1320.0, 0.07, "square", 0.03, bright=4000.0), 0.35, 0.18)
    m.add(tone(990.0, 0.1, "square", 0.04, bright=4000.0), 0.45, 0.18)
    return space(sat(m.render(c.stereo), 1.3), "cockpit", 0.22, c.stereo, 0)


@sfx("mech_destroyed", n=1, target=-13.0, dur=3.6, fout=0.4)
def mech_destroyed(c):
    rng = c.rng
    m = Mix(3.6)
    m.add(thump(rng, 90.0, 28.0, 1.4, 0.35, 0.05, 2.6, 0.5), 0.0, 1.0)
    m.add(crack(rng, 0.1, 0.012, 1200.0), 0.0, 0.6)
    n = ns(1.6)
    t = tt(n)
    body = sweep(sat(norm(pink(n, rng)) * ad(n, 0.004, 0.3), 2.2), "lp", 300.0 + 5000.0 * np.exp(-t / 0.15), 0.8)
    m.add(norm(body), 0.0, 0.7)
    for k, (f0, at, pn) in enumerate([(360.0, 0.0, -0.4), (520.0, 0.07, 0.5), (300.0, 0.18, 0.1)]):
        m.add(clank(rng, f0, 0.1, HEAVY, 0.6, 0.5, 0.7), at, 0.5, pn)
    n2 = ns(2.4)
    t2 = tt(n2)
    fr = 75.0 * (6.0 / 75.0) ** ((t2 / 2.4) ** 0.7)
    tb = turbine(rng, n2, fr, 11, 0.5, 0.3)
    m.add(tb * env([(0, 0.0), (0.15, 1.0), (1.6, 0.4), (2.4, 0.0)], n2), 0.1, 0.45)
    m.add(arc(rng, 0.8, 600.0, 2500.0, 0.2, 0.9, 6) * env([(0, 0), (0.1, 1.0), (0.8, 0.0)], ns(0.8)), 0.3, 0.25, 0.3)
    m.add(debris(rng, 2.0, 30.0, 0.6, 500.0, 4000.0, 0.5), 0.1, 0.35, -0.2)
    m.add(hiss(rng, 1.4, 900.0, 7000.0, 0.1, 0.3, 1.0, (2200.0, 4000.0), 3.0, 0.6), 0.5, 0.25, 0.4)
    for k in range(3):
        m.add(tone(440.0, 0.16, "square", 0.08, bright=2500.0), 1.2 + 0.42 * k, 0.12 * (0.7 ** k))
    return space(sat(m.render(c.stereo), 1.5), "cockpit", 0.22, c.stereo, 0)


@sfx("mech_vent", n=1, target=-17.5, dur=1.8, fout=0.25)
def mech_vent(c):
    rng = c.rng
    m = Mix(1.8)
    m.add(clank(rng, 820.0, 0.04, PLATE, 0.2, 0.8, 0.5), 0.0, 0.5)
    m.add(hiss(rng, 1.0, 900.0, 11000.0, 0.01, 0.2, 0.7, (2400.0, 4600.0, 7200.0), 3.0, 0.5), 0.02, 0.8)
    m.add(hiss(rng, 0.6, 1200.0, 9000.0, 0.02, 0.1, 0.45, (3000.0, 5400.0), 3.0, 0.5), 0.95, 0.45)
    m.add(servo(rng, 0.6, 260.0, 480.0, 0.2, 0.2, 5.0, 0.2), 0.3, 0.2)
    m.add(clank(rng, 560.0, 0.05, HEAVY, 0.25, 0.6, 0.6), 0.85, 0.35)
    return space(m.render(), "yard", 0.16, False, 0)


@sfx("energy_low", n=1, target=-17.0, dur=1.2, fout=0.15)
def energy_low(c):
    rng = c.rng
    m = Mix(1.2)
    for k in range(2):
        m.add(tone(1046.5, 0.13, "tri", 0.07, bright=6000.0), 0.0 + 0.5 * k, 0.6)
        m.add(tone(784.0, 0.2, "tri", 0.1, bright=6000.0), 0.16 + 0.5 * k, 0.6)
    n = ns(1.1)
    hum = harm(np.geomspace(120.0, 95.0, n), [1.0, 0.5, 0.3, 0.2])
    m.add(norm(hum) * ahr(n, 0.05, 0.5, 0.5), 0.0, 0.12)
    return space(m.render(c.stereo), "cockpit", 0.25, c.stereo, 0)


@sfx("energy_emergency", n=1, target=-14.0, dur=1.7, fout=0.25)
def energy_emergency(c):
    """主电源断开、系统掉电，随后应急电源的继电器接通；循环告警由同时开始的 energy_alarm_loop 负责，这里不叠警报。"""
    rng = c.rng
    m = Mix(1.7)
    m.add(clank(rng, 330.0, 0.1, HEAVY, 0.5, 0.8, 0.8), 0.0, 0.7)
    m.add(thump(rng, 110.0, 40.0, 0.5, 0.12, 0.03, 2.0, 0.3), 0.0, 0.7)
    n = ns(0.75)
    t = tt(n)
    m.add(tone(900.0 * (60.0 / 900.0) ** ((t / 0.75) ** 0.6), 0.75, "saw", None, 0.005, bright=3000.0), 0.02, 0.4)
    m.add(arc(rng, 0.3, 700.0, 2500.0, 0.0, 0.7, 6), 0.02, 0.22, -0.3)
    m.add(clank(rng, 820.0, 0.04, PLATE, 0.2, 0.8, 0.5), 0.82, 0.45, 0.25)
    m.add(arc(rng, 0.08, 1200.0, 2500.0, 0.0, 0.3, 7), 0.82, 0.15, 0.25)
    n2 = ns(0.8)
    hum = harm(np.full(n2, 62.0), [1.0, 0.6, 0.45, 0.3, 0.2, 0.12])
    m.add(norm(hum) * env([(0, 0), (0.12, 1.0), (0.45, 0.7), (0.8, 0.0)], n2), 0.85, 0.3)
    return space(m.render(c.stereo), "cockpit", 0.25, c.stereo, 0)


@sfx("energy_alarm_loop", n=1, target=-19.0, loop=1.2, reps=4)
def energy_alarm_loop(c):
    one = np.zeros(c.period)
    place(one, tone(880.0, 0.12, "square", None, 0.004, bright=3200.0), 0.0, 0.8)
    place(one, tone(880.0, 0.12, "square", None, 0.004, bright=3200.0), 0.18, 0.8)
    x = np.tile(one, c.reps)
    return space(x, "cockpit", 0.25, False, 0)


@sfx("energy_restored", n=1, target=-16.0, dur=1.6, fout=0.2)
def energy_restored(c):
    rng = c.rng
    m = Mix(1.6)
    m.add(clank(rng, 720.0, 0.04, PLATE, 0.2, 0.8, 0.5), 0.0, 0.6)
    m.add(arc(rng, 0.12, 900.0, 2500.0, 0.0, 0.4, 7), 0.0, 0.25)
    n = ns(0.7)
    t = tt(n)
    m.add(tone(150.0 * (2000.0 / 150.0) ** ((t / 0.7) ** 1.2), 0.7, "saw", None, 0.01, bright=5000.0), 0.03, 0.25)
    n2 = ns(1.2)
    m.add(norm(harm(np.full(n2, 110.0), [1.0, 0.5, 0.3, 0.2])) * env([(0, 0), (0.6, 1.0), (1.2, 0.0)], n2), 0.1, 0.15)
    for k, f in enumerate([1046.5, 1318.5, 1568.0]):
        m.add(chime(f, 0.5, 0.2), 0.62 + 0.09 * k, 0.35, -0.3 + 0.3 * k)
    return space(m.render(c.stereo), "cockpit", 0.25, c.stereo, 0)


# ---------------------------------------------------------------- 消耗品（2D 立体声）
@sfx("use_fuel_cell", n=1, target=-16.0, dur=1.5, fout=0.2)
def use_fuel_cell(c):
    rng = c.rng
    m = Mix(1.5)
    m.add(clank(rng, 560.0, 0.06, HEAVY, 0.3, 0.7, 0.7), 0.0, 0.8, -0.2)
    m.add(thump(rng, 140.0, 70.0, 0.2, 0.04, 0.015, 1.5, 0.3), 0.0, 0.5)
    m.add(tick(rng, 3600.0, 0.004, 0.03), 0.09, 0.4, 0.2)
    m.add(arc(rng, 0.1, 1200.0, 2500.0, 0.0, 0.3, 7), 0.15, 0.3)
    n = ns(0.9)
    t = tt(n)
    f = 90.0 * (2.0 ** (t / 0.9 * 1.5))
    hum = harm(f, [1.0, 0.6, 0.4, 0.25, 0.15]) * (1.0 + 0.25 * np.sin(2 * np.pi * 12.0 * t))
    m.add(norm(hum) * env([(0, 0), (0.1, 0.7), (0.8, 1.0), (0.9, 0.0)], n), 0.18, 0.3)
    m.add(tone(500.0 * (3000.0 / 500.0) ** (t / 0.9), 0.9, "sine", None, 0.05), 0.18, 0.15)
    m.add(tone(1568.0, 0.08, "sine", 0.03), 1.12, 0.3)
    m.add(tone(2093.0, 0.12, "sine", 0.05), 1.2, 0.3)
    return space(m.render(c.stereo), "cockpit", 0.22, c.stereo, 0)


@sfx("use_repair_kit", n=1, target=-17.0, dur=1.7, fout=0.2)
def use_repair_kit(c):
    rng = c.rng
    m = Mix(1.7)
    m.add(tick(rng, 2400.0, 0.006, 0.04), 0.0, 0.5)
    n = ns(0.9)
    t = tt(n)
    spray = bp(white(n, rng), 3000.0, 12000.0) * (0.75 + 0.25 * np.sin(2 * np.pi * 6.5 * t))
    m.add(norm(spray) * ahr(n, 0.03, 0.6, 0.25), 0.05, 0.45, 0.3)
    m.add(arc(rng, 0.7, 350.0, 3000.0, 0.0, 0.9, 8) * ahr(ns(0.7), 0.05, 0.4, 0.25), 0.25, 0.12, -0.3)
    m.add(servo(rng, 0.6, 450.0, 780.0, 0.2, 0.2, 6.0, 0.2), 0.35, 0.18)
    m.add(tone(1318.5, 0.1, "sine", 0.05), 1.15, 0.3)
    m.add(tone(1760.0, 0.16, "sine", 0.07), 1.25, 0.3)
    return space(m.render(c.stereo), "cockpit", 0.2, c.stereo, 0)


@sfx("use_beacon", n=1, target=-15.0, dur=2.6, fout=0.4)
def use_beacon(c):
    rng = c.rng
    m = Mix(2.6)
    m.add(thump(rng, 200.0, 90.0, 0.2, 0.04, 0.015, 1.6, 0.5), 0.0, 0.7)
    m.add(crack(rng, 0.06, 0.008, 1500.0), 0.0, 0.4)
    m.add(whoosh(rng, 0.8, 500.0, 4500.0, 0.25, 1.4, -2.0), 0.02, 0.6)
    n = ns(0.8)
    m.add(roar(rng, n, 300.0, 5000.0, 20.0, 0.4) * ad(n, 0.01, 0.25), 0.02, 0.35)
    for k in range(3):
        t0 = 0.7 + 0.45 * k
        n1 = ns(0.6)
        t1 = tt(n1)
        m.add(fm(np.full(n1, 1320.0), 2.0, 0.8 * np.exp(-t1 / 0.1)) * expdec(n1, 0.16), t0, 0.5 * (0.8 ** k))
    m.add(norm(bp(white(ns(0.18), rng), 1500.0, 5000.0)) * ahr(ns(0.18), 0.005, 0.12, 0.05), 2.1, 0.12, 0.3)
    m.add(tick(rng, 2000.0, 0.005, 0.03), 2.3, 0.2, 0.3)
    return space(m.render(c.stereo), "valley", 0.3, c.stereo, 0)


@sfx("use_denied", n=1, target=-20.0, dur=0.3, fout=0.03)
def use_denied(c):
    rng = c.rng
    m = Mix()
    m.add(thump(rng, 230.0, 150.0, 0.12, 0.025, 0.01, 1.0, 0.4), 0.0, 0.7)
    m.add(tone(330.0, 0.09, "tri", 0.04, bright=3000.0), 0.01, 0.5)
    m.add(tone(247.0, 0.13, "tri", 0.05, bright=3000.0), 0.11, 0.5)
    return space(m.render(c.stereo), "cockpit", 0.15, c.stereo, 0)
