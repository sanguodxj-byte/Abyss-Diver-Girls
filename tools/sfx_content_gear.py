"""
新装备、地图事件、局外成长与剧情系统的音效配方。
装备音走武器与机构两层：轨道炮是电容升调后的一记电磁爆响，电弧是密集放电，迫击炮是出膛闷响带长尾，
钻头是咬合加持续研磨的循环，等离子是低频呼啸，无人机点射是短促电音；
地图事件走材料声（帆布、金属柜、纸页、风沙）；局外成长与剧情属于界面层，短促克制。
"""
import numpy as np

from sfx_dsp import sfx, ns, tt, white, pink, brown, lp, hp, bp, peak, reson, sweep, sine, harm, saw_amps, square_amps, \
    expdec, ad, env, ahr, sat, crush, space, Mix
from sfx_lib import tick, clank, modal, thump, crack, burst, whoosh, hiss, servo, debris, scrape, rattle, \
    roar, crackle, arc, buzz, tone, chime, bubbles, slime, crunch, turbine, PLATE, BAR, TUBE, HEAVY, BELL


def st(c, x, kind="yard", wet=0.2):
    """按声部是否需要 2D 决定立体声，再放进空间。"""
    return space(x, kind, wet, c.stereo, c.v)


# ====================================================================== 新装备：武器
@sfx("wpn_railgun_charge", n=1, target=-17.0, dur=0.55, fout=0.02)
def railgun_charge(c):
    """电容蓄力：电枢升调的窄带啸声、逐渐变密的放电颗粒、低频电能嗡鸣，恰好铺满 0.55 秒的蓄力窗口。"""
    rng = c.rng
    n = ns(0.55)
    t = tt(n)
    u = t / 0.55
    m = Mix(0.55)
    rise = np.clip(u, 0.0, 1.0) ** 1.5
    m.add(tick(rng, 2600.0, 0.004, 0.03), 0.0, 0.5)
    whine = harm(180.0 + 1180.0 * rise ** 1.7, [1.0, 0.5, 0.3, 0.18, 0.1]) * rise
    m.add(whine, 0.0, 0.55)
    coil = sine(58.0 + 22.0 * rise) * (0.6 + 0.4 * np.sin(2 * np.pi * 7.0 * t)) * rise
    m.add(sat(coil, 2.0), 0.0, 0.5)
    grit = arc(rng, 0.55, 380.0, 3200.0, 0.2, 0.8, 8) * (0.08 + 0.92 * rise ** 2)
    m.add(grit * (0.15 + 0.85 * rise), 0.0, 0.45)
    m.add(hiss(rng, 0.55, 5000.0, 12000.0, 0.02, 0.4, 0.1, (7000.0, 9500.0), 6.0) * rise, 0.0, 0.18)
    m.add(buzz(112.0, 0.55, None, 900.0) * rise, 0.02, 0.16)
    x = m.render()
    x = sat(x / (np.max(np.abs(x)) + 1e-9), 1.25)
    return st(c, x, "cockpit", 0.12)


@sfx("wpn_railgun_fire", n=3, target=-12.5, dur=1.3, fout=0.2)
def railgun_fire(c):
    """电磁爆响：极短的破空瞬态、放电的滑音脉冲、贯穿轨道的金属回震、低频推力与远处的回响。"""
    rng = c.rng
    v = c.v
    tune = [1.0, 0.93, 1.06][v]
    m = Mix()
    m.add(crack(rng, 0.06, 0.007, 1800.0), 0.0, 0.9)
    n1 = ns(0.34)
    t1 = tt(n1)
    zap = sine((260.0 + 3400.0 * np.exp(-t1 / 0.03)) * tune) * expdec(n1, 0.055)
    m.add(sat(zap, 2.2), 0.0, 0.75)
    m.add(burst(rng, 0.3, 0.04, 120.0, 3200.0, -2.0, 0.0004, 1.8), 0.0, 0.85)
    m.add(thump(rng, 96.0 * tune, 34.0, 0.9, 0.22, 0.03, 2.6, 0.15), 0.0, 0.7)
    m.add(modal(rng, 232.0 * tune, HEAVY, 0.55, 1.2, 0.04, 0.8, 0.7), 0.004, 0.5)
    m.add(modal(rng, 640.0 * tune, PLATE, 0.3, 1.0, 0.05, 0.9, 0.8), 0.002, 0.25)
    m.add(hiss(rng, 0.5, 3500.0, 12000.0, 0.002, 0.03, 0.4, (6000.0, 9000.0), 5.0), 0.01, 0.3)
    m.add(hiss(rng, 0.35, 900.0, 6000.0, 0.02, 0.1, 0.4, (2400.0, 4200.0), 4.0, 0.6), 0.06, 0.35)
    x = m.render()
    src = lp(x, 2200.0)
    for d, g in ((0.16, 0.22), (0.34, 0.13), (0.55, 0.07)):
        m.add(src, c.j(d, 0.06), g)
    return st(c, m.render(), "valley", 0.3)


@sfx("wpn_arc_fire", n=3, target=-14.5, dur=0.7, fout=0.08)
def arc_fire(c):
    """电弧甩出：扳机的一声脆响、密集放电、被空气拉长的工频嗡声与嘶嘶的余电。"""
    rng = c.rng
    v = c.v
    tune = [1.0, 0.85, 1.12][v]
    m = Mix()
    m.add(crack(rng, 0.03, 0.004, 2400.0), 0.0, 0.6)
    m.add(tick(rng, 3200.0 * tune, 0.003, 0.02), 0.0, 0.4)
    m.add(arc(rng, c.j(0.26, 0.1), 500.0 + 180.0 * v, 2600.0 * tune, 0.28, 0.75, 7), 0.0, 0.95)
    m.add(arc(rng, 0.18, 260.0, 4000.0, 0.1, 0.9, 8), c.r(0.03, 0.06), 0.35)
    hum = harm(120.0 * tune, saw_amps(18), ns(0.35)) * ad(ns(0.35), 0.004, 0.09)
    m.add(hum, 0.0, 0.16)
    m.add(hiss(rng, 0.4, 4500.0, 13000.0, 0.002, 0.03, 0.25, (6500.0, 9800.0), 6.0), 0.02, 0.3)
    m.add(thump(rng, 210.0, 90.0, 0.14, 0.03, 0.01, 1.4, 0.1), 0.0, 0.3)
    x = sat(m.render(), 1.3)
    return st(c, x, "yard", 0.16)


