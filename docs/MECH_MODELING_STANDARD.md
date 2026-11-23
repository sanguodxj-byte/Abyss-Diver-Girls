# 机甲全模块高精度建模规范（MECH MODELING STANDARD v1.0）

> **适用范围**：全游戏 **101 个机甲模块**（`core_*` 21、`legs_*` 16、`arm_*` 42、`back_*` 6、`gen_*` 16）。  
> **技术路线**：**参数化工业 Kitbash 零件库 + 全局共享 2K 硬表面 Trim Sheet + Blender 离线烘焙 24-ray 光追顶点 AO/磨损 + 无贴图预导入 GLB**。  
> **核心目标**：以极低显存与包体增量（全游戏共用 1 套 2K Trim Sheet，VRAM 仅 ~3–4 MB），让全部 101 个机甲模块达到重工业硬表面精模水准，同时 100% 兼容接口互换、双足/四足/六足/履带动画、左右臂镜像、阵营涂装、战损烧灼、雨湿高光、遮挡透视与 `npc_modules.res` 离线合批缓存。

---

## 1. 资产目录与命名约定

| 资产类型 | 规范路径 | 说明 |
| :--- | :--- | :--- |
| 共享 2K Trim Sheet | `res://assets/textures/mech_trim_{a,n,orm}.png` | 全游戏机甲共用；VRAM 压缩（BPTC/BC7），禁用无损 |
| 生产着色器 | `res://shaders/mech_trim.gdshader` / `mech_trim_occ.gdshader` | 支持动态阵营染色、战损、雨湿、顶点 AO、凸边磨损、天光轮廓光 |
| 模块 GLB 产出 | `res://assets/models/mech_modules/<module_id>.glb` | **严格零内嵌贴图**；由 Godot 预导入为二进制 `PackedScene`（`<2ms` 加载） |
| 运行时加载器 | `res://scripts/modules/mech_glb.gd` | 挂载共享材质、重建 `Socket_*`/`Plug`/`MUZZLE`/腿部 IK 元数据、无负缩放镜像左臂 |
| Kitbash 工具链 | `tools/mech_kitbash/` | `trim_sheet.py` / `kitbash_lib.py` / `specs.py` / `builders/*.py` / `build_all.py` |
| 回退机制 | `res://scripts/modules/<module_id>.gd` | 未出 GLB 的模块自动无缝回退旧 `.gd`，支持分批渐进替换、随时可运行 |

---

## 2. 几何、面数与法线标准（硬性红线）

### 2.1 坐标系与尺度
- **单位与朝向**：与 Godot 严格 1:1（米制，`-Z` 正前、`+Y` 正上、`+X` 正右）。
- **Blender 换算**：`g2b(gx, gy, gz) = (gx, -gz, gy)`，导出勾选 `export_yup=True`。
- **模块原点**：
  - `legs_*`：地面正中 `(0, 0, 0)`；
  - `core_*` / `arm_*` / `back_*` / `gen_*`：对应公插头接合面中心 `(0, 0, 0)`。
- **严禁负缩放**：所有节点 `scale` 必须为正 `(1, 1, 1)`，保证 `normal_audit` 零误差。左臂 (`arm_l`) 由 `mech_glb.gd` 在网格层面镜像顶点/法线/切线并翻转三角形绕序后缓存。

### 2.2 倒角、分段与面数预算（生产推荐档）
- **倒角策略**：主装甲板与结构盒使用 **`bevel_segments = 1`**（45° 硬切倒角 + Face-Weighted Normals），在保持锐利金属高光折边的同时比 2-seg 减少 ~45% 面数；仅超大圆弧曲面或核心观察罩使用 `segments = 2`。
- **圆柱分段规范**：
  - 大径承力件（`r >= 0.25m`）：`24–28` 段；
  - 中径筒体/炮管（`0.08m <= r < 0.25m`）：`14–18` 段；
  - 小径螺杆/销轴/软管（`r < 0.08m`）：`6–10` 段（六角螺栓统一 `6` 段）。

