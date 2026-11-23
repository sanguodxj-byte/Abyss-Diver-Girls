# Google AI Studio Build 委托建模操作手册（补丁包交付规范）

> 本文档面向 **Google AI Studio Build**（通过 GitHub 导入本仓库后执行批量高精度建模细化，并输出可下载补丁包供本地 Blender + Godot 一键合入验证）。

---

## 1. 协作流程（GitHub → AI Studio Build → 本地一键验收）

```text
[GitHub 仓库]
  ├── docs/MECH_MODELING_STANDARD.md        ← 硬性建模/面数/材质/接口规范 v1.0
  ├── docs/MECH_REFINEMENT_MANIFEST.md      ← 全量 101 模块批次清单与进度
  ├── tools/mech_kitbash/manifest.json      ← 101 模块精确坐标/IK/枪口/设计 Brief
  ├── tools/mech_kitbash/kitbash_lib.py     ← Blender Kitbash API（必须严格按此调用）
  ├── tools/mech_kitbash/builders/starter_* ← 已实机验收的 5 类基准范本（核心参考！）
  └── scripts/modules/<module_id>.gd        ← 原版造型比例与特征参考
        │
        ▼ (Google AI Studio Build 按批次生成纯 Python Builder 补丁包 .zip)
[本地一键合入与验收]
  python tools/mech_kitbash/apply_patch.py <下载的补丁包.zip> --jobs 4
        │
        ├─ 1. AST 语法、安全与材质槽/UV带静态校验（不污染引擎代码）
        ├─ 2. Blender 5.1.2 并发生成 GLB + 24-ray 光追顶点 AO + MikkTSpace 切线
        ├─ 3. audit_glb.py 自动合规红线审计（面数 / 体积 / 零贴图 / 零负缩放 / Socket）
        ├─ 4. 刷新 docs/MECH_REFINEMENT_MANIFEST.md 完成进度
        └─ 5. Godot --import + --npc_visual_bake + --npc_visual_cache_test 自动闭环
```

---

## 2. 补丁包交付格式要求（硬性规则）

1. **只需提交纯 Python Builder 文件**，放置在：
   - 按批次合并：`tools/mech_kitbash/builders/<batch_id>.py`（推荐，如 `batch_02a_cores_tactical.py`）
   - 或单模块拆文件：`tools/mech_kitbash/builders/<module_id>.py`
2. **禁止修改其他文件**：不要修改 `builders/__init__.py`（系统已自动扫描注册所有 `def build_<module_id>(kb: KitbashScene):`）、不要修改 `kitbash_lib.py` / `specs.py` / 任何 `.gd` 游戏脚本！
3. **函数命名规范**：每个模块必须是一个顶层函数，函数名严格为 `def build_<module_id>(kb: KitbashScene):`（例如 `def build_core_m1a2_sepv3(kb: KitbashScene):`）。
4. **仅允许导入**：`math`、`mathutils`（`Vector`）、`kitbash_lib`（`KitbashScene`, `g2b_mat`, `g2b_bone_mat`, `crect_2d`, `trap_2d`）、`specs`（`HP_C1_RADIUS` 等）。严禁网络/文件/子进程调用。
5. **建议同时提供一个简明的前端预览/进度导出界面**（AI Studio Build 擅长做轻量 Web App）：展示本批次完成的模块列表、每个模块的设计亮点，并提供「**一键下载补丁包 (.zip)**」按钮，zip 内直接打包 `tools/mech_kitbash/builders/<batch_id>.py`！

---

## 3. `KitbashScene` 核心 API 速查表

> 所有坐标与角度均为 **Godot 右手坐标系（米制，`-Z` 正前、`+Y` 正上、`+X` 正右）**，无需手动换算 Blender 轴向！

### 3.1 基础原语（默认 `bevel_seg=1`，45° 硬切倒角 + Face-Weighted Normals）
- `kb.box(name, (sx, sy, sz), mat_slot, band_key, pos=(0,0,0), rot_deg=(0,0,0), bevel_w=0.012, bevel_seg=1, M_parent=None, tile_u=1.0, tile_v=1.0, group=None)`
- `kb.plate(name, outline_xy, thick, mat_slot, band_key, pos=(0,0,0), rot_deg=(0,0,0), bevel_w=0.012, bevel_seg=1, M_parent=None, group=None)`
  - 配合 `crect_2d(w, h, (cTL, cTR, cBR, cBL))` 或 `trap_2d(wb, wt, h, cut)` 构建多面切角斜装甲。
