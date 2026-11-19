# 全仓 3D 建模低面数全面排查与禁止清单

> **排查日期**：2026-11-19  
> **排查原则**：**任何面向玩家可见的 3D 模型均禁止出现低面数、多边形棱角外露、裸原语拼装或灰盒占位**。  
> **排查范围**：全仓所有 3D 程序化建模脚本（共扫描定位 **172 个** 含低面数特征的 `.gd` 文件）+ `assets/models/boss/` 全部 7 个 `.glb` 外部资产。  
> **关联文档**：本清单与 [modeling_polish_todo.md](modeling_polish_todo.md) 互补；后者记录既有造型批次进度，本文档聚焦**全仓低面数红线排查与彻底清零清单**。

---

## 一、排查总览与量化统计

### 1.1 全仓问题分布总表

> 说明：统计已按几何半径与结构语义分离，将 **微小六角螺栓/铆钉（`r ≤ 0.03m, seg = 6`）** 单独计列（`1,461` 处），不与真实低面数曲面混淆；`VIS_LOW` 表示 **可见曲面分段不足**（`cyl/sphere < 16` 或 `torus < 20` 或硬编码低段 `capsule`）。

| 模块大类 | 涉及文件数 | 可见低分段曲面 (`VIS_LOW`) | 低分段管线 (`A.tube` 默认7边/低段) | 低分段软管 (`A.hose` 7边+8边球帽) | 裸原语 (`Box/Prism/Sphere/Cyl`) | 零倒角块 (`bevel=0`) | 低面数力场 (`reactive_arc`) | 严重程度 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **底层几何库** (`art.gd` / `kit.gd` / `bug.gd` / `models.gd`) | 4 | 10+（源头放大全图） | 全局默认 `seg=7` | 全局 `seg=7` + 8边帽 | 5（库内+`_ball`） | — | 全局默认 `5×14` | **P0 根因** |
| **导弹 / 火箭 / 炮弹 / 弹药 / 发射巢** (`raid.gd` 弹药段 / `hazards.gd` / `weapon_fx.gd` / `back_*` / 发射臂) | 15 | **216+**（含 `raid.gd` 44 处） | 3 | 3 | **4**（方块弹壳/弹托/单三棱柱碎屑/裸Box尾翼） | 0 | 0 | **P0 重点** |
| **技能与战术部署装置** (`extract_barrier` / `decoy_beacon` / `slow_web` / `mech` / `enemy` / `weapon_fx` / `back_shield`) | 7 | **9** + 大量裸盒占位 | 2（4/5边折线棒） | 1 | 0 | 0 | **3**（5×14 / 4×12 / 3×10） | **P0 重点** |
| **建筑预制体与远景城区** (`scripts/buildings/*.gd` / `buildings_ext.gd` / `raid.gd` 远景&窄楼 / `menu_city.gd`) | 32 | **1,146**（含 89 处 5~7 边枯树灌木） | 0 | 0 | **1**（`menu_city` 裸 `BoxMesh`） | 0 | 0 | **P1 重点** |
| **遗迹 POI 与战区/首领地标** (`map_ext/poi/*.gd` / `poi_kit.gd` / `landmarks*.gd`) | 15 | **79**（含 19m 平台 12 边、12.4m 安全壳 12 边） | **39**（大量 4/5/6/8 边） | 0 | 0 | 0 | 0 | **P1 重点** |
| **战区设施 / 载具 / 事件 / 撤离 / 机库** (`raid.gd` 环境段 / `extract_zone` / `events` / `world_link` / `menu_ship` / `hub`) | 6 | **88**（`raid.gd` 剔除弹药后 37 处 + 其余 51 处） | 7 | 4 | 0 | **5**（路标/铁轨） | 0 | **P1** |
| **敌人与首领** (`bug.gd` / `bugs2.gd` / `nest.gd` / `enemies/models.gd` / `boss_models*.gd` / `boss_modular_glb.gd` / `boss_glb.gd` / `spawn_util.gd`) | 10 | **275** + `_sweep`/`_tube` 默认 10 边 | 0 | 0 | 1（`_ball` 16×9 球） | 0 | （计入技能项 `enemy.gd:876`） | **P2** |
| **机甲模块（非导弹发射巢部分）** (`scripts/modules/arm_*` / `core_*` / `gen_*` / `legs_*` / `back_*`) | 88 | **833** | 23 | 39 | 0 | 0 | 0 | **P2** |
| **物资箱 / 掉落物 / NPC 配件** (`loot_box.gd` / `item_models.gd` / `npc_mech.gd`) | 3 | **64** | 0 | 0 | 0 | 0 | 0 | **P2** |
| **合计（去重文件数 172）** | **172** | **2,719**（另 1,461 处微小六角螺栓） | **74** | **47** | **10** | **5** | **3** | — |

### 1.2 核查通过白名单（非低面数缺陷，避免误改）

以下资产经逐一核查属于**有意为之的多边形结构**或**已达高模标准**，整改时应保留几何特征（仅可按需补倒角/细节）：

1. **全部 7 个首领 `.glb` 外部高模**（位于 `assets/models/boss/`）：面数实测为 **2,475 ~ 22,734 三角面**，均非低面数模型（仅其代码挂载附属件如 `boss_glb.gd` / `boss_modular_glb.gd` 需修）：
   - `boss_broodmother.glb` / `boss_king_beetle.glb` / `boss_queen.glb` / `boss_harbor_reaper.glb` / `boss_slag_colossus.glb` / `boss_dune_devourer.glb` / `boss_abyss_harbinger.glb`
2. **明确按现实/结构意图设计的规则多面体**（代码有对应命名/结构逻辑）：
   - 八角永备暗堡外墙/底盘/顶盖：`scripts/buildings/fort_pillbox_bunker.gd` L18, L20, L22, L130-131（`seg=8` 八角混凝土工事）
   - 八角砖烟囱底座与八角地坪：`scripts/buildings/ind_oil_tank_chimney.gd` L127-129；`scripts/buildings/poi_abyss_gate_rig.gd` L18；`scripts/raid.gd::_park_statue` L9187-9188
   - 四棱台反坦克“龙牙”锥：`scripts/buildings/ter_dragon_teeth_pipe.gd` L24..54（9 座 `seg=4`）；`scripts/raid.gd::_build_perimeter` L1141（`seg=4`）
   - 四坡方锥钟楼屋顶：`scripts/map_ext/landmarks_boss.gd::_central_terminus` L159（`seg=4`）；八坡教堂尖顶：`scripts/map_ext/poi/church.gd` L83（`seg=8`）
   - 六方棱柱晶体/高压电极：`scripts/enemies/models.gd::_shard` L102-112；`scripts/item_models.gd::_build_bug_crystal` L356；`scripts/map_ext/poi/well_core.gd` L109；`scripts/map_ext/landmarks.gd::_crystal_cluster` L594；`scripts/enemies/spawn_util.gd` L172（注：若视觉显呆板，应升级为多晶簇+倒角晶面而非单纯增加圆边数）
   - 真正的六角螺母/铆钉头（`r ≤ 0.03m, seg = 6`）：全仓共 `1,461` 处（如机甲装甲板 `Rivets`、法兰螺栓 `bolt_ring`）。但**凡直径 > 0.03m 或本应为圆形的栏杆、树干、灌木、天线、地刺、油管、支架误用 `seg=6` 者均属于严重低面数缺陷，必须清零！**

---

## 二、全仓禁止低面数建模红线规范（整改验收标准）

后续所有整改与新增建模必须满足以下最低几何红线（低画质 / 移动端可做适度 LOD，但**绝不允许出现肉眼可数棱边的多边形曲面或裸几何方块**）：

| 几何类型 | 尺寸分级 | 桌面端最低分段 | 移动端最低分段 | 禁止事项 |
| :--- | :--- | :---: | :---: | :--- |
| **圆柱 / 圆锥 (`A.cyl`)** | 细管/天线/弹体 (`r < 0.08m`) | `≥ 16` | `≥ 12` | **严禁 `seg < 12` 用于任何圆形构件**；禁止 `seg < 8` 绕过下限钳制 |
| **圆柱 / 圆锥 (`A.cyl`)** | 中型管件/炮管/车轮/导弹 (`0.08m ≤ r < 0.4m`) | `≥ 24` | `≥ 18` | 严禁 10/12/14 边车轮、炮管、导弹体、烟囱管 |
| **圆柱 / 圆锥 (`A.cyl`)** | 大型罐体/井口/潜艇/安全壳 (`r ≥ 0.4m`) | `≥ 36`（`r ≥ 2m` 时 `≥ 48`） | `≥ 28`（`r ≥ 2m` 时 `≥ 36`） | 严禁 12/16/18 边大型穹顶、油罐、炮弹坑、潜艇壳 |
| **球体 / 穹顶 (`A.sphere`)** | 小球 (`r < 0.15m`) / 大球 (`r ≥ 0.15m`) | `≥ 20×10` / `≥ 32×16` | `≥ 16×8` / `≥ 24×12` | 严禁 8/10/12/14 边球体与 8 边软管端帽 |
| **圆环 / 法兰 (`A.torus`)** | 环向 `rings` × 管截面 `ring_segments` | 小环 `≥ 24×16` / 大环 `≥ 36×18` | 小环 `≥ 18×12` / 大环 `≥ 28×14` | 严禁 `ring_segments = 10` 或大环 `rings = 12/14/16` |
| **胶囊 (`A.capsule`)** | 任意尺寸 | `radial ≥ 20, rings ≥ 8` | `radial ≥ 16, rings ≥ 6` | 严禁 `radial=10, rings=4` 硬编码 |
| **扫描管 / 软管 (`A.tube` / `A.hose`)** | 截面 `seg` × 路径细分 `sub` | `seg ≥ 14`, `sub ≥ 8`（长弧 `≥ 12`） | `seg ≥ 10`, `sub ≥ 6` | **彻底废除 `A.tube` 默认 `seg=7` 与 4/5/6 边管线** |
| **有机扫描 (`bug._sweep` / `models._tube`)** | 截面 `rad` × 路径 `steps` | `rad ≥ 18, steps ≥ 8` | `rad ≥ 14, steps ≥ 6` | 禁止 `rad=10, steps=5` |
| **力场护盾 (`reactive_arc_mesh`)** | 弧面分段 `segs` × 叶片 `blades` | `segs ≥ 28`, 弧片 `≥ 6` | `segs ≥ 20`, 弧片 `≥ 5` | 禁止 `3×10` / `4×12` / `5×14` 折纸感护盾 |
| **硬表面体块 (`bevel_box` / 裸 `BoxMesh`)** | 所有可见实体 | 必须使用带倒角网格（`bevel > 0`）或组合硬表面 | 同左 | **禁止裸 `BoxMesh`、`PrismMesh` 用于弹翼/弹壳/破片/城市楼体** |
| **技能 / 导弹 / 建筑结构复杂度** | 可见实体 | 禁止“1~6 个基础几何体”的灰盒占位；须有多级构件、法兰/护笼/接口/倒角轮廓 | 同左 | 禁止单箱建筑、3 方块立柱、5 边树干灌木 |

