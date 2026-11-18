"""
音效合成的物理材质与声学原语库（AC6 / Helldivers 2 写实重工业与生物声学重制版）：
彻底摒弃早期 16-bit 电子振荡器、空心塑料管高Q谐振与周期性锯齿脉冲蜂鸣，全部音效建立在四大真实物理声学机制之上：
  1. 宽带瞬态冲击与相位锁定低频压力波（火药爆轰N波、重型装甲冲击、地面踏步震波、碎石散落）
  2. 强阻尼厚重钢板/复合材料多模态碰撞（低Q高阻尼，浑厚扎实，无空心管/木琴敲击感）
  3. 流体与气动湍流（高压液压油流、喷管气动剪切、涡扇宽带气流、酸液沸腾与黏液飞溅）
  4. 非周期生物声门颗粒簇与湿腔共振峰（不规则喉部肉质震颤+胸腔低频共鸣，零锯齿波合成器感）
"""
import numpy as np
from sfx_dsp import (SR, ns, tt, white, pink, brown, colored, smooth_noise, lp, hp, bp, peak, reson, sweep,
                     phase, sine, expdec, ad, env, ahr, sat, asym, fold)


def place(dst, src, at=0.0, gain=1.0):
    """把一维信号 src 加到 dst 的 at 秒处（原地修改并返回 dst），超出末尾的部分截断。"""
    o = int(round(at * SR))
    if o >= len(dst) or o < 0:
        return dst
    m = min(len(src), len(dst) - o)
    dst[o:o + m] += gain * src[:m]
    return dst


def norm(x):
    m = np.max(np.abs(x))
    return x / m if m > 0 else x


def att(x, sec=0.001):
    """只对前 sec 秒做半余弦淡入，抹掉首采样的阶跃，不碰起音之后的瞬态。"""
    m = min(len(x), max(2, ns(sec)))
    y = x.copy()
    y[:m] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(m) / (m - 1))
    return y


