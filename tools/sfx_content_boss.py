"""
Boss 与 Boss 形态虫群的音效配方。
三只 Boss 各有自己的体量与材质：赤湖巢母是湿润的巨腔与卵囊，裂谷铁甲王虫是金属化的厚甲与双柱巨足，
深渊母皇是深渊里的低频长鸣与裸露晶核。Boss 形态的虫群共用一套动作，按体量放大、放到更长的混响里。
"""
import numpy as np

from sfx_dsp import sfx, ns, tt, white, pink, brown, lp, hp, bp, peak, reson, sweep, phase, sine, harm, saw_amps, \
    expdec, ad, env, sat, space, Mix
from sfx_lib import tick, clank, modal, thump, crack, burst, whoosh, hiss, servo, debris, scrape, rattle, \
    roar, crackle, arc, buzz, tone, chime, bubbles, slime, crunch, bug_hiss, chitter, voice, scrabble, \
    PLATE, BAR, TUBE, HEAVY, BELL


def st(c, m, kind="valley", wet=0.3):
    return space(m.render(), kind, wet, c.stereo, c.v)


def boss_cry(c, dur, pts, form, env_pts, sub=0.5, rough=0.45, drive=2.0):
    """Boss 的胸腔共鸣：低八度成分与强饱和让体量压过普通虫鸣。"""
    return voice(c.rng, dur, pts, 0.02, (0.0, 22.0), rough, 55.0, form, 0.35, "pulse", 0.22, drive, sub, env_pts)


def glide_chime(freq, dur, tau, partials=((1.0, 1.0), (1.5, 0.35), (2.3, 0.2))):
    """频率随时间移动的钟体共鸣，高分音衰减更快。"""
    n = ns(dur)
    t = tt(n)
    f = np.asarray(freq, float)
    if f.ndim:
        f = np.interp(np.linspace(0.0, 1.0, n), np.linspace(0.0, 1.0, len(f)), f)
    x = np.zeros(n)
    for r, g in partials:
        x += g * np.sin(2 * np.pi * phase(f * r, n)) * np.exp(-t / max(tau / np.sqrt(r), 1e-3))
    return x * np.clip(t / 0.01, 0.0, 1.0)


# ====================================================================== 登场与部位
@sfx("boss_brood_roar", n=2, target=-12.5, dur=2.8, fout=0.4, max_gr=12, hpf=42.0)
def brood_roar(c):
    """巢母从菌毯里撑起身体：湿腔深处的低频咆哮、层层叠起的菌毯撕裂、卵囊挤压的气泡，尾音沉进巢穴的混响。"""
    rng = c.rng
    m = Mix(2.8)
    m.add(boss_cry(c, 2.2, [(0, 120.0), (0.28, 195.0), (0.62, 160.0), (1.0, 95.0)],
                   ((520.0, 5.0), (980.0, 6.0)), [(0, 0), (0.12, 1.0), (1.6, 0.55), (2.2, 0.0)], 0.6, 0.5), 0.0, 0.7)
    m.add(roar(rng, ns(2.4), 38.0, 900.0, 5.0, 0.6, -5.0) * env([(0, 0), (0.2, 0.8), (1.8, 0.4), (2.4, 0)], ns(2.4)), 0.0, 0.7)
    m.add(slime(rng, 0.9, 1400.0, 180.0, 1.2, 0.4, 0.9), 0.02, 0.45)
    m.add(bubbles(rng, 1.6, 16.0, 120.0, 600.0, 0.08), 0.1, 0.3)
    m.add(thump(rng, 72.0, 26.0, 1.4, 0.4, 0.06, 2.6, 0.3), 0.04, 0.55)
    m.add(bug_hiss(rng, 1.2, 1800.0, 7000.0, (2800.0, 4600.0), (0.5, 12.0)), 0.3, 0.15)
    return st(c, m, "nest", 0.34)