---

## 三、【P0】底层几何库系统性根因（源头清零，全图受益）

大量中低面数问题源自 `scripts/art.gd` 与 `scripts/modules/kit.gd` 的底层硬编码上限、偏低默认值与漏洞分支，**必须作为第一批次优先修复**：

- [ ] **P0-CORE-01** `scripts/art.gd` L97-116 `cyl()`
  - **现状缺陷**：
    1. `if seg >= 8:` 导致所有调用方传入 `seg = 4, 5, 6, 7` 时直接绕过分段校验原样输出，造成全仓大量 5/6/7 边低模；
    2. 桌面端强行向下封顶：`rmax < 0.08` 压至 `16`，`< 0.2` 压至 `20`，`< 0.6` 压至 `24`；移动端更压至 `12 / 14 / 18`；
    3. `c.rings = 1` 固定单环。
  - **整改目标**：新增显式 `allow_poly := false`（仅白名单多边形结构开启），默认曲面下限提升为 `≥ 16/24/36`（桌面）与 `≥ 12/18/28`（移动），取消对调用方高分段的过低封顶。

- [ ] **P0-CORE-02** `scripts/art.gd` L119-136 `sphere()`
  - **现状缺陷**：同样存在 `if seg >= 8:` 漏洞；半径 `< 0.15` 桌面压至 `16`、移动压至 `12`；`s.rings` 仅 `s_seg / 2`（低至 6 环）。
  - **整改目标**：强制最低 `radial ≥ 20`（小）/ `≥ 32`（大）、`rings ≥ 10/16`，移除 `seg < 8` 放行漏洞。

- [ ] **P0-CORE-03** `scripts/art.gd` L2609-2652 `tube()`（**全仓 74 处管线 + 47 处软管源头**）
  - **现状缺陷**：函数签名默认 `seg := 7, sub := 6` —— 全游戏默认生成 **七棱柱管线**！且无最小分段保护，调用方传入 `seg=4/5/6` 直接生成方棒/五棱棒。
  - **整改目标**：默认参数升至 `seg := 14, sub := 10`，内部强钳制 `seg = maxi(seg, 12)`（桌面）/ `10`（移动），路径插值段数 `sub = maxi(sub, 8)`。

- [ ] **P0-CORE-04** `scripts/art.gd` L2654-2672 `hose()` & `A_end_caps()`（**全仓 47 处机甲/机库软管**）
  - **现状缺陷**：`hose()` 直接调用默认 7 边 `tube()`；`A_end_caps()` 用 `sphere(r * 1.5, -1, 8)` 生成 **8 边粗糙球帽** 充当接头！
  - **整改目标**：`hose()` 改用 `seg=14, sub=10` 管体；`A_end_caps()` 改为多级工业液压接头（六角压紧螺母 + 倒角缩口套筒 + 16 边橡胶护套），彻底淘汰 8 边球帽。

- [ ] **P0-CORE-05** `scripts/art.gd` L514-525 `capsule()`
  - **现状缺陷**：硬编码 `radial_segments = 10` (`r < 0.2`) / `14` (`r < 0.5`) / `18` (`≥ 0.5`)，`rings = 4`（极粗糙胶囊）。
  - **整改目标**：提升为 `radial_segments = 20 / 24 / 28`，`rings = 8 / 10`。

- [ ] **P0-CORE-06** `scripts/art.gd` L527-541 `torus()`
  - **现状缺陷**：管截面硬编码 `ring_segments = 10` (`< 0.15`) / `12`（明显多边形横截面）；环向 `rings` 小环被压到 `14`（移动）/ `18`（桌面）。
  - **整改目标**：`ring_segments` 升至 `16 / 18`（桌面）与 `12 / 14`（移动），`rings` 下限 `≥ 24`（大环 `≥ 36`）。

- [ ] **P0-CORE-07** `scripts/art.gd` L2262-2310 `reactive_arc_mesh()`（**全部能量护盾/耗材力场源头**）
  - **现状缺陷**：默认仅 `blades := 5, segs := 14`，且调用处还传入 `4, 12` 与 `3, 10`，展开成球面/柱面时每段转折棱角极其明显。
  - **整改目标**：默认升至 `blades := 6, segs := 28`（内部强钳制 `segs >= 24`），并增加法线平滑与边缘渐变，消除折纸感。

- [ ] **P0-CORE-08** `scripts/art.gd` L139-225 `rock_mesh()` & L228-318 `_branch_tube()` / `tree_trunk_mesh()`
  - **现状缺陷**：
    1. `_branch_tube` 默认 `seg := 7`；`tree_trunk_mesh` 主干仅 `8` 边（L295）、一级树枝仅 `5` 边（L308）、二级树枝仅 `4` 边（L313）！全图所有树木与枯木的枝干均为 4~8 边粗棱棍；
    2. `rock_mesh(variant, detail := 18)` 最小 `nu=14, nv=10`，悬崖放大至 13~34m 时切面粗糙。
  - **整改目标**：`tree_trunk_mesh` 主干升至 `16` 边、一级侧枝 `12` 边、二级枝 `8~10` 边且增加树皮纵向起伏；`rock_mesh` 默认 `detail := 24`（悬崖大岩体单独提供高细分变体 `detail=28`）。

- [ ] **P0-CORE-09** `scripts/modules/kit.gd` L176, L230-243, L260, L396
  - **现状缺陷**：机甲与建筑共用件库中：`holes()` 散热孔 `seg=8`（L176）；`piston()` 液压缸与活塞杆 `seg=12/10/8`（L230-236）；`barrel_bore()` 膛口环 `torus seg=18`、内膛 `cyl seg=14`（L242-243）；`_receiver()` 零件 `seg=8`（L396）。
  - **整改目标**：`holes()` 升至 `16`、`piston()` 升至 `20/18/16`、`barrel_bore()` 升至 `torus 28` + `cyl 24`、`_receiver()` 升至 `16`。

- [ ] **P0-CORE-10** `scripts/bug.gd` L361 `_ball()` & L518 `_sweep()` + `scripts/enemies/models.gd` L63 `_tube()`
  - **现状缺陷**：`_ball()` 硬编码 `SphereMesh` 仅 `rings=9, radial_segments=16`；`_sweep()` 默认 `steps=6, rad=10`；`models.gd::_tube()` 默认 `steps=5, rad=10`（全部敌机与部分首领的曲臂/尾节/管路仅 10 边）。
  - **整改目标**：`_ball()` 升至 `radial=28, rings=14`；`_sweep()` / `_tube()` 默认 `rad := 18, steps := 8`。

---

## 四、【P0】重点重灾区一：技能与战术部署装置全清单

用户重点反馈的**技能建模低面数**问题极其集中，既有“3 个方块堆出来的占位立柱”，也有 4/5 边折线网与 10/12 段折面护盾：