| 模块类别 | 数量 | 目标面数区间 (`tris`) | 单件 GLB 体积上限 | 材质槽上限 (每刚体组) |
| :--- | :---: | :---: | :---: | :---: |
| `core_*` 躯干 | 21 | `10,000 – 22,000` | `<= 1.20 MB` | `<= 12` |
| `legs_*` 底盘 | 16 | `12,000 – 26,000` | `<= 1.40 MB` | `<= 10` |
| `arm_*` 臂部武器 | 42 | `5,000 – 14,000` | `<= 0.85 MB` | `<= 10` |
| `back_*` 背部挂载 | 6 | `5,000 – 12,000` | `<= 0.75 MB` | `<= 10` |
| `gen_*` 动力炉 | 16 | `5,000 – 12,000` | `<= 0.75 MB` | `<= 10` |
| **整机 6 件套总计** | 6 | **`45,000 – 85,000`** | — | — |

### 2.3 必选顶点属性与烘焙规范
所有导出 GLB 必须在导出前执行 `TRIANGULATE (keep_custom_normals=True)`，并包含完整 5 个属性：
1. `POSITION`
2. `NORMAL`（100% 朝外校验：`signed_volume > 0`；开启 Face-Weighted Smooth Normals）
3. `TANGENT`（MikkTSpace 切线，确保 2K Trim Sheet 法线贴图零接缝、零反光错误）
4. `TEXCOORD_0`（映射到 2K Trim Sheet 对应功能带）
5. `COLOR_0`（`CORNER` 域线性 `FLOAT_COLOR`）：
   - **`R` 通道**：`1.0 - convex_edge`（外凸棱边 = `0.0`，平面/凹槽 = `1.0`，驱动 Shader 金属棱边掉漆高光）；
   - **`G` 通道**：Blender `BVHTree` **24-ray 半球光追环境光遮蔽 (Vertex AO)**，真实压暗零件交界死角与凹槽；
   - **`B` / `A` 通道**：保留 `1.0`。

---

## 3. 共享 2K Trim Sheet 与标准材质槽

### 3.1 六功能带 UV 布局（`2048 × 2048`）
| 带编号 | V 范围 (`[0, 1]`) | 功能内容 | 典型应用部位 |
| :---: | :---: | :--- | :--- |
| **Band 0** | `0.00 – 0.24` | 倒角装甲分缝板 + 沉头六角螺栓 + D型扣检修盖板 | 主装甲板、首上首下、炮塔侧板、腿甲 |
| **Band 1** | `0.24 – 0.42` | 冲压加强筋槽 + 双排铆钉 + CNC 减重孔 | 承力副甲、弹箱外壳、货架背板、机匣侧盖 |
| **Band 2** | `0.42 – 0.58` | 左半：14叶深斜百叶散热格栅；右半：交错冲孔防烫网 | 散热舱、动力炉进气口、炮管防烫罩 |
| **Band 3** | `0.58 – 0.72` | 左：橡胶波纹防尘套；中：编织不锈钢软管；右：精铣回转齿圈 | 液压杆护套、高压油管、腰部/肩部回转轴承 |
| **Band 4** | `0.72 – 0.84` | 左半：斑驳黄黑工业警示条；右半：重载螺栓法兰带 | 警示保险杠、接口警示箍、弹鼓警示环 |
| **Band 5** | `0.84 – 1.00` | 铸钢 CNC 减重凹槽 + 6螺栓圆形检视口 | 铸钢骨架、关节鼓、底盘车体 |

### 3.2 13 个标准材质槽（Mesh 对象命名规则：`<NodeGroup>__<mat_slot>`）
为了兼容 `npc_mech._paint()`（敌对流浪者锈红涂装 / 队友识别灯）与 `mech._batch_visual()`，**同一刚体组内按材质槽合并为独立 `MeshInstance3D`**，严禁单 Mesh 混多 Surface：

