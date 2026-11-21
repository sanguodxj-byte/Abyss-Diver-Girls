# 全仓 3D 模型待替换与低面数整改清单

> **更新日期**：2026-11-21（基于全仓代码静态核查 + 六大生态 16 张俯视/战术实拍复检 + Batch 3 10 项精修地标/环境预制体接入）  
> **维护原则**：**只保留尚未替换、实拍仍有灰盒/素盒/低模/比例缺陷的待办模型**；已完成替换且实机质感良好的项目（底层几何库 `P0-CORE-01~10`、全部 10 项技能/部署装置 `P0-SKL-01~10`、全部 10 项导弹/炮弹/弹壳/发射巢 `P0-MSL-01~10`、6 款新精修大件 `veh_transport_vtol`/`veh_mbt_tank_wreck`/`veh_rail_wagon`/`veh_submarine_hull`/`supply_airdrop_pod`/`distress_beacon`、Batch 3 10 款重工地标与环境设施 `bld_central_terminus`/`bld_converter_foundry`/`lm_radio_mast`/`lm_observation_tower`/`lm_wind_turbine`/`lm_crystal_survey_rig`/`env_extract_beacon_tower`/`env_world_portal_gate`/`env_perimeter_pontoon`/`hub_mech_docking_bay`、`extract_zone`/`world_link`/`hub`、28 款精修建筑/载具预制体及 88 个机甲模块等）已全部移出本清单。  
> **关联文档**：本清单聚焦**场景建筑、地标、POI、载具、植被与零倒角/灰盒实体模型替换**；巨型首领 GLB 一体化精雕与敌群 PBR 化请见互补清单 [modeling_polish_todo.md](modeling_polish_todo.md)。

---

## 一、待整改总览（仅含当前有效项）

| 优先级 | 编号范围 | 类别 | 待处理范围 | 实拍 / 代码核心缺陷 |
| :---: | :--- | :--- | :--- | :--- |
| **P0** | `REM-P0-01` ~ `06` | **最刺眼的灰盒 / 素盒 / 生态低模 / 比例失调** | 6 大项（含本次俯视图新补入 4 项） | 干船坞红龙门吊素盒、`egret_bridge` 白灰方盒、`coolant_channel` 60m 灰长条、`ter_arid_flora_pylon` 89 处低模与 `shrub_mesh` 俯视黑点、建筑-载具比例失调、远景/窄楼/主菜单裸盒 |
| **P1** | `REM-P1-01` ~ `05` | **未预制化的 POI 主楼、地标、旧车厢/货柜与主菜单舰** | 5 大项 | 医院/学校/教堂等实心箱 POI、剩余 4 座旧内联首领地标与 7 座常规地标、铁路旧罐车/敞车与零倒角铁轨、坠落货柜、主菜单飞船 |
| **P2** | `REM-P2-01` ~ `04` | **虫巢、特写物件精修、历史字面参数清理与 CI 门禁** | 4 大项 | 虫巢积木感结构、背包 3D 特写道具与物资箱细化、`bug.gd`/`bugs2.gd` 历史字面低段清理、新增静态防回退门禁 |

---

## 二、【P0】最高优先级：俯视 / 战术视角最刺眼的待替换模型

以下 6 项在实机大俯视与战术视角中视觉落差最明显，建议优先重制替换：

- [ ] **REM-P0-01** **东湾船坞港 · 巨型造船龙门吊（Goliath Gantry Crane）与双侧泵房/施工栈桥**【2026-11-21 实拍新补入】
  - **代码位置**：`scripts/map_ext/landmarks_boss.gd` `_submarine_drydock()` L543-585
  - **现状缺陷**：下方潜艇本体已替换为高精 `veh_submarine_hull`（质感优秀，已移出清单），但横跨上方 **22.8m 宽 × 19.6m 高** 的巨型暗红龙门吊仍由十余块光秃素面 `bevel_box` 拼成，既无钢结构桁架腹杆、检修爬梯与高空走道护栏，也无卷扬机房/滑轮组/成型吊钩，仅配 2 根 `A.tube(..., 6, 3)` 吊索；两侧泵房也只是 3 块方盒，与高精潜艇和周边精修厂房形成强烈世代差。
  - **整改目标**：拆出独立 `PrefabLib` 巨构预制件（如 `poi_goliath_crane`）：门腿升级为带斜撑腹杆、节点加固板与盘梯的工业钢构，主桥箱梁补顶部检修走道护栏、带玻璃操纵室的卷扬天车、多滑轮吊钩梁与 `seg≥14` 钢缆；双侧泵房与施工栈桥同步补护栏、管汇、百叶门与防滑钢格栅。