@sfx("wpn_mortar_fire", n=2, target=-13.0, dur=1.0, fout=0.14)
def mortar_fire(c):
    """迫击炮出膛：药包爆燃的闷响、炮管金属余震、炮口冲击气流与山谷里的回声。"""
    rng = c.rng
    v = c.v
    tune = [1.0, 0.92][v]
    m = Mix()
    m.add(thump(rng, 118.0 * tune, 30.0, 0.85, 0.2, 0.045, 3.2, 0.25), 0.0, 0.9)
    m.add(burst(rng, 0.5, 0.06, 45.0, 900.0, -3.0, 0.0008, 2.0), 0.0, 0.8)
    m.add(modal(rng, 286.0 * tune, TUBE, 0.42, 0.9, 0.03, 0.7, 0.5), 0.004, 0.45)
    m.add(clank(rng, 520.0 * tune, 0.09, HEAVY, 0.5, 0.6, 0.7, 5000.0), 0.02, 0.35)
    m.add(whoosh(rng, 0.45, 180.0, 900.0, 0.12, 1.2, -2.0, 3.0), 0.02, 0.3)
    m.add(hiss(rng, 0.35, 1200.0, 7000.0, 0.005, 0.05, 0.4, (2600.0, 4800.0), 4.0, 0.5), 0.04, 0.28)
    x = sat(m.render(), 1.2)
    src = lp(x, 1500.0)
    for d, g in ((0.22, 0.18), (0.46, 0.1)):
        m.add(src, d, g)
    return st(c, m.render(), "valley", 0.28)


@sfx("wpn_drill_ignite", n=1, target=-15.0, dur=0.6, fout=0.06)
def drill_ignite(c):
    """钻头咬合：电机从低速拉起到工作转速、齿轮啃住岩面的第一口、随后的碎屑抛飞。"""
    rng = c.rng
    m = Mix(0.6)
    m.add(servo(rng, 0.32, 90.0, 620.0, 0.28, 0.04, 9.0, 0.35, 6000.0), 0.0, 0.55)
    m.add(clank(rng, 760.0, 0.06, PLATE, 0.35, 0.7, 0.5, 5000.0), 0.05, 0.45)
    m.add(crunch(rng, 0.16, 70, 0.06, 900.0, 8000.0, 0.5, 380.0), 0.06, 0.6)
    m.add(thump(rng, 130.0, 62.0, 0.3, 0.08, 0.02, 1.8, 0.2), 0.08, 0.4)
    m.add(burst(rng, 0.4, 0.08, 200.0, 2600.0, -3.0, 0.004, 1.2), 0.07, 0.45)
    m.add(rattle(rng, 0.3, 90.0, 1800.0, 6000.0, 0.1, 0.004), 0.15, 0.22)
    x = sat(m.render(), 1.4)
    return st(c, x, "yard", 0.14)


@sfx("wpn_drill_loop", n=1, target=-16.5, loop=1.5, reps=4)
def drill_loop(c):
    """钻头持续研磨：电机基频与齿轮啮合的低频轰鸣、岩屑被反复刮碎的噪声、钻杆的金属颤响，一遍 1.5 秒无缝。"""
    rng = c.rng
    n = c.total
    p = c.period
    fr = 61.0 + 2.0 * np.sin(2 * np.pi * np.arange(n) / p * 1.0)
    motor = harm(fr, [1.0, 0.62, 0.42, 0.26, 0.15, 0.09]) * (0.8 + 0.2 * np.sin(2 * np.pi * 18.0 * tt(n)))
    gear = harm(fr * 9.0, [1.0, 0.32, 0.14]) * (1.0 + 0.3 * np.sin(2 * np.pi * 3.0 * tt(n)))
    grind = roar(rng, n, 180.0, 3400.0, 26.0, 0.65, -3.0, p)
    rock = crackle(rng, n, 70.0, 1200.0, 7000.0, p) * 0.5
    metal = rattle(rng, n / 44100.0, 55.0, 900.0, 4200.0, 0.3, 0.006) * 0.35
    x = 0.5 * np.tanh(2.0 * motor) + 0.55 * grind + 0.3 * rock + metal
    x = sat(np.asarray(x) / (np.max(np.abs(x)) + 1e-9), 1.2)
    return st(c, x, "yard", 0.1)


@sfx("wpn_plasma_fire", n=2, target=-13.5, dur=1.0, fout=0.14)
def plasma_fire(c):
    """等离子团出膛：低频推力的呼啸、等离子约束壳的电流颤鸣、炮口的空气爆裂与随后的余温嘶声。"""
    rng = c.rng
    v = c.v
    tune = [1.0, 0.88][v]
    m = Mix()
    m.add(thump(rng, 105.0 * tune, 38.0, 0.7, 0.16, 0.035, 2.4, 0.2), 0.0, 0.7)
    n1 = ns(0.5)
    t1 = tt(n1)
    zap = harm((170.0 + 900.0 * np.exp(-t1 / 0.09)) * tune, [1.0, 0.5, 0.3, 0.16]) * expdec(n1, 0.16)
    m.add(sat(zap, 1.8), 0.0, 0.5)
    m.add(roar(rng, ns(0.55), 55.0, 700.0, 9.0, 0.5, -4.0), 0.0, 0.75)
    m.add(whoosh(rng, 0.5, 260.0, 1800.0, 0.2, 1.6, -2.0, 2.2), 0.02, 0.45)
    m.add(burst(rng, 0.25, 0.03, 600.0, 6000.0, -1.0, 0.0005, 1.5), 0.0, 0.4)
    m.add(hiss(rng, 0.6, 3000.0, 12000.0, 0.01, 0.12, 0.5, (5200.0, 8600.0), 4.0, 0.7), 0.05, 0.22)
    m.add(arc(rng, 0.12, 200.0, 3000.0, 0.15, 0.6, 7), 0.03, 0.3)
    x = sat(m.render(), 1.3)
    return st(c, x, "valley", 0.24)