| 编号 | 技能 / 战术装置 | 代码位置 | 当前低面数 / 占位缺陷 | 整改要求 |
| :--- | :--- | :--- | :--- | :--- |
| **P0-SKL-01** | **撤离屏障 (`extract_barrier`)** | `scripts/modules/extract_barrier.gd` L29-35 | **严重灰盒占位**：4 根力场立柱每根仅由 **3 个上下叠放的 `bevel_box` 方块**构成（方棍 + 方帽 + 发光小方粒），完全没有工业力场桩造型与细节 | 重制高精重工野战力场桩：三脚锚定钢爪基座 + 加强肋配电箱 + 高细分圆柱散热器(`seg≥20`) + 电磁发射线圈环(`torus≥24`) + 护笼频闪灯 + 柱间微弧力场幕 |
| **P0-SKL-02** | **声波诱饵信标 (`sonic_decoy`)** | `scripts/modules/decoy_beacon.gd` L27-38 | **严重简陋拼接**：全实体仅 6 个初级图元（3 根细方棍脚 + `cyl seg=14` 底座 + `cyl seg=18` 裸喇叭锥 + **`seg=6` 六边天线** + **`seg=10` 十边闪灯**） | 重制战术声波诱饵台：可展开折叠三角液压脚垫 + 主控防水机箱（带警示条、散热百叶） + 多级高细分扩音号角(`seg≥28`)与内部防尘音膜网 + `seg≥16` 鞭状天线 + 护笼频闪灯(`seg≥20`) |
| **P0-SKL-03** | **四足跃迁阻拦网 (`slow_web`)** | `scripts/modules/slow_web.gd` L34, L39 | **极低面数硬棒**：11 条放射网丝用 **`A.tube(..., seg=5, sub=5)`**（五棱折线棒），横向连丝用 **`A.tube(..., seg=4, sub=4)`**（四棱方棒），且无锚定桩/网囊抛射器 | 改为战术锚钉阻滞网：中心抛射母罐(`cyl seg≥24` + 弹开瓣盖) + 周边锚钉地桩 + `seg≥12, sub≥10` 平滑悬链线钢缆/高粘纤维束（叠加不规则粘液节点与地面油网贴花） |
| **P0-SKL-04** | **主动防御护盾（玩家 F 键）** | `scripts/mech.gd` L161-163 | `A.reactive_arc_mesh(1.52, 1.55, 5, 14)`：仅 5 片 × 14 段，近看呈明显折线多边形碎片 | 升级为 `blades=6, segs=32` 高细分流畅电磁偏转弧幕 + 双层高频蜂窝干涉纹理与边缘羽化 |
| **P0-SKL-05** | **耗材能量冲击壳（电池棒/冷却剂/超频电芯）** | `scripts/modules/weapon_fx.gd` L100（被 `item_battery.gd:18`, `item_coolant.gd:21`, `item_surge.gd:27` 调用） | `A.reactive_arc_mesh(..., 4, 12)`：仅 4 片 × 12 段，展开瞬间能清晰看到 12 边形折角 | 升级为 `blades=6, segs=28` 高细分弧幕 + 顺滑展开曲线 |
| **P0-SKL-06** | **敌方护盾技能（护盾虫/庇护者）** | `scripts/enemies/enemy.gd` L876 `shield_ally()` | `ART.reactive_arc_mesh(..., 3, 10)`：全游戏最低面数力场（仅 **3 片 × 10 段**），呈粗糙十边形纸片 | 升级为 `blades=5, segs=24` 高细分弧幕 |
| **P0-SKL-07** | **背部护盾发生器挂载 (`back_shield`)** | `scripts/modules/back_shield.gd` L28-29, L56 & `A.hose` | 高压陶瓷绝缘子 `K.cy(..., 10)`、放电探针 `K.cy(..., 8)`、六角螺栓 + 7 边 `A.hose` 软管（配 8 边球帽） | 绝缘子与探针升至 `seg≥20`，软管走升级后高精 `A.hose` |
| **P0-SKL-08** | **首领地刺突袭技能 (`SpikeRow`)** | `scripts/enemies/hazards.gd` L262-263 `_thrust()`（被 6 名首领 AI 调用） | **极低面数 6 边圆锥**：每根破土地刺仅由 2 个 **`A.cyl(..., 6)`** 上下拼接而成，无碎石翻土基座、无金属装甲刺棱细节 | 改为多棱破甲地刺簇：高细节碎石隆起基座(`rock_mesh`) + 主/副 3 根带倒角切削刃面与加强筋的多层穿刺桩（或 `HS.loft` 放样刃体）+ 熔热裂纹核心 |
| **P0-SKL-09** | **敌方近战挥砍特效 (`_slash_fx`)** | `scripts/enemies/enemy.gd` L762 | 直接用 `ART.capsule(0.05, 2.2)`（硬编码 10 边 × 4 环胶囊棍）充当刀光 | 改为高细分弯曲月牙刀光网格（自定义弧形带 `≥24` 段，头尾收尖+渐变贴图） |
| **P0-SKL-10** | **撤离引导烟幕 (`item_flare`)** | `scripts/modules/item_flare.gd` L28-32 | 目前无 3D 烟幕罐实体落地（仅凭空冒粒子），虽无低面数网格但缺少战术实体质感 | 补充高细分落地金属信号弹罐体（`cyl seg≥24` + 拉环拉栓 + 排气孔口 + 焦黑地面痕），与 `extract_zone.gd` 信号弹视觉统一 |

> 注：其余机动技能（`biped` 矢量推进、`tread` 冲锋、`hex` 震踏、`leap.gd` 跃迁）目前仅使用粒子与地面冲击波贴花，不产生低面数 3D 网格；`missile` 齐射技能的弹体问题全部归入下方 **P0 导弹专题清单**。

---

## 五、【P0】重点重灾区二：导弹、火箭、炮弹与弹药全清单

用户重点反馈的**导弹低面数**问题贯穿玩家齐射导弹、肩/臂发射火箭、全部枪炮弹丸、退壳/弹托、以及首领弹幕：

### 5.1 玩家/小队飞行弹体与弹壳（`scripts/raid.gd`）

- [ ] **P0-MSL-01** `scripts/raid.gd` L3103-3120 `_populate_proj_body()` —— **制导导弹 / 火箭弹 / VLS 垂发重弹 (`missile` / `rocket` / `vls`)**
  - **现状缺陷**：
    1. 弹身、整流罩、警示环仅 `A.cyl(..., 14)`；尾喷管收口 `A.cyl(..., 12)`；导引头尖与铜喷喉仅 `A.cyl(..., 10)`；
    2. **全部 4 片尾翼与 4 片前部鸭翼直接使用无倒角裸 `BoxMesh` (`_box_cached`, L3117, L3119)** —— 飞行时呈现极生硬的“十字厚砖片”！
    3. 缺少真实的弹体级间法兰、导引头光学窗/半球罩、翼根整流座、尾喷口内黑膛与拉瓦尔扩张喷管。
  - **整改目标**：
    - 弹身/整流罩/级间环全升至 `seg = 24`（`vls` 大弹 `seg = 28`）；导引头光学半球改用 `sphere(..., 20)` + 金属压圈；
    - 用 `A.prism()` 或 `HS.loft()` 制作**带后掠前缘、翼型剖面厚度与切角根部的梯形/三角形弹翼与鸭翼**，彻底删除 `_box_cached`；
    - 增补级间加强环箍(`torus seg=24`)、尾喷口拉瓦尔内凹黑膛与热耐火喷环。

- [ ] **P0-MSL-02** `scripts/raid.gd` L3121-3152 `_populate_proj_body()` —— **酸液罐弹 / 燃烧弹 / 液氮弹 / 默认炮弹 (`spit` / `flamer` / `cryo` / `_`)**
  - **现状缺陷**：
    - `spit` 仅 `cyl seg=12/10` + 4 片裸 `BoxMesh` 尾翼（L3130）；
    - `flamer` 仅 `cyl seg=10/8`（L3136-3139）；
    - `cryo` 仅 `cyl seg=10`（L3143-3145）；
    - 默认炮弹 `_` 仅 `cyl seg=10`（L3149-3151）。
  - **整改目标**：全部圆筒与弹头升至 `seg = 20~24`；`spit` 尾翼改为梯形倒角尾翼；补全压力阀帽、引信环与尾焰喷口内膛。

- [ ] **P0-MSL-03** `scripts/raid.gd` L3203-3258 `_populate_tracer_body()` —— **全口径实弹弹丸 (`apfsds`/`sniper`/`coil`/`cannon`/`ac30`/`slug`/`pellet`/`mg`)**
  - **现状缺陷**：
    - 共 **24 处 `A.cyl` 仅 `seg=8 / 10 / 12`**（`pellet` / `mg` / 曳光尾杯为 **8 边**，`apfsds` / `sniper` / `coil` / `ac30` / `slug` 为 **10 边**，`cannon` 为 **12 边**）；
    - `apfsds`(L3218)、`coil`(L3230)、`cannon`(L3238)、`pellet`(L3252) 的稳定弹翼全用裸 `BoxMesh` (`_box_cached`)！
  - **整改目标**：所有弹丸圆柱/尖锥升至 `seg = 16~20`（`cannon`/`apfsds` 升至 `20`），尾翼改为薄切角后掠翼片网格（预合批缓存为单一 `ArrayMesh` 兼顾性能与高精度！）。

- [ ] **P0-MSL-04** `scripts/raid.gd` L3364-3451 —— **裸原语退壳 / 弹托 / 破片（极严重）**
  - **现状缺陷**：
    1. `_casing_mesh()`（L3392-3408）：抛出的“3D 黄铜弹壳 / 红色霰弹壳”竟是 **`BoxMesh.new()` 长方体木块**！（旧基线曾为 `CylinderMesh`，被降级成了方块）
    2. `_sabot_petal_mesh()`（L3440-3451）：脱壳穿甲弹铝合金弹托瓣为裸 **`BoxMesh.new()` 方块**；
    3. `_debris_mesh()`（L3412-3436）：全游戏命中/爆炸飞溅的金属破片、石块、甲壳碎屑均为单一 **`PrismMesh.new()` 规则三角柱**；
    4. `_box_cached()`（L3364-3370）：弹翼专用的裸 `BoxMesh.new()` 缓存器。
  - **整改目标**：
    - `_casing_mesh()` 改建为带收口瓶颈、底缘抽壳槽与空心弹口的 `seg=16` 高精度合批 `ArrayMesh`；
    - `_sabot_petal_mesh()` 改建为 120° 弧形凹槽卡瓦瓣 `ArrayMesh`；
    - `_debris_mesh()` 改建为多变体不规则切角破片/碎石 `ArrayMesh`；
    - 废弃 `_box_cached()`，全部弹翼替换为预合批后掠倒角翼网格。

### 5.2 敌方与首领导弹 / 迫击炮 / 动能弹（`scripts/enemies/hazards.gd` & `weapon_fx.gd`）

- [ ] **P0-MSL-05** `scripts/enemies/hazards.gd` L359-372 `RocketSalvo.setup()` —— **首领齐射火箭/导弹（`boss_carrier`/`boss_citadel`/`boss_dreadnought`/`boss_warden`）**
  - **现状缺陷**：弹体 `cyl(..., 12)`、弹头 `cyl(..., 12)`、尖锥 `cyl(..., 8)`、色环 `cyl(..., 12)`、喷口 `cyl(..., 10)`、**4 片 `bevel_box` 矩形块尾翼**（无后掠）。
  - **整改目标**：弹体升至 `seg=24`、整流罩/导引头多段平滑收口、换装后掠翼型尾翼 + 拉瓦尔尾喷口与级间法兰环。