- [ ] **REM-P0-02** **裂谷矿区 · 白鹭号舰桥舱（`egret_bridge`）整体重制**【原 `P1-POI-03` 升级】
  - **代码位置**：`scripts/map_ext/poi/egret_bridge.gd` 全文件（L19-121）
  - **现状缺陷**：原清单仅记录了 5 根 `tube(..., 4, 2)` 骨架和 `cyl(..., 5)` 断裂线束，但实拍可见**整座舰桥主舱本身就是两块压在光秃灰色 `24×20m` 矩形水泥板上的倾斜奶白大 `bevel_box`**（`9×4.2×13m` + `7.6×1.4×5m`），舷窗仅表面贴片，四周碎块是随机平放的小方板。
  - **整改目标**：对标新 `veh_transport_vtol.gd` 与 `raid.gd::_crashed_ship` 精度重制半埋舰桥残骸：真切面倾斜舰艏/装甲窗框内凹结构、撕裂舱壁外露加强肋与管道、倒塌通信雷达桅与接地陨坑土堆；取消突兀的 `24×20m` 规整方水泥板，改为自然焦土撞击坑过渡。

- [ ] **REM-P0-03** **零号深渊井 · 冷却渠（`coolant_channel`）整构重制**【2026-11-21 实拍新补入】
  - **代码位置**：`scripts/map_ext/landmarks.gd` `_coolant_channel()` L623-650
  - **现状缺陷**：整座地标由 1 块 `6.0×0.26×59.8m` 扁平灰色混凝土板 + 两道素面长条墙 + 几块随机倾斜方板组成，在暗紫黑曜石地表的俯视图中宛如一条毫无细节的宽灰色胶带，严重破坏终局地貌沉浸感。
  - **整改目标**：重制为深渊重工冷却导流槽：分段肋板防渗渠壁 + 渠底暗光/余热冷却液槽与格栅漫水盖板 + 沿渠并行的大口径工业冷却管汇与法兰阀门 + 钢格栅跨渠维修桥、警示栏杆及边缘碎岩接地过渡。

- [ ] **REM-P0-04** **荒原枯木灌木预制体（`ter_arid_flora_pylon`）重制 & 山坡/地表黑点灌木（`shrub_mesh`）修复**【原 `P1-BLD-01` 保留 + 2026-11-21 实拍新补入】
  - **代码位置**：`scripts/buildings/ter_arid_flora_pylon.gd` L19-219；`scripts/art.gd` `shrub_mesh()` L490 & `foliage_mat("shrub")` L1295；`scripts/mountain_terrain.gd` L1095
  - **现状缺陷**：
    1. `ter_arid_flora_pylon.gd` 尚未重制，仍是建筑预制库中唯一遗留的灾难级低模（**89 处低分段 `K.cy(..., 5/6/7)`** + 全用硬方棍 `K.bb` 当树枝 + 24 个扁圆柱叠灌木冠 + 方片干草）；
    2. `mountain_terrain.gd` 山坡与地表散落的 `A.shrub_mesh()` 在俯视镜头下因为叶片朝向偏垂、自阴影/底色过暗，呈密集**死黑圆点（黑芝麻感）**，与暖色沙土/铁锈地表极不协调。
  - **整改目标**：
    - `ter_arid_flora_pylon` 枯树干/分枝改用高细分有机枝干 `A.tree_trunk_mesh()` / `FM.snag_limbs_mesh()`，灌木与干草改为真实叶片簇 + `seg≥20` 电塔瓷瓶；
    - 优化 `shrub_mesh()` 顶部蓬松展开角度与 `foliage_mat("shrub")` 漫反射提亮/背光透射，按战区地貌匹配枯黄/灰绿/沙棘色温，彻底消除俯视黑点感。

