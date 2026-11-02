"""
音效积木：撞击、金属共振、机械、气流、电子提示音、燃烧与涡轮、虫族发声等可复用的声音成分。
每个函数返回单声道 float64 数组（幅度归一到 ±1 左右），由配方再做混音与空间处理。
带 period 参数的积木用于循环音效：噪声与随机调制以 period 个采样为周期重复，所以平铺后接缝连续。
"""
import numpy as np
from sfx_dsp import (SR, ns, tt, colored, white, pink, brown, smooth_noise, lp, hp, bp, peak, reson, sweep,
                     phase, sine, harm, saw_amps, square_amps, tri_amps, pulse_amps, expdec, ad, env, ahr,
                     sat, crush, _curve)


def place(dst, src_, at, gain=1.0):
    o = int(round(at * SR))
    if o >= len(dst) or o < 0:
        return dst
    m = min(len(src_), len(dst) - o)
    dst[o:o + m] += gain * src_[:m]
    return dst


def norm(x, to=1.0):
    m = np.max(np.abs(x)) if len(x) else 0.0
    return x * (to / m) if m > 0 else x


def att(x, sec=0.0008):
    """起音处的极短升余弦，避免首采样跳变。"""
    m = min(len(x), max(2, ns(sec)))
    y = x.copy()
    y[:m] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(m) / (m - 1))
    return y


def src(rng, n, slope=0.0, period=None):
    """噪声源；给出 period 时以 period 为周期重复。"""
    if not period:
        return colored(n, rng, slope)
    reps = -(-n // period)
    return np.tile(colored(period, rng, slope), reps)[:n]


def lfo(rng, n, rate, period=None):
    """平滑随机调制曲线（约 -1..1）；给出 period 时以 period 为周期重复。"""
    if not period:
        return smooth_noise(n, rng, rate)
    reps = -(-n // period)
    return np.tile(smooth_noise(period, rng, rate), reps)[:n]


# ---------------------------------------------------------------- 撞击
def thump(rng, f0=120.0, f1=45.0, dur=0.4, tau=0.12, sweep_t=0.05, drive=1.5, click=0.3):
    """低频冲击：正弦从 f0 指数滑到 f1（时间常数 sweep_t），振幅按 tau 衰减，drive 加饱和，click 为起音噪声比例。"""
    n = ns(dur)
    t = tt(n)
    f = f1 + (f0 - f1) * np.exp(-t / sweep_t)
    x = sine(f) * expdec(n, tau)
    if drive:
        x = sat(x, drive)
    if click:
        x = x + click * lp(white(n, rng), 3000.0) * expdec(n, 0.004)
    return att(norm(x))


def crack(rng, dur=0.08, tau=0.012, lo=1500.0, hi=None, slope=0.0):
    """尖锐的噪声瞬态（破空、碎裂的起音）。"""
    n = ns(dur)
    x = hp(colored(n, rng, slope), lo, 2)
    if hi:
        x = lp(x, hi, 2)
    return att(norm(x) * expdec(n, tau), 0.0003)


def burst(rng, dur, tau, lo, hi, slope=-3.0, attack=0.001, drive=0.0):
    """带通噪声猝发：attack 秒起音后按 tau 衰减。"""
    n = ns(dur)
    x = norm(bp(colored(n, rng, slope), lo, hi, 2)) * ad(n, attack, tau)
    return sat(x, drive) if drive else x


# ---------------------------------------------------------------- 金属与机械
PLATE = [1.0, 1.59, 2.14, 2.30, 2.65, 2.92, 3.50, 4.15, 4.8, 5.4]
BAR = [1.0, 2.756, 5.404, 8.933, 13.34]
TUBE = [1.0, 2.01, 2.98, 4.03, 5.1, 6.0]
BELL = [0.56, 0.92, 1.19, 1.71, 2.0, 2.74, 3.0, 3.76, 4.07]
HEAVY = [1.0, 1.47, 1.93, 2.44, 3.1, 3.62, 4.4]


def modal(rng, f0, ratios=PLATE, tau=0.25, dur=None, spread=0.03, tilt=0.7, decay_tilt=0.6, amps=None):
    """模态合成的金属共振：各模态频率 = f0 × ratio（随机偏差 spread），高阶模态幅度按 tilt、衰减时间按 decay_tilt 递减。"""
    dur = dur or min(4.0, tau * 6.0)
    n = ns(dur)
    t = tt(n)
    out = np.zeros(n)
    for i, rt in enumerate(ratios):
        f = f0 * rt * (1.0 + rng.uniform(-spread, spread))
        if f >= SR * 0.45:
            continue
        a = (amps[i] if amps is not None and i < len(amps) else 1.0 / (1.0 + i) ** tilt) * rng.uniform(0.6, 1.0)
        out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)) * np.exp(-t / (tau / rt ** decay_tilt))
    return att(norm(out), 0.0006)