# ---- 循环无缝原语：period 不为 None 时先合成一遍再平铺，或把长事件按周期折叠后再平铺
def src(rng, n, slope=0.0, period=None):
    if period:
        return np.tile(colored(period, rng, slope), -(-n // period))[:n]
    return colored(n, rng, slope)


def lfo(rng, n, rate, period=None):
    if period:
        return np.tile(smooth_noise(period, rng, rate), -(-n // period))[:n]
    return smooth_noise(n, rng, rate)


def fold_tile(x, period, n):
    y = np.zeros(period)
    for k in range(0, len(x), period):
        s = x[k:k + period]
        y[:len(s)] += s
    return np.tile(y, -(-n // period))[:n]


# ---------------------------------------------------------------- 冲击、爆轰与宽带瞬态
def _orig_thump(rng, f0=110.0, f1=32.0, dur=0.22, tau=0.06, sweep_t=0.04, drive=2.2, click=0.35):
    """重型物理冲击（凝聚低频压力波 + 中低频结实躯干冲击 + 清晰表面接触瞬态）：
    扎实有力、层次分明，避免纯超低频浑浊轰鸣与刺耳高频毛刺。"""
    n = ns(dur)
    t = tt(n)
    f0_j = float(max(85.0, f0)) * rng.uniform(0.93, 1.07)
    f1_j = float(max(36.0, f1)) * rng.uniform(0.94, 1.06)
    sw_t = max(float(sweep_t), 0.012)
    tau_s = min(max(float(tau) * 0.72, 0.010), 0.046)
    f_inst = np.clip(f1_j + (f0_j - f1_j) * np.exp(-t / sw_t), 32.0, 320.0)
    ph_jitter = 0.22 * smooth_noise(n, rng, 32.0)
    ph = phase(f_inst, n) + ph_jitter + rng.uniform(0.0, 0.18)
    sub_wave = (np.sin(2.0 * np.pi * ph) + 0.35 * np.sin(4.0 * np.pi * ph)) * np.exp(-t / tau_s)
    raw = 0.78 * pink(n, rng) + 0.22 * white(n, rng)
    body_punch = bp(raw, max(105.0, f1_j * 2.1), min(860.0, max(360.0, f0_j * 3.8)), 2) * np.exp(-t / max(0.008, tau_s * 0.65))
    y = asym(0.52 * norm(sub_wave) + 0.62 * norm(body_punch), min(drive, 2.1), 0.10)
    if click:
        c_sig = bp(0.25 * white(n, rng) + 0.75 * pink(n, rng), 280.0, 2400.0, 2) * np.exp(-t / 0.0028)
        y = y + min(0.55, max(0.25, float(click))) * 0.58 * norm(c_sig)
    return att(norm(lp(y, 3800.0, 2)), 0.0003)


def _orig_crack(rng, dur=0.04, tau=0.005, lo=650.0, hi=9500.0, bi=0.0005):
    """超音速激波/硬物脆裂瞬态：双极性 N 波激波头 + 温润受控中高频脆裂。"""
    n = ns(dur)
    t = tt(n)
    n_wave = np.where(t < bi, 1.0 - 2.0 * (t / max(bi, 1e-5)), -np.exp(-(t - bi) / (bi * 1.8)))
    n_wave *= np.exp(-t / (bi * 2.4))
    lo_c = max(220.0, min(900.0, lo * 0.55))
    hi_c = min(3600.0, max(lo_c * 2.2, hi * 0.42))
    tau_eff = min(float(tau), 0.0045)
    body_hi = bp(0.24 * white(n, rng) + 0.76 * pink(n, rng), lo_c, hi_c, 2) * np.exp(-t / tau_eff)
    body_mid = bp(0.65 * pink(n, rng) + 0.35 * brown(n, rng), max(160.0, lo_c * 0.52), max(980.0, lo_c * 1.9), 2) * np.exp(-t / max(0.006, tau_eff * 1.8))
    y = 0.42 * n_wave + 0.52 * norm(body_hi) + 0.62 * norm(body_mid)
    return att(lp(asym(norm(y), 1.65, 0.08), 3800.0, 2), 0.0002)


def burst(rng, dur=0.18, tau=0.025, lo=80.0, hi=5500.0, slope=-2.0, a=0.0005, drive=1.8):
    """宽带爆轰/冲击簇。"""
    n = ns(dur)
    x = colored(n, rng, min(max(slope, -3.2), -2.0))
    lo_f = max(90.0, min(1400.0, lo))
    hi_f = min(3800.0, max(lo_f * 1.6, hi * 0.68))
    x = bp(x, lo_f, hi_f, 2) * ad(n, a, tau)
    return asym(norm(lp(x, 4000.0, 2)), min(drive, 1.85), 0.10)


# ---------------------------------------------------------------- 厚重装甲与实心钢构件碰撞（真实阻尼金属模态，清脆扎实，零空心塑料管/闷响）
PLATE = [1.0, 1.37, 1.83, 2.39, 3.04, 3.82]
BAR = [1.0, 1.52, 2.18, 2.94, 3.78]
TUBE = [1.0, 1.41, 1.93, 2.56, 3.28]
BELL = [1.0, 1.34, 1.76, 2.28, 2.89, 3.58]
HEAVY = [1.0, 1.29, 1.67, 2.14, 2.68, 3.31]


def _orig_modal(rng, f0, ratios, tau=0.1, dur=None, amp_decay=0.78, detune=0.025, bright=4800.0):
    """高密度实心合金/机械构件阻尼冲击共鸣：
    由短促宽带碰撞冲量激励快衰减金属非谐模态，厚重扎实、杜绝高频正弦刺耳长鸣。"""
    dur = dur or min(0.45, max(0.05, tau * 3.2))
    n = ns(dur)
    t = tt(n)
    f_base = float(np.clip(f0 * rng.uniform(0.95, 1.05), 140.0, 920.0))
    tau_eff = min(float(tau), 0.060)
    bright_cap = min(3200.0, float(bright) * 0.68)
    imp_src = 0.25 * white(n, rng) + 0.75 * pink(n, rng)
    exc_hit = bp(imp_src, max(200.0, f_base * 0.55), min(3400.0, bright_cap), 2) * np.exp(-t / max(0.0020, min(0.006, tau_eff * 0.14)))
    y = np.zeros(n)
    exc_modal = bp(imp_src, max(160.0, f_base * 0.50), min(3000.0, bright_cap * 0.92), 2) * np.exp(-t / max(0.0035, min(0.010, tau_eff * 0.22)))
    for i, r in enumerate(ratios[:5]):
        f = f_base * r * rng.uniform(1.0 - detune, 1.0 + detune)
        if f >= min(bright_cap * 1.05, 2600.0):
            break
        tk = max(0.0035, min(0.032, tau_eff * (0.36 / (r ** 0.78)) * rng.uniform(0.88, 1.12)))
        q = float(np.clip(2.6 + 0.45 * i, 2.6, 4.4))
        m_res = reson(exc_modal, f, q) * np.exp(-t / tk)
        f_env = f * (1.0 + 0.016 * np.exp(-t / 0.0025))
        m_ping = np.sin(2.0 * np.pi * phase(f_env, n) + rng.uniform(0.0, 6.28)) * np.exp(-t / (tk * 0.68))
        ping_w = 0.14 if f < 1600.0 else 0.05
        y += (amp_decay ** i) * ((1.0 - ping_w) * norm(m_res) + ping_w * m_ping)
    mid_body = bp(0.65 * pink(n, rng) + 0.35 * brown(n, rng), max(130.0, f_base * 0.42), min(920.0, f_base * 1.85), 2) * np.exp(-t / max(0.007, tau_eff * 0.36))
    out = 0.56 * norm(y) + 0.38 * norm(exc_hit) + 0.42 * norm(mid_body)
    return att(norm(lp(asym(out, 1.32, 0.06), 3600.0, 2)), 0.0002)


def _orig_clank(rng, f0, tau=0.055, ratios=PLATE, dur=None, hit=0.7, body=0.65, bright=4500.0):
    """精密机械钢件咬合/枪机闭锁/装甲卡榫碰撞：双点金属咬合瞬态 + 实心钢体阻尼模态。"""
    dur = dur or min(0.38, max(0.05, tau * 3.6))
    n = ns(dur)
    t = tt(n)
    f_c = float(np.clip(f0 * rng.uniform(0.94, 1.06), 160.0, 780.0))
    tau_c = min(float(tau), 0.055)
    m_body = _orig_modal(rng, f_c, ratios, tau_c, dur, 0.72, 0.025, min(bright * 0.72, 3200.0))
    snap1 = bp(0.28 * white(n, rng) + 0.72 * pink(n, rng), max(280.0, f_c * 0.75), min(3300.0, bright * 0.68), 2) * np.exp(-t / 0.0030)
    dly_s = int(round(rng.uniform(0.0040, 0.0095) * SR))
    snap2 = np.zeros(n)
    if dly_s < n - 8:
        s_len = n - dly_s
        snap2[dly_s:] = bp(0.26 * white(s_len, rng) + 0.74 * pink(s_len, rng), max(340.0, f_c * 0.90), min(3000.0, bright * 0.62), 2) * np.exp(-tt(s_len) / 0.0035) * 0.46
    weight = bp(0.65 * pink(n, rng) + 0.35 * brown(n, rng), 110.0, min(580.0, f_c * 1.45), 2) * np.exp(-t / max(0.010, tau_c * 0.45))
    y = 0.56 * m_body + hit * 0.55 * norm(snap1 + snap2) + max(0.40, body) * 0.42 * norm(weight)
    return att(norm(lp(asym(y, 1.35, 0.08), 3600.0, 2)), 0.0002)


def _orig_tick(rng, f=2200.0, tau=0.003, dur=0.028, noise=0.55):
    """精密战术微动开关/棘轮清脆触点：温润中高频弹片瞬态 + 铝合金壳体阻尼底座（无刺耳高频鸣响）。"""
    n = ns(dur)
    t = tt(n)
    f_t = float(np.clip(f * rng.uniform(0.95, 1.05), 520.0, 1950.0))
    tau_t = min(max(0.0012, float(tau)), 0.0050)
    imp = bp(0.28 * white(n, rng) + 0.72 * pink(n, rng), max(420.0, f_t * 0.48), min(3200.0, f_t * 1.65), 2) * np.exp(-t / max(0.0007, tau_t * 0.45))
    f_leaf = f_t * (1.0 + 0.025 * np.exp(-t / 0.0012))
    leaf = (np.sin(2.0 * np.pi * phase(f_leaf, n)) + 0.22 * np.sin(2.0 * np.pi * phase(f_leaf * 1.48, n))) * np.exp(-t / max(0.0012, tau_t * 0.65))
    body_t = reson(imp, f_t * 0.68, 2.8) * np.exp(-t / max(0.0018, tau_t * 1.10))
    housing = bp(0.70 * pink(n, rng) + 0.30 * brown(n, rng), 180.0, 980.0, 2) * np.exp(-t / max(0.0024, tau_t * 1.40))
    y = 0.54 * norm(imp) + (1.0 - noise * 0.45) * 0.38 * norm(0.68 * norm(body_t) + 0.32 * leaf) + 0.42 * norm(housing)
    return att(norm(lp(hp(y, 140.0, 2), 3600.0, 2)), 0.00015)


# ---------------------------------------------------------------- 机械运动、液压驱动、摩擦
def _orig_servo(rng, dur=0.25, f_lo=260.0, f_hi=520.0, up=0.1, down=0.08, grit=6.0, noise_amt=0.35):
    """精密液压作动筒与阻尼传动：中频高压油路滑移 + 细密滚珠轴承颗粒，干净利落。"""
    n = ns(dur)
    t = tt(n)
    f0 = float(np.clip(f_lo * 0.85, 160.0, 680.0))
    f1 = float(np.clip(f_hi * 0.85, 180.0, 880.0))
    if dur <= up + down:
        up, down = dur * 0.45, dur * 0.35
    hold = max(0.0, dur - up - down)
    f_curve = env([(0, f0), (up, f1), (up + hold, f1), (dur, (f0 + f1) * 0.52)], n)
    f_curve *= 1.0 + 0.04 * smooth_noise(n, rng, 18.0)
    fluid = sweep(0.65 * white(n, rng) + 0.35 * pink(n, rng), "bp", np.clip(f_curve * 1.65, 240.0, 2400.0), 1.55)
    low_load = sweep(pink(n, rng), "bp", np.clip(f_curve * 0.75, 140.0, 520.0), 1.25)
    k_g = max(10, int(dur * 260.0))
    idx = rng.integers(0, n, k_g)
    vel = np.zeros(n)
    vel[idx] = rng.choice([-1.0, 1.0], k_g) * rng.uniform(0.35, 1.0, k_g)
    bearing = sweep(vel, "bp", np.clip(f_curve * 2.8, 420.0, 3200.0), 1.8)
    e = ahr(n, min(0.010, max(0.002, up * 0.22)), max(0.0, dur - 0.025), min(0.016, max(0.004, down * 0.32)))
    y = (0.58 * norm(fluid) + 0.24 * norm(low_load) + noise_amt * 0.62 * norm(bearing)) * e
    return att(norm(asym(y, 1.35, 0.06)) * 0.72, 0.0004)


def rattle(rng, dur=0.25, rate=55.0, f_lo=1200.0, f_hi=4200.0, tau=0.09, tick_tau=0.0025):
    """弹链、金属扣件、散落弹壳的机械碰撞簇。"""
    n = ns(dur)
    out = np.zeros(n)
    t = 0.0
    f_l = max(240.0, f_lo * 0.42)
    f_h = min(2200.0, f_hi * 0.50)
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= dur - 0.02:
            break
        a = np.exp(-t / tau) * rng.uniform(0.35, 1.0)
        tk = _orig_tick(rng, rng.uniform(f_l, f_h), tick_tau * rng.uniform(0.8, 1.3), 0.024, 0.68)
        place(out, tk, t, a)
    return norm(out)


def scrape(rng, dur=0.22, lo=600.0, hi=4200.0, rough=45.0, modes=None, q=18.0):
    """厚重钢轨与金属构件滑动摩擦。"""
    n = ns(dur)
    raw = 0.55 * pink(n, rng) + 0.45 * brown(n, rng)
    x = bp(raw, max(160.0, lo * 0.45), min(3000.0, hi * 0.62), 2)
    g = np.clip(0.55 + 0.45 * smooth_noise(n, rng, rough), 0.12, 1.0) ** 1.35
    x = x * g
    if modes:
        m = sum(reson(x, min(2000.0, f * 0.58), min(q * 0.22, 2.8)) for f in modes)
        x = 0.72 * norm(x) + 0.28 * norm(m)
    return norm(lp(asym(x, 1.40, 0.08), 3200.0, 2)) * ahr(n, 0.01, max(0.0, dur - 0.04), 0.03)


# ---------------------------------------------------------------- 喷气、呼啸、爆裂碎片
def _orig_hiss(rng, dur=0.3, lo=1200.0, hi=9000.0, a=0.004, h=0.06, r=0.2, peaks=(2400.0, 5200.0), q=3.5, fall=0.0):
    """高压气体喷射/泄压阀气流：自然宽带气体湍流，无窄带尖啸与高频白噪嘶声。"""
    n = ns(dur)
    t = tt(n)
    raw = 0.75 * pink(n, rng) + 0.25 * brown(n, rng)
    lo_f = max(200.0, min(950.0, lo * 0.42))
    hi_f = min(3400.0, max(lo_f * 1.9, hi * 0.45))
    x = bp(raw, lo_f, hi_f, 2)
    for f in peaks:
        f_p = min(2400.0, f * 0.52)
        if fall:
            fc = f_p * (1.0 - min(fall, 0.55) * (t / dur))
            x = x + 0.28 * sweep(raw, "bp", np.clip(fc, 180.0, 2600.0), min(q * 0.45, 1.6))
        else:
            x = peak(x, f_p, min(q * 0.45, 1.5), 1.5)
    low_air = bp(brown(n, rng), 90.0, 480.0, 2)
    x = 0.70 * norm(x) + 0.42 * norm(low_air)
    turb = 1.0 + 0.18 * smooth_noise(n, rng, 28.0)
    return norm(lp(x * turb, 3600.0, 2)) * ahr(n, a, h, max(0.01, dur - a - h if r is None else r))


def _orig_whoosh(rng, dur=0.35, f0=220.0, f1=1800.0, peak_t=0.35, q=1.2, slope=-2.5, shape=1.6):
    """高速破空与重物挥动气浪。"""
    n = ns(dur)
    t = tt(n)
    u = t / dur
    pt = float(np.clip(peak_t, 0.08, 0.92))
    f_curve = f0 * (f1 / max(f0, 20.0)) ** u
    src_n = colored(n, rng, min(slope, -2.2))
    x = sweep(src_n, "bp", np.clip(f_curve, 45.0, 7200.0), min(q, 1.6))
    low_air = sweep(brown(n, rng), "bp", np.clip(f_curve * 0.35, 35.0, 680.0), 0.85)
    turb = 1.0 + 0.25 * smooth_noise(n, rng, 18.0)
    e = np.where(u < pt, (u / pt) ** shape, np.clip((1 - u) / (1 - pt), 0, 1) ** (shape * 0.7))
    return norm((0.72 * norm(x) + 0.45 * norm(low_air)) * turb) * e


def debris(rng, dur=1.5, rate=42.0, tau=0.5, f_lo=550.0, f_hi=4800.0, heavy=0.35):
    """战场弹片、碎混凝土与砂石散落。"""
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
        a = rng.uniform(0.28, 1.0) * (0.4 + 0.6 * dens)
        u = rng.random()
        if u < heavy:
            g = _orig_thump(rng, rng.uniform(95.0, 180.0), rng.uniform(36.0, 68.0), 0.08, rng.uniform(0.014, 0.028), 0.006, 1.7, 0.42)
        elif u < heavy + (1 - heavy) * 0.55:
            g = _orig_clank(rng, rng.uniform(max(280.0, f_lo * 0.55), min(2600.0, f_hi * 0.65)), rng.uniform(0.008, 0.020), PLATE, 0.06, 0.7, 0.55)
        else:
            g = burst(rng, 0.030, rng.uniform(0.003, 0.008), max(200.0, f_lo * 0.5), min(f_hi * 0.95, 8500.0), -2.4)
        place(out, g, t, a)
    return norm(out)


# ---------------------------------------------------------------- 战术驾驶舱物理继电器与闭锁模块（零电子音阶）
def tone(f, dur, wave="sine", tau=None, a=0.001, vib=0.0, vib_rate=6.0, bright=3200.0):
    """战术座舱电磁继电器闭锁脉冲：由微动触点冲击激励强阻尼底座，干脆利落。"""
    n = ns(dur)
    fr_raw = np.full(n, float(f)) if np.ndim(f) == 0 else np.asarray(f, float)
    f_box = float(np.clip(np.mean(fr_raw) * 0.32, 130.0, 480.0))
    seed = int(float(np.mean(fr_raw)) * 19 + n) & 0x7FFFFFFF
    rng_t = np.random.default_rng(seed)
    sw1 = _orig_tick(rng_t, f_box * 3.8, 0.0020, min(dur, 0.028), 0.68)
    box = _orig_clank(rng_t, f_box, min(0.022, dur * 0.30), PLATE, dur, 0.72, 0.72, min(bright, 3200.0))
    out = np.zeros(n)
    place(out, sw1, 0.0, 0.75)
    place(out, box[:n], 0.0, 0.65)
    return att(norm(out), 0.0002)


def chime(f, dur=0.5, tau=0.18, partials=((1.0, 1.0), (2.0, 0.35)), a=0.001):
    """重型战术插销双段咬合确认。"""
    n = ns(dur)
    fr_raw = np.full(n, float(f)) if np.ndim(f) == 0 else np.asarray(f, float)
    f_latch = float(np.clip(np.mean(fr_raw) * 0.30, 145.0, 520.0))
    seed = int(float(np.mean(fr_raw)) * 23 + n) & 0x7FFFFFFF
    rng_c = np.random.default_rng(seed)
    c1 = _orig_clank(rng_c, f_latch, 0.028, HEAVY, min(dur, 0.16), 0.82, 0.78, 3600.0)
    c2 = _orig_tick(rng_c, f_latch * 4.0, 0.0022, min(dur, 0.032), 0.68)
    th = _orig_thump(rng_c, f_latch * 0.82, 44.0, min(dur, 0.15), 0.028, 0.008, 1.8, 0.42)
    out = np.zeros(n)
    place(out, c1, 0.0, 0.75)
    place(out, th, 0.0, 0.68)
    if dur > 0.025:
        place(out, c2, min(0.012, dur * 0.25), 0.55)
    return att(norm(out), 0.0002)


# ---------------------------------------------------------------- 燃烧、涡轮、重型内燃机
def _orig_roar(rng, n, lo=75.0, hi=2400.0, turb=15.0, depth=0.55, slope=-3.2, period=None):
    """重工业燃烧与高压喷流轰鸣。"""
    raw = src(rng, n, slope - 0.5, period)
    x = norm(bp(raw, max(28.0, lo * 0.72), min(9500.0, hi), 2))
    sub = norm(lp(src(rng, n, -5.2, period), max(80.0, min(220.0, lo * 1.65))))
    m = 1.0 + depth * lfo(rng, n, turb, period) + 0.52 * depth * lfo(rng, n, turb * 2.7, period)
    y = (0.74 * x + 0.40 * sub) * np.maximum(m, 0.10)
    return asym(y, 1.45, 0.10)


def crackle(rng, n, rate=28.0, lo=1400.0, hi=6800.0, period=None):
    """高温爆燃/电弧爆裂颗粒簇。"""
    span = period or n
    pulses = np.zeros(span)
    t = 0.0
    dur = span / SR
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= dur:
            break
        pulses[int(t * SR)] += rng.uniform(0.3, 1.0) * (1.0 if rng.random() > 0.45 else -1.0) * rng.uniform(0.35, 1.0) ** 1.6
    if period:
        pulses = np.tile(pulses, -(-n // period))[:n]
    x = bp(pulses, max(320.0, min(950.0, lo * 0.45)), min(3200.0, hi * 0.55), 2)
    x = x + 0.72 * bp(pulses, max(120.0, lo * 0.18), max(480.0, lo * 0.58), 1)
    return norm(lp(asym(x, 1.4, 0.08), 3400.0, 2))


def _orig_turbine(rng, n, f_rot, blades=11, whine=0.35, roar_amt=0.65, lo=55.0, hi=5500.0, period=None):
    """重型燃气涡扇/动力核心：
    深沉燃烧室压气轰鸣 + 宽带气动剪切扫频，兼具动力厚度与高亢气流清晰度。"""
    fr = np.full(n, float(f_rot)) if np.ndim(f_rot) == 0 else np.asarray(f_rot, float)
    if len(fr) != n:
        fr = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(fr)), fr)
    fr = np.clip(fr, 28.0, 260.0)
    core_rumble = bp(src(rng, n, -3.5, period), 55.0, 280.0, 2) * (1.0 + 0.30 * lfo(rng, n, 6.5, period))
    f_air = np.clip(fr * 3.2, 220.0, 1800.0)
    air_shear = sweep(src(rng, n, -2.2, period), "bp", f_air, 1.45) * (1.0 + 0.22 * lfo(rng, n, 12.0, period))
    a = _orig_roar(rng, n, max(95.0, lo), min(hi, 2800.0), 8.5, 0.38, -2.5, period)
    return norm(lp(0.42 * norm(core_rumble) + max(0.28, whine) * 0.58 * norm(air_shear) + roar_amt * 0.85 * norm(a), 3200.0, 2))


def engine(rng, n, f, cyl_jit=0.28, bright=480.0, rough=0.55, period=None):
    """重型多缸柴油/燃气动力炉：采用宽带气缸爆燃脉冲簇替代硬周期脉冲。"""
    fr = np.full(n, float(f)) if np.ndim(f) == 0 else np.asarray(f, float)
    if len(fr) != n:
        fr = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(fr)), fr)
    f_mean = float(np.clip(np.mean(fr), 28.0, 120.0))
    sub = bp(src(rng, n, -3.8, period), 45.0, min(260.0, f_mean * 3.2), 2)
    chug_mod = 0.50 + 0.50 * np.sin(2.0 * np.pi * phase(fr * 0.5, n) + 0.35 * lfo(rng, n, 8.0, period))
    exh = bp(src(rng, n, -2.2, period), 120.0, min(2200.0, bright * 2.6), 2) * chug_mod
    return norm(asym(0.45 * norm(sub) + (0.65 + 0.35 * rough) * norm(exh), 1.50, 0.08))


# ---------------------------------------------------------------- 异虫生物发声腔体与甲壳物理材质（零锯齿波/方波合成器感）
def _orig_voice(rng, dur, pts, jit=0.03, flutter=(0.0, 30.0), rough=0.45, rough_rate=65.0,
          formants=((1200.0, 3.5), (2600.0, 4.0)), breath=0.45, wave="pulse", duty=0.18, drive=1.8, sub=0.5,
          env_pts=None, hpf=55.0):
    """写实异虫声带与湿腔嘶吼：
    采用【非周期随机抖动生物喉部肉质爆裂颗粒（Aperiodic Glottal Fry）+ 气管湿黏湍流】
    通过【宽频生物咽腔共振峰】，穿透力强、极具生物撕裂质感。"""
    n = ns(dur)
    t = tt(n)
    u = t / dur
    f_in = np.interp(u, [p[0] for p in pts], [p[1] for p in pts])
    f_glot = np.clip(65.0 + (f_in - 55.0) * 0.25, 52.0, 260.0)

    glot_grains = np.zeros(n)
    cur_t = 0.0
    while cur_t < dur - 0.008:
        idx = int(cur_t * SR)
        if idx >= n:
            break
        f_now = float(f_glot[idx])
        step = (1.0 / f_now) * rng.uniform(0.55, 1.48)
        g_len = min(n - idx, ns(rng.uniform(0.004, 0.012)))
        tg = tt(g_len)
        grain = (np.exp(-tg / 0.0016) - 0.48 * np.exp(-tg / 0.0042)) * rng.uniform(0.45, 1.15)
        glot_grains[idx:idx + g_len] += grain
        cur_t += max(0.0022, step)
    glot_fry = bp(glot_grains, 110.0, 1900.0, 2)

    chest_sub = bp(0.65 * pink(n, rng) + 0.35 * brown(n, rng), 60.0, 320.0, 2) * (0.6 + 0.4 * np.abs(smooth_noise(n, rng, 18.0)))
    trach_noise = bp(0.80 * pink(n, rng) + 0.20 * brown(n, rng), 160.0, 2100.0, 2)
    mod_r = 0.42 + 0.58 * (np.abs(smooth_noise(n, rng, min(rough_rate, 38.0))) ** 1.2)
    exc = (0.68 * norm(glot_fry) + 0.42 * norm(chest_sub) + min(0.50, max(0.28, breath)) * 0.38 * norm(trach_noise)) * mod_r

    jaw = (0.82 + 0.30 * np.sin(np.pi * np.clip(u * 1.15, 0, 1))
           + 0.14 * smooth_noise(n, rng, 9.0)) * np.clip(f_in / 300.0, 0.68, 1.35)
    y = 0.38 * bp(exc, 110.0, 560.0, 2)
    for idx_f, (fc, q) in enumerate(formants):
        fc_base = min(2200.0, max(260.0, fc * (0.55 if fc > 1300.0 else 0.78)))
        fc_curve = np.clip(fc_base * jaw * (1.0 + 0.08 * idx_f), 220.0, 2500.0)
        y = y + 0.70 * sweep(exc, "bp", fc_curve, min(q, 1.85))

    wet_grit = bp(0.75 * pink(n, rng) + 0.25 * white(n, rng), 340.0, 2200.0, 2) * (np.abs(smooth_noise(n, rng, 34.0)) ** 1.6)
    y = 0.80 * norm(y) + 0.22 * norm(wet_grit)
    y = lp(hp(asym(y, min(1.85, max(1.35, drive)), 0.08), max(60.0, min(hpf, 110.0))), 3200.0, 2)
    e = env(env_pts, n) if env_pts else ahr(n, min(0.016, dur * 0.10), dur * 0.50, dur * 0.40)
    return att(norm(y) * e, 0.0006)


def chitter(rng, dur=0.3, rate=38.0, f=(2200.0, 4800.0), tau=0.003, swing=0.32, env_pts=None, period=None):
    """异虫几丁质大颚咔嗒闭合与骨节摩擦。"""
    span = period if period else ns(dur)
    out = np.zeros(span + ns(0.05))
    t = rng.uniform(0, 0.5 / rate)
    lim = span / SR - (0.0 if period else 0.02)
    f_lo, f_hi = max(420.0, f[0] * 0.36), min(2300.0, f[1] * 0.48)
    while t < lim:
        fk = rng.uniform(f_lo, f_hi)
        tk = _orig_tick(rng, fk, tau * rng.uniform(0.8, 1.4), 0.022, 0.75)
        body = burst(rng, 0.022, 0.0035, 190.0, 950.0, -2.4)
        place(out, 0.65 * tk + 0.50 * body, t, rng.uniform(0.45, 1.0))
        t += (1.0 / rate) * (1.0 + swing * rng.uniform(-1, 1))
    if period:
        return norm(fold_tile(out, period, ns(dur)))
    out = out[:span]
    e = env(env_pts, span) if env_pts else 1.0
    return norm(out) * e


def bubble(rng, f, tau=None, rise=0.1):
    """浓稠酸液囊泡破裂：用宽带阻尼脉冲替代高Q水滴音。"""
    f_c = float(np.clip(f * 0.72, 160.0, 1450.0))
    tau = tau or max(0.005, 4.2 / f_c)
    n = ns(tau * 5.0)
    t = tt(n)
    exc = bp(0.25 * white(n, rng) + 0.75 * pink(n, rng), f_c * 0.55, min(2800.0, f_c * 2.1), 2) * np.exp(-t / (tau * 0.38))
    f_sw = f_c * (1.0 + min(rise, 0.16) * (t / tau))
    cav = sweep(exc, "bp", f_sw, 2.0) * np.exp(-t / tau)
    return att(norm(lp(0.68 * norm(cav) + 0.44 * norm(exc), 3200.0, 2)), 0.0003)


def bubbles(rng, dur=0.5, rate=30.0, f_lo=260.0, f_hi=1350.0, rise=0.1, env_pts=None, period=None):
    """酸液/内脏囊泡沸腾簇。"""
    span = period if period else ns(dur)
    out = np.zeros(span + ns(0.15))
    t = 0.0
    lim = span / SR - (0.0 if period else 0.03)
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= lim:
            break
        f = float(np.exp(rng.uniform(np.log(max(150.0, f_lo * 0.75)), np.log(min(1550.0, f_hi * 0.85)))))
        place(out, bubble(rng, f, None, rise), t, rng.uniform(0.35, 1.0) * (f_lo / f) ** 0.3)
    if period:
        return norm(fold_tile(out, period, ns(dur)))
    out = out[:span]
    e = env(env_pts, span) if env_pts else 1.0
    return norm(out) * e


def slime(rng, dur=0.25, f0=2600.0, f1=260.0, q=1.8, tau=0.08, low=0.45):
    """高粘度生物浆液喷溅与血肉撕裂。"""
    n = ns(dur)
    t = tt(n)
    src_n = 0.25 * white(n, rng) + 0.75 * pink(n, rng)
    fc1 = f1 * 0.82 + (min(2100.0, f0 * 0.65) - f1 * 0.82) * np.exp(-t / (dur * 0.25))
    fc2 = f1 * 0.55 + (min(1250.0, f0 * 0.45) - f1 * 0.55) * np.exp(-t / (dur * 0.35))
    mod = 1.0 + 0.42 * np.abs(smooth_noise(n, rng, 42.0))
    x1 = sweep(src_n, "bp", fc1, min(q, 1.65)) * mod
    x2 = sweep(src_n, "bp", fc2, 1.35) * mod
    wet_sub = bp(0.70 * pink(n, rng) + 0.30 * brown(n, rng), 100.0, 400.0, 2) * expdec(n, tau * 0.95)
    x = 0.58 * norm(x1) + 0.48 * norm(x2) + min(0.38, low) * norm(wet_sub)
    return att(norm(lp(asym(x, 1.40, 0.08), 3200.0, 2)) * expdec(n, tau), 0.0005)


def crunch(rng, dur=0.15, grains=42, spread=0.05, lo=1000.0, hi=8200.0, body=0.45, body_f=360.0):
    """厚重几丁质甲壳/骨骼/混凝土砂石碾碎（清脆多颗粒脆裂，无高频白噪刺耳感）。"""
    n = ns(dur)
    out = np.zeros(n)
    for _ in range(grains):
        t0 = abs(rng.normal(0, spread * 0.5))
        if t0 > dur - 0.018:
            continue
        f_l = rng.uniform(max(320.0, lo * 0.45), max(720.0, lo * 0.85))
        f_h = min(3600.0, max(f_l * 2.0, hi * 0.48))
        g = burst(rng, 0.015, rng.uniform(0.0010, 0.0035), f_l, f_h, -2.0, 0.0002, 1.40)
        place(out, g, t0, rng.uniform(0.42, 1.0) * np.exp(-t0 / max(spread, 0.008)))
    bf = max(190.0, body_f * 0.82)
    b = burst(rng, dur, 0.026, bf * 0.62, min(2200.0, bf * 3.0), -2.2, 0.0003, 1.40)
    x = 0.72 * norm(out) + max(0.38, body) * 0.54 * norm(b)
    return att(norm(lp(asym(x, 1.40, 0.08), 3600.0, 2)), 0.0002)


def bug_hiss(rng, dur=0.5, lo=2200.0, hi=8500.0, peaks=(3400.0, 5800.0), tremble=(0.5, 42.0), env_pts=None):
    """异虫气门高压喷气嘶鸣与喉腔摩擦（宽带气动喷射，剔除刺耳高频嘶音）。"""
    n = ns(dur)
    raw = 0.20 * white(n, rng) + 0.80 * pink(n, rng)
    x = bp(raw, max(380.0, lo * 0.35), min(3200.0, hi * 0.42), 2)
    for f in peaks:
        x = peak(x, min(2400.0, f * 0.52), 1.6, 2.0)
    throat = bp(0.70 * pink(n, rng) + 0.30 * brown(n, rng), 180.0, 850.0, 2)
    x = 0.68 * norm(x) + 0.48 * norm(throat)
    d, r = tremble
    if d:
        x = x * (1.0 - d * 0.65 + d * 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * phase(r * (1.0 + 0.35 * smooth_noise(n, rng, 5.0))))))
    e = env(env_pts, n) if env_pts else ahr(n, 0.020, dur * 0.44, dur * 0.48)
    return norm(lp(asym(x, 1.32, 0.08), 3400.0, 2)) * e


def scrabble(rng, dur=0.5, rate=48.0, env_pts=None):
    """虫爪刨地/抓挠岩面。"""
    n = ns(dur)
    out = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= dur - 0.06:
            break
        if rng.random() < 0.68:
            g = burst(rng, 0.045, rng.uniform(0.006, 0.018), rng.uniform(260, 720), rng.uniform(1400, 3000), -2.2, 0.0010, 1.35)
        else:
            g = _orig_tick(rng, rng.uniform(750, 1950), rng.uniform(0.0020, 0.005), 0.024, 0.72)
        place(out, g, t, rng.uniform(0.35, 1.0))
    e = env(env_pts, n) if env_pts else ahr(n, 0.02, dur * 0.52, dur * 0.38)
    return norm(out) * e


# ---------------------------------------------------------------- 高压等离子电弧与电磁继电器脉冲
def arc(rng, dur=0.4, density=600.0, lo=2200.0, hum=0.35, burstiness=0.72, bits=7):
    """高压等离子电弧撕裂：受控电离脉冲簇 + 变压器磁暴低频震颤（剔除刺耳高频电流嘶声）。"""
    n = ns(dur)
    p = np.zeros(n)
    eff_dens = min(float(density), 220.0)
    k = max(4, int(rng.poisson(eff_dens * dur)))
    idx = rng.integers(0, n, k)
    p[idx] = rng.uniform(-1.0, 1.0, k) * (rng.uniform(0.3, 1.0, k) ** 1.5)
    hi_snap = bp(p, max(420.0, min(1100.0, lo * 0.35)), 2400.0, 2)
    mid_body = bp(p, 180.0, 1200.0, 2)
    sizzle = bp(pink(n, rng), 320.0, 2200.0, 2) * 0.16
    x = norm(0.45 * norm(hi_snap) + 0.62 * norm(mid_body) + sizzle)
    g = np.clip(0.42 + smooth_noise(n, rng, 20.0) * 1.1, 0.05, 1.0) ** 1.4
    x = x * ((1.0 - burstiness * 0.85) + burstiness * 0.85 * g)
    if hum:
        mag = bp(0.65 * pink(n, rng) + 0.35 * brown(n, rng), 75.0, 300.0, 2) * (1.0 + 0.42 * smooth_noise(n, rng, 28.0))
        x = x + hum * 0.55 * norm(asym(mag, 1.45, 0.10)) * (0.5 + 0.5 * g)
    return att(norm(lp(asym(x, 1.45, 0.08), 2800.0, 4)), 0.0004)


def _orig_buzz(f, dur, gate=None, bright=1400.0, wave="square"):
    """战术座舱干式电磁继电器/闭锁阀快频震颤（温润中频机械吸合，无周期蜂鸣或刺耳毛刺）。"""
    n = ns(dur)
    t = tt(n)
    f_arr = np.full(n, float(f)) if np.ndim(f) == 0 else np.asarray(f, float)
    if len(f_arr) != n:
        f_arr = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f_arr)), f_arr)
    f_c = float(np.clip(np.mean(f_arr) * 0.60, 75.0, 240.0))
    seed = int(float(np.mean(f_arr)) * 31 + n) & 0x7FFFFFFF
    rng_b = np.random.default_rng(seed)
    k_imp = max(8, int(dur * f_c * 1.5))
    idx = rng_b.integers(0, n, k_imp)
    imp = np.zeros(n)
    imp[idx] = rng_b.choice([-1.0, 1.0], k_imp) * rng_b.uniform(0.4, 1.0, k_imp)
    chatter = bp(imp, 260.0, min(max(bright * 1.05, 1100.0), 2200.0), 2)
    mid_housing = bp(pink(n, rng_b), 140.0, 680.0, 2) * (0.65 + 0.35 * np.abs(smooth_noise(n, rng_b, 26.0)))
    x = 0.68 * norm(chatter) + 0.40 * norm(mid_housing)
    if gate:
        cnt, duty = gate
        u = t / dur * cnt
        fr = u - np.floor(u)
        g = 1.0 / (1.0 + np.exp(-(fr - 0.025) * 140.0)) / (1.0 + np.exp(-(duty - fr) * 140.0))
        edge = np.exp(-fr * 28.0) * bp(0.22 * white(n, rng_b) + 0.78 * pink(n, rng_b), 360.0, 2100.0, 2)
        x = (0.72 * norm(x) + 0.42 * norm(edge)) * g
    return att(norm(lp(asym(x, 1.38, 0.08), 3000.0, 2)) * ahr(n, 0.0015, max(0.0, dur - 0.022), 0.018), 0.0004)