- [ ] **REM-P0-05** **建筑与载具比例失调校准 + 矿卡（`veh_dump_truck`）顶视质感补强**【2026-11-21 实拍新补入】
  - **代码位置**：`scripts/raid.gd` `_building()` L1558-1595、`_wreck_car()` L1648-1700、`_factory_shed()` L8726；`scripts/buildings/veh_dump_truck.gd`
  - **现状缺陷**：
    1. 城区与工业区小地块直接把多层高层 `bldg_stepped_tower`、三跨锯齿厂房 `bldg_factory_shed` 压进过窄的占地（如 `~6m×6m`），导致 5 层高楼或工业厂房在 7.2m 矿卡与 12m 火车车厢旁显得像“微缩模型”；
    2. 裂谷公路边同色连刷的亮绿 `veh_dump_truck`（`M_BODY` 整车覆盖货斗颜色）从俯视看像光滑绿方盒，顶视货斗空旷、细节密度明显弱于新换上的 `veh_mbt_tank_wreck`。
  - **整改目标**：
    - 在 `_building()` / `_factory_shed()` 中按地块最小长宽门槛限制预制体选型（小地块只选单层小屋/配电房/哨亭，多层塔楼与锯齿厂房仅在达标大占地生成），拉齐建筑与载具/机甲的视觉比例；
    - 为 `veh_dump_truck` 货斗内部补砂石/锈废料堆积、内壁加强肋与做旧污渍，并降低路边连续同款同色刷新概率。

- [ ] **REM-P0-06** **远景城区素盒、窄地块 3 方盒回退与主菜单裸 `BoxMesh` 城市**【原 `P1-BLD-02` / `03` / `04`】
  - **代码位置**：
    - `scripts/raid.gd` `_build_backdrop()` L8321+ & `scripts/buildings_ext.gd` `add_backdrop()` L60-107；
    - `scripts/raid.gd` `_building()` L1560-1566（`size.x < 4.2 or size.z < 4.2` 窄楼 3 方盒回退分支）；
    - `scripts/menu_city.gd` L157（`st.create_from(BoxMesh.new(), 0)` 主菜单裸纯方块城市）。
  - **整改目标**：
    - 战区外围可见圈层（距边界 ≤ 90m）复用精修 `PrefabLib` 建筑（关细部碰撞/次要阴影），更远圈层升级为带压顶女儿墙、退台与 `seg≥32` 罐体的多表面合批网格；
    - 删除 `_building()` 3 方盒回退，接入独立小型配电房/砖砌岗亭预制体；
    - `menu_city.gd` 替换为 3~4 种带退台、压顶与屋面机房轮廓的合批 `ArrayMesh`，彻底消灭裸 `BoxMesh`。

---

## 三、【P1】未预制化的 POI 主楼、地标、旧车厢/货柜与主菜单飞船

- [ ] **REM-P1-01** **遗迹 POI 实心大箱主楼（贴片假窗）与旧内联场地设施**【原 `P1-BLD-05` + `P1-POI-00~11` 合并精简】
  - **代码位置**：`scripts/map_ext/poi_kit.gd` 与 `scripts/map_ext/poi/*.gd`（目前全部 12 座 POI 脚本均尚未接入 `PrefabLib` 高精预制体）
  - **重点缺陷**：
    - **高优先（主楼实心箱 + 贴片窗）**：`hospital.gd`（`13×7×7m` 实心门诊楼 + 表面薄片窗与 2 块板红十字）、`school.gd`（`17×6.4×5.6m` 实心教学楼 + 贴片窗 + 5 边桌腿/塌落斜梁）、`church.gd`（15m 实心钟塔外贴百叶 + 中殿 `tube(..., 10, 4)` 拱肋）；
    - **中优先（旧内联铁塔/工事/管架）**：`well_core.gd`、`mining_terminal.gd`、`relay_tower.gd`、`checkpoint.gd`、`hydro_lab.gd`、`parking_garage.gd`、`power_station.gd`、`metro_station.gd` 及 `poi_kit.gd`（`lattice`/`shelf`/`cable` 仍用简单细圆管拼角钢桁架，建议升级为真实倒角角钢/工字钢结构与可复用高精预制模块）。
  - **整改目标**：优先将医院、学校、教堂主楼升级为真内凹窗洞、立面柱网/腰线与屋顶机房护栏结构，使其与城区 `PrefabLib` 建筑精度拉齐；逐步升级 `poi_kit` 公共桁架与其余 POI 设施。