@sfx("wpn_drone_fire", n=3, target=-17.0, dur=0.4, fout=0.05)
def drone_fire(c):
    """无人机点射：旋翼伺服的一下抽动、短促的下滑电音与尾部的小电流声，三发变体音高不同。"""
    rng = c.rng
    v = c.v
    f = [1850.0, 1620.0, 2080.0][v]
    m = Mix(0.4)
    m.add(tick(rng, 3400.0, 0.003, 0.02), 0.0, 0.4)
    m.add(tone([f, f * 0.72], 0.09, "square", 0.03, 0.001, bright=5200.0), 0.0, 0.7)
    m.add(tone([f * 0.5], 0.06, "sine", 0.02, 0.001), 0.004, 0.35)
    m.add(servo(rng, 0.12, 900.0, 1500.0, 0.05, 0.05, 6.0, 0.4, 6000.0), 0.0, 0.2)
    m.add(arc(rng, 0.1, 300.0, 3800.0, 0.25, 0.6, 8), 0.01, 0.22)
    return st(c, sat(m.render(), 1.2), "cockpit", 0.1)


# ====================================================================== 新装备：挂件与消耗品
@sfx("drone_deploy", n=1, target=-16.0, dur=1.2, fout=0.1)
def drone_deploy(c):
    """无人机弹射展开：挂架解锁的金属撞击、弹射气流的嘶声、旋翼从静止拉到巡航、电子自检的一声轻响。"""
    rng = c.rng
    m = Mix(1.2)
    m.add(clank(rng, 680.0, 0.06, PLATE, 0.4, 0.7, 0.5, 6000.0), 0.0, 0.55)
    m.add(tick(rng, 3200.0, 0.004, 0.03), 0.02, 0.4)
    m.add(whoosh(rng, 0.35, 500.0, 2600.0, 0.15, 1.4, -3.0, 2.0), 0.03, 0.4)
    m.add(hiss(rng, 0.3, 2500.0, 10000.0, 0.004, 0.04, 0.35, (4200.0, 7000.0), 5.0, 0.4), 0.03, 0.25)
    n = ns(0.9)
    rot = np.linspace(38.0, 132.0, n)
    m.add(turbine(rng, n, rot, 9, 0.55, 0.35, 80.0, 7000.0) * env([(0, 0), (0.08, 0.15), (0.35, 1.0), (0.9, 0.8)], n), 0.18, 0.45)
    m.add(servo(rng, 0.35, 500.0, 1100.0, 0.2, 0.1, 6.0, 0.3, 6000.0), 0.22, 0.2)
    m.add(tone(1480.0, 0.07, "sine", 0.03, 0.002), 0.62, 0.18)
    m.add(tone(1980.0, 0.05, "sine", 0.02, 0.002), 0.72, 0.12)
    return st(c, sat(m.render(), 1.15), "yard", 0.18)


@sfx("decoy_deploy", n=1, target=-16.0, dur=1.3, fout=0.1)
def decoy_deploy(c):
    """诱饵三脚架展开：三条支撑腿依次落地、液压杆撑起的伺服声、开机自检的两声电子音与常亮的电流底噪。"""
    rng = c.rng
    m = Mix(1.3)
    for k, (t0, g) in enumerate(((0.0, 0.6), (0.17, 0.5), (0.33, 0.55))):
        m.add(clank(rng, 540.0 + 90.0 * k, 0.05, HEAVY, 0.28, 0.6, 0.5, 5000.0), t0, g)
        m.add(tick(rng, 2600.0 + 300.0 * k, 0.003, 0.02), t0 + 0.01, 0.25)
    m.add(servo(rng, 0.42, 220.0, 760.0, 0.3, 0.08, 8.0, 0.3, 5000.0), 0.3, 0.35)
    m.add(hiss(rng, 0.25, 1800.0, 8000.0, 0.01, 0.06, 0.3, (3200.0, 5600.0), 4.0, 0.5), 0.34, 0.18)
    m.add(tone(1320.0, 0.1, "square", 0.05, 0.002, bright=4200.0), 0.66, 0.22)
    m.add(tone(1760.0, 0.12, "square", 0.05, 0.002, bright=4200.0), 0.79, 0.2)
    m.add(buzz(124.0, 0.45, None, 1200.0) * env([(0, 0), (0.05, 1.0), (0.45, 0.5)], ns(0.45)), 0.78, 0.12)
    return st(c, sat(m.render(), 1.15), "yard", 0.2)


