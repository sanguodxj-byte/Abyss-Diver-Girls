# -*- coding: utf-8 -*-
"""基础虫族（跳虫 ling / 酸液喷吐虫 spitter / 重甲虫 beetle）与虫巢音效（生物声带+甲壳碎裂重制版）。"""
import numpy as np
from sfx_dsp import (
    SR, sfx, env_exp, env_adsr, biquad, reson, sweep,
    white, pink, brown, velvet, sat, place, mix, reverb_tail,
)
from sfx_lib import (
    thump, crack, tick, clank, modal, CHITIN_MODES, METAL_HEAVY,
    hiss, whoosh, roar, rumble, squelch, voice,
)


# ─────────────────────────────────────────────────────────────
# 迅捷跳虫（bug_ling）：高频步足抓地、几丁质颚片咔哒摩擦、喉部嘶鸣（零16-bit方波）
# ─────────────────────────────────────────────────────────────
@sfx("bug_ling_appear", n=3, target=-17.0, dur=0.55, fout=0.06)
def _ling_appear(v, rng):
    p = 1.0 + (v - 1.0) * 0.07
    # 跳虫窜出：步足急促抓扒地面 + 颚片双连咔哒 + 短促气门嘶声
    scurry1 = crack(0.045, 1900 * p, rng, 1.8) * 0.65
    scurry2 = crack(0.050, 2200 * p, rng, 1.8) * 0.72
    mandible = modal(0.14, 520 * p, CHITIN_MODES, 22.0, rng, 0.65)
    growl = voice(0.32, 165 * p, 235 * p, rng, 14.0, 0.28, 1.9) * 0.75
    breath = hiss(0.24, 2400 * p, 1400, 12.0, rng) * 0.45
    return sat(mix(
        place(scurry1, 0.0),
        place(scurry2, 0.045),
        place(mandible, 0.06),
        place(growl, 0.08),
        place(breath, 0.09),
    ), 1.5)


@sfx("bug_ling_windup", n=2, target=-17.5, dur=0.45, fout=0.05)
def _ling_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 扑击前蓄力：甲壳收紧摩擦 + 喉腔低沉吸气嘶鸣
    chitin_rub = modal(0.18, 460 * p, CHITIN_MODES, 18.0, rng, 0.6)
    inhale = whoosh(0.28, 950 * p, 420 * p, rng, 2.0) * 0.65
    rasp = voice(0.28, 140 * p, 260 * p, rng, 18.0, 0.35, 2.0) * 0.72
    return sat(mix(
        place(chitin_rub, 0.0),
        place(inhale, 0.03),
        place(rasp, 0.05),
    ), 1.45)


@sfx("bug_ling_attack", n=3, target=-16.0, dur=0.48, fout=0.05)
def _ling_attack(v, rng):
    p = 1.0 + (v - 1.0) * 0.07
    # 跳虫撕咬：破风扑击 + 锋利口器狠狠闭合脆响 + 粘液飞溅
    leap_air = whoosh(0.18, 380 * p, 1450 * p, rng, 2.2) * 0.72
    bite_snap = crack(0.065, 2100 * p, rng, 2.2) * 0.88
    jaw_clack = modal(0.16, 480 * p, CHITIN_MODES, 20.0, rng, 0.75)
    bite_thump = thump(0.16, 115 * p, 38 * p, 18.0, rng, 2.0) * 0.7
    spit_wet = squelch(0.18, 360 * p, 1150 * p, rng, 1.8) * 0.55
    snarl = voice(0.22, 220 * p, 135 * p, rng, 16.0, 0.32, 2.1) * 0.68
    return sat(mix(
        place(leap_air, 0.0),
        place(bite_snap, 0.065),
        place(jaw_clack, 0.068),
        place(bite_thump, 0.070),
        place(snarl, 0.075),
        place(spit_wet, 0.095),
    ), 1.6)


