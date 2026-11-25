extends RefCounted
## 地图团队的扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
##
## MAPS     新战区，格式与 scripts\maps.gd 的 MAPS 相同（9×9 区块、道路、河流、湖、山脊、铁路、POI、地名、撤离点）；
##          可选 music = 探索曲音乐槽（默认 <战区 id>_explore）。
## POIS     新遗迹 POI 类型：{id: {"name": 地图上显示的名字, "script": 路径, "compound": true/false}}。
##          script 里写 static func build(raid, center: Vector3, poi_id: String)；compound = true 时 raid.gd 先建标准围墙院落
##          （缺口墙、灯、火桶、军用箱、保险柜、工具箱、守卫甲虫），再调用 build 摆中央布景。
##          战区的 pois 条目写成 [列, 行, POI id] 指定类型；只写 [列, 行] 的按 scripts\maps.gd 的 POI_ORDER 依次分配。
## ITEMS / LOOT_TABLES  档案物件、POI 专属容器等。
## MUSIC    新战区的探索曲槽（格式同 scripts\audio\audio_registry.gd 的 MUSIC）。
## SFX      地标、天气、动态事件音效的登记；不登记也能按命名约定播放，登记后列入音频清单。
## RAID_SCRIPTS  行动扩展脚本路径（规则见 scripts\raid.gd 的 _run_ext_build）：地标在 build 里摆，天气与动态事件写成 Node 脚本；
##          这些脚本读取 raid.MAP（当前战区条目）里自己定义的字段，如 landmarks、weather。
## EXTEND   给已有条目补字段，如 {"MAPS": {"greyport": {"landmarks": [...], "weather": {...}}}}、往已有战区追加 pois。

