# -*- coding: utf-8 -*-
"""9种扩展虫族（刀螳 mantis / 自爆虫 bomber / 晶甲虫 crystal_bug / 掘地虫 burrower /
机甲寄生虫 mech_beetle / 毒蜂 wasp / 盾甲虫 shielder / 迫击炮虫 mortar / 铁颚虫 ironjaw）
全物理生物声学与几丁质甲壳谐振重制版（零16-bit合成器方波/锯齿波）。"""
import numpy as np
from sfx_dsp import (
    SR, sfx, env_exp, env_adsr, biquad, reson, sweep,
    white, pink, brown, velvet, sat, place, mix, reverb_tail,
)
from sfx_lib import (
    thump, crack, tick, clank, modal, METAL_HEAVY, METAL_HOLLOW, METAL_LIGHT,
    GLASS_MODES, CHITIN_MODES, servo, hiss, whoosh, roar, rumble,
    zap, buzz, turbine, squelch, voice,
)


# ─────────────────────────────────────────────────────────────
# 1. 镰刀螳螂（bug_mantis）：金属化几丁质刀臂摩擦、高速破风挥砍、嘶哑气门鸣叫
# ─────────────────────────────────────────────────────────────
@sfx("bug_mantis_appear", n=2, target=-16.0, dur=0.65, fout=0.07)
def _mantis_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 双镰刀臂交叉刮擦出鞘 + 步足疾行 + 凶狠气门嘶声
    blade_scrape = clank(0.22, 420 * p, METAL_LIGHT, 18.0, rng, 0.72)
    chitin = modal(0.20, 480 * p, CHITIN_MODES, 18.0, rng, 0.68)
    whoosh_in = whoosh(0.28, 420 * p, 1550 * p, rng, 2.2) * 0.68
    rasp = voice(0.38, 175 * p, 245 * p, rng, 15.0, 0.32, 2.0) * 0.75
    return sat(mix(
        place(blade_scrape, 0.0),
        place(chitin, 0.01),
        place(whoosh_in, 0.04),
        place(rasp, 0.08),
    ), 1.55)


@sfx("bug_mantis_windup", n=2, target=-16.5, dur=0.55, fout=0.06)
def _mantis_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 镰刀臂高举蓄力：关节棘轮紧绷咔哒声 + 胸腔急促吸气
    joint_lock = modal(0.22, 440 * p, CHITIN_MODES, 16.0, rng, 0.7)
    scrape = hiss(0.26, 2600 * p, 1400, 11.0, rng) * 0.52
    hiss_vox = voice(0.34, 150 * p, 265 * p, rng, 16.0, 0.35, 2.1) * 0.72
    return sat(mix(
        place(joint_lock, 0.0),
        place(scrape, 0.03),
        place(hiss_vox, 0.05),
    ), 1.5)