| 材质槽后缀 | 绑定材质 | 动态涂装行为 | 说明 |
| :--- | :--- | :--- | :--- |
| `armor` | `mech_trim` (`ctx.color`, `metal=0.26`, `rough=0.46`, `takes_damage=1`) | 随模块 `REAL` 色与阵营变化 | 主装甲漆面 |
| `armor_sub` | `mech_trim` (`ctx.color.darkened(0.24)`, `metal=0.32`, `rough=0.44`, `takes_damage=1`) | 随模块色加深变化 | 次级/内层装甲 |
| `dark` | `mech_trim` (`#212429`, `metal=0.68`, `rough=0.42`) | 保持深冷钢骨架 | 主桁架、内构、关节壳 |
| `gunmetal` | `mech_trim` (`#3B4047`, `metal=0.80`, `rough=0.36`) | 保持精铣枪钢 | 炮管、机匣、法兰、散热叶 |
| `chrome` | `mech_trim` (`#C2C9D6`, `metal=0.95`, `rough=0.18`) | 保持镀铬亮钢 | 液压活塞杆、螺栓头、销轴 |
| `copper` | `mech_trim` (`#AD6138`, `metal=0.88`, `rough=0.28`) | 保持紫铜 | 冷却铜管、电池母排、散热鳍 |
| `brass` | `mech_trim` (`#A3803D`, `metal=0.86`, `rough=0.30`) | 保持黄铜 | 液压油封、阀门、棘轮轴 |
| `rubber` | `mech_trim` (`#17181B`, `metal=0.04`, `rough=0.86`) | 保持哑光黑橡胶 | 波纹管、足底防滑垫、挡泥板、软管 |
| `hazard` | `mech_trim` (`raw_albedo=1.0`, `metal=0.12`, `rough=0.48`) | **保留原始黄黑警示色** | 仅用于映射 Band 4 左半的警示面 |
| `accent` | `mech_trim` (`K.ACCENT`, `metal=0.18`, `rough=0.48`) | 保持低饱和工业琥珀黄 | 接口标记条、战术识别带 |
| `bore` | `K.bore_mat()` | 纯黑超哑光 | 枪膛内壁、炮口泄气槽、凹陷暗底 |
| `glass` | `K.canopy(K.VISOR, 0.28)` | 光学镀膜玻璃 | 驾驶舱防弹观察窗、潜望镜、瞄具镜片 |
| `emit_*` | `A.emit(...)` | 敌我自动换色（视类型） | `emit_headlight`（暖白）/ `emit_amber`（琥珀）/ `emit_cyan`（光电青）/ `emit_red`（警示红）/ `emit_core`（跟随 `ctx.info.color`） |

---

## 4. 机械接口与关节层级标准（零穿模、全动画兼容）

### 4.1 统一机械接口硬性尺寸
- **`HP-C1` 腰部回转座圈**（`legs` → `core`）：
  - 统一对接半径 **`r = 0.360m`**，中心 **`(0, y, 0)`**；
  - 底盘腰领顶面必须满足 **`y_top <= SOCKET_core.y - 0.015m`**；
  - 躯干底裙必须满足 **`y_bot >= -0.005m`**，裙口包络半径 **`r <= 0.360m`**。
- **`HP-A1` 臂部法兰**（`core` → `arm_l` / `arm_r`）：
  - 躯干导出 `SOCKET_arm_l` / `SOCKET_arm_r` Empty，左右严格对称 `x = ±socket_x`；
  - 武器模块统一以 **右臂 (`side = +1.0`)** 为标准建构，插头法兰居中在 `(0, 0, 0)`，机匣沿 `+X` 向外延伸，枪口朝 `-Z`，必须导出 `MUZZLE` Empty。
- **`HP-B1` 背部双导轨**（`core` → `back`）：
  - 躯干导出 `SOCKET_back` Empty（拆卸方向 `out = (0, 1, 0.25).normalized()`）；
  - 背包插头卡箍覆盖 `y = -0.04..+0.11m`，消除悬空缝。
- **`HP-G1` 动力舱**（`core` → `gen`）：
  - 躯干导出 `SOCKET_gen` Empty（拆卸方向 `out = Vector3.BACK`）；
  - 动力炉安装背板紧贴 `z = 0.0..0.11m`，所有散热/电芯/仪表面向 `+Z`。

