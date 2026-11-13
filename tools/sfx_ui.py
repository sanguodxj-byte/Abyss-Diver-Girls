# -*- coding: utf-8 -*-
"""战术终端 UI、机库整备装配、货舱装卸与商店交易音效（冷峻工业机械终端重制版）。"""
import numpy as np
from sfx_dsp import (
    SR, sfx, env_exp, env_adsr, biquad, reson, sweep,
    white, pink, brown, velvet, sat, place, mix, reverb_tail,
)
from sfx_lib import (
    thump, crack, tick, clank, modal, METAL_HEAVY, METAL_HOLLOW, METAL_LIGHT,
    METAL_BELL, GLASS_MODES, servo, hiss, whoosh, roar, rumble, zap, turbine,
)


# ─────────────────────────────────────────────────────────────
# 战术终端基础交互（微动机械开关 / 电磁继电器 / 阻尼拨盘，零电子蜂鸣）
# ─────────────────────────────────────────────────────────────
@sfx("ui_click", n=2, target=-21.0, dur=0.08, fout=0.012)
def _ui_click(v, rng):
    p = 1.0 + (v - 0.5) * 0.06
    # 战术面板微动开关：清脆银触点瞬态 + 紧凑铝合金键帽壳体共鸣 + 微动回弹
    sw_down = tick(0.013, 1950 * p, rng) * 0.92
    body = modal(0.034, 620 * p, METAL_LIGHT, 55.0, rng, 0.38) * 0.48
    sw_release = tick(0.010, 1520 * p, rng) * 0.42
    return sat(mix(
        place(sw_down, 0.0),
        place(body, 0.001),
        place(sw_release, 0.024),
    ), 1.25)


@sfx("ui_hover", n=1, target=-25.5, dur=0.045, fout=0.008)
def _ui_hover(v, rng):
    # 极轻快的磁吸刻度拨盘微触感（剔除低频闷响，纯清脆微动刻度）
    detent = tick(0.009, 2250, rng) * 0.85
    cap = modal(0.020, 860, METAL_LIGHT, 75.0, rng, 0.25) * 0.30
    return sat(mix(place(detent, 0.0), place(cap, 0.001)), 1.15)


@sfx("ui_confirm", n=1, target=-18.5, dur=0.24, fout=0.03)
def _ui_confirm(v, rng):
    # 确认指令：干脆利落的双段式战术扳机锁合（微动预压 -> 精密电磁栓清脆咬合）
    pre_sw = tick(0.013, 1850, rng) * 0.82
    pre_cl = modal(0.042, 560, METAL_LIGHT, 45.0, rng, 0.45) * 0.52
    lock_tick = tick(0.015, 2380, rng) * 0.88
    main_lock = clank(0.095, 460, METAL_BELL, 28.0, rng, 0.58) * 0.68
    main_thump = thump(0.065, 150, 64, 34.0, rng, 1.3) * 0.26
    return sat(mix(
        place(pre_sw, 0.0),
        place(pre_cl, 0.002),
        place(lock_tick, 0.042),
        place(main_lock, 0.043),
        place(main_thump, 0.045),
    ), 1.32)


@sfx("ui_cancel", n=1, target=-19.5, dur=0.20, fout=0.025)
def _ui_cancel(v, rng):
    # 取消/退回：清脆弹簧卡扣脱钩 + 阻尼复位（由高到低双段机械瞬态）
    unlatch_t = tick(0.012, 1920, rng) * 0.80
    unlatch = clank(0.055, 520, METAL_LIGHT, 38.0, rng, 0.52) * 0.58
    drop_t = tick(0.011, 1360, rng) * 0.65
    drop_clank = clank(0.075, 350, METAL_HOLLOW, 32.0, rng, 0.48) * 0.55
    drop_thump = thump(0.055, 132, 56, 36.0, rng, 1.25) * 0.24
    return sat(mix(
        place(unlatch_t, 0.0),
        place(unlatch, 0.001),
        place(drop_t, 0.038),
        place(drop_clank, 0.040),
        place(drop_thump, 0.042),
    ), 1.28)


