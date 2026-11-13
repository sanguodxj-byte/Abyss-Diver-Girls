# -*- coding: utf-8 -*-
"""机甲底盘步态（履带/双足/四足/六足）、推进闪避、战术技能、护盾、受击损毁与能源反应堆音效（写实重型机械重制版）。"""
import numpy as np
from sfx_dsp import (
    SR, ns, tt, sfx, env_exp, env_adsr, lp, hp, bp, biquad, reson, sweep,
    white, pink, brown, smooth_noise, velvet, sat, asym, place, mix, reverb_tail,
)
from sfx_lib import (
    norm, att, thump, crack, burst, crunch, tick, clank, modal, METAL_HEAVY, METAL_HOLLOW, METAL_LIGHT,
    GLASS_MODES, servo, hiss, whoosh, roar, rumble, zap, buzz, turbine, squelch,
)


# ─────────────────────────────────────────────────────────────
# 底盘移动：双足重型踏步 / 四足与六足机械爪踏步 / 履带碾压循环 / 落地重震
# ─────────────────────────────────────────────────────────────
@sfx("step_biped", n=4, target=-19.5, dur=0.22, fout=0.028)
def _step_biped(v, rng):
    """十余吨双足机甲利落踏步：
    0ms 合金脚掌砸击地表清脆瞬态 + 砂石碎裂咬地声 + 胫甲机械连杆紧凑顿挫 + 干净紧致的低频落脚重量（不轰头、不糊成一团）。"""
    p = [1.0, 0.93, 1.06, 0.96][v]
    heel_crack = crack(0.022, 1650.0 * p, rng, 1.6) * 0.58
    grit_crunch = crunch(rng, dur=0.075, grains=24 + v * 3, spread=0.018, lo=380.0 * p, hi=4600.0, body=0.45, body_f=260.0 * p) * 0.78
    strut_settle = clank(0.070, 290.0 * p, METAL_HEAVY, 32.0, rng, 0.55) * 0.62
    joint_tick = tick(0.012, 1850.0 * p, rng) * 0.46
    foot_thud = thump(0.095, 118.0 * p, 44.0 * p, 26.0, rng, 1.5) * 0.42
    out = mix(
        place(heel_crack, 0.0),
        place(grit_crunch, 0.001),
        place(foot_thud, 0.002),
        place(strut_settle, 0.008),
        place(joint_tick, 0.015 + 0.002 * v),
    )
    return sat(out, 1.35)


@sfx("step_quad", n=4, target=-20.5, dur=0.17, fout=0.022)
def _step_quad(v, rng):
    """四足蜘蛛底盘合金驻锄利落点地：0ms 合金尖足叩击岩土脆响 + 机械趾骨清脆咬合 + 紧凑轻盈的低频支撑。"""
    p = [1.0, 0.92, 1.07, 0.95][v]
    claw_snap = tick(0.012, 2200.0 * p, rng) * 0.72
    rock_bite = crunch(rng, dur=0.055, grains=18 + v * 2, spread=0.014, lo=480.0 * p, hi=5200.0, body=0.42, body_f=310.0 * p) * 0.75
    joint_tap = clank(0.055, 360.0 * p, METAL_LIGHT, 36.0, rng, 0.52) * 0.58
    toe_strike = thump(0.075, 132.0 * p, 52.0 * p, 32.0, rng, 1.4) * 0.36
    out = mix(
        place(claw_snap, 0.0),
        place(rock_bite, 0.001),
        place(toe_strike, 0.002),
        place(joint_tap, 0.007),
    )
    return sat(out, 1.32)