- [ ] **P0-MSL-06** `scripts/enemies/hazards.gd` L113-124 `LobShell.setup()` —— **迫击炮弹（`enemy.gd` & `boss_artillery`/`boss_brood`/`boss_burrower`/`boss_queen`）**
  - **现状缺陷**：炮弹本体 `cyl(..., 12)`、引信座 `cyl(..., 12)`、尖锥 `cyl(..., 10)`、闭气环 `cyl(..., 12)`、尾管 `cyl(..., 10)`，共 6 处低段圆柱。
  - **整改目标**：全段升至 `seg=24`，补泪滴型迫击炮弹体曲线过渡与带导气孔的尾翼管。

- [ ] **P0-MSL-07** `scripts/enemies/hazards.gd` L528-540 `KineticSlug.setup()` —— **首领重型动能穿甲弹（`boss_carrier`/`boss_citadel`/`boss_dreadnought`/`boss_warden`）**
  - **现状缺陷**：弹杆 `cyl(..., 10)`、钨芯尖 `cyl(..., 8)`、闭气环 `cyl(..., 10)`、尾杯 `cyl(..., 8)`。
  - **整改目标**：全段升至 `seg=20`，并换装后掠穿甲稳定尾翼。

- [ ] **P0-MSL-08** `scripts/modules/weapon_fx.gd` L23-25 `beam()` —— **激光/轨道炮/电弧高能弹束**
  - **现状缺陷**：3 段弹芯与尖锥全为 `A.cyl(..., 10)`（十棱硬棒）。
  - **整改目标**：升至 `seg=20`（或高细分平滑锥柱 + 尾流渐变）。

### 5.3 发射巢内常驻导弹 / 弹头模型（背部 + 手臂发射器）

玩家在第三人称机库与战斗中近距离持续盯着机甲背部与双臂的发射管口，以下 **12 个发射器模块** 内的弹头/发射筒口均低于 `seg=16`：

- [ ] **P0-MSL-09** 背部导弹/火箭发射巢（3 文件）：
  - `scripts/modules/back_missile.gd` L25, L39-41：耳轴 `seg=14`、巢内导弹头 `seg=12`、导引头球 **`A.sphere(..., 10)`** + 7 边 `A.hose`；
  - `scripts/modules/back_rocket.gd` L19, L24, L42-46：俯仰轴 `seg=12/14`、火箭弹头 `seg=12`、引信尖 **`seg=8`**、喷环 `seg=14` + 7 边 `A.hose`；
  - `scripts/modules/back_vls.gd` L21, L48, L50, L60-62：天线 `seg=8`、垂发井口环 `seg=14`、井内 VLS 导弹体/弹头 **`seg=12`** + 7 边 `A.hose`。
- [ ] **P0-MSL-10** 手臂导弹/火箭发射巢（9 文件）：
  - `scripts/modules/arm_ram116.gd` L75-111：**35 处**（11 联装 RIM-116 发射管 `seg=14`、内膛 `seg=12`、导弹弹头 **`seg=10`**）；
  - `scripts/modules/arm_lau61.gd` L72-109：**31 处**（19 联装 Hydra-70 发射孔 `seg=10`、内藏黄铜弹头 **`seg=8`** + 7 边 `A.tube` 软管）；
  - `scripts/modules/arm_tos220.gd` L116-140：**18 处**（6 联装 220mm 温压弹发射管 `seg=14`、引信 `seg=12`）；
  - `scripts/modules/arm_tow2b.gd` L73-95（10 处 `seg=12/14`）、`arm_kornet.gd` L87-120（8 处 `seg=12/14`）、`arm_m299.gd` L72-112（8 处 `seg=12/14`）、`arm_rpo93.gd` L72-105（10 处 `seg=12/14`）、`arm_cg84.gd` L80-95（8 处 `seg=12`）、`arm_miclic.gd` L70-100（11 处含 5 处 `torus seg=16` + 2 处 7 边 `A.tube`）。
  - **整改目标**：所有发射筒口、内膛、外露导弹头统一升至 `seg ≥ 20`（大口径管 `≥ 24`），导引头球 `sphere ≥ 20`，全部软管升至 `seg ≥ 14`。

---

## 六、【P1】重点重灾区三：建筑、预制体、遗迹 POI、地标与远景城区全清单

用户重点反馈的**部分建筑低面数**来自四层问题：**裸盒远景建筑与窄楼回退**、**荒原 5~7 边枯树灌木预制体**、**30 项建筑预制体中的低段大型圆柱/环箍/散热器/车轮**、以及**遗迹 POI 与首领地标的巨型 12~18 边圆筒/穹顶与 4~6 边管架**。

### 6.1 裸盒占位与灾难级低模建筑/地貌（最刺眼，建筑类第一优先）

- [ ] **P1-BLD-01** **荒原枯木灌木与电塔预制体** `scripts/buildings/ter_arid_flora_pylon.gd` L19-219
  - **现状缺陷（建筑预制体中最恶劣）**：共 **89 处低面数曲面** —— 3 座土丘 `seg=7/6`（`r=1.8~2.0m`）；2 棵胡杨主干 **`seg=7/6`**、根部 `seg=6`、所有分叉树枝全是**硬方棍 `K.bb`**（L29-33, L41-45）；4 丛沙棘灌木用 **24 个 6 边扁圆柱（`seg=6, r=0.36~0.50m`）** 拼凑树冠、用 **20 个 5 边圆柱（`seg=5`）** 做枝条；6 丛干草根基 `seg=6` + 方片草叶；电塔陶瓷绝缘子 `seg=10/8`。
  - **整改目标**：树干/树枝彻底替换为升级后的 `A.tree_trunk_mesh()` 高细分有机枝干；灌木冠层替换为 `A.shrub_mesh()` 真实叶片簇；干草替换为 `A.grass_clump_mesh()`；绝缘子串升至 `seg≥20`。

- [ ] **P1-BLD-02** **战区外围远景建筑 MultiMesh** `scripts/raid.gd` L8163-8405 `_build_backdrop()` & `scripts/buildings_ext.gd` L60-107 `add_backdrop()`
  - **现状缺陷**：战区隔离墙/河岸外侧紧邻视线的上百栋城区建筑，全部由 **1~4 个拉伸单位方盒** + **3 顶点三角棱柱 (`gable_m`/`saw_m`)** + **`cyl seg=18` 拱顶 (`barrel_wh`)** + **`cyl seg=20` 裸储罐 (`tank_cyls`)** 构成（无真窗洞、无女儿墙细节、无空调/楼梯间/管道结构），与围墙内精修预制体形成剧烈割裂感。
  - **整改目标**：外围可见圈层（距边界 ≤ 90m）直接复用 `PrefabLib` 精修建筑预制体（关闭小装饰碰撞与次要阴影以控开销），更远圈层至少升级为带真分段立面/压顶/屋面机房与 `seg≥32` 罐体的多表面合批网格。

- [ ] **P1-BLD-03** **窄地块通用建筑回退分支** `scripts/raid.gd` L1560-1566 `_building()`
  - **现状缺陷**：当 `size.x < 4.2 or size.z < 4.2` 时，跳过 `PrefabLib`，仅生成 **3 个叠放方盒**（主块 + 底座 + 顶沿），无门窗、无屋顶设备、无任何结构细节。
  - **整改目标**：接入小型配电房/门卫室/砖砌岗亭高精预制体或自动匹配缩放 `bldg_house` / `bldg_substation` 变体，彻底删除 3 方块灰盒回退。

- [ ] **P1-BLD-04** **主菜单云下城市楼体** `scripts/menu_city.gd` L82-90 `setup()`
  - **现状缺陷**：`st.create_from(BoxMesh.new(), 0)` —— 整片主菜单俯瞰废土城市全由**无倒角裸 `BoxMesh` 纯方块**构成。
  - **整改目标**：升级为 3~4 种带女儿墙压顶、退台层次、屋顶水箱/机房轮廓的合批 `ArrayMesh` 变体（按楼体类型分桶 MultiMesh）。

- [ ] **P1-BLD-05** **遗迹 POI 实心大箱主楼（贴片假窗）**
  - `scripts/map_ext/poi/hospital.gd` L16-35（门诊楼：1 块 `13×7×7m` 实心 `K.wall` + 表面粘贴薄板窗 + 2 块板拼红十字）；
  - `scripts/map_ext/poi/school.gd` L16-29（教学楼：1 块 `17×6.4×5.6m` 实心 `K.wall` + 表面贴片假窗）；
  - `scripts/map_ext/poi/church.gd` L66-88（15m 钟塔基于实心 `K.wall` 外贴百叶板）；
  - **整改目标**：改造为具备真内凹窗洞、立面柱网/腰线、屋顶机房护栏的精修建筑结构，与城区 `PrefabLib` 建筑精度拉齐。

### 6.2 30 项建筑 / 载具 / 工事预制体逐文件清单（`scripts/buildings/*.gd`）

> 以下覆盖全部 30 个预制件文件（`ter_road_shoulder.gd` 为 0 项，已核验合格）。共检出 **1,146 处可见低分段曲面**（不含 63 处微小 `r≤0.03m` 六角螺栓）。

#### A. 大尺寸显眼曲面低面数（**高优先级**）

