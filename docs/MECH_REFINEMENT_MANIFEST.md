# 全量 101 个机甲模块建模细化任务清单（MECH REFINEMENT MANIFEST）

> **规范基准**：[MECH_MODELING_STANDARD.md](./MECH_MODELING_STANDARD.md)（v1.0）  
> **AI Studio Build 委托手册**：[AISTUDIO_BUILD_BRIEF.md](./AISTUDIO_BUILD_BRIEF.md)  
> **机器可读完整参数表**：[tools/mech_kitbash/manifest.json](../tools/mech_kitbash/manifest.json)  
> **当前总进度**：**`5 / 101`**（已完成 `5`，待细化 `96`）

---

## 批次总览

| 批次 ID | 说明 | 进度 | 目标产出文件建议 |
| :--- | :--- | :---: | :--- |
| `batch_01_starter` | 第 1 批：起步整机 5 件套（已完成基准示例） | `5 / 5` | `starter_*.py` (已完成参考样板) |
| `batch_02a_cores_tactical` | 第 2A 批：战术与主战躯干（10 款） | `0 / 10` | `tools/mech_kitbash/builders/batch_02a_cores_tactical.py` |
| `batch_02b_cores_heavy` | 第 2B 批：重装/炮艇/电子战躯干（10 款） | `0 / 10` | `tools/mech_kitbash/builders/batch_02b_cores_heavy.py` |
| `batch_03a_legs_walk` | 第 3A 批：双足 + 履带底盘（7 款） | `0 / 7` | `tools/mech_kitbash/builders/batch_03a_legs_walk.py` |
| `batch_03b_legs_multi` | 第 3B 批：四足 + 六足多足底盘（8 款） | `0 / 8` | `tools/mech_kitbash/builders/batch_03b_legs_multi.py` |
| `batch_04a_arms_ballistic` | 第 4A 批：机炮/机枪/转管类臂武（14 款） | `0 / 14` | `tools/mech_kitbash/builders/batch_04a_arms_ballistic.py` |
| `batch_04b_arms_heavy` | 第 4B 批：重炮/狙击/磁轨/霰弹臂武（14 款） | `0 / 14` | `tools/mech_kitbash/builders/batch_04b_arms_heavy.py` |
| `batch_04c_arms_ordnance` | 第 4C 批：导弹/火箭/喷火/激光臂武（13 款） | `0 / 13` | `tools/mech_kitbash/builders/batch_04c_arms_ordnance.py` |
| `batch_05a_backs_all` | 第 5A 批：全部剩余背部挂载（5 款） | `0 / 5` | `tools/mech_kitbash/builders/batch_05a_backs_all.py` |
| `batch_05b_gens_all` | 第 5B 批：全部剩余动力炉（15 款） | `0 / 15` | `tools/mech_kitbash/builders/batch_05b_gens_all.py` |

---

## 第 1 批：起步整机 5 件套（已完成基准示例） (`batch_01_starter` — `5/5`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ✅ | `core_scout` | SC-1 轻型 框架 | `core` | `SOCKET_arm_l=[-0.66, 0.3, 0.0]`<br>`SOCKET_arm_r=[0.66, 0.3, 0.0]`<br>`SOCKET_back=[0.0, 0.56, 0.405]`<br>`SOCKET_gen=[0.0, 0.12, 0.725]` | [`core_scout.gd`](../scripts/modules/core_scout.gd)<br>侦察躯干 SC-1（B.o.T 式）：楔形机首夹出观察缝、侧挂传感舱、轻薄切角甲 接口：插头 HP-C1（向下）；插座 HP-A1×2、HP-B1、HP-G1 |
| ✅ | `legs_biped` | ST-8 制式 机动双足底盘 | `legs` | `SOCKET_core=[0.0, 2.17, 0.0]`<br>type=`biped`<br>hip=`1.62`<br>KN=`[0.0, -0.78, -0.34]`<br>AN=`[0.0, -1.3, 0.2]`<br>sole=`-3.18` | [`legs_biped.gd`](../scripts/modules/legs_biped.gd)<br>双足底盘 Stride（B.o.T 式泰坦腿）：反关节（鸟足式）结构， 多面切角大腿甲 / 尖形护膝 / 长胫甲、外露液压骨架、三趾爪足 + 后跟距 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ✅ | `arm_gatling` | GAU-6 六管 转管炮 | `arm` | wpn=`mg`<br>muzzle=`[0.0, 0.0, -2.25]` | [`arm_gatling.gd`](../scripts/modules/arm_gatling.gd)<br>重型转管炮 GAU-H：加强法兰 + 加强筋、厚机匣 + 驱动电机、外侧超大弹鼓 + 节段供弹槽、七管转管 + 三道管箍 接口：插头 HP-A1 → a1_mount（加强）→ 机匣；导出 muzzle |
| ✅ | `back_cargo` | CG-10 轻型 载货背包 | `back` | 见原版 `.gd` | [`back_cargo.gd`](../scripts/modules/back_cargo.gd)<br>货运背包：货架 + 绑带货箱 接口：插头 HP-B1（朝下，贴躯干顶部后方导轨）；局部 +Y 向上，+Z 向后 |
| ✅ | `gen_cell` | B-40 轻型 电池组 | `gen` | 见原版 `.gd` | [`gen_cell.gd`](../scripts/modules/gen_cell.gd)<br>电池组 B-40：6 节电芯阵列 + 电量指示条 接口：插头 HP-G1（朝前，插入躯干背面动力舱）；局部 +Z 向后 |