- `kb.loft(name, [(z0, pts0), (z1, pts1), ...], mat_slot, band_key, ...)` — 截面放样壳体。
- `kb.cyl(name, r_top, r_bot, h, segs, mat_slot, band_key, pos=(0,0,0), rot_deg=(0,0,0), chamf=0.005, hollow_r=0.0, M_parent=None, u_rep=1.0, group=None)`
  - **注意**：`rot_deg=(90, 0, 0)` 时圆柱轴沿 Godot Z，`+Y` 朝 `-Z`（正前）；`rot_deg=(0, 0, 90)` 时轴沿 X。
- `kb.lathe(name, [(r0, y0), (r1, y1), ...], segs, mat_slot, band_key, ...)` — 车削旋转体（炮塔座圈、喷口、反应堆外壳）。
- `kb.tube_path(name, [p0, p1, p2, ...], r, segs=8, mat_slot="gunmetal", band_key="braid_hose", add_clamps=True, M_parent=None, group=None)` — 高压软管/冷却铜管 + P型管卡。

### 3.2 高精度复用 Kitbash 工业组件（直接拼装出 3 层轮廓密度！）
- `kb.spaced_armor_plate(prefix, (sx, sy, sz), mat_slot, band_key, pos, rot_deg=(0,0,0), standoffs=True, bolts=True, M_parent=None, group=None)` — 双层间隔装甲板 + 暗钢底框 + 四角螺栓
- `kb.hydraulic(prefix, p_from, p_to, r=0.022, M_parent=None, group=None)` — 重型液压杆（枪钢油缸 + 橡胶波纹防尘套 + 黄铜油封 + 镀铬活塞杆 + 双耳轴）
- `kb.actuator_drum(prefix, pos, r, w, M_parent=None, group=None)` — X 轴重型关节作动鼓 + 齿轮加强环 + 8 螺栓法兰
- `kb.louver_bay(prefix, w, h, d, pos, rot_deg=(0,0,0), blades=5, mesh_style=False, M_parent=None, group=None)` — 嵌入式百叶散热舱（`mesh_style=True` 为冲孔防烫网）
- `kb.headlight_cage(prefix, pos, rot_deg=(0,0,0), M_parent=None, group=None)` — 带焊接钢管防撞笼的双大灯总成
- `kb.eoir_gimbal(prefix, pos, M_parent=None, group=None)` — 阿帕奇式三目 EO/IR 光电稳瞄云台
- `kb.smoke_pod(prefix, pos, rot_deg, M_parent=None, group=None)` — 三联空心烟雾弹发射器
- `kb.cupola_hatch(prefix, pos, M_parent=None, group=None)` — 10 螺栓车长指挥塔 + 铰链舱盖 + 三面潜望镜
- `kb.recon_mast(prefix, pos, M_parent=None, group=None)` — 折叠式相控阵雷达桅杆 + 双弹簧鞭状天线
- `kb.stowage_rack(prefix, pos, rot_deg=(0,0,0), M_parent=None, group=None)` — 焊接管框储物架 + 绑带弹药箱 + 警示保险杠
- `kb.era_block(prefix, (sx, sy, sz), mat_slot, pos, rot_deg=(0,0,0), M_parent=None, group=None)` — 爆炸反应装甲块 + 四角螺栓
- `kb.grab_rail(prefix, w, d, pos, rot_deg=(0,0,0), r=0.011, M_parent=None, group=None)` — 弯折钢制维修抓手
- `kb.bolt_ring(prefix, r, n_bolts, bolt_r=0.012, pos=(0,0,0), rot_deg=(90,0,0), M_parent=None, group=None)` — 环形六角螺栓圈
- `kb.tow_shackle(prefix, pos, rot_deg=(0,0,90), scale=1.0, M_parent=None, group=None)` — 锻钢牵引吊环
- `kb.waist_collar_core(prefix="HP_C1_Core", y_top=0.14)` — **所有 `core_*` 必调！** 统一 `HP-C1` 腰部齿轮座圈（`r=0.360m, y_bot=-0.005m`）
- `kb.waist_collar_legs(prefix, socket_y, ped_bot_y)` — **所有 `legs_*` 必调！** 统一 `HP-C1` 底盘腰领（自动保留 `>=0.018m` 间隙）
- `kb.arm_bulkhead(prefix, x_abs, y, z=0.0)` — `core_*` 两侧对称 `HP-A1` 回转肩座
- `kb.a1_shoulder_mount(prefix="A1Mount", heavy=False)` — **所有 `arm_*` 必调！** 右臂 (`side=+1.0`) 标准 `HP-A1` 法兰/轴承/叉架
- `kb.barrel_bore(prefix, r_outer, r_inner, pos, depth=0.08, rot_deg=(90,0,0), segs=14, M_parent=None)` — 真实空心炮口冠 + 深黑枪膛（炮管实体末端应退后 `0.02m` 避免穿透空心冠）