| 文件 | 低分段数 | 最显著问题部位（行号 / 半径 / 当前分段） | 整改目标 |
| :--- | :---: | :--- | :--- |
| `scripts/buildings/poi_abyss_gate_rig.gd` | 47（另 4 处 `seg=6` 细杆） | **终局 Boss 战核心地标**：L80 直径 7.36m 封印巨环 **`torus(3.25, 3.68, 16)`**（连同 L78-81 井圈 `seg=16`）；L84..136 **32 根液压锁栓/活塞杆 (`r=0.13/0.075`) 全 `seg=10`**；L143..156 防喷器手轮 **`torus seg=12`**、阀杆 `seg=8`；L217-225 天车滑轮 `seg=14`、**6 边主动钻杆 `r=0.18`**（仅 L18 八角底盘为白名单） | 封印井环升至 `48` 段、液压缸/活塞升至 `24/20` 段、BOP 手轮升至 `torus 24`、钻井滑轮升至 `24` 段 |
| `scripts/buildings/bldg_chem_plant.gd` | 67 | **化工精馏塔**：L154/209 直径 2.16m 混凝土底座 **`seg=10`**；L157..229 **6 层直径 2.64m 环形走道与护栏 `cyl seg=12` + `torus(1.28, 1.32, 12)`**；L155/210 主塔筒 `r=0.84m` 仅 `seg=18`；L273-280 管桥 6.5m 工艺管 `seg=10` + 阀轮 `torus seg=12`；L189..259 33 根爬梯横杆 `seg=8` | 主塔与底座升至 `36` 段、环形走道/栏杆升至 `32` 段、工艺管/阀轮升至 `20~24` 段、爬梯横杆 `≥14` 段 |
| `scripts/buildings/ind_oil_tank_chimney.gd` | 39（另 36 处 `seg=6` 栏杆立柱！） | **储油罐与高炉烟囱**：L35-44 & L55..118 **24 根罐顶与盘梯圆管栏杆立柱误用 `seg=6`**；L146..176 12 根护笼支架 `seg=6`；L130-137 11.5m 高烟囱主筒 `seg=16`、5 道钢箍 `torus seg=18`、烟口 `seg=14`；L145..174 6 道爬梯护笼 **`torus(0.3, 0.33, 12)`** + 14 根横杆 `seg=8`；L45-48 呼吸阀/直径 0.84m 人孔 `seg=10/12`；L121 7.45m 消防立管 `seg=10`；L180-184 泵撬与 3.25m 管汇 `seg=12` + `torus seg=12`（L127-129 八角砖基座为白名单） | 烟囱主筒/箍环升至 `32` 段、罐体人孔/呼吸阀/泵撬管汇升至 `24` 段、护笼圆环 `torus 24`、全部栏杆立柱/横杆 `≥14~16` 段 |
| `scripts/buildings/bldg_command_bunker.gd` | 35 | **指挥地堡雷达罩**：L317-321 直径 3.24m `PolyhedralGeodesicRadome` 由 5 层 `seg=10` 圆柱叠加；L147/150 防爆门手轮 `torus seg=14`；L359-366 避雷针 `seg=10/8`；L178..237 24 根窗栅 `seg=8` | 雷达罩改建真正高细分测地线球面穹顶（或 `≥24` 段分瓣球壳）、门轮 `torus 24`、细杆 `≥14` 段 |
| `scripts/buildings/ter_dragon_teeth_pipe.gd` | 16（剔除 9 处白名单 `seg=4` 龙牙锥 + 3 处 `seg=6` 露筋） | **弹坑与断油管**：L57-58 **直径 4.12m 炮弹坑环与焦土底仅 `seg=10`**；L71-84 **直径 1.06m 断裂输油管仅 `seg=16`、内黑膛 `seg=14`、3 道大法兰 `torus(0.51, 0.61, 16)`**；L25..55 9 个龙牙顶吊环 **`torus seg=10`** | 弹坑环升至 `32` 段（并改不规则弹坑轮廓）、1.06m 管道及法兰升至 `32` 段、吊环 `torus 20`、露筋 `≥12` 段 |
| `scripts/buildings/bldg_foundry.gd` | 8 | L217-228 双联熔炉/烟囱 **6 道大直径 `torus(0.66~0.95, seg=16)`**；L223/232 双 2.5m 排烟管 (`r=0.36m`) 仅 `seg=12` | 大环升至 `32` 段、排烟管升至 `24` 段 |
| `scripts/buildings/bldg_substation.gd` | 76 | **110KV 变电站**：L190/236 双储油枕 `r=0.28m` 仅 `seg=14`；L192..260 **36 个高压瓷瓶伞裙 (`r=0.08~0.105m`) 全 `seg=12`**、接线柱 `seg=8`；L278-289 避雷器/母线 `seg=10`；L97..121 窗栅 `seg=8` | 油枕升至 `24` 段、瓷瓶伞裙升至 `20` 段、接线/窗栅升至 `14~16` 段 |
| `scripts/buildings/poi_silo_radar.gd` | 11 | L134-135 直径 2.36m 筒仓/雷达底座 **`seg=8` / `seg=14`**；L103-108 6 根窗栅 `seg=8`；L152-153 避雷针 `seg=10/8` | 筒仓/雷达座升至 `32` 段（若意图八角座则仅升上部圆形座至 `28`），细杆 `≥14` 段 |
| `scripts/buildings/fort_pillbox_bunker.gd` | 14（剔除 5 处白名单八角暗堡主体 + 4 处 `seg=6` 露筋） | L48-49 机枪水冷套筒与枪管 **`seg=10/8`**；L132-134 顶部潜望镜塔 (`r=0.54m`) **`seg=8`**、通风帽 (`r=0.38m`) **`seg=10`**；L142-150 伪装网支架 `seg=8/10`；L171-172 排风机环 `torus seg=18` | 潜望镜塔/通风帽升至 `24` 段、机枪套筒/枪管升至 `20/16` 段、风机环 `torus 24`、露筋 `≥12` 段 |
| `scripts/buildings/fort_watchtower.gd` | 9 | L233-240 双联探照灯筒 (`r=0.21m`) **`seg=12`** + 灯罩环 **`torus seg=12`**；L243-244 避雷针 `seg=10/8` | 探照灯升至 `24` 段 + `torus 24`，细杆 `≥14` 段 |
| `scripts/buildings/poi_gantry_rail.gd` | 28（另 8 处 `seg=6` 钢索） | L46-58 8 只行车钢轮 (`r=0.26m`) 仅 `seg=14`；L79 卷扬滚筒 (`r=0.38m`) 仅 `seg=14`；L81-89 8 根吊钩钢索 **`seg=6`**；L194-215 18 个信号灯/缓冲缸 `seg=10` | 钢轮/卷扬筒升至 `28` 段、钢索 `≥14` 段、信号灯/液压缓冲升至 `20` 段 |
| `scripts/buildings/bldg_loco_shed.gd` | 8 | L253-266 屋顶 4 座大型涡轮排气烟帽 (`r=0.46/0.32m`) 仅 `seg=14` | 排气烟帽升至 `24~28` 段 |
| `scripts/buildings/bldg_factory_shed.gd` | 19 | L35-42 & L365-367 排风机护圈 `torus seg=18`、旋风除尘器箍环 `torus seg=18`；L298/301 导管 `seg=12`；L132-145 吊葫芦轮与链环 `seg=14/12/8` + `torus seg=12` | 除尘器/风机环升至 `28` 段、吊葫芦轮与管件升至 `20~24` 段 |

#### B. 民用/综合楼预制体中的高频低分段件（空调外机风扇 / 屋顶水箱 / 窗栅 / 门把手）

| 文件 | 低分段数 | 主要问题部位 | 整改目标 |
| :--- | :---: | :--- | :--- |
| `scripts/buildings/bldg_apartment.gd` | 129 | L1231-1238 **8 道屋顶水箱箍环 `torus(0.34, 0.37, 14)`**；L1292/1302 屋顶管道 `seg=12`；11 台空调外机风机 `seg=14/10`；L1209-1230 22 根水箱爬梯横杆 `seg=8`；68 根防盗窗圆钢栅 `seg=8` | 水箱箍升至 `torus 28`、风机/管道升至 `24`、防盗窗栏/梯杆 `≥14`（或改方钢倒角条省面又更写实） |
| `scripts/buildings/bldg_tenement.gd` | 129 | L1709-1725 3 座屋顶通风筒 (`r=0.22m`) `seg=14`；7 台空调外机 `seg=14/10`；16 个门拉手 `seg=10`；92 根窗栅圆钢 `seg=8` | 通风筒/空调升至 `24`、细杆 `≥14`（或方钢窗栅） |
| `scripts/buildings/bldg_arcade_shop.gd` | 78 | L845 直径 1.04m 屋顶排风/水塔件 `seg=14`；L27-28 排风机 `torus seg=18`；7 台空调风机 `seg=14/10`；56 根窗栅 `seg=8` | 大件升至 `28`、风机 `24`、窗栅 `≥14` |
| `scripts/buildings/bldg_courtyard_blk.gd` | 74 | 4 台空调风机 `seg=14/10`；L1184-1185 屋顶管 `seg=10`；62 根栏杆与窗栅 `seg=8` | 风机 `24`、管与栏杆 `≥16/14` |
| `scripts/buildings/poi_generic_building.gd` | 34（另 8 处 `seg=6` 细杆） | L537-551 4 道爬梯护笼 **`torus(0.32, 0.35, 12)`**；L595-597 屋顶通风筒 (`r=0.34m`) `seg=14`；L80-104 8 根 `seg=6` 细杆；3 台空调 `seg=14/10`；12 根窗栅 `seg=8` | 护笼与通风筒升至 `24~28`、细杆 `≥14` |
| `scripts/buildings/bldg_barrack.gd` | 45 | L335 防爆门轮 `torus seg=14`；42 根防盗窗圆钢 `seg=8` | 门轮 `torus 24`、窗栅 `≥14` |
| `scripts/buildings/bldg_warehouse.gd` | 38 | L376-384 3 座屋顶排风筒 (`r=0.24m`) `seg=14`；L30-33 4 根装卸台防撞柱 `seg=14`；L166-186 4 组门灯/滚轴 `seg=14/12`；12 根窗栅 `seg=8` | 排风筒与防撞柱升至 `24`、其余 `≥16` |
| `scripts/buildings/bldg_house.gd` | 28 | L399-402 屋顶烟囱管 `seg=12`；L46-47 排风机 `torus seg=18`；空调 `seg=14/10`；15 根窗栅 `seg=8` | 烟囱/风机升至 `24`、窗栅 `≥14` |
| `scripts/buildings/poi_duplex_coldstore.gd` | 16 | L107-111 3 座冷库屋顶大型冷凝风机 (`r=0.46m`) `seg=14`；L95-96 2 根冷媒立管 (`r=0.24m`) `seg=14`；L51/67 双冷库门手轮 `torus seg=14` | 冷凝风机升至 `28`、冷媒管与门轮升至 `24` |
| `scripts/buildings/bldg_terrace.gd` | 13 | L499-510 6 根屋顶陶土烟囱筒 `seg=10`；2 台空调 `seg=14/10` | 烟囱筒升至 `20`、空调升至 `24` |
| `scripts/buildings/bldg_stepped_tower.gd` | 4 | L1158-1159 屋顶直径 0.76m 旋转信标/雷达座 `seg=10` + 桅杆 `seg=8`；L80-81 门把手 `seg=8` | 底座升至 `24`、细杆 `≥16` |