@sfx("boss_brood_hatch", n=2, target=-14.0, dur=1.8, fout=0.25, max_gr=12, hpf=42.0)
def brood_hatch(c):
    """卵囊裂开：囊壁被撑破的湿裂声、黏液泼洒、成群幼虫的第一声口器咔哒。"""
    rng = c.rng
    m = Mix(1.8)
    m.add(crack(rng, 0.12, 0.02, 400.0), 0.0, 0.4)
    m.add(slime(rng, 0.55, 1800.0, 200.0, 1.0, 0.3, 0.9), 0.0, 0.7)
    m.add(burst(rng, 0.5, 0.09, 80.0, 2200.0, -2.0, 0.002, 1.5), 0.02, 0.5)
    m.add(bubbles(rng, 0.9, 26.0, 150.0, 700.0, 0.1), 0.06, 0.35)
    m.add(chitter(rng, 0.7, 46.0, (2400.0, 5600.0)), 0.22, 0.4)
    m.add(chitter(rng, 0.5, 60.0, (3200.0, 7000.0)), 0.55, 0.25)
    m.add(thump(rng, 80.0, 34.0, 0.6, 0.18, 0.04, 1.8, 0.2), 0.0, 0.35)
    return st(c, m, "nest", 0.3)


@sfx("boss_king_roar", n=2, target=-11.5, dur=3.2, fout=0.45, max_gr=12, hpf=42.0)
def king_roar(c):
    """王虫撞开岩壁：金属化甲壳摩擦出的低频吼声、背甲板材的共振、脚下碎石被震落，尾音在裂谷里来回。"""
    rng = c.rng
    m = Mix(3.2)
    m.add(boss_cry(c, 2.6, [(0, 88.0), (0.25, 148.0), (0.6, 126.0), (1.0, 78.0)],
                   ((680.0, 4.0), (1500.0, 5.0)), [(0, 0), (0.1, 1.0), (1.9, 0.5), (2.6, 0.0)], 0.7, 0.55, 2.4), 0.0, 0.75)
    m.add(roar(rng, ns(2.8), 30.0, 700.0, 4.0, 0.55, -5.0) * env([(0, 0), (0.15, 0.9), (2.0, 0.45), (2.8, 0)], ns(2.8)), 0.0, 0.75)
    m.add(modal(rng, 118.0, HEAVY, 0.9, 2.4, 0.03, 0.8, 0.7), 0.05, 0.45)
    m.add(rattle(rng, 1.6, 22.0, 500.0, 3500.0, 0.6, 0.01), 0.15, 0.3)
    m.add(debris(rng, 2.0, 25.0, 0.7, 200.0, 3000.0, 0.6), 0.3, 0.25)
    m.add(hiss(rng, 1.0, 2500.0, 9000.0, 0.02, 0.2, 0.6, (4000.0, 7000.0), 4.0), 0.6, 0.12)
    return st(c, m, "valley", 0.36)


@sfx("boss_king_stomp", n=2, target=-12.0, dur=2.0, fout=0.3, max_gr=12, hpf=42.0)
def king_stomp(c):
    """双柱巨足砸地：第一记闷到胸口的冲击、另一条腿紧跟的第二记、岩面碎裂与久久不散的余震。"""
    rng = c.rng
    m = Mix(2.0)
    for t0, g in ((0.0, 1.0), (0.42, 0.85)):
        m.add(thump(rng, 62.0 * c.j(1.0, 0.05), 22.0, 1.0, 0.3, 0.06, 3.2, 0.3), t0, 0.9 * g)
        m.add(burst(rng, 0.6, 0.09, 30.0, 900.0, -3.0, 0.001, 2.4), t0, 0.65 * g)
        m.add(clank(rng, 160.0, 0.3, HEAVY, 1.0, 0.6, 0.8), t0, 0.45 * g)
        m.add(debris(rng, 0.9, 50.0, 0.3, 200.0, 4000.0, 0.55), t0 + 0.03, 0.4 * g)
    m.add(roar(rng, ns(1.4), 26.0, 300.0, 3.0, 0.4, -5.0) * expdec(ns(1.4), 0.5), 0.0, 0.4)
    src = lp(m.render(), 900.0)
    m2 = Mix(2.0)
    m2.add(src, 0.0, 1.0)
    m2.add(src, 0.34, 0.2)
    m2.add(src, 0.72, 0.1)
    return st(c, m2, "valley", 0.32)


