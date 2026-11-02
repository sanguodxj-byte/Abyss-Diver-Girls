"""
虫族与虫巢的音效配方：跳虫尖细急促，酸液虫湿黏带咕嘟声，甲虫低沉厚重，虫巢是湿润的搏动。
"""
import numpy as np
from sfx_dsp import (sfx, SR, ns, tt, white, pink, brown, smooth_noise, lp, hp, bp, peak, reson, sweep, sine, harm,
                     expdec, ad, env, ahr, sat, space, Mix)
from sfx_lib import (place, norm, att, fold, thump, crack, burst, clank, tick, rattle, hiss, whoosh, debris, voice,
                     chitter, bubble, bubbles, slime, crunch, bug_hiss, scrabble, HEAVY)

LING_F = ((2600.0, 6.0), (4800.0, 7.0))
SPIT_F = ((900.0, 4.0), (2200.0, 5.0))
BEET_F = ((450.0, 3.0), (1100.0, 4.0))


# ---------------------------------------------------------------- 跳虫
@sfx("bug_ling_appear", n=3, target=-18.5, dur=1.0, fout=0.1)
def ling_appear(c):
    rng = c.rng
    v = c.v
    m = Mix()
    if v < 2:
        m.add(scrabble(rng, 0.45, 50.0), 0.0, 0.5)
    t0 = 0.3 if v < 2 else 0.0
    f0 = [1050.0, 950.0, 1200.0][v]
    m.add(voice(rng, 0.42, [(0, f0 * 0.75), (0.45, f0 * 1.45), (1.0, f0 * 0.9)], 0.03, (0.04, c.r(28, 38)), 0.45, 80.0,
                LING_F, 0.35, "pulse", 0.2, 1.6, 0.0, [(0, 0), (0.04, 1.0), (0.3, 0.7), (0.42, 0.0)]), t0, 0.8)
    m.add(chitter(rng, 0.25, 40.0, (3000.0, 6000.0)), t0 + 0.38 if v != 1 else 0.05, 0.35)
    return space(m.render(), "yard", 0.12, False, v)