#### C. 4 型重型载具残骸预制体（`scripts/buildings/veh_*.gd`）

| 文件 | 低分段数 | 问题部位（玩家贴脸掩体，近距极显眼） | 整改目标 |
| :--- | :---: | :--- | :--- |
| `scripts/buildings/veh_fuel_tanker.gd` | 21 | L120-123 **直径 2.16m 油罐 4 道加强环 `torus(1.02, 1.08, 16)`**；L45 车头油箱/排气管 `r=0.48m` 仅 `seg=14`；L125-127 3 个罐顶装油口 `seg=12`；L18..109 **12 处车轴与轮毂 (`r=0.10~0.12m`) 仅 `seg=10`** | 油罐环箍升至 `32`、油箱/装油口升至 `24`、全部车轴轮毂升至 `20` |
| `scripts/buildings/veh_armored_dozer.gd` | 22 | L20-28 **6 只履带主动轮/引导轮 (`r=0.34~0.36m`) 仅 `seg=14`**；L82-103 推土铲大液压缸/活塞杆 `seg=14/12`；L42-43 排烟管 `seg=10`；L64-68 驾驶室护栏 `seg=8` | 履带轮升至 `28`、液压缸升至 `20~24`、排烟管与护栏 `≥16` |
| `scripts/buildings/veh_apc_wreck.gd` | 18 | L114 炮塔座圈 (`r=0.68m`) 仅 `seg=14`；L116-123 机炮防盾/炮管 `seg=12` + 3 根烟雾弹发射筒 **`seg=8`**；L18..53 **12 处 8×8 车桥与轮毂仅 `seg=10`** | 炮塔座圈升至 `32`、车桥轮毂与炮管升至 `20~24`、烟雾筒 `≥16` |
| `scripts/buildings/veh_dump_truck.gd` | 17 | L65 储气/油箱 (`r=0.34m`) `seg=14`；L141-149 货箱双举升液压缸 `seg=14/12`；L18..43 **8 处前后车桥与轮毂仅 `seg=10/12`**；L79-80 竖排烟囱 `seg=12/10` | 储罐/液压缸升至 `24`、车桥轮毂与烟囱升至 `20` |

### 6.3 遗迹 POI 与搭建件库清单（`scripts/map_ext/poi/*.gd` & `poi_kit.gd`）

- [ ] **P1-POI-00** **公共搭建件库** `scripts/map_ext/poi_kit.gd`
  - L59 `wall_line()` 断墙外露钢筋 `cyl(..., 6)`；
  - L136, L149-151 `lattice()` 格构铁塔主材 **`tube(..., 8, 2)`**、横斜撑 **`tube(..., 6, 2)`**（全图所有电塔/铁塔）；
  - L210 `cable()` 下垂线缆 **`tube(..., 6, 5)`**；
  - L215 `pipe()` 工业管道 **`tube(..., 14, 3)`**；
  - L252-253 `shelf()` 货架背斜撑 **`tube(..., 5, 2)`**；
  - L281 `sign()` 路牌柱 `cyl(..., 12)`；L290 `railing()` 栏杆柱 `cyl(..., 10)`；L331 `roof_kit()` 屋顶天线 `cyl(..., 10)`；L372 `canopy()` 雨棚立柱 `cyl(..., 14)`。
  - **整改目标**：所有 `lattice`/`pipe`/`cable`/`shelf` 管架统一升至 `seg≥14`（主材/管道 `≥18~20`），或将角钢桁架改为真实倒角角钢/工字钢截面；立柱/栏杆升至 `seg≥16~20`。

- [ ] **P1-POI-01** `scripts/map_ext/poi/school.gd` —— **重灾区（城西学校）**：
  - L47 **108 根教室课桌腿全为 5 边圆柱 (`cyl seg=5`)**；L55 11m 操场旗杆 **`seg=8`**；L59-62 篮球架立柱 `seg=10`、伸臂 **`tube seg=6`**、篮筐 `torus seg=14`；L66-67 秋千架钢管 **`seg=6`**；L77/81 体育馆拱形钢屋架 `tube seg=8`、**塌落斜梁 `tube seg=5`**；L89 操场散落篮球 **`sphere(..., 10)`**；且主教学楼为实心大箱+贴片窗。
- [ ] **P1-POI-02** `scripts/map_ext/poi/hospital.gd` —— **重灾区（城南医院）**：
  - L48 病床护栏立柱 **`seg=6`**；L56/58 发电机排气管 `seg=10`、油桶 `seg=12`；L64/68 医疗帐篷钢支架 `seg=8`；L73/75 **担架床脚与输液架杆全 `seg=5`**；L100-101 救护车车轮/轮毂 `seg=14/12`；且主门诊楼为实心大箱+贴片窗。
- [ ] **P1-POI-03** `scripts/map_ext/poi/egret_bridge.gd` —— **白鹭号舰桥舱**：
  - L35 姿态喷口 `seg=14`；L52 甲板破口露出的 5 根骨架 **`tube(..., 4, 2)`**；L64 斜插断桅 **`tube(..., 8, 3)`**；L69-71 顶灯 `seg=12` + `torus seg=12`；L86 指挥席底座 `seg=12`；L102 黑匣子声呐筒 `seg=12`；L106 尾部 5 根断裂线束 **`cyl(..., 5)`**。
- [ ] **P1-POI-04** `scripts/map_ext/poi/well_core.gd` —— **零号钻井核心台**：
  - L43 12 根井口液压锁紧柱 `seg=10`；L49 井口护栏立柱 `seg=12`；L59 20m 钻塔四主材 **`tube(..., 10, 3)`**；L73-75 五层横撑与斜撑 **`tube(..., 6, 2)`**；L81-84 避雷针 `seg=8`、障碍灯 `seg=12`、19.8m 主动钻杆 `seg=14`。
- [ ] **P1-POI-05** `scripts/map_ext/poi/relay_tower.gd` —— **中继塔**：
  - L55/64 天线与地面电缆 `tube seg=6` / 默认 `7`；L110/125-127 铁塔主材 **`tube seg=8`**、全部横斜撑 **`tube seg=6`**。
- [ ] **P1-POI-06** `scripts/map_ext/poi/mining_terminal.gd` —— **矿区终端**：
  - L22 12m 栈桥腿 `tube seg=10`；L46/54 管柱 `seg=12`；L103/105 矿井架立柱 **`seg=6`**、细杆 `seg=8`；L112-113 悬索 `tube seg=6`。
- [ ] **P1-POI-07** `scripts/map_ext/poi/checkpoint.gd` —— **公路检查站**：
  - L35-42 哨岗雷达/灯座 `seg=8/12/14` + `torus seg=14`；L65 挂环 **`torus seg=10`**。
- [ ] **P1-POI-08** `scripts/map_ext/poi/hydro_lab.gd` —— **水文实验室**：
  - L37 管道 `tube(0.2, 12, 4)`；L47-49 顶灯/仪表 `seg=14/12` + `torus seg=14`；L69 环箍 `torus seg=16`；L72/93 细杆/管 `seg=8/12`。
- [ ] **P1-POI-09** `scripts/map_ext/poi/church.gd` —— **旧港教堂**：
  - L46 五道中殿大石拱肋 **`tube(pts, 0.22, 10, 4)`**（跨度 11m 仅 10 边 × 4 段插值）；L60/63 蜡烛与吊灯杆 `seg=12/10`；L84/86 塔顶十字架柱 `seg=14` + `torus seg=18`。
- [ ] **P1-POI-10** `scripts/map_ext/poi/parking_garage.gd` —— **立体停车楼**：
  - L27/63 盘座与通风筒 `seg=14/12`；L78 2.4m 高立柱 **`seg=6`**。
- [ ] **P1-POI-11** `scripts/map_ext/poi/power_station.gd` —— **发电厂**：
  - L66-67 绝缘环 `torus seg=14` + 杆 `seg=8`（其余主要调用 `poi_kit` 的 `tower` / `lattice`）。

### 6.4 首领地标与战区大型地标清单（`scripts/map_ext/landmarks_boss.gd` & `landmarks.gd`）

- [ ] **P1-LM-01** **`_geothermal_vault`（零号深渊井 · 地热磁约束腔）** `scripts/map_ext/landmarks_boss.gd` L466-510 —— **重灾区**
  - L466 **直径 19.2m 圆形前场竞技平台仅 `cyl seg=12`**（十二边形大盘！）；L469 中心盖 `seg=12`；
  - L473-475 **直径 12.4m 主反应堆压力安全壳与两级穹顶仅 `cyl seg=16 / 12 / 12`**；
  - L489-490 直径 4.7m 顶部蒸汽集箱 `seg=16` + `torus seg=20`；
  - L508-509 **直径 1.0m 跨顶高压蒸汽巨管 `A.tube(pipe_pts, 0.48, 12, 4)`**（巨型拱管仅 4 段折线！）+ 铜法兰 `torus seg=14`。
  - **整改目标**：19m 平台与 12.4m 安全壳升至 `seg=48`、顶部集箱 `32`、蒸汽弯管 `tube(pts, 0.48, 24, 16)` + `torus 28`。

