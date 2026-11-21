# 3D 建模与场景资产逐项精修 TODO 清单

> **更新日期**：2026-11-21  
> **维护原则**：已完成替换且经六大生态俯视/战术实拍验证质感良好的条目（原 P0-1 城区与工业建筑 30 项精修预制包 B1~B6、原 P0-2 重型载具与路肩重制、以及原 P1-3 中已落地的农田打散与龙牙油管）已移出本清单，**仅保留尚未闭环的模型精修项**。  
> **关联文档**：场景地标/POI/灰盒/低模实体替换清单见 [low_poly_model_audit.md](low_poly_model_audit.md)。

---

## P0 · 场景生态残余低模与比例校准（实拍复检补齐）

### 1. 荒原生态预制体补修、俯视灌木防黑点与建筑-载具比例校准
- **问题现状**：前期 30 项建筑预制包中，`ter_arid_flora_pylon.gd` 内部仍遗留 89 处低分段圆柱与方棍树枝未重制；山坡与地表 `A.shrub_mesh()` 在高俯视下呈黑芝麻点；同时城区/工业区小地块把高层塔楼与锯齿厂房缩放得比旁边 7.2m 矿卡、12m 火车更显迷你，且 `veh_dump_truck` 绿漆货斗俯视偏素。
- **涉及脚本**：`scripts/buildings/ter_arid_flora_pylon.gd`、`scripts/art.gd`、`scripts/mountain_terrain.gd`、`scripts/raid.gd`、`scripts/buildings/veh_dump_truck.gd`（详细拆分见 [low_poly_model_audit.md](low_poly_model_audit.md) `REM-P0-04` / `REM-P0-05`）
- **逐项精做标准**：
  - [ ] **M1.1 重制 `ter_arid_flora_pylon` 并修复 `shrub_mesh` 俯视过暗黑点**：枯树改用高细分有机枝干、灌木改用真实叶片簇并提亮俯视漫反射/按生态着色，彻底消除沙地黑点感。
  - [ ] **M1.2 建筑最小占地门槛与矿卡顶视补细**：限制高层塔楼/锯齿厂房落入过窄地块以对齐载具/机甲尺度，为 `veh_dump_truck` 货斗增加废料/加强肋与锈蚀层次。

---

## P1 · 新巨型首领模型一体化精雕（消除拼接重复感）

### 2. 六足要塞（`citadel_behemoth`）一体化宽体主舰壳与铰接座精修
- **问题现状**：当前宽体版通过 5 个 `citadel_hull.glb` 旋转拼接获得了扎实的 `36m` 宏观宽高比，但俯视近看时五块相同舰壳的重复烟囱/舱门纹理密集堆叠，且腹底斜撑油缸与船体连接处仍用基础几何块过渡。
- **涉及资产与脚本**：`assets/models/boss/citadel_hull.glb`、`assets/models/boss/citadel_leg.glb`、`scripts/enemies/boss_modular_glb.gd`
- **逐项精做标准**：
  - [ ] **M2.1 定制原生 2:1 超宽体陆地巡洋舰一体主壳 GLB**：单独使用 Meshy 生成并减面一件原生宽扁八角重装舰壳（区分前向破障首楼、左右独立外伸炮廓耳台、后部集中式排烟动力舱），替换当前 5 件同模拼接，让俯视甲板动线干净清晰。
  - [ ] **M2.2 独立建模上股节（Femur）与下胫节（Tibia）专用资产**：拆分为专门的「重型箱型桁架上股节 GLB」+「垂直双缸液压柱与四爪驻锄巨靴 GLB」，使膝关节球头与腹底斜撑耳轴严丝合缝咬合。
  - [ ] **M2.3 炮塔击毁专属残骸模型**：为被玩家打爆的副炮塔制作专属扭曲断管/掀盖焦黑残骸网格，替代当前的整件变黑倾斜。

### 3. 浮空母舰（`sky_carrier`）机库内构与舰腹炮廓一体化精修
- **问题现状**：前腹两座副炮塔目前采用程序化圆柱吊篮下挂，前机库弹射无人机时缺少可见的内部发光导轨舱室。
- **涉及资产与脚本**：`assets/models/boss/carrier_hull.glb`、`assets/models/boss/carrier_thruster.glb`、`scripts/enemies/boss_modular_glb.gd`
- **逐项精做标准**：
  - [ ] **M3.1 舰腹流线型装甲炮廓吊舱**：建模专用斜面装甲武器挂舱，自然贴合母舰下腹部折角，消除圆筒过渡件。
  - [ ] **M3.2 贯通式无人机弹射甲板内舱**：在前首防爆门后方制作带警示灯带与弹射滑轨的内凹机库腔体，释放 `wasp` 编队时舱门滑开、导轨亮起。
  - [ ] **M3.3 涡扇进气道旋转扇叶分离**：将 `carrier_thruster` 顶部的进气涡轮风扇拆分为独立旋转子网格，悬停与俯冲时高速旋转。

---

## P2 · 全图鉴敌群与武器模块材质世代统一

### 4. 程序化常规虫族 / 旧首领与 PBR GLB 首领的质感对齐
- **问题现状**：目前 `excavator_titan`、`citadel_behemoth`、`sky_carrier` 已升级为 2K PBR 写实重工贴图，而部分早期常规虫群与程序化首领仍使用较光滑的程序化色块材质，同屏混战时材质颗粒度略有差异。
- **涉及脚本**：`scripts/enemies/models.gd`、`scripts/enemies/boss_models.gd`、`scripts/enemies/boss_models_ext.gd`
- **逐项精做标准**：
  - [ ] **M4.1 高频出镜精英怪（`mech_beetle`、`ironjaw`、`colossus`）Meshy PBR 化**：将体型较大、停留时间长的重甲精英敌种分批替换为带骨骼动作的减面 PBR GLB。
  - [ ] **M4.2 程序化金属/甲壳 Shader 细节补强**：为保留程序化建模的中小虫种统一叠加微表面划痕法线、边缘磨损掉漆与关节暗部 AO 顶点色。