const EXTEND := {
	"MAPS": {
		"greyport": {
			"pois": [[5, 2, "metro_station"], [6, 6, "hospital"], [5, 4, "church"], [2, 3, "fire_station"], [4, 5, "police_precinct"]],
			"weather": {
				"preset": "clear",
			},
			"landmarks": [
				{"type": "broken_bridge", "x": 64, "z": 6, "rot": 0, "clear": 10, "water": true},
				{"type": "radio_mast", "x": -120, "z": -120, "rot": 30, "clear": 6},
				{"type": "elevated_road", "x": 110, "z": -120, "rot": 25, "clear": 9},
				{"type": "central_terminus", "x": -96, "z": 12, "rot": 12, "clear": 12},
				{"type": "drawbridge_gate", "x": 124, "z": 58, "rot": 0, "clear": 10},
			],
			"labels": [["三号线站台", 40, -80], ["城南医院", 80, 80], ["旧港教堂", 40, 0], ["旧城消防站", -80, -40], ["旧城治安分局", 0, 40], ["灰港断桥", 64, 6], ["旧城广播塔", -120, -120], ["高架残段", 95, -114], ["中央穹顶总站", -96, 12], ["东河开启桥头堡", 124, 58]],
		},
		"ironbelt": {
			"pois": [[3, 1, "power_station"], [6, 3, "parking_garage"], [4, 6, "relay_tower"], [2, 4, "salvage_foundry"], [4, 2, "locomotive_roundhouse"]],
			"weather": {"preset": "dusk_gloom"},
			"landmarks": [
				{"type": "gantry", "x": 120, "z": 10, "rot": 8, "clear": 9},
				{"type": "blast_furnace", "x": -140, "z": -120, "rot": 0, "clear": 8},
				{"type": "gas_holder", "x": 30, "z": -60, "rot": 18, "clear": 7},
				{"type": "converter_foundry", "x": -82, "z": -18, "rot": 0, "clear": 13},
				{"type": "cooling_tower", "x": 116, "z": -118, "rot": 12, "clear": 9},
			],
			"labels": [["北区发电站", -40, -140], ["东区停车楼", 80, -40], ["废弃通讯中继塔", 0, 80], ["重工熔炉铸造厂", -80, 0], ["扇形机车检修库", 0, -80], ["运河龙门吊", 126, 25], ["一号钢厂高炉", -146, -114], ["煤气罐区", 30, -60], ["二号转炉钢厂", -82, -18], ["双曲面冷却塔", 116, -118]],
		},
		"dustfield": {
			"pois": [[3, 3, "school"], [6, 3, "checkpoint"], [5, 5, "fuel_depot"], [4, 1, "airship_mooring_mast"], [6, 6, "checkpoint_fortress"]],
			"weather": {"preset": "sandstorm"},
			"landmarks": [
				{"type": "windmill", "x": -130, "z": 30, "rot": 12, "clear": 8},
				{"type": "pylon_row", "x": 40, "z": 40, "rot": 78, "clear": 6},
				{"type": "silo", "x": -80, "z": 80, "rot": 0, "clear": 8},
				{"type": "missile_silo", "x": -62, "z": -112, "rot": 18, "clear": 13},
			],
			"labels": [["城西学校", -40, -40], ["七号检查站", 100, -40], ["七号公路加油站", 40, 40], ["飞空艇系泊塔", 0, -120], ["南线装甲检查站", 80, 80], ["风车阵", -130, 30], ["高压电塔列", 40, 40], ["农场筒仓", -80, 80], ["洲际发射井阵地", -62, -112]],
		},
		"redlake": {
			"pois": [[5, 2, "hydro_lab"], [7, 5, "parking_garage"], [3, 6, "hydroponic_biodome"], [3, 1, "astronomical_observatory"]],
			"weather": {"preset": "lake_mist"},
			"landmarks": [
				{"type": "boardwalk", "x": 44, "z": -24, "rot": 0, "clear": 6, "water": true},
				{"type": "observation_tower", "x": 130, "z": 30, "rot": 20, "clear": 6},
				{"type": "spillway_dam", "x": 18, "z": 88, "rot": -8, "clear": 12},
			],
			"labels": [["沉没的水质观测所", 40, -80], ["东区停车楼", 120, 40], ["生态水培穹顶温室", -40, 80], ["北岭天文观测台", -40, -120], ["赤湖观景栈桥", 44, -24], ["环湖观景塔", 142, 30], ["赤湖溢洪闸枢", 18, 88]],
		},
		"canyon": {
			"pois": [[4, 7, "mining_terminal"], [4, 4, "egret_bridge"], [2, 5, "radar_array_tower"], [3, 2, "ore_crusher_tipple"]],
			"weather": {"preset": "canyon_noon"},
			"landmarks": [
				{"type": "cable_tower", "x": -80, "z": -140, "rot": 15, "clear": 6},
				{"type": "ore_silos", "x": -20, "z": -100, "rot": 8, "clear": 9},
				{"type": "rope_bridge", "x": 140, "z": -40, "rot": 90, "clear": 5},
				{"type": "bucket_excavator", "x": 76, "z": 18, "rot": -24, "clear": 13},
			],
			"labels": [["深井选矿终端", 0, 120], ["白鹭号舰桥舱", 0, 0], ["峡谷预警雷达塔", -80, 40], ["选矿破碎传送楼", -40, -80], ["峡谷缆车塔", -80, -140], ["矿场筒仓", -20, -100], ["悬崖索桥", 140, -40], ["斗轮挖掘机平台", 76, 18]],
		},
		"bayport": {
			"music": "bayport_explore",
			"pois": [[3, 5, "power_station"], [6, 3, "checkpoint"], [6, 1, "coastal_artillery"], [4, 1, "abyss_lighthouse"], [5, 5, "bathysphere_dock"]],
			"weather": {
				"preset": "rain",
			},
			"landmarks": [
				{"type": "gantry", "x": 134, "z": -78, "rot": 88, "clear": 9},
				{"type": "observation_tower", "x": -18, "z": -122, "rot": 18, "clear": 6},
				{"type": "gas_holder", "x": 14, "z": 112, "rot": 14, "clear": 7},
				{"type": "submarine_drydock", "x": 116, "z": 12, "rot": -90, "clear": 14},
				{"type": "helipad_pad", "x": -96, "z": 108, "rot": 15, "clear": 7},
			],
			"labels": [["港区变电站", -40, 40], ["港务海防哨卡", 80, -40], ["北岬海防重炮要塞", 80, -120], ["北岬断顶灯塔", 0, -120], ["深潜器干船坞", 40, 40], ["北泊位龙门吊", 134, -78], ["港务领航塔", -18, -122], ["船用储油罐区", 14, 112], ["巨型潜艇干船坞", 116, 12], ["港西起降坪", -96, 108]],
		},
	},
}