### 4.2 可动底盘 (`legs_*`) GLB 节点树规范
`mech_glb.gd` 按 GLB 内标准节点名自动绑定 `leg_parts`、`leg_type` 与全部 IK 元数据，确保 `mech.gd` 步行/转向/冲刺动画 100% 原生驱动：

1. **双足 `biped`**（4 款）：
   ```text
   Root
   ├── Pelvis__<mat>...         (骨盆 + 腰柱 + 护腰液压，静态)
   ├── SOCKET_core              (Empty：HP-C1 插座坐标)
   ├── Leg_L                    (髋枢轴，pos = (-hip_x, hip_y, 0))
   │   ├── Leg_L__<mat>...      (髋作动器 + 大腿 + 护膝)
   │   ├── MARK_SOLE            (Empty：y = sole 相对髋高度)
   │   └── Knee                 (膝枢轴，local pos = KN)
   │       ├── Knee__<mat>...   (小腿 + 减震油缸)
   │       └── Ankle            (踝枢轴，local pos = AN - KN)
   │           └── Ankle__<mat>... (机械爪足 + 三趾 + 后跟)
   └── Leg_R                    (同上，pos = (+hip_x, hip_y, 0))
   ```
2. **四足 `quad` (4 款) / 六足 `hex` (4 款)**：
   ```text
   Root
   ├── Pelvis__<mat>...         (中央车体 + 炮塔座圈)
   ├── SOCKET_core              (Empty)
   └── Leg_0 .. Leg_{N-1}       (基节枢轴，pos = hip_pos, rot.y = base_yaw)
       ├── Leg_i__<mat>...      (基节轴承鼓)
       └── Femur                (股节枢轴，local pos = (0,0,0))
           ├── Femur__<mat>...  (大腿 + 膝护罩)
           └── Knee             (膝枢轴，local pos = KN)
               ├── Knee__<mat>... (胫节)
               └── Ankle        (踝枢轴，local pos = FT - KN)
                   └── Ankle__<mat>... (液压足垫)
   ```
3. **履带 `tread` (4 款)**：
   ```text
   Root
   ├── Hull__<mat>...           (斜装甲车体 + 座圈领口 + 车灯 + 副油箱)
   ├── SOCKET_core              (Empty)
   ├── Track_L                  (左履带总成：履带链 + 主动/诱导轮 + 负重轮 + 侧裙)
   └── Track_R                  (右履带总成)
   ```

---

## 5. 美术质感细化铁律（消灭“积木感”检查清单）

每个模块在提交前，必须满足以下 **5 条结构层次标准**（缺一不可）：
1. **三层轮廓密度**：主壳体（Primary）→ 间隔附加装甲/支架/仓盖（Secondary）→ 螺栓圈、抓手、软管、防撞笼、传感器、吊环（Tertiary），严禁任何大面积光秃平整盒子。
2. **功能逻辑闭环**：每个外挂件必须有连接支座/法兰/支架/卡箍焊在主体上，严禁“悬浮贴片”。
3. **深度与镂空感**：所有炮口、烟雾弹筒、进气百叶、观察窗、灯杯必须有真实凹腔或内膛 (`bore`)，绝不出现实心灰圆柱或平板贴纸窗。
4. **冷暖与材质对比**：哑光漆面装甲 (`rough 0.46`) + 深冷骨架 (`dark`) + 亮镀铬活塞/螺栓 (`chrome`) + 紫铜/黄铜管件 (`copper/brass`) + 哑光黑橡胶 (`rubber`) + 局部黄黑警示 (`hazard`)。
5. **自动合规审计 (`build_all.py --audit`)**：每个 GLB 必须通过自动验收（零内嵌贴图、面数/体积达标、含 `TANGENT`/`TEXCOORD_0`/`COLOR_0`、100% 朝外法线、无负缩放、必选 Socket/Bone/Muzzle 节点齐全、满足 `HP-C1` 间隙红线）。