@sfx("boss_king_core", n=1, target=-13.0, dur=2.6, fout=0.35, max_gr=12, hpf=42.0)
def king_core(c):
    """背甲裂开、晶核暴露：厚甲被从内部顶开的断裂声、碎片落地的金属声，晶核升起后稳定下来的嗡鸣。"""
    rng = c.rng
    m = Mix(2.6)
    m.add(clank(rng, 190.0, 0.4, HEAVY, 1.4, 0.7, 0.85), 0.0, 0.7)
    m.add(crunch(rng, 0.3, 80, 0.1, 800.0, 8000.0, 0.6, 200.0), 0.0, 0.55)
    m.add(burst(rng, 0.5, 0.07, 40.0, 1200.0, -2.0, 0.001, 1.8), 0.0, 0.5)
    n0 = ns(1.5)
    u = tt(n0) / 1.5
    m.add(glide_chime(420.0 + 260.0 * u, 1.5, 0.6, ((1.0, 1.0), (1.5, 0.4), (2.3, 0.2), (3.1, 0.1))), 0.3, 0.32)
    m.add(harm(96.0, [1.0, 0.5, 0.3], n0) * env([(0, 0), (0.4, 1), (1.5, 0.6)], n0), 0.3, 0.25)
    m.add(debris(rng, 1.4, 30.0, 0.4, 300.0, 5000.0, 0.5), 0.15, 0.35)
    return st(c, m, "valley", 0.34)


@sfx("boss_queen_roar", n=2, target=-12.0, dur=3.6, fout=0.5, max_gr=12, hpf=42.0)
def queen_roar(c):
    """母皇在竖井底部苏醒：比王虫更低的胸腔共鸣、竖井井壁把声音压回来的长混响、晶簇随声压颤动的高频。"""
    rng = c.rng
    m = Mix(3.6)
    m.add(boss_cry(c, 3.0, [(0, 62.0), (0.2, 104.0), (0.55, 88.0), (1.0, 55.0)],
                   ((420.0, 4.0), (900.0, 5.0)), [(0, 0), (0.12, 1.0), (2.2, 0.55), (3.0, 0.0)], 0.8, 0.5, 2.6), 0.0, 0.8)
    m.add(roar(rng, ns(3.2), 24.0, 520.0, 3.0, 0.55, -6.0) * env([(0, 0), (0.25, 0.85), (2.4, 0.5), (3.2, 0)], ns(3.2)), 0.0, 0.75)
    m.add(chime(1480.0, 2.4, 1.0, ((1.0, 1.0), (1.47, 0.4), (2.1, 0.25))), 0.4, 0.12)
    m.add(slime(rng, 0.8, 1200.0, 160.0, 1.0, 0.35, 0.8), 0.05, 0.35)
    m.add(bubbles(rng, 2.0, 12.0, 100.0, 500.0, 0.08), 0.3, 0.22)
    return st(c, m, "valley", 0.4)


@sfx("boss_queen_wail", n=2, target=-12.5, dur=3.6, fout=0.5, max_gr=12, hpf=42.0)
def queen_wail(c):
    """阶段长鸣：音高从胸腔一路拔到颅顶的哀鸣、颤音在尾段散开、湿腔与晶体的泛音一起拖长。"""
    rng = c.rng
    m = Mix(3.6)
    m.add(boss_cry(c, 3.2, [(0, 90.0), (0.35, 240.0), (0.62, 420.0), (0.8, 300.0), (1.0, 120.0)],
                   ((700.0, 5.0), (1600.0, 6.0)), [(0, 0), (0.15, 0.9), (2.4, 0.6), (3.2, 0.0)], 0.55, 0.6, 2.2), 0.0, 0.75)
    n0 = ns(3.2)
    u = tt(n0) / 3.2
    m.add(glide_chime(660.0 * (1.0 + 0.6 * u), 3.0, 0.9, ((1.0, 1.0), (1.5, 0.35), (2.2, 0.2))), 0.15, 0.18)
    m.add(bug_hiss(rng, 2.6, 1500.0, 7000.0, (2600.0, 5000.0), (0.45, 9.0)), 0.2, 0.2)
    m.add(roar(rng, n0, 30.0, 600.0, 3.0, 0.4, -6.0) * env([(0, 0), (0.4, 0.7), (2.4, 0.35), (3.2, 0)], n0), 0.0, 0.5)
    return st(c, m, "valley", 0.4)


