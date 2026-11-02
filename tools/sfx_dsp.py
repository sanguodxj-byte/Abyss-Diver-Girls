"""
音效合成的信号处理底层：噪声、滤波、振荡器、包络、失真、混响、混音、响度统一与写盘。
全部信号是 float64 数组：单声道形状为 (n,)，立体声形状为 (n, 2)。采样率固定 44100。
"""
import zlib
import numpy as np
from scipy import signal as sps
from scipy.io import wavfile

SR = 44100
NYQ = SR / 2.0


def ns(sec):
    return max(1, int(round(sec * SR)))


def tt(sec_or_n):
    n = sec_or_n if isinstance(sec_or_n, (int, np.integer)) else ns(sec_or_n)
    return np.arange(n) / SR


def seed_of(*parts):
    """由字符串拼出稳定的随机种子，同一个 id 与变体每次重建结果相同。"""
    return zlib.crc32("|".join(str(p) for p in parts).encode("utf-8")) & 0x7FFFFFFF


# ---------------------------------------------------------------- 噪声
def colored(n, rng, slope=0.0, fmin=20.0):
    """频谱斜率为 slope dB/倍频程的噪声（0 白噪声，-3 粉红，-6 布朗），fmin 以下的频谱保持平坦，峰值归一。"""
    n = int(n)
    if n < 2:
        return np.zeros(max(n, 0))
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f = np.maximum(f, fmin)
    spec *= f ** (slope / 6.0206)
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    m = np.max(np.abs(x))
    return x / m if m > 0 else x


def white(n, rng):
    return colored(n, rng, 0.0)


def pink(n, rng):
    return colored(n, rng, -3.0)


def brown(n, rng):
    return colored(n, rng, -6.0)


def smooth_noise(n, rng, rate):
    """带宽约为 rate Hz 的平滑随机曲线，幅度约在 -1..1；圆周频域滤波，首尾无缝。"""
    n = int(n)
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spec *= np.exp(-0.5 * (f / max(rate, 0.01)) ** 2)
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    s = np.std(x)
    return x / (2.2 * s) if s > 0 else x


# ---------------------------------------------------------------- 滤波
def _apply(sos, x):
    return sps.sosfilt(sos, x, axis=0)


def _cut(f):
    return float(np.clip(f, 10.0, NYQ * 0.98))