@sfx("decoy_off", n=1, target=-19.0, dur=0.6, fout=0.06)
def decoy_off(c):
    """信标熄灭：电流被切断后扬声器频率一路下滑、继电器松开的一记咔哒与电容放完的余音。"""
    rng = c.rng
    m = Mix(0.6)
    n = ns(0.32)
    wh = harm(np.geomspace(1500.0, 220.0, n), [1.0, 0.45, 0.2]) * expdec(n, 0.14)
    m.add(wh, 0.0, 0.5)
    m.add(clank(rng, 420.0, 0.03, PLATE, 0.18, 0.5, 0.4, 5000.0), 0.02, 0.35)
    m.add(tick(rng, 1800.0, 0.004, 0.03), 0.16, 0.25)
    m.add(hiss(rng, 0.3, 2000.0, 9000.0, 0.002, 0.02, 0.3, (4000.0, 6600.0), 5.0, 0.8), 0.02, 0.16)
    m.add(thump(rng, 120.0, 70.0, 0.18, 0.05, 0.015, 1.2, 0.1), 0.0, 0.18)
    return st(c, m.render(), "yard", 0.14)


@sfx("flare_ignite", n=1, target=-16.0, dur=1.6, fout=0.2)
def flare_ignite(c):
    """烟幕点燃：擦火的一下、药柱被点燃的爆燃、随后持续喷出的嘶嘶气流与火星爆裂，尾音留出烟幕铺开的余量。"""
    rng = c.rng
    m = Mix(1.6)
    m.add(scrape(rng, 0.12, 1500.0, 7000.0, 90.0, [2600.0, 4200.0], 20.0), 0.0, 0.35)
    m.add(crack(rng, 0.05, 0.006, 2200.0), 0.01, 0.5)
    m.add(thump(rng, 160.0, 60.0, 0.35, 0.08, 0.02, 1.8, 0.3), 0.02, 0.4)
    m.add(roar(rng, ns(0.5), 90.0, 2400.0, 12.0, 0.6, -3.0), 0.02, 0.55)
    n = ns(1.5)
    body = roar(rng, n, 400.0, 6000.0, 20.0, 0.5, -2.0) * env([(0, 0), (0.06, 0.9), (0.5, 0.7), (1.5, 0.0)], n)
    m.add(body, 0.03, 0.65)
    m.add(crackle(rng, n, 26.0, 1800.0, 9000.0) * env([(0, 0), (0.08, 1.0), (1.2, 0.3), (1.5, 0)], n), 0.03, 0.3)
    m.add(hiss(rng, 1.3, 3000.0, 12000.0, 0.02, 0.4, 0.9, (5600.0, 8800.0), 4.0, 0.6), 0.08, 0.25)
    return st(c, sat(m.render(), 1.2), "yard", 0.2)


@sfx("energy_cell_plug", n=1, target=-16.0, dur=1.0, fout=0.1)
def energy_cell_plug(c):
    """电池棒接通：插进槽位的一记闷响与锁扣、电流涌入时升起的嗡鸣、接触点的噼啪与充能完成的一声确认。"""
    rng = c.rng
    m = Mix(1.0)
    m.add(thump(rng, 150.0, 70.0, 0.25, 0.05, 0.015, 1.6, 0.3), 0.0, 0.5)
    m.add(clank(rng, 620.0, 0.05, PLATE, 0.25, 0.7, 0.5, 6000.0), 0.0, 0.5)
    m.add(tick(rng, 2400.0, 0.003, 0.02), 0.04, 0.3)
    n = ns(0.7)
    t = tt(n)
    cur = harm(100.0 + 140.0 * np.clip(t / 0.35, 0, 1), [1.0, 0.5, 0.3, 0.18]) * (0.4 + 0.6 * np.clip(t / 0.3, 0, 1)) * expdec(n, 0.5)
    m.add(sat(cur, 1.6), 0.06, 0.4)
    m.add(arc(rng, 0.18, 120.0, 2600.0, 0.3, 0.6, 8), 0.08, 0.28)
    m.add(tone(1560.0, 0.09, "sine", 0.04, 0.002), 0.5, 0.16)
    m.add(tone(2080.0, 0.07, "sine", 0.03, 0.002), 0.6, 0.12)
    m.add(buzz(98.0, 0.3, None, 800.0) * env([(0, 0), (0.06, 1.0), (0.3, 0)], ns(0.3)), 0.3, 0.1)
    return st(c, m.render(), "cockpit", 0.12)


@sfx("web_pulse", n=2, target=-17.0, dur=0.9, fout=0.1)
def web_pulse(c):
    """减速网的黏性脉冲：发射器放出的电流短促声、网团张开时甩出的黏稠吧唧、细小气泡与随后拉丝的尾音。"""
    rng = c.rng
    v = c.v
    m = Mix(0.9)
    m.add(arc(rng, 0.12, 260.0, 3200.0, 0.2, 0.7, 8), 0.0, 0.35)
    m.add(tick(rng, 2600.0 + 400.0 * v, 0.003, 0.02), 0.0, 0.3)
    m.add(slime(rng, 0.28, 3200.0 + 600.0 * v, 420.0, 1.8, 0.1, 0.5), 0.03, 0.7)
    m.add(whoosh(rng, 0.3, 700.0, 2400.0, 0.2, 1.2, -2.0, 2.0), 0.03, 0.3)
    m.add(bubbles(rng, 0.55, 40.0, 500.0, 1800.0, 0.12), 0.1, 0.25)
    m.add(thump(rng, 130.0, 55.0, 0.3, 0.07, 0.02, 1.4, 0.2), 0.02, 0.3)
    m.add(hiss(rng, 0.5, 2500.0, 9000.0, 0.005, 0.05, 0.5, (4200.0, 6800.0), 5.0, 0.7), 0.06, 0.16)
    return st(c, sat(m.render(), 1.2), "yard", 0.14)


# ====================================================================== 地图事件
def flap(rng, dur, rate=9.0):
    """帆布与布面被风掀起时的低频扑动。"""
    n = ns(dur)
    x = bp(white(n, rng), 180.0, 1400.0)
    g = 0.35 + 0.65 * np.abs(np.sin(np.pi * rate * tt(n)))
    return x * g * ahr(n, 0.06, dur * 0.3, dur * 0.55)