@sfx("boss_queen_core", n=1, target=-13.0, dur=2.8, fout=0.4, max_gr=12, hpf=42.0)
def queen_core(c):
    """胸口晶核暴露：覆盖晶核的甲片被剥开的碎裂、晶体暴露后第一声干净的鸣响、低频的压力从下方顶上来。"""
    rng = c.rng
    m = Mix(2.8)
    m.add(crunch(rng, 0.35, 90, 0.12, 2000.0, 12000.0, 0.4, 260.0), 0.0, 0.55)
    m.add(slime(rng, 0.5, 1600.0, 220.0, 1.2, 0.25, 0.7), 0.0, 0.5)
    m.add(chime(520.0, 2.4, 0.9, ((1.0, 1.0), (1.5, 0.45), (2.0, 0.25), (2.7, 0.12))), 0.18, 0.4)
    m.add(chime(780.0, 2.0, 0.7, ((1.0, 0.6), (1.5, 0.3))), 0.22, 0.18)
    m.add(roar(rng, ns(2.2), 28.0, 420.0, 3.0, 0.4, -6.0) * expdec(ns(2.2), 0.9), 0.0, 0.45)
    m.add(debris(rng, 1.6, 28.0, 0.5, 600.0, 9000.0, 0.4), 0.1, 0.3)
    return st(c, m, "valley", 0.38)


@sfx("boss_phase_shift", n=2, target=-12.5, dur=2.0, fout=0.3, max_gr=12, hpf=42.0)
def phase_shift(c):
    """阶段切换：整片甲壳与晶簇同时崩开、冲击波把碎石扫出去、低频一路下坠到底。"""
    rng = c.rng
    m = Mix(2.0)
    m.add(crunch(rng, 0.4, 120, 0.12, 600.0, 12000.0, 0.6, 180.0), 0.0, 0.7)
    for k in range(6):
        m.add(clank(rng, 180.0 + 120.0 * k, 0.25, HEAVY, 0.9, 0.6, 0.6), 0.01 * k, 0.3)
    m.add(thump(rng, 70.0, 22.0, 1.2, 0.35, 0.06, 2.8, 0.3), 0.0, 0.7)
    m.add(whoosh(rng, 1.0, 2400.0, 120.0, 0.12, 1.2, -3.0, 1.8), 0.0, 0.45)
    n0 = ns(1.6)
    m.add(sweep(white(n0, rng), "bp", np.geomspace(6000.0, 200.0, n0), 1.2) * expdec(n0, 0.5), 0.0, 0.3)
    m.add(debris(rng, 1.3, 60.0, 0.4, 200.0, 7000.0, 0.5), 0.03, 0.4)
    return st(c, m, "valley", 0.34)


# ====================================================================== Boss 形态的虫群动作
BOSS_KINDS = {
    "broodmother": {"mat": "brood", "f0": 165.0, "form": ((480.0, 4.0), (1050.0, 5.0)), "body": 62.0,
                    "t": {"appear": -15.5, "windup": -15.5, "attack": -13.5, "hurt": -15.0, "death": -12.5}},
    "king_beetle": {"mat": "king", "f0": 120.0, "form": ((360.0, 3.5), (820.0, 4.5)), "body": 55.0,
                    "t": {"appear": -15.5, "windup": -15.5, "attack": -13.5, "hurt": -15.0, "death": -12.5}},
    "abyss_queen": {"mat": "queen", "f0": 150.0, "form": ((420.0, 4.0), (960.0, 5.0)), "body": 50.0,
                    "t": {"appear": -15.0, "windup": -15.5, "attack": -13.0, "hurt": -14.5, "death": -12.0}},
}
BOSS_DUR = {"appear": 1.8, "windup": 1.2, "attack": 1.0, "hurt": 0.9, "death": 2.8}
BOSS_FOUT = {"appear": 0.2, "windup": 0.15, "attack": 0.15, "hurt": 0.12, "death": 0.35}


