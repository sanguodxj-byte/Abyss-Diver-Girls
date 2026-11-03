# 物品 / 导航 / 设施像素图标（16×16 美术像素，左上受光，绘制后自动加 1px 黑描边）。
# 每个函数 f(c, tint) 在画布 c 上作画；tint 是物品主色（模块数据里的 color），没有则用默认。
# ICONS[id] = (函数, 默认主色)。同类物品（同一武器类型 / 底盘类型）至少靠轮廓或关键部件区分，不只靠换色。
from px_lib import (Cv, ramp, snap, mix, METAL, GUN, STEEL, AMB, BRASS, RED, GRN, BLU, CYN, PUR, OLIVE, BROWN, WOOD,
                    PAPER, SKIN, WHITE, CREAM, OUT, stencil)

ICONS = {}


def icon(id_, tint=None):
    def deco(f):
        ICONS[id_] = (f, tint)
        return f
    return deco


def T(tint, dflt):
    return ramp(tint if tint else dflt)


# ================================================================ 臂部武器（枪口朝右）
@icon("arm_mg")          # G-36 转管机炮：三管短转管 + 弹链
def _(c, t):
    c.srect(1, 5, 7, 5, GUN)
    c.rect(2, 6, 4, 1, GUN[3])
    c.rect(8, 6, 6, 1, METAL[2]); c.rect(8, 7, 6, 1, METAL[0]); c.rect(8, 8, 6, 1, METAL[2])
    c.rect(10, 5, 1, 5, METAL[1]); c.rect(14, 6, 1, 3, GUN[0])
    c.rect(3, 10, 2, 1, GUN[0])
    for i, (x, y) in enumerate([(4, 11), (3, 12), (4, 13), (3, 14)]):
        c.px(x, y, AMB[2] if i % 2 == 0 else AMB[1])


@icon("arm_gatling")     # GAU-6 六管转管炮：粗管束 + 两道箍环 + 弹鼓
def _(c, t):
    c.srect(1, 4, 6, 7, GUN)
    for j in range(5):
        c.rect(7, 4 + j + (1 if j > 1 else 0) * 0, 7, 1, METAL[2] if j % 2 == 0 else METAL[0])
    c.rect(7, 9, 7, 1, METAL[0])
    c.rect(9, 3, 1, 7, METAL[3]); c.rect(12, 3, 1, 7, METAL[3])
    c.rect(14, 4, 1, 5, GUN[1])
    c.sdisc(4, 12.5, 2.5, BRASS)


@icon("arm_hmg")         # HMG-24 重机枪：长细管 + 散热孔护套 + 弹箱 + 两脚架
def _(c, t):
    c.srect(1, 5, 7, 4, GUN)
    c.rect(3, 4, 3, 1, GUN[2])
    c.srect(8, 5, 4, 3, STEEL)
    for x in (9, 11):
        c.px(x, 6, OUT)
    c.rect(12, 6, 3, 1, METAL[2]); c.rect(12, 7, 3, 1, METAL[0])
    c.srect(2, 9, 4, 4, OLIVE)
    c.px(3, 10, AMB[2])
    c.line(10, 8, 9, 12, GUN[2]); c.line(11, 8, 12, 12, GUN[2])


@icon("arm_ac30")        # AC-30 机炮：单根粗炮管 + 开槽炮口制退器 + 抛壳
def _(c, t):
    c.srect(1, 5, 6, 6, GUN)
    c.rect(2, 7, 3, 1, AMB[1])
    c.srect(7, 6, 5, 3, METAL)
    c.srect(12, 5, 3, 5, GUN)
    c.px(13, 6, OUT); c.px(13, 8, OUT)
    c.rect(4, 12, 1, 2, AMB[2]); c.px(4, 11, AMB[3]); c.rect(6, 13, 2, 1, AMB[1])


@icon("arm_shotgun")     # SG-7 霰弹枪：木托 + 泵动护木 + 宽口径 + 红色霰弹
def _(c, t):
    c.srect(1, 7, 4, 3, WOOD)
    c.srect(4, 6, 4, 3, GUN)
    c.rect(8, 6, 6, 1, METAL[2]); c.rect(8, 7, 6, 1, METAL[1])
    c.rect(14, 6, 1, 2, OUT)
    c.srect(8, 8, 4, 2, WOOD)
    for x in (4, 7):
        c.rect(x, 11, 2, 3, RED[2]); c.rect(x, 13, 2, 1, BRASS[2])


@icon("arm_slug")        # SLG-12 独头枪：单根厚壁枪管 + 亮色膛线口 + 独头弹
def _(c, t):
    c.srect(1, 6, 5, 4, GUN)
    c.rect(2, 9, 2, 2, GUN[1])
    c.srect(6, 5, 8, 4, STEEL)
    c.rect(14, 6, 1, 2, AMB[2])
    c.rect(7, 7, 6, 1, STEEL[0])
    c.sdisc(10.5, 12, 1.6, METAL); c.rect(9, 12, 1, 2, BRASS[2])


@icon("arm_cannon")      # CN-105 短管炮：又短又粗的炮管 + 黑洞炮口 + 复进筒
def _(c, t):
    c.srect(1, 7, 4, 4, GUN)
    c.srect(5, 4, 7, 7, METAL)
    c.rect(6, 11, 5, 1, GUN[1])
    c.sdisc(13, 7.5, 2.5, GUN)
    c.disc(13.2, 7.5, 1.2, OUT)
    c.rect(6, 6, 4, 1, METAL[0]); c.rect(6, 8, 4, 1, METAL[0])


@icon("arm_flamer")      # FT-20 喷火器：红色燃料罐 + 软管 + 喷嘴 + 火焰
def _(c, t):
    c.srect(1, 4, 4, 9, RED)
    c.rect(2, 3, 2, 1, METAL[2])
    c.rect(1, 7, 4, 1, RED[0])
    c.line(5, 11, 7, 10, GUN[2])
    c.srect(6, 7, 5, 3, GUN)
    c.rect(11, 8, 1, 1, GUN[3])
    c.rect(12, 7, 1, 3, AMB[2]); c.rect(13, 6, 1, 5, AMB[1]); c.px(14, 8, RED[2]); c.px(14, 6, AMB[3]); c.px(13, 8, AMB[3])


@icon("arm_laser")       # LZ-42 聚焦激光器：浅色流线机身 + 青色聚焦环 + 亮透镜
def _(c, t):
    c.srect(1, 6, 7, 4, METAL)
    c.rect(2, 7, 4, 1, CYN[0])
    for i, x in enumerate(range(8, 13)):
        c.rect(x, 5 + (i % 2), 1, 6 - 2 * (i % 2), CYN[1] if i % 2 == 0 else GUN[1])
    c.rect(13, 6, 1, 4, CYN[2]); c.px(14, 7, WHITE); c.px(14, 8, CYN[2])