@sfx("supply_drop_land", n=2, target=-13.0, dur=2.6, fout=0.2)
def supply_drop_land(c):
    """补给舱落地：舱体砸进地面的低频闷响、金属框的短促余震、缓冲帆布的扑动与扬起的碎石。"""
    rng = c.rng
    v = c.v
    tune = [1.0, 0.94][v]
    m = Mix(2.6)
    m.add(thump(rng, 108.0 * tune, 32.0, 0.9, 0.22, 0.04, 2.8, 0.3), 0.0, 0.95)
    m.add(burst(rng, 0.5, 0.06, 40.0, 700.0, -3.0, 0.0008, 1.8), 0.0, 0.7)
    m.add(modal(rng, 196.0 * tune, HEAVY, 0.5, 1.4, 0.05, 0.8, 0.6), 0.01, 0.5)
    m.add(clank(rng, 430.0 * tune, 0.12, PLATE, 0.6, 0.6, 0.5, 5000.0), 0.02, 0.4)
    m.add(flap(rng, 1.0, 7.0), 0.08, 0.35)
    m.add(flap(rng, 0.7, 11.0), 0.4, 0.2)
    m.add(debris(rng, 1.4, 45.0, 0.45, 600.0, 5000.0, 0.35), 0.05, 0.3)
    m.add(tick(rng, 2200.0, 0.005, 0.04), 0.22, 0.25)
    x = sat(m.render(), 1.2)
    return st(c, x, "valley", 0.26)


@sfx("cargo_crash", n=1, target=-12.0, dur=3.4, fout=0.3)
def cargo_crash(c):
    """货柜砸地：柜体爆开的金属断裂、压缩空气的爆响、柜板与货物四散、远处墙体反射回来的长尾回声。"""
    rng = c.rng
    m = Mix(3.4)
    m.add(crack(rng, 0.09, 0.012, 900.0), 0.0, 0.6)
    m.add(thump(rng, 92.0, 28.0, 1.2, 0.3, 0.05, 3.0, 0.25), 0.0, 0.9)
    m.add(burst(rng, 0.7, 0.09, 35.0, 1600.0, -2.0, 0.0008, 2.2), 0.0, 0.85)
    for k in range(5):
        m.add(modal(rng, 120.0 + 90.0 * k, HEAVY, 0.5 + 0.2 * k, 1.6, 0.06, 0.8, 0.7), 0.004 * k, 0.28)
    m.add(debris(rng, 2.6, 55.0, 0.7, 400.0, 7000.0, 0.4), 0.04, 0.45)
    m.add(rattle(rng, 1.2, 35.0, 800.0, 4000.0, 0.35, 0.006), 0.1, 0.3)
    m.add(hiss(rng, 0.8, 2000.0, 10000.0, 0.003, 0.04, 0.5, (4500.0, 8000.0), 4.0, 0.6), 0.02, 0.2)
    x = sat(m.render(), 1.3)
    src = lp(x, 1200.0)
    for d, g in ((0.28, 0.2), (0.62, 0.12), (1.05, 0.06)):
        m.add(src, d, g)
    return st(c, m.render(), "valley", 0.34)


@sfx("distress_beacon", n=1, target=-16.0, dur=2.4, fout=0.15)
def distress_beacon(c):
    """求救信标：三段两升的电子哔声、每段之间的载波噪声与前级电流，尾音留着信标继续呼叫的空隙。"""
    rng = c.rng
    m = Mix(2.4)
    for k, t0 in enumerate((0.0, 0.72, 1.44)):
        f = 1180.0 if k % 2 == 0 else 980.0
        m.add(tone(f, 0.13, "square", 0.09, 0.004, bright=3600.0), t0, 0.5)
        m.add(tone(f * 1.5, 0.1, "square", 0.06, 0.004, bright=3600.0), t0 + 0.16, 0.3)
        m.add(tick(rng, 3000.0, 0.002, 0.02), t0, 0.2)
        m.add(hiss(rng, 0.18, 1500.0, 9000.0, 0.002, 0.02, 0.15, (3000.0, 6000.0), 3.0, 0.7), t0 + 0.05, 0.08)
    m.add(buzz(100.0, 2.2, None, 700.0) * env([(0, 0), (0.1, 0.5), (2.2, 0.3)], ns(2.2)), 0.0, 0.05)
    m.add(thump(rng, 90.0, 55.0, 0.3, 0.06, 0.02, 1.2, 0.05), 0.0, 0.1)
    return st(c, m.render(), "valley", 0.2)


@sfx("relay_unlock", n=1, target=-16.5, dur=1.2, fout=0.1)
def relay_unlock(c):
    """铅封箱开启：撬动时锁扣的一记脆响、弹簧片弹开的金属声、箱盖抬起的铰链摩擦与落定。"""
    rng = c.rng
    m = Mix(1.2)
    m.add(clank(rng, 900.0, 0.05, PLATE, 0.35, 0.8, 0.5, 7000.0), 0.0, 0.6)
    m.add(crack(rng, 0.04, 0.004, 2500.0), 0.0, 0.35)
    m.add(tick(rng, 3400.0, 0.004, 0.03), 0.06, 0.3)
    m.add(clank(rng, 520.0, 0.09, HEAVY, 0.5, 0.6, 0.6, 5000.0), 0.16, 0.45)
    m.add(servo(rng, 0.4, 260.0, 520.0, 0.25, 0.1, 9.0, 0.2, 4000.0), 0.22, 0.22)
    m.add(scrape(rng, 0.25, 900.0, 3600.0, 70.0, None, 30.0), 0.3, 0.18)
    m.add(thump(rng, 120.0, 70.0, 0.25, 0.05, 0.02, 1.2, 0.1), 0.7, 0.2)
    return st(c, sat(m.render(), 1.2), "hangar", 0.22)


