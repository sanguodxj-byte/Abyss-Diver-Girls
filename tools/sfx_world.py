# -*- coding: utf-8 -*-
"""搜刮容器、战利品检视、空投舱降落、撤离信标与运输机音效（重工业物理重制版）。"""
import numpy as np
from sfx_dsp import (
    SR, sfx, env_exp, env_adsr, biquad, reson, sweep,
    white, pink, brown, velvet, sat, place, mix, reverb_tail,
)
from sfx_lib import (
    thump, crack, tick, clank, modal, METAL_HEAVY, METAL_HOLLOW, METAL_LIGHT,
    METAL_BELL, GLASS_MODES, CHITIN_MODES, servo, hiss, whoosh, roar, rumble,
    zap, buzz, turbine, squelch,
)


# ─────────────────────────────────────────────────────────────
# 战地容器开启（补给箱 / 工具箱 / 军用武器箱 / 保险箱 / 虫茧 / 虫巢囊）
# ─────────────────────────────────────────────────────────────
@sfx("loot_open", n=2, target=-17.0, dur=0.75, fout=0.08)
def _loot_open(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 通用金属箱：搭扣弹开 + 铰链摩擦 + 箱盖掀开撞击限位器
    latch = clank(0.16, 360 * p, METAL_LIGHT, 20.0, rng, 0.72)
    hinge = servo(0.24, 190 * p, 310 * p, rng, 0.38) * 0.48
    lid_thump = thump(0.24, 105 * p, 34 * p, 14.0, rng, 2.0) * 0.72
    lid_clank = clank(0.26, 235 * p, METAL_HOLLOW, 14.0, rng, 0.75)
    return sat(mix(
        place(latch, 0.0),
        place(hinge, 0.06),
        place(lid_thump, 0.26),
        place(lid_clank, 0.265),
    ), 1.45)


@sfx("loot_open_supply", n=1, target=-16.5, dur=0.95, fout=0.1)
def _loot_open_supply(v, rng):
    # 气密补给箱：双侧气压锁扣弹开 + 负压密封圈泄气嘶鸣 + 厚重箱盖液压撑杆升起
    l1 = clank(0.16, 340, METAL_HEAVY, 18.0, rng, 0.75)
    l2 = clank(0.16, 370, METAL_HEAVY, 18.0, rng, 0.75)
    seal_hiss = hiss(0.45, 1950, 1200, 6.5, rng) * 0.62
    strut = servo(0.38, 150, 275, rng, 0.42) * 0.52
    stop_thump = thump(0.24, 108, 34, 14.0, rng, 2.1) * 0.7
    return sat(mix(
        place(l1, 0.0),
        place(l2, 0.09),
        place(seal_hiss, 0.14),
        place(strut, 0.18),
        place(stop_thump, 0.52),
    ), 1.5)


@sfx("loot_open_tool", n=1, target=-17.0, dur=0.8, fout=0.08)
def _loot_open_tool(v, rng):
    # 机械工具箱：铁皮卡扣清脆弹开 + 折叠托盘连环展开碰撞声
    snap = clank(0.15, 420, METAL_LIGHT, 22.0, rng, 0.75)
    tray1 = clank(0.18, 310, METAL_HOLLOW, 18.0, rng, 0.68) * 0.72
    tray2 = clank(0.20, 260, METAL_HOLLOW, 16.0, rng, 0.7) * 0.75
    tools_rat = clank(0.14, 520, METAL_LIGHT, 24.0, rng, 0.55) * 0.5
    return sat(mix(
        place(snap, 0.0),
        place(tray1, 0.12),
        place(tools_rat, 0.18),
        place(tray2, 0.28),
    ), 1.45)


@sfx("loot_open_military", n=1, target=-16.0, dur=1.1, fout=0.1)
def _loot_open_military(v, rng):
    # 重型军械箱：旋转泄压阀 -> 四角重型卡榫同步脱锁 -> 装甲箱盖沉重掀起
    valve = servo(0.20, 210, 130, rng, 0.42)
    unbolt = clank(0.28, 250, METAL_HEAVY, 13.0, rng, 0.85)
    sub_pop = thump(0.30, 115, 30, 11.0, rng, 2.3)
    gas_strut = hiss(0.48, 1750, 1100, 5.5, rng) * 0.55
    heavy_open = clank(0.32, 195, METAL_HEAVY, 11.0, rng, 0.82) * 0.78
    return sat(mix(
        place(valve, 0.0),
        place(unbolt, 0.18),
        place(sub_pop, 0.185),
        place(gas_strut, 0.24),
        place(heavy_open, 0.58),
    ), 1.6)


@sfx("loot_open_safe", n=1, target=-16.0, dur=1.2, fout=0.12)
def _loot_open_safe(v, rng):
    # 装甲保险箱：密码棘轮飞速拨动 -> 主锁舌沉重退槽 -> 厚钢门缓慢旋开
    dials = np.zeros(int(1.2 * SR))
    for i in range(5):
        t0 = i * 0.045
        tk = tick(0.012, 1450 + i * 70, rng) * 0.7
        dials = mix(dials, place(tk, t0, 1.2))
    bolt_slide = clank(0.28, 230, METAL_HEAVY, 13.0, rng, 0.85)
    bolt_thump = thump(0.28, 108, 30, 12.0, rng, 2.3)
    hinge_creak = modal(0.45, 185, METAL_HEAVY, 7.5, rng, 0.55) * 0.52
    door_stop = thump(0.26, 92, 28, 13.0, rng, 2.1) * 0.72
    return sat(mix(
        dials,
        place(bolt_slide, 0.26),
        place(bolt_thump, 0.265),
        place(hinge_creak, 0.42),
        place(door_stop, 0.78),
    ), 1.55)


@sfx("loot_open_bug", n=1, target=-16.5, dur=0.95, fout=0.1)
def _loot_open_bug(v, rng):
    # 破开虫族甲壳囊：几丁质硬壳脆裂 + 粘稠组织撕开 + 内部气压湿滑喷溅
    chitin_snap = crack(0.09, 1750, rng, 2.0) * 0.82
    shell_res = modal(0.24, 380, CHITIN_MODES, 15.0, rng, 0.65)
    wet_rip = squelch(0.48, 320, 1250, rng, 2.0) * 0.85
    sac_pop = thump(0.24, 105, 34, 14.0, rng, 2.0) * 0.7
    ooze = squelch(0.32, 240, 780, rng, 1.6) * 0.55
    return sat(mix(
        place(chitin_snap, 0.0),
        place(shell_res, 0.005),
        place(sac_pop, 0.06),
        place(wet_rip, 0.07),
        place(ooze, 0.38),
    ), 1.55)


@sfx("loot_open_nest", n=1, target=-15.5, dur=1.15, fout=0.12)
def _loot_open_nest(v, rng):
    # 掘开深渊母巢核心囊：厚甲碎裂闷响 + 深层生物腔体蠕动 + 大量粘液爆浆
    crush_thump = thump(0.38, 115, 28, 9.5, rng, 2.4)
    chitin_break = modal(0.32, 290, CHITIN_MODES, 11.0, rng, 0.78)
    snap = crack(0.12, 1550, rng, 2.2) * 0.85
    burst_wet = squelch(0.65, 260, 1450, rng, 2.2) * 0.9
    cavity_roar = roar(0.55, 180, 5.5, rng, 1.7) * 0.55
    drip = squelch(0.35, 210, 680, rng, 1.5) * 0.5
    return reverb_tail(sat(mix(
        place(crush_thump, 0.0),
        place(chitin_break, 0.006),
        place(snap, 0.01),
        place(burst_wet, 0.12),
        place(cavity_roar, 0.15),
        place(drip, 0.52),
    ), 1.65), 0.18, 0.18)


# ─────────────────────────────────────────────────────────────
# 战利品检视 / 拾取 / 放置 / 货舱满载
# ─────────────────────────────────────────────────────────────
@sfx("loot_reveal", n=3, target=-19.0, dur=0.38, fout=0.04)
def _loot_reveal(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    # 扫描检视出常规物资：战术扫描仪快门咔哒 + 金属部件落位轻响
    shutter = tick(0.014, 1550 * p, rng) * 0.75
    cl = clank(0.16, 360 * p, METAL_LIGHT, 22.0, rng, 0.62)
    th = thump(0.14, 98 * p, 38 * p, 22.0, rng, 1.6) * 0.58
    return sat(mix(place(shutter, 0.0), place(cl, 0.025), place(th, 0.028)), 1.35)


@sfx("loot_reveal_rare", n=1, target=-16.5, dur=1.0, fout=0.12)
def _loot_reveal_rare(v, rng):
    # 检视出高价值稀有遗物：重型气压锁弹开 + 高密度合金/晶体双模态清冽共鸣（非电子音阶）
    lock = clank(0.22, 290, METAL_HEAVY, 16.0, rng, 0.78)
    sub = thump(0.28, 112, 32, 12.0, rng, 2.2)
    bell_low = modal(0.58, 360, METAL_BELL, 6.5, rng, 0.58) * 0.55
    crystal_hi = modal(0.68, 540, GLASS_MODES, 5.5, rng, 0.62) * 0.58
    air_shimmer = hiss(0.38, 2200, 1400, 8.0, rng) * 0.32
    return reverb_tail(sat(mix(
        place(lock, 0.0),
        place(sub, 0.005),
        place(bell_low, 0.04),
        place(air_shimmer, 0.08),
        place(crystal_hi, 0.16),
    ), 1.55), 0.22, 0.2)


@sfx("loot_take", n=2, target=-18.0, dur=0.45, fout=0.05)
def _loot_take(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 抓取物资收入囊中：机械爪收拢 + 物资扣入挂架锁死
    grab = servo(0.12, 180 * p, 310 * p, rng, 0.4) * 0.5
    latch = clank(0.18, 320 * p, METAL_HEAVY, 18.0, rng, 0.72)
    th = thump(0.16, 105 * p, 36 * p, 18.0, rng, 1.9) * 0.68
    return sat(mix(place(grab, 0.0), place(latch, 0.085), place(th, 0.088)), 1.45)


@sfx("loot_put", n=1, target=-18.5, dur=0.42, fout=0.05)
def _loot_put(v, rng):
    # 放下物资：松开卡扣 + 沉稳落槽闷响
    rel = tick(0.014, 1350, rng) * 0.65
    drop_th = thump(0.18, 95, 34, 18.0, rng, 1.9) * 0.72
    drop_cl = clank(0.18, 250, METAL_HOLLOW, 18.0, rng, 0.68)
    return sat(mix(place(rel, 0.0), place(drop_th, 0.045), place(drop_cl, 0.048)), 1.4)


@sfx("loot_close", n=1, target=-18.0, dur=0.5, fout=0.05)
def _loot_close(v, rng):
    # 关闭容器：箱盖合拢砸下 + 锁扣咬合
    swing = whoosh(0.16, 620, 240, rng, 1.8) * 0.45
    shut_th = thump(0.22, 102, 32, 15.0, rng, 2.1) * 0.75
    shut_cl = clank(0.22, 240, METAL_HEAVY, 15.0, rng, 0.78)
    latch = clank(0.12, 380, METAL_LIGHT, 24.0, rng, 0.65) * 0.6
    return sat(mix(
        place(swing, 0.0),
        place(shut_th, 0.10),
        place(shut_cl, 0.104),
        place(latch, 0.18),
    ), 1.45)


@sfx("cargo_full", n=1, target=-16.5, dur=0.75, fout=0.08)
def _cargo_full(v, rng):
    # 货舱满载：液压悬挂承重下沉闷响 + 限位器双连死锁撞击
    susp_groan = modal(0.38, 145, METAL_HEAVY, 8.0, rng, 0.65) * 0.65
    c1 = clank(0.18, 280, METAL_HEAVY, 18.0, rng, 0.8)
    t1 = thump(0.18, 105, 34, 16.0, rng, 2.1) * 0.75
    c2 = clank(0.22, 230, METAL_HEAVY, 15.0, rng, 0.85)
    t2 = thump(0.22, 88, 30, 14.0, rng, 2.2) * 0.8
    return sat(mix(
        place(susp_groan, 0.0),
        place(c1, 0.05),
        place(t1, 0.054),
        place(c2, 0.22),
        place(t2, 0.224),
    ), 1.55)


@sfx("cargo_overload", n=1, target=-15.0, dur=1.2, fout=0.15)
def _cargo_overload(v, rng):
    # 货舱严重超载：机甲底盘钢梁受压金属呻吟 + 液压过压阀喷气 + 沉重警告撞针
    strain = modal(0.65, 130, METAL_HEAVY, 5.5, rng, 0.78) * 0.72
    th_heavy = thump(0.42, 110, 26, 8.5, rng, 2.5)
    valve_pop = clank(0.26, 260, METAL_HEAVY, 13.0, rng, 0.85)
    steam = hiss(0.55, 1850, 1200, 5.0, rng) * 0.58
    kn = clank(0.24, 340, METAL_HEAVY, 14.0, rng, 0.8) * 0.75
    return reverb_tail(sat(mix(
        place(strain, 0.0),
        place(th_heavy, 0.04),
        place(valve_pop, 0.18),
        place(steam, 0.22),
        place(kn, 0.48),
    ), 1.65), 0.18, 0.18)


# ─────────────────────────────────────────────────────────────
# 轨道空投舱（Hellpod式音爆穿云 / 反推火箭点火 / 砸穿地表）
# ─────────────────────────────────────────────────────────────
@sfx("drop_fall", n=1, target=-15.0, dur=2.2, fout=0.2)
def _drop_fall(v, rng):
    # 空投舱超音速再入大气层：高空音爆 + 剧烈气动加热呼啸 + 舱体隔热瓦震颤
    sonic_boom = thump(0.45, 125, 28, 8.0, rng, 2.6)
    reentry_whoosh = whoosh(1.95, 220, 1550, rng, 2.8) * 0.88
    plasma_roar = roar(1.85, 240, 2.2, rng, 2.0) * 0.78
    hull_vib = turbine(1.80, 95, 185, rng, 5, 0.1) * 0.52
    return reverb_tail(sat(mix(
        place(sonic_boom, 0.0),
        place(reentry_whoosh, 0.04),
        place(plasma_roar, 0.08),
        place(hull_vib, 0.12),
    ), 1.7), 0.22, 0.2)


@sfx("drop_retro", n=1, target=-14.0, dur=1.4, fout=0.15)
def _drop_retro(v, rng):
    # 近地反推火箭齐射制动：爆炸螺栓抛出防热盾 + 固体反推火箭狂暴喷射
    shield_jettison = clank(0.26, 280, METAL_HEAVY, 14.0, rng, 0.85)
    ignite_boom = thump(0.45, 135, 28, 8.0, rng, 2.7)
    retro_roar = roar(1.05, 290, 3.2, rng, 2.3) * 0.9
    jet_shear = whoosh(0.95, 1600, 380, rng, 2.6) * 0.82
    nozzle_hiss = hiss(0.85, 2200, 1400, 4.0, rng) * 0.55
    return reverb_tail(sat(mix(
        place(shield_jettison, 0.0),
        place(ignite_boom, 0.06),
        place(retro_roar, 0.07),
        place(jet_shear, 0.08),
        place(nozzle_hiss, 0.12),
    ), 1.75), 0.2, 0.2)


@sfx("drop_impact", n=1, target=-12.5, dur=2.2, fout=0.35)
def _drop_impact(v, rng):
    # 空投舱砸穿地表并弹开舱门：毁天灭地撞击低频 + 装甲楔入岩层 + 爆炸螺栓炸开舱门
    earth_shatter = thump(0.95, 140, 20, 4.2, rng, 3.1)
    impact_roar = roar(1.25, 195, 2.8, rng, 2.5) * 0.92
    hull_slam = clank(0.75, 165, METAL_HEAVY, 6.0, rng, 0.95) * 0.88
    rock_crack = crack(0.32, 1450, rng, 2.2) * 0.72
    # 0.75s 后爆炸螺栓炸开舱门，液压踏板砸地
    bolt_pop = thump(0.35, 125, 32, 11.0, rng, 2.4) * 0.8
    door_clang = clank(0.42, 240, METAL_HEAVY, 9.5, rng, 0.88) * 0.82
    steam_vent = hiss(0.85, 1950, 1300, 3.5, rng) * 0.55
    return reverb_tail(sat(mix(
        place(earth_shatter, 0.0),
        place(impact_roar, 0.01),
        place(hull_slam, 0.015),
        place(rock_crack, 0.025),
        place(bolt_pop, 0.72),
        place(door_clang, 0.73),
        place(steam_vent, 0.76),
    ), 1.9), 0.3, 0.28)


# ─────────────────────────────────────────────────────────────
# 撤离信标与重型运输机（Pelican式重型倾转旋翼/喷气运输机）
# ─────────────────────────────────────────────────────────────
@sfx("extract_start", n=1, target=-15.5, dur=1.6, fout=0.2)
def _extract_start(v, rng):
    # 启动撤离终端：拉下重型机械闸刀 -> 天线塔液压升起 -> 向轨道发射大功率电磁脉冲
    lever = clank(0.28, 235, METAL_HEAVY, 13.0, rng, 0.85)
    lever_th = thump(0.26, 110, 32, 13.0, rng, 2.2)
    mast_srv = servo(0.55, 140, 290, rng, 0.48)
    mast_lock = clank(0.24, 330, METAL_LIGHT, 16.0, rng, 0.72)
    pulse_boom = thump(0.45, 125, 28, 8.0, rng, 2.4)
    pulse_zap = zap(0.42, 2200, rng, 40) * 0.58
    return reverb_tail(sat(mix(
        place(lever, 0.0),
        place(lever_th, 0.005),
        place(mast_srv, 0.18),
        place(mast_lock, 0.72),
        place(pulse_boom, 0.78),
        place(pulse_zap, 0.79),
    ), 1.6), 0.22, 0.2)


@sfx("extract_cancel", n=1, target=-16.5, dur=1.2, fout=0.15)
def _extract_cancel(v, rng):
    # 撤离中断：断路器跳闸 + 天线塔泄压收回 + 涡轮停转
    trip = clank(0.26, 220, METAL_HEAVY, 13.0, rng, 0.82)
    th = thump(0.28, 105, 30, 11.0, rng, 2.2)
    spool_down = turbine(0.75, 240, 75, rng, 5, 0.09) * 0.58
    vent = hiss(0.55, 1650, 1100, 5.5, rng) * 0.48
    return sat(mix(
        place(trip, 0.0),
        place(th, 0.006),
        place(spool_down, 0.08),
        place(vent, 0.12),
    ), 1.5)


@sfx("extract_success", n=1, target=-14.5, dur=2.6, fout=0.4)
def _extract_success(v, rng):
    # 登机撤离成功：尾舱跳板液压升起闭合 -> 气密锁死 -> 主引擎全功率加力轰鸣升空
    ramp_srv = servo(0.65, 135, 260, rng, 0.5)
    ramp_slam = thump(0.45, 120, 26, 8.5, rng, 2.6)
    ramp_lock = clank(0.42, 210, METAL_HEAVY, 10.0, rng, 0.88)
    seal_hiss = hiss(0.45, 1900, 1200, 6.0, rng) * 0.52
    afterburner = roar(1.45, 230, 2.2, rng, 2.2) * 0.88
    turb_up = turbine(1.40, 110, 320, rng, 6, 0.11) * 0.72
    return reverb_tail(sat(mix(
        place(ramp_srv, 0.0),
        place(ramp_slam, 0.62),
        place(ramp_lock, 0.63),
        place(seal_hiss, 0.68),
        place(afterburner, 0.85),
        place(turb_up, 0.88),
    ), 1.75), 0.28, 0.25)


@sfx("transport_arrive", n=1, target=-14.0, dur=3.0, fout=0.35)
def _transport_arrive(v, rng):
    # 运输机进场着陆：高空涡扇呼啸逼近 -> 反推喷口咆哮 -> 起落架重砸地面与尾舱门弹开
    approach = whoosh(1.6, 180, 950, rng, 2.4) * 0.78
    turb = turbine(2.2, 260, 135, rng, 6, 0.1) * 0.72
    jet_roar = roar(1.8, 220, 2.4, rng, 2.1) * 0.82
    touchdown_sub = thump(0.55, 120, 24, 7.0, rng, 2.7)
    gear_clank = clank(0.45, 195, METAL_HEAVY, 9.5, rng, 0.88)
    brake_hiss = hiss(0.75, 1850, 1200, 4.0, rng) * 0.58
    ramp_drop = clank(0.35, 250, METAL_HEAVY, 11.0, rng, 0.8) * 0.75
    return reverb_tail(sat(mix(
        place(approach, 0.0),
        place(turb, 0.05),
        place(jet_roar, 0.25),
        place(touchdown_sub, 1.55),
        place(gear_clank, 1.56),
        place(brake_hiss, 1.62),
        place(ramp_drop, 2.15),
    ), 1.75), 0.28, 0.25)


@sfx("transport_idle_loop", n=1, target=-18.5, loop=4.0, reps=4)
def _transport_idle(v, rng):
    dur = 4.0
    # 运输机地面怠速循环：双发重型涡扇发动机低频轰鸣 + 尾喷口热浪湍流 + 机身蒙皮偶发微震
    low_rumble = rumble(dur, 65, 5.5, rng, 1.7) * 0.68
    turb = turbine(dur, 128, 128, rng, 6, 0.07) * 0.62
    exhaust = sweep(pink(dur, rng), "bp", 420, 480, 1.6) * 0.45
    rattles = np.zeros(int(dur * SR))
    for i in range(4):
        t0 = i * 1.0 + 0.25
        cl = clank(0.14, 240, METAL_HOLLOW, 22.0, rng, 0.45) * 0.28
        rattles = mix(rattles, place(cl, t0, dur))
    return sat(mix(low_rumble, turb, exhaust, rattles), 1.35)


@sfx("transport_depart", n=1, target=-14.0, dur=2.8, fout=0.4)
def _transport_depart(v, rng):
    # 运输机满载爬升撤离：矢量喷口加力爆燃 -> 狂暴下洗气流席卷地面 -> 呼啸远去
    ignite = thump(0.55, 130, 26, 6.5, rng, 2.7)
    roar_main = roar(2.2, 240, 1.8, rng, 2.3) * 0.9
    turb_climb = turbine(2.3, 125, 340, rng, 6, 0.11) * 0.75
    flyby = whoosh(2.2, 320, 1650, rng, 2.6) * 0.85
    gear_retract = clank(0.32, 280, METAL_HEAVY, 12.0, rng, 0.78) * 0.68
    return reverb_tail(sat(mix(
        place(ignite, 0.0),
        place(roar_main, 0.04),
        place(turb_climb, 0.06),
        place(flyby, 0.12),
        place(gear_retract, 0.95),
    ), 1.8), 0.32, 0.28)