@icon("arm_rail")        # RG-9 轨道炮：上下双导轨 + 中间蓝色电弧
def _(c, t):
    c.srect(1, 5, 5, 6, GUN)
    c.rect(2, 7, 3, 2, BLU[1])
    c.rect(6, 4, 9, 2, METAL[2]); c.rect(6, 5, 9, 1, METAL[0])
    c.rect(6, 10, 9, 2, METAL[1]); c.rect(6, 11, 9, 1, METAL[0])
    for x, y in [(7, 7), (8, 8), (9, 7), (10, 8), (11, 7), (12, 8), (13, 7)]:
        c.px(x, y, BLU[2])
    c.px(14, 7, BLU[3]); c.px(14, 8, BLU[3])


@icon("arm_railgun")     # RG-85 电磁轨道炮：更长的导轨 + 电容线圈
def _(c, t):
    c.srect(1, 4, 4, 8, GUN)
    for x in (5, 7):
        c.rect(x, 4, 1, 8, BLU[1])
    c.rect(6, 5, 9, 1, METAL[2]); c.rect(6, 10, 9, 1, METAL[1])
    c.rect(8, 7, 7, 2, BLU[2]); c.rect(8, 8, 7, 1, BLU[1]); c.px(14, 7, BLU[3])


@icon("arm_arc")         # ARC-16 电弧发射器：双叉电极 + 闪电
def _(c, t):
    c.srect(1, 6, 6, 5, GUN)
    c.sdisc(5, 8.5, 2, CYN)
    c.rect(7, 5, 6, 1, BRASS[2]); c.rect(7, 11, 6, 1, BRASS[1])
    c.rect(12, 4, 2, 2, BRASS[2]); c.rect(12, 11, 2, 2, BRASS[1])
    for x, y in [(9, 7), (10, 8), (11, 7), (12, 9), (13, 8)]:
        c.px(x, y, CYN[2])
    c.px(10, 9, WHITE)


@icon("arm_mortar")      # MT-58 迫击炮：斜指天空的炮管 + 底座板
def _(c, t):
    c.rect(2, 12, 10, 2, GUN[1]); c.rect(2, 12, 10, 1, GUN[2])
    for i in range(7):
        c.rect(4 + i, 10 - i, 3, 2, METAL[1])
        c.px(4 + i, 10 - i, METAL[2])
    c.rect(11, 2, 3, 2, METAL[2]); c.px(13, 3, OUT)
    c.line(9, 7, 11, 11, GUN[2])