@sfx("archive_pickup", n=1, target=-19.0, dur=1.0, fout=0.1)
def archive_pickup(c):
    """拾取档案：纸页被抽起时的摩擦与翻动、随后的两音轻提示，收在一声很轻的落纸声上。"""
    rng = c.rng
    m = Mix(1.0)
    n = ns(0.4)
    paper = bp(white(n, rng), 1800.0, 7000.0)
    flutter = 0.3 + 0.7 * np.abs(np.sin(np.pi * 17.0 * tt(n) + 0.7 * np.sin(2 * np.pi * 3.0 * tt(n))))
    m.add(paper * flutter * env([(0, 0), (0.05, 1.0), (0.4, 0.0)], n), 0.0, 0.5)
    m.add(tick(rng, 2400.0, 0.003, 0.02), 0.02, 0.2)
    m.add(tone(1420.0, 0.1, "sine", 0.05, 0.003), 0.26, 0.22)
    m.add(tone(1900.0, 0.14, "sine", 0.07, 0.003), 0.36, 0.16)
    m.add(chime(1900.0, 0.35, 0.12, ((1.0, 1.0), (2.0, 0.25))), 0.36, 0.12)
    m.add(burst(rng, 0.12, 0.02, 900.0, 5000.0, -2.0, 0.002), 0.66, 0.12)
    return st(c, m.render(), "ui", 0.14)


@sfx("sandstorm_start", n=1, target=-16.0, dur=4.0, fout=0.5)
def sandstorm_start(c):
    """沙暴逼近：从远处压过来的低频风墙、逐渐加密的砂粒击打、风里的呼啸层次一层层叠上来，最后稳定在持续的风压上。"""
    rng = c.rng
    n = ns(4.0)
    u = tt(n) / 4.0
    m = Mix(4.0)
    wall = roar(rng, n, 45.0, 900.0, 5.0, 0.55, -5.0) * np.clip(u / 0.7, 0, 1) ** 1.6
    m.add(wall, 0.0, 0.9)
    gust = whoosh(rng, 3.6, 200.0, 1400.0, 0.65, 1.0, -3.0, 2.4)
    m.add(gust, 0.1, 0.45)
    grit = bp(white(n, rng), 2500.0, 11000.0) * (0.2 + 0.8 * np.clip((u - 0.15) / 0.5, 0, 1)) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 3.7 * tt(n))))
    m.add(grit, 0.0, 0.3)
    m.add(roar(rng, n, 700.0, 4000.0, 12.0, 0.5, -3.0) * np.clip(u / 0.5, 0, 1), 0.0, 0.22)
    m.add(buzz(46.0, 4.0, None, 200.0) * np.clip(u / 0.6, 0, 1), 0.0, 0.1)
    return st(c, sat(m.render(), 1.15), "valley", 0.3)


@sfx("sandstorm_end", n=1, target=-18.0, dur=5.0, fout=0.8)
def sandstorm_end(c):
    """沙暴退去：风压从顶上一点点松开、砂粒击打变疏、最后只剩下风在远处拖着的一口气。"""
    rng = c.rng
    n = ns(5.0)
    u = tt(n) / 5.0
    m = Mix(5.0)
    wall = roar(rng, n, 40.0, 800.0, 4.0, 0.5, -5.0) * (1.0 - u) ** 1.8
    m.add(wall, 0.0, 0.85)
    m.add(whoosh(rng, 4.6, 1200.0, 260.0, 0.12, 1.0, -3.0, 2.0), 0.0, 0.4)
    grit = bp(white(n, rng), 2500.0, 11000.0) * (1.0 - u) ** 2.6 * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 4.3 * tt(n))))
    m.add(grit, 0.0, 0.28)
    m.add(roar(rng, n, 500.0, 3000.0, 10.0, 0.4, -3.0) * (1.0 - u) ** 2.0, 0.0, 0.2)
    return st(c, sat(m.render(), 1.1), "valley", 0.32)