- [ ] **P1-LM-02** **`_submarine_drydock`（东湾船坞港 · 潜艇干船坞）** `scripts/map_ext/landmarks_boss.gd` L546-592
  - L546-551 **直径 4.3m、长 14.6m 巨型潜艇耐压壳仅 `cyl seg=20`、艇艏/艇艉锥仅 `seg=18`**、分段肋环 `torus seg=22`（特写极显多边形棱）；L556 3 根潜望镜桅 `seg=10`；L592 龙门吊双钢索 **`tube(..., 0.08, 6, 3)`**。
  - **整改目标**：潜艇主壳/艏艉升至 `seg=48`（艏部改半球/椭球整流罩）、肋环 `torus 48`、潜望镜 `20`、吊索 `tube seg=14`。

- [ ] **P1-LM-03** **其余首领地标** `scripts/map_ext/landmarks_boss.gd`：
  - `_central_terminus`（L113-136）：20.8m 大跨度穹顶半圆拱肋仅分 **8 段直板**（`arch_segs=8`），建议提至 `16` 段流畅拱线（L159 四坡钟楼尖顶为白名单）；
  - `_converter_foundry`（L243）：铸造桥机双吊索 `cyl(..., 8)`；
  - `_missile_silo`（L287-288）：井盖液压开闭巨缸 (`r=0.26/0.16m`) 仅 `seg=12`；
  - `_bucket_excavator`（L411, L435-436）：耳轴滚筒 `seg=12`；两条主斜拉钢索 **`tube(..., 0.075, 6, ...)`**。

- [ ] **P1-LM-04** **常规战区地标** `scripts/map_ext/landmarks.gd`：
  - `_broken_bridge`（L178, L180）：断口钢筋 `seg=8`、5m 桥面路灯杆 `seg=12`；
  - `_radio_mast`（L203, L211, L656）：28m 广播塔三根主腿 **`tube seg=8`**、横撑 **`tube seg=6`**、拉索 `_wire()` **`tube seg=6, sub=5`**；
  - `_elevated_road`（L262）：高架断口钢筋 `seg=8`；
  - `_windmill`（L381, L392）：风车轮毂/杆 `seg=8/14`；
  - `_observation_tower`（L469, L479, L486）：12m 瞭望塔主腿 `tube seg=10`、细柱/管 `seg=10/14`；
  - `_cable_tower`（L516）：未显式给段数的 `A.tube`（继承 **7 边** 默认值！）；
  - `_crystal_cluster`（L601, L604）：测绘杆 **`tube seg=6`**、设备筒 `seg=14`。

### 6.5 战区设施、内联载具、撤离区、动态事件与飞船（`raid.gd` / `extract_zone.gd` / `events.gd` / `world_link.gd` / `menu_ship.gd` / `hub.gd`）

- [ ] **P1-ENV-01** `scripts/raid.gd` 非弹药低面数模型（共 **37 处低段曲面 + 2 处低段 `tube` + 5 处 `bevel=0`**）：
  - `_tank_wreck()`（L9131-9164）：**主战坦克 12 只负重轮 (`r=0.34m`) 仅 `seg=10`、120mm 主炮/抽气筒/顶舱盖仅 `seg=12/10`；6×6 APC 6 只大越野胎 (`r=0.54m`) 仅 `seg=12`、轮毂 `seg=10`、炮塔 `seg=12`、炮管 `seg=8`**；
  - `_build_perimeter()`（L1092, L1096）：跨河防撞钢桩 `seg=10`、大浮箱 `r=0.42m` 仅 `seg=12`；
  - `_spawn_transport_ship()`（L2376-2399）& `_crashed_ship()`（L1506-1526）：起落架撑杆 `seg=8`、机鼻雷达罩 `seg=14/16`、直径 1.8m 倾转涡扇引擎短舱及进气唇环仅 **`seg=18` / `torus seg=18`**；
  - `_build_one_river()`（L7289, L7301）：河滩圆石 **`A.sphere(0.5, -1, 8)`**（8 边多面球！）、木桩 `seg=12`；
  - `_bridge()`（L7478）：桥墩/柱 `seg=14`；
  - `_wagon()`（L8032, L8055）：铁路货车钢轮 (`r=0.42m`) `seg=12`、缓冲器 `seg=14`；
  - `_scatter()`（L8929-8932）：倒木主干 (`r=0.26~0.31m`) `seg=12`、断枝 `seg=8`；
  - `_dead_tree()`（L9416）：枯树枝 `A.tube(..., 0.036, 6, 3)`（6 边树枝，且主干用 8/5/4 边 `tree_trunk_mesh`）；
  - `_fire_barrel()`（L834, L836）：燃烧桶 `seg=14` + `torus seg=16`；
  - `_poi_lamp()`（L1315-1316）：全图路灯底座与 4.1m 灯杆 `seg=10`；
  - `_bug_spire()`（L1217-1221）：10 边部件 + `tube seg=10`；
  - `_tank()`（L9323）：储油罐顶护栏立柱 `seg=10`；
  - **5 处零倒角 `bevel_box(..., 0.0)`**：L7166-7167 道路虚线/斑马线、L7468 桥面标线、L8006/8008 铁轨与护轨（其中铁轨/护轨为 3D 实体，须改为真实工字轨倒角剖面）。

- [ ] **P1-ENV-02** `scripts/extract_zone.gd`（撤离区全套装置，**17 处低段 + 2 处 6 边天线 + 1 处 6 边拉杆**）：
  - L28-32 频闪信标桩全为 `seg=10` + `seg=6` 天线；
  - L41-43 发烟信号罐 `seg=12/10`；
  - L76-92 固定撤离塔 4.9m 主桅与法兰 `seg=12`、斜撑 `tube(..., 6, 2)`、横杆天线 `seg=8`、信标灯头 `seg=14`；
  - L112-117 运输机降落区四角信标桩底座 **`seg=8`**、灯柱 `seg=10`、天线 `seg=6`。

- [ ] **P1-ENV-03** `scripts/map_ext/events.gd`（动态空投 / 求救信号 / 坠落货柜，**15 处低段 + 2 处低段 `tube`**）：
  - L122-141 **补给空投舱**：直径 7.1m 降落伞伞衣仅 **`cyl seg=12`** + `torus seg=16`、8 根伞绳 **`tube(..., 5, 2)`**、空投舱体 `seg=8`（注：若为八棱舱体则保留主壳，但液压着陆脚 `seg=8`、顶部吊环 `torus seg=14`、姿态喷口 `seg=10` 均需升至 `≥20`）；
  - L164-173 **求救信标台**：三脚架腿 **`tube(..., 6, 2)`**、主桅 `seg=10`、灯头与护环 `seg=12` + `torus seg=12`、1.75m 天线 **`seg=6`**；
  - L210 & L264 **坠落货柜**：逆喷推进器喷口 (`r=0.34~0.42m`) 仅 `seg=12`。

- [ ] **P1-ENV-04** `scripts/world_link.gd`（战区跨图传送闸门与竖井电梯）：
  - L163-164 闸门部件 (`r=0.32/0.42m`) 仅 `seg=12`；L442 竖井部件 `seg=10`。

- [ ] **P1-ENV-05** `scripts/menu_ship.gd` & `scripts/hub.gd`（主菜单与机库，近景特写最高频）：
  - `menu_ship.gd` L105-190：**11 处低段曲面**（`cyl seg=8/12/14`、`sphere seg=10`、`torus seg=12`）+ 2 处 `tube`（`seg=10/12`）+ 2 处 7 边 `A.hose`；
  - `hub.gd` L2838-2948：**5 处低段曲面**（`torus seg=12/14/18`、`cyl seg=6/8`）+ 2 处 7 边 `A.hose`。

---

## 七、【P2】敌人/首领、机甲模块与交互物件清单

### 7.1 常规敌群、虫巢与首领程序化模型（共 **275 处可见低段 + 1 处裸球 + `_sweep`/`_tube` 默认 10 边**）

- [ ] **P2-ENM-01** `scripts/bug.gd`（35 处低段 + `_ball` 16×9 球 + `_sweep` 默认 10 边）：
  - L296 `_pustule()` 发光囊泡 **`sphere(..., 10)`**；L361 `_ball()` 球体 `16×9`；L518 `_sweep()` 默认 `rad=10`；
  - L622 `_foot_pad()` 足垫 `seg=8`；L683-686 `_servo()` 伺服关节 `seg=12/10/6`；
  - `_build_ling()`（6 处 `seg=8/10/14`）、`_tleg()`（`seg=8`）、`_build_spitter()`（14 处 `seg=8/10/12`）、`_pleg()`（2 处 `seg=10`）、`_build_brute()`（6 处 `seg=8/10`）。
- [ ] **P2-ENM-02** `scripts/bugs2.gd`（57 处低段）：
  - 覆盖 `_muzzle`、`build_bomber`（含 `torus seg=12`）、`build_aegis`（`r=0.24*s` 仅 `seg=8`）、`build_mortar`、`build_lancer`、`build_burrower`（**直径 `1.03*s` 钻头环仅 `seg=12`**）、`build_overseer`、`build_ripper`、`build_brood`、`build_colossus`，全部 `seg=8/10/12/14`。
- [ ] **P2-ENM-03** `scripts/enemies/models.gd`（60 处低段 + L63 `_tube` 默认 `rad=10, steps=5`）：
  - `_sac()`（7 处 `seg=12`）、`_mantis()`（`seg=8`）、`_bomber()`（8 处 `seg=10/12/14`）、`_crystal()`（`r=0.42*s` 底座 `seg=8`）、`_burrower()`（10 处 `r=0.45*s` 钻头 `seg=8/12`）、`_mech_beetle()`（8 处含 `torus seg=10/16`）、`_wasp()`（5 处 `seg=6/8/10` 含尾刺 `seg=6`）、`_shielder()`（6 处 `r=0.34*s` 护盾发生器 `seg=8` + `torus seg=16`）、`_mortar()`（5 处 `seg=10/12`）、`_ironjaw()`（4 处 `seg=10`）。
- [ ] **P2-ENM-04** `scripts/nest.gd`（虫巢建筑实体，7 处低段）：
  - L46 **直径 4.1m 虫巢基座仅 `cyl seg=8`**；L47/51 环口 `torus seg=16`；L52 巢心 `seg=12`；L75-77 外露棘刺/管 `seg=8`。
