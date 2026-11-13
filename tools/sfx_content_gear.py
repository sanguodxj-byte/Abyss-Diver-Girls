# -*- coding: utf-8 -*-
"""扩展重武器、战术装备、地图动态事件、沙尘暴/暴雨天气、机师养成与通讯音效（全物理谐振重制版）。"""
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
# 扩展重型武器（电磁轨道炮 / 电弧步枪 / 迫击炮 / 破岩钻头 / 等离子炮 / 浮游炮）
# ─────────────────────────────────────────────────────────────
@sfx("wpn_railgun_charge", n=1, target=-15.5, dur=1.4, fout=0.15)
def _railgun_charge(v, rng):
    # 电磁轨道炮高压电容蓄能：导轨机械闭锁 + 磁流体涡轮升频 + 洛伦兹力金属导轨呻吟
    rail_lock = clank(0.24, 250, METAL_HEAVY, 14.0, rng, 0.82)
    spool = turbine(1.15, 85, 310, rng, 6, 0.11) * env_adsr(1.15, 0.25, 0.2, 0.85, 0.2) * 0.72
    mag_strain = buzz(1.10, 65, 195, rng, 1.9) * env_adsr(1.10, 0.3, 0.2, 0.8, 0.2) * 0.62
    sparks = zap(0.45, 2300, rng, 38) * 0.48
    ready_clank = clank(0.20, 340, METAL_HEAVY, 18.0, rng, 0.78) * 0.75
    return sat(mix(
        place(rail_lock, 0.0),
        place(spool, 0.06),
        place(mag_strain, 0.08),
        place(sparks, 0.68),
        place(ready_clank, 1.08),
    ), 1.6)


@sfx("wpn_railgun_fire", n=3, target=-12.5, dur=0.95, fout=0.15)
def _railgun_fire(v, rng):
    p = 1.0 + (v - 1.0) * 0.05
    # 7马赫高超音速穿甲弹击发：电枢瞬间汽化爆震 + 超强音爆撕裂空气 + 导轨退磁颤音
    sub_kick = thump(0.45, 140 * p, 22 * p, 7.5, rng, 3.0)
    sonic_crack = crack(0.06, 2600 * p, rng, 2.8) * 0.95
    plasma_arc = zap(0.28, 2500 * p, rng, 46) * 0.72
    mach_roar = roar(0.58, 230 * p, 5.5, rng, 2.4) * 0.88
    rail_ring = clank(0.48, 210 * p, METAL_HEAVY, 8.5, rng, 0.9) * 0.82
    vent = hiss(0.45, 2100 * p, 1400, 6.5, rng) * 0.48
    return reverb_tail(sat(mix(
        place(sonic_crack, 0.0),
        place(sub_kick, 0.002),
        place(plasma_arc, 0.005),
        place(mach_roar, 0.008),
        place(rail_ring, 0.015),
        place(vent, 0.14),
    ), 1.9), 0.24, 0.22)