@icon("arm_drill")       # DR-11 钻探臂：螺旋钻头（近战）+ 琥珀警示马达
def _(c, t):
    c.srect(1, 5, 5, 6, GUN)
    c.rect(2, 6, 3, 1, AMB[2]); c.px(3, 8, AMB[1])
    for x in range(6, 15):
        h = max(0, (15 - x) // 2)
        for y in range(8 - h, 8 + h + (1 if x < 14 else 0)):
            c.px(x, y, METAL[2] if (x + y) % 3 == 0 else (METAL[1] if (x + y) % 3 == 1 else METAL[0]))
    c.px(14, 8, METAL[3])


@icon("arm_plasma")      # PL-66 等离子炮：紫色球形腔 + 散热鳍
def _(c, t):
    c.srect(1, 6, 4, 5, GUN)
    c.sdisc(7.5, 8.5, 3.2, PUR)
    c.px(7, 8, WHITE)
    c.srect(10, 7, 4, 3, GUN); c.rect(14, 7, 1, 3, PUR[2])
    for x in (11, 13):
        c.px(x, 6, GUN[2]); c.px(x, 10, GUN[2])


@icon("arm_grenade")     # GL-30 榴弹发射器：左轮式弹巢 + 粗短管 + 绿色榴弹
def _(c, t):
    c.srect(1, 7, 3, 3, GUN)
    c.sdisc(6, 8.5, 3, STEEL)
    for x, y in [(6, 6), (8, 8), (6, 10), (4, 8)]:
        c.px(x, y, OUT)
    c.srect(9, 6, 5, 4, GUN); c.rect(14, 7, 1, 2, OUT)
    c.sdisc(12, 13, 1.6, GRN); c.px(11, 13, BRASS[2])


@icon("arm_flak")        # FL-20 双联高射机炮：两根并列斜管 + 转座
def _(c, t):
    c.srect(2, 10, 7, 4, GUN)
    c.rect(3, 9, 5, 1, GUN[2])
    for i in range(7):
        c.rect(5 + i, 9 - i, 2, 1, METAL[2])
        c.rect(7 + i, 10 - i, 2, 1, METAL[1])
    c.px(12, 2, AMB[2]); c.px(14, 3, AMB[2])


@icon("arm_cryo")        # CR-18 低温喷射器：淡蓝球罐 + 喷嘴 + 冰晶
def _(c, t):
    c.sdisc(4, 8, 3.2, BLU)
    c.rect(3, 6, 2, 1, WHITE)
    c.srect(7, 7, 4, 3, METAL)
    c.rect(11, 8, 1, 1, CYN[1])
    for x, y in [(13, 6), (12, 8), (14, 8), (13, 10), (13, 8)]:
        c.px(x, y, CYN[2] if (x, y) != (13, 8) else WHITE)


@icon("arm_sniper")      # SR-70 反器材步枪：超长细管 + 瞄准镜 + 枪口制退器
def _(c, t):
    c.rect(1, 8, 2, 3, GUN[2])
    c.srect(2, 7, 5, 3, GUN)
    c.rect(7, 8, 7, 1, METAL[2])
    c.rect(13, 7, 2, 3, GUN[2])
    c.srect(3, 4, 5, 2, GUN); c.px(7, 4, BLU[2]); c.px(3, 4, BLU[1])
    c.rect(4, 6, 1, 1, GUN[1])
    c.line(10, 9, 9, 12, GUN[1]); c.line(10, 9, 11, 12, GUN[1])


# ================================================================ 背部挂载
@icon("back_cargo", (128, 107, 77))   # CG-10 载货背包
def _(c, t):
    r = T(t, (128, 107, 77))
    c.srect(3, 3, 10, 11, r)
    c.rect(3, 6, 10, 1, r[0])
    c.srect(5, 8, 6, 4, r)
    c.rect(7, 9, 2, 1, BRASS[2])
    c.rect(5, 2, 1, 2, r[0]); c.rect(10, 2, 1, 2, r[0])


@icon("back_rack")       # RK-4 外挂货架：金属格架 + 绑着的箱子
def _(c, t):
    for x in (2, 13):
        c.rect(x, 2, 1, 12, METAL[1])
    for y in (3, 8, 13):
        c.rect(2, y, 12, 1, METAL[2])
    c.srect(4, 4, 5, 4, OLIVE)
    c.srect(8, 9, 4, 4, WOOD)
    c.line(4, 6, 8, 6, AMB[1])


@icon("back_missile", (102, 115, 89))   # MS-6 导弹挂架：方形发射箱 2×3 + 红色弹头
def _(c, t):
    r = T(t, (102, 115, 89))
    c.srect(2, 4, 12, 9, r)
    for i in range(3):
        for j in range(2):
            x, y = 3 + i * 4, 5 + j * 4
            c.rect(x, y, 2, 2, OUT)
            c.px(x, y, RED[2])
    c.rect(2, 13, 12, 1, r[0])


@icon("back_rocket")     # RP-7 火箭巢：圆形蜂巢 + 琥珀弹头
def _(c, t):
    c.sdisc(8, 8, 6, OLIVE)
    for x, y in [(6, 5), (10, 5), (4, 8), (8, 8), (12, 8), (6, 11), (10, 11)]:
        c.rect(x - 1, y - 1, 2, 2, OUT)
        c.px(x - 1, y - 1, AMB[2])


@icon("back_vls")        # VLS-12 垂发单元：俯视 4×3 舱盖，一格打开
def _(c, t):
    c.srect(1, 3, 14, 10, STEEL)
    for i in range(4):
        for j in range(3):
            x, y = 2 + i * 3, 4 + j * 3
            c.rect(x, y, 2, 2, STEEL[0] if (i, j) != (2, 1) else OUT)
            if (i, j) != (2, 1):
                c.px(x, y, STEEL[2])
    c.px(9, 7, RED[2])


@icon("back_shield")     # SH-3 力场护盾：发射盘 + 蓝色六边护罩弧
def _(c, t):
    c.srect(5, 10, 6, 3, GUN)
    c.rect(7, 9, 2, 1, BLU[2])
    for x, y in [(3, 8), (3, 7), (4, 5), (5, 4), (6, 3), (7, 3), (8, 3), (9, 3), (10, 4), (11, 5), (12, 7), (12, 8)]:
        c.px(x, y, BLU[2])
    for x, y in [(5, 6), (7, 5), (9, 5), (10, 7), (6, 8), (8, 7)]:
        c.px(x, y, BLU[1])


@icon("back_cloak")      # CK-1 迷彩背件：数码迷彩板 + 向右渐隐
def _(c, t):
    for y in range(3, 13):
        for x in range(2, 14):
            if x > 9 and (x + y) % (14 - x if x < 13 else 2) == 0:
                continue
            v = (x * 7 + y * 13) % 5
            c.px(x, y, [OLIVE[1], OLIVE[2], GRN[0], OLIVE[1], (36, 37, 34)][v])
    c.rect(2, 3, 8, 1, OLIVE[3])


@icon("back_drone")      # DR-3 蜂群挂架：挂着三架小旋翼无人机
def _(c, t):
    c.rect(2, 12, 12, 2, GUN[1]); c.rect(2, 12, 12, 1, GUN[2])
    for x, y in [(4, 4), (11, 5), (7, 9)]:
        c.rect(x - 2, y, 5, 1, METAL[2])
        c.srect(x - 1, y + 1, 3, 2, GUN)
        c.px(x, y + 2, RED[2])


@icon("back_jump")       # JP-4 跳跃背包：双推进器 + 尾焰
def _(c, t):
    for x in (3, 9):
        c.srect(x, 2, 4, 8, STEEL)
        c.rect(x, 10, 4, 1, GUN[1])
        c.rect(x + 1, 11, 2, 1, AMB[3]); c.rect(x + 1, 12, 2, 1, AMB[2]); c.px(x + 1, 13, RED[2])
    c.rect(7, 4, 2, 3, GUN[2])


@icon("back_turret")     # TR-2 哨戒炮塔：底座 + 炮塔 + 炮管
def _(c, t):
    c.srect(3, 11, 9, 3, GUN)
    c.rect(6, 9, 3, 2, GUN[2])
    c.srect(4, 5, 7, 4, OLIVE)
    c.rect(11, 6, 4, 1, METAL[2]); c.rect(11, 7, 4, 1, METAL[0])
    c.px(6, 6, RED[2])


@icon("back_mines")      # MN-3 布雷背包：弹药箱 + 圆饼地雷（红灯）
def _(c, t):
    c.srect(2, 9, 12, 5, OLIVE)
    c.rect(4, 11, 8, 1, AMB[1])
    for x in (5, 11):
        c.sdisc(x, 6, 2.6, GUN)
        c.px(x - 1, 5, RED[2])


@icon("back_repair")     # RP-6 维修吊舱：吊舱 + 机械臂 + 绿十字
def _(c, t):
    c.srect(2, 6, 8, 8, METAL)
    c.rect(5, 8, 2, 4, GRN[2]); c.rect(4, 9, 4, 2, GRN[2])
    c.line(9, 6, 12, 3, GUN[2]); c.line(12, 3, 14, 5, GUN[2])
    c.px(14, 6, AMB[2])


# ================================================================ 动力炉
@icon("gen_cell", (255, 204, 51))     # B-40 电池组：两节黄色电池 + 闪电
def _(c, t):
    r = T(t, (255, 204, 51))
    for x in (3, 9):
        c.srect(x, 4, 5, 10, r)
        c.rect(x + 1, 3, 3, 1, METAL[2])
        c.rect(x, 7, 5, 1, r[0])
    c.px(5, 9, OUT); c.px(4, 10, OUT); c.px(5, 11, OUT)
    c.px(11, 9, OUT); c.px(10, 10, OUT); c.px(11, 11, OUT)


@icon("gen_reactor", (51, 230, 255))  # RT-1 动力炉：竖筒 + 青色发光核心窗
def _(c, t):
    c.srect(4, 2, 8, 12, STEEL)
    c.rect(3, 4, 10, 1, GUN[1]); c.rect(3, 11, 10, 1, GUN[1])
    c.rect(6, 5, 4, 6, OUT)
    c.rect(7, 6, 2, 4, CYN[1]); c.px(7, 6, CYN[3])


@icon("gen_crystal", (217, 77, 255))  # CR-8 反应炉：框架里的紫色晶体
def _(c, t):
    c.rect(3, 2, 10, 2, GUN[2]); c.rect(3, 12, 10, 2, GUN[1])
    c.rect(3, 4, 1, 8, GUN[1]); c.rect(12, 4, 1, 8, GUN[1])
    for y in range(4, 12):
        h = 3 - abs(y - 7.5) // 1.5
        c.rect(int(8 - h), y, int(2 * h), 1, PUR[1])
    c.rect(7, 5, 1, 4, PUR[2]); c.px(7, 5, WHITE)


@icon("gen_diesel")      # DS-6 柴油机组：机体 + 排气管 + 黑烟
def _(c, t):
    c.srect(2, 7, 10, 7, OLIVE)
    for x in (4, 6, 8):
        c.rect(x, 9, 1, 3, OLIVE[0])
    c.rect(11, 3, 2, 5, GUN[2])
    c.px(12, 1, (64, 66, 57)); c.px(13, 2, (78, 80, 72)); c.px(11, 2, (52, 53, 48))
    c.rect(2, 13, 10, 1, GUN[0])


@icon("gen_hfc")         # HFC-3 氢燃料堆：两只储氢罐 + H 字
def _(c, t):
    for x in (2, 9):
        c.srect(x, 3, 5, 10, METAL)
        c.rect(x + 1, 2, 3, 1, METAL[1])
    c.poly_rows(["1.1", "111", "1.1"], 3, 7, {"1": BLU[1]})
    c.poly_rows(["1.1", "111", "1.1"], 10, 7, {"1": BLU[1]})
    c.rect(7, 6, 2, 1, GUN[2]); c.rect(7, 10, 2, 1, GUN[2])


@icon("gen_turbine")     # TB-5 涡轮机组：圆形机匣 + 风扇叶片
def _(c, t):
    c.sdisc(8, 8, 6.5, STEEL)
    c.disc(8, 8, 4.6, GUN[0])
    for x, y in [(8, 4), (9, 5), (11, 7), (11, 8), (8, 11), (7, 10), (4, 8), (5, 7), (10, 6), (6, 10)]:
        c.px(x, y, METAL[2])
    c.rect(7, 7, 2, 2, AMB[2])


@icon("gen_fission")     # B-80 裂变动力炉：圆桶 + 辐射标志
def _(c, t):
    c.srect(3, 2, 10, 12, AMB)
    c.rect(3, 4, 10, 1, AMB[0]); c.rect(3, 11, 10, 1, AMB[0])
    c.rect(7, 7, 2, 2, OUT)
    c.rect(5, 5, 2, 2, OUT); c.rect(9, 5, 2, 2, OUT); c.rect(7, 9, 2, 1, OUT)


@icon("gen_abyss")       # AB-9 过载动力炉：暗紫核心 + 红色裂纹
def _(c, t):
    c.srect(2, 3, 12, 10, GUN)
    c.sdisc(8, 8, 4, PUR)
    c.line(6, 6, 8, 8, RED[2]); c.line(8, 8, 10, 7, RED[2]); c.line(8, 8, 9, 11, RED[2])
    c.rect(2, 2, 2, 1, RED[2]); c.rect(12, 2, 2, 1, RED[2])


@icon("gen_isotope")     # RT-9 同位素动力炉：铅罐 + 绿光窗
def _(c, t):
    c.srect(4, 3, 8, 11, GUN)
    c.rect(5, 2, 6, 1, GUN[2])
    c.rect(6, 6, 4, 5, GRN[0]); c.rect(7, 7, 2, 3, GRN[2]); c.px(7, 7, GRN[3])


@icon("gen_kinetic")     # K-2 动能回收炉：飞轮 + 辐条
def _(c, t):
    c.sdisc(8, 8, 6, METAL)
    c.ring(8, 8, 3.2, 4.4, GUN[1])
    c.line(8, 3, 8, 13, GUN[0]); c.line(3, 8, 13, 8, GUN[0])
    c.rect(7, 7, 2, 2, AMB[2])


# ================================================================ 躯干框架（tint = 模块主色）
def _core(c, t, kind, extra=""):
    r = T(t, (160, 160, 145))
    if kind == "round":
        c.sdisc(8, 8.5, 5.5, r)
        c.rect(5, 7, 6, 2, OUT); c.rect(7, 7, 2, 2, CYN[1]); c.px(7, 7, CYN[3])
        c.rect(1, 7, 2, 4, GUN[2]); c.rect(13, 7, 2, 4, GUN[2])
    elif kind == "box":
        c.srect(3, 3, 10, 10, r)
        c.rect(4, 6, 8, 2, OUT); c.rect(5, 6, 6, 1, CYN[1])
        c.rect(4, 10, 8, 1, r[0])
        c.rect(1, 5, 2, 6, GUN[2]); c.rect(13, 5, 2, 6, GUN[2])
    elif kind == "wedge":
        for y in range(3, 13):
            hw = 7 - max(0, y - 7)
            c.rect(8 - hw, y, hw * 2, 1, r[1] if y > 3 else r[2])
        c.rect(1, 3, 1, 4, r[2])
        c.rect(5, 6, 6, 2, OUT); c.rect(6, 6, 4, 1, RED[2])
    elif kind == "spike":
        c.srect(3, 4, 10, 9, r)
        c.poly_rows(["1....1", "11..11"], 5, 2, {"1": r[2]})
        c.rect(1, 4, 2, 2, r[2]); c.rect(13, 4, 2, 2, r[2])
        c.rect(5, 7, 6, 2, OUT); c.rect(6, 7, 1, 1, AMB[2]); c.rect(9, 7, 1, 1, AMB[2])
    elif kind == "cmd":
        c.srect(3, 5, 10, 9, r)
        c.rect(5, 8, 6, 2, OUT); c.rect(6, 8, 4, 1, GRN[2])
        c.rect(11, 1, 1, 4, METAL[2]); c.px(11, 1, RED[2])
        c.ring(5, 3.5, 1.2, 2.3, METAL[2])
    elif kind == "plate":
        c.srect(2, 3, 12, 11, r)
        c.srect(3, 4, 10, 4, r)
        c.rect(5, 9, 6, 2, OUT); c.rect(6, 9, 4, 1, AMB[2])
        c.rect(2, 12, 12, 1, r[0])
        for x in (3, 12):
            c.px(x, 5, METAL[3])
    if "wing" in extra:
        c.rect(0, 9, 3, 1, WHITE); c.rect(13, 9, 3, 1, WHITE)
    if "glow" in extra:
        c.px(8, 12, PUR[2]); c.px(7, 12, PUR[1])
    if "rack" in extra:
        c.rect(4, 13, 8, 1, BRASS[2])
    if "shield" in extra:
        c.rect(0, 4, 2, 8, STEEL[2])
        c.rect(14, 4, 2, 8, STEEL[1])
    if "relay" in extra:
        c.rect(4, 1, 1, 4, METAL[2]); c.px(4, 1, BLU[2])


for _id, _k, _ex, _t in [("core_scout", "round", "", (235, 184, 64)), ("core_std", "box", "", (77, 148, 217)),
                         ("core_heavy", "wedge", "", (199, 77, 61)), ("core_assault", "spike", "", (107, 87, 71)),
                         ("core_command", "cmd", "", (87, 97, 107)), ("core_fortress", "plate", "", (102, 107, 97)),
                         ("core_bastion", "plate", "shield", (179, 107, 51)), ("core_egret", "round", "wing", (217, 222, 230)),
                         ("core_abyss", "wedge", "glow", (115, 64, 153)), ("core_relay", "cmd", "relay", (102, 140, 179)),
                         ("core_odyssey", "box", "rack", (140, 140, 107))]:
    ICONS[_id] = ((lambda k, ex: (lambda c, t: _core(c, t, k, ex)))(_k, _ex), _t)


# ================================================================ 底盘
def _legs(c, t, kind):
    r = T(t, (140, 140, 128))
    if kind == "biped":
        c.srect(4, 2, 8, 3, r)
        for x in (4, 9):
            c.srect(x, 5, 3, 4, r); c.srect(x + (0 if x == 4 else 0), 9, 3, 3, r)
            c.px(x + 1, 9, OUT)
            c.rect(x - 1, 12, 5, 2, GUN[1]); c.rect(x - 1, 12, 5, 1, GUN[2])
    elif kind == "reverse":
        c.srect(4, 2, 8, 3, r)
        for x in (4, 9):
            c.line(x + 1, 5, x - 1, 8, r[1], 2)
            c.line(x - 1, 8, x + 2, 11, r[1], 2)
            c.px(x - 1, 8, AMB[2])
            c.rect(x, 12, 5, 2, GUN[1])
    elif kind == "tread":
        c.srect(4, 2, 8, 4, r)
        c.srect(1, 7, 14, 7, GUN)
        for x in (3, 6, 9, 12):
            c.sdisc(x + 0.5, 10.5, 1.5, METAL)
        for x in range(1, 15, 2):
            c.px(x, 7, GUN[3])
    elif kind in ("quad", "titan"):
        th = 2 if kind == "titan" else 1
        c.srect(3, 3, 10, 4 if kind == "quad" else 5, r)
        for x0, x1 in [(3, 1), (6, 5), (9, 10), (12, 14)]:
            c.line(x0, 7, x1, 13, r[1] if x0 in (6, 9) else r[2], th)
            c.rect(x1 - 1, 13, 2 + th, 1, GUN[1])
        if kind == "titan":
            c.rect(4, 4, 8, 1, AMB[2])
    elif kind == "hover":
        c.srect(2, 4, 12, 5, r)
        c.rect(3, 9, 3, 2, GUN[2]); c.rect(10, 9, 3, 2, GUN[2])
        for x in (3, 4, 5, 10, 11, 12):
            c.px(x, 11, CYN[1]); c.px(x, 12 + (x % 2), CYN[0])
    elif kind == "wraith":
        c.srect(5, 3, 6, 3, r)
        for x0, x1, kx in [(5, 1, 2), (7, 5, 4), (9, 11, 12), (11, 15, 14)]:
            c.line(x0, 6, kx, 9, r[2]); c.line(kx, 9, x1 if x1 < 15 else 14, 13, r[1])
    elif kind == "spring":
        c.srect(4, 2, 8, 3, r)
        for x in (4, 9):
            for y in range(5, 11):
                c.px(x + (y % 2) * 2, y, METAL[2]); c.px(x + 1, y, METAL[0] if y % 2 else METAL[1])
            c.rect(x - 1, 11, 5, 2, GUN[1])
    elif kind == "wheel":
        c.srect(3, 3, 10, 5, r)
        for x in (4.5, 11.5):
            c.sdisc(x, 10.5, 3, GUN)
            c.rect(int(x) - 1 + 0, 10, 1, 1, METAL[2])


for _id, _k, _t in [("legs_biped", "biped", (140, 140, 128)), ("legs_tread", "tread", (89, 97, 77)), ("legs_quad", "quad", (128, 107, 153)),
                    ("legs_hover", "hover", (217, 217, 230)), ("legs_reverse", "reverse", (140, 120, 90)), ("legs_titan", "titan", (92, 97, 87)),
                    ("legs_wraith", "wraith", (120, 128, 120)), ("legs_spring", "spring", (150, 140, 110)), ("legs_wheel", "wheel", (110, 110, 100))]:
    ICONS[_id] = ((lambda k: (lambda c, t: _legs(c, t, k)))(_k), _t)


# ================================================================ 食物
@icon("can_food")        # 罐头肉：锡罐 + 米色标签 + 红色肉块图
def _(c, t):
    c.srect(4, 3, 8, 11, METAL)
    c.rect(4, 6, 8, 5, PAPER[2]); c.rect(4, 10, 8, 1, PAPER[0])
    c.rect(6, 7, 4, 2, RED[2]); c.px(6, 7, RED[3])
    c.rect(4, 3, 8, 1, METAL[3]); c.rect(4, 13, 8, 1, METAL[0])


@icon("biscuit")         # 压缩饼干：砖块 + 针孔 + 包装封口
def _(c, t):
    c.srect(2, 4, 12, 8, BRASS)
    for x, y in [(4, 6), (7, 6), (10, 6), (5, 9), (8, 9), (11, 9)]:
        c.px(x, y, BRASS[0])
    c.rect(1, 6, 1, 4, PAPER[1]); c.rect(14, 6, 1, 4, PAPER[1])


@icon("water_tab")       # 净水片：铝箔泡罩板 + 蓝色药片
def _(c, t):
    c.srect(2, 3, 12, 10, METAL)
    for x in (4, 9):
        for y in (5, 9):
            c.rect(x, y, 3, 2, BLU[2]); c.px(x, y, BLU[3])


@icon("coffee")          # 旧世界咖啡豆：两颗咖啡豆 + 中线
def _(c, t):
    r = ramp((109, 59, 39))
    c.sdisc(6, 7, 4, r); c.line(4, 5, 7, 9, r[0])
    c.sdisc(10.5, 10, 3.5, r); c.line(9, 8, 12, 11, r[0])


# ================================================================ 杂物（升级材料）
@icon("circuit")         # 电路板：绿板 + 芯片 + 金色走线
def _(c, t):
    c.srect(1, 3, 14, 10, GRN)
    c.rect(4, 5, 4, 4, OUT); c.rect(5, 6, 2, 2, GUN[2])
    c.rect(10, 6, 2, 2, OUT)
    c.rect(3, 10, 9, 1, BRASS[3]); c.rect(9, 4, 1, 6, BRASS[3])
    for x in range(4, 8):
        c.px(x, 9, BRASS[2])


@icon("wire")            # 铜线卷：铜色线圈 + 线头
def _(c, t):
    c.ring(8, 8, 2.2, 6, BRASS[2])
    c.ring(8, 8, 3.3, 4.3, BRASS[1])
    c.ring(8, 8, 5.2, 6, BRASS[1])
    c.line(12, 12, 15, 14, BRASS[3])


@icon("bolts")           # 螺栓：六角螺栓 + 螺母
def _(c, t):
    c.srect(2, 2, 6, 3, METAL)
    c.rect(4, 5, 2, 8, METAL[1])
    for y in (6, 8, 10, 12):
        c.px(5, y, METAL[0])
    c.sdisc(11, 10, 3, METAL)
    c.rect(10, 9, 2, 2, OUT)


@icon("hdd")             # 旧世界硬盘：机壳 + 盘片 + 绿灯
def _(c, t):
    c.srect(2, 2, 12, 12, STEEL)
    c.sdisc(7.5, 7.5, 4, METAL)
    c.rect(7, 7, 1, 1, OUT)
    c.line(9, 10, 12, 6, GUN[0])
    c.px(12, 12, GRN[2])


@icon("toy")             # 发条玩具：小机器人 + 发条钥匙
def _(c, t):
    c.srect(4, 3, 6, 5, RED)
    c.rect(5, 5, 1, 1, OUT); c.rect(8, 5, 1, 1, OUT)
    c.srect(4, 8, 6, 4, BLU)
    c.rect(4, 12, 2, 2, GUN[2]); c.rect(8, 12, 2, 2, GUN[2])
    c.rect(10, 9, 2, 1, BRASS[2]); c.rect(12, 8, 2, 3, BRASS[3])


@icon("chitin")          # 虫甲壳：分节甲片
def _(c, t):
    r = ramp((110, 90, 120))
    for y in range(3, 14):
        hw = int(round((36 - ((y - 8) * 1.1) ** 2) ** 0.5)) if abs(y - 8) < 5.5 else 2
        c.rect(8 - hw, y, hw * 2, 1, r[1])
    for y in (5, 8, 11):
        c.rect(3, y, 10, 1, r[0])
    c.rect(4, 4, 3, 1, r[2]); c.rect(4, 7, 2, 1, r[2])


@icon("bug_crystal")     # 虫晶：青色晶簇
def _(c, t):
    for x0, h, w in [(4, 7, 3), (7, 11, 3), (10, 6, 3)]:
        for y in range(14 - h, 14):
            c.rect(x0, y, w, 1, CYN[1])
        c.px(x0 + 1, 14 - h, CYN[2])
        c.rect(x0, 15 - h, 1, h - 2, CYN[2])
        c.rect(x0 + w - 1, 15 - h, 1, h - 1, CYN[0])
    c.px(8, 4, WHITE)


# ================================================================ 档案（剧情收集品）
def _paper(c, r=PAPER, x=3, y=2, w=10, h=12):
    c.srect(x, y, w, h, r)


@icon("arch_blueprint")    # 手绘蓝图：蓝纸卷 + 白线
def _(c, t):
    c.srect(2, 3, 12, 10, BLU)
    c.rect(4, 5, 6, 1, WHITE); c.rect(4, 5, 1, 5, WHITE); c.rect(4, 9, 8, 1, BLU[2]); c.rect(9, 6, 1, 3, BLU[2])
    c.rect(12, 3, 2, 10, BLU[0]); c.rect(13, 3, 1, 10, BLU[2])


@icon("arch_child_drawing")  # 儿童画：白纸 + 太阳 + 小房子
def _(c, t):
    _paper(c, x=2, y=3, w=12, h=10)
    c.disc(5, 6, 1.8, AMB[2])
    c.rect(8, 8, 4, 3, RED[2]); c.poly_rows(["..1..", ".111.", "11111"], 7, 5, {"1": RED[1]})
    c.rect(3, 11, 10, 1, GRN[1])


@icon("arch_deep_record")  # 深井钻探记录：岩芯样管（分层）
def _(c, t):
    c.srect(5, 1, 6, 14, METAL)
    for y, col in [(3, (109, 59, 39)), (5, (135, 90, 72)), (7, (78, 80, 72)), (9, (60, 19, 20)), (11, (110, 50, 140))]:
        c.rect(6, y, 4, 2, col)
    c.rect(5, 1, 6, 1, METAL[3])


@icon("arch_duty_log")     # 值班日志：墨绿硬皮本 + 松紧带
def _(c, t):
    c.srect(3, 2, 10, 12, GRN)
    c.rect(3, 2, 1, 12, GRN[0])
    c.rect(10, 2, 1, 12, OUT)
    c.rect(5, 5, 4, 2, PAPER[2])


@icon("arch_flight_log")   # 航行日志残页：泛黄纸 + 撕边 + 横线
def _(c, t):
    r = ramp((212, 184, 150))
    c.srect(3, 2, 10, 12, r)
    for y in (4, 6, 8, 10):
        c.rect(4, y, 7, 1, r[0])
    for y in range(2, 14, 2):
        c.px(12, y, None if False else (0, 0, 0, 0))
    for y in range(3, 14, 3):
        c.px(12, y, (0, 0, 0, 0))
        c.px(11, y + 1, r[0])


@icon("arch_letter")       # 未寄出的信：信封 + 红色火漆
def _(c, t):
    c.srect(2, 4, 12, 9, PAPER)
    c.line(2, 4, 8, 9, PAPER[0]); c.line(13, 4, 8, 9, PAPER[0])
    c.sdisc(8, 9.5, 1.6, RED)


@icon("arch_manifest")     # 货运清单：夹板 + 勾选列表
def _(c, t):
    c.srect(3, 2, 10, 12, WOOD)
    c.rect(4, 4, 8, 9, PAPER[2])
    c.rect(6, 1, 4, 2, METAL[2])
    for y in (5, 8, 11):
        c.px(5, y, GRN[1]); c.rect(7, y, 4, 1, PAPER[0])


@icon("arch_observation")  # 水质记录：试管 + 浑水 + 标签
def _(c, t):
    for x in (5, 10):
        c.rect(x, 2, 3, 11, CYN[2]); c.rect(x, 2, 3, 1, METAL[2])
        c.rect(x, 8, 3, 4, (78, 80, 72) if x == 5 else GRN[1])
        c.px(x + 1, 13, CYN[2])
    c.rect(4, 5, 10, 1, PAPER[2])


@icon("arch_photo")        # 泛黄照片：宝丽来 + 天空 + 人影
def _(c, t):
    c.srect(2, 2, 12, 12, PAPER)
    c.rect(3, 3, 10, 8, (102, 103, 89)); c.rect(3, 3, 10, 3, (140, 138, 120))
    c.rect(7, 6, 2, 4, (52, 53, 48)); c.px(7, 5, (52, 53, 48)); c.px(8, 5, (52, 53, 48))


@icon("arch_research_note")  # 观测笔记：螺旋线圈本 + 星图点
def _(c, t):
    c.srect(4, 2, 10, 12, ramp((135, 90, 72)))
    for y in range(3, 13, 2):
        c.rect(2, y, 3, 1, METAL[2])
    c.rect(6, 4, 6, 6, PAPER[2])
    for x, y in [(7, 5), (10, 6), (8, 8)]:
        c.px(x, y, BLU[1])


@icon("arch_shift_log")    # 班次记录：打孔考勤卡
def _(c, t):
    c.srect(4, 1, 8, 14, PAPER)
    c.rect(4, 1, 3, 1, (0, 0, 0, 0))
    for y in range(4, 14, 2):
        c.rect(6, y, 4, 1, PAPER[0])
        if y % 4 == 0:
            c.px(8, y, OUT)


@icon("arch_tape")         # 录音磁带：卡带外壳 + 两个卷轴
def _(c, t):
    c.srect(1, 4, 14, 9, GUN)
    c.rect(3, 5, 10, 4, PAPER[2])
    c.disc(5.5, 7, 1.4, OUT); c.disc(10.5, 7, 1.4, OUT)
    c.rect(5, 10, 6, 2, GUN[0])


# ================================================================ 礼物
@icon("gift_chart")        # 航线图册：硬皮书 + 罗盘玫瑰
def _(c, t):
    c.srect(2, 2, 12, 12, ramp((26, 53, 50)))
    c.rect(2, 2, 2, 12, BRASS[1])
    c.poly_rows(["..1..", "..1..", "11211", "..1..", "..1.."], 6, 5, {"1": BRASS[3], "2": RED[2]})


@icon("gift_cocoa")        # 旧世界可可粉：棕色铁罐 + 米色标签
def _(c, t):
    r = ramp((109, 59, 39))
    c.srect(3, 3, 10, 11, r)
    c.rect(3, 2, 10, 2, BRASS[2])
    c.rect(3, 7, 10, 4, PAPER[2]); c.rect(6, 8, 4, 2, r[1])


@icon("gift_flask")        # 银质酒壶：弧形壶身 + 壶盖
def _(c, t):
    c.srect(3, 4, 10, 10, METAL)
    c.rect(3, 13, 10, 1, METAL[0])
    c.rect(6, 2, 4, 2, BRASS[2])
    c.rect(5, 6, 1, 6, METAL[3])


@icon("gift_watch")        # 铜壳怀表：表盘 + 指针 + 表链
def _(c, t):
    c.sdisc(8, 9, 5.5, BRASS)
    c.disc(8, 9, 3.8, PAPER[2])
    c.line(8, 9, 8, 6, OUT); c.line(8, 9, 10, 9, OUT)
    c.rect(7, 2, 2, 2, BRASS[2]); c.px(6, 1, BRASS[1]); c.px(9, 1, BRASS[1])


@icon("gift_wrench")       # 钨钢扳手：深色钢 + 开口
def _(c, t):
    for i in range(9):
        c.rect(3 + i, 12 - i, 2, 2, STEEL[1])
        c.px(3 + i, 12 - i, STEEL[2])
    c.srect(10, 1, 5, 5, STEEL)
    c.rect(12, 1, 2, 3, (0, 0, 0, 0))
    c.sdisc(3.5, 12.5, 2.2, STEEL)


@icon("fac_flask")         # 研究 / 实验室：锥形瓶
def _(c, t):
    r = T(t, (115, 217, 160))
    c.rect(6, 2, 4, 5, METAL[2]); c.rect(6, 2, 4, 1, METAL[3])
    for y in range(7, 14):
        hw = min(2 + (y - 7), 6)
        c.rect(8 - hw, y, hw * 2, 1, r[1] if y > 9 else METAL[2])
    c.px(5, 11, r[3])


@icon("fac_star")          # 天赋 / 训练：星形徽章
def _(c, t):
    r = T(t, (255, 206, 84))
    c.poly_rows(["......1......", ".....111.....", "1111111111111", ".11111111111.", "...1111111...", "...1111111...", "..111...111..", ".11.......11."],
                1, 3, {"1": r[1]})
    c.rect(7, 5, 1, 3, r[3])


# ================================================================ 货币
@icon("credit_s")          # 信用芯片（小）：蓝色小卡 + 金触点
def _(c, t):
    c.srect(3, 5, 10, 7, BLU)
    c.rect(5, 7, 3, 3, BRASS[2]); c.px(5, 7, BRASS[3])
    c.rect(9, 8, 3, 1, BLU[2])


@icon("credit_l")          # 信用芯片（大）：紫色大卡 + 大块金触点 + 全息条
def _(c, t):
    c.srect(1, 3, 14, 10, PUR)
    c.rect(3, 5, 5, 4, BRASS[2]); c.rect(4, 6, 3, 2, BRASS[1]); c.px(3, 5, BRASS[3])
    c.rect(9, 6, 4, 1, PUR[2]); c.rect(9, 8, 4, 1, PUR[2])
    c.rect(2, 11, 12, 1, CYN[1])


@icon("gold")              # 金条：两块叠放的梯形金锭
def _(c, t):
    for i in range(4):
        c.rect(1 + i, 13 - i, 9 - i * 2 + 4, 1, BRASS[2] if i < 3 else BRASS[3])
    for i in range(4):
        c.rect(5 + i, 9 - i, 9 - i * 2 + 1, 1, BRASS[2] if i < 3 else BRASS[3])
    c.rect(1, 13, 13, 1, BRASS[1]); c.rect(5, 9, 10, 1, BRASS[1])


# ================================================================ 消耗品
@icon("beacon")            # 呼叫信标：底座 + 天线 + 红灯 + 信号弧
def _(c, t):
    c.srect(4, 10, 8, 4, AMB)
    c.rect(7, 4, 2, 6, GUN[2])
    c.rect(7, 3, 2, 1, RED[2])
    c.px(4, 3, AMB[2]); c.px(3, 4, AMB[2]); c.px(3, 5, AMB[2])
    c.px(11, 3, AMB[2]); c.px(12, 4, AMB[2]); c.px(12, 5, AMB[2])


@icon("coolant_pack")      # 冷却剂罐：蓝色罐 + 雪花标
def _(c, t):
    c.srect(4, 3, 8, 11, BLU)
    c.rect(6, 1, 4, 2, METAL[2])
    c.poly_rows(["1.1", ".1.", "1.1"], 7, 7, {"1": WHITE})


@icon("energy_rod")        # 高能电池棒：斜放发光棒
def _(c, t):
    for i in range(9):
        c.rect(3 + i, 11 - i, 2, 2, AMB[2])
        c.px(3 + i, 11 - i, AMB[3])
    c.rect(2, 12, 3, 3, GUN[2])
    c.rect(12, 1, 3, 3, WHITE)


@icon("extract_barrier")   # 撤离屏障：双立柱 + 蓝色能量幕
def _(c, t):
    c.rect(2, 3, 2, 11, GUN[2]); c.rect(12, 3, 2, 11, GUN[2])
    c.rect(2, 2, 2, 1, AMB[2]); c.rect(12, 2, 2, 1, AMB[2])
    for y in range(4, 13):
        for x in range(4, 12):
            if (x + y) % 3 == 0:
                c.px(x, y, BLU[2])
            elif (x + y) % 3 == 1:
                c.px(x, y, BLU[1])


@icon("extract_flare")     # 撤离引导烟幕：绿色烟罐 + 烟
def _(c, t):
    c.srect(5, 7, 6, 7, GRN)
    c.rect(5, 6, 6, 1, METAL[2]); c.rect(5, 10, 6, 1, OUT)
    c.disc(7, 4, 2, GRN[3]); c.disc(10, 3, 1.6, GRN[2]); c.px(5, 2, GRN[2])


@icon("fuel_cell")         # 燃料电池：琥珀单节电池 + 刻度
def _(c, t):
    c.srect(5, 3, 6, 11, AMB)
    c.rect(6, 2, 4, 1, METAL[2])
    c.rect(5, 6, 6, 1, AMB[0]); c.rect(5, 10, 6, 1, AMB[0])
    c.rect(7, 7, 2, 2, WHITE)


@icon("repair_kit")        # 维修包：白色箱 + 红十字 + 提手
def _(c, t):
    c.srect(2, 5, 12, 9, PAPER)
    c.rect(6, 3, 4, 2, GUN[2])
    c.rect(7, 6, 2, 6, RED[2]); c.rect(5, 8, 6, 2, RED[2])


@icon("sonic_decoy")       # 声波诱饵信标：喇叭 + 声波弧
def _(c, t):
    c.srect(2, 5, 4, 6, GUN)
    c.poly_rows(["...1", "..11", "1111", "1111", "..11", "...1"], 5, 5, {"1": ramp((70, 120, 110))[1]})
    for x, y in [(11, 5), (12, 6), (12, 7), (12, 8), (11, 9), (13, 3), (14, 5), (14, 7), (14, 9), (13, 11)]:
        c.px(x, y, CYN[2] if x < 13 else CYN[1])


@icon("surge_cell")        # 超频电芯：紫色电芯 + 闪电
def _(c, t):
    c.srect(4, 3, 8, 11, PUR)
    c.rect(6, 2, 4, 1, METAL[2])
    c.poly_rows(["..1", ".11", "111", ".1.", "1.."], 6, 6, {"1": AMB[3]})


# ================================================================ 未知物品回退
@icon("unknown")
def _(c, t):
    c.srect(2, 3, 12, 11, WOOD)
    c.rect(2, 7, 12, 1, WOOD[0])
    stencil(c, "?", 7, 6, CREAM, gap=0)


# ================================================================ 底部导航（16×16）
@icon("nav_maintenance")   # 整备：机甲头盔 + 目镜
def _(c, t):
    c.srect(3, 3, 10, 9, METAL)
    c.rect(4, 6, 8, 2, OUT); c.rect(5, 6, 2, 1, AMB[2]); c.rect(9, 6, 2, 1, AMB[2])
    c.rect(2, 12, 12, 2, GUN[2])
    c.rect(7, 1, 2, 2, GUN[2])


@icon("nav_trade")         # 交易：信用币堆 + ¥
def _(c, t):
    for i, y in enumerate((11, 8, 5)):
        c.rect(3 + i, y, 9, 3, BRASS[1]); c.rect(3 + i, y, 9, 1, BRASS[3])
    c.sdisc(11, 5, 3.5, AMB)
    c.poly_rows(["1.1", ".1.", "111", ".1."], 10, 3, {"1": BRASS[0]})


@icon("nav_deploy")        # 降落：空投舱 + 降落伞
def _(c, t):
    c.poly_rows(["..111111..", ".11111111.", "1111111111"], 3, 1, {"1": AMB[2]})
    c.rect(3, 3, 10, 1, AMB[1])
    c.line(3, 4, 7, 9, CREAM); c.line(12, 4, 8, 9, CREAM)
    c.srect(6, 9, 4, 5, GUN)
    c.px(7, 11, AMB[2])


@icon("nav_skills")        # 技能：齿轮 + 扳手
def _(c, t):
    c.sdisc(7, 8, 5, METAL)
    for x, y in [(7, 2), (7, 13), (1, 8), (12, 8)]:
        c.rect(x, y, 1 if x in (1, 12) else 1, 1, METAL[1])
    c.rect(6, 2, 3, 1, METAL[2]); c.rect(6, 13, 3, 1, METAL[0]); c.rect(1, 7, 1, 3, METAL[2]); c.rect(12, 7, 1, 3, METAL[0])
    c.disc(7, 8, 2, OUT)
    for i in range(5):
        c.rect(9 + i, 14 - i, 2, 1, AMB[2])


@icon("nav_stash")         # 仓库：军绿板条箱
def _(c, t):
    c.srect(2, 4, 12, 10, OLIVE)
    c.rect(2, 8, 12, 1, OLIVE[0])
    c.rect(7, 4, 2, 10, OLIVE[0])
    c.rect(4, 6, 2, 1, AMB[2])
    c.rect(2, 3, 12, 1, OLIVE[3])


@icon("nav_codex")         # 图鉴：翻开的手册
def _(c, t):
    c.srect(1, 3, 7, 11, PAPER); c.srect(8, 3, 7, 11, PAPER)
    c.rect(7, 3, 2, 11, GUN[1])
    for y in (5, 7, 9):
        c.rect(2, y, 4, 1, PAPER[0]); c.rect(10, y, 4, 1, PAPER[0])
    c.rect(10, 11, 3, 1, AMB[1])


# 8×8 小图标（顶栏状态、地图标记），单独一张图集
SMALL = {}


def small(id_):
    def deco(f):
        SMALL[id_] = f
        return f
    return deco


@small("money")            # 信用点：琥珀硬币 + ¥
def _(c):
    c.sdisc(4, 4, 3.6, AMB)
    c.poly_rows(["1.1", ".1.", "111", ".1."], 3, 2, {"1": BRASS[0]})


@small("junk")             # 杂物：螺母
def _(c):
    c.sdisc(4, 4, 3.4, METAL)
    c.rect(3, 3, 2, 2, OUT)


@small("level")            # 等级：琥珀军衔箭头
def _(c):
    c.poly_rows(["...1...", "..111..", ".11.11.", "11...11", "...1...", "..111..", ".11.11."], 0, 0, {"1": AMB[2]})


@small("raid")             # 出击：准星
def _(c):
    c.ring(4, 4, 1.8, 3.2, CREAM)
    c.px(3, 0, CREAM); c.px(3, 7, CREAM); c.px(0, 3, CREAM); c.px(7, 3, CREAM)
    c.px(3, 3, RED[2])


@small("clock")            # 舰时：小表盘
def _(c):
    c.ring(4, 4, 2.6, 3.6, CREAM)
    c.rect(3, 2, 1, 2, CREAM); c.rect(4, 3, 2, 1, CREAM)


@small("extract")          # 撤离点：绿色旗
def _(c):
    c.rect(1, 0, 1, 8, CREAM)
    c.rect(2, 0, 4, 3, GRN[2]); c.rect(2, 3, 2, 1, GRN[1])


@small("poi")              # 遗迹 / 兴趣点：琥珀菱形
def _(c):
    c.poly_rows(["..1..", ".121.", "12221", ".121.", "..1.."], 1, 1, {"1": AMB[1], "2": AMB[3]})


@small("ship")             # 飞空艇「信天翁号」当前位置
def _(c):
    c.poly_rows([".1111..", "1222211", "1222221", ".1111..", "..1.1.."], 0, 1, {"1": AMB[1], "2": AMB[2]})


@small("lock")             # 未解锁战区：锁
def _(c):
    c.ring(4, 3, 1.2, 2.4, METAL[2])
    c.srect(1, 3, 6, 5, METAL)
    c.px(3, 5, OUT); c.px(4, 5, OUT)


@small("quest")            # 主线：琥珀星
def _(c):
    c.poly_rows(["...1...", "..111..", "1111111", ".11111.", ".1...1."], 0, 1, {"1": AMB[2]})