@sfx("bug_mantis_attack", n=3, target=-15.0, dur=0.55, fout=0.06)
def _mantis_attack(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    # 双镰十字斩击：凌厉破空风刃 + 刀锋劈砍脆响 + 凶暴低嘶
    slash1 = whoosh(0.18, 480 * p, 1950 * p, rng, 2.6) * 0.85
    snap1 = crack(0.055, 2300 * p, rng, 2.4) * 0.88
    blade_cl = clank(0.18, 390 * p, METAL_LIGHT, 20.0, rng, 0.78)
    slash2 = whoosh(0.18, 520 * p, 2100 * p, rng, 2.6) * 0.8
    th = thump(0.18, 118 * p, 36 * p, 18.0, rng, 2.1) * 0.72
    snarl = voice(0.26, 230 * p, 130 * p, rng, 17.0, 0.35, 2.1) * 0.7
    return sat(mix(
        place(slash1, 0.0),
        place(snap1, 0.045),
        place(blade_cl, 0.048),
        place(th, 0.05),
        place(snarl, 0.06),
        place(slash2, 0.14),
    ), 1.65)


@sfx("bug_mantis_hurt", n=3, target=-16.0, dur=0.5, fout=0.05)
def _mantis_hurt(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    crk = crack(0.065, 2050 * p, rng, 2.1) * 0.85
    chitin = modal(0.18, 420 * p, CHITIN_MODES, 18.0, rng, 0.72)
    wet = squelch(0.24, 340 * p, 1280 * p, rng, 2.0) * 0.75
    shriek = voice(0.28, 240 * p, 115 * p, rng, 18.0, 0.38, 2.2) * 0.75
    return sat(mix(
        place(crk, 0.0),
        place(chitin, 0.004),
        place(wet, 0.015),
        place(shriek, 0.025),
    ), 1.55)


@sfx("bug_mantis_death", n=2, target=-15.0, dur=0.85, fout=0.09)
def _mantis_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    sub = thump(0.28, 118 * p, 30 * p, 12.0, rng, 2.3)
    blade_snap = clank(0.26, 360 * p, METAL_LIGHT, 15.0, rng, 0.8)
    shell_break = crack(0.095, 1900 * p, rng, 2.2) * 0.88
    gore = squelch(0.45, 290 * p, 1380 * p, rng, 2.2) * 0.85
    dying = voice(0.52, 210 * p, 72 * p, rng, 14.0, 0.4, 2.1) * 0.78
    return sat(mix(
        place(sub, 0.0),
        place(blade_snap, 0.005),
        place(shell_break, 0.008),
        place(gore, 0.025),
        place(dying, 0.04),
    ), 1.65)


# ─────────────────────────────────────────────────────────────
# 2. 高挥发自爆虫（bug_bomber）：膨胀化学毒囊沸腾、急促气压脉动引信、剧烈爆浆轰炸
# ─────────────────────────────────────────────────────────────
@sfx("bug_bomber_appear", n=2, target=-16.0, dur=0.7, fout=0.08)
def _bomber_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 自爆虫滚出：沉重液囊晃动 + 体内挥发气体咕嘟沸腾 + 压抑低喘
    slosh = squelch(0.42, 220 * p, 950 * p, rng, 2.0) * 0.82
    sac_thump = thump(0.26, 102 * p, 32 * p, 13.0, rng, 2.1) * 0.72
    gas_hiss = hiss(0.38, 1950 * p, 1200, 8.0, rng) * 0.52
    wheeze = voice(0.42, 115 * p, 165 * p, rng, 12.0, 0.35, 2.0) * 0.75
    return sat(mix(
        place(sac_thump, 0.0),
        place(slosh, 0.02),
        place(wheeze, 0.06),
        place(gas_hiss, 0.10),
    ), 1.55)


@sfx("bug_bomber_windup", n=2, target=-15.5, dur=0.65, fout=0.07)
def _bomber_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 自爆虫充气膨胀：腹部气囊急剧鼓起拉伸 + 内部化学反应剧烈翻腾
    inflate = thump(0.32, 85 * p, 42 * p, 10.0, rng, 2.2)
    boil = squelch(0.48, 280 * p, 1450 * p, rng, 2.3) * 0.88
    strain_vox = voice(0.45, 105 * p, 215 * p, rng, 16.0, 0.38, 2.2) * 0.78
    return sat(mix(
        place(inflate, 0.0),
        place(boil, 0.02),
        place(strain_vox, 0.04),
    ), 1.6)


@sfx("bug_bomber_fuse", n=2, target=-15.0, dur=0.85, fout=0.08)
def _bomber_fuse(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 临爆引信脉动（绝不用8-bit滴滴声）：4次加速的生物心脏超压搏动 + 高压蒸汽喷孔嘶鸣 + 几丁质外壳撑裂声
    out = np.zeros(int(0.85 * SR))
    t_schedule = [0.0, 0.24, 0.43, 0.58]
    for i, t0 in enumerate(t_schedule):
        pf = p * (1.0 + i * 0.12)
        hb = thump(0.16, 115 * pf, 38 * pf, 18.0, rng, 2.3) * (0.7 + i * 0.08)
        crk = crack(0.05, 1750 * pf, rng, 2.0) * 0.65
        sq = squelch(0.15, 320 * pf, 1350 * pf, rng, 2.0) * 0.68
        out = mix(out, place(hb, t0, 0.85), place(crk, t0 + 0.005, 0.85), place(sq, t0 + 0.01, 0.85))
    steam_scream = hiss(0.75, 2300 * p, 1500, 3.5, rng) * 0.62
    throat = voice(0.72, 130 * p, 240 * p, rng, 18.0, 0.4, 2.3) * 0.72
    return sat(mix(out, place(steam_scream, 0.05, 0.85), place(throat, 0.08, 0.85)), 1.7)


@sfx("bug_bomber_attack", n=2, target=-12.5, dur=1.4, fout=0.2)
def _bomber_attack(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 自爆虫引爆：超重低频生物炸弹轰鸣 + 强酸粘液漫天爆浆 + 冲击波气浪
    det_sub = thump(0.65, 135 * p, 20 * p, 5.5, rng, 3.0)
    blast_roar = roar(0.95, 210 * p, 3.5, rng, 2.5) * 0.92
    shell_shatter = crack(0.16, 1750 * p, rng, 2.5) * 0.88
    mega_gore = squelch(0.85, 280 * p, 1650 * p, rng, 2.6) * 0.92
    acid_sizzle = hiss(0.85, 2300 * p, 1500, 4.0, rng) * 0.62
    return reverb_tail(sat(mix(
        place(det_sub, 0.0),
        place(shell_shatter, 0.004),
        place(blast_roar, 0.008),
        place(mega_gore, 0.015),
        place(acid_sizzle, 0.12),
    ), 1.9), 0.26, 0.24)


@sfx("bug_bomber_hurt", n=2, target=-15.5, dur=0.55, fout=0.06)
def _bomber_hurt(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    th = thump(0.22, 112 * p, 34 * p, 15.0, rng, 2.1)
    leak = hiss(0.35, 2250 * p, 1400, 8.0, rng) * 0.65
    splat = squelch(0.32, 310 * p, 1380 * p, rng, 2.1) * 0.82
    groan = voice(0.30, 160 * p, 105 * p, rng, 15.0, 0.38, 2.1) * 0.72
    return sat(mix(
        place(th, 0.0),
        place(splat, 0.008),
        place(leak, 0.015),
        place(groan, 0.025),
    ), 1.6)


@sfx("bug_bomber_death", n=1, target=-13.0, dur=1.3, fout=0.18)
def _bomber_death(v, rng):
    # 被击杀殉爆：略小于主动自爆的粘稠化学内爆
    sub = thump(0.55, 130, 22, 6.0, rng, 2.9)
    roar_b = roar(0.85, 195, 4.0, rng, 2.3) * 0.88
    gore = squelch(0.75, 260, 1550, rng, 2.5) * 0.9
    acid = hiss(0.75, 2200, 1400, 4.5, rng) * 0.58
    return reverb_tail(sat(mix(
        place(sub, 0.0),
        place(roar_b, 0.008),
        place(gore, 0.015),
        place(acid, 0.10),
    ), 1.85), 0.24, 0.22)


# ─────────────────────────────────────────────────────────────
# 3. 矿脉晶甲虫（bug_crystal_bug）：厚重石英晶簇碰撞、高硬度矿物碎裂共鸣、低沉矿洞吼声
# ─────────────────────────────────────────────────────────────
@sfx("bug_crystal_bug_appear", n=2, target=-16.0, dur=0.75, fout=0.08)
def _crystal_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    stomp = thump(0.26, 108 * p, 30 * p, 13.0, rng, 2.2)
    cryst_clink = modal(0.38, 520 * p, GLASS_MODES, 10.0, rng, 0.68) * 0.72
    chitin = modal(0.28, 280 * p, CHITIN_MODES, 12.0, rng, 0.72)
    growl = voice(0.45, 92 * p, 138 * p, rng, 9.5, 0.35, 2.0) * 0.75
    return sat(mix(
        place(stomp, 0.0),
        place(chitin, 0.006),
        place(cryst_clink, 0.015),
        place(growl, 0.08),
    ), 1.55)


@sfx("bug_crystal_bug_windup", n=2, target=-16.0, dur=0.65, fout=0.07)
def _crystal_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 背部晶簇棱柱摩擦蓄能
    grind = modal(0.38, 460 * p, GLASS_MODES, 8.5, rng, 0.65) * 0.7
    sub_strain = thump(0.24, 98 * p, 32 * p, 13.0, rng, 2.0) * 0.68
    vox = voice(0.42, 85 * p, 155 * p, rng, 10.5, 0.35, 2.1) * 0.75
    return sat(mix(place(sub_strain, 0.0), place(grind, 0.02), place(vox, 0.05)), 1.55)


@sfx("bug_crystal_bug_attack", n=2, target=-14.5, dur=0.75, fout=0.08)
def _crystal_attack(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 晶刺猛击/迸射：沉重矿物撞击 + 高密度石英晶簇脆裂泛音
    imp_sub = thump(0.36, 120 * p, 26 * p, 9.5, rng, 2.5)
    shard_crack = crack(0.09, 2100 * p, rng, 2.3) * 0.85
    cryst_ring = modal(0.45, 580 * p, GLASS_MODES, 8.0, rng, 0.75) * 0.75
    chitin_slam = modal(0.32, 250 * p, CHITIN_MODES, 11.0, rng, 0.8)
    roar_v = voice(0.36, 125 * p, 75 * p, rng, 11.0, 0.38, 2.2) * 0.75
    return reverb_tail(sat(mix(
        place(imp_sub, 0.0),
        place(shard_crack, 0.004),
        place(chitin_slam, 0.008),
        place(cryst_ring, 0.012),
        place(roar_v, 0.03),
    ), 1.7), 0.18, 0.18)


@sfx("bug_crystal_bug_hurt", n=2, target=-15.5, dur=0.6, fout=0.06)
def _crystal_hurt(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    th = thump(0.26, 112 * p, 30 * p, 12.0, rng, 2.2)
    chip_snap = crack(0.08, 2200 * p, rng, 2.2) * 0.82
    cryst = modal(0.38, 620 * p, GLASS_MODES, 9.5, rng, 0.72) * 0.72
    grunt = voice(0.32, 115 * p, 72 * p, rng, 10.0, 0.38, 2.1) * 0.72
    return sat(mix(
        place(th, 0.0),
        place(chip_snap, 0.004),
        place(cryst, 0.008),
        place(grunt, 0.025),
    ), 1.6)


@sfx("bug_crystal_bug_death", n=2, target=-14.0, dur=1.1, fout=0.14)
def _crystal_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 晶甲虫碎裂倒毙：浑身矿石晶簇崩解散落一地 + 虫躯爆浆闷响
    sub = thump(0.42, 118 * p, 24 * p, 8.5, rng, 2.5)
    shatter1 = modal(0.55, 540 * p, GLASS_MODES, 7.0, rng, 0.82) * 0.78
    shatter2 = modal(0.45, 680 * p, GLASS_MODES, 8.5, rng, 0.72) * 0.65
    crk = crack(0.14, 2100 * p, rng, 2.4) * 0.88
    gore = squelch(0.48, 250 * p, 1180 * p, rng, 2.1) * 0.78
    dying = voice(0.62, 105 * p, 52 * p, rng, 9.0, 0.4, 2.2) * 0.8
    return reverb_tail(sat(mix(
        place(sub, 0.0),
        place(crk, 0.005),
        place(shatter1, 0.01),
        place(gore, 0.03),
        place(dying, 0.05),
        place(shatter2, 0.28),
    ), 1.75), 0.22, 0.2)


# ─────────────────────────────────────────────────────────────
# 4. 潜沙掘地虫（bug_burrower）：地底岩层钻探闷响、破土喷发碎石飞溅、深渊瓮声咆哮
# ─────────────────────────────────────────────────────────────
@sfx("bug_burrower_appear", n=2, target=-15.5, dur=0.8, fout=0.09)
def _burrower_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    sub_dig = rumble(0.55, 68 * p, 5.5, rng, 1.9) * 0.78
    th = thump(0.32, 105 * p, 26 * p, 10.5, rng, 2.3)
    gravel = crack(0.14, 1500 * p, rng, 1.9) * 0.68
    growl = voice(0.48, 82 * p, 128 * p, rng, 9.0, 0.36, 2.1) * 0.78
    return sat(mix(
        place(sub_dig, 0.0),
        place(th, 0.08),
        place(gravel, 0.09),
        place(growl, 0.12),
    ), 1.6)


@sfx("bug_burrower_windup", n=2, target=-15.5, dur=0.7, fout=0.08)
def _burrower_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    tremor = rumble(0.55, 72 * p, 6.0, rng, 2.0) * 0.8
    chitin = modal(0.32, 230 * p, CHITIN_MODES, 10.0, rng, 0.75)
    vox = voice(0.45, 75 * p, 145 * p, rng, 10.0, 0.38, 2.2) * 0.78
    return sat(mix(place(tremor, 0.0), place(chitin, 0.05), place(vox, 0.08)), 1.6)


@sfx("bug_burrower_erupt", n=2, target=-13.5, dur=1.0, fout=0.12)
def _burrower_erupt(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 掘地虫破土冲出：地表岩层炸裂 + 泥土碎石冲天而起 + 巨口咆哮
    earth_pop = thump(0.52, 128 * p, 22 * p, 6.5, rng, 2.8)
    rock_roar = roar(0.75, 185 * p, 4.0, rng, 2.3) * 0.88
    debris = crack(0.22, 1550 * p, rng, 2.2) * 0.78
    bellow = voice(0.58, 95 * p, 165 * p, rng, 9.5, 0.38, 2.3) * 0.82
    return reverb_tail(sat(mix(
        place(earth_pop, 0.0),
        place(rock_roar, 0.01),
        place(debris, 0.02),
        place(bellow, 0.08),
    ), 1.8), 0.22, 0.2)


@sfx("bug_burrower_attack", n=2, target=-14.5, dur=0.7, fout=0.08)
def _burrower_attack(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    crush_jaw = thump(0.35, 118 * p, 26 * p, 9.5, rng, 2.5)
    mandible = modal(0.28, 240 * p, CHITIN_MODES, 11.0, rng, 0.85)
    snap = crack(0.095, 1650 * p, rng, 2.2) * 0.85
    wet = squelch(0.32, 260 * p, 1220 * p, rng, 2.0) * 0.72
    snarl = voice(0.38, 125 * p, 72 * p, rng, 10.5, 0.38, 2.2) * 0.78
    return sat(mix(
        place(crush_jaw, 0.0),
        place(mandible, 0.005),
        place(snap, 0.008),
        place(snarl, 0.02),
        place(wet, 0.04),
    ), 1.7)


@sfx("bug_burrower_hurt", n=2, target=-15.5, dur=0.6, fout=0.07)
def _burrower_hurt(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    th = thump(0.28, 110 * p, 28 * p, 11.5, rng, 2.2)
    shell = modal(0.26, 250 * p, CHITIN_MODES, 12.0, rng, 0.78)
    wet = squelch(0.30, 270 * p, 1180 * p, rng, 2.0) * 0.75
    grunt = voice(0.35, 105 * p, 64 * p, rng, 9.5, 0.38, 2.1) * 0.75
    return sat(mix(place(th, 0.0), place(shell, 0.005), place(wet, 0.02), place(grunt, 0.03)), 1.6)


@sfx("bug_burrower_death", n=2, target=-14.0, dur=1.1, fout=0.14)
def _burrower_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    sub = thump(0.45, 115 * p, 22 * p, 8.0, rng, 2.6)
    shell = modal(0.38, 215 * p, CHITIN_MODES, 9.0, rng, 0.85)
    gore = squelch(0.55, 230 * p, 1320 * p, rng, 2.3) * 0.85
    dying = voice(0.68, 92 * p, 46 * p, rng, 8.0, 0.42, 2.3) * 0.82
    return reverb_tail(sat(mix(
        place(sub, 0.0),
        place(shell, 0.008),
        place(gore, 0.025),
        place(dying, 0.05),
    ), 1.75), 0.2, 0.2)


# ─────────────────────────────────────────────────────────────
# 5. 机械寄生甲虫（bug_mech_beetle）：半生物半机械装甲撞击、伺服电机异响、电磁干扰脉冲
# ─────────────────────────────────────────────────────────────
@sfx("bug_mech_beetle_appear", n=2, target=-15.5, dur=0.8, fout=0.09)
def _mech_beetle_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    cl = clank(0.28, 240 * p, METAL_HEAVY, 12.0, rng, 0.82)
    srv = servo(0.26, 150 * p, 280 * p, rng, 0.45)
    spark = zap(0.22, 2100 * p, rng, 34) * 0.52
    vox = voice(0.48, 88 * p, 135 * p, rng, 9.5, 0.36, 2.1) * 0.78
    return sat(mix(
        place(cl, 0.0),
        place(srv, 0.02),
        place(spark, 0.06),
        place(vox, 0.10),
    ), 1.65)


@sfx("bug_mech_beetle_windup", n=2, target=-15.5, dur=0.7, fout=0.08)
def _mech_beetle_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    spool = turbine(0.48, 95 * p, 245 * p, rng, 5, 0.1) * 0.65
    cl = clank(0.22, 260 * p, METAL_HEAVY, 14.0, rng, 0.78)
    vox = voice(0.45, 80 * p, 155 * p, rng, 10.5, 0.38, 2.2) * 0.75
    return sat(mix(place(cl, 0.0), place(spool, 0.03), place(vox, 0.06)), 1.6)


@sfx("bug_mech_beetle_attack", n=2, target=-14.5, dur=0.8, fout=0.09)
def _mech_beetle_attack(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    slam_sub = thump(0.40, 122 * p, 24 * p, 8.5, rng, 2.6)
    metal_hit = clank(0.36, 215 * p, METAL_HEAVY, 10.0, rng, 0.9)
    arc = zap(0.28, 2250 * p, rng, 38) * 0.62
    roar_v = voice(0.42, 118 * p, 68 * p, rng, 10.0, 0.38, 2.2) * 0.78
    return sat(mix(
        place(slam_sub, 0.0),
        place(metal_hit, 0.005),
        place(arc, 0.015),
        place(roar_v, 0.03),
    ), 1.75)


@sfx("bug_mech_beetle_jam", n=2, target=-15.0, dur=0.9, fout=0.1)
def _mech_beetle_jam(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 释放EMP机械阻滞脉冲：电磁爆震 + 狂暴电弧 + 金属腔体共鸣
    emp_sub = thump(0.38, 128 * p, 26 * p, 9.0, rng, 2.5)
    emp_zap = zap(0.55, 2400 * p, rng, 48) * 0.78
    mag_buzz = buzz(0.52, 92 * p, 58 * p, rng, 2.1) * 0.65
    cl = clank(0.30, 280 * p, METAL_HOLLOW, 12.0, rng, 0.78)
    return reverb_tail(sat(mix(
        place(emp_sub, 0.0),
        place(cl, 0.006),
        place(emp_zap, 0.012),
        place(mag_buzz, 0.025),
    ), 1.7), 0.2, 0.18)


@sfx("bug_mech_beetle_hurt", n=3, target=-15.5, dur=0.65, fout=0.07)
def _mech_beetle_hurt(v, rng):
    p = 1.0 + (v - 1.0) * 0.05
    th = thump(0.28, 115 * p, 28 * p, 11.5, rng, 2.3)
    cl = clank(0.28, 250 * p, METAL_HEAVY, 12.0, rng, 0.82)
    spark = zap(0.22, 2200 * p, rng, 34) * 0.55
    wet = squelch(0.26, 260 * p, 1080 * p, rng, 1.9) * 0.65
    grunt = voice(0.35, 108 * p, 66 * p, rng, 9.5, 0.38, 2.1) * 0.75
    return sat(mix(
        place(th, 0.0),
        place(cl, 0.005),
        place(spark, 0.015),
        place(wet, 0.03),
        place(grunt, 0.04),
    ), 1.65)


@sfx("bug_mech_beetle_death", n=2, target=-14.0, dur=1.2, fout=0.15)
def _mech_beetle_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    sub = thump(0.45, 122 * p, 24 * p, 8.0, rng, 2.7)
    metal_rip = clank(0.45, 195 * p, METAL_HEAVY, 8.5, rng, 0.9)
    arc = zap(0.42, 2150 * p, rng, 42) * 0.68
    gore = squelch(0.52, 240 * p, 1280 * p, rng, 2.2) * 0.8
    dying = voice(0.68, 95 * p, 48 * p, rng, 8.5, 0.42, 2.3) * 0.82
    return reverb_tail(sat(mix(
        place(sub, 0.0),
        place(metal_rip, 0.006),
        place(arc, 0.015),
        place(gore, 0.035),
        place(dying, 0.055),
    ), 1.8), 0.22, 0.2)


# ─────────────────────────────────────────────────────────────
# 6. 掠食毒蜂（bug_wasp）：几丁质膜翅低中频拍击（110-165 Hz，绝无高频蚊音）、尾针破空毒刺
# ─────────────────────────────────────────────────────────────
@sfx("bug_wasp_appear", n=2, target=-16.5, dur=0.65, fout=0.07)
def _wasp_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 巨型甲壳翅翼拍击气浪 + 口器咔哒 + 嘶鸣
    wings = buzz(0.52, 125 * p, 148 * p, rng, 1.8) * env_adsr(0.52, 0.05, 0.15, 0.7, 0.2) * 0.68
    flutter = whoosh(0.45, 320 * p, 1150 * p, rng, 2.0) * 0.65
    rasp = voice(0.35, 185 * p, 255 * p, rng, 16.0, 0.32, 2.0) * 0.72
    return sat(mix(place(wings, 0.0), place(flutter, 0.02), place(rasp, 0.06)), 1.5)


@sfx("bug_wasp_windup", n=2, target=-16.5, dur=0.55, fout=0.06)
def _wasp_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    wings_up = buzz(0.42, 130 * p, 175 * p, rng, 1.9) * 0.72
    chitin = modal(0.18, 460 * p, CHITIN_MODES, 18.0, rng, 0.68)
    vox = voice(0.32, 165 * p, 270 * p, rng, 17.0, 0.35, 2.1) * 0.72
    return sat(mix(place(wings_up, 0.0), place(chitin, 0.02), place(vox, 0.04)), 1.5)


@sfx("bug_wasp_attack", n=2, target=-15.5, dur=0.55, fout=0.06)
def _wasp_attack(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 俯冲毒针刺击：高速破风 + 骨针穿透脆响 + 毒液高压注入
    dive = whoosh(0.22, 420 * p, 1750 * p, rng, 2.5) * 0.8
    sting_snap = crack(0.06, 2250 * p, rng, 2.3) * 0.88
    sting_th = thump(0.16, 120 * p, 38 * p, 18.0, rng, 2.0) * 0.72
    venom_sq = squelch(0.22, 360 * p, 1420 * p, rng, 2.1) * 0.75
    shriek = voice(0.25, 235 * p, 135 * p, rng, 18.0, 0.35, 2.1) * 0.7
    return sat(mix(
        place(dive, 0.0),
        place(sting_snap, 0.06),
        place(sting_th, 0.063),
        place(shriek, 0.07),
        place(venom_sq, 0.085),
    ), 1.6)


@sfx("bug_wasp_hurt", n=3, target=-16.0, dur=0.48, fout=0.05)
def _wasp_hurt(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    crk = crack(0.06, 2000 * p, rng, 2.1) * 0.82
    wings_stutter = buzz(0.22, 155 * p, 95 * p, rng, 2.0) * env_exp(0.22, 12.0) * 0.65
    wet = squelch(0.22, 340 * p, 1280 * p, rng, 2.0) * 0.72
    yelp = voice(0.25, 245 * p, 120 * p, rng, 19.0, 0.36, 2.2) * 0.75
    return sat(mix(
        place(crk, 0.0),
        place(wings_stutter, 0.005),
        place(wet, 0.015),
        place(yelp, 0.025),
    ), 1.55)


@sfx("bug_wasp_death", n=2, target=-15.5, dur=0.75, fout=0.08)
def _wasp_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    crush_th = thump(0.24, 115 * p, 32 * p, 14.0, rng, 2.2)
    wing_rip = crack(0.09, 1950 * p, rng, 2.2) * 0.85
    spiral_down = buzz(0.38, 150 * p, 68 * p, rng, 2.0) * env_exp(0.38, 6.0) * 0.65
    gore = squelch(0.42, 300 * p, 1380 * p, rng, 2.2) * 0.85
    dying = voice(0.45, 215 * p, 75 * p, rng, 15.0, 0.38, 2.1) * 0.75
    return sat(mix(
        place(crush_th, 0.0),
        place(wing_rip, 0.005),
        place(spiral_down, 0.01),
        place(gore, 0.02),
        place(dying, 0.04),
    ), 1.6)


# ─────────────────────────────────────────────────────────────
# 7. 盾甲壁垒虫（bug_shielder）：重型生物骨盾合拢砸地、生物力场脉动、沉重顶撞
# ─────────────────────────────────────────────────────────────
@sfx("bug_shielder_appear", n=2, target=-15.5, dur=0.85, fout=0.09)
def _shielder_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    shield_slam = thump(0.35, 112 * p, 26 * p, 10.0, rng, 2.4)
    plate_lock = modal(0.35, 210 * p, CHITIN_MODES, 10.0, rng, 0.85)
    bellow = voice(0.52, 76 * p, 118 * p, rng, 8.5, 0.36, 2.2) * 0.8
    return sat(mix(
        place(shield_slam, 0.0),
        place(plate_lock, 0.008),
        place(bellow, 0.08),
    ), 1.65)


@sfx("bug_shielder_windup", n=2, target=-15.5, dur=0.7, fout=0.08)
def _shielder_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    brace_th = thump(0.28, 102 * p, 28 * p, 12.0, rng, 2.2)
    chitin = modal(0.34, 195 * p, CHITIN_MODES, 9.5, rng, 0.8)
    vox = voice(0.46, 72 * p, 132 * p, rng, 9.0, 0.38, 2.2) * 0.78
    return sat(mix(place(brace_th, 0.0), place(chitin, 0.02), place(vox, 0.06)), 1.6)


@sfx("bug_shielder_pulse", n=2, target=-14.5, dur=0.95, fout=0.1)
def _shielder_pulse(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 骨盾砸地激发震荡波：厚重骨板轰击地面 + 低频生物电磁场谐振扩散
    slam = thump(0.45, 122 * p, 24 * p, 8.0, rng, 2.6)
    plate = modal(0.42, 205 * p, CHITIN_MODES, 9.0, rng, 0.88)
    field_hum = buzz(0.65, 68 * p, 112 * p, rng, 1.8) * env_adsr(0.65, 0.05, 0.2, 0.6, 0.3) * 0.62
    cryst = modal(0.55, 440 * p, GLASS_MODES, 7.5, rng, 0.55) * 0.48
    return reverb_tail(sat(mix(
        place(slam, 0.0),
        place(plate, 0.006),
        place(field_hum, 0.04),
        place(cryst, 0.06),
    ), 1.7), 0.2, 0.2)


@sfx("bug_shielder_attack", n=1, target=-14.5, dur=0.8, fout=0.09)
def _shielder_attack(v, rng):
    rush = whoosh(0.22, 180, 720, rng, 2.1) * 0.72
    bash_sub = thump(0.42, 120, 24, 8.5, rng, 2.6)
    bash_plate = modal(0.38, 195, CHITIN_MODES, 9.5, rng, 0.9)
    crk = crack(0.11, 1500, rng, 2.2) * 0.82
    roar_v = voice(0.40, 110, 64, rng, 9.5, 0.38, 2.2) * 0.78
    return sat(mix(
        place(rush, 0.0),
        place(bash_sub, 0.09),
        place(bash_plate, 0.095),
        place(crk, 0.10),
        place(roar_v, 0.12),
    ), 1.75)


@sfx("bug_shielder_hurt", n=2, target=-15.5, dur=0.65, fout=0.07)
def _shielder_hurt(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    th = thump(0.32, 112 * p, 28 * p, 11.0, rng, 2.3)
    plate = modal(0.30, 220 * p, CHITIN_MODES, 10.5, rng, 0.85)
    crk = crack(0.085, 1600 * p, rng, 2.1) * 0.78
    grunt = voice(0.36, 98 * p, 62 * p, rng, 9.0, 0.38, 2.1) * 0.75
    return sat(mix(place(th, 0.0), place(plate, 0.005), place(crk, 0.01), place(grunt, 0.03)), 1.6)


@sfx("bug_shielder_death", n=2, target=-14.0, dur=1.2, fout=0.15)
def _shielder_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    sub = thump(0.48, 118 * p, 22 * p, 7.5, rng, 2.7)
    shield_break = modal(0.48, 190 * p, CHITIN_MODES, 8.0, rng, 0.9)
    snap = crack(0.15, 1500 * p, rng, 2.3) * 0.85
    gore = squelch(0.55, 235 * p, 1250 * p, rng, 2.2) * 0.82
    dying = voice(0.72, 90 * p, 45 * p, rng, 8.0, 0.42, 2.3) * 0.82
    return reverb_tail(sat(mix(
        place(sub, 0.0),
        place(shield_break, 0.008),
        place(snap, 0.012),
        place(gore, 0.03),
        place(dying, 0.05),
    ), 1.8), 0.22, 0.2)


# ─────────────────────────────────────────────────────────────
# 8. 生物迫击炮虫（bug_mortar）：背部巨型气室蓄压、生物臼炮深沉闷嘭喷射
# ─────────────────────────────────────────────────────────────
@sfx("bug_mortar_appear", n=2, target=-15.5, dur=0.85, fout=0.09)
def _mortar_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    anchor_th = thump(0.34, 105 * p, 26 * p, 11.0, rng, 2.3)
    sac_churn = squelch(0.45, 210 * p, 920 * p, rng, 1.9) * 0.78
    bellow = voice(0.52, 74 * p, 112 * p, rng, 8.0, 0.36, 2.1) * 0.78
    return sat(mix(place(anchor_th, 0.0), place(sac_churn, 0.04), place(bellow, 0.08)), 1.6)


@sfx("bug_mortar_windup", n=2, target=-15.5, dur=0.8, fout=0.09)
def _mortar_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 背部炮囊剧烈蠕动收缩蓄压
    swell = thump(0.38, 82 * p, 42 * p, 9.0, rng, 2.3)
    gurgle = squelch(0.55, 220 * p, 1280 * p, rng, 2.2) * 0.85
    groan = voice(0.52, 68 * p, 145 * p, rng, 10.0, 0.38, 2.2) * 0.78
    return sat(mix(place(swell, 0.0), place(gurgle, 0.03), place(groan, 0.06)), 1.65)


@sfx("bug_mortar_launch", n=3, target=-13.5, dur=0.95, fout=0.12)
def _mortar_launch(v, rng):
    p = 1.0 + (v - 1.0) * 0.05
    # 生物迫击炮击发：深沉厚重的气囊爆压“嘭！” + 粘稠炮弹破空呼啸
    pop_boom = thump(0.48, 128 * p, 24 * p, 7.5, rng, 2.8)
    tube_res = modal(0.38, 165 * p, CHITIN_MODES, 9.0, rng, 0.85)
    wet_blast = squelch(0.48, 320 * p, 1550 * p, rng, 2.4) * 0.88
    air_whoosh = whoosh(0.58, 240 * p, 1180 * p, rng, 2.3) * 0.75
    return reverb_tail(sat(mix(
        place(pop_boom, 0.0),
        place(tube_res, 0.005),
        place(wet_blast, 0.012),
        place(air_whoosh, 0.05),
    ), 1.8), 0.22, 0.2)


@sfx("bug_mortar_attack", n=2, target=-14.0, dur=0.85, fout=0.1)
def _mortar_attack(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    return _mortar_launch(v, rng)


@sfx("bug_mortar_hurt", n=2, target=-15.5, dur=0.65, fout=0.07)
def _mortar_hurt(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    th = thump(0.30, 108 * p, 28 * p, 11.5, rng, 2.2)
    splat = squelch(0.38, 260 * p, 1320 * p, rng, 2.1) * 0.82
    groan = voice(0.38, 95 * p, 58 * p, rng, 9.0, 0.38, 2.1) * 0.75
    return sat(mix(place(th, 0.0), place(splat, 0.015), place(groan, 0.03)), 1.6)


@sfx("bug_mortar_death", n=2, target=-13.5, dur=1.25, fout=0.16)
def _mortar_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    sub = thump(0.52, 122 * p, 22 * p, 7.0, rng, 2.8)
    sac_burst = squelch(0.75, 240 * p, 1580 * p, rng, 2.5) * 0.92
    roar_b = roar(0.75, 185 * p, 4.2, rng, 2.2) * 0.82
    dying = voice(0.72, 88 * p, 44 * p, rng, 8.0, 0.42, 2.3) * 0.82
    return reverb_tail(sat(mix(
        place(sub, 0.0),
        place(sac_burst, 0.012),
        place(roar_b, 0.02),
        place(dying, 0.05),
    ), 1.85), 0.24, 0.22)


# ─────────────────────────────────────────────────────────────
# 9. 铁颚碎甲虫（bug_ironjaw）：液压捕兽夹般的合金巨颚咬合、刺耳金属撕裂
# ─────────────────────────────────────────────────────────────
@sfx("bug_ironjaw_appear", n=2, target=-15.5, dur=0.8, fout=0.09)
def _ironjaw_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    jaw_snap = clank(0.26, 260 * p, METAL_HEAVY, 14.0, rng, 0.85)
    th = thump(0.28, 112 * p, 28 * p, 12.0, rng, 2.3)
    growl = voice(0.48, 86 * p, 138 * p, rng, 9.5, 0.36, 2.2) * 0.8
    return sat(mix(place(jaw_snap, 0.0), place(th, 0.005), place(growl, 0.08)), 1.65)


@sfx("bug_ironjaw_windup", n=2, target=-15.5, dur=0.7, fout=0.08)
def _ironjaw_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 巨颚大张蓄力：肌腱与几丁质棘轮拉伸嘎吱声
    crank = modal(0.35, 240 * p, CHITIN_MODES, 10.0, rng, 0.8)
    metal_rub = clank(0.22, 320 * p, METAL_HEAVY, 16.0, rng, 0.72) * 0.68
    vox = voice(0.45, 78 * p, 152 * p, rng, 10.5, 0.38, 2.2) * 0.78
    return sat(mix(place(crank, 0.0), place(metal_rub, 0.03), place(vox, 0.06)), 1.6)


@sfx("bug_ironjaw_attack", n=2, target=-14.0, dur=0.75, fout=0.08)
def _ironjaw_attack(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 铁颚断头台式咬合：捕兽夹般极具穿透力的重金属咬合巨响 + 破甲低频冲击
    lunge = whoosh(0.18, 260 * p, 980 * p, rng, 2.2) * 0.75
    clamp_sub = thump(0.40, 128 * p, 24 * p, 8.5, rng, 2.7)
    jaw_clang = clank(0.36, 235 * p, METAL_HEAVY, 10.0, rng, 0.92)
    snap = crack(0.095, 1950 * p, rng, 2.4) * 0.88
    snarl = voice(0.36, 125 * p, 68 * p, rng, 11.0, 0.38, 2.2) * 0.78
    return sat(mix(
        place(lunge, 0.0),
        place(clamp_sub, 0.075),
        place(jaw_clang, 0.078),
        place(snap, 0.082),
        place(snarl, 0.095),
    ), 1.8)


@sfx("bug_ironjaw_hurt", n=3, target=-15.5, dur=0.6, fout=0.07)
def _ironjaw_hurt(v, rng):
    p = 1.0 + (v - 1.0) * 0.05
    th = thump(0.28, 115 * p, 28 * p, 11.5, rng, 2.3)
    cl = clank(0.26, 270 * p, METAL_HEAVY, 13.0, rng, 0.8)
    wet = squelch(0.26, 270 * p, 1180 * p, rng, 2.0) * 0.7
    grunt = voice(0.34, 108 * p, 64 * p, rng, 10.0, 0.38, 2.1) * 0.75
    return sat(mix(place(th, 0.0), place(cl, 0.005), place(wet, 0.02), place(grunt, 0.03)), 1.65)


@sfx("bug_ironjaw_death", n=2, target=-14.0, dur=1.15, fout=0.14)
def _ironjaw_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    sub = thump(0.45, 120 * p, 22 * p, 8.0, rng, 2.6)
    jaw_break = clank(0.42, 210 * p, METAL_HEAVY, 9.0, rng, 0.88)
    crk = crack(0.14, 1750 * p, rng, 2.3) * 0.85
    gore = squelch(0.52, 245 * p, 1320 * p, rng, 2.2) * 0.82
    dying = voice(0.68, 95 * p, 46 * p, rng, 8.5, 0.42, 2.3) * 0.82
    return reverb_tail(sat(mix(
        place(sub, 0.0),
        place(jaw_break, 0.006),
        place(crk, 0.01),
        place(gore, 0.03),
        place(dying, 0.05),
    ), 1.8), 0.22, 0.2)