## 第 2A 批：战术与主战躯干（10 款） (`batch_02a_cores_tactical` — `0/10`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `core_abv_shredder` | core_abv_shredder | `core` | `SOCKET_arm_l=[-1.16, 0.82, 0.02]`<br>`SOCKET_arm_r=[1.16, 0.82, 0.02]`<br>`SOCKET_back=[0.0, 1.56, 0.54]`<br>`SOCKET_gen=[0.0, 0.72, 0.96]` | [`core_abv_shredder.gd`](../scripts/modules/core_abv_shredder.gd)<br>M1150-B 突击破障防爆犁鼻框架（M1150-B）：重装雷场强行破障躯干：首上铺设 6 块重型反应装甲，下颌液压双缸收拢锁定 V 字梳齿除雷破障犁，两侧集成 8 管通路标示杆抛射架。 标准接口：HP-C1 / 自… |
| ⬜ | `core_assault` | AS-2 突击 框架 | `core` | `SOCKET_arm_l=[-0.8, 0.45, 0.0]`<br>`SOCKET_arm_r=[0.8, 0.45, 0.0]`<br>`SOCKET_back=[0.0, 1.06, 0.4]`<br>`SOCKET_gen=[0.0, 0.55, 0.68]` | [`core_assault.gd`](../scripts/modules/core_assault.gd)<br>突击躯干 AS-3：楔形倾斜首上装甲、两侧挂臂短舱、潜望镜组、顶部舱盖、后倾发动机甲板 接口：插头 HP-C1（向下，经回转座圈接底盘）；插座 HP-A1×2（短舱外侧）、HP-B1（后倾甲板）、HP-G1（尾部动力… |
| ⬜ | `core_bmpt_terminator` | core_bmpt_terminator | `core` | `SOCKET_arm_l=[-1.14, 0.8, 0.04]`<br>`SOCKET_arm_r=[1.14, 0.8, 0.04]`<br>`SOCKET_back=[0.0, 1.52, 0.54]`<br>`SOCKET_gen=[0.0, 0.68, 0.96]` | [`core_bmpt_terminator.gd`](../scripts/modules/core_bmpt_terminator.gd)<br>BMPT-72 终结者双榴弹腮舱框架（BMPT-72）：巷战火力压制重躯干：车体前肩两侧内嵌 AGS-30 30mm 自动榴弹副武器装甲腮舱与供弹蜗鼓，首上镶嵌 5 块接触-5反应甲。 标准接口：HP-C1 / 自动… |
| ⬜ | `core_bradley_busk` | core_bradley_busk | `core` | `SOCKET_arm_l=[-1.12, 0.8, 0.02]`<br>`SOCKET_arm_r=[1.12, 0.8, 0.02]`<br>`SOCKET_back=[0.0, 1.54, 0.54]`<br>`SOCKET_gen=[0.0, 0.7, 0.94]` | [`core_bradley_busk.gd`](../scripts/modules/core_bradley_busk.gd)<br>M2A4-BK 布雷德利巷战反应甲框架（M2A4-BK）：美军城市生存套件构型：高耸折角车首与双侧满铺厚重箱式 BRAT 爆炸反应装甲砖，右前动力甲板百叶与左前防弹透明装甲护盾笼。 标准接口：HP-C1 / 自动对齐… |
| ⬜ | `core_command` | CMD-1 指挥 框架 | `core` | `SOCKET_arm_l=[-0.75, 0.42, 0.0]`<br>`SOCKET_arm_r=[0.75, 0.42, 0.0]`<br>`SOCKET_back=[0.0, 1.22, 0.3]`<br>`SOCKET_gen=[0.0, 0.6, 0.6]` | [`core_command.gd`](../scripts/modules/core_command.gd)<br>指挥躯干 CM-7：高车体、宽幅观察窗、肩部通信箱、前置传感桅杆（相控阵面板 + 鞭状天线）、烟幕弹发射器 接口：插头 HP-C1（向下）；插座 HP-A1×2（肩块外侧）、HP-B1（后倾甲板）、HP-G1（尾部动… |
| ⬜ | `core_fennek_recon` | core_fennek_recon | `core` | `SOCKET_arm_l=[-0.94, 0.64, 0.02]`<br>`SOCKET_arm_r=[0.94, 0.64, 0.02]`<br>`SOCKET_back=[0.0, 1.28, 0.48]`<br>`SOCKET_gen=[0.0, 0.58, 0.86]` | [`core_fennek_recon.gd`](../scripts/modules/core_fennek_recon.gd)<br>FNK-4 大耳狐低矮隐身侦察框架（FNK-4）：全目录最低矮紧凑的雷达隐身多面折角侦察车体，正面三向防激光倾斜观察窗，左后竖立可升降 BAA 三合一热像激光侦察桅杆。 标准接口：HP-C1 / 自动对齐 res:/… |
| ⬜ | `core_fortress` | FT-5 要塞 框架 | `core` | `SOCKET_arm_l=[-1.1, 0.85, 0.0]`<br>`SOCKET_arm_r=[1.1, 0.85, 0.0]`<br>`SOCKET_back=[0.0, 1.72, 0.56]`<br>`SOCKET_gen=[0.0, 0.75, 1.08]` | [`core_fortress.gd`](../scripts/modules/core_fortress.gd)<br>堡垒躯干 FT-9：超宽车体、间隙复合装甲首上（主装甲 + 三块披挂板）、宽侧挂臂短舱、 车长指挥塔（周视潜望镜环）、驾驶装甲舱、侧后栅格装甲、烟幕发射器 接口：插头 HP-C1（向下，加粗回转座圈）；插座 HP-A… |
| ⬜ | `core_heavy` | BW-3 重型 框架 | `core` | `SOCKET_arm_l=[-1.01, 0.3, 0.0]`<br>`SOCKET_arm_r=[1.01, 0.3, 0.0]`<br>`SOCKET_back=[0.0, 1.06, 0.535]`<br>`SOCKET_gen=[0.0, 0.12, 0.835]` | [`core_heavy.gd`](../scripts/modules/core_heavy.gd)<br>重装躯干 HV-3（B.o.T 式）：双层楔形胸甲、低矮装甲头、肩堡、方形排气管 接口：插头 HP-C1（向下）；插座 HP-A1×2、HP-B1、HP-G1 |
| ⬜ | `core_ka52_alligator` | core_ka52_alligator | `core` | `SOCKET_arm_l=[-0.96, 0.68, 0.04]`<br>`SOCKET_arm_r=[0.96, 0.68, 0.04]`<br>`SOCKET_back=[0.0, 1.34, 0.5]`<br>`SOCKET_gen=[0.0, 0.62, 0.9]` | [`core_ka52_alligator.gd`](../scripts/modules/core_ka52_alligator.gd)<br>KA-52M 短吻鳄并列武直突击框架（KA-52M）：多段龙骨放样宽扁“鸭嘴”有源相控阵机鼻，并列双座防弹平板风挡配顶置 K-37 弹射火箭导槽，颌下挂载 GOES-451 八棱光电球转塔。 标准接口：HP-C1 /… |
| ⬜ | `core_krasukha_ew` | core_krasukha_ew | `core` | `SOCKET_arm_l=[-1.1, 0.78, 0.02]`<br>`SOCKET_arm_r=[1.1, 0.78, 0.02]`<br>`SOCKET_back=[0.0, 1.52, 0.54]`<br>`SOCKET_gen=[0.0, 0.68, 0.94]` | [`core_krasukha_ew.gd`](../scripts/modules/core_krasukha_ew.gd)<br>1RL257 克拉苏哈重型电战方舱框架（1RL257）：瓦楞加强筋法拉第电磁屏蔽方舱胸体，正面排布 2×3 具金字塔形微波阻塞干扰波导喇叭，顶置十二棱折面干扰碟与六向测向天线冠。 标准接口：HP-C1 / 自动对齐 … |