def lp(x, f, order=2):
    return _apply(sps.butter(order, _cut(f), "lowpass", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return _apply(sps.butter(order, _cut(f), "highpass", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    lo, hi = _cut(lo), _cut(hi)
    if hi <= lo * 1.01:
        hi = min(lo * 1.05, NYQ * 0.98)
    return _apply(sps.butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def biquad_coef(kind, f, q=0.707, gain_db=0.0):
    """二阶节系数 (b0,b1,b2,a0,a1,a2)，kind 为 lp / hp / bp / peak / lowshelf / highshelf。"""
    f = _cut(f)
    w0 = 2.0 * np.pi * f / SR
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2.0 * q)
    a = 10.0 ** (gain_db / 40.0)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        aa = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        aa = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":
        b = [alpha, 0.0, -alpha]
        aa = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * a, -2 * cw, 1 - alpha * a]
        aa = [1 + alpha / a, -2 * cw, 1 - alpha / a]
    elif kind in ("lowshelf", "highshelf"):
        sq = 2.0 * np.sqrt(a) * alpha
        if kind == "lowshelf":
            b = [a * ((a + 1) - (a - 1) * cw + sq), 2 * a * ((a - 1) - (a + 1) * cw), a * ((a + 1) - (a - 1) * cw - sq)]
            aa = [(a + 1) + (a - 1) * cw + sq, -2 * ((a - 1) + (a + 1) * cw), (a + 1) + (a - 1) * cw - sq]
        else:
            b = [a * ((a + 1) + (a - 1) * cw + sq), -2 * a * ((a - 1) + (a + 1) * cw), a * ((a + 1) + (a - 1) * cw - sq)]
            aa = [(a + 1) - (a - 1) * cw + sq, 2 * ((a - 1) - (a + 1) * cw), (a + 1) - (a - 1) * cw - sq]
    else:
        raise ValueError(kind)
    return np.array(b + aa, dtype=float)


def biquad(x, kind, f, q=0.707, gain_db=0.0):
    c = biquad_coef(kind, f, q, gain_db)
    return sps.lfilter(c[:3] / c[3], c[3:] / c[3], x, axis=0)


def peak(x, f, q, gain_db):
    return biquad(x, "peak", f, q, gain_db)


def reson(x, f, q):
    """恒定峰值增益的共振带通（中心频率处增益为 1）。"""
    return biquad(x, "bp", f, q)


def _curve(v, n):
    if np.ndim(v) == 0:
        return np.full(n, float(v))
    v = np.asarray(v, float)
    if len(v) == n:
        return v
    return np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(v)), v)


def sweep(x, kind, freq, q=0.707, stages=1, block=32):
    """随时间变化的二阶滤波（lp / hp / bp）：freq、q 为常数或曲线；每 block 个采样更新一次系数，
    滤波器状态跨块延续，所以扫频连续、不产生块边界的咔哒声。"""
    if x.ndim == 2:
        return np.stack([sweep(x[:, c], kind, freq, q, stages, block) for c in range(2)], axis=1)
    n = len(x)
    fr = _curve(freq, n)
    qq = _curve(q, n)
    nb = (n + block - 1) // block
    mid = np.minimum(np.arange(nb) * block + block // 2, n - 1)
    w0 = 2.0 * np.pi * np.clip(fr[mid], 10.0, NYQ * 0.98) / SR
    cw, sw = np.cos(w0), np.sin(w0)
    al = sw / (2.0 * np.maximum(qq[mid], 0.05))
    if kind == "lp":
        b = np.stack([(1 - cw) / 2, 1 - cw, (1 - cw) / 2], 1)
    elif kind == "hp":
        b = np.stack([(1 + cw) / 2, -(1 + cw), (1 + cw) / 2], 1)
    elif kind == "bp":
        b = np.stack([al, np.zeros(nb), -al], 1)
    else:
        raise ValueError(kind)
    a = np.stack([1 + al, -2 * cw, 1 - al], 1)
    b = b / a[:, :1]
    a = a / a[:, :1]
    y = np.asarray(x, float)
    for _ in range(stages):
        out = np.empty(n)
        zi = np.zeros(2)
        for k in range(nb):
            s0, s1 = k * block, min(n, (k + 1) * block)
            out[s0:s1], zi = sps.lfilter(b[k], a[k], y[s0:s1], zi=zi)
        y = out
    return y


# ---------------------------------------------------------------- 振荡器
def phase(freq, n=None):
    """瞬时频率（Hz，常数或曲线）积分得到的相位，单位为周。"""
    if np.ndim(freq) == 0:
        return np.arange(int(n)) * float(freq) / SR
    f = np.asarray(freq, float)
    return np.concatenate([[0.0], np.cumsum(f[:-1])]) / SR


def sine(freq, n=None, ph0=0.0):
    if n is None:
        n = len(freq)
    return np.sin(2.0 * np.pi * (phase(freq, n) + ph0))


def harm(freq, amps, n=None, ph0=None):
    """加法合成：第 k 次谐波幅度为 amps[k-1]；接近奈奎斯特频率的谐波逐渐衰减为零，不产生混叠。"""
    if n is None:
        n = len(freq)
    ph = phase(freq, n)
    fr = _curve(freq, n)
    out = np.zeros(n)
    for k, a in enumerate(amps, start=1):
        if a == 0.0:
            continue
        g = np.clip((0.45 * SR - k * fr) / (0.05 * SR), 0.0, 1.0)
        if not np.any(g > 0):
            break
        p0 = 0.0 if ph0 is None else ph0[k - 1]
        out += a * g * np.sin(2.0 * np.pi * (k * ph + p0))
    return out


def saw_amps(k, bright=1.0):
    return [1.0 / (i ** bright) for i in range(1, k + 1)]


def square_amps(k):
    return [(1.0 / i if i % 2 else 0.0) for i in range(1, k + 1)]


def tri_amps(k):
    return [((-1) ** ((i - 1) // 2) / (i * i) if i % 2 else 0.0) for i in range(1, k + 1)]


def pulse_amps(k, duty=0.25):
    return [abs(np.sin(np.pi * i * duty)) / i for i in range(1, k + 1)]


def fm(fc, ratio, index, n=None, fb=0.0, os_=4):
    """二算子调频：调制器频率 = 载波频率 × ratio；index 为调制指数（常数或曲线）。
    调频边带会越过奈奎斯特频率，所以在 os_ 倍采样率下合成再抗混叠降采样。"""
    if n is None:
        n = len(fc)
    m = n * os_
    f = np.repeat(_curve(fc, n), os_)
    pc = np.concatenate([[0.0], np.cumsum(f[:-1])]) / (SR * os_)
    mod = np.sin(2.0 * np.pi * pc * ratio)
    if fb:
        mod = np.sin(2.0 * np.pi * pc * ratio + fb * mod)
    y = np.sin(2.0 * np.pi * pc + np.repeat(_curve(index, n), os_) * mod)
    return sps.resample_poly(y, 1, os_)[:n] if os_ > 1 else y[:m]


# ---------------------------------------------------------------- 包络
def expdec(n, tau):
    return np.exp(-tt(int(n)) / max(tau, 1e-4))


def ad(n, a, tau):
    """线性起音 a 秒后按时间常数 tau 指数衰减。"""
    t = tt(int(n))
    e = np.exp(-np.maximum(t - a, 0.0) / max(tau, 1e-4))
    if a > 0:
        e *= np.clip(t / a, 0.0, 1.0)
    return e


def env(points, n, db=False):
    """分段包络，points 为 (秒, 值) 列表；db 为真时在对数域插值，衰减更自然。"""
    t = tt(int(n))
    xs = np.array([p[0] for p in points], float)
    ys = np.array([p[1] for p in points], float)
    if db:
        return np.exp(np.interp(t, xs, np.log(np.maximum(ys, 1e-5))))
    return np.interp(t, xs, ys)


def ahr(n, a, h, r):
    """起音、保持、余弦释放。"""
    t = tt(int(n))
    e = np.ones(int(n))
    if a > 0:
        e = np.minimum(e, np.clip(t / a, 0.0, 1.0))
    rr = np.clip((t - a - h) / max(r, 1e-4), 0.0, 1.0)
    return e * 0.5 * (1.0 + np.cos(np.pi * rr))


# ---------------------------------------------------------------- 失真
def sat(x, drive=2.0):
    return np.tanh(drive * x) / np.tanh(drive)


def asym(x, drive=2.0, bias=0.2):
    y = np.tanh(drive * (x + bias)) - np.tanh(drive * bias)
    m = np.max(np.abs(y))
    return y / m * np.max(np.abs(x)) if m > 0 else y


def fold(x, amt=2.0):
    return np.sin(0.5 * np.pi * amt * x)


def crush(x, bits=8, down=1):
    q = 2.0 ** (bits - 1)
    y = np.round(x * q) / q
    if down > 1:
        idx = (np.arange(len(y)) // down) * down
        y = y[idx]
    return y


# ---------------------------------------------------------------- 混响
## 空间预设：rt 为中频混响时间（秒），lo / hi 为低频与高频衰减时间的倍率，er 为早期反射（延时秒, 增益），
## pre 为预延迟，bright 为尾音上限频率，build 为扩散尾音的建立时间。
SPACES = {
    "yard": {"rt": 0.9, "lo": 1.1, "hi": 0.45, "er": [(0.017, 0.5), (0.031, 0.32), (0.052, 0.26), (0.083, 0.18)],
             "pre": 0.008, "bright": 7000.0, "build": 0.02},
    "valley": {"rt": 1.6, "lo": 1.25, "hi": 0.35, "er": [(0.045, 0.42), (0.11, 0.34), (0.19, 0.28), (0.31, 0.2), (0.47, 0.13)],
               "pre": 0.02, "bright": 5000.0, "build": 0.06},
    "hangar": {"rt": 2.1, "lo": 1.0, "hi": 0.6, "er": [(0.012, 0.45), (0.024, 0.38), (0.041, 0.3), (0.066, 0.22), (0.095, 0.16)],
               "pre": 0.01, "bright": 9000.0, "build": 0.04},
    "cockpit": {"rt": 0.28, "lo": 0.8, "hi": 0.6, "er": [(0.0023, 0.55), (0.0041, 0.45), (0.0067, 0.35), (0.0098, 0.25)],
                "pre": 0.001, "bright": 8000.0, "build": 0.004},
    "nest": {"rt": 1.2, "lo": 1.2, "hi": 0.3, "er": [(0.009, 0.4), (0.021, 0.3), (0.037, 0.22)],
             "pre": 0.005, "bright": 4000.0, "build": 0.03},
    "ui": {"rt": 0.18, "lo": 0.7, "hi": 0.8, "er": [(0.003, 0.3), (0.0071, 0.2)],
           "pre": 0.001, "bright": 12000.0, "build": 0.003},
}
_IR = {}


def impulse(kind, stereo, seed=0):
    """按空间预设合成的脉冲响应：三段频带各自指数衰减的噪声尾音 + 离散早期反射，能量归一。"""
    key = (kind, bool(stereo), seed)
    if key in _IR:
        return _IR[key]
    sp = SPACES[kind]
    rng = np.random.default_rng(seed_of("ir", kind, seed))
    rt = sp["rt"]
    n = ns(rt * max(sp["lo"], 1.0) * 1.15 + sp["pre"] + 0.02)
    t = tt(n)
    chans = []
    for c in range(2 if stereo else 1):
        w = rng.standard_normal(n)
        lo_b = lp(w, 250.0)
        hi_b = hp(w, 2500.0)
        mid_b = w - lo_b - hi_b

        def dec(r):
            return np.exp(-6.9078 * t / max(r, 1e-3))

        tail = lo_b * dec(rt * sp["lo"]) + mid_b * dec(rt) + hi_b * dec(rt * sp["hi"])
        tail = lp(tail, sp["bright"])
        tail *= 1.0 - np.exp(-t / max(sp["build"], 1e-4))
        pre = int(round(sp["pre"] * SR))
        tail = np.concatenate([np.zeros(pre), tail[: n - pre]])
        tail /= np.sqrt(np.sum(tail ** 2)) + 1e-12
        er = np.zeros(n)
        for dly, g in sp["er"]:
            j = int(round(dly * (1.0 + 0.07 * c * rng.uniform(-1.0, 1.0)) * SR))
            if j < n:
                er[j] += g * (1.0 if rng.random() > 0.3 else -1.0)
        er = lp(er, sp["bright"] * 0.8)
        ir = tail * 0.8 + er
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
        chans.append(ir)
    ir = np.stack(chans, 1) if stereo else chans[0]
    _IR[key] = ir
    return ir


def space(x, kind, wet=0.25, stereo=False, seed=0, dry=1.0, width=1.0):
    """把干声放进空间：干声保持原样（立体声时居中），湿声按空间预设卷积；
    stereo 为真时左右声道的湿声去相关，width 调整其宽度。输出长度包含混响尾音。"""
    ir = impulse(kind, stereo, seed)
    mono = x if x.ndim == 1 else x.mean(axis=1)
    if stereo:
        base = x if x.ndim == 2 else np.stack([x, x], 1)
        wl = sps.fftconvolve(mono, ir[:, 0])
        wr = sps.fftconvolve(mono, ir[:, 1])
        m, s = 0.5 * (wl + wr), 0.5 * (wl - wr) * width
        out = wet * np.stack([m + s, m - s], 1)
        out[: len(base)] += dry * base
        return out
    out = wet * sps.fftconvolve(mono, ir)
    out[: len(mono)] += dry * mono
    return out


# ---------------------------------------------------------------- 混音
class Mix:
    """按时间摆放的多层混音；pan 只在立体声渲染时生效（-1 左，1 右，等功率，居中与单声道等响）。"""

    def __init__(self, dur=None):
        self.items = []
        self.dur = dur

    def add(self, x, at=0.0, gain=1.0, pan=0.0):
        if x is None or len(x) == 0:
            return self
        self.items.append((np.asarray(x, float), max(0, int(round(at * SR))), float(gain), float(pan)))
        return self

    def render(self, stereo=False):
        n = max([o + len(x) for x, o, _, _ in self.items] + [ns(self.dur or 0.05)])
        out = np.zeros((n, 2)) if stereo else np.zeros(n)
        for x, o, g, p in self.items:
            m = len(x)
            if stereo:
                if x.ndim == 1:
                    a = (np.clip(p, -1.0, 1.0) + 1.0) * np.pi / 4.0
                    out[o:o + m, 0] += g * np.cos(a) * np.sqrt(2.0) * x
                    out[o:o + m, 1] += g * np.sin(a) * np.sqrt(2.0) * x
                else:
                    out[o:o + m] += g * x
            else:
                out[o:o + m] += g * (x if x.ndim == 1 else x.mean(axis=1))
        return out


# ---------------------------------------------------------------- 响度与限幅
def _kw(x):
    """K 加权：约 1.68 kHz 起 +4 dB 的高架 + 约 38 Hz 的高通，近似人耳对响度的频率权重。"""
    y = biquad(x, "highshelf", 1681.97, 0.7072, 4.0)
    return biquad(y, "hp", 38.135, 0.5003)


def loudness(x, win=0.4):
    """K 加权响度，取 win 秒滑动窗口的最大值（LUFS 刻度）。立体声取左右功率平均，
    所以左右相同的立体声与同样内容的单声道读数一致；短于窗口的声音按补零后的窗口计。"""
    y = _kw(x)
    p = y ** 2 if y.ndim == 1 else np.mean(y ** 2, axis=1)
    w = ns(win)
    if len(p) < w:
        p = np.concatenate([p, np.zeros(w - len(p))])
    c = np.concatenate([[0.0], np.cumsum(p)])
    hop = ns(0.01)
    idx = np.arange(0, len(p) - w + 1, hop)
    m = np.max((c[idx + w] - c[idx]) / w)
    return -0.691 + 10.0 * np.log10(m + 1e-20)


def _tp_env(x):
    """逐采样的真峰值包络：4 倍过采样后每个原采样位置取其 4 个子采样与原值的最大绝对值（立体声取两声道最大）。"""
    up = np.abs(sps.resample_poly(x, 4, 1, axis=0))
    n = len(x)
    up = up[: n * 4]
    if up.ndim == 2:
        up = up.max(axis=1)
    e = up.reshape(n, 4).max(axis=1)
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    return np.maximum(e, a)


def limit(x, ceil_db=-1.0, attack=0.0015, release=0.07):
    """前瞻真峰值限幅：增益曲线在峰值前 attack 秒内平滑压下、之后按 release 秒每 10 dB 线性回升，
    采样值与采样间的真峰值都不超过 ceil_db（真峰值按 4 倍过采样估计）。返回 (输出, 最大压缩量 dB)。"""
    ceil = 10.0 ** (ceil_db / 20.0)
    a = _tp_env(x)
    need = np.maximum(0.0, 20.0 * np.log10(np.maximum(a, 1e-12) / ceil))
    if need.max() <= 0.0:
        return x.copy(), 0.0
    n = len(need)
    w = max(1, ns(attack))
    pad = np.concatenate([np.zeros(w), need, np.zeros(w)])
    fmax = np.lib.stride_tricks.sliding_window_view(pad[w:], w + 1).max(axis=1)
    fmax = np.concatenate([np.zeros(w), fmax])[: n + w]
    c = np.concatenate([[0.0], np.cumsum(fmax)])
    sm = (c[w + 1: n + w + 1] - c[0: n]) / (w + 1)
    sm = np.maximum(sm, need)
    k = 10.0 / (release * SR)
    i = np.arange(n)
    gr = np.maximum.accumulate(sm + k * i) - k * i
    gr = np.maximum(gr, need)
    g = 10.0 ** (-gr / 20.0)
    y = x * (g if x.ndim == 1 else g[:, None])
    return np.clip(y, -ceil, ceil), float(gr.max())


def level(y, target, ceil_db=-1.0, max_gr=8.0):
    """增益对齐到响度目标并限幅；限幅会吃掉一点响度，所以迭代补偿，压缩量超过 max_gr 时整体退让。
    返回 (输出, 最大压缩量 dB, 施加的增益 dB)。"""
    g_db = target - loudness(y)
    z, gr = limit(y * 10.0 ** (g_db / 20.0), ceil_db)
    for _ in range(4):
        if gr > max_gr:
            g_db -= gr - max_gr
            z, gr = limit(y * 10.0 ** (g_db / 20.0), ceil_db)
            break
        err = target - loudness(z)
        if abs(err) < 0.2:
            break
        g_db += err
        z, gr = limit(y * 10.0 ** (g_db / 20.0), ceil_db)
    return z, gr, g_db


def fade_in(x, sec):
    m = min(len(x), max(2, ns(sec)))
    e = 0.5 - 0.5 * np.cos(np.pi * np.arange(m) / (m - 1))
    y = x.copy()
    y[:m] *= e if x.ndim == 1 else e[:, None]
    return y


def fade_out(x, sec):
    m = min(len(x), max(2, ns(sec)))
    e = 0.5 + 0.5 * np.cos(np.pi * np.arange(m) / (m - 1))
    y = x.copy()
    y[len(x) - m:] *= e if x.ndim == 1 else e[:, None]
    return y


def tail_end(x, floor_db=-64.0):
    """最后一个高于（峰值 + floor_db）的位置再留 30 毫秒。"""
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    thr = a.max() * 10.0 ** (floor_db / 20.0)
    idx = np.nonzero(a > thr)[0]
    if len(idx) == 0:
        return len(x)
    return min(len(x), idx[-1] + ns(0.03))


def master(x, target, ceil_db=-1.0, max_gr=8.0, hpf=25.0, fin=0.0008, fout=0.02, dur=None):
    """单次音效的母带：去直流 → 截掉低于峰值 64 dB 的尾巴（dur 为最长时长，超出时按时长的四分之一、
    最长 0.12 秒淡出）→ 首尾升余弦淡入淡出 → 响度对齐到 target 并限幅（压缩超过 max_gr 时整体退让响度）。
    限幅只乘增益，所以淡入淡出后为零的首尾采样保持为零；响度在最终波形上测量，与目标一致。"""
    y = hp(x, hpf, 2) if hpf else x.copy()
    end = tail_end(y)
    cut_long = False
    if dur is not None and end > ns(dur):
        end = ns(dur)
        cut_long = True
    y = y[:end]
    y = fade_in(y, fin)
    y = fade_out(y, min(0.12, 0.25 * len(y) / SR) if cut_long else fout)
    z, gr, g_db = level(y, target, ceil_db, max_gr)
    return z, {"dur": len(z) / SR, "lufs": loudness(z), "gain": g_db, "gr": gr}


def master_loop(x, period, reps, target, ceil_db=-1.0, max_gr=6.0, hpf=25.0):
    """循环音效的母带：x 的前 reps 遍是同一段内容的重复（其后可能还有混响尾音），取第 reps 遍
    （前面各遍让滤波与混响进入稳态），再按三遍圆周拼接做响度与限幅，只保留中间一遍，所以首尾严丝合缝、可以无限循环。"""
    y = hp(x, hpf, 2) if hpf else x.copy()
    seg = y[(reps - 1) * period: reps * period]
    tri = np.concatenate([seg, seg, seg], axis=0)
    z, gr, g_db = level(tri, target, ceil_db, max_gr)
    z = quiet_start(z[period: 2 * period])
    return z, {"dur": len(z) / SR, "lufs": loudness(np.concatenate([z, z], axis=0)), "gain": g_db, "gr": gr}


def quiet_start(z, win=0.01):
    """把一遍循环圆周平移，让第一个采样落在全遍能量最低处附近的过零点：循环本身首尾相接不变，
    而播放器从第 0 个采样起播时不会从波形中途突然开始。"""
    m = z if z.ndim == 1 else z.mean(axis=1)
    n = len(m)
    w = max(1, ns(win))
    e = np.concatenate([m ** 2, m[:w] ** 2])
    c = np.concatenate([[0.0], np.cumsum(e)])
    k = int(np.argmin(c[w: n + w] - c[0: n]))
    lo, hi = max(0, k - w), min(n - 1, k + w)
    zc = np.nonzero(np.signbit(m[lo:hi]) != np.signbit(m[lo + 1:hi + 1]))[0]
    if len(zc):
        j = lo + zc + 1
        k = int(j[np.argmin(np.abs(m[j]))])
    return np.roll(z, -k, axis=0)


def seam_ratio(z):
    """循环接缝处（末采样 → 首采样）的跳变与全段 99.9% 分位的相邻采样差之比，小于 1 说明接缝不比正常波形更突兀。"""
    m = z if z.ndim == 1 else z.mean(axis=1)
    d = np.abs(np.diff(m))
    q = np.quantile(d, 0.999) + 1e-12
    return float(abs(m[0] - m[-1]) / q)


def true_peak_db(z):
    """4 倍过采样估计的真峰值（dBFS）。"""
    m = z if z.ndim == 1 else z
    up = sps.resample_poly(m, 4, 1, axis=0)
    return 20.0 * np.log10(np.max(np.abs(up)) + 1e-12)


def write_wav(path, z):
    q = np.round(np.clip(z, -1.0, 1.0) * 32767.0).astype(np.int16)
    wavfile.write(path, SR, q)



# ---------------------------------------------------------------- 配方登记
RECIPES = {}


def sfx(sid, n=1, target=-18.0, dur=None, loop=None, reps=4, fout=0.02, fin=0.0008, hpf=25.0, max_gr=8.0):
    """登记一个音效配方：n 为变体数，target 为响度目标（LUFS，400 毫秒窗口最大值），dur 为最长时长（秒）；
    loop 为循环一遍的时长（秒）时按循环母带处理，reps 为合成时重复的遍数。"""
    def deco(fn):
        RECIPES[sid] = {"fn": fn, "n": n, "target": target, "dur": dur, "loop": loop, "reps": reps,
                        "fout": fout, "fin": fin, "hpf": hpf, "max_gr": max_gr}
        return fn
    return deco


class Ctx:
    """配方的输入：v 为变体序号（0 起），rng 为按 id 与变体固定种子的随机数，stereo 为是否输出立体声；
    循环配方另有 loop（一遍的秒数）、period（一遍的采样数）与 reps（重复遍数）。"""

    def __init__(self, sid, v, stereo, loop=None, reps=4):
        self.sid = sid
        self.v = v
        self.rng = np.random.default_rng(seed_of(sid, v))
        self.stereo = stereo
        self.loop = loop
        self.period = ns(loop) if loop else 0
        self.reps = reps

    def r(self, lo, hi):
        return float(self.rng.uniform(lo, hi))

    def j(self, x, amt=0.05):
        """x 按比例 amt 随机抖动。"""
        return x * (1.0 + self.r(-amt, amt))

    def pick(self, seq):
        return seq[int(self.rng.integers(len(seq)))]

    def noise(self, sec, slope=0.0):
        return colored(ns(sec), self.rng, slope)

    def seed(self):
        return int(self.rng.integers(1 << 30))

    # ---- 循环配方专用：一切成分都以一遍为周期，平铺 reps 遍
    @property
    def total(self):
        return self.period * self.reps

    def qf(self, f):
        """把频率量化成一遍时长的整数倍，正弦在接缝处相位连续。"""
        return max(1, round(f * self.loop)) / self.loop

    def pnoise(self, slope=0.0):
        return np.tile(colored(self.period, self.rng, slope), self.reps)

    def plfo(self, rate):
        """以一遍为周期的平滑随机曲线（约 -1..1，均值为零）。"""
        return np.tile(smooth_noise(self.period, self.rng, rate), self.reps)

    def ptile(self, x):
        """把任意长的一段（可以超过一遍，比如事件的余音）折叠进一遍再平铺，超出部分叠回开头，接缝连续。"""
        p = self.period
        y = np.zeros(p) if x.ndim == 1 else np.zeros((p, x.shape[1]))
        for k in range(0, len(x), p):
            seg = x[k:k + p]
            y[:len(seg)] += seg
        return np.tile(y, self.reps) if y.ndim == 1 else np.tile(y, (self.reps, 1))