@sfx("weather_rain_loop", n=1, target=-21.0, loop=6.0, reps=4)
def rain_loop(c):
    """阴雨环境：绵密的雨幕噪声、雨点打在不同材质上的细碎声、远处水流与偶尔的风阵，一遍 6 秒无缝。"""
    rng = c.rng
    n = c.total
    p = c.period
    m = Mix()
    bed = bp(white(n, rng), 900.0, 9000.0) * (0.7 + 0.3 * lfo_curve(rng, n, 0.6, p))
    m.add(bed, 0.0, 0.5)
    m.add(bp(white(n, rng), 3500.0, 12000.0), 0.0, 0.16)
    drops = np.zeros(p)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / 150.0)
        if t >= p / 44100.0:
            break
        place_local(drops, tick(rng, rng.uniform(1800.0, 6500.0), 0.0025, 0.02, 0.8), t, rng.uniform(0.15, 0.6))
    m.add(np.tile(drops, -(-n // p))[:n], 0.0, 0.35)
    water = roar(rng, n, 120.0, 700.0, 2.0, 0.35, -4.0, p)
    m.add(water, 0.0, 0.16)
    return st(c, sat(m.render(), 1.1), "valley", 0.25)


def lfo_curve(rng, n, rate, period):
    """以 period 为周期的慢速随机起伏，用于环境声的密度呼吸。"""
    from sfx_dsp import smooth_noise
    reps = -(-n // period)
    return np.tile(smooth_noise(period, rng, rate), reps)[:n]


def place_local(dst, x, at, gain=1.0):
    o = int(round(at * 44100))
    if o >= len(dst) or o < 0:
        return
    m = min(len(x), len(dst) - o)
    dst[o:o + m] += gain * x[:m]


# ====================================================================== 局外成长
def ui_room(x, c, wet=0.12):
    """界面类音效统一走小房间混响并保持立体声。"""
    return space(x, "ui", wet, True, c.v)


@sfx("grow_upgrade", n=1, target=-19.0, dur=1.4, fout=0.1)
def grow_upgrade(c):
    """设施升级完成：锁扣咬合的两记金属声、低频确认音垫底、收尾一声短促的液压泄压。"""
    rng = c.rng
    m = Mix(1.4)
    m.add(clank(rng, 980.0, 0.05, PLATE, 0.3, 0.8, 0.5, 7000.0), 0.0, 0.55)
    m.add(thump(rng, 120.0, 55.0, 0.5, 0.12, 0.03, 1.8, 0.2), 0.0, 0.45)
    m.add(clank(rng, 760.0, 0.04, PLATE, 0.25, 0.7, 0.4, 6500.0), 0.13, 0.4)
    m.add(tone(196.0, 0.6, "sine", 0.3, 0.006), 0.05, 0.22)
    m.add(tone(294.0, 0.5, "sine", 0.22, 0.006), 0.18, 0.14)
    m.add(hiss(rng, 0.25, 1200.0, 6000.0, 0.01, 0.05, 0.2, (2600.0, 4600.0), 4.0, 0.6), 0.42, 0.14)
    return ui_room(m.render(True), c, 0.16)


@sfx("grow_research", n=1, target=-19.0, dur=1.6, fout=0.1)
def grow_research(c):
    """研究完成：数据扫描的密集短音由低到高扫过、解析完成的一记清脆确认与消散的余响。"""
    rng = c.rng
    m = Mix(1.6)
    for k in range(9):
        t0 = 0.02 + 0.045 * k
        f = 900.0 * (1.09 ** k)
        m.add(tick(rng, f, 0.0025, 0.018), t0, 0.18 + 0.02 * k)
    m.add(hiss(rng, 0.45, 4000.0, 12000.0, 0.01, 0.1, 0.35, (6200.0, 9000.0), 5.0, 0.5), 0.02, 0.12)
    m.add(chime(1760.0, 0.7, 0.22, ((1.0, 1.0), (2.0, 0.3), (3.0, 0.12))), 0.46, 0.28)
    m.add(tone(880.0, 0.35, "sine", 0.12, 0.003), 0.46, 0.14)
    m.add(buzz(110.0, 0.9, None, 900.0) * env([(0, 0), (0.05, 0.6), (0.5, 0.3), (0.9, 0)], ns(0.9)), 0.0, 0.06)
    return ui_room(m.render(True), c, 0.14)


@sfx("grow_level", n=1, target=-19.0, dur=1.2, fout=0.1)
def grow_level(c):
    """驾驶员升级：一记干净的上扬双音，第二音带一点金属光泽，尾音短而不拖。"""
    rng = c.rng
    m = Mix(1.2)
    m.add(tone(660.0, 0.16, "sine", 0.08, 0.004), 0.0, 0.35)
    m.add(tone(990.0, 0.55, "sine", 0.24, 0.004), 0.12, 0.35)
    m.add(chime(990.0, 0.6, 0.2, ((1.0, 1.0), (2.0, 0.22), (3.01, 0.08))), 0.12, 0.2)
    m.add(tick(rng, 2800.0, 0.003, 0.02), 0.11, 0.18)
    return ui_room(m.render(True), c, 0.14)


@sfx("grow_affinity", n=1, target=-20.0, dur=1.8, fout=0.2)
def grow_affinity(c):
    """好感提升：柔和的三音上行，音色偏暖、起音软，尾音融在一起。"""
    rng = c.rng
    m = Mix(1.8)
    for k, (f, t0) in enumerate(((523.25, 0.0), (659.25, 0.22), (783.99, 0.46))):
        m.add(tone(f, 0.75, "sine", 0.45, 0.02), t0, 0.26 - 0.03 * k)
        m.add(tone(f * 2.0, 0.4, "sine", 0.2, 0.02), t0, 0.06)
    m.add(hiss(rng, 0.8, 3000.0, 9000.0, 0.06, 0.2, 0.6, (5000.0, 8000.0), 3.0, 0.4), 0.05, 0.05)
    return ui_room(m.render(True), c, 0.22)


@sfx("grow_gift", n=1, target=-20.0, dur=1.0, fout=0.1)
def grow_gift(c):
    """赠礼：纸盒被推开的窸窣、里面小金属件碰撞的两三声、盒盖合上的一记轻响。"""
    rng = c.rng
    n = ns(0.35)
    paper = bp(white(n, rng), 1200.0, 6500.0) * (0.4 + 0.6 * np.abs(np.sin(np.pi * 13.0 * tt(n))))
    m = Mix(1.0)
    m.add(paper * env([(0, 0), (0.04, 1.0), (0.35, 0)], n), 0.0, 0.35)
    m.add(tick(rng, 2200.0, 0.003, 0.03), 0.12, 0.2)
    for t0, f in ((0.22, 1600.0), (0.29, 2100.0), (0.37, 1450.0)):
        m.add(tick(rng, f, 0.006, 0.05, 0.5), t0, 0.3)
    m.add(clank(rng, 520.0, 0.04, PLATE, 0.2, 0.5, 0.3, 5000.0), 0.5, 0.25)
    m.add(burst(rng, 0.08, 0.015, 500.0, 3000.0, -2.0, 0.001), 0.5, 0.1)
    return ui_room(m.render(True), c, 0.12)


@sfx("grow_meal", n=1, target=-20.0, dur=1.5, fout=0.2)
def grow_meal(c):
    """烹制餐点：蒸汽阀放气的嘶声、锅具与瓷盘相碰的清脆声、汤液翻滚的细密气泡。"""
    rng = c.rng
    m = Mix(1.5)
    m.add(hiss(rng, 0.9, 1800.0, 9000.0, 0.05, 0.35, 0.5, (3200.0, 5600.0), 3.0, 0.4), 0.0, 0.4)
    m.add(clank(rng, 1450.0, 0.25, BELL, 0.7, 0.6, 0.3, 9000.0), 0.12, 0.32)
    m.add(clank(rng, 2100.0, 0.18, BELL, 0.5, 0.7, 0.2, 9000.0), 0.22, 0.2)
    m.add(bubbles(rng, 0.8, 22.0, 350.0, 1200.0, 0.1), 0.18, 0.22)
    m.add(burst(rng, 0.2, 0.03, 300.0, 1800.0, -2.0, 0.002), 0.5, 0.1)
    m.add(tick(rng, 3000.0, 0.004, 0.03), 0.7, 0.12)
    return ui_room(m.render(True), c, 0.16)


@sfx("grow_recover", n=1, target=-19.0, dur=1.8, fout=0.15)
def grow_recover(c):
    """医务室回收模块：液压夹爪合拢的两段驱动、模块落回架位的金属声、复位完成的两音提示。"""
    rng = c.rng
    m = Mix(1.8)
    m.add(hiss(rng, 0.35, 600.0, 4000.0, 0.01, 0.08, 0.2, (1400.0, 2600.0), 4.0, 0.5), 0.0, 0.25)
    m.add(servo(rng, 0.45, 260.0, 700.0, 0.3, 0.1, 9.0, 0.3, 5000.0), 0.05, 0.4)
    m.add(clank(rng, 480.0, 0.07, HEAVY, 0.4, 0.7, 0.5, 5000.0), 0.44, 0.5)
    m.add(thump(rng, 110.0, 50.0, 0.4, 0.1, 0.03, 1.6, 0.15), 0.44, 0.4)
    m.add(servo(rng, 0.3, 600.0, 900.0, 0.2, 0.08, 8.0, 0.2, 5000.0), 0.56, 0.2)
    m.add(tone(880.0, 0.12, "sine", 0.06, 0.004), 0.95, 0.22)
    m.add(tone(1320.0, 0.2, "sine", 0.09, 0.004), 1.08, 0.18)
    return ui_room(m.render(True), c, 0.18)


# ====================================================================== 剧情系统
@sfx("story_open", n=1, target=-20.0, dur=1.0, fout=0.12)
def story_open(c):
    """对话演出开始：低频展开的 whoosh 把人声压到后面，带一点金属余响的短尾，收在演出真正开始前的空隙。"""
    rng = c.rng
    m = Mix(1.0)
    m.add(whoosh(rng, 0.7, 120.0, 900.0, 0.55, 1.0, -4.0, 2.2), 0.0, 0.6)
    m.add(roar(rng, ns(0.7), 50.0, 300.0, 4.0, 0.4, -5.0) * env([(0, 0), (0.18, 1.0), (0.7, 0)], ns(0.7)), 0.0, 0.45)
    m.add(clank(rng, 320.0, 0.25, HEAVY, 0.8, 0.4, 0.4, 4000.0), 0.08, 0.18)
    m.add(tick(rng, 1800.0, 0.004, 0.03), 0.02, 0.1)
    m.add(buzz(74.0, 0.6, None, 300.0) * env([(0, 0), (0.1, 0.7), (0.6, 0)], ns(0.6)), 0.0, 0.1)
    return ui_room(m.render(True), c, 0.2)


@sfx("story_close", n=1, target=-21.0, dur=0.8, fout=0.15)
def story_close(c):
    """对话演出结束：一记收束的低频落点，量轻、不振，尾音快速收干，避免盖住回到局内的第一个操作反馈。"""
    rng = c.rng
    m = Mix(0.8)
    m.add(thump(rng, 150.0, 62.0, 0.42, 0.13, 0.03, 1.3, 0.12), 0.0, 0.5)
    m.add(tone(180.0, 0.3, "sine", 0.1, 0.006), 0.0, 0.2)
    m.add(whoosh(rng, 0.4, 900.0, 200.0, 0.2, 1.0, -4.0, 2.0), 0.0, 0.18)
    m.add(tick(rng, 1500.0, 0.004, 0.03), 0.02, 0.1)
    return ui_room(m.render(True), c, 0.1)


@sfx("story_text", n=1, target=-30.0, dur=0.06, fout=0.008)
def story_text(c):
    """逐字显示：极轻的一记电子点击，高频、极短，只够让文字出现时有触感。"""
    rng = c.rng
    m = Mix(0.06)
    m.add(tick(rng, 4200.0, 0.0018, 0.012, 0.35), 0.0, 0.5)
    m.add(tone(2600.0, 0.018, "sine", 0.006, 0.0005), 0.0, 0.2)
    return ui_room(m.render(True), c, 0.05)


@sfx("comm_open", n=2, target=-20.0, dur=0.7, fout=0.08)
def comm_open(c):
    """无线电小窗：发射键的咔哒、载波接通时的电流嘶声、一声短促的上行提示，收在静电尾音里。"""
    rng = c.rng
    v = c.v
    tune = [1.0, 0.92][v]
    m = Mix(0.7)
    m.add(tick(rng, 1600.0, 0.004, 0.03, 0.6), 0.0, 0.4)
    m.add(hiss(rng, 0.35, 900.0, 7000.0, 0.003, 0.03, 0.35, (2200.0, 4800.0), 3.0, 0.7), 0.03, 0.25)
    m.add(buzz(120.0, 0.3, None, 900.0) * env([(0, 0), (0.02, 0.8), (0.3, 0)], ns(0.3)), 0.02, 0.1)
    m.add(tone(1240.0 * tune, 0.09, "sine", 0.04, 0.003), 0.14, 0.22)
    m.add(tone(1560.0 * tune, 0.12, "sine", 0.05, 0.003), 0.24, 0.18)
    m.add(tick(rng, 2400.0, 0.003, 0.02), 0.42, 0.12)
    return ui_room(m.render(True), c, 0.12)