## 第 2B 批：重装/炮艇/电子战躯干（10 款） (`batch_02b_cores_heavy` — `0/10`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `core_m1a2_sepv3` | core_m1a2_sepv3 | `core` | `SOCKET_arm_l=[-1.14, 0.82, 0.02]`<br>`SOCKET_arm_r=[1.14, 0.82, 0.02]`<br>`SOCKET_back=[0.0, 1.56, 0.54]`<br>`SOCKET_gen=[0.0, 0.72, 0.96]` | [`core_m1a2_sepv3.gd`](../scripts/modules/core_m1a2_sepv3.gd)<br>SEP-V3 贫铀复合楔甲框架（SEP-V3）：复刻 M1A2 SEPv3 标志性非对称大倾角贫铀复合颊甲、正面牵引配重挂耳、双侧 TUSK ARAT-2 瓦状反应装甲裙与尾舱泄压板。 标准接口：HP-C1 / 自动… |
| ⬜ | `core_merkava_mk4m` | core_merkava_mk4m | `core` | `SOCKET_arm_l=[-1.16, 0.84, 0.04]`<br>`SOCKET_arm_r=[1.16, 0.84, 0.04]`<br>`SOCKET_back=[0.0, 1.58, 0.56]`<br>`SOCKET_gen=[0.0, 0.72, 0.98]` | [`core_merkava_mk4m.gd`](../scripts/modules/core_merkava_mk4m.gd)<br>MRK-4M 战利品主动防御重框架（MRK-4M）：前置动力舱长刀锋铸造楔形首上（左置散热百叶凸台+右置潜望鼓），双肩集成四面 Trophy 相控阵雷达平板与后悬防弹铁锤链帘。 标准接口：HP-C1 / 自动对齐 r… |
| ⬜ | `core_mi24_hind` | core_mi24_hind | `core` | `SOCKET_arm_l=[-0.98, 0.72, 0.04]`<br>`SOCKET_arm_r=[0.98, 0.72, 0.04]`<br>`SOCKET_back=[0.0, 1.42, 0.54]`<br>`SOCKET_gen=[0.0, 0.64, 0.92]` | [`core_mi24_hind.gd`](../scripts/modules/core_mi24_hind.gd)<br>MI-24P 雌鹿双阶重武直框架（MI-24P）：飞行步兵战车经典剪影：前后高低错位串联双层平板防弹风挡座舱、顶置双联 TV3-117 防沙尘进气分离鼓与侧挂箱式红外抑制排烟罩。 标准接口：HP-C1 / 自动对齐 … |
| ⬜ | `core_pantsir_s1` | core_pantsir_s1 | `core` | `SOCKET_arm_l=[-1.08, 0.78, 0.02]`<br>`SOCKET_arm_r=[1.08, 0.78, 0.02]`<br>`SOCKET_back=[0.0, 1.5, 0.52]`<br>`SOCKET_gen=[0.0, 0.68, 0.92]` | [`core_pantsir_s1.gd`](../scripts/modules/core_pantsir_s1.gd)<br>96K6-M 铠甲双面相控阵防空框架（96K6-M）：前胸斜置大尺寸八边形 1RS2-1E 毫米波制导相控阵雷达板，顶置左 10ES1 红外光电跟踪柱与右 2RL80 搜索相控阵横梁。 标准接口：HP-C1 / 自动… |
| ⬜ | `core_patriot_mpq65` | core_patriot_mpq65 | `core` | `SOCKET_arm_l=[-1.12, 0.8, 0.04]`<br>`SOCKET_arm_r=[1.12, 0.8, 0.04]`<br>`SOCKET_back=[0.0, 1.54, 0.54]`<br>`SOCKET_gen=[0.0, 0.7, 0.94]` | [`core_patriot_mpq65.gd`](../scripts/modules/core_patriot_mpq65.gd)<br>MPQ-65 爱国者相控阵制导核心框架（MPQ-65）：正面整块 26° 大倾角 AN/MPQ-65 相控阵雷达装甲板，集成主八角 C波段阵面、副制导阵面、敌我识别横阵与双侧液冷热交换机组。 标准接口：HP-C1 /… |
| ⬜ | `core_pionier_dach` | core_pionier_dach | `core` | `SOCKET_arm_l=[-1.12, 0.78, 0.02]`<br>`SOCKET_arm_r=[1.12, 0.78, 0.02]`<br>`SOCKET_back=[0.0, 1.52, 0.54]`<br>`SOCKET_gen=[0.0, 0.7, 0.94]` | [`core_pionier_dach.gd`](../scripts/modules/core_pionier_dach.gd)<br>PIO-2A 獾式装甲工程起重框架（PIO-2A）：前线重型战损抢修工程躯干：车首内嵌 35 吨铜缆滚轴导缆主绞盘与大吊钩，左舷收拢固定伸缩式箱梁工程起重臂，右舷外挂双联气割钢瓶笼。 标准接口：HP-C1 / 自动对… |
| ⬜ | `core_puma_spz` | core_puma_spz | `core` | `SOCKET_arm_l=[-1.08, 0.76, 0.02]`<br>`SOCKET_arm_r=[1.08, 0.76, 0.02]`<br>`SOCKET_back=[0.0, 1.46, 0.52]`<br>`SOCKET_gen=[0.0, 0.68, 0.92]` | [`core_puma_spz.gd`](../scripts/modules/core_puma_spz.gd)<br>SPZ-30 美洲狮刺猬间隙甲框架（SPZ-30）：德系 C 级重装步战车构型：首上铺设防顶攻橡胶刺猬针垫条，两侧外挂超厚螺栓锁紧 AMAP 模块化复合间隙装甲箱与 MUSS 软杀伤告警头。 标准接口：HP-C1 /… |
| ⬜ | `core_std` | MK-II 中型 框架 | `core` | `SOCKET_arm_l=[-0.78, 0.3, 0.0]`<br>`SOCKET_arm_r=[0.78, 0.3, 0.0]`<br>`SOCKET_back=[0.0, 0.68, 0.36]`<br>`SOCKET_gen=[0.0, 0.12, 0.66]` | [`core_std.gd`](../scripts/modules/core_std.gd)<br>标准躯干 MK-II（B.o.T 式）：多面切角胸甲、偏置三目传感头、肩部护甲 接口：插头 HP-C1（向下）；插座 HP-A1×2、HP-B1、HP-G1 |
| ⬜ | `core_t90m_proryv` | core_t90m_proryv | `core` | `SOCKET_arm_l=[-1.1, 0.76, 0.02]`<br>`SOCKET_arm_r=[1.1, 0.76, 0.02]`<br>`SOCKET_back=[0.0, 1.44, 0.52]`<br>`SOCKET_gen=[0.0, 0.66, 0.94]` | [`core_t90m_proryv.gd`](../scripts/modules/core_t90m_proryv.gd)<br>PRV-90 突破型飞碟楔甲框架（PRV-90）：俄系低矮八角焊接胸塔排布 6 组蚌式 Relikt“化石”双层楔形反应装甲，配双侧窗式红宝石光电干扰灯与侧后防破甲格栅网。 标准接口：HP-C1 / 自动对齐 res… |
| ⬜ | `core_trieste_bathy` | core_trieste_bathy | `core` | `SOCKET_arm_l=[-1.12, 0.8, 0.02]`<br>`SOCKET_arm_r=[1.12, 0.8, 0.02]`<br>`SOCKET_back=[0.0, 1.52, 0.54]`<br>`SOCKET_gen=[0.0, 0.7, 0.94]` | [`core_trieste_bathy.gd`](../scripts/modules/core_trieste_bathy.gd)<br>DSV-11K 万米深潜锻钢耐压框架（DSV-11K）：呼应《潜渊少女》世界观的万米级深海耐压核心：16棱马氏体锻钢耐压筒配中腰 16 螺栓主对接法兰、超厚截锥观察窗、四联深海探照灯与固体浮力护甲。 标准接口：HP-… |