def _register_boss_bug(kind, K):
    mat = K["mat"]
    P = BOSS_KINDS[kind]

    @sfx("bug_%s_appear" % kind, n=2, target=P["t"]["appear"], dur=BOSS_DUR["appear"], fout=BOSS_FOUT["appear"], max_gr=12, hpf=42.0)
    def appear(c, K=K, mat=mat):
        rng = c.rng
        m = Mix(BOSS_DUR["appear"])
        m.add(thump(rng, K["body"] * 1.3, K["body"] * 0.5, 1.0, 0.28, 0.05, 2.4, 0.25), 0.0, 0.6)
        m.add(roar(rng, ns(1.4), 30.0, 700.0, 4.0, 0.5, -5.0) * env([(0, 0), (0.3, 0.8), (1.4, 0)], ns(1.4)), 0.0, 0.5)
        if mat == "brood":
            m.add(slime(rng, 0.7, 1200.0, 180.0, 1.2, 0.3, 0.8), 0.02, 0.5)
            m.add(bubbles(rng, 1.2, 16.0, 120.0, 600.0, 0.08), 0.1, 0.3)
        elif mat == "king":
            m.add(clank(rng, 150.0, 0.35, HEAVY, 1.2, 0.65, 0.85), 0.0, 0.5)
            m.add(rattle(rng, 1.0, 20.0, 400.0, 3000.0, 0.45, 0.01), 0.05, 0.3)
        else:
            m.add(slime(rng, 0.6, 1400.0, 160.0, 1.1, 0.3, 0.7), 0.0, 0.45)
            m.add(chime(760.0, 1.4, 0.5, ((1.0, 1.0), (1.5, 0.35), (2.3, 0.2))), 0.1, 0.2)
        m.add(boss_cry(c, 1.2, [(0, K["f0"]), (0.5, K["f0"] * 1.35), (1.0, K["f0"] * 0.9)],
                       K["form"], [(0, 0), (0.2, 1), (1.2, 0)], 0.6, 0.5, 2.0), 0.15, 0.45)
        return st(c, m, "valley", 0.3)

    @sfx("bug_%s_windup" % kind, n=2, target=P["t"]["windup"], dur=BOSS_DUR["windup"], fout=BOSS_FOUT["windup"], max_gr=12, hpf=42.0)
    def windup(c, K=K, mat=mat):
        rng = c.rng
        m = Mix(BOSS_DUR["windup"])
        n0 = ns(1.1)
        u = tt(n0) / 1.1
        m.add(roar(rng, n0, 35.0, 600.0, 3.0, 0.45, -5.0) * u, 0.0, 0.45)
        if mat == "brood":
            m.add(slime(rng, 0.5, 1400.0, 200.0, 1.2, 0.2, 0.7), 0.0, 0.4)
            m.add(bubbles(rng, 0.9, 18.0, 120.0, 600.0, 0.1), 0.1, 0.25)
        elif mat == "king":
            m.add(servo(rng, 0.8, 90.0, 260.0, 0.7, 0.1, 5.0, 0.35), 0.0, 0.35)
            m.add(clank(rng, 130.0, 0.2, HEAVY, 0.9, 0.6, 0.8), 0.15, 0.35)
        else:
            m.add(chime(900.0, 1.1, 0.4, ((1.0, 1.0), (1.5, 0.3))) * u, 0.0, 0.25)
            m.add(bug_hiss(rng, 0.9, 1500.0, 7000.0, (2600.0, 4800.0), (0.4, 14.0)), 0.05, 0.22)
        m.add(boss_cry(c, 0.9, [(0, K["f0"] * 0.9), (1.0, K["f0"] * 1.25)], K["form"],
                       [(0, 0), (0.25, 1), (0.9, 0)], 0.6, 0.5, 2.0), 0.15, 0.4)
        return st(c, m, "valley", 0.28)

    @sfx("bug_%s_attack" % kind, n=2, target=P["t"]["attack"], dur=BOSS_DUR["attack"], fout=BOSS_FOUT["attack"], max_gr=12, hpf=42.0)
    def attack(c, K=K, mat=mat):
        rng = c.rng
        m = Mix(BOSS_DUR["attack"])
        m.add(thump(rng, K["body"] * 1.1, K["body"] * 0.42, 0.9, 0.24, 0.04, 2.8, 0.3), 0.0, 0.8)
        m.add(burst(rng, 0.6, 0.08, 35.0, 1200.0, -2.5, 0.001, 2.0), 0.0, 0.6)
        if mat == "brood":
            m.add(slime(rng, 0.45, 2000.0, 220.0, 1.2, 0.18, 0.8), 0.0, 0.6)
            m.add(bubbles(rng, 0.5, 30.0, 150.0, 700.0, 0.1), 0.05, 0.25)
        elif mat == "king":
            m.add(clank(rng, 170.0, 0.3, HEAVY, 1.1, 0.7, 0.9), 0.0, 0.6)
            m.add(crunch(rng, 0.2, 40, 0.05, 700.0, 6000.0, 0.5, 250.0), 0.0, 0.3)
        else:
            m.add(crunch(rng, 0.25, 70, 0.07, 1500.0, 11000.0, 0.4, 220.0), 0.0, 0.45)
            m.add(chime(620.0, 1.0, 0.4, ((1.0, 1.0), (1.6, 0.3))), 0.0, 0.2)
        m.add(debris(rng, 0.8, 40.0, 0.3, 200.0, 4000.0, 0.5), 0.05, 0.3)
        return st(c, m, "valley", 0.32)

    @sfx("bug_%s_hurt" % kind, n=2, target=P["t"]["hurt"], dur=BOSS_DUR["hurt"], fout=BOSS_FOUT["hurt"], max_gr=12, hpf=42.0)
    def hurt(c, K=K, mat=mat):
        rng = c.rng
        m = Mix(BOSS_DUR["hurt"])
        if mat == "king":
            m.add(clank(rng, 240.0, 0.22, HEAVY, 0.8, 0.7, 0.8), 0.0, 0.65)
        elif mat == "queen":
            m.add(crunch(rng, 0.15, 30, 0.04, 1800.0, 11000.0, 0.3, 260.0), 0.0, 0.45)
            m.add(chime(880.0, 0.6, 0.22, ((1.0, 1.0), (1.6, 0.3))), 0.0, 0.25)
        else:
            m.add(slime(rng, 0.3, 1600.0, 200.0, 1.2, 0.12, 0.6), 0.0, 0.55)
        m.add(thump(rng, K["body"], K["body"] * 0.45, 0.5, 0.14, 0.02, 2.2, 0.2), 0.0, 0.45)
        m.add(boss_cry(c, 0.55, [(0, K["f0"] * 1.1), (1.0, K["f0"] * 0.8)], K["form"],
                       [(0, 0), (0.2, 0.8), (0.55, 0)], 0.6, 0.5, 2.0), 0.02, 0.35)
        return st(c, m, "valley", 0.26)

    @sfx("bug_%s_death" % kind, n=2, target=P["t"]["death"], dur=BOSS_DUR["death"], fout=BOSS_FOUT["death"], max_gr=12, hpf=42.0)
    def death(c, K=K, mat=mat):
        rng = c.rng
        m = Mix(BOSS_DUR["death"])
        m.add(thump(rng, K["body"] * 0.9, K["body"] * 0.32, 1.6, 0.45, 0.08, 2.8, 0.3), 0.0, 0.8)
        m.add(roar(rng, ns(2.0), 26.0, 500.0, 3.0, 0.45, -6.0) * env([(0, 0), (0.3, 0.8), (2.0, 0)], ns(2.0)), 0.0, 0.55)
        if mat == "brood":
            m.add(slime(rng, 0.9, 1400.0, 160.0, 1.0, 0.35, 0.8), 0.0, 0.55)
            m.add(bubbles(rng, 1.2, 18.0, 100.0, 500.0, 0.08), 0.2, 0.3)
        elif mat == "king":
            m.add(clank(rng, 150.0, 0.6, HEAVY, 2.0, 0.65, 0.9), 0.0, 0.55)
            m.add(rattle(rng, 1.6, 18.0, 300.0, 3000.0, 0.7, 0.012), 0.15, 0.35)
        else:
            m.add(crunch(rng, 0.5, 90, 0.15, 1200.0, 12000.0, 0.5, 200.0), 0.0, 0.5)
            m.add(chime(520.0, 2.2, 0.8, ((1.0, 1.0), (1.5, 0.4), (2.2, 0.2))), 0.2, 0.25)
        m.add(debris(rng, 1.8, 35.0, 0.6, 180.0, 6000.0, 0.55), 0.15, 0.4)
        m.add(boss_cry(c, 1.4, [(0, K["f0"] * 1.1), (0.4, K["f0"] * 0.9), (1.0, K["f0"] * 0.6)], K["form"],
                       [(0, 0), (0.15, 1), (1.4, 0)], 0.65, 0.55, 2.2), 0.1, 0.4)
        return st(c, m, "valley", 0.36)


for _kind, _K in BOSS_KINDS.items():
    _register_boss_bug(_kind, _K)

del _kind, _K