- [ ] **REM-P1-02** **其余未预制化首领地标结构精修**【原 `P1-LM-01` / `P1-LM-03` 精简；`_central_terminus` 与 `_converter_foundry` 已替换接入 `bld_central_terminus` / `bld_converter_foundry`】
  - **代码位置**：`scripts/map_ext/landmarks_boss.gd`
  - **现状缺陷**：虽然 `art.gd` 已自动兜底曲面分段，但仍有 4 座首领地标主体为早期内联 `bevel_box` 拼接：
    - `_geothermal_vault`：虽已挂载 `poi_abyss_gate_rig`，但后部三层安全壳叠柱与跨顶蒸汽弯管（`tube(..., 0.48, 12, 4)` 仅 4 段路径插值）仍显生硬；
    - `_missile_silo`、`_spillway_dam`、`_bucket_excavator`：整体均未预制化，存在大块素面 `bevel_box` 柱梁与简陋钢索。
  - **整改目标**：优先将 `_geothermal_vault` 蒸汽管廊路径细分升至 `sub≥16` 并精修平台接缝；分批将剩余 3 座首领地标升级为高精工业巨构预制件。

- [ ] **REM-P1-03** **未预制化的常规战区地标**【原 `P1-LM-04` 精简；`_radio_mast` / `_observation_tower` / `_windmill` / `_crystal_cluster` 已替换接入 `lm_*` 精修模型】
  - **代码位置**：`scripts/map_ext/landmarks.gd`
  - **现状缺陷**：`_gantry` / `_elevated_road` / `_silo` / `_pylon_row` / `_drill_derrick` / `_radio_mast` / `_observation_tower` / `_windmill` / `_crystal_cluster` 已接入 `PrefabLib` 高精预制体，其余 7 座常规地标仍为早期内联代码：
    - 重点：`_ore_silos`（裂谷三联矿石筒仓，实拍 `audit_canyon_tactical.png` 顶部可见光秃素面锥顶）、`_broken_bridge`、`_blast_furnace`、`_gas_holder`、`_cable_tower`、`_boardwalk`、`_rope_bridge`。
  - **整改目标**：优先补强 `_ore_silos`（增设仓顶检修连廊、送料皮带机、支撑腿斜撑与出料漏斗）与 `_broken_bridge` / `_blast_furnace`，其余分批收口为高精结构。

- [ ] **REM-P1-04** **铁路旧罐车/敞车变体、坠落轨道货柜与零倒角铁轨**【原 `P1-ENV-01` / `P1-ENV-03` 残余项】
  - **代码位置**：
    - `scripts/raid.gd` `_wagon()` L8254-8280（`wtype == 1` 卧式化工罐车、`wtype == 2` 帆布高边敞车）；
    - `scripts/raid.gd` `_build_rails()` L8219, L8221（铁轨与道口护轨使用零倒角 `bevel_box(Vector3.ONE, 0.0)`；另有 L7372-7373 路面贴地标线）；
    - `scripts/map_ext/events.gd` `_build_cargo_visual()` / `_build_wreck_visual()` L267-319（坠落轨道货柜与落地残骸）。
  - **整改目标**：
    - 棚车 `wtype == 0` 已升级为高精 `veh_rail_wagon`，需同规格重制 `veh_rail_tanker`（加鞍座肋、人孔安全阀台、侧扶梯、双管制动系统与锈蚀做旧）与 `veh_rail_gondola`（替换两块素色方箱帆布）；
    - 铁轨与护轨改用带倒角/工字轨剖面的预制截段网格；
    - 坠落轨道货柜对标新 `supply_airdrop_pod` / `distress_beacon` 升级为高精耐热隔热瓦 + 折叠着陆稳定翼 + 撕裂货舱门残骸。

- [ ] **REM-P1-05** **主菜单近景轨道运输舰**【原 `P1-ENV-05` 残余项，`hub.gd` 已移出】
  - **代码位置**：`scripts/menu_ship.gd` L105-240
  - **现状缺陷**：主菜单全屏近景特写，结构仍为早期简单几何块拼接（含 13 处旧低段参数），细部质感明显落后于新导入的 `veh_transport_vtol.gd`。
  - **整改目标**：对标 `veh_transport_vtol.gd` 重制主菜单轨道运输舰的装甲蒙皮分缝、推进短舱进气道/矢量喷口、起落架与机腹挂载细节。

---

## 四、【P2】虫巢结构、特写物件精修、历史代码清理与防回退门禁

