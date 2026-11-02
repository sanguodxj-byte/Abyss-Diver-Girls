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
			"pois": [[5, 2, "metro_station"], [6, 6, "hospital"], [5, 4, "church"]],
			"weather": {"preset": "rain"},
			"landmarks": [
				{"type": "broken_bridge", "x": 64, "z": 6, "rot": 0, "clear": 10, "water": true},
				{"type": "radio_mast", "x": -120, "z": -120, "rot": 30, "clear": 6},
				{"type": "elevated_road", "x": 110, "z": -120, "rot": 25, "clear": 9},
			],
			"labels": [["三号线站台", 40, -80], ["城南医院", 80, 80], ["旧港教堂", 40, 0], ["灰港断桥", 64, 6], ["旧城广播塔", -120, -120], ["高架残段", 110, -120]],
		},
		"ironbelt": {
			"pois": [[3, 1, "power_station"], [6, 3, "parking_garage"], [4, 6, "relay_tower"]],
			"weather": {"preset": "dusk_gloom"},
			"landmarks": [
				{"type": "gantry", "x": 120, "z": 10, "rot": 8, "clear": 9},
				{"type": "blast_furnace", "x": -140, "z": -120, "rot": 0, "clear": 8},
				{"type": "gas_holder", "x": 30, "z": -60, "rot": 18, "clear": 7},
			],
			"labels": [["北区发电站", -40, -140], ["东区停车楼", 80, -40], ["废弃通讯中继塔", 0, 80], ["运河龙门吊", 120, 10], ["一号钢厂高炉", -140, -120], ["煤气罐区", 30, -60]],
		},
		"dustfield": {
			"pois": [[3, 3, "school"], [6, 3, "checkpoint"]],
			"weather": {"preset": "sandstorm"},
			"landmarks": [
				{"type": "windmill", "x": -130, "z": 30, "rot": 12, "clear": 8},
				{"type": "pylon_row", "x": 40, "z": 40, "rot": 78, "clear": 6},
				{"type": "silo", "x": -80, "z": 80, "rot": 0, "clear": 8},
			],
			"labels": [["城西学校", -40, -40], ["七号检查站", 100, -40], ["风车阵", -130, 30], ["高压电塔列", 40, 40], ["农场筒仓", -80, 80]],
		},
		"redlake": {
			"pois": [[5, 2, "hydro_lab"], [7, 5, "parking_garage"]],
			"weather": {"preset": "lake_mist"},
			"landmarks": [
				{"type": "boardwalk", "x": 44, "z": -24, "rot": 0, "clear": 6, "water": true},
				{"type": "observation_tower", "x": 130, "z": 30, "rot": 20, "clear": 6},
			],
			"labels": [["沉没的水质观测所", 40, -80], ["东区停车楼", 120, 40], ["赤湖观景栈桥", 44, -24], ["环湖观景塔", 130, 30]],
		},
		"canyon": {
			"pois": [[4, 7, "mining_terminal"], [4, 4, "egret_bridge"]],
			"weather": {"preset": "canyon_noon"},
			"landmarks": [
				{"type": "cable_tower", "x": -80, "z": -140, "rot": 15, "clear": 6},
				{"type": "ore_silos", "x": -20, "z": -100, "rot": 8, "clear": 9},
				{"type": "rope_bridge", "x": 140, "z": -40, "rot": 90, "clear": 5},
			],
			"labels": [["深井选矿终端", 0, 120], ["白鹭号舰桥舱", 0, 0], ["峡谷缆车塔", -80, -140], ["矿场筒仓", -20, -100], ["悬崖索桥", 140, -40]],
		},
	},
}

## 终章战区：裂谷矿区再往下的超深钻探竖井遗址。黑曜岩壁合围成环，中央是塌陷的钻探弹坑，
## 菌毯与紫光晶簇铺满井底，孢子代替了地表的灰烬。
const MAPS := {
	"abyss_maw": {
		"name": "零号深渊井",
		"tag": "深渊 · 竖井与晶脉",
		"desc": "裂谷矿区再往下，是旧世界超深钻探留下的竖井遗址。黑曜岩壁把井口合围成一圈，中央塌陷的弹坑里铺满菌毯与紫光晶簇；孢子像雪一样在探照灯的光柱里浮沉，井底的母巢仍在缓慢呼吸。",
		"zones": [
			"KKKKKKKKK",
			"KKWSSSWKK",
			"KSISSSSIK",
			"KSSCCCSSK",
			"KSCCCCCSK",
			"KSSCCCSSK",
			"KSISSSSIK",
			"KKWSSSWKK",
			"KKKKKKKKK"],
		"roads": [],
		"curves": [
			[7.0, true, [[-180, -120], [-80, -90], [0, -40], [70, -70], [170, -110]]],
			[7.0, true, [[-160, 140], [-60, 100], [20, 60], [90, 90], [180, 140]]],
			[6.0, true, [[-188, 20], [-120, 30], [-60, 10], [-20, -30]]]],
		"river": {"w": 0.0, "dry": true, "pts": []},
		"lakes": [],
		"ridges": [],
		"rails": [],
		"pois": [[4, 4, "well_core"], [2, 2, "mining_terminal"]],
		"weather": {"preset": "spore_abyss"},
		"landmarks": [
			{"type": "coolant_channel", "x": -30, "z": 70, "rot": 0, "clear": 10},
			{"type": "crystal_cluster", "x": 110, "z": 70, "rot": 0, "clear": 6},
			{"type": "crystal_cluster", "x": -110, "z": -70, "rot": 30, "clear": 6},
			{"type": "drill_derrick", "x": 90, "z": -120, "rot": 0, "clear": 6},
		],
		"labels": [["零号竖井", 0, 0], ["深井选矿终端", -80, -80], ["冷却渠", -30, 70], ["北侧晶脉", -110, -70], ["南侧孢子林", 110, 70],
			["黑曜岩壁", -160, 0], ["钻井残台", 90, -120], ["东侧菌毯", 120, -60], ["西侧塌方", -120, 100]],
		"extracts": [["北侧升降机", 0, -168], ["南侧塌方口", 0, 168], ["东侧通风井", 168, 0], ["西侧旧巷道", -168, 0]],
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