def clank(rng, f0=600.0, tau=0.12, ratios=PLATE, dur=None, hit=0.5, body=0.5, bright=6000.0):
    """金属件撞击：敲击噪声 + 模态共振 + 半频的短促体感。"""
    m = modal(rng, f0, ratios, tau, dur)
    n = len(m)
    h = norm(lp(hp(white(n, rng), 800.0), bright)) * expdec(n, 0.003)
    b = sine(np.full(n, f0 * 0.5)) * expdec(n, 0.025)
    return att(norm(m + hit * h + body * b), 0.0004)


def tick(rng, f=3000.0, tau=0.006, dur=0.04, noise=0.5):
    """细小的金属或塑料咔嗒。"""
    n = ns(dur)
    t = tt(n)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
    x = x + noise * norm(hp(white(n, rng), f * 0.5)) * np.exp(-t / (tau * 0.4))
    return att(norm(x), 0.0003)


def rattle(rng, dur=0.3, rate=60.0, f_lo=1500.0, f_hi=5000.0, tau=0.08, tick_tau=0.004):
    """松动零件的哗啦声：泊松分布的细小金属敲击，整体按 tau 衰减。"""
    n = ns(dur)
    out = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= dur:
            break
        a = np.exp(-t / tau) * rng.uniform(0.3, 1.0)
        place(out, tick(rng, rng.uniform(f_lo, f_hi), tick_tau * rng.uniform(0.6, 1.5), 0.03, 0.6), t, a)
    return norm(out)


def scrape(rng, dur=0.5, lo=800.0, hi=4000.0, grit=40.0, modes=None, q=30.0, env_pts=None):
    """金属刮擦：带通噪声乘上粘滑颗粒感的调制，再激励几条高 Q 共振，形成尖啸；env_pts 为 (秒, 值) 包络。"""
    n = ns(dur)
    x = bp(white(n, rng), lo, hi)
    g = np.abs(smooth_noise(n, rng, grit)) ** 1.5
    x = x * (0.3 + 3.0 * g)
    if modes:
        x = 0.5 * norm(x) + 2.0 * norm(sum(reson(x, f, q) for f in modes))
    e = env(env_pts, n) if env_pts else ahr(n, 0.02, dur * 0.6, dur * 0.35)
    return norm(x) * e


def servo(rng, dur=0.5, f_lo=300.0, f_hi=900.0, up=0.25, down=0.2, gear=7.0, buzz_amt=0.3, bright=4500.0):
    """伺服电机：基频在 up 秒内从 f_lo 升到 f_hi、最后 down 秒回落，叠加齿轮转动的调幅与电刷噪声。"""
    n = ns(dur)
    t = tt(n)
    k = np.clip(t / max(up, 1e-3), 0, 1)
    kd = np.clip((dur - t) / max(down, 1e-3), 0, 1)
    f = f_lo + (f_hi - f_lo) * (k * k * (3 - 2 * k)) * (kd * kd * (3 - 2 * kd))
    x = harm(f, [1.0, 0.5, 0.35, 0.2, 0.12, 0.08])
    x = x * (1.0 + 0.25 * np.sin(2 * np.pi * phase(f / gear)))
    br = bp(white(n, rng), 2000.0, 7000.0) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * phase(f * 0.5))))
    x = norm(x) + buzz_amt * norm(br)
    return norm(lp(x, bright)) * ahr(n, 0.015, max(0.0, dur - 0.075), 0.06)