# ---------------------------------------------------------------- 材质模态常量与双签名物理合成接口
METAL_HEAVY = HEAVY
METAL_HOLLOW = TUBE
METAL_LIGHT = BAR
METAL_BELL = BELL
GLASS_MODES = [1.0, 1.41, 1.87, 2.36, 2.91, 3.54]
CHITIN_MODES = [1.0, 1.26, 1.58, 1.97, 2.41, 2.93]


def thump(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_thump(a0, *args, **kwargs)
    # (dur, f0, f1, decay, rng[, drive])
    dur = float(a0)
    f0 = float(args[0]) if len(args) > 0 else 110.0
    f1 = float(args[1]) if len(args) > 1 else 36.0
    decay = float(args[2]) if len(args) > 2 else 16.0
    rng = args[3] if len(args) > 3 else np.random.default_rng(101)
    drive = float(args[4]) if len(args) > 4 else 1.9
    tau = max(0.010, 1.05 / max(decay, 2.0))
    return _orig_thump(rng, f0=f0, f1=f1, dur=dur, tau=tau, sweep_t=0.024, drive=drive, click=0.45)


def crack(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_crack(a0, *args, **kwargs)
    # (dur, fc, rng[, drive])
    dur = float(a0)
    fc = float(args[0]) if len(args) > 0 else 1800.0
    rng = args[1] if len(args) > 1 else np.random.default_rng(102)
    tau = min(0.0045, max(0.0018, dur * 0.06))
    return _orig_crack(rng, dur=dur, tau=tau, lo=max(200.0, min(800.0, fc * 0.38)), hi=min(3400.0, max(1200.0, fc * 1.15)))


def modal(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_modal(a0, *args, **kwargs)
    # (dur, f0, modes, decay, rng[, bright])
    dur = float(a0)
    f0 = float(args[0]) if len(args) > 0 else 360.0
    modes = args[1] if len(args) > 1 else METAL_HEAVY
    decay = float(args[2]) if len(args) > 2 else 16.0
    rng = args[3] if len(args) > 3 else np.random.default_rng(103)
    tau = max(0.009, 0.95 / max(decay, 2.0))
    return _orig_modal(rng, f0=f0, ratios=modes, tau=tau, dur=dur)


def clank(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_clank(a0, *args, **kwargs)
    # (dur, f0, modes, decay, rng[, bright])
    dur = float(a0)
    f0 = float(args[0]) if len(args) > 0 else 340.0
    modes = args[1] if len(args) > 1 else METAL_HEAVY
    decay = float(args[2]) if len(args) > 2 else 18.0
    rng = args[3] if len(args) > 3 else np.random.default_rng(104)
    bright_ratio = float(args[4]) if len(args) > 4 else 0.80
    tau = max(0.009, 0.95 / max(decay, 2.0))
    return _orig_clank(rng, f0=f0, tau=tau, ratios=modes, dur=dur, hit=0.72, body=0.52, bright=min(3200.0, 1800.0 + 1400.0 * bright_ratio))


def tick(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_tick(a0, *args, **kwargs)
    # (dur, fc, rng)
    dur = float(a0)
    fc = float(args[0]) if len(args) > 0 else 2100.0
    rng = args[1] if len(args) > 1 else np.random.default_rng(105)
    return _orig_tick(rng, f=fc, tau=max(0.0014, dur * 0.22), dur=max(0.015, dur), noise=0.55)


def servo(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_servo(a0, *args, **kwargs)
    # (dur, f0, f1, rng[, bright])
    dur = float(a0)
    f0 = float(args[0]) if len(args) > 0 else 160.0
    f1 = float(args[1]) if len(args) > 1 else 280.0
    rng = args[2] if len(args) > 2 else np.random.default_rng(106)
    return _orig_servo(rng, dur=dur, f_lo=f0, f_hi=f1, up=dur * 0.45, down=dur * 0.35)


def hiss(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_hiss(a0, *args, **kwargs)
    # (dur, fc, bw, decay, rng)
    dur = float(a0)
    fc = float(args[0]) if len(args) > 0 else 1800.0
    bw = float(args[1]) if len(args) > 1 else 1200.0
    decay = float(args[2]) if len(args) > 2 else 8.0
    rng = args[3] if len(args) > 3 else np.random.default_rng(107)
    lo = max(250.0, fc - bw * 0.6)
    hi = min(8500.0, fc + bw * 0.9)
    y = _orig_hiss(rng, dur=dur, lo=lo, hi=hi, a=min(0.005, dur * 0.08), h=dur * 0.35, r=dur * 0.55, peaks=(fc, min(6500.0, fc * 1.5)), fall=0.30)
    return y * np.exp(-tt(len(y)) * (decay * 0.48))


def whoosh(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_whoosh(a0, *args, **kwargs)
    # (dur, f0, f1, rng[, q])
    dur = float(a0)
    f0 = float(args[0]) if len(args) > 0 else 280.0
    f1 = float(args[1]) if len(args) > 1 else 1200.0
    rng = args[2] if len(args) > 2 else np.random.default_rng(108)
    q = float(args[3]) if len(args) > 3 else 1.5
    return _orig_whoosh(rng, dur=dur, f0=f0, f1=f1, peak_t=0.38, q=min(q, 1.6), slope=-2.8, shape=1.5)


def roar(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_roar(a0, *args, **kwargs)
    # (dur, fc, decay, rng[, drive])
    dur = float(a0)
    fc = float(args[0]) if len(args) > 0 else 220.0
    decay = float(args[1]) if len(args) > 1 else 4.0
    rng = args[2] if len(args) > 2 else np.random.default_rng(109)
    drive = float(args[3]) if len(args) > 3 else 1.8
    n = ns(dur)
    y = _orig_roar(rng, n, lo=max(32.0, fc * 0.32), hi=min(3600.0, fc * 6.5), turb=14.0, depth=0.52)
    return att(norm(asym(y * np.exp(-tt(n) * (decay * 0.65)), drive, 0.12)), 0.001)


def rumble(dur, fc=65.0, rate=5.0, rng=None, drive=1.5):
    if rng is None:
        rng = np.random.default_rng(110)
    n = ns(float(dur))
    raw = 0.65 * brown(n, rng) + 0.35 * pink(n, rng)
    sub = bp(raw, max(24.0, fc * 0.45), min(360.0, fc * 2.5), 2)
    mod = 1.0 + 0.48 * smooth_noise(n, rng, float(rate))
    return norm(asym(sub * np.maximum(0.18, mod), float(drive), 0.10))


def zap(dur, fc=2200.0, rng=None, density=38):
    if rng is None:
        rng = np.random.default_rng(111)
    y = arc(rng, dur=float(dur), density=min(float(density) * 5.0, 180.0), lo=max(260.0, min(900.0, float(fc) * 0.35)), hum=0.50, burstiness=0.68)
    return y * np.exp(-tt(len(y)) * (2.2 / max(float(dur), 0.1)))


def buzz(a0, *args, **kwargs):
    if len(args) >= 3 and isinstance(args[2], np.random.Generator):
        # (dur, f0, f1, rng[, drive])：重型液压/电磁回路负载震颤（无周期锯齿波）
        dur = float(a0)
        f0 = float(args[0])
        f1 = float(args[1])
        rng = args[2]
        drive = float(args[3]) if len(args) > 3 else 1.5
        n = ns(dur)
        f_curve = np.geomspace(max(40.0, f0), max(40.0, f1), n)
        raw = 0.55 * brown(n, rng) + 0.45 * pink(n, rng)
        body = sweep(raw, "bp", np.clip(f_curve * 1.4, 55.0, 950.0), 1.35)
        mod = 0.65 + 0.35 * np.abs(smooth_noise(n, rng, 28.0))
        return att(norm(asym(body * mod, min(drive, 1.7), 0.10)), 0.001)
    return _orig_buzz(a0, *args, **kwargs)


def turbine(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_turbine(a0, *args, **kwargs)
    # (dur, f0, f1, rng[, blades, jitter])
    dur = float(a0)
    f0 = float(args[0]) if len(args) > 0 else 110.0
    f1 = float(args[1]) if len(args) > 1 else 220.0
    rng = args[2] if len(args) > 2 else np.random.default_rng(112)
    blades = int(args[3]) if len(args) > 3 else 6
    n = ns(dur)
    f_curve = np.geomspace(max(25.0, f0), max(25.0, f1), n)
    return _orig_turbine(rng, n, f_curve, blades=blades, whine=0.35, roar_amt=0.72)


def squelch(dur, f0=280.0, f1=1280.0, rng=None, drive=1.8):
    if rng is None:
        rng = np.random.default_rng(113)
    d = float(dur)
    s1 = slime(rng, dur=d, f0=max(f0, f1), f1=min(f0, f1), q=1.55, tau=max(0.04, d * 0.42), low=0.55)
    b1 = bubbles(rng, dur=d, rate=28.0, f_lo=max(130.0, min(f0, f1) * 0.65), f_hi=min(1500.0, max(f0, f1) * 0.95))
    return att(norm(asym(0.70 * s1 + 0.38 * b1[:len(s1)], min(float(drive), 1.85), 0.10)), 0.0005)


def voice(a0, *args, **kwargs):
    if isinstance(a0, np.random.Generator):
        return _orig_voice(a0, *args, **kwargs)
    # (dur, f0, f1, rng[, rate, breath, drive])
    dur = float(a0)
    f0 = float(args[0]) if len(args) > 0 else 110.0
    f1 = float(args[1]) if len(args) > 1 else 165.0
    rng = args[2] if len(args) > 2 else np.random.default_rng(114)
    rate = float(args[3]) if len(args) > 3 else 12.0
    breath = float(args[4]) if len(args) > 4 else 0.38
    drive = float(args[5]) if len(args) > 5 else 1.8
    pts = [(0.0, f0), (0.38, max(f0, f1) * 1.06), (1.0, f1)]
    return _orig_voice(rng, dur=dur, pts=pts, jit=0.06, flutter=(0.06, rate), rough=0.55, rough_rate=max(24.0, rate * 3.5),
                       formants=((max(240.0, min(f0, f1) * 2.1), 1.6), (max(620.0, max(f0, f1) * 3.8), 1.8)),
                       breath=breath, drive=drive, sub=0.58)