## 终章战区：裂谷矿区再往下的超深钻探竖井遗址。黑曜岩壁合围成环，中央是塌陷的钻探弹坑，
## 菌毯与紫光晶簇铺满井底，孢子代替了地表的灰烬。
const MAPS := {
	"abyss_maw": {
		"name": "零号深渊井",
		"hidden": true,
		"tag": "深渊 · 竖井与晶脉",
		"desc": "裂谷矿区再往下，是旧世界超深钻探留下的竖井遗址。黑曜岩壁把井口合围成一圈，中央塌陷的弹坑里铺满菌毯与紫光晶簇；孢子像雪一样在探照灯的光柱里浮沉，井底的母巢仍在缓慢呼吸。",
		"zones": [
			"KKKWCKKKK",
			"KKWWCSWKK",
			"KWWCCSWWK",
			"KWSSCCCWK",
			"WCCCCCSCW",
			"KWSCCCCSK",
			"KKWSCSSKK",
			"KKKWCWSKK",
			"KKKKCWKKK"],
		"roads": [],
		"curves": [],
		"river": {"w": 0.0, "dry": true, "pts": []},
		"lakes": [],
		"ridges": [
			[[-138, -118], [-116, -92], [-128, -54]],
			[[126, 38], [104, 84], [68, 118]]],
		"rails": [
			[[-158, -42], [-112, -68], [-60, -76], [-8, -74], [42, -74], [84, -66]]],
		"pois": [[4, 4, "well_core"], [2, 2, "mining_terminal"], [5, 6, "geothermal_wellhead"], [2, 5, "comms_dish_station"]],
		"weather": {"preset": "spore_abyss"},
		"landmarks": [
			{"type": "coolant_channel", "x": -48, "z": 86, "rot": 25, "clear": 10},
			{"type": "crystal_cluster", "x": 110, "z": 70, "rot": 0, "clear": 6},
			{"type": "crystal_cluster", "x": -110, "z": -70, "rot": 30, "clear": 6},
			{"type": "drill_derrick", "x": 90, "z": -120, "rot": 0, "clear": 6},
			{"type": "geothermal_vault", "x": 82, "z": -22, "rot": 16, "clear": 12},
		],
		"labels": [["零号竖井", 0, 0], ["深井选矿终端", -80, -80], ["深渊地热井口站", 40, 80], ["深空射电接收站", -80, 40], ["冷却渠", -30, 70], ["北侧晶脉", -110, -70], ["南侧孢子林", 110, 70],
			["黑曜岩壁", -160, 0], ["钻井残台", 90, -120], ["地热磁约束腔", 82, -22], ["西侧塌方", -120, 100]],
		"extracts": [["北侧升降机", 0, -168], ["南侧塌方口", 4, 166], ["东侧通风井", 166, -8], ["西侧旧巷道", -166, 10]],
	},
}
## 新遗迹类型。每个条目自带完整院落与轮廓，不用标准围墙（compound 省略即为 false）。
const POIS := {
	"metro_station": {"name": "三号线站台", "script": "res://scripts/map_ext/poi/metro_station.gd"},
	"hospital": {"name": "城南医院", "script": "res://scripts/map_ext/poi/hospital.gd"},
	"power_station": {"name": "北区发电站", "script": "res://scripts/map_ext/poi/power_station.gd"},
	"checkpoint": {"name": "七号检查站", "script": "res://scripts/map_ext/poi/checkpoint.gd"},
	"church": {"name": "旧港教堂", "script": "res://scripts/map_ext/poi/church.gd"},
	"school": {"name": "城西学校", "script": "res://scripts/map_ext/poi/school.gd"},
	"parking_garage": {"name": "东区停车楼", "script": "res://scripts/map_ext/poi/parking_garage.gd"},
	"relay_tower": {"name": "废弃通讯中继塔", "script": "res://scripts/map_ext/poi/relay_tower.gd"},
	"hydro_lab": {"name": "沉没的水质观测所", "script": "res://scripts/map_ext/poi/hydro_lab.gd"},
	"mining_terminal": {"name": "深井选矿终端", "script": "res://scripts/map_ext/poi/mining_terminal.gd"},
	"egret_bridge": {"name": "白鹭号舰桥舱", "script": "res://scripts/map_ext/poi/egret_bridge.gd"},
	"well_core": {"name": "零号钻井核心台", "script": "res://scripts/map_ext/poi/well_core.gd"},
	"fire_station": {
		"name": "旧城消防站",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_fire_station_remake",
		"sz": Vector3(17.2, 12.2, 12.6),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.6), "sz": Vector3(13.6, 10.5, 8.2)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.2), "kind": "tool", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.2), "kind": "med", "yaw": 0.0},
			{"pos": Vector3(-3.8, 0.0, 7.6), "kind": "supply", "yaw": 180.0},
			{"pos": Vector3(3.8, 0.0, 7.6), "kind": "safe", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "beetle", "r": 2.8}, {"pos": Vector3(6.0, 0.0, 2.2), "kind": "spitter", "r": 2.2}],
		"lamps": [{"pos": Vector3(-8.8, 0.0, 4.0), "col": Color(1.0, 0.72, 0.42)}, {"pos": Vector3(8.8, 0.0, 4.0), "col": Color(0.95, 0.45, 0.35)}],
	},
	"police_precinct": {
		"name": "旧城治安分局",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_police_precinct_remake",
		"sz": Vector3(17.6, 10.2, 13.0),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.6), "sz": Vector3(14.0, 9.2, 8.4)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.2), "kind": "weapon", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.2), "kind": "ammo", "yaw": 0.0},
			{"pos": Vector3(-3.8, 0.0, 7.6), "kind": "safe", "yaw": 180.0},
			{"pos": Vector3(3.8, 0.0, 7.6), "kind": "military", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.4), "kind": "beetle", "r": 3.0}, {"pos": Vector3(-5.8, 0.0, 2.6), "kind": "ling", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.8, 0.0, 4.0), "col": Color(0.55, 0.78, 1.0)}, {"pos": Vector3(8.8, 0.0, 4.0), "col": Color(1.0, 0.78, 0.48)}],
	},
	"coastal_artillery": {
		"name": "北岬海防重炮要塞",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_coastal_artillery_remake",
		"sz": Vector3(16.6, 10.0, 13.6),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.6), "sz": Vector3(13.2, 8.8, 8.4)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.2), "kind": "weapon", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.2), "kind": "ammo", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.6), "kind": "military", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.6), "kind": "safe", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.4), "kind": "beetle", "r": 3.0}, {"pos": Vector3(5.6, 0.0, 2.8), "kind": "spitter", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.6, 0.0, 3.8), "col": Color(1.0, 0.74, 0.42)}, {"pos": Vector3(8.6, 0.0, 3.8), "col": Color(0.62, 0.84, 1.0)}],
	},
	"abyss_lighthouse": {
		"name": "北岬断顶灯塔",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_abyss_lighthouse_remake",
		"sz": Vector3(14.0, 16.8, 12.0),
		"offset": Vector3(0.0, 0.0, -5.0),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.2), "sz": Vector3(10.6, 14.0, 8.0)}],
		"crates": [
			{"pos": Vector3(-5.8, 0.0, 3.8), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(5.8, 0.0, 3.8), "kind": "supply", "yaw": 0.0},
			{"pos": Vector3(-3.4, 0.0, 7.2), "kind": "safe", "yaw": 180.0},
			{"pos": Vector3(3.4, 0.0, 7.2), "kind": "med", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.0), "kind": "spitter", "r": 2.6}, {"pos": Vector3(-5.0, 0.0, 2.5), "kind": "ling", "r": 2.2}],
		"lamps": [{"pos": Vector3(-7.6, 0.0, 3.6), "col": Color(0.70, 0.88, 1.0)}, {"pos": Vector3(7.6, 0.0, 3.6), "col": Color(1.0, 0.78, 0.48)}],
	},
	"bathysphere_dock": {
		"name": "深潜器干船坞",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_bathysphere_dock_remake",
		"sz": Vector3(17.2, 11.8, 12.8),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.6), "sz": Vector3(13.6, 10.2, 8.4)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.2), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.2), "kind": "tool", "yaw": 0.0},
			{"pos": Vector3(-3.8, 0.0, 7.6), "kind": "safe", "yaw": 180.0},
			{"pos": Vector3(3.8, 0.0, 7.6), "kind": "container", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "beetle", "r": 2.8}, {"pos": Vector3(5.6, 0.0, 2.6), "kind": "spitter", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.8, 0.0, 4.0), "col": Color(0.55, 0.88, 0.96)}, {"pos": Vector3(8.8, 0.0, 4.0), "col": Color(1.0, 0.76, 0.44)}],
	},
	"salvage_foundry": {
		"name": "重工熔炉铸造厂",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "bldg_salvage_foundry_remake",
		"sz": Vector3(17.6, 13.0, 12.4),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.6), "sz": Vector3(14.0, 11.4, 8.2)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.2), "kind": "tool", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.2), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(-3.8, 0.0, 7.6), "kind": "safe", "yaw": 180.0},
			{"pos": Vector3(3.8, 0.0, 7.6), "kind": "supply", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "beetle", "r": 3.0}, {"pos": Vector3(-5.8, 0.0, 2.4), "kind": "spitter", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.8, 0.0, 4.0), "col": Color(1.0, 0.62, 0.28)}, {"pos": Vector3(8.8, 0.0, 4.0), "col": Color(1.0, 0.78, 0.46)}],
	},
	"locomotive_roundhouse": {
		"name": "扇形机车检修库",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "bldg_locomotive_roundhouse_remake",
		"sz": Vector3(17.8, 10.8, 13.4),
		"offset": Vector3(0.0, 0.0, -5.4),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.8), "sz": Vector3(14.2, 9.6, 8.6)}],
		"crates": [
			{"pos": Vector3(-6.4, 0.0, 4.2), "kind": "tool", "yaw": 0.0},
			{"pos": Vector3(6.4, 0.0, 4.2), "kind": "supply", "yaw": 0.0},
			{"pos": Vector3(-3.8, 0.0, 7.8), "kind": "tech", "yaw": 180.0},
			{"pos": Vector3(3.8, 0.0, 7.8), "kind": "container", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.4), "kind": "beetle", "r": 3.0}, {"pos": Vector3(5.8, 0.0, 2.6), "kind": "ling", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.8, 0.0, 4.0), "col": Color(1.0, 0.74, 0.44)}, {"pos": Vector3(8.8, 0.0, 4.0), "col": Color(0.68, 0.85, 1.0)}],
	},
	"fuel_depot": {
		"name": "七号公路加油站",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_fuel_depot_remake",
		"sz": Vector3(17.8, 7.6, 13.0),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.6), "sz": Vector3(14.0, 6.8, 8.2)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.2), "kind": "supply", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.2), "kind": "tool", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.6), "kind": "register", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.6), "kind": "cache", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "spitter", "r": 2.8}, {"pos": Vector3(-5.6, 0.0, 2.4), "kind": "ling", "r": 2.2}],
		"lamps": [{"pos": Vector3(-8.8, 0.0, 4.0), "col": Color(1.0, 0.78, 0.44)}, {"pos": Vector3(8.8, 0.0, 4.0), "col": Color(1.0, 0.68, 0.36)}],
	},
	"airship_mooring_mast": {
		"name": "飞空艇系泊塔",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_airship_mooring_mast_remake",
		"sz": Vector3(15.6, 16.8, 13.4),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.4), "sz": Vector3(9.4, 15.0, 8.4), "cyl": true}],
		"crates": [
			{"pos": Vector3(-6.0, 0.0, 4.0), "kind": "military", "yaw": 0.0},
			{"pos": Vector3(6.0, 0.0, 4.0), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.4), "kind": "supply", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.4), "kind": "safe", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "beetle", "r": 2.8}, {"pos": Vector3(5.6, 0.0, 2.4), "kind": "spitter", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.2, 0.0, 3.8), "col": Color(1.0, 0.76, 0.42)}, {"pos": Vector3(8.2, 0.0, 3.8), "col": Color(0.62, 0.86, 1.0)}],
	},
	"checkpoint_fortress": {
		"name": "南线装甲检查站",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_checkpoint_fortress_remake",
		"sz": Vector3(17.6, 8.8, 11.2),
		"offset": Vector3(0.0, 0.0, -5.0),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.4), "sz": Vector3(13.8, 7.8, 7.6)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.0), "kind": "military", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.0), "kind": "ammo", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.4), "kind": "weapon", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.4), "kind": "safe", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "beetle", "r": 3.0}, {"pos": Vector3(-5.8, 0.0, 2.6), "kind": "ling", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.6, 0.0, 3.8), "col": Color(1.0, 0.70, 0.38)}, {"pos": Vector3(8.6, 0.0, 3.8), "col": Color(1.0, 0.78, 0.48)}],
	},
	"hydroponic_biodome": {
		"name": "生态水培穹顶温室",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_hydroponic_biodome_remake",
		"sz": Vector3(17.2, 10.8, 13.2),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.6), "sz": Vector3(13.4, 9.5, 8.4)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.2), "kind": "med", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.2), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.6), "kind": "supply", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.6), "kind": "safe", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "spitter", "r": 2.8}, {"pos": Vector3(5.6, 0.0, 2.4), "kind": "ling", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.6, 0.0, 4.0), "col": Color(0.48, 0.92, 0.76)}, {"pos": Vector3(8.6, 0.0, 4.0), "col": Color(0.68, 0.90, 1.0)}],
	},
	"astronomical_observatory": {
		"name": "北岭天文观测台",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_astronomical_observatory_remake",
		"sz": Vector3(16.0, 13.2, 12.6),
		"offset": Vector3(0.0, 0.0, -5.0),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.4), "sz": Vector3(12.2, 11.4, 8.2)}],
		"crates": [
			{"pos": Vector3(-6.0, 0.0, 4.0), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(6.0, 0.0, 4.0), "kind": "safe", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.4), "kind": "med", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.4), "kind": "supply", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.0), "kind": "beetle", "r": 2.8}, {"pos": Vector3(-5.4, 0.0, 2.4), "kind": "spitter", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.2, 0.0, 3.8), "col": Color(0.64, 0.86, 1.0)}, {"pos": Vector3(8.2, 0.0, 3.8), "col": Color(1.0, 0.80, 0.52)}],
	},
	"radar_array_tower": {
		"name": "峡谷预警雷达塔",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_radar_array_tower_remake",
		"sz": Vector3(14.6, 15.4, 12.4),
		"offset": Vector3(0.0, 0.0, -5.0),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.4), "sz": Vector3(10.8, 13.2, 8.0)}],
		"crates": [
			{"pos": Vector3(-5.8, 0.0, 4.0), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(5.8, 0.0, 4.0), "kind": "military", "yaw": 0.0},
			{"pos": Vector3(-3.4, 0.0, 7.4), "kind": "ammo", "yaw": 180.0},
			{"pos": Vector3(3.4, 0.0, 7.4), "kind": "safe", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.0), "kind": "beetle", "r": 2.8}, {"pos": Vector3(5.2, 0.0, 2.4), "kind": "spitter", "r": 2.2}],
		"lamps": [{"pos": Vector3(-7.8, 0.0, 3.8), "col": Color(0.60, 0.86, 1.0)}, {"pos": Vector3(7.8, 0.0, 3.8), "col": Color(1.0, 0.72, 0.40)}],
	},
	"ore_crusher_tipple": {
		"name": "选矿破碎传送楼",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "bldg_ore_crusher_tipple_remake",
		"sz": Vector3(17.8, 13.2, 11.4),
		"offset": Vector3(0.0, 0.0, -5.0),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.4), "sz": Vector3(14.0, 11.6, 7.8)}],
		"crates": [
			{"pos": Vector3(-6.2, 0.0, 4.0), "kind": "tool", "yaw": 0.0},
			{"pos": Vector3(6.2, 0.0, 4.0), "kind": "cache", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.4), "kind": "tech", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.4), "kind": "supply", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "beetle", "r": 3.0}, {"pos": Vector3(-5.6, 0.0, 2.4), "kind": "ling", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.6, 0.0, 3.8), "col": Color(1.0, 0.72, 0.38)}, {"pos": Vector3(8.6, 0.0, 3.8), "col": Color(1.0, 0.78, 0.48)}],
	},
	"geothermal_wellhead": {
		"name": "深渊地热井口站",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_geothermal_wellhead_remake",
		"sz": Vector3(16.6, 14.8, 12.2),
		"offset": Vector3(0.0, 0.0, -5.0),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.4), "sz": Vector3(12.8, 13.0, 8.0)}],
		"crates": [
			{"pos": Vector3(-6.0, 0.0, 4.0), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(6.0, 0.0, 4.0), "kind": "cache", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.4), "kind": "safe", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.4), "kind": "military", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "beetle", "r": 3.0}, {"pos": Vector3(5.4, 0.0, 2.4), "kind": "spitter", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.4, 0.0, 3.8), "col": Color(1.0, 0.58, 0.24)}, {"pos": Vector3(8.4, 0.0, 3.8), "col": Color(0.48, 0.88, 0.96)}],
	},
	"comms_dish_station": {
		"name": "深空射电接收站",
		"script": "res://scripts/map_ext/poi/prefab_poi.gd",
		"prefab": "poi_comms_dish_station_remake",
		"sz": Vector3(16.6, 14.4, 12.8),
		"offset": Vector3(0.0, 0.0, -5.2),
		"blockers": [{"pos": Vector3(0.0, 0.0, -5.6), "sz": Vector3(12.8, 12.6, 8.2)}],
		"crates": [
			{"pos": Vector3(-6.0, 0.0, 4.2), "kind": "tech", "yaw": 0.0},
			{"pos": Vector3(6.0, 0.0, 4.2), "kind": "safe", "yaw": 0.0},
			{"pos": Vector3(-3.6, 0.0, 7.6), "kind": "weapon", "yaw": 180.0},
			{"pos": Vector3(3.6, 0.0, 7.6), "kind": "med", "yaw": 180.0},
		],
		"guards": [{"pos": Vector3(0.0, 0.0, 4.2), "kind": "beetle", "r": 2.8}, {"pos": Vector3(-5.6, 0.0, 2.4), "kind": "spitter", "r": 2.4}],
		"lamps": [{"pos": Vector3(-8.4, 0.0, 4.0), "col": Color(0.50, 0.86, 1.0)}, {"pos": Vector3(8.4, 0.0, 4.0), "col": Color(1.0, 0.74, 0.42)}],
	},
}