@sfx("legs_tread_loop", n=1, target=-20.5, loop=1.6, reps=4)
def _legs_tread_loop(v, rng):
    """重型履带底盘行进循环：深沉柴油涡轮底盘轰鸣 + 连续厚重履带板啮合与碾过砂石地面的滚动摩擦。"""
    dur = 1.6
    n = ns(dur)
    eng_low = rumble(dur, 62.0, 5.5, rng, 1.45) * 0.38
    t = tt(n)
    roll_mod = 0.68 + 0.32 * np.sin(2.0 * np.pi * (8.0 / dur) * t + 0.3 * smooth_noise(n, rng, 4.0))
    gravel_bed = bp(0.75 * pink(n, rng) + 0.25 * white(n, rng), 240.0, 2200.0, 2) * roll_mod * 0.62
    links = np.zeros(n)
    n_links = 8
    step_t = dur / n_links
    for i in range(n_links):
        t0 = i * step_t + 0.008 * np.sin(i * 1.7)
        th = thump(0.065, 110.0 + (i % 3) * 8.0, 46.0, 32.0, rng, 1.35) * 0.22
        cl = clank(0.055, 290.0 + (i % 4) * 18.0, METAL_HEAVY, 36.0, rng, 0.42) * 0.32
        links = mix(links, place(th, t0, dur), place(cl, t0 + 0.002, dur))
    return sat(mix(eng_low, gravel_bed, links), 1.32)


@sfx("mech_land", n=2, target=-14.5, dur=0.72, fout=0.08)
def _mech_land(v, rng):
    """机甲推进跳跃后重砸着陆：0ms 全车重量砸地低频巨震 + 岩石砂砾崩裂 + 液压减震筒深压缓冲。"""
    p = 1.0 + (v - 0.5) * 0.06
    impact_sub = thump(0.42, 118.0 * p, 24.0 * p, 8.5, rng, 2.5)
    ground_crunch = crunch(rng, dur=0.22, grains=48, spread=0.055, lo=240.0 * p, hi=4200.0, body=0.72, body_f=175.0 * p) * 0.85
    chassis_slam = clank(0.26, 168.0 * p, METAL_HEAVY, 14.0, rng, 0.55) * 0.72
    shock_air = whoosh(0.32, 680.0 * p, 180.0 * p, rng, 1.3) * 0.52
    settle_thud = thump(0.18, 76.0 * p, 26.0 * p, 18.0, rng, 1.7) * 0.48
    out = mix(
        place(impact_sub, 0.0),
        place(ground_crunch, 0.002),
        place(chassis_slam, 0.006),
        place(shock_air, 0.045),
        place(settle_thud, 0.16),
    )
    return reverb_tail(sat(out, 1.65), 0.14, 0.16)