## 第 3A 批：双足 + 履带底盘（7 款） (`batch_03a_legs_walk` — `0/7`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `legs_biped_assault` | VK-5 中重 突击双足底盘 | `legs` | `SOCKET_core=[0.0, 2.21, 0.0]`<br>type=`biped`<br>hip=`1.66`<br>KN=`[0.0, -0.76, -0.22]`<br>AN=`[0.0, -1.38, -0.02]`<br>sole=`-3.32` | [`legs_biped_assault.gd`](../scripts/modules/legs_biped_assault.gd)<br>中重突击双足底盘 VK-5：正关节人形战术重甲腿、铰接防弹腰裙甲、高耸反应装甲撞膝盾、小腿喷口与重型平底战靴 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_biped_scout` | LN-3 轻型 侦察双足底盘 | `legs` | `SOCKET_core=[0.0, 2.08, 0.0]`<br>type=`biped`<br>hip=`1.54`<br>KN=`[0.0, -0.74, -0.36]`<br>AN=`[0.0, -1.26, 0.24]`<br>sole=`-3.076` | [`legs_biped_scout.gd`](../scripts/modules/legs_biped_scout.gd)<br>轻型侦察双足底盘 LN-3：铬钼钢管桁架骨盆、双侧斜置固体火箭推进荚舱、外露氮气减震筒、高速双趾猛禽爪足 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_titan` | TT-8 泰坦 重装双足底盘 | `legs` | `SOCKET_core=[0.0, 2.27, 0.0]`<br>type=`biped`<br>hip=`1.72`<br>KN=`[0.0, -0.74, -0.34]`<br>AN=`[0.0, -1.24, 0.2]`<br>sole=`-3.425` | [`legs_titan.gd`](../scripts/modules/legs_titan.gd)<br>重型双足 Titan：比 Stride 高约 0.4m、粗约 1.4 倍的反关节泰坦腿。 箱形骨盆 + 双层裙甲、三液压大腿、厚胫甲、象足式平底大足（四趾垫 + 后跟） 接口：提供插座 HP-C1（躯干，粗壮腰柱顶端… |
| ⬜ | `legs_tread` | SAXX-1 中重 装甲履带底盘 | `legs` | `SOCKET_core=[0.0, 1.6, 0.0]`<br>type=`tread`<br>hip=`1.05` | [`legs_tread.gd`](../scripts/modules/legs_tread.gd)<br>履带底盘 Mole：分节履带板、负重轮、侧裙甲、斜装甲车体 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_tread_heavy` | KV-6 重型 攻坚履带底盘 | `legs` | `SOCKET_core=[0.0, 1.68, 0.0]`<br>type=`tread`<br>hip=`1.13` | [`legs_tread_heavy.gd`](../scripts/modules/legs_tread_heavy.gd)<br>重型攻坚履带底盘 KV-6：前置V型液压破障推土铲、全车体ERA爆炸反应装甲砖、六负重轮宽履带、立式装甲排烟囱 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_tread_light` | MT-2 轻型 高速履带底盘 | `legs` | `SOCKET_core=[0.0, 1.5, 0.0]`<br>type=`tread`<br>hip=`0.95` | [`legs_tread_light.gd`](../scripts/modules/legs_tread_light.gd)<br>轻型高速履带底盘 MT-2：克里斯蒂大负重轮悬挂、楔形侦察车体、冲孔轻量化挡泥板、双置消音排气管 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_tread_siege` | DT-9 超重 四履带铰接底盘 | `legs` | `SOCKET_core=[0.0, 1.74, 0.0]`<br>type=`tread`<br>hip=`1.19` | [`legs_tread_siege.gd`](../scripts/modules/legs_tread_siege.gd)<br>超重四履带铰接底盘 DT-9：中央飞碟式防核爆斜切底壳 + 四组独立摆臂式重型铰接履带舱（Obj-279 / 巨型工程履带风） 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |

## 第 3B 批：四足 + 六足多足底盘（8 款） (`batch_03b_legs_multi` — `0/8`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `legs_hex` | HX-6 中重 巡航六足底盘 | `legs` | `SOCKET_core=[0.0, 1.84, 0.0]`<br>type=`hex`<br>hip=`1.28`<br>KN=`[0.0, 0.34, 0.78]`<br>AN=`[0.0, -1.23, 1.16]` | [`legs_hex.gd`](../scripts/modules/legs_hex.gd)<br>中重巡航六足底盘 HX-6：流线折面装甲巡航车体、八肋炮塔领座、六条军规双箱梁液压步行肢与三爪驻锄足垫 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_hex_ant` | AT-6 轻型 工兵六足底盘 | `legs` | `SOCKET_core=[0.0, 1.72, 0.0]`<br>type=`hex`<br>hip=`1.18`<br>KN=`[0.0, 0.28, 0.68]`<br>AN=`0, -(hip - 0.02` | [`legs_hex_ant.gd`](../scripts/modules/legs_hex_ant.gd)<br>轻型工兵六足底盘 AT-6：敞露钢管桁架长车体、前置工兵电动绞盘与探照灯、尾部物资备件架、六条双管液压工兵步进肢 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_hex_beetle` | BT-9 重型 甲虫六足底盘 | `legs` | `SOCKET_core=[0.0, 1.82, 0.0]`<br>type=`hex`<br>hip=`1.26`<br>KN=`[0.0, 0.3, 0.78]`<br>AN=`0, -(hip - 0.04` | [`legs_hex_beetle.gd`](../scripts/modules/legs_hex_beetle.gd)<br>重型甲虫六足底盘 BT-9：宽体大倾角防化重装甲背壳、前置双分叉破障撞角、侧悬耳轴护裙与ERA反应砖、六扇弧面重盾步足 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_hex_colossus` | CL-12 巨像 攻城六足底盘 | `legs` | `SOCKET_core=[0.0, 1.96, 0.0]`<br>type=`hex`<br>hip=`1.38`<br>KN=`[0.0, 0.24, 0.76]`<br>AN=`0, -(hip + 0.02` | [`legs_hex_colossus.gd`](../scripts/modules/legs_hex_colossus.gd)<br>巨像攻城六足底盘 CL-12：三段式超重型攻城铆接堡垒船体、前置攻城破城锤铲、双立式防烫柴油烟囱、六根双缸液压打桩重足 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_quad` | AR-4 制式 多地形四足底盘 | `legs` | `SOCKET_core=[0.0, 1.95, 0.0]`<br>type=`quad`<br>hip=`1.4`<br>KN=`[0.0, 0.44, 0.94]`<br>AN=`[0.0, -1.35, 1.36]` | [`legs_quad.gd`](../scripts/modules/legs_quad.gd)<br>四足底盘 Arachne：骨架 + 装甲 + 活塞的蜘蛛腿 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_quad_crab` | CR-6 重甲 堡垒四足底盘 | `legs` | `SOCKET_core=[0.0, 1.78, 0.0]`<br>type=`quad`<br>hip=`1.24`<br>KN=`[0.0, 0.36, 0.96]`<br>AN=`[0.0, -1.19, 1.44]` | [`legs_quad_crab.gd`](../scripts/modules/legs_quad_crab.gd)<br>重甲堡垒四足底盘 CR-6：低矮宽体六边形暗堡车壳、前置钢缆绞盘、四扇弧面重型防爆盾甲蟹足（带ERA反应装甲块） 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_quad_hound` | HD-4 轻型 猎犬四足底盘 | `legs` | `SOCKET_core=[0.0, 1.86, 0.0]`<br>type=`quad`<br>hip=`1.32`<br>KN=`[0.0, -0.46, 0.52]`<br>AN=`0, -(hip - 0.04` | [`legs_quad_hound.gd`](../scripts/modules/legs_quad_hound.gd)<br>轻型猎犬四足底盘 HD-4：仿生军用机械犬窄体纵梁脊柱、前置激光雷达观瞄头与防撞笼、内收式高速液压奔袭四肢 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |
| ⬜ | `legs_quad_mammoth` | MM-10 巨象 支腿四足底盘 | `legs` | `SOCKET_core=[0.0, 2.08, 0.0]`<br>type=`quad`<br>hip=`1.52`<br>KN=`[0.0, 0.1, 0.74]`<br>AN=`0, -(hip + 0.02` | [`legs_quad_mammoth.gd`](../scripts/modules/legs_quad_mammoth.gd)<br>巨象支腿四足底盘 MM-10：重工龙门桁架承重平台、四角防撞警示块、四根垂直双缸液压打桩立柱腿与八角调平驻锄巨足 接口：提供插座 HP-C1（躯干）；自身是装配树的根，无插头 |

## 第 4A 批：机炮/机枪/转管类臂武（14 款） (`batch_04a_arms_ballistic` — `0/14`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `arm_2a46` | 2A46-125 突破型 125mm 自动装填滑膛炮 | `arm` | wpn=`cannon`<br>muzzle=`[0.0, 0.0, -2.84]` | [`arm_2a46.gd`](../scripts/modules/arm_2a46.gd)<br>2A46-125 突破型 125mm 自动装填滑膛炮（2A46-125）：参照T-90M突破型主炮机甲化，配备4S23“化石”反应装甲防盾、五段铝皮抱箍隔热套筒、尾舱抛壳窗与松树-U热像仪。 接口：插头 HP-A1 … |
| ⬜ | `arm_2a72` | 2A72-30 巴赫恰桁架稳管 30mm 自动炮 | `arm` | wpn=`autocannon`<br>muzzle=`[0.0, 0.0, -2.51]` | [`arm_2a72.gd`](../scripts/modules/arm_2a72.gd)<br>2A72-30 巴赫恰桁架稳管 30mm 自动炮（2A72-30）：俄系战车最具辨识度的空间三角形钢桁架稳管30mm自动炮，整合根部波纹复进簧套筒、PKTM并列机枪与双锥切槽制退器。 接口：插头 HP-A1 → a1… |
| ⬜ | `arm_aa12` | AA12-40 恒定后坐弹鼓全自动 40mm 破片霰弹炮 | `arm` | wpn=`shotgun`<br>muzzle=`[0.0, 0.04, -1.77]` | [`arm_aa12.gd`](../scripts/modules/arm_aa12.gd)<br>AA12-40 恒定后坐弹鼓全自动 40mm 破片霰弹炮（AA12-40）：以AA-12全自动战斗霰弹枪为蓝本放大的40mm高爆破片霰弹武器，含一体式恒定后坐方匣、20发腹下圆盘弹鼓、内嵌战术灯与皇冠破门齿。 接口：… |
| ⬜ | `arm_ac30` | AC-30 机炮 | `arm` | wpn=`autocannon`<br>muzzle=`[0.0, -0.02, -2.7]` | [`arm_ac30.gd`](../scripts/modules/arm_ac30.gd)<br>30mm 链式炮 AC-30：链传动机匣 + 侧置电机、装甲防盾、后坐套筒、长身管与双室制退器、腹下弹舱双供弹 接口：插头 HP-A1（朝向躯干）→ a1_mount → 机匣；导出 muzzle |
| ⬜ | `arm_ags152` | AGS-152 折面隐身水冷 152mm 舰载主炮舱 | `arm` | wpn=`cannon`<br>muzzle=`[0.0, -0.01, -2.6]` | [`arm_ags152.gd`](../scripts/modules/arm_ags152.gd)<br>AGS-152 折面隐身水冷 152mm 舰载主炮舱（AGS-152）：融合朱姆沃尔特级AGS与博福斯隐身舰炮设计，采用四截面雷达散射折角炮塔壳、双紫铜水冷循环管与双室舰炮制退器。 接口：插头 HP-A1 → a1_… |
| ⬜ | `arm_amr` | NTW-20 反器材炮 | `arm` | wpn=`sniper`<br>muzzle=`[0.0, -0.01, -3.48]` | [`arm_amr.gd`](../scripts/modules/arm_amr.gd)<br>NTW-20 反器材炮：液压双后坐复进筒、重型机匣与侧置 20mm 弹匣、测距狙击光学舱、超长凹槽重管与宽体冲击制退器 接口：插头 HP-A1 → a1_mount → 炮架本体；导出 muzzle |
| ⬜ | `arm_bofors40` | L70-40 博福斯顶置弹夹 40mm 自动高炮 | `arm` | wpn=`autocannon`<br>muzzle=`[0.0, 0.02, -2.52]` | [`arm_bofors40.gd`](../scripts/modules/arm_bofors40.gd)<br>L70-40 博福斯顶置弹夹 40mm 自动高炮（L70-40）：传奇博福斯40毫米L/70高平两用自动炮，保留标志性顶置梯形供弹漏斗与外露黄铜桥夹、3P近炸编程线圈及锥形喇叭口消焰筒。 接口：插头 HP-A1 → … |
| ⬜ | `arm_cannon` | CN-105 短管炮 | `arm` | wpn=`cannon`<br>muzzle=`[0.0, 0.0, -3.3]` | [`arm_cannon.gd`](../scripts/modules/arm_cannon.gd)<br>105mm 臂载加农炮 HC-105：加粗双层法兰 + 三角加强筋、厚炮盾、双后坐筒、长身管 + 抽烟装置、双室制退器、侧挂炮弹架 接口：插头 HP-A1 → a1_mount（加强）→ 炮尾；导出 muzzle |
| ⬜ | `arm_cg84` | CG84-X2 卡尔·古斯塔夫 M4 双联 84mm 无后坐力炮 | `arm` | wpn=`launcher`<br>muzzle=`[0.0, 0.095, -1.36]` | [`arm_cg84.gd`](../scripts/modules/arm_cg84.gd)<br>CG84-X2 卡尔·古斯塔夫 M4 双联 84mm 无后坐力炮（CG84-X2）：萨博M4碳纤缠绕无后坐力炮双联机甲化挂架，具备外扩文丘里尾喷口、FCD-558智能火控盒与外侧4发串联破甲备弹架。 接口：插头 HP… |
| ⬜ | `arm_cs88` | CS-88 威猛开沟机级碳化钨截齿装甲链锯臂 | `arm` | wpn=`melee`<br>muzzle=`[0.0, -0.01, -2.29]` | [`arm_cs88.gd`](../scripts/modules/arm_cs88.gd)<br>CS-88 威猛开沟机级碳化钨截齿装甲链锯臂（CS-88）：摒弃卡通薄片电锯，参照军用硬岩战壕开沟机打造：外置径向液压马达驱动1.6米锰钢导板，全周排布25节重型链座与斜置镀铬碳化钨截齿锥。 接口：插头 HP-A1 … |
| ⬜ | `arm_flamer` | FT-20 燃烧弹投射器 | `arm` | wpn=`flamer`<br>muzzle=`[0.0, -0.04, -1.45]` | [`arm_flamer.gd`](../scripts/modules/arm_flamer.gd)<br>火焰喷射器：双燃料罐、输油软管、引燃火 接口：插头 HP-A1（朝向躯干）；导出 muzzle |
| ⬜ | `arm_gau8` | GAU-8/30 复仇者七管 30mm 液压加特林机炮 | `arm` | wpn=`autocannon`<br>muzzle=`[0.0, 0.0, -2.34]` | [`arm_gau8.gd`](../scripts/modules/arm_gau8.gd)<br>GAU-8/30 复仇者七管 30mm 液压加特林机炮（GAU-8/30）：将A-10攻击机传奇七管30mm贫铀穿甲转管炮完整浓缩于机械臂，含后置横置无链大弹鼓、双闭环输退弹道与双液压驱动马达。 接口：插头 HP-A… |
| ⬜ | `arm_hc40` | HC-40 创世纪工程拆解级液压鹰嘴破甲剪 | `arm` | wpn=`melee`<br>muzzle=`[0.0, 0.0, -2.08]` | [`arm_hc40.gd`](../scripts/modules/arm_hc40.gd)<br>HC-40 创世纪工程拆解级液压鹰嘴破甲剪（HC-40）：源自万吨级废钢与舰船拆解液压鹰嘴剪，具备黄铜齿圈360°行星回转腕、上下双高压油缸、可更换镀铬直刃刀块与鹰嘴钩状咬合上下颚。 接口：插头 HP-A1 → a1… |
| ⬜ | `arm_hmg` | HMG-24 重型 机枪 | `arm` | wpn=`mg`<br>muzzle=`[0.0, -0.02, -2.32]` | [`arm_hmg.gd`](../scripts/modules/arm_hmg.gd)<br>重机枪 HMG-12：长方形机匣 + 铰接顶盖、带散热孔的枪管护套、锥形消焰器、外挂弹药箱与弹链 接口：插头 HP-A1（朝向躯干）→ a1_mount（法兰 / 回转轴承 / 立轴）→ 机匣；导出 muzzle |

## 第 4B 批：重炮/狙击/磁轨/霰弹臂武（14 款） (`batch_04b_arms_heavy` — `0/14`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `arm_kornet` | 9M133-X4 短号-EM 四联装激光驾束导弹架 | `arm` | wpn=`launcher`<br>muzzle=`[0.0, 0.13, -0.88]` | [`arm_kornet.gd`](../scripts/modules/arm_kornet.gd)<br>9M133-X4 短号-EM 四联装激光驾束导弹架（9M133-X4）：俄制短号-EM重型反装甲导弹开放式四联装桁架，由三道镂空钢框抱持全长外露的4具螺旋玻纤发射筒与厚橡胶防撞端箍，顶置1PN79M热像制导头。 接口… |
| ⬜ | `arm_ks60` | KS-60 截短高炮管 60mm 线膛箭霰弹镇暴重枪 | `arm` | wpn=`shotgun`<br>muzzle=`[0.0, 0.06, -1.92]` | [`arm_ks60.gd`](../scripts/modules/arm_ks60.gd)<br>KS-60 截短高炮管 60mm 线膛箭霰弹镇暴重枪（KS-60）：延续苏式KS-23用高射炮管改制霰弹枪的暴力哲学，采用上置线膛重管、下置全长管式弹仓、双导杆液压泵动护木与外侧5发备弹鞍架。 接口：插头 HP-A1… |
| ⬜ | `arm_laser` | LZ-42 电磁线圈步枪 | `arm` | wpn=`laser`<br>muzzle=`[0.0, -0.02, -2.0]` | [`arm_laser.gd`](../scripts/modules/arm_laser.gd)<br>聚焦激光：散热片阵列、聚焦线圈、冷却管 接口：插头 HP-A1（朝向躯干）；导出 muzzle |
| ⬜ | `arm_lau61` | LAU-61 九头蛇十九管 70mm 蜂窝航空火箭巢 | `arm` | wpn=`launcher`<br>muzzle=`[0.0, -0.05, -1.02]` | [`arm_lau61.gd`](../scripts/modules/arm_lau61.gd)<br>LAU-61 九头蛇十九管 70mm 蜂窝航空火箭巢（LAU-61）：阿帕奇武装直升机经典19管70毫米航空火箭发射巢，采用北约BRU上置挂梁与内侧耳轴转换臂吊挂全长连续圆筒铝壳、19孔蜂窝前端面与缩径尾喷罩。 接口… |
| ⬜ | `arm_m10flm` | M10-FLM “打火机”装甲高压凝固汽油喷射器 | `arm` | wpn=`flamer`<br>muzzle=`[0.0, 0.04, -2.18]` | [`arm_m10flm.gd`](../scripts/modules/arm_m10flm.gd)<br>M10-FLM “打火机”装甲高压凝固汽油喷射器（M10-FLM）：参照美军M132“Zippo”装甲喷火车的M10-8高压液火发射器，腹下并列凝固汽油罐与高压氮气推进钢瓶，配穿孔隔热套与六杆防撞点火稳焰笼。 接口：… |
| ⬜ | `arm_m242` | M242-25 大毒蛇 25mm 双路供弹链式机炮 | `arm` | wpn=`autocannon`<br>muzzle=`[0.0, 0.0, -2.22]` | [`arm_m242.gd`](../scripts/modules/arm_m242.gd)<br>M242-25 大毒蛇 25mm 双路供弹链式机炮（M242-25）：布雷德利步战车主力外动力链式自动炮，配备上下双层穿甲/高爆独立供弹箱、驱动电机鼓、纵向散热槽重枪管与开叉消焰器。 接口：插头 HP-A1 → a1… |
| ⬜ | `arm_m299` | M299-HF4 长弓地狱火四联装滑轨重型导弹架 | `arm` | wpn=`launcher`<br>muzzle=`[0.0, 0.158, -1.1]` | [`arm_m299.gd`](../scripts/modules/arm_m299.gd)<br>M299-HF4 长弓地狱火四联装滑轨重型导弹架（M299-HF4）：采用真实M299全开放式中央工字主梁与四条独立滑轨，4枚AGM-114L毫米波制导“地狱火”导弹从头锥到X形十字尾翼100%全长外露悬挂。 接口：… |
| ⬜ | `arm_m45` | M45-50X4 勃朗宁四联装机甲防空重机枪塔 | `arm` | wpn=`mg`<br>muzzle=`[0.0, 0.105, -1.95]` | [`arm_m45.gd`](../scripts/modules/arm_m45.gd)<br>M45-50X4 勃朗宁四联装机甲防空重机枪塔（M45-50X4）：致敬经典M45“绞肉机”四联装勃朗宁M2HB防空机枪座，配备切角防盾、2×2四联打孔套筒重枪管、十字稳管箍与外挂双层墓碑弹药箱。 接口：插头 HP-… |
| ⬜ | `arm_m68` | M68-105 斯崔克顶置式 105mm 线膛突击炮 | `arm` | wpn=`cannon`<br>muzzle=`[0.0, 0.0, -2.68]` | [`arm_m68.gd`](../scripts/modules/arm_m68.gd)<br>M68-105 斯崔克顶置式 105mm 线膛突击炮（M68-105）：汲取M1128机动火炮系统无人炮舱构型，集成后置转轮自动装弹鼓、风琴橡胶防尘罩与多孔胡椒瓶制退器。 接口：插头 HP-A1 → a1_mount… |
| ⬜ | `arm_m777` | M777-155 超轻型钛合金桁架 155mm 榴弹炮 | `arm` | wpn=`cannon`<br>muzzle=`[0.0, 0.02, -2.85]` | [`arm_m777.gd`](../scripts/modules/arm_m777.gd)<br>M777-155 超轻型钛合金桁架 155mm 榴弹炮（M777-155）：将BAE M777钛合金155毫米榴弹炮重构为重型曲直两用炮臂，具备断隔螺式炮闩、上置双筒液气平衡机、雪橇式摇架与宽翼双室制退器+炮口牵引环… |
| ⬜ | `arm_m82` | M82-35 巴雷特机甲放大版 35mm 反器材狙击炮 | `arm` | wpn=`sniper`<br>muzzle=`[0.0, 0.02, -2.74]` | [`arm_m82.gd`](../scripts/modules/arm_m82.gd)<br>M82-35 巴雷特机甲放大版 35mm 反器材狙击炮（M82-35）：将巴雷特M82A1按机甲尺度重构为35mm精密反器材步枪，采用上下分体冲压机匣、拉机柄抛壳窗、双排散热孔护木、前倾压筋弹匣、中置BORS狙击镜与… |
| ⬜ | `arm_mg` | G-36 转管机炮 | `arm` | wpn=`mg`<br>muzzle=`[0.0, 0.0, -2.26]` | [`arm_mg.gd`](../scripts/modules/arm_mg.gd)<br>速射机炮（B.o.T 式）：长冷却套转管、侧挂橙色大弹鼓、切角机匣 接口：插头 HP-A1（朝向躯干）；导出 muzzle |
| ⬜ | `arm_miclic` | M58-CLC 突击破障车火箭爆破索与反应装甲盾臂 | `arm` | wpn=`launcher`<br>muzzle=`[0.0, 0.365, -1.81]` | [`arm_miclic.gd`](../scripts/modules/arm_miclic.gd)<br>M58-CLC 突击破障车火箭爆破索与反应装甲盾臂（M58-CLC）：集重装防盾与远程爆破清障于一体：前段敞口对开舱盖储药槽显露5圈盘卷C-4导爆索，龙门仰角滑轨搭载MK22固体牵引火箭，外侧披挂ERA破城巨盾。 接… |
| ⬜ | `arm_mk108` | MK108-4X 四联装 30mm 短管薄壳高爆突击炮 | `arm` | wpn=`autocannon`<br>muzzle=`[0.0, 0.01, -1.55]` | [`arm_mk108.gd`](../scripts/modules/arm_mk108.gd)<br>MK108-4X 四联装 30mm 短管薄壳高爆突击炮（MK108-4X）：以二战末期著名的MK 108“气锤”30毫米短管重机炮为原型的四联近距重火力吊舱，配顶置双压缩空气装填瓶、倾角炮盾与四根粗短锥口身管。 接口… |

## 第 4C 批：导弹/火箭/喷火/激光臂武（13 款） (`batch_04c_arms_ordnance` — `0/13`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `arm_ntw57` | NTW-57 丹尼尔侧插弹匣 57mm 远射反装甲枪 | `arm` | wpn=`sniper`<br>muzzle=`[0.0, 0.02, -2.8]` | [`arm_ntw57.gd`](../scripts/modules/arm_ntw57.gd)<br>NTW-57 丹尼尔侧插弹匣 57mm 远射反装甲枪（NTW-57）：源自南非NTW-20重型反器材系统，拥有全长下摇架缓冲滑轨、水平外侧横插重型弹匣、管式防撞提把瞄具护框与超长重枪管。 接口：插头 HP-A1 → … |
| ⬜ | `arm_pb09` | PB-09 火药燃气液压复合攻城打桩机 | `arm` | wpn=`melee`<br>muzzle=`[0.0, -0.01, -2.65]` | [`arm_pb09.gd`](../scripts/modules/arm_pb09.gd)<br>PB-09 火药燃气液压复合攻城打桩机（PB-09）：机甲硬核近战巅峰——结合海上液压打桩锤与6室重型空包弹左轮燃气击发室，沿重型工字钢滑床将实心钨铬八棱穿甲桩瞬间轰入目标核心。 接口：插头 HP-A1 → a1_m… |
| ⬜ | `arm_phalanx` | MK15-20 密集阵 Block 1B 雷达近防炮系统 | `arm` | wpn=`autocannon`<br>muzzle=`[0.0, -0.02, -2.02]` | [`arm_phalanx.gd`](../scripts/modules/arm_phalanx.gd)<br>MK15-20 密集阵 Block 1B 雷达近防炮系统（MK15-20）：舰载终极近程防御系统机甲化移植，主炮箱正上方耸立标志性海雾灰16棱硬表面搜索跟踪雷达塔、侧置HDTI红外吊舱、腹下大弹鼓与6管M61A2火神… |
| ⬜ | `arm_rail` | RG-9 轨道炮 | `arm` | wpn=`laser`<br>muzzle=`[0.0, 0.0, -2.18]` | [`arm_rail.gd`](../scripts/modules/arm_rail.gd)<br>电磁轨道炮 RG-2：双导轨 + 绝缘夹箍、炮尾电容组、动力电缆、散热片；两轨之间透出电弧光 接口：插头 HP-A1（朝向躯干）→ a1_mount → 炮尾；导出 muzzle |
| ⬜ | `arm_ram116` | MK49-RAM 海拉姆十一联装滚体近防导弹箱 | `arm` | wpn=`launcher`<br>muzzle=`[0.0, 0.0, -0.79]` | [`arm_ram116.gd`](../scripts/modules/arm_ram116.gd)<br>MK49-RAM 海拉姆十一联装滚体近防导弹箱（MK49-RAM）：美德联合研制Mk 49舰载近防导弹发射箱机甲化版本，采用八角切边装甲前框、4+3+4交错11管发射阵、尾部泄压百叶与双ESM射频干涉仪角天线。 接口… |
| ⬜ | `arm_rh120` | L55-120 莱茵金属 120mm 长管滑膛坦克炮 | `arm` | wpn=`cannon`<br>muzzle=`[0.0, 0.0, -3.06]` | [`arm_rh120.gd`](../scripts/modules/arm_rh120.gd)<br>L55-120 莱茵金属 120mm 长管滑膛坦克炮（L55-120）：机甲化豹2A7主炮总成，还原楔形间隙复合炮盾、三段玻纤隔热护套、偏心抽烟器、MRS炮口基准镜与外挂MG3同轴机枪箱。 接口：插头 HP-A1 →… |
| ⬜ | `arm_rpo93` | RPO-93X4 “大黄蜂”四联装 93mm 云爆突击包 | `arm` | wpn=`launcher`<br>muzzle=`[0.0, 0.122, -1.11]` | [`arm_rpo93.gd`](../scripts/modules/arm_rpo93.gd)<br>RPO-93X4 “大黄蜂”四联装 93mm 云爆突击包（RPO-93X4）：采用开放式十字承力桁架与三道铝合金偏心快拆抱箍锁紧全长外露的4具93mm玻纤云爆筒，上排两具开盖待发露出黄铜弹头，下排两具保留十字密封盖。… |
| ⬜ | `arm_shotgun` | SG-7 重型霰弹枪 | `arm` | wpn=`shotgun`<br>muzzle=`[0.0, 0.04, -1.62]` | [`arm_shotgun.gd`](../scripts/modules/arm_shotgun.gd)<br>霰弹臂：双管散热护套、侧格栅 接口：插头 HP-A1（朝向躯干）；导出 muzzle |
| ⬜ | `arm_slug` | SLG-12 独头枪 | `arm` | wpn=`shotgun`<br>muzzle=`[0.0, 0.05, -1.82]` | [`arm_slug.gd`](../scripts/modules/arm_slug.gd)<br>独头弹炮 SG-1：大口径单管、通风上导轨、管状弹仓 + 橡胶护木、侧挂弹托（6 发） 接口：插头 HP-A1（朝向躯干）→ a1_mount → 机匣；导出 muzzle |
| ⬜ | `arm_sniper` | M99 精确狙击步枪 | `arm` | wpn=`sniper`<br>muzzle=`[0.0, 0.02, -3.08]` | [`arm_sniper.gd`](../scripts/modules/arm_sniper.gd)<br>M99 精确狙击步枪：肩部稳压护盾、长机匣与直插五发弹匣、高架长焦光学瞄准镜（发光物镜/目镜）、重型浮置精密枪管、双室平板制退器与折叠两脚架 接口：插头 HP-A1 → a1_mount → 狙击步枪机匣；导出 mu… |
| ⬜ | `arm_th60` | TH-60 克虏伯 HB-7000 箱式液压碎岩破甲锤 | `arm` | wpn=`melee`<br>muzzle=`[0.0, 0.0, -2.7]` | [`arm_th60.gd`](../scripts/modules/arm_th60.gd)<br>TH-60 克虏伯 HB-7000 箱式液压碎岩破甲锤（TH-60）：将7吨级矿山与工事拆除液压破碎锤移植上臂，包含挖掘机双耳转接臂、4根外露贯通拉杆、橡胶减振衬垫、氮气蓄能器与粗壮扁楔合金钎杆。 接口：插头 HP-… |
| ⬜ | `arm_tos220` | TOS-220 “烈日”六联装 220mm 装甲温压火箭炮 | `arm` | wpn=`cannon`<br>muzzle=`[0.0, 0.02, -1.43]` | [`arm_tos220.gd`](../scripts/modules/arm_tos220.gd)<br>TOS-220 “烈日”六联装 220mm 装甲温压火箭炮（TOS-220）：一体贯通式TOS-1A“烈日”重型喷火坦克装甲定向器箱，3×2排列6管220毫米温压火箭弹，箱顶全长铺满5块Kontakt-5反应装甲瓦，… |
| ⬜ | `arm_tow2b` | TOW-2B 陶式双联装重型攻顶反坦克导弹箱 | `arm` | wpn=`launcher`<br>muzzle=`[0.0, 0.0, -0.92]` | [`arm_tow2b.gd`](../scripts/modules/arm_tow2b.gd)<br>TOW-2B 陶式双联装重型攻顶反坦克导弹箱（TOW-2B）：布雷德利战车侧面双联陶式反坦克导弹箱机甲化重构，呈现前上方掀开式防爆护盖与双侧液压撑杆、前后贯通肋纹发射筒、攻顶探杆导弹锥头与TAS-4热像舱。 接口：插… |

## 第 5A 批：全部剩余背部挂载（5 款） (`batch_05a_backs_all` — `0/5`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `back_missile` | MS-6 中型 导弹挂架 | `back` | 见原版 `.gd` | [`back_missile.gd`](../scripts/modules/back_missile.gd)<br>蜂巢导弹：双联装 6 发发射巢，带挂架与装填门 接口：插头 HP-B1（朝下，贴躯干顶部后方导轨）；局部 +Y 向上，+Z 向后 |
| ⬜ | `back_rack` | RK-4 外挂 货架 | `back` | 见原版 `.gd` | [`back_rack.gd`](../scripts/modules/back_rack.gd)<br>外挂货架 R-14：管焊框架 + 网格底板，捆着弹药木箱、两只油桶、帆布卷，橙色棘轮绑带 接口：插头 HP-B1 → b1_mount → 货架；局部 +Y 远离躯干 |
| ⬜ | `back_rocket` | RP-7 火箭 巢 | `back` | 见原版 `.gd` | [`back_rocket.gd`](../scripts/modules/back_rocket.gd)<br>双联火箭巢 RK-4：两只 2×2 箱式发射巢，耳轴 + 俯仰液压缸，前盖露出弹头，后部易碎封盖 接口：插头 HP-B1 → b1_mount（导轨卡箍 + 横梁）→ 发射巢；局部 +Y 远离躯干 |
| ⬜ | `back_shield` | SH-3 中型 力场护盾 | `back` | 见原版 `.gd` | [`back_shield.gd`](../scripts/modules/back_shield.gd)<br>相位护盾：发生器箱、桅杆、环形发射器 接口：插头 HP-B1（朝下，贴躯干顶部后方导轨）；局部 +Y 向上，+Z 向后 |
| ⬜ | `back_vls` | VLS-12 垂发 单元 | `back` | 见原版 `.gd` | [`back_vls.gd`](../scripts/modules/back_vls.gd)<br>垂直发射箱 VLS-8：2×4 垂直发射单元，铰链舱盖、侧面加强肋、尾部燃气排导口 接口：插头 HP-B1 → b1_mount（加宽横梁）→ 发射箱；局部 +Y 远离躯干 |

## 第 5B 批：全部剩余动力炉（15 款） (`batch_05b_gens_all` — `0/15`)

| 状态 | 模块 ID | 名称 | 类别 | 接口 / 骨骼关键参数 | 原版脚本参考 & 设计要点 |
| :---: | :--- | :--- | :---: | :--- | :--- |
| ⬜ | `gen_agt1500_turbine` | gen_agt1500_turbine | `gen` | 见原版 `.gd` | [`gen_agt1500_turbine.gd`](../scripts/modules/gen_agt1500_turbine.gd)<br>AGT-1500 回热燃气轮机动力包（AGT-1500）：浓缩 M1 坦克燃气轮机动力总成：顶置旋流滤尘进气箱、双轴压气机壳、尾部圆柱板式回热器圆鼓与矩形防红外上翻排烟百叶。 标准接口：HP-G1 / 自动对齐 re… |
| ⬜ | `gen_crystal` | CR-8 试作中型 反应炉 | `gen` | 见原版 `.gd` | [`gen_crystal.gd`](../scripts/modules/gen_crystal.gd)<br>虫晶反应炉：约束笼 + 悬浮虫晶 + 抑制线圈 接口：插头 HP-G1（朝前，插入躯干背面动力舱）；局部 +Z 向后 |
| ⬜ | `gen_diesel` | DS-6 柴油 机组 | `gen` | 见原版 `.gd` | [`gen_diesel.gd`](../scripts/modules/gen_diesel.gd)<br>柴油发电机组 DG-130：直列缸体 + 带肋缸盖、排气歧管接竖置消音筒（防雨帽）、尾部散热器 + 风扇护罩、燃油滤清器 接口：插头 HP-G1（朝前插入动力舱）→ g1_mount（背板 + 四角锁销）→ 机组；局… |
| ⬜ | `gen_hfc` | HFC-3 氢燃料 堆 | `gen` | 见原版 `.gd` | [`gen_hfc.gd`](../scripts/modules/gen_hfc.gd)<br>氢燃料电池堆 HFC-180：两只卧式高压储氢罐（箍带 + 阀门）、层叠电堆（端板 + 拉杆）、冷却液管 接口：插头 HP-G1（朝前插入动力舱）→ g1_mount → 罐组与电堆；局部 +Z 向后 |
| ⬜ | `gen_homopolar_pulse` | gen_homopolar_pulse | `gen` | 见原版 `.gd` | [`gen_homopolar_pulse.gd`](../scripts/modules/gen_homopolar_pulse.gd)<br>HPG-90 单极超导脉冲电容电站（HPG-90）：专为电磁轨道炮与定向脉冲电弧打造的 64MJ 脉冲储能模块：法拉第屏蔽钢柜内嵌 3×2 高压薄膜电容方罐、双色绝缘套管与横贯紫铜层叠母排。 标准接口：HP-G1 /… |
| ⬜ | `gen_hydrothermal_hx` | gen_hydrothermal_hx | `gen` | 见原版 `.gd` | [`gen_hydrothermal_hx.gd`](../scripts/modules/gen_hydrothermal_hx.gd)<br>HTX-12 深渊热液超临界钛换热炉（HTX-12）：专为深渊高压热液裂口研发的闭式热能动力炉：上下双筒并列钛合金管壳式高压换热器、10螺栓锻造管箱盲板、四路紫铜跨接歧管与双涡轮膨胀机。 标准接口：HP-G1 / 自… |
| ⬜ | `gen_lfr_lead_bismuth` | gen_lfr_lead_bismuth | `gen` | 见原版 `.gd` | [`gen_lfr_lead_bismuth.gd`](../scripts/modules/gen_lfr_lead_bismuth.gd)<br>SVBR-10 铅铋液态金属快中子堆（SVBR-10）：极高功率密度液态重金属反应堆：八边形生物屏蔽胸甲包裹铅铋反应芯鼓、3 道防凝固紫铜电伴热母排箍与双侧无轴 MHD 电磁液态金属泵。 标准接口：HP-G1 / 自… |
| ⬜ | `gen_mhd_plasma_gen` | gen_mhd_plasma_gen | `gen` | 见原版 `.gd` | [`gen_mhd_plasma_gen.gd`](../scripts/modules/gen_mhd_plasma_gen.gd)<br>MHD-40 磁流体超音速通道发电炉（MHD-40）：冷战硬核黑科技军械化：电离燃气以超音速冲过中央矩形法拉第通道，切割上下巨型紫铜鞍形励磁线圈磁场直接转化为兆瓦级强电流。 标准接口：HP-G1 / 自动对齐 res… |
| ⬜ | `gen_mtu_mb873_v12` | gen_mtu_mb873_v12 | `gen` | 见原版 `.gd` | [`gen_mtu_mb873_v12.gd`](../scripts/modules/gen_mtu_mb873_v12.gd)<br>MB-873 双涡轮 V12 重柴动力包（MB-873）：德系整体快拆重型柴油动力包：90° V 型 12 缸分列铸铝气缸盖、左右对称双废气涡轮增压蜗壳、紫铜中冷管与顶置双圆环冷却风扇。 标准接口：HP-G1 / 自… |
| ⬜ | `gen_naval_pwr_s9g` | gen_naval_pwr_s9g | `gen` | 见原版 `.gd` | [`gen_naval_pwr_s9g.gd`](../scripts/modules/gen_naval_pwr_s9g.gd)<br>S9G-PWR 潜艇级压水微堆动力舱（S9G-PWR）：重装舰载级核动力核心：中央立式 12 螺栓锻钢反应堆压力壳与 4 组控制棒套管，左右对称双立式蒸汽发生器圆筒与主冷却剂刚性横管。 标准接口：HP-G1 / 自动… |
| ⬜ | `gen_pem_fuelcell` | gen_pem_fuelcell | `gen` | 见原版 `.gd` | [`gen_pem_fuelcell.gd`](../scripts/modules/gen_pem_fuelcell.gd)<br>PEM-600 氢氧质子交换膜燃料电堆（PEM-600）：零红外与零声学特征电化学静默电站：4 根高强预紧拉杆锁紧多层双极板反应电堆、顶置紫铜直流汇流母排与周围 4 具固态金属氢化物储氢罐。 标准接口：HP-G1 /… |
| ⬜ | `gen_reactor` | RT-1 试作中型 动力炉 | `gen` | 见原版 `.gd` | [`gen_reactor.gd`](../scripts/modules/gen_reactor.gd)<br>微型反应堆：圆柱压力容器、径向散热片、冷却回路 接口：插头 HP-G1（朝前，插入躯干背面动力舱）；局部 +Z 向后 |
| ⬜ | `gen_stirling_aip` | gen_stirling_aip | `gen` | 见原版 `.gd` | [`gen_stirling_aip.gd`](../scripts/modules/gen_stirling_aip.gd)<br>MK3-AIP 斯特林闭式绝气动力炉（MK3-AIP）：深海潜航闭式外燃机：上部四缸斯特林再生加热器套筒与紫铜燃烧钟罩，下部双联台锥封头低温液氧杜瓦钢瓶，水下无气泡超静音运行。 标准接口：HP-G1 / 自动对齐 r… |
| ⬜ | `gen_turbine` | TB-5 涡轮 机组 | `gen` | 见原版 `.gd` | [`gen_turbine.gd`](../scripts/modules/gen_turbine.gd)<br>燃气轮机组 GT-260：加强安装背板、减速齿轮箱、粗壮涡轮机匣（法兰环 + 燃烧室凸台）、顶部进气罩、双排气管 + 打孔隔热罩、下挂发电机 接口：插头 HP-G1 → g1_mount → 齿轮箱 → 涡轮；局部 … |
| ⬜ | `gen_twin_apu_gtcp` | gen_twin_apu_gtcp | `gen` | 见原版 `.gd` | [`gen_twin_apu_gtcp.gd`](../scripts/modules/gen_twin_apu_gtcp.gd)<br>GTCP-85 双转子航空涡轮发电舱（GTCP-85）：仅重 7kg 的超轻量化空降双冗余涡轮发电包：左右并列双套微型离心燃气轮机、无刷交流发电机鼓、侧进气网罩与顶置灭火瓶。 标准接口：HP-G1 / 自动对齐 re… |