## 档案物件：散落在遗迹里的可拾取记录。codex 字段是拾取后解锁的图鉴条目 id（与物品同名）。
## 描述是占位句，正文与图鉴条目由编剧统一撰写。
const ITEMS := {
		"arch_duty_log": {"name": "值班日志", "cat": "misc", "w": 0.1, "v": 40, "rar": 1, "codex": "arch_duty_log"},
		"arch_photo": {"name": "泛黄照片", "cat": "misc", "w": 0.1, "v": 40, "rar": 1, "codex": "arch_photo"},
		"arch_letter": {"name": "未寄出的信", "cat": "misc", "w": 0.1, "v": 40, "rar": 1, "codex": "arch_letter"},
		"arch_manifest": {"name": "货运清单", "cat": "misc", "w": 0.1, "v": 40, "rar": 1, "codex": "arch_manifest"},
		"arch_blueprint": {"name": "手绘蓝图", "cat": "misc", "w": 0.1, "v": 50, "rar": 1, "codex": "arch_blueprint"},
		"arch_tape": {"name": "录音磁带", "cat": "misc", "w": 0.1, "v": 50, "rar": 1, "codex": "arch_tape"},
		"arch_child_drawing": {"name": "儿童画", "cat": "misc", "w": 0.1, "v": 40, "rar": 1, "codex": "arch_child_drawing"},
		"arch_research_note": {"name": "观测笔记", "cat": "misc", "w": 0.1, "v": 50, "rar": 2, "codex": "arch_research_note"},
		"arch_observation": {"name": "水质记录", "cat": "misc", "w": 0.1, "v": 50, "rar": 2, "codex": "arch_observation"},
		"arch_shift_log": {"name": "班次记录", "cat": "misc", "w": 0.1, "v": 40, "rar": 1, "codex": "arch_shift_log"},
		"arch_flight_log": {"name": "航行日志残页", "cat": "misc", "w": 0.1, "v": 80, "rar": 2, "codex": "arch_flight_log"},
		"arch_deep_record": {"name": "深井钻探记录", "cat": "misc", "w": 0.1, "v": 80, "rar": 3, "codex": "arch_deep_record"},
	}
## 行动扩展脚本：地标摆放 + 天气与动态事件（含档案解锁、中继塔军械箱解锁）
const RAID_SCRIPTS := [
	"res://scripts/map_ext/landmarks.gd",
	"res://scripts/map_ext/weather.gd",
	"res://scripts/map_ext/events.gd",
]
const MUSIC := {
	"bayport_explore": {"file": "greyport_explore.ogg", "loop": true, "scene": "东湾船坞港探索（未交战）"},
	"abyss_maw_explore": {"file": "abyss_maw_explore.ogg", "loop": true, "scene": "零号深渊井探索（未交战）"},
}