@sfx("ui_tab", n=1, target=-21.0, dur=0.11, fout=0.015)
def _ui_tab(v, rng):
    # 切换分页：清脆旋转波段开关咔哒啮合
    det1 = tick(0.012, 1820, rng) * 0.85
    rot = clank(0.055, 510, METAL_LIGHT, 42.0, rng, 0.50) * 0.58
    det2 = tick(0.010, 2180, rng) * 0.52
    return sat(mix(place(det1, 0.0), place(rot, 0.002), place(det2, 0.018)), 1.25)


@sfx("ui_open", n=1, target=-19.5, dur=0.28, fout=0.035)
def _ui_open(v, rng):
    # 打开战术面板：锁扣清脆弹开 + 精密导轨轻快滑出 + 到位卡榫啮合
    latch_t = tick(0.012, 1780, rng) * 0.78
    latch = clank(0.065, 440, METAL_LIGHT, 34.0, rng, 0.55) * 0.62
    slide = whoosh(0.14, 420, 1250, rng, 1.5) * 0.38
    stop_t = tick(0.012, 2150, rng) * 0.72
    stop_lock = clank(0.075, 480, METAL_HOLLOW, 32.0, rng, 0.52) * 0.58
    return sat(mix(
        place(latch_t, 0.0),
        place(latch, 0.002),
        place(slide, 0.018),
        place(stop_t, 0.125),
        place(stop_lock, 0.127),
    ), 1.3)


@sfx("ui_close", n=1, target=-20.0, dur=0.24, fout=0.03)
def _ui_close(v, rng):
    # 关闭战术面板：脱扣瞬态 + 导轨收拢 + 清脆卡扣合拢
    unlatch = tick(0.012, 1850, rng) * 0.75
    rel_clank = clank(0.055, 460, METAL_LIGHT, 36.0, rng, 0.50) * 0.52
    slide = whoosh(0.11, 1100, 360, rng, 1.5) * 0.35
    shut_t = tick(0.012, 1480, rng) * 0.72
    shut_clank = clank(0.075, 360, METAL_HOLLOW, 30.0, rng, 0.55) * 0.60
    shut_thump = thump(0.055, 130, 56, 36.0, rng, 1.3) * 0.24
    return sat(mix(
        place(unlatch, 0.0),
        place(rel_clank, 0.002),
        place(slide, 0.012),
        place(shut_t, 0.078),
        place(shut_clank, 0.080),
        place(shut_thump, 0.082),
    ), 1.3)


@sfx("ui_denied", n=1, target=-18.5, dur=0.24, fout=0.025)
def _ui_denied(v, rng):
    # 权限拒绝/操作无效：干脆的双连机械止动卡死声（咔-咔！）
    t_hit1 = tick(0.013, 1750, rng) * 0.85
    c1 = clank(0.065, 430, METAL_HEAVY, 36.0, rng, 0.65) * 0.72
    th1 = thump(0.045, 145, 62, 38.0, rng, 1.35) * 0.25
    t_hit2 = tick(0.013, 1420, rng) * 0.88
    c2 = clank(0.080, 340, METAL_HEAVY, 30.0, rng, 0.70) * 0.76
    th2 = thump(0.055, 128, 54, 34.0, rng, 1.4) * 0.28
    return sat(mix(
        place(t_hit1, 0.0),
        place(c1, 0.001),
        place(th1, 0.003),
        place(t_hit2, 0.072),
        place(c2, 0.073),
        place(th2, 0.075),
    ), 1.35)


# ─────────────────────────────────────────────────────────────
# 机库整备：部件拆装 / 爆炸图展开 / 出击整备启动
# ─────────────────────────────────────────────────────────────
@sfx("hub_detach", n=1, target=-16.5, dur=0.95, fout=0.08)
def _hub_detach(v, rng):
    # 拆卸机甲部件：气动套筒松脱螺栓 -> 液压吊臂抽离 -> 高压气管断开嘶鸣
    bolt_loos = clank(0.22, 340, METAL_HEAVY, 16.0, rng, 0.78)
    air_puff = hiss(0.28, 1900, 1200, 10.0, rng) * 0.55
    srv_pull = servo(0.42, 240, 130, rng, 0.48)
    heavy_unseat = thump(0.28, 105, 34, 14.0, rng, 2.0) * 0.72
    cl_free = clank(0.25, 220, METAL_HOLLOW, 14.0, rng, 0.68) * 0.65
    return sat(mix(
        place(bolt_loos, 0.0),
        place(air_puff, 0.04),
        place(srv_pull, 0.14),
        place(heavy_unseat, 0.22),
        place(cl_free, 0.23),
    ), 1.55)