def hiss(rng, dur=0.5, lo=2000.0, hi=10000.0, a=0.005, h=0.05, r=0.3, peaks=(3500.0, 6200.0), q=4.0, fall=0.0):
    """气动嘶声：高频带通噪声 + 阀门共振峰；fall 为 0..1，上限频率随压力下降按比例降低。"""
    n = ns(dur)
    x = bp(white(n, rng), lo, hi)
    for f in peaks:
        x = peak(x, f, q, 6.0)
    if fall:
        x = sweep(x, "lp", np.geomspace(hi, max(hi * (1.0 - fall), 200.0), n), 0.7)
    return norm(x) * ahr(n, a, h, r)


def whoosh(rng, dur=0.5, f0=400.0, f1=3000.0, peak_t=0.6, q=1.5, slope=-3.0, shape=2.0):
    """掠过声：带通中心频率从 f0 滑到 f1，振幅在 dur × peak_t 处最大。"""
    n = ns(dur)
    u = tt(n) / dur
    pt = float(np.clip(peak_t, 0.02, 0.98))
    x = sweep(colored(n, rng, slope), "bp", f0 * (f1 / f0) ** u, q)
    e = np.where(u < pt, (u / pt) ** shape, np.clip((1 - u) / (1 - pt), 0, 1) ** (shape * 0.7))
    return norm(x) * e


def debris(rng, dur=1.5, rate=40.0, tau=0.5, f_lo=600.0, f_hi=5000.0, heavy=0.3):
    """碎屑落地：泊松分布的小撞击（石块与金属片），密度按 tau 衰减；heavy 为较重碎块的比例。"""
    n = ns(dur)
    out = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= dur - 0.08:
            break
        dens = np.exp(-t / tau)
        if rng.random() > dens:
            continue
        a = rng.uniform(0.2, 1.0) * (0.4 + 0.6 * dens)
        u = rng.random()
        if u < heavy:
            g = burst(rng, 0.08, rng.uniform(0.01, 0.03), 150.0, 1500.0, -3.0)
        elif u < heavy + (1 - heavy) * 0.5:
            g = tick(rng, rng.uniform(f_lo, f_hi), rng.uniform(0.003, 0.02), 0.06, 0.4)
        else:
            g = burst(rng, 0.03, rng.uniform(0.002, 0.006), f_lo, min(f_hi * 1.5, 16000.0), 0.0)
        place(out, g, t, a)
    return norm(out)


# ---------------------------------------------------------------- 电子提示音
def tone(f, dur, wave="sine", tau=None, a=0.002, vib=0.0, vib_rate=6.0, bright=8000.0):
    """提示音：f 为常数或曲线；wave 为 sine / tri / square / saw / pulse；tau 为空时用余弦释放，否则指数衰减。"""
    n = ns(dur)
    fr = _curve(f, n)
    if vib:
        fr = fr * (1.0 + vib * np.sin(2 * np.pi * vib_rate * tt(n)))
    if wave == "sine":
        x = sine(fr)
    elif wave == "tri":
        x = harm(fr, tri_amps(15))
    elif wave == "square":
        x = harm(fr, square_amps(21))
    elif wave == "saw":
        x = harm(fr, saw_amps(24))
    else:
        x = harm(fr, pulse_amps(24, 0.25))
    if wave != "sine":
        x = lp(x, bright)
    e = ad(n, a, tau) if tau else ahr(n, a, max(0.0, dur * 0.4 - a), dur * 0.6)
    return norm(x) * e


def chime(f, dur=0.6, tau=0.25, partials=((1.0, 1.0), (2.0, 0.35), (3.01, 0.15), (4.2, 0.08)), a=0.002):
    """铃音：几条按比例的分音，高分音衰减更快。"""
    n = ns(dur)
    t = tt(n)
    x = np.zeros(n)
    for r, g in partials:
        if f * r < SR * 0.45:
            x += g * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (tau / max(r, 1.0) ** 0.5))
    if a > 0:
        x *= np.clip(t / a, 0, 1)
    return norm(x)


# ---------------------------------------------------------------- 燃烧、涡轮、引擎
def roar(rng, n, lo=80.0, hi=2500.0, turb=14.0, depth=0.5, slope=-3.0, period=None):
    """燃烧与喷流的轰鸣：带通噪声乘以湍流般的随机调幅。"""
    x = norm(bp(src(rng, n, slope, period), lo, hi))
    m = 1.0 + depth * lfo(rng, n, turb, period) + 0.5 * depth * lfo(rng, n, turb * 3.0, period)
    return x * np.maximum(m, 0.05)


