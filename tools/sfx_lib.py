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
    扎实有力、层次分明，避免纯超低频浑浊轰鸣。"""
    n = ns(dur)
    t = tt(n)
    f0_j = float(max(85.0, f0)) * rng.uniform(0.93, 1.07)
    f1_j = float(max(36.0, f1)) * rng.uniform(0.94, 1.06)
    sw_t = max(float(sweep_t), 0.012)
    tau_s = min(max(float(tau) * 0.72, 0.010), 0.046)
    f_inst = np.clip(f1_j + (f0_j - f1_j) * np.exp(-t / sw_t), 32.0, 320.0)
    # 1) 相位凝聚的低频压缩波（适度控制时长，保证拳拳到肉而非拖沓轰头）
    ph_jitter = 0.22 * smooth_noise(n, rng, 32.0)
    ph = phase(f_inst, n) + ph_jitter + rng.uniform(0.0, 0.18)
    sub_wave = (np.sin(2.0 * np.pi * ph) + 0.35 * np.sin(4.0 * np.pi * ph)) * np.exp(-t / tau_s)
    # 2) 宽带中低频结实冲击肉感（120~780Hz）
    raw = 0.65 * pink(n, rng) + 0.35 * white(n, rng)
    body_punch = bp(raw, max(110.0, f1_j * 2.2), min(920.0, max(380.0, f0_j * 4.2)), 2) * np.exp(-t / max(0.008, tau_s * 0.65))
    y = asym(0.50 * norm(sub_wave) + 0.62 * norm(body_punch), min(drive, 2.2), 0.10)
    if click:
        c_sig = bp(0.65 * white(n, rng) + 0.35 * pink(n, rng), 380.0, 3800.0, 2) * np.exp(-t / 0.0030)
        y = y + max(0.35, float(click)) * 0.78 * norm(c_sig)
    return att(norm(y), 0.0003)


def _orig_crack(rng, dur=0.04, tau=0.005, lo=650.0, hi=9500.0, bi=0.0005):
    """超音速激波/硬物脆裂瞬态：双极性 N 波激波头 + 宽带中高频脆裂。"""
    n = ns(dur)
    t = tt(n)
    n_wave = np.where(t < bi, 1.0 - 2.0 * (t / max(bi, 1e-5)), -np.exp(-(t - bi) / (bi * 1.8)))
    n_wave *= np.exp(-t / (bi * 2.4))
    lo_c = max(320.0, lo * 0.75)
    hi_c = min(12000.0, max(lo_c * 2.5, hi * 0.92))
    body_hi = bp(0.68 * white(n, rng) + 0.32 * pink(n, rng), lo_c, hi_c, 2) * np.exp(-t / tau)
    body_mid = bp(pink(n, rng), max(260.0, lo_c * 0.55), max(1200.0, lo_c * 2.2), 2) * np.exp(-t / (tau * 1.4))
    y = 0.45 * n_wave + 0.78 * norm(body_hi) + 0.48 * norm(body_mid)
    return att(asym(norm(y), 1.8, 0.10), 0.0002)


def burst(rng, dur=0.18, tau=0.025, lo=80.0, hi=5500.0, slope=-2.0, a=0.0005, drive=1.8):
    """宽带爆轰/冲击簇。"""
    n = ns(dur)
    x = colored(n, rng, max(slope, -1.8))
    x = bp(x, max(120.0, lo), min(11500.0, hi), 2) * ad(n, a, tau)
    return asym(norm(x), min(drive, 2.0), 0.10)


# ---------------------------------------------------------------- 厚重装甲与实心钢构件碰撞（真实阻尼金属模态，清脆扎实，零空心塑料管/闷响）
PLATE = [1.0, 1.37, 1.83, 2.39, 3.04, 3.82]
BAR = [1.0, 1.52, 2.18, 2.94, 3.78]
TUBE = [1.0, 1.41, 1.93, 2.56, 3.28]
BELL = [1.0, 1.34, 1.76, 2.28, 2.89, 3.58]
HEAVY = [1.0, 1.29, 1.67, 2.14, 2.68, 3.31]


def _orig_modal(rng, f0, ratios, tau=0.1, dur=None, amp_decay=0.78, detune=0.025, bright=4800.0):
    """高密度实心合金/机械构件阻尼冲击共鸣：
    由短促宽带碰撞冲量（3~8ms）激励快衰减金属非谐模态（tau <= 36ms），
    既有鲜明的实心金属冷冽质感，又绝无空心塑料管长尾或低频闷噪。"""
    dur = dur or min(0.45, max(0.05, tau * 3.2))
    n = ns(dur)
    t = tt(n)
    f_base = float(np.clip(f0 * rng.uniform(0.95, 1.05), 210.0, 1650.0))
    tau_eff = min(float(tau), 0.065)
    # 1) 短促清脆接触冲量（仅在接触瞬间 3~7ms 注入能量，而非全程持续噪声）
    imp_src = 0.62 * white(n, rng) + 0.38 * pink(n, rng)
    exc_hit = bp(imp_src, max(280.0, f_base * 0.65), min(7800.0, bright * 1.1), 2) * np.exp(-t / max(0.0022, min(0.007, tau_eff * 0.16)))
    # 2) 实心金属短阻尼非谐模态（冲量激励谐振 + 瞬态微张力包络，快速衰减）
    y = np.zeros(n)
    exc_modal = bp(imp_src, max(220.0, f_base * 0.55), min(7200.0, bright), 2) * np.exp(-t / max(0.004, min(0.012, tau_eff * 0.25)))
    for i, r in enumerate(ratios[:5]):
        f = f_base * r * rng.uniform(1.0 - detune, 1.0 + detune)
        if f >= min(bright * 1.15, SR * 0.42):
            break
        tk = max(0.0035, min(0.036, tau_eff * (0.38 / (r ** 0.72)) * rng.uniform(0.88, 1.12)))
        q = float(np.clip(3.2 + 0.55 * i, 3.2, 5.5))
        m_res = reson(exc_modal, f, q) * np.exp(-t / tk)
        f_env = f * (1.0 + 0.018 * np.exp(-t / 0.0025))
        m_ping = np.sin(2.0 * np.pi * phase(f_env, n) + rng.uniform(0.0, 6.28)) * np.exp(-t / (tk * 0.78))
        y += (amp_decay ** i) * (0.68 * norm(m_res) + 0.32 * m_ping)
    # 3) 紧凑中频结构底座（220~980Hz，干脆收束，不产生 <150Hz 闷响）
    mid_body = bp(pink(n, rng), max(190.0, f_base * 0.50), min(1150.0, f_base * 2.1), 2) * np.exp(-t / max(0.006, tau_eff * 0.32))
    out = 0.56 * norm(y) + 0.54 * norm(exc_hit) + 0.24 * norm(mid_body)
    return att(norm(asym(out, 1.38, 0.06)), 0.0002)


def _orig_clank(rng, f0, tau=0.055, ratios=PLATE, dur=None, hit=0.7, body=0.65, bright=4500.0):
    """精密机械钢件咬合/枪机闭锁/装甲卡榫碰撞：双点金属咬合瞬态 + 实心钢体阻尼模态。"""
    dur = dur or min(0.38, max(0.05, tau * 3.6))
    n = ns(dur)
    t = tt(n)
    f_c = float(np.clip(f0 * rng.uniform(0.94, 1.06), 220.0, 1250.0))
    tau_c = min(float(tau), 0.058)
    m_body = _orig_modal(rng, f_c, ratios, tau_c, dur, 0.74, 0.025, min(bright * 1.15, 6200.0))
    # 机械双点接触瞬态（主咬合 0ms + 闭锁销微弹跳 4~9ms，中高频清脆利落）
    snap1 = bp(0.65 * white(n, rng) + 0.35 * pink(n, rng), max(450.0, f_c * 0.95), min(7500.0, bright * 1.25), 2) * np.exp(-t / 0.0032)
    dly_s = int(round(rng.uniform(0.0040, 0.0095) * SR))
    snap2 = np.zeros(n)
    if dly_s < n - 8:
        s_len = n - dly_s
        snap2[dly_s:] = bp(0.6 * white(s_len, rng) + 0.4 * pink(s_len, rng), max(580.0, f_c * 1.2), min(6800.0, bright * 1.1), 2) * np.exp(-tt(s_len) / 0.0038) * 0.52
    weight = bp(pink(n, rng), 150.0, min(680.0, f_c * 1.65), 2) * np.exp(-t / max(0.009, tau_c * 0.42))
    y = 0.54 * m_body + hit * 0.78 * norm(snap1 + snap2) + body * 0.28 * norm(weight)
    return att(norm(asym(y, 1.42, 0.08)), 0.0002)


def _orig_tick(rng, f=2200.0, tau=0.003, dur=0.028, noise=0.55):
    """精密战术微动开关/棘轮清脆触点：清脆中高频弹片瞬态 + 极短铝合金底座反响（零低频闷响）。"""
    n = ns(dur)
    t = tt(n)
    f_t = float(np.clip(f * rng.uniform(0.95, 1.05), 950.0, 4800.0))
    tau_t = min(max(0.0012, float(tau)), 0.0055)
    # 1) 银触点瞬态弹击（900~8500Hz）
    imp = bp(0.72 * white(n, rng) + 0.28 * pink(n, rng), max(850.0, f_t * 0.55), min(9200.0, f_t * 2.4), 2) * np.exp(-t / max(0.0008, tau_t * 0.52))
    # 2) 微动弹簧片清脆金属短振（1.5~3.5ms 极速衰减）
    f_leaf = f_t * (1.0 + 0.03 * np.exp(-t / 0.0012))
    leaf = (np.sin(2.0 * np.pi * phase(f_leaf, n)) + 0.42 * np.sin(2.0 * np.pi * phase(f_leaf * 1.58, n))) * np.exp(-t / max(0.0014, tau_t * 0.85))
    body_t = reson(imp, f_t * 0.72, 3.4) * np.exp(-t / max(0.0018, tau_t * 1.15))
    # 3) 紧凑键帽/开关壳体支撑（高通 340Hz，杜绝低频浑浊）
    housing = bp(pink(n, rng), 360.0, 1650.0, 2) * np.exp(-t / max(0.0022, tau_t * 1.35))
    y = 0.65 * norm(imp) + (1.0 - noise * 0.35) * 0.46 * norm(0.55 * norm(body_t) + 0.45 * leaf) + 0.28 * norm(housing)
    return att(norm(hp(y, 320.0, 2)), 0.00012)


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
    f_l = max(320.0, f_lo * 0.55)
    f_h = min(3800.0, f_hi * 0.72)
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
    x = bp(raw, max(180.0, lo * 0.55), min(4600.0, hi * 0.8), 2)
    g = np.clip(0.55 + 0.45 * smooth_noise(n, rng, rough), 0.12, 1.0) ** 1.35
    x = x * g
    if modes:
        m = sum(reson(x, min(2800.0, f * 0.72), min(q * 0.25, 3.2)) for f in modes)
        x = 0.70 * norm(x) + 0.30 * norm(m)
    return norm(asym(x, 1.45, 0.08)) * ahr(n, 0.01, max(0.0, dur - 0.04), 0.03)


# ---------------------------------------------------------------- 喷气、呼啸、爆裂碎片
def _orig_hiss(rng, dur=0.3, lo=1200.0, hi=9000.0, a=0.004, h=0.06, r=0.2, peaks=(2400.0, 5200.0), q=3.5, fall=0.0):
    """高压气体喷射/泄压阀气流：自然宽带气体湍流，无窄带尖啸。"""
    n = ns(dur)
    t = tt(n)
    raw = 0.55 * pink(n, rng) + 0.45 * white(n, rng)
    lo_f = max(280.0, lo * 0.58)
    hi_f = min(7800.0, max(lo_f * 2.2, hi * 0.78))
    x = bp(raw, lo_f, hi_f, 2)
    for f in peaks:
        f_p = min(5200.0, f * 0.72)
        if fall:
            fc = f_p * (1.0 - min(fall, 0.55) * (t / dur))
            x = x + 0.32 * sweep(raw, "bp", np.clip(fc, 220.0, 5800.0), min(q * 0.55, 2.0))
        else:
            x = peak(x, f_p, min(q * 0.55, 1.8), 3.0)
    low_air = bp(brown(n, rng), 110.0, 580.0, 2)
    x = 0.75 * norm(x) + 0.32 * norm(low_air)
    turb = 1.0 + 0.18 * smooth_noise(n, rng, 32.0)
    return norm(x * turb) * ahr(n, a, h, max(0.01, dur - a - h if r is None else r))


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
    x = bp(pulses, max(480.0, lo * 0.65), min(9500.0, hi), 2)
    x = x + 0.65 * bp(pulses, max(140.0, lo * 0.20), max(600.0, lo * 0.75), 1)
    return norm(asym(x, 1.5, 0.10))


def _orig_turbine(rng, n, f_rot, blades=11, whine=0.35, roar_amt=0.65, lo=55.0, hi=5500.0, period=None):
    """重型燃气涡扇/动力核心：
    深沉燃烧室压气轰鸣 + 宽带气动剪切扫频，兼具动力厚度与高亢气流清晰度。"""
    fr = np.full(n, float(f_rot)) if np.ndim(f_rot) == 0 else np.asarray(f_rot, float)
    if len(fr) != n:
        fr = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(fr)), fr)
    fr = np.clip(fr, 28.0, 260.0)
    core_rumble = bp(src(rng, n, -3.5, period), 55.0, 280.0, 2) * (1.0 + 0.30 * lfo(rng, n, 6.5, period))
    f_air = np.clip(fr * 3.8, 280.0, 2800.0)
    air_shear = sweep(src(rng, n, -1.4, period), "bp", f_air, 1.85) * (1.0 + 0.22 * lfo(rng, n, 14.0, period))
    a = _orig_roar(rng, n, max(120.0, lo), min(hi, 4800.0), 8.5, 0.38, -2.2, period)
    return norm(0.38 * norm(core_rumble) + max(0.35, whine) * 0.72 * norm(air_shear) + roar_amt * 0.85 * norm(a))


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
    glot_fry = bp(glot_grains, 140.0, 2800.0, 2)

    chest_sub = bp(pink(n, rng), 65.0, 320.0, 2) * (0.6 + 0.4 * np.abs(smooth_noise(n, rng, 18.0)))
    trach_noise = bp(0.60 * white(n, rng) + 0.40 * pink(n, rng), 240.0, 5200.0, 2)
    mod_r = 0.42 + 0.58 * (np.abs(smooth_noise(n, rng, min(rough_rate, 42.0))) ** 1.2)
    exc = (0.65 * norm(glot_fry) + 0.24 * norm(chest_sub) + max(0.48, breath) * 0.75 * norm(trach_noise)) * mod_r

    jaw = (0.82 + 0.32 * np.sin(np.pi * np.clip(u * 1.15, 0, 1))
           + 0.14 * smooth_noise(n, rng, 9.0)) * np.clip(f_in / 300.0, 0.72, 1.55)
    y = 0.28 * bp(exc, 120.0, 620.0, 2)
    for idx_f, (fc, q) in enumerate(formants):
        fc_base = min(3400.0, max(320.0, fc * (0.65 if fc > 1500.0 else 0.85)))
        fc_curve = np.clip(fc_base * jaw * (1.0 + 0.10 * idx_f), 260.0, 4600.0)
        y = y + 0.75 * sweep(exc, "bp", fc_curve, min(q, 2.2))

    wet_grit = bp(0.55 * white(n, rng) + 0.45 * pink(n, rng), 680.0, 4800.0, 2) * (np.abs(smooth_noise(n, rng, 38.0)) ** 1.6)
    y = 0.72 * norm(y) + 0.42 * norm(wet_grit)
    y = hp(asym(y, min(2.0, max(1.45, drive)), 0.10), max(65.0, min(hpf, 120.0)))
    e = env(env_pts, n) if env_pts else ahr(n, min(0.016, dur * 0.10), dur * 0.50, dur * 0.40)
    return att(norm(y) * e, 0.0006)


def chitter(rng, dur=0.3, rate=38.0, f=(2200.0, 4800.0), tau=0.003, swing=0.32, env_pts=None, period=None):
    """异虫几丁质大颚咔嗒闭合与骨节摩擦。"""
    span = period if period else ns(dur)
    out = np.zeros(span + ns(0.05))
    t = rng.uniform(0, 0.5 / rate)
    lim = span / SR - (0.0 if period else 0.02)
    f_lo, f_hi = max(520.0, f[0] * 0.50), min(4200.0, f[1] * 0.68)
    while t < lim:
        fk = rng.uniform(f_lo, f_hi)
        tk = _orig_tick(rng, fk, tau * rng.uniform(0.8, 1.4), 0.022, 0.75)
        body = burst(rng, 0.022, 0.0035, 220.0, 1100.0, -2.2)
        place(out, 0.70 * tk + 0.45 * body, t, rng.uniform(0.45, 1.0))
        t += (1.0 / rate) * (1.0 + swing * rng.uniform(-1, 1))
    if period:
        return norm(np.tile(fold(out, period), -(-ns(dur) // period))[:ns(dur)])
    out = out[:span]
    e = env(env_pts, span) if env_pts else 1.0
    return norm(out) * e


def bubble(rng, f, tau=None, rise=0.1):
    """浓稠酸液囊泡破裂：用宽带阻尼脉冲替代高Q水滴音。"""
    f_c = float(np.clip(f * 0.78, 180.0, 1650.0))
    tau = tau or max(0.005, 4.2 / f_c)
    n = ns(tau * 5.0)
    t = tt(n)
    exc = bp(0.55 * white(n, rng) + 0.45 * pink(n, rng), f_c * 0.6, min(4800.0, f_c * 2.5), 2) * np.exp(-t / (tau * 0.38))
    f_sw = f_c * (1.0 + min(rise, 0.16) * (t / tau))
    cav = sweep(exc, "bp", f_sw, 2.4) * np.exp(-t / tau)
    return att(norm(0.68 * norm(cav) + 0.48 * norm(exc)), 0.0003)


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
        f = float(np.exp(rng.uniform(np.log(max(160.0, f_lo * 0.80)), np.log(min(1850.0, f_hi * 0.90)))))
        place(out, bubble(rng, f, None, rise), t, rng.uniform(0.35, 1.0) * (f_lo / f) ** 0.3)
    if period:
        return norm(np.tile(fold(out, period), -(-ns(dur) // period))[:ns(dur)])
    out = out[:span]
    e = env(env_pts, span) if env_pts else 1.0
    return norm(out) * e


def slime(rng, dur=0.25, f0=2600.0, f1=260.0, q=1.8, tau=0.08, low=0.45):
    """高粘度生物浆液喷溅与血肉撕裂。"""
    n = ns(dur)
    t = tt(n)
    src_n = 0.65 * white(n, rng) + 0.35 * pink(n, rng)
    fc1 = f1 * 0.85 + (min(3600.0, f0 * 0.85) - f1 * 0.85) * np.exp(-t / (dur * 0.25))
    fc2 = f1 * 0.55 + (min(1850.0, f0 * 0.55) - f1 * 0.55) * np.exp(-t / (dur * 0.35))
    mod = 1.0 + 0.45 * np.abs(smooth_noise(n, rng, 48.0))
    x1 = sweep(src_n, "bp", fc1, min(q, 1.85)) * mod
    x2 = sweep(src_n, "bp", fc2, 1.45) * mod
    wet_sub = bp(pink(n, rng), 110.0, 420.0, 2) * expdec(n, tau * 0.95)
    x = 0.62 * norm(x1) + 0.48 * norm(x2) + min(0.32, low) * norm(wet_sub)
    return att(norm(asym(x, 1.45, 0.08)) * expdec(n, tau), 0.0005)


def crunch(rng, dur=0.15, grains=42, spread=0.05, lo=1000.0, hi=8200.0, body=0.45, body_f=360.0):
    """厚重几丁质甲壳/骨骼/混凝土砂石碾碎（清脆多颗粒脆裂，不混入超低频轰鸣）。"""
    n = ns(dur)
    out = np.zeros(n)
    for _ in range(grains):
        t0 = abs(rng.normal(0, spread * 0.5))
        if t0 > dur - 0.018:
            continue
        f_l = rng.uniform(max(480.0, lo * 0.65), max(1100.0, lo * 1.35))
        f_h = min(8200.0, max(f_l * 2.2, hi * 0.88))
        g = burst(rng, 0.015, rng.uniform(0.0010, 0.0035), f_l, f_h, -1.0, 0.0002, 1.45)
        place(out, g, t0, rng.uniform(0.42, 1.0) * np.exp(-t0 / max(spread, 0.008)))
    bf = max(220.0, body_f * 0.88)
    b = burst(rng, dur, 0.026, bf * 0.65, min(3200.0, bf * 3.5), -1.6, 0.0003, 1.45)
    x = 0.76 * norm(out) + max(0.35, body) * 0.48 * norm(b)
    return att(norm(asym(x, 1.45, 0.08)), 0.0002)


def bug_hiss(rng, dur=0.5, lo=2200.0, hi=8500.0, peaks=(3400.0, 5800.0), tremble=(0.5, 42.0), env_pts=None):
    """异虫气门高压喷气嘶鸣与喉腔摩擦。"""
    n = ns(dur)
    raw = 0.62 * white(n, rng) + 0.38 * pink(n, rng)
    x = bp(raw, max(680.0, lo * 0.58), min(7600.0, hi * 0.82), 2)
    for f in peaks:
        x = peak(x, min(5200.0, f * 0.80), 2.2, 4.0)
    throat = bp(pink(n, rng), 240.0, 1100.0, 2)
    x = 0.76 * norm(x) + 0.32 * norm(throat)
    d, r = tremble
    if d:
        x = x * (1.0 - d * 0.65 + d * 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * phase(r * (1.0 + 0.35 * smooth_noise(n, rng, 5.0))))))
    e = env(env_pts, n) if env_pts else ahr(n, 0.020, dur * 0.44, dur * 0.48)
    return norm(asym(x, 1.38, 0.08)) * e


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
            g = burst(rng, 0.045, rng.uniform(0.006, 0.018), rng.uniform(320, 880), rng.uniform(1800, 4800), -1.8, 0.0010, 1.4)
        else:
            g = _orig_tick(rng, rng.uniform(1100, 3200), rng.uniform(0.0020, 0.005), 0.024, 0.75)
        place(out, g, t, rng.uniform(0.35, 1.0))
    e = env(env_pts, n) if env_pts else ahr(n, 0.02, dur * 0.52, dur * 0.38)
    return norm(out) * e


# ---------------------------------------------------------------- 高压等离子电弧与电磁继电器脉冲
def arc(rng, dur=0.4, density=600.0, lo=2200.0, hum=0.35, burstiness=0.72, bits=7):
    """高压等离子电弧撕裂：电离爆裂簇 + 变压器磁暴震颤。"""
    n = ns(dur)
    p = np.zeros(n)
    k = max(5, int(rng.poisson(density * dur)))
    idx = rng.integers(0, n, k)
    p[idx] = rng.uniform(-1.0, 1.0, k) * (rng.uniform(0.3, 1.0, k) ** 1.5)
    hi_snap = bp(p, max(950.0, lo * 0.55), 8500.0, 2)
    mid_body = bp(p, 340.0, 2200.0, 2)
    sizzle = bp(white(n, rng), 850.0, 5600.0, 2) * 0.38
    x = norm(0.65 * norm(hi_snap) + 0.52 * norm(mid_body) + sizzle)
    g = np.clip(0.42 + smooth_noise(n, rng, 24.0) * 1.2, 0.05, 1.0) ** 1.4
    x = x * ((1.0 - burstiness * 0.85) + burstiness * 0.85 * g)
    if hum:
        mag = bp(pink(n, rng), 90.0, 340.0, 2) * (1.0 + 0.45 * smooth_noise(n, rng, 35.0))
        x = x + hum * 0.45 * norm(asym(mag, 1.55, 0.10)) * (0.5 + 0.5 * g)
    return att(norm(asym(x, 1.55, 0.10)), 0.0003)


def _orig_buzz(f, dur, gate=None, bright=1400.0, wave="square"):
    """战术座舱干式电磁继电器/闭锁阀快频震颤（清脆中频机械吸合，无周期蜂鸣或低频浑浊）。"""
    n = ns(dur)
    t = tt(n)
    f_arr = np.full(n, float(f)) if np.ndim(f) == 0 else np.asarray(f, float)
    if len(f_arr) != n:
        f_arr = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f_arr)), f_arr)
    f_c = float(np.clip(np.mean(f_arr) * 0.65, 85.0, 280.0))
    seed = int(float(np.mean(f_arr)) * 31 + n) & 0x7FFFFFFF
    rng_b = np.random.default_rng(seed)
    k_imp = max(8, int(dur * f_c * 1.6))
    idx = rng_b.integers(0, n, k_imp)
    imp = np.zeros(n)
    imp[idx] = rng_b.choice([-1.0, 1.0], k_imp) * rng_b.uniform(0.4, 1.0, k_imp)
    chatter = bp(imp, 320.0, min(max(bright * 1.4, 1600.0), 3600.0), 2)
    mid_housing = bp(pink(n, rng_b), 180.0, 780.0, 2) * (0.65 + 0.35 * np.abs(smooth_noise(n, rng_b, 28.0)))
    x = 0.74 * norm(chatter) + 0.32 * norm(mid_housing)
    if gate:
        cnt, duty = gate
        u = t / dur * cnt
        fr = u - np.floor(u)
        g = 1.0 / (1.0 + np.exp(-(fr - 0.025) * 140.0)) / (1.0 + np.exp(-(duty - fr) * 140.0))
        edge = np.exp(-fr * 28.0) * bp(0.6 * white(n, rng_b) + 0.4 * pink(n, rng_b), 480.0, 3200.0, 2)
        x = (0.72 * norm(x) + 0.48 * norm(edge)) * g
    return att(norm(asym(x, 1.42, 0.08)) * ahr(n, 0.0015, max(0.0, dur - 0.022), 0.018), 0.0004)


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
    tau = max(0.003, dur * 0.20)
    return _orig_crack(rng, dur=dur, tau=tau, lo=max(320.0, fc * 0.58), hi=min(11500.0, fc * 2.6))


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
    return _orig_clank(rng, f0=f0, tau=tau, ratios=modes, dur=dur, hit=0.82, body=0.45, bright=2800.0 + 3200.0 * bright_ratio)


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
    y = arc(rng, dur=float(dur), density=float(density) * 14.0, lo=max(550.0, float(fc) * 0.60), hum=0.40, burstiness=0.72)
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