- [ ] **REM-P2-01** **虫巢建筑实体（`nest.gd`）结构重制**【原 `P2-ENM-04`】
  - **代码位置**：`scripts/nest.gd` L33-92
  - **现状缺陷**：虽然 `art.gd` 已兜底圆筒分段，但整座虫巢仍由中心同心圆筒 + 规则放射排列的 `bevel_box` 护板拼出，整体呈机械对称积木感，缺少与地表岩渣/菌毯融合的破土体量与有机/重工侵蚀细节。
  - **整改目标**：重制多层次不规则破土基座 + 撕裂装甲井壁 + 内部可视热熔/脉动腔体，与周围菌毯贴花自然衔接。

- [ ] **REM-P2-02** **背包 3D 特写道具与高频物资箱细化**【原 `P2-PROP-01` / `02`】
  - **代码位置**：`scripts/item_models.gd`（51 处旧字面低段参数，背包特写界面直接近距展示）、`scripts/loot_box.gd`（16 处旧字面低段参数，局内高频近距交互）
  - **整改目标**：曲面分段虽已有 `art.gd` 兜底，但部分早期道具（罐头/信标/电池棒/工具/医疗包等）和箱体锁扣/提手/阀门造型仍偏简单，逐批补强硬表面倒角细部，并同步规范源码字面分段参数。

- [ ] **REM-P2-03** **常规程序化敌群/首领精雕衔接与历史低段字面清理**【衔接 `modeling_polish_todo.md`；`world_link.gd` 竖井与转场闸门已升级接入 `env_world_portal_gate`】
  - **代码位置**：`scripts/bug.gd`、`scripts/bugs2.gd`
  - **整改目标**：清理遗留字面低段参数；巨型首领 `citadel_behemoth` / `sky_carrier` 一体化 GLB 精雕与重甲精英怪 PBR 化按 [modeling_polish_todo.md](modeling_polish_todo.md) 推进。

- [ ] **REM-P2-04** **自动化低面数与裸原语门禁测试**
  - **代码位置**：`tests/` 新增静态扫描门禁脚本
  - **整改目标**：CI / 本地一键拦截：禁止新增未登记白名单的裸 `BoxMesh.new()` / `PrismMesh.new()`、禁止 3D 实体使用 `bevel_box(..., 0.0)`、禁止绕过 `art.gd` 曲线分段下限的新增硬编码低段网格。

---

## 五、建模验收红线与白名单规范（后续替换统一执行）

### 5.1 最低几何红线（`art.gd` 已内置底层兜底，新增/重制代码须同样遵守）

| 几何类型 | 桌面端最低分段 | 移动端最低分段 | 硬性禁止 |
| :--- | :---: | :---: | :--- |
| **圆柱 / 圆锥 (`A.cyl`)** | 细 `≥16` / 中 `≥24` / 大 `≥36`（`r≥2m` 时 `≥48`） | `≥12 / 18 / 28 / 36` | 非白名单禁止 `allow_poly=true` 绕过下限 |
| **球体 (`A.sphere`) / 胶囊 (`A.capsule`)** | 球 `≥20×10` / `≥32×16`；胶囊 `≥20×8` | 球 `≥16×8` / `≥24×12`；胶囊 `≥16×6` | 禁止手写低段 `SphereMesh`/`CapsuleMesh` |
| **圆环 (`A.torus`) / 扫描管 (`A.tube`)** | 环 `≥24×16` / `≥36×18`；管 `seg≥14, sub≥8` | 环 `≥18×12` / `≥28×14`；管 `seg≥10, sub≥6` | 禁止长跨度拱管用 `sub≤4` 折线 |
| **硬表面实体与结构复杂度** | 须使用 `bevel > 0` 倒角或复合硬表面预制件 | 同左 | 禁止裸 `BoxMesh`/`PrismMesh` 及 1~6 方块灰盒占位 |

### 5.2 规则多面体白名单（有意造型，勿误圆滑）
- 全部 7 个首领外部 `.glb` 高模（`assets/models/boss/`，实测 2,475 ~ 22,734 面）；
- 八角暗堡/八角烟囱基座/八角纪念碑台基（`fort_pillbox_bunker`、`ind_oil_tank_chimney`、`poi_abyss_gate_rig`、`raid.gd::_park_statue`）；
- 四棱台反坦克“龙牙”锥（`ter_dragon_teeth_pipe`）、四坡/八坡尖顶（`_central_terminus` L159、`church.gd` L83）；
- 六方晶柱与微小六角螺母/铆钉头（`r ≤ 0.035m, seg = 6`）。