def crackle(rng, n, rate=25.0, lo=1500.0, hi=7000.0, period=None):
    """燃烧的噼啪声：泊松分布的细小爆裂；给出 period 时事件以 period 为周期重复。"""
    span = period or n
    pulses = np.zeros(span)
    t = 0.0
    dur = span / SR
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= dur:
            break
        pulses[int(t * SR)] += rng.uniform(0.2, 1.0) * (1.0 if rng.random() > 0.5 else -1.0) * rng.uniform(0.3, 1.0) ** 2
    if period:
        pulses = np.tile(pulses, -(-n // period))[:n]
    x = bp(pulses, lo, hi, 2)
    x = x + 0.4 * bp(pulses, lo * 0.4, lo, 1)
    return norm(x)


def turbine(rng, n, f_rot, blades=11, whine=0.4, roar_amt=0.6, lo=60.0, hi=6000.0, period=None):
    """涡轮：转子低频谐波 + 叶片通过频率的啸叫（f_rot × blades）+ 气流噪声；f_rot 为常数或曲线。"""
    fr = _curve(f_rot, n)
    x = 0.6 * harm(fr, [1.0, 0.6, 0.4, 0.25, 0.15])
    w = harm(fr * blades, [1.0, 0.3, 0.12])
    w *= 1.0 + 0.15 * lfo(rng, n, 3.0, period)
    a = roar(rng, n, lo, hi, 6.0, 0.25, -3.0, period)
    return norm(norm(x) * 0.7 + whine * norm(w) + roar_amt * norm(a))


def engine(rng, n, f, cyl_jit=0.25, bright=500.0, rough=0.5, period=None):
    """往复式引擎：每个点火周期一次衰减脉冲，脉冲强弱随机（cyl_jit），低通后叠加谐波与排气噪声；
    给出 period 时 f 必须是常数且已按周期量化，点火强弱以 period 为周期重复。"""
    fr = _curve(f, n)
    ph = phase(fr)
    cyc = np.floor(ph).astype(np.int64)
    if period:
        cpp = max(1, int(round(float(fr[0]) * period / SR)))
        jit = 1.0 + cyl_jit * rng.uniform(-1, 1, cpp)
        amp = jit[cyc % cpp]
    else:
        jit = 1.0 + cyl_jit * rng.uniform(-1, 1, int(cyc.max()) + 2)
        amp = jit[cyc]
    frac = ph - cyc
    pul = amp * np.exp(-frac * 6.0)
    x = lp(pul - np.mean(pul), bright, 2)
    x = norm(x) + 0.5 * norm(harm(fr, saw_amps(12, 1.2)))
    exh = norm(lp(src(rng, n, -3.0, period), bright * 1.5)) * (0.4 + 0.6 * pul / max(pul.max(), 1e-9))
    return norm(lp(x + rough * exh, bright * 2.0))


def fold(x, period):
    """把超过 period 的部分叠回开头，得到以 period 为周期、接缝连续的一遍。"""
    y = np.zeros(period)
    for k in range(0, len(x), period):
        seg = x[k:k + period]
        y[:len(seg)] += seg
    return y


# ---------------------------------------------------------------- 虫族发声
def voice(rng, dur, pts, jit=0.02, flutter=(0.0, 30.0), rough=0.3, rough_rate=70.0,
          formants=((2500.0, 5.0), (4500.0, 6.0)), breath=0.3, wave="pulse", duty=0.18, drive=1.5, sub=0.0,
          env_pts=None, hpf=150.0):
    """虫族的嘶鸣与吼叫：脉冲波声源沿音高曲线 pts（(时间比例 0..1, Hz) 列表）发声，叠加音高抖动 jit、
    颤音 flutter = (深度, Hz)、粗糙调幅 rough 与气声 breath，经共振峰塑形与饱和；sub 为低八度成分（大型虫族的胸腔共鸣）；
    env_pts 为 (秒, 值) 振幅包络。"""
    n = ns(dur)
    u = tt(n) / dur
    f = np.interp(u, [p[0] for p in pts], [p[1] for p in pts])
    f = f * (1.0 + jit * smooth_noise(n, rng, 25.0))
    fd, fr = flutter
    if fd:
        f = f * (1.0 + fd * np.sin(2 * np.pi * phase(fr * (1.0 + 0.2 * smooth_noise(n, rng, 3.0)))))
    nh = int(min(60, max(4, SR * 0.4 / max(f.min(), 50.0))))
    x = harm(f, pulse_amps(nh, duty) if wave == "pulse" else saw_amps(nh, 1.0))
    if sub:
        x = norm(x) + sub * norm(harm(f * 0.5, saw_amps(60, 1.3)))
    x = norm(x)
    if rough:
        x = x * (1.0 - rough + rough * np.abs(smooth_noise(n, rng, rough_rate)) * 2.2)
    if breath:
        x = x + breath * norm(bp(white(n, rng), 1500.0, 9000.0)) * (0.5 + 0.5 * np.abs(smooth_noise(n, rng, 40.0)))
    y = 0.25 * x
    for fc, q in formants:
        y = y + reson(x, fc, q)
    y = norm(hp(y, hpf))
    if drive:
        y = sat(y, drive)
    e = env(env_pts, n) if env_pts else ahr(n, min(0.03, dur * 0.15), dur * 0.45, dur * 0.4)
    return norm(y) * e


def chitter(rng, dur=0.3, rate=35.0, f=(2500.0, 5000.0), tau=0.003, swing=0.3, env_pts=None, period=None):
    """口器的咔嗒连击：间隔围绕 1/rate 抖动 swing 的短促共振脉冲；给出 period 时 dur 为输出总长、点击以 period 为周期重复。"""
    span = period if period else ns(dur)
    out = np.zeros(span + ns(0.05))
    t = rng.uniform(0, 1.0 / rate)
    lim = span / SR - (0.0 if period else 0.02)
    while t < lim:
        place(out, tick(rng, rng.uniform(*f), tau * rng.uniform(0.7, 1.4), 0.02, 0.7), t, rng.uniform(0.5, 1.0))
        t += (1.0 / rate) * (1.0 + swing * rng.uniform(-1, 1))
    if period:
        return norm(np.tile(fold(out, period), -(-ns(dur) // period))[:ns(dur)])
    out = out[:span]
    e = env(env_pts, span) if env_pts else 1.0
    return norm(out) * e


def bubble(rng, f, tau=None, rise=0.1):
    """单个气泡：频率随衰减上扬的正弦。"""
    tau = tau or max(0.004, 6.0 / f)
    n = ns(tau * 6.0)
    t = tt(n)
    x = np.sin(2 * np.pi * phase(f * (1.0 + rise * t / tau))) * np.exp(-t / tau)
    return att(x, 0.0005)


def bubbles(rng, dur=0.5, rate=30.0, f_lo=300.0, f_hi=1500.0, rise=0.1, env_pts=None, period=None):
    """一串气泡（咕嘟、酸液翻滚）：泊松分布，频率对数均匀；给出 period 时 dur 为输出总长、气泡以 period 为周期重复。"""
    span = period if period else ns(dur)
    out = np.zeros(span + ns(0.15))
    t = 0.0
    lim = span / SR - (0.0 if period else 0.03)
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= lim:
            break
        f = float(np.exp(rng.uniform(np.log(f_lo), np.log(f_hi))))
        place(out, bubble(rng, f, None, rise), t, rng.uniform(0.3, 1.0) * (f_lo / f) ** 0.3)
    if period:
        return norm(np.tile(fold(out, period), -(-ns(dur) // period))[:ns(dur)])
    out = out[:span]
    e = env(env_pts, span) if env_pts else 1.0
    return norm(out) * e


def slime(rng, dur=0.25, f0=3000.0, f1=300.0, q=2.0, tau=0.08, low=0.4):
    """湿黏的吧唧声：带通中心频率快速下滑的噪声 + 低频湿重成分。"""
    n = ns(dur)
    t = tt(n)
    x = sweep(white(n, rng), "bp", f1 + (f0 - f1) * np.exp(-t / (dur * 0.25)), q)
    x = norm(x) + low * norm(lp(brown(n, rng), 400.0))
    return att(norm(x) * expdec(n, tau), 0.001)


def crunch(rng, dur=0.15, grains=40, spread=0.05, lo=1200.0, hi=9000.0, body=0.4, body_f=400.0):
    """甲壳碎裂：短时间内密集的碎裂颗粒 + 一记沉闷的壳体声。"""
    n = ns(dur)
    out = np.zeros(n)
    for _ in range(grains):
        t0 = abs(rng.normal(0, spread * 0.5))
        if t0 > dur - 0.02:
            continue
        g = burst(rng, 0.015, rng.uniform(0.0008, 0.003), rng.uniform(lo, lo * 2), hi, 0.0)
        place(out, g, t0, rng.uniform(0.3, 1.0) * np.exp(-t0 / spread))
    b = burst(rng, dur, 0.03, body_f * 0.5, body_f * 2.0, -3.0)
    return att(norm(norm(out) + body * b), 0.0004)


def bug_hiss(rng, dur=0.5, lo=2500.0, hi=9000.0, peaks=(3800.0, 6500.0), tremble=(0.5, 45.0), env_pts=None):
    """虫族的嘶嘶声：高频带通噪声 + 共振峰，tremble = (深度, Hz) 为气门颤动。"""
    n = ns(dur)
    x = bp(white(n, rng), lo, hi)
    for f in peaks:
        x = peak(x, f, 5.0, 8.0)
    d, r = tremble
    if d:
        x = x * (1.0 - d + d * (0.5 + 0.5 * np.sin(2 * np.pi * phase(r * (1.0 + 0.3 * smooth_noise(n, rng, 4.0))))))
    e = env(env_pts, n) if env_pts else ahr(n, 0.04, dur * 0.4, dur * 0.5)
    return norm(x) * e


def scrabble(rng, dur=0.5, rate=45.0, env_pts=None):
    """爪子刨土：短促的沙土摩擦 + 小石子。"""
    n = ns(dur)
    out = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= dur - 0.06:
            break
        if rng.random() < 0.7:
            g = burst(rng, 0.05, rng.uniform(0.006, 0.02), rng.uniform(300, 900), rng.uniform(2000, 6000), -3.0, 0.002)
        else:
            g = tick(rng, rng.uniform(1500, 4500), rng.uniform(0.002, 0.006), 0.03, 0.8)
        place(out, g, t, rng.uniform(0.3, 1.0))
    e = env(env_pts, n) if env_pts else ahr(n, 0.03, dur * 0.5, dur * 0.4)
    return norm(out) * e


# ---------------------------------------------------------------- 电气
def arc(rng, dur=0.4, density=600.0, lo=2500.0, hum=0.3, burstiness=0.7, bits=7):
    """电弧：密集的随机放电脉冲 + 断续的爆发感 + 工频嗡声，轻度位深压缩带出电子毛刺。"""
    n = ns(dur)
    p = np.zeros(n)
    k = int(rng.poisson(density * dur))
    p[rng.integers(0, n, k)] = rng.uniform(-1, 1, k)
    x = norm(hp(p, lo, 2) + 0.5 * bp(p, 800.0, 2500.0))
    g = np.clip(0.5 + smooth_noise(n, rng, 18.0) * 1.2, 0.0, 1.0) ** 1.5
    x = x * ((1 - burstiness) + burstiness * g)
    if hum:
        x = x + hum * norm(harm(np.full(n, 120.0), saw_amps(20))) * (0.6 + 0.4 * g)
    return norm(crush(norm(x), bits))


def buzz(f, dur, gate=None, bright=1800.0, wave="square"):
    """电子拒绝音：低通方波；gate = (段数, 占空比) 时分成几段短促的嗡声，段落边缘平滑。"""
    n = ns(dur)
    x = lp(harm(np.full(n, f), square_amps(31) if wave == "square" else saw_amps(31)), bright)
    if gate:
        cnt, duty = gate
        u = tt(n) / dur * cnt
        fr = u - np.floor(u)
        x = x / (1.0 + np.exp(-(fr - 0.03) * 150.0)) / (1.0 + np.exp(-(duty - fr) * 150.0))
    return norm(x) * ahr(n, 0.003, dur - 0.03, 0.025)