@sfx("bug_ling_windup", n=2, target=-19.0, dur=0.4, fout=0.05)
def ling_windup(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(bug_hiss(rng, 0.24, 2500.0, 9000.0, (3800.0, 6500.0), (0.4, 60.0), [(0, 0), (0.2, 1.0), (0.24, 0.0)]), 0.0, 0.7)
    m.add(chitter(rng, 0.2, 55.0, (3500.0, 6500.0)), 0.03, 0.4)
    f0 = [1500.0, 1700.0][v]
    m.add(voice(rng, 0.18, [(0, f0), (1.0, f0 * 1.3)], 0.02, (0.03, 40.0), 0.3, 80.0, LING_F, 0.4, "pulse", 0.2, 1.4,
                0.0, [(0, 0), (0.12, 1.0), (0.18, 0.0)]), 0.06, 0.4)
    return space(m.render(), "yard", 0.1, False, v)


@sfx("bug_ling_attack", n=3, target=-17.5, dur=0.45, fout=0.05)
def ling_attack(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(whoosh(rng, 0.1, 1500.0, 6000.0, 0.6, 2.5, 0.0), 0.0, 0.7)
    m.add(crack(rng, 0.04, 0.004, 3000.0), 0.06, 0.6)
    m.add(tick(rng, c.r(3500, 5500), 0.004, 0.03), 0.065, 0.4)
    f0 = [1800.0, 1600.0, 2000.0][v]
    m.add(voice(rng, 0.14, [(0, f0), (0.3, f0 * 1.2), (1.0, f0 * 0.85)], 0.03, (0.03, 35.0), 0.5, 90.0, LING_F, 0.35,
                "pulse", 0.2, 1.8, 0.0, [(0, 0), (0.01, 1.0), (0.1, 0.5), (0.14, 0.0)]), 0.05, 0.55)
    if v == 2:
        m.add(whoosh(rng, 0.12, 1800.0, 5500.0, 0.6, 2.5, 0.0), 0.12, 0.4)
    return space(m.render(), "yard", 0.1, False, v)


@sfx("bug_ling_hurt", n=3, target=-18.0, dur=0.4, fout=0.04)
def ling_hurt(c):
    rng = c.rng
    v = c.v
    m = Mix()
    f0 = [1400.0, 1250.0, 1600.0][v]
    m.add(voice(rng, 0.22, [(0, f0), (0.25, f0 * 1.6), (1.0, f0 * 0.8)], 0.04, (0.05, 30.0), 0.6, 70.0, LING_F, 0.3,
                "pulse", 0.2, 2.0, 0.0, [(0, 0), (0.008, 1.0), (0.12, 0.6), (0.22, 0.0)]), 0.0, 0.8)
    m.add(crunch(rng, 0.08, 15, 0.02, 1500.0, 8000.0, 0.2, 500.0), 0.0, 0.35)
    return space(m.render(), "yard", 0.1, False, v)


@sfx("bug_ling_death", n=3, target=-17.5, dur=1.2, fout=0.15)
def ling_death(c):
    rng = c.rng
    v = c.v
    m = Mix()
    f0 = [1500.0, 1350.0, 1700.0][v]
    m.add(voice(rng, 0.55, [(0, f0 * 1.3), (0.15, f0 * 1.5), (1.0, f0 * 0.35)], 0.06, (0.08, 22.0), 0.75, 50.0, LING_F,
                0.4, "pulse", 0.2, 2.0, 0.0, [(0, 0), (0.01, 1.0), (0.3, 0.6), (0.55, 0.0)]), 0.0, 0.8)
    m.add(crunch(rng, 0.15, 35, 0.04, 1200.0, 9000.0, 0.4, 420.0), 0.0, 0.6)
    m.add(slime(rng, 0.25, 2800.0, 300.0, 2.0, 0.07, 0.5), 0.02, 0.5)
    m.add(bubbles(rng, 0.4, 25.0, 500.0, 1500.0, 0.15), 0.3, 0.2)
    for k in range(int(c.r(2, 4))):
        m.add(tick(rng, c.r(2500, 4500), 0.004, 0.03), c.r(0.5, 0.9), 0.15)
    return space(m.render(), "yard", 0.12, False, v)


# ---------------------------------------------------------------- 酸液虫
@sfx("bug_spitter_appear", n=2, target=-18.5, dur=1.2, fout=0.12)
def spitter_appear(c):
    rng = c.rng
    v = c.v
    m = Mix()
    if v == 0:
        m.add(scrabble(rng, 0.4, 40.0), 0.0, 0.45)
    t0 = 0.25 if v == 0 else 0.0
    m.add(bubbles(rng, 0.8, 30.0, 180.0, 700.0, 0.15), t0, 0.5)
    f0 = [330.0, 290.0][v]
    m.add(voice(rng, 0.7, [(0, f0), (0.5, f0 * 1.5), (1.0, f0 * 1.1)], 0.03, (0.05, 18.0), 0.5, 45.0, SPIT_F, 0.25,
                "saw", 0.2, 1.8, 0.0, [(0, 0), (0.08, 1.0), (0.5, 0.8), (0.7, 0.0)]), t0 + 0.05, 0.7)
    m.add(bug_hiss(rng, 0.5, 2000.0, 8000.0, (3200.0, 5500.0), (0.5, 25.0)), t0 + 0.35, 0.35)
    m.add(chitter(rng, 0.2, 30.0, (2200.0, 4500.0)), t0 + 0.6, 0.25)
    return space(m.render(), "yard", 0.12, False, v)


@sfx("bug_spitter_windup", n=2, target=-18.5, dur=0.6, fout=0.05)
def spitter_windup(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(bubbles(rng, 0.45, 30.0, 250.0, 900.0, 0.3, [(0, 0.2), (0.4, 1.0), (0.45, 0.0)]), 0.0, 0.7)
    f0 = [260.0, 230.0][v]
    m.add(voice(rng, 0.45, [(0, f0), (1.0, f0 * 1.9)], 0.02, (0.06, 14.0), 0.4, 40.0, SPIT_F, 0.2, "saw", 0.2, 1.6,
                0.0, [(0, 0), (0.38, 1.0), (0.45, 0.0)]), 0.0, 0.6)
    n = ns(0.3)
    m.add(norm(sweep(white(n, rng), "bp", np.geomspace(500.0, 2500.0, n), 2.0)) * np.linspace(0, 1, n) ** 2, 0.15, 0.25)
    m.add(tick(rng, 1800.0, 0.006, 0.03, 0.8), 0.44, 0.3)
    return space(m.render(), "yard", 0.1, False, v)


@sfx("bug_spitter_attack", n=3, target=-17.0, dur=0.7, fout=0.08)
def spitter_attack(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(burst(rng, 0.12, 0.03, 300.0, 3000.0, -3.0, 0.002, 1.5), 0.0, 0.8)
    m.add(thump(rng, [190.0, 170.0, 210.0][v], 80.0, 0.15, 0.035, 0.012, 1.4, 0.0), 0.0, 0.6)
    m.add(slime(rng, 0.2, [2400.0, 2000.0, 2800.0][v], 500.0, 1.8, 0.06, 0.5), 0.005, 0.7)
    m.add(hiss(rng, 0.45, 2500.0, 10000.0, 0.01, 0.05, 0.35, (4000.0, 7000.0), 3.0, 0.3), 0.03, 0.3)
    m.add(bubbles(rng, 0.25, 40.0, 600.0, 2000.0, 0.2), 0.04, 0.25)
    return space(m.render(), "yard", 0.1, False, v)


@sfx("bug_spitter_hurt", n=3, target=-18.0, dur=0.5, fout=0.05)
def spitter_hurt(c):
    rng = c.rng
    v = c.v
    m = Mix()
    f0 = [520.0, 470.0, 580.0][v]
    m.add(voice(rng, 0.3, [(0, f0), (0.3, f0 * 1.6), (1.0, f0 * 0.9)], 0.04, (0.06, 20.0), 0.6, 50.0, SPIT_F, 0.3,
                "saw", 0.2, 2.0, 0.0, [(0, 0), (0.01, 1.0), (0.18, 0.6), (0.3, 0.0)]), 0.0, 0.8)
    m.add(bubbles(rng, 0.2, 40.0, 300.0, 1200.0, 0.2), 0.03, 0.3)
    m.add(slime(rng, 0.12, 2200.0, 500.0, 2.0, 0.03, 0.4), 0.0, 0.35)
    return space(m.render(), "yard", 0.1, False, v)


@sfx("bug_spitter_death", n=2, target=-17.0, dur=1.5, fout=0.2)
def spitter_death(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(slime(rng, 0.4, 2600.0, 200.0, 1.4, 0.12, 0.7), 0.0, 1.0)
    m.add(thump(rng, 150.0, 55.0, 0.3, 0.07, 0.02, 1.8, 0.3), 0.0, 0.7)
    m.add(burst(rng, 0.2, 0.05, 200.0, 4000.0, -3.0, 0.002, 1.5), 0.0, 0.5)
    n = ns(1.1)
    sz = hiss(rng, 1.1, 2500.0, 11000.0, 0.05, 0.4, 0.6, (4200.0, 7400.0), 3.0)
    m.add(sz * (0.6 + 0.4 * np.abs(smooth_noise(n, rng, 30.0))), 0.04, 0.35)
    m.add(voice(rng, 0.7, [(0, 380.0), (0.2, 420.0), (1.0, 150.0)], 0.05, (0.08, 12.0), 0.7, 35.0, SPIT_F, 0.2,
                "saw", 0.2, 1.8, 0.0, [(0, 0), (0.05, 1.0), (0.4, 0.5), (0.7, 0.0)]), 0.06 + 0.1 * v, 0.5)
    m.add(bubbles(rng, 0.9, 25.0, 200.0, 900.0, 0.15, [(0, 1.0), (0.9, 0.0)]), 0.1, 0.4)
    return space(m.render(), "yard", 0.12, False, v)


# ---------------------------------------------------------------- 甲虫
@sfx("bug_beetle_appear", n=2, target=-17.0, dur=1.4, fout=0.15)
def beetle_appear(c):
    rng = c.rng
    v = c.v
    m = Mix()
    f0 = [85.0, 75.0][v]
    m.add(voice(rng, 0.9, [(0, f0), (0.4, f0 * 1.35), (1.0, f0 * 0.9)], 0.05, (0.05, 9.0), 0.7, 30.0, BEET_F, 0.1,
                "saw", 0.2, 2.2, 0.6, [(0, 0), (0.12, 1.0), (0.6, 0.8), (0.9, 0.0)], 60.0), 0.0, 0.9)
    n = ns(0.8)
    grind = bp(white(n, rng), 250.0, 1500.0) * (np.abs(smooth_noise(n, rng, 18.0)) * 2.0) ** 1.5
    m.add(norm(grind) * ahr(n, 0.05, 0.4, 0.35), 0.1, 0.45)
    for k in range(3):
        m.add(thump(rng, 95.0, 45.0, 0.3, 0.07, 0.02, 1.8, 0.4), 0.25 + 0.28 * k, 0.45)
    m.add(chitter(rng, 0.25, 22.0, (1200.0, 2600.0), 0.006), 0.85 if v == 0 else 0.3, 0.3)
    return space(sat(m.render(), 1.3), "yard", 0.14, False, v)


@sfx("bug_beetle_windup", n=2, target=-17.5, dur=0.6, fout=0.05)
def beetle_windup(c):
    rng = c.rng
    v = c.v
    m = Mix()
    n = ns(0.45)
    creak = bp(white(n, rng), 300.0, 1800.0) * (np.abs(smooth_noise(n, rng, 25.0)) * 2.0) ** 2
    m.add(norm(creak) * env([(0, 0.1), (0.4, 1.0), (0.45, 0.0)], n), 0.0, 0.5)
    f0 = [70.0, 80.0][v]
    m.add(voice(rng, 0.45, [(0, f0), (1.0, f0 * 1.6)], 0.04, (0.05, 11.0), 0.6, 30.0, BEET_F, 0.15, "saw", 0.2, 2.0,
                0.5, [(0, 0), (0.38, 1.0), (0.45, 0.0)], 60.0), 0.0, 0.8)
    m.add(clank(rng, 900.0, 0.02, HEAVY, 0.1, 0.8, 0.3), 0.4, 0.3)
    return space(m.render(), "yard", 0.12, False, v)


@sfx("bug_beetle_attack", n=2, target=-14.5, dur=1.1, fout=0.15)
def beetle_attack(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(whoosh(rng, 0.08, 200.0, 1200.0, 0.8, 1.2, -3.0), 0.0, 0.5)
    t0 = 0.06
    m.add(thump(rng, [85.0, 75.0][v], 32.0, 0.6, 0.15, 0.04, 2.6, 0.5), t0, 0.34)
    m.add(crunch(rng, 0.2, 50, 0.06, 800.0, 7000.0, 0.6, 300.0), t0, 0.8)
    m.add(debris(rng, 0.7, 40.0, 0.2, 500.0, 4000.0, 0.5), t0 + 0.01, 0.45)
    m.add(voice(rng, 0.2, [(0, 110.0), (1.0, 80.0)], 0.05, (0.0, 1.0), 0.6, 30.0, BEET_F, 0.1, "saw", 0.2, 2.2, 0.5,
                [(0, 0), (0.02, 1.0), (0.2, 0.0)], 60.0), t0 - 0.02, 0.4)
    return space(sat(m.render(), 1.5), "yard", 0.16, False, v)


@sfx("bug_beetle_hurt", n=3, target=-17.0, dur=0.6, fout=0.06)
def beetle_hurt(c):
    rng = c.rng
    v = c.v
    m = Mix()
    f0 = [110.0, 100.0, 125.0][v]
    m.add(voice(rng, 0.3, [(0, f0), (0.3, f0 * 1.5), (1.0, f0 * 0.85)], 0.05, (0.05, 10.0), 0.7, 30.0, BEET_F, 0.1,
                "saw", 0.2, 2.2, 0.5, [(0, 0), (0.015, 1.0), (0.2, 0.5), (0.3, 0.0)], 60.0), 0.0, 0.8)
    m.add(crunch(rng, 0.1, 25, 0.03, 900.0, 7000.0, 0.5, 320.0), 0.0, 0.45)
    return space(sat(m.render(), 1.3), "yard", 0.12, False, v)


@sfx("bug_beetle_death", n=2, target=-15.0, dur=2.0, fout=0.25)
def beetle_death(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(voice(rng, 1.3, [(0, 120.0), (0.15, 135.0), (1.0, 45.0)], 0.07, (0.1, 7.0), 0.85, 25.0, BEET_F, 0.15,
                "saw", 0.2, 2.2, 0.6, [(0, 0), (0.03, 1.0), (0.6, 0.6), (1.3, 0.0)], 50.0), 0.0, 0.8)
    m.add(crunch(rng, 0.3, 70, 0.1, 600.0, 7000.0, 0.7, 260.0), 0.0, 0.6)
    m.add(thump(rng, 90.0, 35.0, 0.5, 0.12, 0.03, 2.2, 0.4), 0.95 + 0.1 * v, 0.7)
    m.add(debris(rng, 0.6, 30.0, 0.2, 400.0, 3000.0, 0.6), 0.97 + 0.1 * v, 0.3)
    m.add(bubbles(rng, 0.7, 18.0, 120.0, 500.0, 0.1, [(0, 1.0), (0.7, 0.0)]), 1.05, 0.25)
    m.add(bug_hiss(rng, 0.7, 1500.0, 7000.0, (2500.0, 4500.0), (0.3, 8.0)), 1.1, 0.2)
    return space(sat(m.render(), 1.3), "yard", 0.14, False, v)


# ---------------------------------------------------------------- 虫巢
@sfx("nest_loop", n=1, target=-21.0, loop=4.2, reps=4)
def nest_loop(c):
    """一遍两次心跳（每次「咚—咚」两拍），间隔与虫巢外观的脉动周期接近。"""
    rng = c.rng
    p = c.period
    one = np.zeros(p + ns(0.8))
    for t0 in (0.0, 2.1):
        place(one, thump(rng, 78.0, 42.0, 0.45, 0.12, 0.05, 2.6, 0.0), t0, 1.0)
        place(one, thump(rng, 88.0, 46.0, 0.4, 0.1, 0.05, 2.6, 0.0), t0 + 0.24, 0.7)
        place(one, slime(rng, 0.3, 1400.0, 200.0, 1.5, 0.1, 0.6), t0 + 0.02, 0.45)
    for _ in range(3):
        place(one, chitter(rng, 0.3, 30.0, (2500.0, 5000.0), 0.003), rng.uniform(0.3, c.loop - 0.3), 0.06)
    beat = np.tile(fold(one, p), c.reps)
    churn = bp(np.tile(pink(p, rng), c.reps), 150.0, 900.0) * (1.0 + 0.4 * c.plfo(0.5))
    bub = bubbles(rng, c.total / SR, 9.0, 220.0, 1100.0, 0.1, None, p)
    x = 0.9 * norm(beat) + 0.3 * norm(churn) + 0.45 * norm(bub)
    return space(x, "nest", 0.25, False, 0)


@sfx("nest_spawn", n=2, target=-17.5, dur=1.3, fout=0.15)
def nest_spawn(c):
    rng = c.rng
    v = c.v
    m = Mix()
    n = ns(0.35)
    stretch = bp(white(n, rng), 300.0, 1500.0) * (np.abs(smooth_noise(n, rng, 20.0)) * 2.0) ** 2
    m.add(norm(stretch) * env([(0, 0.1), (0.35, 1.0)], n), 0.0, 0.4)
    m.add(voice(rng, 0.35, [(0, 70.0), (1.0, 95.0)], 0.04, (0.04, 8.0), 0.5, 25.0, BEET_F, 0.1, "saw", 0.2, 1.8, 0.4,
                [(0, 0), (0.3, 1.0), (0.35, 0.0)], 50.0), 0.0, 0.4)
    n2 = ns(0.18)
    tear = bp(white(n2, rng), 600.0, 4000.0) * (np.abs(smooth_noise(n2, rng, 70.0)) * 2.2) ** 1.5
    m.add(norm(tear) * ahr(n2, 0.005, 0.1, 0.07), 0.35, 0.7)
    m.add(slime(rng, 0.35, 2400.0, 250.0, 1.5, 0.1, 0.7), 0.4, 0.9)
    m.add(thump(rng, 120.0, 55.0, 0.25, 0.06, 0.02, 1.4, 0.0), 0.4, 0.5)
    f0 = [1700.0, 1500.0][v]
    m.add(voice(rng, 0.2, [(0, f0 * 0.8), (0.5, f0 * 1.2), (1.0, f0)], 0.03, (0.04, 35.0), 0.4, 80.0, LING_F, 0.3,
                "pulse", 0.2, 1.5, 0.0, [(0, 0), (0.03, 1.0), (0.2, 0.0)]), 0.62, 0.45)
    return space(m.render(), "nest", 0.18, False, v)


@sfx("nest_hurt", n=2, target=-17.5, dur=0.9, fout=0.1)
def nest_hurt(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(thump(rng, [95.0, 85.0][v], 45.0, 0.3, 0.07, 0.02, 1.6, 0.0), 0.0, 0.55)
    m.add(slime(rng, 0.25, 1800.0, 250.0, 1.5, 0.08, 0.6), 0.0, 0.7)
    n = ns(0.5)
    sh = voice(rng, 0.5, [(0, 75.0), (0.4, 95.0), (1.0, 60.0)], 0.05, (0.15, 13.0), 0.6, 20.0, BEET_F, 0.1, "saw", 0.2,
               1.6, 0.4, [(0, 0), (0.04, 1.0), (0.5, 0.0)], 50.0)
    m.add(sh, 0.02, 0.45)
    m.add(bubbles(rng, 0.4, 25.0, 200.0, 800.0, 0.15), 0.05, 0.3)
    return space(m.render(), "nest", 0.2, False, v)


@sfx("nest_destroyed", n=1, target=-14.5, dur=2.6, fout=0.3)
def nest_destroyed(c):
    """与 explosion 同时触发：这里是巢体破裂、汁液喷溅与幼虫的哀鸣。"""
    rng = c.rng
    m = Mix(2.6)
    m.add(slime(rng, 0.6, 2400.0, 150.0, 1.2, 0.2, 0.8), 0.0, 1.0)
    m.add(thump(rng, 90.0, 30.0, 0.8, 0.2, 0.04, 2.2, 0.4), 0.0, 0.6)
    m.add(crunch(rng, 0.35, 70, 0.12, 500.0, 6000.0, 0.6, 220.0), 0.0, 0.5)
    for k in range(4):
        f0 = c.r(1100.0, 1700.0)
        m.add(voice(rng, 0.9, [(0, f0), (0.2, f0 * 1.15), (1.0, f0 * 0.45)], 0.05, (0.07, c.r(18, 30)), 0.6, 60.0,
                    LING_F, 0.3, "pulse", 0.2, 1.6, 0.0, [(0, 0), (0.05, 1.0), (0.5, 0.5), (0.9, 0.0)]),
              0.1 + 0.12 * k, 0.25)
    m.add(bubbles(rng, 1.8, 30.0, 150.0, 900.0, 0.15, [(0, 1.0), (1.8, 0.0)]), 0.2, 0.4)
    m.add(hiss(rng, 1.4, 2000.0, 10000.0, 0.05, 0.3, 1.0, (3800.0, 6600.0), 3.0), 0.15, 0.25)
    return space(m.render(), "nest", 0.22, False, 0)
