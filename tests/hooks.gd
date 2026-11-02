extends "res://tests/lib/test_base.gd"
## 扩展点：临时登记一份样例脚本（tests\lib\hook_fixture.gd），确认行动扩展的 build 与节点、
## 武器 AMMO.script 的 fire、技能 SKILLS.script 的 use、消耗品 ITEMS.script 的 use 都会被调用。
## godot --headless --path . -- --hooks
const FIX := "res://tests/lib/hook_fixture.gd"


func run() -> void:
	await wait(0.3)
	GameData.RAID_SCRIPTS.append(FIX)
	GameData.AMMO["zz_gun"] = {"mag": 4, "reload": 1.0, "tex": "ammo_mg", "script": FIX}
	var arm: Dictionary = GameData.MODULES["arm_mg"].duplicate()
	arm["name"] = "zz_gun"
	arm["weapon"] = "zz_gun"
	GameData.MODULES["zz_gun_arm"] = arm
	GameData._module_item("zz_gun_arm")
	GameData.SKILLS["core_scout"]["script"] = FIX
	GameData.ITEMS["zz_item"] = {"name": "zz_item", "cat": "use", "w": 0.1, "v": 1, "rar": 0, "desc": "", "script": FIX}
	var lo: Dictionary = GameData.STARTER.duplicate()
	lo["arm_l"] = "zz_gun_arm"
	GameData.cargo = ["zz_item"]
	var raid = await deploy(lo)
	if not check(raid != null, "出击失败"):
		return
	var m = raid.mech
	m.shield_time = 999.0
	if not check(raid.has_meta("zz_built"), "行动扩展的 static func build 没有被调用"):
		return
	if not check(raid.has_meta("zz_node_setup") and raid.get_node_or_null("ext_hook_fixture") != null, "行动扩展节点没有加进行动场景或没有调用 setup"):
		return
	m.try_fire("arm_l")
	if not check(m.get_meta("zz_fired", "") == "arm_l", "AMMO.script 的 fire 没有被调用"):
		return
	m.energy = m.max_energy
	m.try_skill_e()
	if not check(m.get_meta("zz_skill_used", "") == "e", "SKILLS.script 的 use 没有被调用"):
		return
	if not check(m.cargo.has("zz_item"), "测试消耗品没有带进货舱：%s" % [m.cargo]):
		return
	m.use_item("zz_item")
	if not check(m.get_meta("zz_item_used", "") == "zz_item" and not m.cargo.has("zz_item"), "ITEMS.script 的 use 没有被调用或没有扣除物品"):
		return
	GameData.SKILLS["core_scout"].erase("script")
	GameData.RAID_SCRIPTS.erase(FIX)