@sfx("hub_dock", n=2, target=-15.5, dur=0.95, fout=0.08)
def _hub_dock(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 安装机甲部件：液压推进对准 -> 重型钢制卡榫轰然落锁 -> 气动锁紧扳手加固
    srv_in = servo(0.22, 140 * p, 260 * p, rng, 0.45)
    dock_thump = thump(0.36, 118 * p, 28 * p, 10.0, rng, 2.5)
    dock_clank = clank(0.35, 225 * p, METAL_HEAVY, 11.0, rng, 0.88)
    wrench_lock = clank(0.22, 390 * p, METAL_LIGHT, 18.0, rng, 0.72) * 0.7
    seal_hiss = hiss(0.25, 1750 * p, 1100, 12.0, rng) * 0.42
    return reverb_tail(sat(mix(
        place(srv_in, 0.0),
        place(dock_thump, 0.18),
        place(dock_clank, 0.185),
        place(wrench_lock, 0.42),
        place(seal_hiss, 0.46),
    ), 1.65), 0.16, 0.16)


@sfx("hub_explode", n=1, target=-17.5, dur=1.1, fout=0.1)
def _hub_explode(v, rng):
    # 机库检视“装甲分解展开”：多组导轨依次解锁滑开
    out = np.zeros(int(1.1 * SR))
    for i in range(4):
        t0 = i * 0.11
        pf = 1.0 + i * 0.08
        unlatch = clank(0.16, 280 * pf, METAL_HEAVY, 18.0, rng, 0.7) * 0.65
        srv = servo(0.26, 160 * pf, 290 * pf, rng, 0.4) * 0.48
        slide = whoosh(0.24, 300 * pf, 850 * pf, rng, 1.8) * 0.45
        out = mix(out, place(unlatch, t0, 1.1), place(srv, t0 + 0.02, 1.1), place(slide, t0 + 0.03, 1.1))
    return sat(out, 1.45)


@sfx("hub_assemble", n=1, target=-16.5, dur=1.2, fout=0.1)
def _hub_assemble(v, rng):
    # 机库检视“装甲合拢复位”：导轨滑回 + 连环重型装甲锁扣合拢
    slide = whoosh(0.45, 820, 240, rng, 2.0) * 0.55
    srv = servo(0.42, 280, 150, rng, 0.45) * 0.5
    out = mix(place(slide, 0.0, 1.2), place(srv, 0.02, 1.2))
    for i in range(3):
        t0 = 0.25 + i * 0.14
        pf = 1.1 - i * 0.08
        cl = clank(0.24, 250 * pf, METAL_HEAVY, 14.0, rng, 0.8) * 0.72
        th = thump(0.22, 108 * pf, 32 * pf, 14.0, rng, 2.1) * 0.68
        out = mix(out, place(cl, t0, 1.2), place(th, t0 + 0.004, 1.2))
    return sat(out, 1.55)


@sfx("hub_starter", n=1, target=-15.0, dur=2.2, fout=0.25)
def _hub_starter(v, rng):
    # 出击整备主电源合闸：机库重型闸刀闭合 -> 燃气轮机点火 -> 弹射架气压蓄满
    breaker = clank(0.35, 210, METAL_HEAVY, 11.0, rng, 0.88)
    sub_boom = thump(0.45, 115, 26, 8.0, rng, 2.5)
    spool = turbine(1.55, 75, 245, rng, 6, 0.1) * 0.72
    furnace = roar(1.25, 210, 3.0, rng, 1.9) * 0.65
    catapult_lock = clank(0.32, 290, METAL_HEAVY, 12.0, rng, 0.82) * 0.75
    steam = hiss(0.75, 1850, 1200, 4.5, rng) * 0.48
    return reverb_tail(sat(mix(
        place(breaker, 0.0),
        place(sub_boom, 0.02),
        place(spool, 0.12),
        place(furnace, 0.18),
        place(catapult_lock, 1.25),
        place(steam, 1.30),
    ), 1.7), 0.25, 0.22)


# ─────────────────────────────────────────────────────────────
# 货舱装卸 / 军需商店交易 / 委托完成
# ─────────────────────────────────────────────────────────────
@sfx("cargo_load", n=1, target=-18.5, dur=0.55, fout=0.05)
def _cargo_load(v, rng):
    # 物资装入货舱：金属箱滑入导轨 + 弹簧卡扣锁紧
    slide = whoosh(0.16, 280, 680, rng, 1.8) * 0.48
    th = thump(0.20, 105, 36, 16.0, rng, 2.0) * 0.72
    latch = clank(0.22, 290, METAL_HEAVY, 16.0, rng, 0.75)
    return sat(mix(place(slide, 0.0), place(th, 0.11), place(latch, 0.115)), 1.45)


@sfx("cargo_unload", n=1, target=-18.5, dur=0.55, fout=0.05)
def _cargo_unload(v, rng):
    # 物资卸下货舱：卡扣弹开 + 货箱抽出落位
    unlatch = clank(0.16, 360, METAL_LIGHT, 20.0, rng, 0.68)
    slide = whoosh(0.18, 650, 260, rng, 1.8) * 0.45
    drop = thump(0.20, 95, 34, 16.0, rng, 1.9) * 0.7
    cl = clank(0.18, 230, METAL_HOLLOW, 18.0, rng, 0.65) * 0.65
    return sat(mix(
        place(unlatch, 0.0),
        place(slide, 0.05),
        place(drop, 0.18),
        place(cl, 0.185),
    ), 1.45)


@sfx("shop_buy", n=1, target=-17.5, dur=0.8, fout=0.08)
def _shop_buy(v, rng):
    # 军需采购：印章式气动钢印砸下 + 弹药箱滑出补给槽
    stamp_thump = thump(0.24, 115, 34, 14.0, rng, 2.2)
    stamp_clank = clank(0.22, 275, METAL_HEAVY, 15.0, rng, 0.8)
    chute = whoosh(0.28, 320, 780, rng, 1.8) * 0.5
    crate_land = clank(0.26, 340, METAL_LIGHT, 16.0, rng, 0.72) * 0.72
    air_puff = hiss(0.20, 1750, 1100, 14.0, rng) * 0.35
    return sat(mix(
        place(stamp_thump, 0.0),
        place(stamp_clank, 0.005),
        place(air_puff, 0.04),
        place(chute, 0.18),
        place(crate_land, 0.36),
    ), 1.5)


@sfx("shop_sell", n=2, target=-18.0, dur=0.75, fout=0.08)
def _shop_sell(v, rng):
    p = 1.0 + (v - 0.5) * 0.05
    # 物资回收变卖：回收舱门闭合 + 机械计数器连跳三下 + 液压压实闷响
    chute_in = clank(0.18, 260 * p, METAL_HOLLOW, 18.0, rng, 0.7)
    t1 = tick(0.015, 1600 * p, rng) * 0.65
    t2 = tick(0.015, 1750 * p, rng) * 0.65
    t3 = tick(0.015, 1900 * p, rng) * 0.7
    seal_thump = thump(0.24, 102 * p, 34 * p, 14.0, rng, 2.0) * 0.75
    seal_clank = clank(0.22, 310 * p, METAL_HEAVY, 16.0, rng, 0.75) * 0.7
    return sat(mix(
        place(chute_in, 0.0),
        place(t1, 0.14),
        place(t2, 0.21),
        place(t3, 0.28),
        place(seal_thump, 0.36),
        place(seal_clank, 0.365),
    ), 1.45)


@sfx("request_complete", n=1, target=-16.0, dur=1.4, fout=0.15)
def _request_complete(v, rng):
    # 作战委托达成：重型钢印落锁 + 双层厚重金属钟板共鸣（非电子音阶） + 气压泄放
    slam = thump(0.36, 120, 30, 10.0, rng, 2.4)
    bolt = clank(0.32, 245, METAL_HEAVY, 12.0, rng, 0.85)
    plate1 = modal(0.65, 320, METAL_BELL, 6.5, rng, 0.6) * 0.55
    plate2 = modal(0.75, 425, METAL_BELL, 5.5, rng, 0.65) * 0.6
    air = hiss(0.45, 1700, 1100, 7.0, rng) * 0.38
    return reverb_tail(sat(mix(
        place(slam, 0.0),
        place(bolt, 0.006),
        place(plate1, 0.02),
        place(air, 0.12),
        place(plate2, 0.24),
    ), 1.6), 0.22, 0.2)