@sfx("wpn_arc_fire", n=3, target=-14.5, dur=0.65, fout=0.08)
def _arc_fire(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    # 高压电弧投射器：空气电离爆鸣（雷击式低频闷响）+ 狂暴电弧鞭挞声
    ion_thump = thump(0.28, 128 * p, 30 * p, 12.0, rng, 2.4)
    whip_crack = crack(0.055, 2400 * p, rng, 2.5) * 0.88
    arc_storm = zap(0.45, 2300 * p, rng, 52) * 0.88
    transformer = buzz(0.38, 82 * p, 64 * p, rng, 2.0) * env_exp(0.38, 8.0) * 0.58
    ozone_hiss = hiss(0.35, 2600 * p, 1600, 9.0, rng) * 0.45
    return reverb_tail(sat(mix(
        place(whip_crack, 0.0),
        place(ion_thump, 0.003),
        place(arc_storm, 0.006),
        place(transformer, 0.012),
        place(ozone_hiss, 0.05),
    ), 1.7), 0.18, 0.18)


@sfx("wpn_mortar_fire", n=2, target=-13.5, dur=0.9, fout=0.12)
def _mortar_fire(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 重型机甲臼炮：粗口径炮管空腔闷嘭（Thumper）+ 炮尾座钣金巨震 + 榴弹破空呼啸
    tube_pop = thump(0.45, 130 * p, 24 * p, 7.5, rng, 2.8)
    hollow_tube = modal(0.38, 155 * p, METAL_HOLLOW, 9.0, rng, 0.88)
    breech_clank = clank(0.32, 230 * p, METAL_HEAVY, 11.0, rng, 0.82)
    blast = roar(0.48, 195 * p, 6.5, rng, 2.1) * 0.82
    shell_whoosh = whoosh(0.55, 260 * p, 1150 * p, rng, 2.2) * 0.68
    return reverb_tail(sat(mix(
        place(tube_pop, 0.0),
        place(hollow_tube, 0.004),
        place(breech_clank, 0.008),
        place(blast, 0.012),
        place(shell_whoosh, 0.06),
    ), 1.8), 0.22, 0.2)


@sfx("wpn_drill_ignite", n=1, target=-15.5, dur=0.95, fout=0.1)
def _drill_ignite(v, rng):
    # 攻城破岩钻头启动：离合器重型啮合 + 液压马达扭矩爆发 + 合金钻头高速旋转擦出火花
    clutch = clank(0.26, 220, METAL_HEAVY, 13.0, rng, 0.85)
    kick = thump(0.30, 115, 30, 11.0, rng, 2.3)
    motor_up = turbine(0.75, 78, 225, rng, 6, 0.11) * 0.75
    grind = roar(0.68, 280, 3.8, rng, 2.0) * 0.68
    sparks = crack(0.18, 2100, rng, 2.0) * 0.55
    return sat(mix(
        place(clutch, 0.0),
        place(kick, 0.01),
        place(motor_up, 0.08),
        place(grind, 0.12),
        place(sparks, 0.22),
    ), 1.65)


@sfx("wpn_drill_loop", n=1, target=-17.5, loop=1.5, reps=4)
def _drill_loop(v, rng):
    dur = 1.5
    # 破岩钻头持续钻探循环：粗犷液压马达轰鸣 + 碳化钨齿持续切削岩石甲壳的金属刮擦声
    motor = rumble(dur, 72, 6.0, rng, 1.8) * 0.68
    turb = turbine(dur, 145, 145, rng, 6, 0.09) * 0.62
    grind_band = sweep(pink(dur, rng), "bp", 680, 920, 2.2) * 0.55
    teeth = np.zeros(int(dur * SR))
    for i in range(12):
        t0 = i * (dur / 12.0)
        cl = clank(0.08, 310 + (i % 3) * 40, METAL_HEAVY, 32.0, rng, 0.5) * 0.42
        cr = crack(0.05, 1850, rng, 1.7) * 0.35
        teeth = mix(teeth, place(cl, t0, dur), place(cr, t0 + 0.01, dur))
    return sat(mix(motor, turb, grind_band, teeth), 1.45)


@sfx("wpn_plasma_fire", n=2, target=-14.0, dur=0.75, fout=0.1)
def _plasma_fire(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 重型等离子团喷射：磁约束腔室泄压爆震 + 高温电离气团呼啸 + 散热阀排障
    chamber_thump = thump(0.36, 128 * p, 26 * p, 9.5, rng, 2.6)
    mag_snap = zap(0.26, 2200 * p, rng, 40) * 0.68
    plasma_whoosh = whoosh(0.48, 320 * p, 1450 * p, rng, 2.5) * 0.82
    plasma_roar = roar(0.45, 240 * p, 6.0, rng, 2.1) * 0.78
    breech = clank(0.24, 280 * p, METAL_HEAVY, 15.0, rng, 0.75) * 0.68
    return reverb_tail(sat(mix(
        place(chamber_thump, 0.0),
        place(mag_snap, 0.005),
        place(breech, 0.01),
        place(plasma_whoosh, 0.015),
        place(plasma_roar, 0.02),
    ), 1.75), 0.18, 0.18)


@sfx("wpn_drone_fire", n=3, target=-16.5, dur=0.35, fout=0.04)
def _drone_fire(v, rng):
    p = 1.0 + (v - 1.0) * 0.06
    # 战术浮游炮速射：紧凑型电磁脉冲栓击发 + 清脆枪机复进声
    snap = crack(0.035, 2200 * p, rng, 2.2) * 0.82
    punch = thump(0.16, 125 * p, 42 * p, 22.0, rng, 2.0) * 0.78
    bolt = clank(0.14, 380 * p, METAL_LIGHT, 24.0, rng, 0.7) * 0.72
    arc = zap(0.12, 2400 * p, rng, 32) * 0.48
    return sat(mix(
        place(snap, 0.0),
        place(punch, 0.002),
        place(arc, 0.005),
        place(bolt, 0.035),
    ), 1.55)


# ─────────────────────────────────────────────────────────────
# 战术装备（无人机释放 / 诱饵弹 / 照明弹 / 能量棒直插 / 震荡网）
# ─────────────────────────────────────────────────────────────
@sfx("drone_deploy", n=1, target=-16.0, dur=1.1, fout=0.12)
def _drone_deploy(v, rng):
    # 背部无人机挂架弹射：挂钩脱锁 + 气压弹射出舱 + 微型涵道涡扇启动悬停
    unlatch = clank(0.20, 290, METAL_HEAVY, 16.0, rng, 0.78)
    eject_pop = thump(0.24, 115, 36, 15.0, rng, 2.1)
    srv_wing = servo(0.25, 190, 360, rng, 0.45)
    rotor_up = turbine(0.72, 130, 295, rng, 5, 0.09) * 0.62
    air = whoosh(0.55, 320, 980, rng, 2.0) * 0.52
    return sat(mix(
        place(unlatch, 0.0),
        place(eject_pop, 0.04),
        place(srv_wing, 0.14),
        place(rotor_up, 0.22),
        place(air, 0.25),
    ), 1.5)


@sfx("decoy_deploy", n=1, target=-16.0, dur=1.1, fout=0.12)
def _decoy_deploy(v, rng):
    # 投掷机械声学诱饵：榴弹筒抛射 -> 落地弹跳锚定 -> 诱饵发生器脉冲启动
    pop = thump(0.22, 118, 38, 16.0, rng, 2.0)
    land_clank = clank(0.24, 270, METAL_HEAVY, 14.0, rng, 0.8)
    spike_th = thump(0.24, 105, 32, 14.0, rng, 2.1) * 0.75
    hum_start = buzz(0.55, 85, 145, rng, 1.8) * 0.55
    zap_p = zap(0.32, 2100, rng, 34) * 0.48
    return sat(mix(
        place(pop, 0.0),
        place(land_clank, 0.28),
        place(spike_th, 0.285),
        place(hum_start, 0.38),
        place(zap_p, 0.42),
    ), 1.5)


@sfx("decoy_off", n=1, target=-17.0, dur=0.75, fout=0.1)
def _decoy_off(v, rng):
    # 诱饵耗尽自毁：电容烧毁啪嗒声 + 涡轮停转 + 残骸泄气
    burn_pop = thump(0.22, 110, 34, 15.0, rng, 2.0)
    arc = zap(0.24, 1950, rng, 32) * 0.55
    cl = clank(0.22, 240, METAL_HOLLOW, 16.0, rng, 0.7)
    spin_dn = turbine(0.48, 220, 70, rng, 5, 0.08) * 0.52
    hiss_out = hiss(0.42, 1650, 1100, 7.0, rng) * 0.42
    return sat(mix(
        place(burn_pop, 0.0),
        place(arc, 0.008),
        place(cl, 0.015),
        place(spin_dn, 0.05),
        place(hiss_out, 0.08),
    ), 1.45)


@sfx("flare_ignite", n=1, target=-15.5, dur=1.4, fout=0.2)
def _flare_ignite(v, rng):
    # 高亮镁光照明弹击发：底火击穿清脆金属声 + 镁粉剧烈嘶嘶爆燃 + 升空呼啸
    striker = clank(0.16, 380, METAL_LIGHT, 20.0, rng, 0.75)
    pop = thump(0.24, 122, 36, 15.0, rng, 2.2)
    mag_burn = hiss(1.15, 2500, 1600, 2.6, rng) * 0.82
    flare_roar = roar(1.05, 320, 3.2, rng, 1.9) * 0.68
    rise_whoosh = whoosh(0.85, 380, 1350, rng, 2.2) * 0.65
    return sat(mix(
        place(striker, 0.0),
        place(pop, 0.025),
        place(mag_burn, 0.04),
        place(flare_roar, 0.05),
        place(rise_whoosh, 0.06),
    ), 1.6)


@sfx("energy_cell_plug", n=1, target=-16.0, dur=0.95, fout=0.1)
def _energy_cell_plug(v, rng):
    # 战术能量电池直插：重型卡口推入锁死 + 高压液冷管路导通嘶鸣
    push_th = thump(0.24, 112, 34, 14.0, rng, 2.1)
    lock_cl = clank(0.24, 265, METAL_HEAVY, 15.0, rng, 0.82)
    twist_srv = servo(0.22, 160, 280, rng, 0.45)
    coolant = hiss(0.48, 1950, 1200, 6.0, rng) * 0.55
    arc = zap(0.22, 2200, rng, 30) * 0.42
    return sat(mix(
        place(push_th, 0.0),
        place(lock_cl, 0.006),
        place(twist_srv, 0.14),
        place(arc, 0.32),
        place(coolant, 0.34),
    ), 1.55)


@sfx("web_pulse", n=2, target=-15.5, dur=0.85, fout=0.1)
def _web_pulse(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 电磁束缚网抛射：网枪气压击发 + 配重块破风展开 + 电击网吸附麻痹电弧
    launch = thump(0.26, 120 * p, 34 * p, 13.0, rng, 2.2)
    canister = clank(0.20, 320 * p, METAL_HOLLOW, 18.0, rng, 0.72)
    spread_whoosh = whoosh(0.42, 420 * p, 1450 * p, rng, 2.4) * 0.75
    taser_arc = zap(0.45, 2350 * p, rng, 44) * 0.68
    return sat(mix(
        place(launch, 0.0),
        place(canister, 0.006),
        place(spread_whoosh, 0.03),
        place(taser_arc, 0.22),
    ), 1.6)


# ─────────────────────────────────────────────────────────────
# 战场动态事件与恶劣天气（空投补给着陆 / 货船坠毁 / 求救信标 / 中继塔 / 沙暴 / 酸雨）
# ─────────────────────────────────────────────────────────────
@sfx("supply_drop_land", n=2, target=-13.5, dur=1.6, fout=0.2)
def _supply_drop_land(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 轨道补给舱砸落地面：反推喷气急停 + 沉重装甲箱体砸地 + 四面舱板液压解锁弹开
    incoming = whoosh(0.38, 1200 * p, 280 * p, rng, 2.4) * 0.75
    slam_sub = thump(0.65, 130 * p, 22 * p, 5.5, rng, 2.9)
    slam_clank = clank(0.55, 185 * p, METAL_HEAVY, 7.5, rng, 0.92)
    dirt_roar = roar(0.75, 195 * p, 4.0, rng, 2.2) * 0.82
    unlatch = clank(0.32, 290 * p, METAL_HEAVY, 12.0, rng, 0.8) * 0.75
    steam = hiss(0.55, 1850 * p, 1200, 5.0, rng) * 0.52
    return reverb_tail(sat(mix(
        place(incoming, 0.0),
        place(slam_sub, 0.26),
        place(slam_clank, 0.265),
        place(dirt_roar, 0.27),
        place(unlatch, 0.82),
        place(steam, 0.85),
    ), 1.8), 0.25, 0.22)


@sfx("cargo_crash", n=1, target=-12.5, dur=2.8, fout=0.35)
def _cargo_crash(v, rng):
    # 运输船远方坠毁巨响：尖啸坠落 -> 地面连环大爆炸 -> 舰体龙骨撕裂扭曲巨响
    scream_down = whoosh(0.85, 1650, 220, rng, 2.8) * 0.85
    crash_sub1 = thump(1.1, 135, 20, 3.8, rng, 3.1)
    crash_roar = roar(1.9, 180, 1.9, rng, 2.6) * 0.95
    hull_crush = clank(1.1, 155, METAL_HEAVY, 4.5, rng, 0.95) * 0.88
    sec_boom = thump(0.85, 115, 22, 4.5, rng, 2.8) * 0.85
    debris = crack(0.45, 1450, rng, 2.4) * 0.72
    return reverb_tail(sat(mix(
        place(scream_down, 0.0),
        place(crash_sub1, 0.62),
        place(crash_roar, 0.63),
        place(hull_crush, 0.65),
        place(debris, 0.68),
        place(sec_boom, 1.28),
    ), 1.95), 0.35, 0.3)


@sfx("distress_beacon", n=1, target=-17.0, dur=1.4, fout=0.18)
def _distress_beacon(v, rng):
    # 战损求救信标：受损继电器火花噼啪 + 机械旋转信标灯塔低沉嗡鸣与金属卡扣声
    spark = zap(0.28, 2100, rng, 35) * 0.52
    rotor = servo(0.85, 145, 195, rng, 0.42) * 0.58
    pulse1 = clank(0.22, 320, METAL_BELL, 12.0, rng, 0.68) * 0.7
    th1 = thump(0.18, 98, 36, 16.0, rng, 1.8) * 0.6
    pulse2 = clank(0.24, 260, METAL_BELL, 11.0, rng, 0.72) * 0.75
    return reverb_tail(sat(mix(
        place(spark, 0.0),
        place(rotor, 0.05),
        place(pulse1, 0.12),
        place(th1, 0.125),
        place(pulse2, 0.52),
    ), 1.45), 0.22, 0.2)


@sfx("relay_unlock", n=1, target=-15.5, dur=1.6, fout=0.2)
def _relay_unlock(v, rng):
    # 激活通讯中继塔：重型机械断路器合闸 + 阵列天线液压展开锁死 + 高压电离连通
    breaker = clank(0.28, 225, METAL_HEAVY, 12.0, rng, 0.85)
    sub = thump(0.32, 115, 30, 11.0, rng, 2.3)
    dish_srv = servo(0.65, 130, 285, rng, 0.48)
    lock_top = clank(0.26, 310, METAL_HEAVY, 14.0, rng, 0.8)
    online_arc = zap(0.38, 2250, rng, 38) * 0.55
    turb = turbine(0.75, 95, 220, rng, 5, 0.09) * 0.55
    return reverb_tail(sat(mix(
        place(breaker, 0.0),
        place(sub, 0.005),
        place(dish_srv, 0.15),
        place(turb, 0.25),
        place(lock_top, 0.78),
        place(online_arc, 0.82),
    ), 1.6), 0.2, 0.2)


@sfx("archive_pickup", n=1, target=-17.5, dur=0.75, fout=0.08)
def _archive_pickup(v, rng):
    # 回收黑匣子数据盘：拔出装甲存储卡带 + 磁带仓机械退弹锁合
    unplug = clank(0.18, 340, METAL_LIGHT, 18.0, rng, 0.72)
    slide = servo(0.22, 210, 145, rng, 0.38) * 0.48
    slot_in = clank(0.20, 275, METAL_HEAVY, 16.0, rng, 0.75)
    th = thump(0.18, 102, 36, 18.0, rng, 1.9) * 0.65
    return sat(mix(
        place(unplug, 0.0),
        place(slide, 0.08),
        place(slot_in, 0.32),
        place(th, 0.325),
    ), 1.45)


@sfx("sandstorm_start", n=1, target=-15.5, dur=2.5, fout=0.35)
def _sandstorm_start(v, rng):
    # 强沙尘暴席卷而至：远方低频气压骤降轰鸣 + 狂风裹挟砂石猛烈抽打机甲装甲板
    low_front = rumble(2.5, 65, 3.0, rng, 1.8) * 0.78
    gale = whoosh(2.4, 180, 1250, rng, 2.5) * 0.85
    grit_hiss = hiss(2.3, 2400, 1600, 1.4, rng) * 0.62
    pelting = np.zeros(int(2.5 * SR))
    for i in range(10):
        t0 = 0.25 + i * 0.2 + rng.uniform(-0.04, 0.04)
        p_cl = clank(0.08, 420 + (i % 4) * 60, METAL_LIGHT, 32.0, rng, 0.45) * 0.35
        pelting = mix(pelting, place(p_cl, t0, 2.5))
    return reverb_tail(sat(mix(low_front, gale, grit_hiss, pelting), 1.55), 0.28, 0.25)


@sfx("sandstorm_end", n=1, target=-17.5, dur=2.0, fout=0.35)
def _sandstorm_end(v, rng):
    # 沙尘暴平息：风沙呼啸逐渐向低频退去 + 机甲防尘百叶窗复位轻响
    wind_fade = whoosh(1.85, 1100, 160, rng, 1.8) * env_exp(1.85, 1.8) * 0.8
    low_fade = rumble(1.85, 60, 2.5, rng, 1.4) * env_exp(1.85, 2.0) * 0.65
    louver_reset = clank(0.20, 290, METAL_LIGHT, 18.0, rng, 0.62) * 0.55
    return sat(mix(
        place(wind_fade, 0.0),
        place(low_fade, 0.0),
        place(louver_reset, 1.35),
    ), 1.35)


@sfx("weather_rain_loop", n=1, target=-19.5, loop=6.0, reps=4)
def _weather_rain_loop(v, rng):
    dur = 6.0
    # 异星酸雨环境循环：密集雨幕白/粉噪带通层 + 雨滴敲击机甲顶盖的细碎金属声 + 远方低沉闷雷
    rain_bed = biquad(pink(dur, rng), "bp", 1650, 1.2) * 0.55
    rain_hi = biquad(white(dur, rng), "bp", 3800, 1.8) * 0.28
    roof_drops = velvet(dur, 42, rng)
    roof_pings = biquad(roof_drops, "bp", 520, 2.2) * 0.35
    distant_thunder = rumble(dur, 52, 2.2, rng, 1.5) * 0.48
    return sat(mix(rain_bed, rain_hi, roof_pings, distant_thunder), 1.25)


# ─────────────────────────────────────────────────────────────
# 机师基地养成与通讯（改装升级 / 科研突破 / 晋升 / 好感 / 赠礼 / 进餐 / 休整 / 档案 / 通讯）
# ─────────────────────────────────────────────────────────────
@sfx("grow_upgrade", n=1, target=-16.0, dur=1.2, fout=0.15)
def _grow_upgrade(v, rng):
    # 机甲部件改装升级：气动扭矩扳手高速紧固 + 重型装甲卡榫落位 + 高压充能就绪
    wrench = servo(0.28, 170, 340, rng, 0.48)
    slam_th = thump(0.32, 118, 30, 11.0, rng, 2.4)
    slam_cl = clank(0.30, 240, METAL_HEAVY, 12.0, rng, 0.85)
    spool = turbine(0.65, 110, 260, rng, 5, 0.09) * 0.58
    seal_hiss = hiss(0.38, 1900, 1200, 7.5, rng) * 0.45
    return reverb_tail(sat(mix(
        place(wrench, 0.0),
        place(slam_th, 0.24),
        place(slam_cl, 0.245),
        place(spool, 0.32),
        place(seal_hiss, 0.68),
    ), 1.6), 0.18, 0.18)


@sfx("grow_research", n=1, target=-16.5, dur=1.3, fout=0.15)
def _grow_research(v, rng):
    # 研发图纸解析完成：精密机械绘图仪滑轨到位 + 真空管腔体锁定 + 合金音叉双模态清澄共鸣
    plotter = servo(0.32, 190, 320, rng, 0.42)
    lock_cl = clank(0.22, 310, METAL_LIGHT, 16.0, rng, 0.72)
    th = thump(0.24, 108, 34, 14.0, rng, 2.0) * 0.7
    fork1 = modal(0.65, 380, METAL_BELL, 6.5, rng, 0.55) * 0.52
    fork2 = modal(0.75, 510, GLASS_MODES, 5.5, rng, 0.58) * 0.55
    return reverb_tail(sat(mix(
        place(plotter, 0.0),
        place(lock_cl, 0.28),
        place(th, 0.285),
        place(fork1, 0.32),
        place(fork2, 0.48),
    ), 1.5), 0.22, 0.2)


@sfx("grow_level", n=1, target=-15.5, dur=1.5, fout=0.2)
def _grow_level(v, rng):
    # 军衔/等级晋升：重型勋章钢印砸落 + 三级液压动力舱依次点火轰鸣
    stamp_th = thump(0.38, 122, 28, 9.5, rng, 2.5)
    stamp_cl = clank(0.35, 235, METAL_HEAVY, 11.0, rng, 0.88)
    bell1 = modal(0.65, 290, METAL_BELL, 6.0, rng, 0.6) * 0.55
    bell2 = modal(0.75, 390, METAL_BELL, 5.5, rng, 0.65) * 0.6
    spool = turbine(0.85, 105, 275, rng, 6, 0.1) * 0.58
    return reverb_tail(sat(mix(
        place(stamp_th, 0.0),
        place(stamp_cl, 0.006),
        place(bell1, 0.04),
        place(spool, 0.18),
        place(bell2, 0.32),
    ), 1.65), 0.24, 0.22)


@sfx("grow_affinity", n=1, target=-17.5, dur=1.0, fout=0.15)
def _grow_affinity(v, rng):
    # 机师羁绊加深：柔和的机械怀表/八音盒棘轮轻响 + 温润低频水晶模态泛音（无刺耳合成器）
    w1 = tick(0.012, 1350, rng) * 0.6
    w2 = tick(0.012, 1500, rng) * 0.6
    warm_th = thump(0.22, 92, 36, 14.0, rng, 1.7) * 0.65
    glass1 = modal(0.55, 340, GLASS_MODES, 6.5, rng, 0.48) * 0.55
    glass2 = modal(0.65, 455, GLASS_MODES, 5.5, rng, 0.52) * 0.58
    return reverb_tail(sat(mix(
        place(w1, 0.0),
        place(w2, 0.06),
        place(warm_th, 0.12),
        place(glass1, 0.13),
        place(glass2, 0.30),
    ), 1.38), 0.24, 0.22)


@sfx("grow_gift", n=1, target=-17.5, dur=0.85, fout=0.1)
def _grow_gift(v, rng):
    # 赠送战术纪念品：精致金属礼盒卡扣打开 + 物品稳稳放置桌面
    latch = clank(0.16, 380, METAL_LIGHT, 20.0, rng, 0.68)
    slide = whoosh(0.20, 320, 720, rng, 1.8) * 0.42
    set_down = thump(0.20, 98, 36, 16.0, rng, 1.8) * 0.7
    bell = modal(0.45, 410, GLASS_MODES, 7.5, rng, 0.5) * 0.52
    return sat(mix(
        place(latch, 0.0),
        place(slide, 0.06),
        place(set_down, 0.24),
        place(bell, 0.25),
    ), 1.4)


@sfx("grow_meal", n=1, target=-17.0, dur=1.1, fout=0.12)
def _grow_meal(v, rng):
    # 战地食堂补给进餐：不锈钢餐盘落桌清脆金属声 + 高压保温舱泄气嘶声
    tray_clank = clank(0.24, 340, METAL_HOLLOW, 15.0, rng, 0.72)
    tray_th = thump(0.20, 102, 36, 16.0, rng, 1.9) * 0.68
    cutlery = clank(0.16, 480, METAL_LIGHT, 22.0, rng, 0.65) * 0.6
    steam_sizzle = hiss(0.55, 2100, 1400, 5.5, rng) * 0.52
    return sat(mix(
        place(tray_clank, 0.0),
        place(tray_th, 0.005),
        place(cutlery, 0.18),
        place(steam_sizzle, 0.28),
    ), 1.45)


@sfx("grow_recover", n=1, target=-16.5, dur=1.3, fout=0.18)
def _grow_recover(v, rng):
    # 医疗舱休整恢复：气密医疗舱门解封泄气 + 气压稳压深呼吸声 + 锁扣解除
    seal_release = hiss(0.65, 1750, 1100, 4.5, rng) * 0.62
    deep_breath = whoosh(0.75, 240, 780, rng, 1.9) * 0.65
    unlatch = clank(0.24, 280, METAL_HEAVY, 15.0, rng, 0.75)
    sub = thump(0.26, 98, 32, 13.0, rng, 2.0) * 0.7
    return reverb_tail(sat(mix(
        place(unlatch, 0.0),
        place(sub, 0.006),
        place(seal_release, 0.08),
        place(deep_breath, 0.22),
    ), 1.45), 0.2, 0.18)


@sfx("story_open", n=1, target=-18.0, dur=0.65, fout=0.08)
def _story_open(v, rng):
    # 开启机密作战简报：缩微胶片/全息投影仪快门开启 + 导轨展开
    shutter = clank(0.16, 350, METAL_LIGHT, 20.0, rng, 0.68)
    srv = servo(0.26, 160, 275, rng, 0.38) * 0.48
    slide = whoosh(0.32, 280, 820, rng, 1.8) * 0.5
    lock = clank(0.16, 260, METAL_HOLLOW, 20.0, rng, 0.65) * 0.65
    return sat(mix(
        place(shutter, 0.0),
        place(srv, 0.04),
        place(slide, 0.05),
        place(lock, 0.32),
    ), 1.4)


@sfx("story_close", n=1, target=-18.5, dur=0.5, fout=0.06)
def _story_close(v, rng):
    # 关闭作战简报：快门脱扣 + 卷宗合拢闷响 + 金属档案夹锁扣咬合
    unlatch = clank(0.11, 330, METAL_LIGHT, 24.0, rng, 0.62)
    slide = whoosh(0.20, 760, 240, rng, 1.8) * 0.45
    shut_th = thump(0.20, 95, 34, 16.0, rng, 1.9) * 0.72
    clasp = clank(0.16, 290, METAL_LIGHT, 20.0, rng, 0.68) * 0.68
    return sat(mix(
        place(unlatch, 0.0),
        place(slide, 0.015),
        place(shut_th, 0.12),
        place(clasp, 0.125),
    ), 1.4)


@sfx("story_text", n=1, target=-24.5, dur=0.042, fout=0.006)
def _story_text(v, rng):
    # 简报电传打字机微触点声：干脆短促的机械撞针轻敲（剔除低频闷鼓声）
    tap = tick(0.009, 2100, rng) * 0.85
    carriage = modal(0.018, 760, METAL_LIGHT, 80.0, rng, 0.28) * 0.32
    return sat(mix(place(tap, 0.0), place(carriage, 0.001)), 1.15)


@sfx("comm_open", n=2, target=-17.5, dur=0.55, fout=0.06)
def _comm_open(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 军用加密无线电PTT按下接通：重型胸前通话键咔哒按下 + 短促静电噪波开启声
    ptt_click = clank(0.14, 340 * p, METAL_LIGHT, 22.0, rng, 0.72)
    ptt_th = thump(0.12, 102 * p, 38 * p, 22.0, rng, 1.8) * 0.65
    squelch_noise = hiss(0.18, 2100 * p, 1200, 14.0, rng) * 0.48
    relay = tick(0.015, 1650 * p, rng) * 0.65
    return sat(mix(
        place(ptt_click, 0.0),
        place(ptt_th, 0.003),
        place(squelch_noise, 0.035),
        place(relay, 0.18),
    ), 1.45)