@sfx("bug_ling_hurt", n=3, target=-16.5, dur=0.45, fout=0.05)
def _ling_hurt(v, rng):
    p = 1.0 + (v - 1.0) * 0.07
    # 跳虫受创：甲壳被击穿脆裂 + 粘稠体液飙出 + 短促抽搐痛嘶
    shell_crack = crack(0.06, 1950 * p, rng, 2.0) * 0.82
    chitin = modal(0.16, 440 * p, CHITIN_MODES, 20.0, rng, 0.7)
    splat = squelch(0.24, 340 * p, 1280 * p, rng, 2.0) * 0.75
    yelp = voice(0.25, 245 * p, 125 * p, rng, 20.0, 0.35, 2.2) * 0.72
    return sat(mix(
        place(shell_crack, 0.0),
        place(chitin, 0.004),
        place(splat, 0.015),
        place(yelp, 0.025),
    ), 1.55)


@sfx("bug_ling_death", n=3, target=-15.5, dur=0.72, fout=0.08)
def _ling_death(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    # 跳虫毙命：胸腔甲壳彻底爆裂 + 浆液飞溅 + 喉部泄气绝命低嘶 + 躯干摔落地面
    crush_sub = thump(0.26, 118 * p, 32 * p, 13.0, rng, 2.3)
    shell_break = crack(0.09, 1800 * p, rng, 2.2) * 0.88
    chitin = modal(0.24, 390 * p, CHITIN_MODES, 15.0, rng, 0.75)
    gore = squelch(0.42, 290 * p, 1350 * p, rng, 2.2) * 0.85
    death_rattle = voice(0.45, 195 * p, 78 * p, rng, 14.0, 0.38, 2.0) * 0.75
    body_drop = thump(0.18, 92 * p, 30 * p, 18.0, rng, 1.8) * 0.62
    return sat(mix(
        place(crush_sub, 0.0),
        place(shell_break, 0.005),
        place(chitin, 0.008),
        place(gore, 0.02),
        place(death_rattle, 0.04),
        place(body_drop, 0.34),
    ), 1.65)


# ─────────────────────────────────────────────────────────────
# 酸液喷吐虫（bug_spitter）：腹腔酸囊咕嘟翻涌、气道压缩、高压粘液喷射
# ─────────────────────────────────────────────────────────────
@sfx("bug_spitter_appear", n=2, target=-16.5, dur=0.7, fout=0.08)
def _spitter_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 喷吐虫现身：湿滑软体蠕动 + 咽喉囊袋鼓胀低吼
    slither = squelch(0.38, 240 * p, 860 * p, rng, 1.8) * 0.78
    sac_thump = thump(0.24, 98 * p, 32 * p, 14.0, rng, 1.9) * 0.65
    gurgle_voice = voice(0.45, 125 * p, 175 * p, rng, 11.0, 0.32, 1.9) * 0.75
    return sat(mix(
        place(slither, 0.0),
        place(sac_thump, 0.05),
        place(gurgle_voice, 0.08),
    ), 1.5)


@sfx("bug_spitter_windup", n=2, target=-16.5, dur=0.65, fout=0.07)
def _spitter_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 喷吐前蓄力：腹腔酸液剧烈反刍翻涌 + 咽部括约肌收紧吸气
    churn = squelch(0.45, 220 * p, 1150 * p, rng, 2.1) * 0.85
    suck_in = whoosh(0.38, 850 * p, 280 * p, rng, 2.0) * 0.68
    throat_swell = voice(0.42, 95 * p, 190 * p, rng, 14.0, 0.3, 2.0) * 0.72
    return sat(mix(
        place(churn, 0.0),
        place(suck_in, 0.04),
        place(throat_swell, 0.06),
    ), 1.55)


@sfx("bug_spitter_attack", n=3, target=-15.5, dur=0.65, fout=0.07)
def _spitter_attack(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    # 高压酸液喷射：囊腔爆压闷响 + 浓稠酸液喷口炸裂 + 腐蚀性气雾嘶鸣
    sac_pop = thump(0.24, 122 * p, 36 * p, 14.0, rng, 2.2)
    spit_blast = squelch(0.38, 380 * p, 1650 * p, rng, 2.4) * 0.92
    acid_hiss = hiss(0.42, 2400 * p, 1500, 7.5, rng) * 0.68
    retching = voice(0.28, 185 * p, 110 * p, rng, 16.0, 0.35, 2.1) * 0.7
    return sat(mix(
        place(sac_pop, 0.0),
        place(spit_blast, 0.012),
        place(retching, 0.018),
        place(acid_hiss, 0.035),
    ), 1.65)


@sfx("bug_spitter_hurt", n=3, target=-16.0, dur=0.55, fout=0.06)
def _spitter_hurt(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    # 喷吐虫受创：软甲破裂 + 酸囊泄漏滋滋声 + 湿哑痛嚎
    th = thump(0.20, 108 * p, 34 * p, 16.0, rng, 2.0) * 0.7
    burst = squelch(0.34, 310 * p, 1380 * p, rng, 2.2) * 0.85
    leak_hiss = hiss(0.32, 2200 * p, 1400, 9.0, rng) * 0.52
    groan = voice(0.32, 165 * p, 95 * p, rng, 15.0, 0.35, 2.0) * 0.72
    return sat(mix(
        place(th, 0.0),
        place(burst, 0.008),
        place(groan, 0.02),
        place(leak_hiss, 0.04),
    ), 1.55)


@sfx("bug_spitter_death", n=2, target=-15.0, dur=0.95, fout=0.1)
def _spitter_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 喷吐虫死亡：体内酸液囊彻底炸裂爆浆 + 地面强酸腐蚀沸腾 + 低沉抽气哀鸣
    pop_boom = thump(0.36, 120 * p, 28 * p, 10.0, rng, 2.5)
    shell_snap = crack(0.09, 1600 * p, rng, 2.0) * 0.75
    mega_splat = squelch(0.62, 260 * p, 1550 * p, rng, 2.5) * 0.92
    boil_hiss = hiss(0.65, 2100 * p, 1400, 4.5, rng) * 0.62
    dying_gurgle = voice(0.55, 145 * p, 62 * p, rng, 12.0, 0.4, 2.1) * 0.75
    return reverb_tail(sat(mix(
        place(pop_boom, 0.0),
        place(shell_snap, 0.006),
        place(mega_splat, 0.015),
        place(dying_gurgle, 0.04),
        place(boil_hiss, 0.08),
    ), 1.7), 0.18, 0.18)


# ─────────────────────────────────────────────────────────────
# 重甲巨虫（bug_beetle）：厚重骨板撞击、大地颤动、超低频胸腔共鸣咆哮
# ─────────────────────────────────────────────────────────────
@sfx("bug_beetle_appear", n=2, target=-15.5, dur=0.9, fout=0.1)
def _beetle_appear(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 重甲虫登场：沉重步足砸地 + 背部厚重骨板摩擦碰撞 + 胸腔深沉瓮声低吼
    stomp1 = thump(0.28, 105 * p, 28 * p, 12.0, rng, 2.3)
    plate1 = modal(0.26, 220 * p, CHITIN_MODES, 12.0, rng, 0.75)
    stomp2 = thump(0.32, 95 * p, 26 * p, 11.0, rng, 2.4)
    bellow = voice(0.58, 78 * p, 115 * p, rng, 8.5, 0.35, 2.2) * 0.82
    sub_roar = roar(0.52, 160 * p, 5.0, rng, 1.9) * 0.68
    return sat(mix(
        place(stomp1, 0.0),
        place(plate1, 0.008),
        place(bellow, 0.12),
        place(sub_roar, 0.14),
        place(stomp2, 0.24),
    ), 1.65)


@sfx("bug_beetle_windup", n=2, target=-15.5, dur=0.8, fout=0.08)
def _beetle_windup(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 重甲虫冲撞蓄力：前足刨地碎石飞溅 + 头角压低甲壳嘎吱作响 + 鼻腔粗重喷气
    paw_ground = thump(0.26, 98 * p, 30 * p, 13.0, rng, 2.1)
    chitin_creak = modal(0.38, 195 * p, CHITIN_MODES, 9.0, rng, 0.78)
    snort = hiss(0.42, 1350 * p, 900, 6.5, rng) * 0.62
    deep_growl = voice(0.52, 68 * p, 128 * p, rng, 9.0, 0.38, 2.2) * 0.8
    return sat(mix(
        place(paw_ground, 0.0),
        place(chitin_creak, 0.04),
        place(deep_growl, 0.08),
        place(snort, 0.12),
    ), 1.6)


@sfx("bug_beetle_attack", n=2, target=-14.5, dur=0.85, fout=0.1)
def _beetle_attack(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 巨角猛烈顶撞：破风冲刺 + 攻城锤般的骨板巨响 + 低频震波
    rush = whoosh(0.24, 180 * p, 780 * p, rng, 2.2) * 0.75
    ram_sub = thump(0.45, 122 * p, 24 * p, 8.0, rng, 2.7)
    horn_slam = modal(0.38, 210 * p, CHITIN_MODES, 9.5, rng, 0.9)
    horn_crack = crack(0.11, 1450 * p, rng, 2.2) * 0.82
    roar_atk = voice(0.42, 115 * p, 68 * p, rng, 10.0, 0.38, 2.3) * 0.78
    return reverb_tail(sat(mix(
        place(rush, 0.0),
        place(ram_sub, 0.11),
        place(horn_slam, 0.115),
        place(horn_crack, 0.118),
        place(roar_atk, 0.13),
    ), 1.75), 0.18, 0.18)


@sfx("bug_beetle_hurt", n=3, target=-15.5, dur=0.65, fout=0.07)
def _beetle_hurt(v, rng):
    p = 1.0 + (v - 1.0) * 0.05
    # 重甲虫受创：厚重甲壳闷响 + 骨板裂纹声 + 沉闷痛吼
    th = thump(0.32, 112 * p, 28 * p, 11.0, rng, 2.3)
    shell = modal(0.30, 235 * p, CHITIN_MODES, 11.0, rng, 0.82)
    crk = crack(0.085, 1550 * p, rng, 2.0) * 0.75
    wet = squelch(0.26, 260 * p, 980 * p, rng, 1.8) * 0.62
    grunt = voice(0.38, 105 * p, 65 * p, rng, 9.5, 0.38, 2.1) * 0.78
    return sat(mix(
        place(th, 0.0),
        place(shell, 0.005),
        place(crk, 0.008),
        place(grunt, 0.025),
        place(wet, 0.04),
    ), 1.6)


@sfx("bug_beetle_death", n=2, target=-14.0, dur=1.25, fout=0.15)
def _beetle_death(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 重甲虫轰然毙命：背甲崩裂解体 + 深沉绝命咆哮 + 数吨虫躯砸地巨震
    break_sub = thump(0.42, 118 * p, 26 * p, 8.5, rng, 2.5)
    carapace_shatter = modal(0.45, 205 * p, CHITIN_MODES, 8.5, rng, 0.88)
    snap = crack(0.14, 1500 * p, rng, 2.3) * 0.85
    gore = squelch(0.55, 240 * p, 1250 * p, rng, 2.2) * 0.82
    dying_bellow = voice(0.75, 98 * p, 48 * p, rng, 8.0, 0.42, 2.3) * 0.85
    collapse_sub = thump(0.50, 95 * p, 22 * p, 7.5, rng, 2.6) * 0.88
    return reverb_tail(sat(mix(
        place(break_sub, 0.0),
        place(carapace_shatter, 0.008),
        place(snap, 0.012),
        place(gore, 0.03),
        place(dying_bellow, 0.05),
        place(collapse_sub, 0.55),
    ), 1.8), 0.22, 0.2)


# ─────────────────────────────────────────────────────────────
# 虫族母巢建筑（nest_loop / nest_spawn / nest_hurt / nest_destroyed）
# ─────────────────────────────────────────────────────────────
@sfx("nest_loop", n=1, target=-19.0, loop=4.2, reps=4)
def _nest_loop(v, rng):
    dur = 4.2
    # 虫巢脉动循环：深层地热生物腔体低频搏动 + 粘稠羊水囊周期性蠕动呼吸
    sub_pulse = rumble(dur, 58, 4.5, rng, 1.7) * 0.68
    beats = np.zeros(int(dur * SR))
    for i in range(3):
        t0 = i * 1.4 + 0.15
        hb1 = thump(0.28, 78, 26, 11.0, rng, 2.0) * 0.58
        hb2 = thump(0.24, 65, 24, 13.0, rng, 1.8) * 0.45
        sq = squelch(0.55, 190, 680, rng, 1.6) * 0.48
        br = voice(0.65, 62, 82, rng, 6.5, 0.35, 1.7) * 0.38
        beats = mix(
            beats,
            place(hb1, t0, dur),
            place(hb2, t0 + 0.24, dur),
            place(sq, t0 + 0.1, dur),
            place(br, t0 + 0.2, dur),
        )
    return sat(mix(sub_pulse, beats), 1.35)


@sfx("nest_spawn", n=2, target=-15.5, dur=1.1, fout=0.12)
def _nest_spawn(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 虫巢孵化喷出虫群：肉囊内部气压蓄积 -> 胎膜撕裂爆浆 -> 幼体嘶吼窜出
    swell = thump(0.35, 110 * p, 28 * p, 9.5, rng, 2.3)
    membrane_rip = squelch(0.62, 260 * p, 1450 * p, rng, 2.3) * 0.9
    chitin_pop = crack(0.10, 1650 * p, rng, 2.0) * 0.75
    brood_hiss = voice(0.52, 135 * p, 210 * p, rng, 13.0, 0.35, 2.0) * 0.72
    air_puff = hiss(0.45, 1850 * p, 1200, 6.5, rng) * 0.48
    return reverb_tail(sat(mix(
        place(swell, 0.0),
        place(membrane_rip, 0.08),
        place(chitin_pop, 0.09),
        place(brood_hiss, 0.15),
        place(air_puff, 0.18),
    ), 1.65), 0.18, 0.18)


@sfx("nest_hurt", n=2, target=-15.5, dur=0.75, fout=0.08)
def _nest_hurt(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 虫巢受创：外层硬化几丁质壁碎裂 + 大量组织液喷溅 + 巢穴深处低沉震颤
    th = thump(0.36, 115 * p, 26 * p, 10.0, rng, 2.4)
    wall_crack = modal(0.32, 220 * p, CHITIN_MODES, 10.5, rng, 0.82)
    snap = crack(0.10, 1600 * p, rng, 2.1) * 0.8
    splat = squelch(0.45, 280 * p, 1320 * p, rng, 2.1) * 0.85
    cavity_groan = voice(0.45, 82 * p, 54 * p, rng, 8.0, 0.4, 2.1) * 0.72
    return sat(mix(
        place(th, 0.0),
        place(wall_crack, 0.006),
        place(snap, 0.01),
        place(splat, 0.025),
        place(cavity_groan, 0.04),
    ), 1.65)


@sfx("nest_destroyed", n=1, target=-13.0, dur=2.6, fout=0.35)
def _nest_destroyed(v, rng):
    # 虫巢彻底坍塌毁灭：地下生物腔室连环内爆 + 巨型甲壳穹顶崩塌 + 漫天粘液喷发与绝命哀嚎
    sub1 = thump(0.65, 125, 22, 5.5, rng, 2.9)
    wall_shatter = modal(0.65, 195, CHITIN_MODES, 6.5, rng, 0.92)
    snap = crack(0.22, 1500, rng, 2.4) * 0.88
    erupt_roar = roar(1.65, 185, 2.2, rng, 2.4) * 0.92
    gore_geyser = squelch(1.35, 240, 1550, rng, 2.5) * 0.9
    hive_wail = voice(1.45, 110, 48, rng, 7.5, 0.42, 2.4) * 0.82
    sub_collapse = thump(0.85, 95, 20, 4.8, rng, 2.8) * 0.9
    after_ooze = squelch(0.75, 210, 780, rng, 1.8) * 0.65
    return reverb_tail(sat(mix(
        place(sub1, 0.0),
        place(wall_shatter, 0.01),
        place(snap, 0.015),
        place(erupt_roar, 0.04),
        place(gore_geyser, 0.06),
        place(hive_wail, 0.12),
        place(sub_collapse, 0.78),
        place(after_ooze, 1.35),
    ), 1.9), 0.32, 0.28)
