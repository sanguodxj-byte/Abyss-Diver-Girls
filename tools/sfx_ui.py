"""
界面、机库、商店与委托的音效配方：界面音短促干净、音量克制，机库音带机库空间的混响。
"""
import numpy as np
from sfx_dsp import (sfx, SR, ns, tt, white, pink, brown, lp, hp, bp, peak, sweep, sine, harm, saw_amps, expdec, ad,
                     env, ahr, sat, space, Mix)
from sfx_lib import (place, norm, att, thump, crack, burst, modal, clank, tick, rattle, scrape, servo, hiss, whoosh,
                     tone, chime, buzz, PLATE, BAR, HEAVY, BELL)


def noise_tick(rng, lo=3500.0, hi=12000.0, tau=0.0015, dur=0.02):
    n = ns(dur)
    return att(norm(bp(white(n, rng), lo, hi)) * expdec(n, tau), 0.0003)


def airy(rng, dur, f0, f1, peak_t=0.7):
    """界面开合的气流声：很轻的扫频带通噪声。"""
    return whoosh(rng, dur, f0, f1, peak_t, 2.0, -1.5)


# ---------------------------------------------------------------- 通用界面
@sfx("ui_click", n=2, target=-29.0, dur=0.12, fout=0.015)
def ui_click(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(noise_tick(rng, 3500.0, 12000.0, 0.0012), 0.0, 0.5)
    m.add(tone([2400.0, 2150.0][v], 0.03, "sine", 0.009), 0.0, 0.6)
    m.add(tone([1200.0, 1080.0][v], 0.035, "sine", 0.01), 0.0, 0.3)
    return space(m.render(c.stereo), "ui", 0.15, c.stereo, v)


@sfx("ui_hover", n=1, target=-28.0, dur=0.08, fout=0.012)
def ui_hover(c):
    m = Mix()
    m.add(tone(3200.0, 0.025, "sine", 0.007), 0.0, 0.7)
    m.add(tone(4800.0, 0.02, "sine", 0.005), 0.0, 0.2)
    return space(m.render(c.stereo), "ui", 0.12, c.stereo, 0)


@sfx("ui_confirm", n=1, target=-21.0, dur=0.45, fout=0.05)
def ui_confirm(c):
    rng = c.rng
    m = Mix()
    m.add(noise_tick(rng, 3000.0, 11000.0, 0.0015), 0.0, 0.4)
    m.add(tone(880.0, 0.07, "tri", 0.03, bright=8000.0), 0.0, 0.55)
    m.add(tone(1318.5, 0.16, "tri", 0.07, bright=8000.0), 0.075, 0.55)
    m.add(tone(2637.0, 0.12, "sine", 0.05), 0.08, 0.12)
    return space(m.render(c.stereo), "ui", 0.2, c.stereo, 0)


@sfx("ui_cancel", n=1, target=-22.0, dur=0.35, fout=0.04)
def ui_cancel(c):
    rng = c.rng
    m = Mix()
    m.add(noise_tick(rng, 2500.0, 9000.0, 0.0015), 0.0, 0.35)
    m.add(tone(987.8, 0.06, "tri", 0.025, bright=7000.0), 0.0, 0.55)
    m.add(tone(659.3, 0.12, "tri", 0.05, bright=7000.0), 0.065, 0.55)
    return space(m.render(c.stereo), "ui", 0.18, c.stereo, 0)


@sfx("ui_tab", n=1, target=-29.0, dur=0.12, fout=0.015)
def ui_tab(c):
    rng = c.rng
    n = ns(0.05)
    m = Mix()
    sl = sweep(white(n, rng), "bp", np.geomspace(2500.0, 6000.0, n), 1.5) * ahr(n, 0.005, 0.02, 0.025)
    m.add(norm(sl), 0.0, 0.35)
    m.add(noise_tick(rng, 3000.0, 10000.0, 0.0012), 0.035, 0.5)
    m.add(tone(1760.0, 0.03, "sine", 0.008), 0.035, 0.45)
    return space(m.render(c.stereo), "ui", 0.15, c.stereo, 0)


@sfx("ui_open", n=1, target=-22.0, dur=0.4, fout=0.05)
def ui_open(c):
    """面板是瞬间出现的，所以咔嗒与第一个音在 0 秒，随后上行的第二个音与轻气流表现「展开」。"""
    rng = c.rng
    m = Mix()
    m.add(noise_tick(rng, 3000.0, 11000.0, 0.0015), 0.0, 0.4)
    m.add(tone(1174.7, 0.07, "sine", 0.03), 0.0, 0.4)
    m.add(tone(1568.0, 0.12, "sine", 0.05), 0.055, 0.4)
    m.add(tone(2349.3, 0.1, "sine", 0.04), 0.07, 0.15)
    m.add(airy(rng, 0.16, 900.0, 4500.0, 0.3), 0.0, 0.3)
    return space(m.render(c.stereo), "ui", 0.2, c.stereo, 0)


@sfx("ui_close", n=1, target=-22.5, dur=0.35, fout=0.04)
def ui_close(c):
    """面板是瞬间关闭的，咔嗒在 0 秒，随后下行的音与轻气流表现「收起」。"""
    rng = c.rng
    m = Mix()
    m.add(noise_tick(rng, 2500.0, 9000.0, 0.0015), 0.0, 0.4)
    m.add(tone(1396.9, 0.06, "sine", 0.025), 0.0, 0.35)
    m.add(tone(1046.5, 0.09, "sine", 0.035), 0.05, 0.4)
    m.add(airy(rng, 0.14, 4000.0, 800.0, 0.25), 0.0, 0.3)
    return space(m.render(c.stereo), "ui", 0.18, c.stereo, 0)


@sfx("ui_denied", n=1, target=-22.0, dur=0.3, fout=0.03)
def ui_denied(c):
    rng = c.rng
    m = Mix()
    m.add(noise_tick(rng, 1500.0, 6000.0, 0.002), 0.0, 0.3)
    m.add(buzz(185.0, 0.22, (2, 0.55), 1300.0), 0.0, 0.8)
    m.add(tone(370.0, 0.2, "tri", 0.08, bright=2500.0), 0.0, 0.2)
    return space(m.render(c.stereo), "ui", 0.15, c.stereo, 0)


# ---------------------------------------------------------------- 机库（换装：分离后约 0.45 秒新模块到位并播放对接声）
@sfx("hub_detach", n=1, target=-18.5, dur=0.9, fout=0.12)
def hub_detach(c):
    rng = c.rng
    m = Mix()
    m.add(clank(rng, 760.0, 0.05, PLATE, 0.3, 0.8, 0.5), 0.0, 0.8, -0.2)
    m.add(tick(rng, 3400.0, 0.004, 0.03), 0.03, 0.35, 0.2)
    m.add(hiss(rng, 0.35, 1500.0, 9000.0, 0.004, 0.05, 0.25, (3000.0, 5600.0), 4.0, 0.5), 0.04, 0.4, 0.3)
    m.add(servo(rng, 0.4, 620.0, 300.0, 0.35, 0.03, 5.0, 0.2), 0.08, 0.3, -0.3)
    return space(m.render(c.stereo), "hangar", 0.2, c.stereo, 0)


@sfx("hub_dock", n=2, target=-17.5, dur=1.0, fout=0.12)
def hub_dock(c):
    rng = c.rng
    v = c.v
    m = Mix()
    m.add(clank(rng, [520.0, 580.0][v], 0.07, HEAVY, 0.4, 0.8, 0.8), 0.0, 0.9)
    m.add(thump(rng, [130.0, 140.0][v], 60.0, 0.25, 0.05, 0.02, 1.6, 0.3), 0.0, 0.6)
    m.add(clank(rng, [1150.0, 1250.0][v], 0.03, PLATE, 0.15, 0.8, 0.3), 0.055, 0.5, 0.2)
    m.add(hiss(rng, 0.3, 2000.0, 9000.0, 0.01, 0.04, 0.2, (3500.0, 6000.0), 4.0, 0.4), 0.1, 0.25, -0.3)
    m.add(servo(rng, 0.3, 420.0, 300.0, 0.25, 0.04, 5.0, 0.15), 0.12, 0.15, 0.3)
    return space(m.render(c.stereo), "hangar", 0.22, c.stereo, v)


@sfx("hub_explode", n=1, target=-18.0, dur=1.5, fout=0.2)
def hub_explode(c):
    rng = c.rng
    m = Mix(1.5)
    for k, pn in enumerate([-0.6, 0.6, -0.2, 0.3, 0.0]):
        t0 = 0.05 * k + c.r(0.0, 0.015)
        m.add(clank(rng, c.r(700.0, 1100.0), 0.035, PLATE, 0.2, 0.8, 0.4), t0, 0.5, pn)
        m.add(servo(rng, 0.5, c.r(380.0, 450.0), c.r(800.0, 950.0), 0.15, 0.2, 5.0, 0.2), t0 + 0.04, 0.12, pn)
    m.add(hiss(rng, 0.6, 1500.0, 9000.0, 0.01, 0.1, 0.4, (3000.0, 5600.0), 4.0, 0.5), 0.05, 0.3)
    m.add(airy(rng, 0.7, 400.0, 2500.0, 0.4), 0.1, 0.25)
    return space(m.render(c.stereo), "hangar", 0.22, c.stereo, 0)


@sfx("hub_assemble", n=1, target=-17.5, dur=1.5, fout=0.2)
def hub_assemble(c):
    rng = c.rng
    m = Mix(1.5)
    m.add(airy(rng, 0.6, 2500.0, 400.0, 0.6), 0.0, 0.25)
    for k, pn in enumerate([0.6, -0.6, 0.2, -0.3, 0.0]):
        m.add(servo(rng, 0.45, c.r(800.0, 950.0), c.r(380.0, 450.0), 0.3, 0.05, 5.0, 0.2), 0.05 * k, 0.12, pn)
        m.add(clank(rng, c.r(600.0, 900.0), 0.04, HEAVY, 0.25, 0.8, 0.5), 0.42 + 0.055 * k, 0.55, pn)
    m.add(thump(rng, 120.0, 55.0, 0.3, 0.07, 0.02, 1.6, 0.2), 0.68, 0.6)
    m.add(hiss(rng, 0.4, 2000.0, 9000.0, 0.01, 0.05, 0.3, (3500.0, 6000.0), 4.0, 0.4), 0.72, 0.25)
    return space(m.render(c.stereo), "hangar", 0.22, c.stereo, 0)


@sfx("hub_starter", n=1, target=-16.5, dur=2.4, fout=0.3)
def hub_starter(c):
    rng = c.rng
    m = Mix(2.4)
    m.add(rattle(rng, 1.0, 50.0, 900.0, 3000.0, 2.0, 0.01), 0.0, 0.4, -0.3)
    m.add(servo(rng, 1.0, 140.0, 260.0, 0.3, 0.3, 4.0, 0.25, 2500.0), 0.0, 0.35, 0.2)
    m.add(hiss(rng, 0.8, 1200.0, 7000.0, 0.2, 0.3, 0.3, (2400.0, 4400.0), 4.0), 0.3, 0.15)
    m.add(clank(rng, 260.0, 0.12, HEAVY, 0.8, 0.6, 0.9), 1.05, 0.9)
    m.add(thump(rng, 95.0, 38.0, 0.5, 0.13, 0.03, 2.2, 0.4), 1.05, 0.8)
    m.add(rattle(rng, 0.4, 70.0, 1200.0, 4000.0, 0.12), 1.08, 0.3, 0.3)
    m.add(clank(rng, 1250.0, 0.025, PLATE, 0.12, 0.8, 0.3), 1.5, 0.4, -0.2)
    m.add(hiss(rng, 0.5, 1500.0, 9000.0, 0.005, 0.08, 0.35, (3000.0, 5600.0), 4.0, 0.5), 1.52, 0.4, 0.2)
    return space(m.render(c.stereo), "hangar", 0.25, c.stereo, 0)


@sfx("cargo_load", n=1, target=-19.5, dur=0.6, fout=0.06)
def cargo_load(c):
    rng = c.rng
    m = Mix()
    m.add(scrape(rng, 0.18, 300.0, 2500.0, 40.0, None), 0.0, 0.35, -0.3)
    m.add(thump(rng, 170.0, 90.0, 0.2, 0.04, 0.015, 1.4, 0.3), 0.15, 0.45, 0.2)
    m.add(clank(rng, 620.0, 0.03, PLATE, 0.15, 0.6, 0.6), 0.15, 0.6, 0.2)
    return space(m.render(c.stereo), "hangar", 0.15, c.stereo, 0)


@sfx("cargo_unload", n=1, target=-19.5, dur=0.6, fout=0.06)
def cargo_unload(c):
    rng = c.rng
    m = Mix()
    m.add(thump(rng, 200.0, 120.0, 0.12, 0.025, 0.01, 1.0, 0.3), 0.0, 0.4, 0.2)
    m.add(scrape(rng, 0.18, 300.0, 2500.0, 40.0, None), 0.04, 0.35, 0.3)
    m.add(thump(rng, 150.0, 85.0, 0.2, 0.045, 0.015, 1.4, 0.3), 0.21, 0.4, -0.2)
    m.add(clank(rng, 560.0, 0.03, PLATE, 0.15, 0.6, 0.6), 0.21, 0.55, -0.2)
    return space(m.render(c.stereo), "hangar", 0.15, c.stereo, 0)


# ---------------------------------------------------------------- 商店与委托
@sfx("shop_buy", n=1, target=-19.0, dur=0.8, fout=0.1)
def shop_buy(c):
    rng = c.rng
    m = Mix()
    m.add(tick(rng, 4200.0, 0.003, 0.02), 0.0, 0.3)
    m.add(tone(1760.0, 0.05, "sine", 0.02), 0.0, 0.35)
    m.add(chime(1568.0, 0.5, 0.18, ((1.0, 1.0), (2.0, 0.3), (2.76, 0.12))), 0.06, 0.45, -0.2)
    m.add(chime(2093.0, 0.55, 0.2, ((1.0, 1.0), (2.0, 0.3), (2.76, 0.12))), 0.13, 0.45, 0.2)
    m.add(modal(rng, 3600.0, BAR, 0.05, 0.2, 0.01, 0.8, 0.6), 0.13, 0.12)
    return space(m.render(c.stereo), "hangar", 0.12, c.stereo, 0)


@sfx("shop_sell", n=2, target=-19.0, dur=0.9, fout=0.1)
def shop_sell(c):
    rng = c.rng
    v = c.v
    m = Mix()
    count = [3, 5][v]
    for k in range(count):
        t0 = 0.05 * k + c.r(0.0, 0.02)
        m.add(modal(rng, c.r(3000.0, 4200.0), BAR, 0.06, 0.25, 0.02, 0.8, 0.6), t0, 0.4 * (0.85 ** k), c.r(-0.4, 0.4))
        m.add(tick(rng, c.r(5000.0, 7000.0), 0.002, 0.015), t0, 0.15)
    m.add(chime([1318.5, 1174.7][v], 0.45, 0.18), 0.05 * count + 0.04, 0.4)
    m.add(chime([1975.5, 1760.0][v], 0.5, 0.2), 0.05 * count + 0.1, 0.35)
    return space(m.render(c.stereo), "hangar", 0.12, c.stereo, v)


@sfx("request_complete", n=1, target=-18.0, dur=1.6, fout=0.25)
def request_complete(c):
    rng = c.rng
    m = Mix(1.6)
    for k, f in enumerate([523.3, 659.3, 784.0, 1046.5]):
        m.add(chime(f, 1.0, 0.4, ((1.0, 1.0), (2.0, 0.35), (3.0, 0.12), (4.2, 0.05))), 0.07 * k, 0.4, -0.3 + 0.2 * k)
    m.add(thump(rng, 160.0, 80.0, 0.2, 0.04, 0.015, 1.4, 0.4), 0.4, 0.6)
    m.add(burst(rng, 0.06, 0.012, 1200.0, 6000.0, -3.0, 0.002), 0.4, 0.3)
    n = ns(1.2)
    pad = sum(np.sin(2 * np.pi * f * tt(n)) for f in (261.6, 262.4, 392.0))
    m.add(norm(pad) * env([(0, 0), (0.3, 1.0), (1.2, 0.0)], n), 0.1, 0.15)
    return space(m.render(c.stereo), "hangar", 0.18, c.stereo, 0)