# ─────────────────────────────────────────────────────────────
# 底盘位移与主动战术技能（skill_*）
# ─────────────────────────────────────────────────────────────
@sfx("skill_dash", n=2, target=-14.5, dur=0.72, fout=0.08)
def _skill_dash(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    ignite = thump(0.28, 128.0 * p, 30.0 * p, 11.0, rng, 2.4)
    valve = clank(0.14, 260.0 * p, METAL_HEAVY, 22.0, rng, 0.65) * 0.65
    jet_roar = roar(0.55, 220.0 * p, 4.5, rng, 2.0) * 0.85
    air_shear = whoosh(0.48, 280.0 * p, 1350.0 * p, rng, 1.5) * 0.78
    return reverb_tail(sat(mix(
        place(ignite, 0.0),
        place(valve, 0.004),
        place(jet_roar, 0.015),
        place(air_shear, 0.025),
    ), 1.65), 0.16, 0.16)


@sfx("skill_ram", n=1, target=-13.5, dur=0.95, fout=0.12)
def _skill_ram(v, rng):
    rev = roar(0.75, 165.0, 3.2, rng, 2.2) * 0.88
    plow_drop = clank(0.26, 180.0, METAL_HEAVY, 14.0, rng, 0.75)
    slam_sub = thump(0.45, 125.0, 24.0, 8.0, rng, 2.7)
    armor_crunch = crunch(rng, dur=0.25, grains=55, spread=0.06, lo=280.0, hi=4400.0, body=0.75, body_f=185.0) * 0.85
    return reverb_tail(sat(mix(
        place(plow_drop, 0.0),
        place(slam_sub, 0.005),
        place(armor_crunch, 0.015),
        place(rev, 0.02),
    ), 1.75), 0.2, 0.18)


@sfx("skill_leap", n=1, target=-14.5, dur=0.8, fout=0.1)
def _skill_leap(v, rng):
    piston_fire = thump(0.34, 130.0, 26.0, 9.5, rng, 2.5)
    latch_pop = clank(0.22, 230.0, METAL_HEAVY, 16.0, rng, 0.72)
    ground_push = crunch(rng, dur=0.16, grains=36, spread=0.04, lo=260.0, hi=3800.0, body=0.68, body_f=190.0) * 0.72
    lift_whoosh = whoosh(0.52, 220.0, 1250.0, rng, 1.5) * 0.78
    return reverb_tail(sat(mix(
        place(piston_fire, 0.0),
        place(latch_pop, 0.005),
        place(ground_push, 0.01),
        place(lift_whoosh, 0.04),
    ), 1.65), 0.16, 0.16)


@sfx("skill_missile", n=1, target=-14.0, dur=0.95, fout=0.12)
def _skill_missile(v, rng):
    hatch = clank(0.16, 280.0, METAL_HEAVY, 18.0, rng, 0.7) * 0.72
    out = place(hatch, 0.0, 0.95)
    for i in range(4):
        t0 = 0.03 + i * 0.085
        pf = 1.0 + i * 0.04
        pop = thump(0.16, 128.0 * pf, 38.0 * pf, 18.0, rng, 2.1) * 0.75
        jet = whoosh(0.34, 420.0 * pf, 1850.0 * pf, rng, 1.6) * 0.72
        hss = hiss(0.28, 2200.0 * pf, 1400, 10.0, rng) * 0.52
        out = mix(out, place(pop, t0, 0.95), place(jet, t0 + 0.01, 0.95), place(hss, t0 + 0.02, 0.95))
    return reverb_tail(sat(out, 1.65), 0.18, 0.18)


@sfx("skill_shield", n=1, target=-15.0, dur=0.9, fout=0.1)
def _skill_shield(v, rng):
    latch = clank(0.20, 240.0, METAL_HEAVY, 15.0, rng, 0.75)
    sub_swell = thump(0.42, 110.0, 32.0, 8.5, rng, 2.2)
    expand_air = whoosh(0.55, 220.0, 1150.0, rng, 1.5) * 0.75
    arc_hum = zap(0.45, 1950.0, rng, 34) * 0.55
    return reverb_tail(sat(mix(
        place(latch, 0.0),
        place(sub_swell, 0.01),
        place(expand_air, 0.03),
        place(arc_hum, 0.06),
    ), 1.6), 0.16, 0.16)


@sfx("skill_decoy", n=1, target=-15.5, dur=0.85, fout=0.1)
def _skill_decoy(v, rng):
    pop = thump(0.24, 118.0, 36.0, 14.0, rng, 2.1)
    latch = clank(0.20, 260.0, METAL_HEAVY, 16.0, rng, 0.75)
    air = whoosh(0.38, 320.0, 980.0, rng, 1.5) * 0.65
    arc = zap(0.32, 2000.0, rng, 32) * 0.52
    return sat(mix(
        place(pop, 0.0),
        place(latch, 0.005),
        place(air, 0.04),
        place(arc, 0.22),
    ), 1.5)


@sfx("skill_overdrive", n=1, target=-14.0, dur=1.2, fout=0.15)
def _skill_overdrive(v, rng):
    limiter_break = clank(0.26, 220.0, METAL_HEAVY, 14.0, rng, 0.8)
    core_kick = thump(0.42, 128.0, 24.0, 8.0, rng, 2.6)
    spool_up = turbine(0.95, 75.0, 210.0, rng, 6, 0.1) * 0.78
    furnace_roar = roar(0.95, 220.0, 3.0, rng, 2.1) * 0.82
    arc_burst = zap(0.55, 2100.0, rng, 42) * 0.65
    return reverb_tail(sat(mix(
        place(limiter_break, 0.0),
        place(core_kick, 0.005),
        place(spool_up, 0.04),
        place(furnace_roar, 0.06),
        place(arc_burst, 0.12),
    ), 1.75), 0.2, 0.18)


@sfx("skill_quake", n=1, target=-13.0, dur=1.1, fout=0.15)
def _skill_quake(v, rng):
    slam_sub = thump(0.55, 132.0, 20.0, 6.0, rng, 2.8)
    ground_break = crunch(rng, dur=0.30, grains=62, spread=0.07, lo=240.0, hi=4200.0, body=0.78, body_f=170.0) * 0.9
    hull_clank = clank(0.34, 175.0, METAL_HEAVY, 11.0, rng, 0.8)
    roar_q = roar(0.75, 185.0, 3.5, rng, 2.2) * 0.82
    return reverb_tail(sat(mix(
        place(slam_sub, 0.0),
        place(ground_break, 0.004),
        place(hull_clank, 0.008),
        place(roar_q, 0.02),
    ), 1.8), 0.22, 0.2)


@sfx("skill_charge", n=1, target=-15.0, dur=0.95, fout=0.12)
def _skill_charge(v, rng):
    sw = clank(0.20, 250.0, METAL_HEAVY, 16.0, rng, 0.75)
    th = thump(0.28, 115.0, 30.0, 12.0, rng, 2.2)
    spool = turbine(0.75, 80.0, 230.0, rng, 6, 0.09) * 0.72
    arc = zap(0.45, 2100.0, rng, 38) * 0.58
    return reverb_tail(sat(mix(
        place(sw, 0.0),
        place(th, 0.005),
        place(spool, 0.04),
        place(arc, 0.25),
    ), 1.6), 0.16, 0.16)


@sfx("skill_vent", n=1, target=-14.5, dur=0.95, fout=0.12)
def _skill_vent(v, rng):
    valve = clank(0.22, 235.0, METAL_HEAVY, 15.0, rng, 0.78)
    pop = thump(0.28, 118.0, 28.0, 11.0, rng, 2.3)
    steam = hiss(0.75, 1950.0, 1350, 3.8, rng) * 0.82
    blast = whoosh(0.65, 950.0, 220.0, rng, 1.5) * 0.72
    return reverb_tail(sat(mix(
        place(valve, 0.0),
        place(pop, 0.006),
        place(steam, 0.02),
        place(blast, 0.03),
    ), 1.65), 0.18, 0.18)


@sfx("skill_repair", n=1, target=-15.5, dur=1.0, fout=0.12)
def _skill_repair(v, rng):
    cl1 = clank(0.18, 280.0, METAL_HEAVY, 18.0, rng, 0.75)
    th1 = thump(0.20, 112.0, 34.0, 16.0, rng, 2.0) * 0.75
    weld = zap(0.45, 2050.0, rng, 40) * 0.65
    spray = hiss(0.45, 1850.0, 1200, 6.0, rng) * 0.52
    cl2 = clank(0.18, 320.0, METAL_LIGHT, 20.0, rng, 0.7) * 0.68
    return reverb_tail(sat(mix(
        place(cl1, 0.0),
        place(th1, 0.004),
        place(weld, 0.12),
        place(spray, 0.22),
        place(cl2, 0.58),
    ), 1.55), 0.14, 0.14)


@sfx("skill_emp", n=1, target=-13.5, dur=1.1, fout=0.15)
def _skill_emp(v, rng):
    coil_thump = thump(0.52, 140.0, 20.0, 6.5, rng, 2.8)
    snap = crack(0.055, 2200.0, rng, 2.4) * 0.88
    emp_arc = zap(0.75, 2100.0, rng, 52) * 0.85
    mag_drop = whoosh(0.65, 1350.0, 95.0, rng, 1.6) * 0.75
    ring_plate = modal(0.55, 195.0, METAL_HOLLOW, 8.5, rng, 0.6) * 0.55
    return reverb_tail(sat(mix(
        place(snap, 0.0),
        place(coil_thump, 0.003),
        place(emp_arc, 0.008),
        place(mag_drop, 0.02),
        place(ring_plate, 0.04),
    ), 1.8), 0.22, 0.2)


@sfx("skill_cloak", n=1, target=-16.0, dur=0.85, fout=0.12)
def _skill_cloak(v, rng):
    shutter = tick(0.02, 1650.0, rng) * 0.7
    relay = clank(0.16, 280.0, METAL_LIGHT, 20.0, rng, 0.55) * 0.62
    field_in = whoosh(0.58, 980.0, 140.0, rng, 1.5) * 0.78
    sub_hum = thump(0.38, 82.0, 28.0, 10.0, rng, 1.6) * 0.68
    return reverb_tail(sat(mix(
        place(shutter, 0.0),
        place(relay, 0.015),
        place(sub_hum, 0.03),
        place(field_in, 0.04),
    ), 1.4), 0.16, 0.16)


@sfx("skill_guard", n=1, target=-14.5, dur=0.85, fout=0.1)
def _skill_guard(v, rng):
    srv = servo(0.18, 150.0, 240.0, rng, 0.4) * 0.55
    slam1 = clank(0.28, 195.0, METAL_HEAVY, 12.0, rng, 0.75)
    th1 = thump(0.32, 115.0, 28.0, 10.0, rng, 2.4)
    lock2 = clank(0.22, 260.0, METAL_HEAVY, 16.0, rng, 0.7) * 0.78
    th2 = thump(0.24, 92.0, 28.0, 14.0, rng, 2.0) * 0.72
    return reverb_tail(sat(mix(
        place(slam1, 0.0),
        place(th1, 0.004),
        place(srv, 0.02),
        place(lock2, 0.16),
        place(th2, 0.165),
    ), 1.7), 0.16, 0.16)


@sfx("skill_jam", n=1, target=-15.0, dur=0.95, fout=0.12)
def _skill_jam(v, rng):
    trig = clank(0.16, 260.0, METAL_HEAVY, 18.0, rng, 0.7)
    pulse_sub = thump(0.35, 118.0, 28.0, 10.0, rng, 2.3)
    static_roar = roar(0.68, 280.0, 4.0, rng, 1.9) * 0.78
    arc_crackle = zap(0.65, 1950.0, rng, 46) * 0.75
    return reverb_tail(sat(mix(
        place(trig, 0.0),
        place(pulse_sub, 0.01),
        place(static_roar, 0.03),
        place(arc_crackle, 0.04),
    ), 1.65), 0.16, 0.16)


@sfx("skill_denied", n=1, target=-18.5, dur=0.24, fout=0.025)
def _skill_denied(v, rng):
    tk1 = tick(0.013, 1780.0, rng) * 0.85
    c1 = clank(0.065, 420.0, METAL_HEAVY, 36.0, rng, 0.65) * 0.72
    t1 = thump(0.045, 142.0, 60.0, 38.0, rng, 1.35) * 0.26
    tk2 = tick(0.013, 1440.0, rng) * 0.88
    c2 = clank(0.080, 330.0, METAL_HEAVY, 30.0, rng, 0.70) * 0.76
    t2 = thump(0.055, 125.0, 52.0, 34.0, rng, 1.4) * 0.28
    return sat(mix(
        place(tk1, 0.0),
        place(c1, 0.001),
        place(t1, 0.003),
        place(tk2, 0.075),
        place(c2, 0.076),
        place(t2, 0.078),
    ), 1.35)


# ─────────────────────────────────────────────────────────────
# 偏导护盾（shield_up / shield_hit / shield_down）
# ─────────────────────────────────────────────────────────────
@sfx("shield_up", n=1, target=-15.0, dur=0.9, fout=0.1)
def _shield_up(v, rng):
    latch = clank(0.20, 240.0, METAL_HEAVY, 15.0, rng, 0.75)
    sub_swell = thump(0.42, 110.0, 32.0, 8.5, rng, 2.2)
    expand_air = whoosh(0.55, 220.0, 1150.0, rng, 1.5) * 0.75
    arc_hum = zap(0.45, 1950.0, rng, 34) * 0.55
    return reverb_tail(sat(mix(
        place(latch, 0.0),
        place(sub_swell, 0.01),
        place(expand_air, 0.03),
        place(arc_hum, 0.06),
    ), 1.6), 0.16, 0.16)


@sfx("shield_hit", n=3, target=-14.5, dur=0.5, fout=0.06)
def _shield_hit(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    th = thump(0.24, 128.0 * p, 34.0 * p, 14.0, rng, 2.3)
    crk = crack(0.045, 2100.0 * p, rng, 2.1) * 0.82
    arc = zap(0.26, 2200.0 * p, rng, 38) * 0.72
    body = clank(0.22, 320.0 * p, METAL_HEAVY, 18.0, rng, 0.65) * 0.58
    return reverb_tail(sat(mix(
        place(crk, 0.0),
        place(th, 0.002),
        place(body, 0.005),
        place(arc, 0.008),
    ), 1.65), 0.12, 0.14)


@sfx("shield_down", n=1, target=-15.0, dur=0.85, fout=0.1)
def _shield_down(v, rng):
    shatter = crack(0.08, 1950.0, rng, 2.3) * 0.85
    sub_drop = thump(0.38, 118.0, 24.0, 9.0, rng, 2.4)
    collapse_whoosh = whoosh(0.48, 1250.0, 150.0, rng, 1.5) * 0.78
    arc_die = zap(0.38, 1850.0, rng, 36) * 0.62
    steam = hiss(0.45, 1750.0, 1100, 6.5, rng) * 0.52
    return reverb_tail(sat(mix(
        place(shatter, 0.0),
        place(sub_drop, 0.004),
        place(arc_die, 0.01),
        place(collapse_whoosh, 0.02),
        place(steam, 0.08),
    ), 1.65), 0.16, 0.16)


# ─────────────────────────────────────────────────────────────
# 机体受击、部件断离与反应堆殉爆（mech_hurt / mech_part_lost / mech_destroyed / mech_vent）
# ─────────────────────────────────────────────────────────────
@sfx("mech_hurt", n=3, target=-14.0, dur=0.52, fout=0.06)
def _mech_hurt(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    hull_thud = thump(0.28, 125.0 * p, 28.0 * p, 12.0, rng, 2.5)
    armor_slam = clank(0.24, 210.0 * p, METAL_HEAVY, 15.0, rng, 0.72)
    spall = crunch(rng, dur=0.14, grains=32, spread=0.035, lo=380.0 * p, hi=4600.0, body=0.65, body_f=220.0 * p) * 0.72
    short_arc = zap(0.18, 1950.0 * p, rng, 30) * 0.48
    return reverb_tail(sat(mix(
        place(hull_thud, 0.0),
        place(armor_slam, 0.003),
        place(spall, 0.005),
        place(short_arc, 0.02),
    ), 1.7), 0.12, 0.14)


@sfx("mech_part_lost", n=1, target=-13.0, dur=1.2, fout=0.15)
def _mech_part_lost(v, rng):
    bolt_snap = crack(0.11, 1850.0, rng, 2.4) * 0.9
    blast_sub = thump(0.48, 130.0, 22.0, 7.0, rng, 2.8)
    tear_clank = clank(0.42, 185.0, METAL_HEAVY, 9.0, rng, 0.85)
    arc_burst = zap(0.45, 2100.0, rng, 44) * 0.72
    pipe_burst = hiss(0.65, 1950.0, 1300, 4.5, rng) * 0.65
    fall_clank = clank(0.28, 240.0, METAL_HOLLOW, 13.0, rng, 0.7) * 0.72
    fall_thump = thump(0.25, 95.0, 28.0, 14.0, rng, 2.1) * 0.68
    return reverb_tail(sat(mix(
        place(bolt_snap, 0.0),
        place(blast_sub, 0.004),
        place(tear_clank, 0.008),
        place(arc_burst, 0.02),
        place(pipe_burst, 0.06),
        place(fall_clank, 0.42),
        place(fall_thump, 0.425),
    ), 1.8), 0.2, 0.18)


@sfx("mech_destroyed", n=1, target=-11.5, dur=2.6, fout=0.35)
def _mech_destroyed(v, rng):
    init_boom = thump(0.75, 135.0, 20.0, 5.0, rng, 3.0)
    init_roar = roar(1.2, 210.0, 2.8, rng, 2.4) * 0.9
    hull_rip = clank(0.65, 165.0, METAL_HEAVY, 6.5, rng, 0.85)
    arc_storm = zap(1.1, 2200.0, rng, 50) * 0.75
    core_det = thump(0.95, 145.0, 18.0, 3.8, rng, 3.2)
    core_roar = roar(1.6, 175.0, 1.9, rng, 2.6) * 0.95
    collapse_clank = clank(0.55, 150.0, METAL_HEAVY, 7.5, rng, 0.8) * 0.85
    collapse_thump = thump(0.55, 98.0, 22.0, 7.0, rng, 2.6) * 0.85
    steam_die = hiss(1.1, 1750.0, 1100, 3.0, rng) * 0.55
    return reverb_tail(sat(mix(
        place(init_boom, 0.0),
        place(init_roar, 0.01),
        place(hull_rip, 0.02),
        place(arc_storm, 0.05),
        place(core_det, 0.48),
        place(core_roar, 0.49),
        place(collapse_clank, 1.18),
        place(collapse_thump, 1.19),
        place(steam_die, 1.25),
    ), 1.95), 0.28, 0.25)


@sfx("mech_vent", n=1, target=-15.5, dur=1.1, fout=0.15)
def _mech_vent(v, rng):
    valve_pop = clank(0.22, 240.0, METAL_HEAVY, 15.0, rng, 0.75)
    sub_th = thump(0.26, 108.0, 30.0, 12.0, rng, 2.1) * 0.75
    steam = hiss(0.85, 1850.0, 1250, 3.5, rng) * 0.78
    air = whoosh(0.72, 780.0, 195.0, rng, 1.4) * 0.65
    return reverb_tail(sat(mix(
        place(valve_pop, 0.0),
        place(sub_th, 0.005),
        place(steam, 0.02),
        place(air, 0.04),
    ), 1.55), 0.16, 0.16)


# ─────────────────────────────────────────────────────────────
# 能源反应堆监控与战地消耗品（energy_* / use_*）
# ─────────────────────────────────────────────────────────────
@sfx("energy_low", n=1, target=-16.5, dur=0.75, fout=0.08)
def _energy_low(v, rng):
    cl1 = clank(0.18, 250.0, METAL_HEAVY, 18.0, rng, 0.72)
    th1 = thump(0.20, 98.0, 32.0, 16.0, rng, 2.0) * 0.75
    spool_dn = whoosh(0.45, 580.0, 140.0, rng, 1.4) * 0.62
    cl2 = clank(0.20, 210.0, METAL_HEAVY, 16.0, rng, 0.75) * 0.85
    th2 = thump(0.22, 86.0, 28.0, 15.0, rng, 2.0) * 0.78
    return sat(mix(
        place(cl1, 0.0),
        place(th1, 0.004),
        place(spool_dn, 0.03),
        place(cl2, 0.22),
        place(th2, 0.224),
    ), 1.5)


@sfx("energy_emergency", n=1, target=-14.0, dur=1.2, fout=0.15)
def _energy_emergency(v, rng):
    breaker_trip = clank(0.32, 195.0, METAL_HEAVY, 11.0, rng, 0.82)
    power_drop_sub = thump(0.48, 122.0, 22.0, 7.5, rng, 2.6)
    turbine_die = whoosh(0.85, 820.0, 95.0, rng, 1.5) * 0.78
    vent_steam = hiss(0.65, 1850.0, 1200, 4.5, rng) * 0.58
    aux_latch = clank(0.22, 275.0, METAL_HOLLOW, 16.0, rng, 0.7) * 0.72
    return reverb_tail(sat(mix(
        place(breaker_trip, 0.0),
        place(power_drop_sub, 0.008),
        place(turbine_die, 0.03),
        place(vent_steam, 0.08),
        place(aux_latch, 0.62),
    ), 1.7), 0.18, 0.18)


@sfx("energy_alarm_loop", n=1, target=-18.5, loop=1.2, reps=4)
def _energy_alarm_loop(v, rng):
    dur = 1.2
    pump_sub = rumble(dur, 48.0, 4.0, rng, 1.45) * 0.52
    hit1 = thump(0.18, 92.0, 30.0, 18.0, rng, 1.9) * 0.78
    cl1 = clank(0.14, 230.0, METAL_HEAVY, 22.0, rng, 0.65) * 0.72
    hit2 = thump(0.16, 78.0, 28.0, 20.0, rng, 1.8) * 0.65
    cl2 = clank(0.12, 195.0, METAL_HOLLOW, 24.0, rng, 0.6) * 0.62
    air_puff = hiss(0.22, 1450.0, 900, 12.0, rng) * 0.35
    return sat(mix(
        pump_sub,
        place(hit1, 0.04, dur),
        place(cl1, 0.044, dur),
        place(hit2, 0.26, dur),
        place(cl2, 0.264, dur),
        place(air_puff, 0.30, dur),
    ), 1.4)


@sfx("energy_restored", n=1, target=-15.0, dur=1.1, fout=0.15)
def _energy_restored(v, rng):
    slam_on = clank(0.28, 225.0, METAL_HEAVY, 13.0, rng, 0.8)
    sub_on = thump(0.38, 112.0, 30.0, 9.5, rng, 2.3)
    spool_up = turbine(0.78, 68.0, 185.0, rng, 6, 0.09) * 0.72
    roar_up = roar(0.68, 190.0, 4.0, rng, 1.8) * 0.65
    ready_lock = clank(0.18, 310.0, METAL_LIGHT, 20.0, rng, 0.68) * 0.68
    return reverb_tail(sat(mix(
        place(slam_on, 0.0),
        place(sub_on, 0.008),
        place(spool_up, 0.05),
        place(roar_up, 0.08),
        place(ready_lock, 0.65),
    ), 1.6), 0.16, 0.16)


@sfx("use_fuel_cell", n=1, target=-15.5, dur=1.0, fout=0.12)
def _use_fuel_cell(v, rng):
    insert_clank = clank(0.22, 250.0, METAL_HEAVY, 16.0, rng, 0.78)
    insert_thump = thump(0.24, 112.0, 34.0, 14.0, rng, 2.1)
    inject_hiss = hiss(0.45, 1850.0, 1200, 6.5, rng) * 0.62
    burn_roar = roar(0.55, 210.0, 4.5, rng, 1.9) * 0.72
    seal_lock = clank(0.18, 320.0, METAL_LIGHT, 20.0, rng, 0.7) * 0.68
    return reverb_tail(sat(mix(
        place(insert_clank, 0.0),
        place(insert_thump, 0.006),
        place(inject_hiss, 0.12),
        place(burn_roar, 0.25),
        place(seal_lock, 0.58),
    ), 1.6), 0.14, 0.14)


@sfx("use_repair_kit", n=1, target=-15.5, dur=1.2, fout=0.12)
def _use_repair_kit(v, rng):
    rivet1 = clank(0.18, 290.0, METAL_HEAVY, 18.0, rng, 0.78)
    th1 = thump(0.18, 115.0, 36.0, 18.0, rng, 2.1) * 0.78
    rivet2 = clank(0.18, 315.0, METAL_HEAVY, 18.0, rng, 0.78)
    th2 = thump(0.18, 120.0, 36.0, 18.0, rng, 2.1) * 0.78
    weld_arc = zap(0.48, 2100.0, rng, 42) * 0.68
    spray_hiss = hiss(0.45, 1950.0, 1200, 6.5, rng) * 0.55
    return reverb_tail(sat(mix(
        place(rivet1, 0.0),
        place(th1, 0.004),
        place(rivet2, 0.16),
        place(th2, 0.164),
        place(weld_arc, 0.34),
        place(spray_hiss, 0.42),
    ), 1.6), 0.14, 0.14)


@sfx("use_beacon", n=1, target=-15.5, dur=1.1, fout=0.12)
def _use_beacon(v, rng):
    th = thump(0.26, 118.0, 32.0, 13.0, rng, 2.2)
    cl = clank(0.22, 270.0, METAL_HEAVY, 15.0, rng, 0.78)
    launch_whoosh = whoosh(0.55, 340.0, 1450.0, rng, 1.6) * 0.75
    flare_hiss = hiss(0.65, 2100.0, 1350, 5.0, rng) * 0.58
    return reverb_tail(sat(mix(
        place(th, 0.0),
        place(cl, 0.005),
        place(launch_whoosh, 0.03),
        place(flare_hiss, 0.06),
    ), 1.6), 0.16, 0.16)


@sfx("use_denied", n=1, target=-18.5, dur=0.24, fout=0.025)
def _use_denied(v, rng):
    tk1 = tick(0.013, 1850.0, rng) * 0.85
    c1 = clank(0.065, 450.0, METAL_HOLLOW, 36.0, rng, 0.65) * 0.72
    t1 = thump(0.045, 140.0, 58.0, 38.0, rng, 1.35) * 0.25
    tk2 = tick(0.013, 1480.0, rng) * 0.88
    c2 = clank(0.080, 350.0, METAL_HOLLOW, 30.0, rng, 0.68) * 0.75
    t2 = thump(0.055, 122.0, 52.0, 34.0, rng, 1.4) * 0.28
    return sat(mix(
        place(tk1, 0.0),
        place(c1, 0.001),
        place(t1, 0.003),
        place(tk2, 0.072),
        place(c2, 0.073),
        place(t2, 0.075),
    ), 1.35)
