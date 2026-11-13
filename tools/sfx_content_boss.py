# -*- coding: utf-8 -*-
"""三大巨型领主 Boss（育母虫后 broodmother / 铠甲虫王 king_beetle / 深渊女皇 abyss_queen）
专属技能咆哮与本体受击/攻击/死亡音效（超低频生物胸腔谐振+地壳崩裂重制版）。"""
import numpy as np
from sfx_dsp import (
    SR, sfx, env_exp, env_adsr, biquad, reson, sweep,
    white, pink, brown, velvet, sat, place, mix, reverb_tail,
)
from sfx_lib import (
    thump, crack, tick, clank, modal, METAL_HEAVY, METAL_HOLLOW,
    GLASS_MODES, CHITIN_MODES, hiss, whoosh, roar, rumble,
    zap, buzz, squelch, voice,
)


# ─────────────────────────────────────────────────────────────
# 领主专属大招与转阶段（boss_*）
# ─────────────────────────────────────────────────────────────
@sfx("boss_brood_roar", n=2, target=-13.0, dur=2.4, fout=0.35)
def _brood_roar(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 育母虫后震天咆哮：深渊巨型胸腔双声带次声波共鸣 + 粘稠气道喷发 + 洞窟混响
    sub_tremor = thump(0.75, 115 * p, 20 * p, 4.5, rng, 2.8)
    chest_roar = roar(2.0, 165 * p, 1.8, rng, 2.4) * 0.9
    vox_low = voice(1.9, 58 * p, 95 * p, rng, 6.5, 0.42, 2.5) * 0.92
    vox_mid = voice(1.8, 112 * p, 68 * p, rng, 8.5, 0.38, 2.3) * 0.78
    phlegm = squelch(1.2, 220 * p, 1150 * p, rng, 2.1) * 0.65
    return reverb_tail(sat(mix(
        place(sub_tremor, 0.0),
        place(chest_roar, 0.03),
        place(vox_low, 0.05),
        place(vox_mid, 0.08),
        place(phlegm, 0.15),
    ), 1.9), 0.35, 0.3)


@sfx("boss_brood_hatch", n=2, target=-14.0, dur=1.6, fout=0.2)
def _brood_hatch(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 虫后产卵孵化：巨大育儿囊连环爆裂 + 羊水粘液狂喷 + 幼虫嘶鸣
    sac1 = thump(0.42, 112 * p, 26 * p, 8.5, rng, 2.5)
    rip1 = squelch(0.75, 240 * p, 1480 * p, rng, 2.4) * 0.92
    sac2 = thump(0.38, 98 * p, 24 * p, 9.0, rng, 2.4) * 0.85
    rip2 = squelch(0.65, 280 * p, 1550 * p, rng, 2.4) * 0.88
    mother_groan = voice(1.1, 68 * p, 108 * p, rng, 7.5, 0.4, 2.2) * 0.78
    return reverb_tail(sat(mix(
        place(sac1, 0.0),
        place(rip1, 0.02),
        place(mother_groan, 0.08),
        place(sac2, 0.42),
        place(rip2, 0.44),
    ), 1.75), 0.25, 0.22)


@sfx("boss_king_roar", n=2, target=-12.5, dur=2.5, fout=0.35)
def _king_roar(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 铠甲虫王咆哮：重型几丁质胸甲共鸣撞击 + 50Hz超低频威压吼叫 + 狂暴气浪
    plate_slam = modal(0.55, 165 * p, CHITIN_MODES, 7.0, rng, 0.92)
    sub_boom = thump(0.85, 125 * p, 20 * p, 4.2, rng, 3.0)
    bellow_sub = voice(2.1, 52 * p, 88 * p, rng, 5.8, 0.45, 2.6) * 0.95
    roar_body = roar(2.1, 175 * p, 1.7, rng, 2.5) * 0.92
    air_blast = whoosh(1.6, 220 * p, 1250 * p, rng, 2.4) * 0.72
    return reverb_tail(sat(mix(
        place(sub_boom, 0.0),
        place(plate_slam, 0.01),
        place(roar_body, 0.03),
        place(bellow_sub, 0.05),
        place(air_blast, 0.10),
    ), 1.95), 0.36, 0.3)


@sfx("boss_king_stomp", n=2, target=-12.0, dur=1.6, fout=0.25)
def _king_stomp(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 虫王崩山践踏：百吨重足砸裂地壳 + 岩石崩碎 + 次声波震荡
    quake1 = thump(0.85, 138 * p, 18 * p, 4.2, rng, 3.2)
    quake2 = thump(0.65, 95 * p, 18 * p, 5.5, rng, 2.8) * 0.85
    erupt = roar(1.15, 185 * p, 3.0, rng, 2.6) * 0.95
    carapace = modal(0.55, 175 * p, CHITIN_MODES, 7.5, rng, 0.92)
    rock_snap = crack(0.32, 1450 * p, rng, 2.4) * 0.82
    return reverb_tail(sat(mix(
        place(quake1, 0.0),
        place(erupt, 0.008),
        place(carapace, 0.012),
        place(rock_snap, 0.02),
        place(quake2, 0.28),
    ), 1.95), 0.32, 0.28)


@sfx("boss_king_core", n=1, target=-13.5, dur=1.8, fout=0.25)
def _king_core(v, rng):
    # 虫王熔核暴露过载：背部甲壳向两侧沉重裂开 + 核心生物电浆狂暴喷涌
    shell_split = modal(0.48, 185, CHITIN_MODES, 8.0, rng, 0.9)
    sub_pop = thump(0.55, 125, 24, 6.5, rng, 2.7)
    plasma_arc = zap(0.95, 2250, rng, 52) * 0.78
    core_roar = roar(1.45, 210, 2.4, rng, 2.3) * 0.88
    steam = hiss(1.25, 2100, 1400, 3.2, rng) * 0.62
    return reverb_tail(sat(mix(
        place(shell_split, 0.0),
        place(sub_pop, 0.02),
        place(core_roar, 0.08),
        place(plasma_arc, 0.12),
        place(steam, 0.18),
    ), 1.85), 0.28, 0.25)


@sfx("boss_queen_roar", n=2, target=-12.5, dur=2.6, fout=0.35)
def _queen_roar(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 深渊女皇君临咆哮：双重胸腔/咽腔声带共振（低频威压+中频凄厉生物共鸣，绝不用方波）+ 灵能风暴
    sub_boom = thump(0.85, 128 * p, 20 * p, 4.2, rng, 3.0)
    abyss_roar = roar(2.2, 180 * p, 1.6, rng, 2.5) * 0.92
    vox_sub = voice(2.2, 56 * p, 98 * p, rng, 6.0, 0.42, 2.5) * 0.92
    vox_harmonic = voice(2.1, 145 * p, 225 * p, rng, 9.5, 0.35, 2.3) * 0.82
    cryst_res = modal(1.4, 480 * p, GLASS_MODES, 4.5, rng, 0.65) * 0.55
    return reverb_tail(sat(mix(
        place(sub_boom, 0.0),
        place(abyss_roar, 0.02),
        place(vox_sub, 0.04),
        place(vox_harmonic, 0.06),
        place(cryst_res, 0.12),
    ), 1.95), 0.38, 0.32)


@sfx("boss_queen_wail", n=2, target=-13.5, dur=2.2, fout=0.3)
def _queen_wail(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 女皇深渊悲鸣冲击：剧烈气道抽吸 -> 凄厉咽腔共振长啸 + 精神震波低频脉动
    inhale = whoosh(0.35, 950 * p, 260 * p, rng, 2.2) * 0.78
    pulse_sub = thump(0.65, 118 * p, 22 * p, 5.5, rng, 2.7)
    wail_vox = voice(1.75, 185 * p, 82 * p, rng, 11.0, 0.38, 2.4) * 0.9
    wail_low = voice(1.75, 92 * p, 48 * p, rng, 6.5, 0.42, 2.4) * 0.85
    glass_shimmer = modal(1.3, 520 * p, GLASS_MODES, 5.0, rng, 0.62) * 0.58
    return reverb_tail(sat(mix(
        place(inhale, 0.0),
        place(pulse_sub, 0.22),
        place(wail_vox, 0.24),
        place(wail_low, 0.25),
        place(glass_shimmer, 0.28),
    ), 1.85), 0.35, 0.3)


@sfx("boss_queen_core", n=1, target=-13.0, dur=2.0, fout=0.3)
def _queen_core(v, rng):
    # 女皇深渊核心解放：地壳震动 + 生物电弧风暴 + 晶态几丁质共鸣爆裂
    sub = thump(0.75, 132, 20, 4.8, rng, 2.9)
    roar_b = roar(1.65, 195, 2.0, rng, 2.4) * 0.9
    arc_storm = zap(1.25, 2350, rng, 55) * 0.78
    cryst = modal(1.2, 460, GLASS_MODES, 5.0, rng, 0.75) * 0.68
    vox = voice(1.4, 78, 145, rng, 8.5, 0.4, 2.3) * 0.8
    return reverb_tail(sat(mix(
        place(sub, 0.0),
        place(roar_b, 0.02),
        place(arc_storm, 0.05),
        place(cryst, 0.08),
        place(vox, 0.12),
    ), 1.9), 0.32, 0.28)


@sfx("boss_phase_shift", n=2, target=-12.5, dur=2.2, fout=0.3)
def _phase_shift(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 领主狂暴转阶段：旧甲壳爆裂褪去 + 毁天灭地冲击波 + 狂暴觉醒咆哮
    shatter_sub = thump(0.85, 138 * p, 20 * p, 4.5, rng, 3.1)
    molt_crack = crack(0.28, 1650 * p, rng, 2.5) * 0.9
    carapace = modal(0.65, 185 * p, CHITIN_MODES, 6.5, rng, 0.92)
    shock_roar = roar(1.85, 190 * p, 1.9, rng, 2.5) * 0.92
    awaken_vox = voice(1.75, 62 * p, 125 * p, rng, 7.5, 0.42, 2.5) * 0.9
    shock_air = whoosh(1.45, 240 * p, 1450 * p, rng, 2.6) * 0.78
    return reverb_tail(sat(mix(
        place(shatter_sub, 0.0),
        place(molt_crack, 0.008),
        place(carapace, 0.015),
        place(shock_roar, 0.03),
        place(awaken_vox, 0.08),
        place(shock_air, 0.12),
    ), 1.95), 0.35, 0.3)


# ─────────────────────────────────────────────────────────────
# 三大 Boss 标准虫族动作集（appear / windup / attack / hurt / death）
# ─────────────────────────────────────────────────────────────
def _make_boss_unit_sfx(kind, f_vox_lo, f_vox_hi, f_chitin, has_crystal=False):
    @sfx(f"bug_{kind}_appear", n=2, target=-13.5, dur=1.4, fout=0.18)
    def _appear(v, rng):
        p = 1.0 + (v - 0.5) * 0.05
        stomp1 = thump(0.48, 120 * p, 22 * p, 7.0, rng, 2.7)
        stomp2 = thump(0.55, 110 * p, 20 * p, 6.5, rng, 2.8)
        plate = modal(0.45, f_chitin * p, CHITIN_MODES, 8.0, rng, 0.88)
        bellow = voice(1.05, f_vox_lo * p, f_vox_hi * p, rng, 7.0, 0.42, 2.4) * 0.9
        roar_b = roar(0.95, 175 * p, 3.0, rng, 2.2) * 0.82
        sig = mix(
            place(stomp1, 0.0),
            place(plate, 0.01),
            place(bellow, 0.12),
            place(roar_b, 0.15),
            place(stomp2, 0.38),
        )
        if has_crystal:
            sig = mix(sig, place(modal(0.65, 460 * p, GLASS_MODES, 6.5, rng, 0.65) * 0.55, 0.16))
        return reverb_tail(sat(sig, 1.85), 0.26, 0.24)

    @sfx(f"bug_{kind}_windup", n=2, target=-14.0, dur=1.0, fout=0.12)
    def _windup(v, rng):
        p = 1.0 + (v - 0.5) * 0.05
        brace = thump(0.42, 108 * p, 24 * p, 8.5, rng, 2.5)
        creak = modal(0.48, f_chitin * p, CHITIN_MODES, 7.5, rng, 0.85)
        snort = hiss(0.55, 1450 * p, 950, 5.0, rng) * 0.65
        growl = voice(0.75, f_vox_lo * p, f_vox_hi * 1.15 * p, rng, 8.0, 0.4, 2.3) * 0.88
        return reverb_tail(sat(mix(
            place(brace, 0.0),
            place(creak, 0.03),
            place(growl, 0.06),
            place(snort, 0.12),
        ), 1.75), 0.2, 0.18)

    @sfx(f"bug_{kind}_attack", n=2, target=-12.5, dur=1.2, fout=0.16)
    def _attack(v, rng):
        p = 1.0 + (v - 0.5) * 0.05
        rush = whoosh(0.32, 180 * p, 920 * p, rng, 2.4) * 0.82
        slam_sub = thump(0.65, 132 * p, 20 * p, 5.5, rng, 3.0)
        erupt = roar(0.85, 190 * p, 3.5, rng, 2.5) * 0.9
        plate = modal(0.48, f_chitin * p, CHITIN_MODES, 7.5, rng, 0.92)
        crk = crack(0.18, 1550 * p, rng, 2.4) * 0.88
        atk_vox = voice(0.72, f_vox_hi * p, f_vox_lo * p, rng, 8.5, 0.42, 2.4) * 0.88
        sig = mix(
            place(rush, 0.0),
            place(slam_sub, 0.12),
            place(erupt, 0.125),
            place(plate, 0.13),
            place(crk, 0.135),
            place(atk_vox, 0.15),
        )
        if has_crystal:
            sig = mix(sig, place(zap(0.45, 2250 * p, rng, 42) * 0.62, 0.14))
        return reverb_tail(sat(sig, 1.9), 0.26, 0.24)

    @sfx(f"bug_{kind}_hurt", n=2, target=-14.0, dur=0.85, fout=0.1)
    def _hurt(v, rng):
        p = 1.0 + (v - 0.5) * 0.05
        th = thump(0.42, 118 * p, 24 * p, 9.0, rng, 2.6)
        shell = modal(0.38, f_chitin * p, CHITIN_MODES, 9.0, rng, 0.88)
        crk = crack(0.12, 1650 * p, rng, 2.2) * 0.82
        gore = squelch(0.42, 250 * p, 1320 * p, rng, 2.2) * 0.82
        roar_hurt = voice(0.58, f_vox_hi * p, f_vox_lo * 0.85 * p, rng, 8.0, 0.42, 2.3) * 0.85
        return sat(mix(
            place(th, 0.0),
            place(shell, 0.006),
            place(crk, 0.01),
            place(gore, 0.025),
            place(roar_hurt, 0.04),
        ), 1.75)

    @sfx(f"bug_{kind}_death", n=2, target=-12.0, dur=2.6, fout=0.35)
    def _death(v, rng):
        p = 1.0 + (v - 0.5) * 0.05
        # 领主级巨兽轰然倒塌：连环内爆 + 背甲彻底崩解 + 绝命深渊哀嚎 + 山崩地裂倒地巨震
        sub1 = thump(0.75, 130 * p, 20 * p, 5.0, rng, 3.0)
        shatter = modal(0.68, f_chitin * p, CHITIN_MODES, 6.0, rng, 0.95)
        snap = crack(0.24, 1550 * p, rng, 2.5) * 0.9
        gore_burst = squelch(1.25, 230 * p, 1580 * p, rng, 2.6) * 0.92
        death_bellow = voice(1.65, f_vox_hi * p, 42 * p, rng, 7.0, 0.45, 2.6) * 0.92
        roar_tail = roar(1.85, 180 * p, 2.0, rng, 2.5) * 0.9
        collapse_quake = thump(0.95, 105 * p, 18 * p, 4.2, rng, 3.1) * 0.95
        return reverb_tail(sat(mix(
            place(sub1, 0.0),
            place(shatter, 0.01),
            place(snap, 0.015),
            place(gore_burst, 0.04),
            place(roar_tail, 0.06),
            place(death_bellow, 0.08),
            place(collapse_quake, 0.95),
        ), 1.95), 0.36, 0.32)


_make_boss_unit_sfx("broodmother", f_vox_lo=58.0, f_vox_hi=96.0, f_chitin=185.0, has_crystal=False)
_make_boss_unit_sfx("king_beetle", f_vox_lo=52.0, f_vox_hi=88.0, f_chitin=165.0, has_crystal=False)
_make_boss_unit_sfx("abyss_queen", f_vox_lo=64.0, f_vox_hi=118.0, f_chitin=205.0, has_crystal=True)