- [ ] **P2-ENM-05** 首领程序化模型与 GLB 附属件（共 **113 处低段**）：
  - `scripts/enemies/boss_models.gd`（37 处）：`_brood` / `_grey_brood` / `_dust_matriarch`（L329 `seg=8` 尖锥）/ `_king` / `_iron_warden`（`torus seg=18`）/ `_queen`（L605 `r=0.50*s` 环仅 `seg=8` + `torus seg=16`）；
  - `scripts/enemies/boss_models_ext.gd`（37 处）：`harbor_reaper` / `slag_colossus` / `dune_devourer`（`torus seg=18`）/ `prism_archon`（**直径 `1.96*s` 棱镜光环 `torus seg=16`**）/ `gorge_tyrant` / `abyss_harbinger`（多道 `torus seg=16/18`）；
  - `scripts/enemies/boss_models_new.gd`（25 处）：`terminus_warden` / `foundry_dreadnought` / `silo_warhead`（导弹筒体 `seg=10/12`）/ `spillway_leviathan` / `excavator_titan` / `core_overlord` / `drydock_behemoth`（`torus seg=14`）；
  - `scripts/enemies/boss_modular_glb.gd`（12 处）：`build_citadel_behemoth`（L161 巨足底 `r=0.62*s` 仅 `seg=8` + `torus seg=14`）、`build_sky_carrier`（L423 `torus seg=14` + `cyl seg=10/12/14`）；
  - `scripts/enemies/boss_glb.gd`（2 处）：L121/126 胸口弱点核心 `sphere(..., 14)`；
  - `scripts/enemies/spawn_util.gd`（2 处）：L161/172 首领巢穴底座 `seg=10` & 晶刺 `seg=6`。

### 7.2 机甲核心 / 武器 / 动力炉 / 底盘模块（88 个文件，非导弹发射巢部分）

> 全仓机甲模块已自动分离 `1,167` 处微小六角螺栓（`r≤0.03m, seg=6`）；下列 **833 处可视低分段曲面 + 23 处 7 边 `A.tube` + 39 处 `A.hose`** 均为真实低面数（主要集中在散热/复进筒、多管转膛、吊环 `torus seg=12`、轮毂/负重轮 `seg=10~14`、以及软管）：

- [ ] **P2-MECH-01** **手臂武器（33 个非导弹武器文件）**：
  - 高频重灾文件：`arm_m10flm.gd`（35 处 + 2 处 7 边 `tube`）、`arm_m82.gd`（35 处）、`arm_pb09.gd`（19 处）、`arm_mk108.gd`（17 处）、`arm_m68.gd`（14 处 + `tube`）、`arm_ks60.gd`（13 处）、`arm_m45.gd`（12 处）、`arm_ntw57.gd`（12 处）、`arm_hc40.gd`（11 处 + `tube`）、`arm_th60.gd`（11 处含 4 根 1.34m 细管 `seg=8` + `tube`）、`arm_gau8.gd`（10 处多管枪管 `seg=12/14` + `tube`）、`arm_m777.gd`（9 处）、`arm_flamer.gd`（7 处含双 `sphere seg=14` 燃料罐 + 2 `hose`）、`arm_m242.gd`（7 处含 5 根 `seg=8`）、`arm_rh120.gd`（7 处）、`arm_phalanx.gd`（7 处 6 管 `seg=10/12`）、`arm_hmg.gd` / `arm_shotgun.gd`（各 6 处）、`arm_cannon.gd` / `arm_bofors40.gd` / `arm_slug.gd`（各 5 处）、其余 12 个武器文件（1~4 处 + `hose`）。
- [ ] **P2-MECH-02** **躯干核心（19 个 `core_*.gd` 文件）**：
  - 共 250+ 处可见低分段，几乎全部含通用肩部液压缸（`seg=14/12`）、吊耳环（`torus seg=12`）、烟雾弹发射器/观瞄头（`seg=8/10/12`）、细天线（`seg=8`）；其中 `core_m1a2_sepv3.gd`（36 处）、`core_merkava_mk4m.gd`（29 处）、`core_abv_shredder.gd`（25 处）、`core_trieste_bathy.gd`（23 处 + 2 `tube`）、`core_bradley_busk.gd` / `core_pionier_dach.gd`（各 22 处）、`core_patriot_mpq65.gd`（18 处）、`core_bmpt_terminator.gd`（15 处）最多；`core_pantsir_s1.gd` 另有 2 处 7 边 `tube`。
- [ ] **P2-MECH-03** **动力炉（15 个 `gen_*.gd` 文件）**：
  - 共 175 处可见低分段 + 12 处 7 边 `tube` + 12 处 `hose`；重点：`gen_homopolar_pulse.gd`（24 处 + 2 `tube`）、`gen_mhd_plasma_gen.gd`（24 处 + 2 `tube`）、`gen_naval_pwr_s9g.gd`（20 处）、`gen_stirling_aip.gd`（20 处 + 2 `tube`）、`gen_hydrothermal_hx.gd` / `gen_mtu_mb873_v12.gd` / `gen_pem_fuelcell.gd`（各 14 处）、`gen_agt1500_turbine.gd` / `gen_lfr_lead_bismuth.gd`（各 12 处 + 2 `tube`）、`gen_crystal.gd`（7 处含 `seg=6` 晶柱）。
- [ ] **P2-MECH-04** **底盘足部（16 个 `legs_*.gd` 文件）& 背部货架（`back_cargo.gd` / `back_rack.gd`）**：
  - 履带底盘（`legs_tread*.gd`）的**负重轮与托带轮仅 `seg=10 / 12 / 14`**、吊环 `torus seg=12`；
  - 多足/双足底盘（`legs_hex*.gd` / `legs_quad*.gd` / `legs_biped*.gd` / `legs_titan.gd`）的髋/膝关节柱仅 `seg=8 / 10 / 12 / 14`、吊环 `torus seg=12` + 19 处 `A.hose`；
  - `back_rack.gd`（5 处管架 `seg=8/10`）、`back_cargo.gd`（1 处 `seg=8`）。

### 7.3 物资箱、掉落物品与 NPC 配件

- [ ] **P2-PROP-01** `scripts/loot_box.gd`（9 处低段，全图高频近距交互）：
  - `_build_tool()` L270 提手 `seg=8`；`_build_military()` L311/314 锁扣与天线 `seg=10/8`；`_build_safe()` L333-334 密码转盘 `seg=12`；`_build_wreck()` L366-374 残骸箱体阀门与天线 `seg=10/8`。
- [ ] **P2-PROP-02** `scripts/item_models.gd`（51 处低段，背包 3D 预览特写直接暴露多边形！）：
  - 覆盖 24 种物品模型（罐头环 `torus 16`、净水片 `sphere 14`、咖啡豆 `sphere 12`、电线 `cyl 10`、玩具球 **`sphere 14/12/10`** + `torus 14`、信标与声波诱饵 **`cyl 8` + `sphere 12`**、高能电池棒 `cyl 6/12` + `torus 18`、撤离屏障道具 **`cyl 8`**、手表/扳手/水壶/档案卷/磁带等 `seg=8~14`）。
- [ ] **P2-PROP-03** `scripts/factions/npc_mech.gd` L116-120 `_add_raider_kit()`：4 处掠夺者附加件 `cyl seg=10/8`。

---

## 八、建议分阶段整改执行顺序与门禁方案

为在最短时间内彻底消灭玩家视野中的低面数观感，建议按以下 **4 个阶段** 推进：

| 阶段 | 范围 | 预期收益 | 预计改动量 |
| :---: | :--- | :--- | :---: |
| **Stage 1（底层根治）** | 修复 `art.gd`（`cyl`/`sphere`/`torus`/`capsule`/`tube`/`hose`/`reactive_arc_mesh`/`tree_trunk_mesh`/`rock_mesh`）+ `kit.gd` + `bug.gd::_ball/_sweep` + `models.gd::_tube` | **一次性自动拉升全仓 2,000+ 处曲面与全部 121 处管线/软管的分段下限**，彻底堵住 `seg < 8` 漏洞 | ~6 个核心文件 |
| **Stage 2（技能与导弹重制）** | 全量高精重制 `extract_barrier`、`decoy_beacon`、`slow_web`、`hazards.gd`（`LobShell`/`RocketSalvo`/`KineticSlug`/`SpikeRow`）、`raid.gd` 全部弹体/弹翼/圆柱弹壳/弹托/破片、`enemy.gd::_slash_fx`、12 个发射巢内弹头 | **彻底清零战斗中最显眼的技能灰盒与低模导弹/方块弹壳** | ~20 个文件 |
| **Stage 3（建筑 / 地标 / POI / 远景升级）** | 重制 `ter_arid_flora_pylon.gd`；升级 `raid.gd::_build_backdrop` + `buildings_ext.gd` + `raid.gd::_building` 窄楼 + `menu_city.gd`；精修 29 个 `scripts/buildings/*.gd` 大曲面；精修 11 座 POI（优先 `school`/`hospital`/`egret_bridge`/`well_core`）与 `poi_kit` + `landmarks*`（优先 `geothermal_vault`/`submarine_drydock`）+ `extract_zone`/`events`/`_tank_wreck` | **彻底根除建筑、地标、POI、载具残骸与远景城区的低面数多边形** | ~55 个文件 |
| **Stage 4（敌群 / 机甲 / 物件精修 + CI 门禁）** | 清理 `item_models.gd`（背包特写）、`loot_box.gd`、`nest.gd`、敌人/首领/机甲残余低段；并在 `tests/` 新增 **低面数静态扫描门禁测试**（禁止新增 `BoxMesh`/`PrismMesh` 裸实体、禁止无白名单标记的 `seg < 16` 曲面与 `tube < 12`） | **形成永久防回退机制，确保后续永不引入低面数模型** | ~10 个重点文件 + 1 个门禁脚本 |