### 3.3 层级骨骼与接口标记
- `kb.add_group(group_key, leaf_name, pos, rot_deg=(0,0,0), parent_key="")` + `kb.use_group(group_key)`（用于 `legs_*` 可动腿部：`Leg_L/Knee/Ankle`, `Leg_0/Femur/Knee/Ankle`, `Track_L/Track_R`）
- `kb.add_marker(name, pos, rot_deg=(0,0,0), parent_key="")`：
  - `core_*` **必含**：`SOCKET_arm_l`, `SOCKET_arm_r`, `SOCKET_back`, `SOCKET_gen`（严格取自 `manifest.json` 原坐标！）
  - `legs_*` **必含**：`SOCKET_core`；双足必含 `Leg_L`/`Leg_R` -> `Knee` -> `Ankle` + `MARK_SOLE`；四/六足必含 `Leg_0..N` -> `Femur` -> `Knee` -> `Ankle`；履带必含 `Track_L`, `Track_R`
  - `arm_*` **必含**：`MUZZLE`（按右臂 `side = +1.0` 构建，左臂由引擎无负缩放自动镜像！）
  - 动力炉发光点可选：`LIGHT_core`

### 3.4 合法 `mat_slot` 与 `band_key` 白名单（写错将被静态校验拦截）
- **`mat_slot`**：`armor`, `armor_sub`, `armor_dark`, `dark`, `gunmetal`, `chrome`, `copper`, `brass`, `rubber`, `hazard`, `accent`, `bore`, `glass`, `emit_headlight`, `emit_amber`, `emit_cyan`, `emit_red`, `emit_core`
- **`band_key`**：`armor_panel`, `armor_hatch`, `armor_ribs`, `armor_pocket`, `vent_louver`, `vent_mesh`, `dust_boot`, `braid_hose`, `gear_collar`, `hazard`, `bolt_flange`, `frame_cnc`, `plain_metal`

---

## 4. 直接复制给 Google AI Studio Build 的委托提示词模板

```text
请阅读本仓库的以下文件，作为严格执行依据：
1. docs/MECH_MODELING_STANDARD.md（机甲建模标准 v1.0）
2. docs/AISTUDIO_BUILD_BRIEF.md（补丁包与 KitbashScene API 规范）
3. docs/MECH_REFINEMENT_MANIFEST.md 与 tools/mech_kitbash/manifest.json（101 模块清单与精确坐标）
4. tools/mech_kitbash/kitbash_lib.py 与 tools/mech_kitbash/builders/starter_*.py（5 大类基准范本）

本次任务：请完成批次【batch_02a_cores_tactical】（共 10 款躯干模块）的高精度 Kitbash Python 建模！
要求：
- 对批次内每个模块，先阅读其原版 scripts/modules/<id>.gd 保留标志性军事轮廓、特征武器/传感器与精确的 SOCKET_* 坐标；
- 使用 KitbashScene API 全面重构为三层硬表面工业细节（间隔装甲、百叶/冲孔网、液压波纹杆、编织软管、螺栓圈、警示条、深度观察窗/光电云台，消灭所有光秃大盒子），并严格遵守类别面数预算与合法 mat_slot / band_key 白名单；
- 产出一个干净的补丁包（打包 tools/mech_kitbash/builders/batch_02a_cores_tactical.py），并在应用页面提供清晰的任务进度面板与「下载补丁包 (.zip)」按钮，供本地执行 `python tools/mech_kitbash/apply_patch.py <zip>` 一键在 Blender 中生成 GLB 并通过 audit_glb.py 红线审计。
```

> 换下一个批次时，只需把提示词里的 `【batch_02a_cores_tactical】` 替换成清单里的 `batch_02b_cores_heavy`、`batch_03a_legs_walk`、`batch_03b_legs_multi`、`batch_04a_arms_ballistic`、`batch_04b_arms_heavy`、`batch_04c_arms_ordnance`、`batch_05a_backs_all`、`batch_05b_gens_all` 即可！
