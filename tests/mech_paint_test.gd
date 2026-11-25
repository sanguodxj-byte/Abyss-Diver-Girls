extends "res://tests/lib/test_base.gd"
## 机甲军工涂装与迷彩系统全链路回归测试：
##   1. 机库 UI 交互：涂装叶片开关、与挂点换装抽屉互斥、10 套预设切换、迷彩/旧化/色板一键转自定义；
##   2. PBR 物理分层审计：仅重绘电介质烤漆层（armor/armor_sub/armor_dark/accent），裸钢/橡胶履带/警示条/光学玻璃/发光灯 100% 原样保留，且不污染全局共享材质缓存；
##   3. 一键恢复原厂：零重建精确还原每个网格的原始材质引用；
##   4. 存档往返与战斗实装：save_game/load_game 无损持久化，玩家机体保持 occ_exempt=1.0，NPC 机体不受玩家涂装影响。
## 运行：godot --headless --path . -- --mech_paint_test

const START := "hub"
const TIMEOUT := 60.0

const MechPaint = preload("res://scripts/mech_paint.gd")
const MechScript = preload("res://scripts/mech.gd")
const NpcMechScript = preload("res://scripts/factions/npc_mech.gd")
const MechGlb = preload("res://scripts/modules/mech_glb.gd")


func _collect_role_meshes(root: Node3D) -> Dictionary:
	var out := {"painted": [], "untouched": []}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or mi.material_override == null:
			continue
		var orig: Material = mi.get_meta("_paint_orig_mat") if mi.has_meta("_paint_orig_mat") else mi.material_override
		var role := MechPaint.classify_material(orig)
		if role != "":
			out["painted"].append([mi, orig, role])
		else:
			out["untouched"].append([mi, orig])
	return out


func run() -> void:
	await frames(3)
	var hub = main.hub
	check(hub != null and is_instance_valid(hub), "机库主界面已初始化")
	check(hub.preview_mech != null and is_instance_valid(hub.preview_mech), "机库 3D 预览机甲已生成")
	check(hub.maint_paint_blade != null and hub.maint_paint_drawer != null, "机库涂装定制入口与抽屉已挂载")

	# 装配履带底盘以同时覆盖橡胶履带、枪钢炮管、警示条与多层装甲
	GameData.loadout["core"] = "core_heavy"
	GameData.loadout["legs"] = "legs_tread_heavy"
	GameData.loadout["arm_l"] = "arm_ac30"
	GameData.loadout["arm_r"] = "arm_cannon"
	GameData.loadout["back"] = "back_missile"
	GameData.loadout["gen"] = "gen_reactor"
	hub.refresh()
	await frames(2)

	# 1. 抽屉开关与挂点抽屉互斥检查
	hub._toggle_maint_swap("core")
	check(hub.maint_drawer.visible and not hub.maint_paint_drawer.visible, "打开挂点抽屉时涂装抽屉保持关闭")
	hub._toggle_maint_paint()
	check(hub.maint_paint_open and hub.maint_paint_drawer.visible and not hub.maint_drawer.visible, "打开涂装抽屉时自动收起挂点抽屉")
	hub._toggle_maint_swap("arm_l")
	check(not hub.maint_paint_open and not hub.maint_paint_drawer.visible and hub.maint_drawer.visible, "切换回挂点抽屉时自动收起涂装抽屉")
	hub._toggle_maint_paint()
	check(hub.maint_paint_open and hub.maint_paint_drawer.visible, "再次打开涂装抽屉正常")

	# 记录默认状态下所有网格原始材质引用及全局缓存基准颜色
	var snap0 := _collect_role_meshes(hub.preview_mech)
	check((snap0["painted"] as Array).size() >= 6, "识别到机甲主/副装甲与点缀烤漆层 (%d)" % (snap0["painted"] as Array).size())
	check((snap0["untouched"] as Array).size() >= 4, "识别到裸金属/橡胶履带/灯具等非涂装层 (%d)" % (snap0["untouched"] as Array).size())
	var orig_colors := {}
	for entry: Array in snap0["painted"]:
		var orig_sm := entry[1] as ShaderMaterial
		orig_colors[orig_sm.get_instance_id()] = orig_sm.get_shader_parameter("base_color")

	# 2. 遍历全部 10 套预设，校验参数同步与非涂装材质保护
	for pd: Dictionary in MechPaint.PRESETS:
		var pid := str(pd.get("id", "default"))
		hub._select_paint_preset(pid)
		var cur := _collect_role_meshes(hub.preview_mech)
		for u: Array in cur["untouched"]:
			var mi_u: MeshInstance3D = u[0]
			var orig_u: Material = u[1]
			check(mi_u.material_override == orig_u, "预设 [%s] 未污染裸金属/橡胶/发光材质" % pid)
		if pid == "default":
			for p_ent: Array in cur["painted"]:
				var mi_p: MeshInstance3D = p_ent[0]
				var orig_p: Material = p_ent[1]
				check(mi_p.material_override == orig_p, "原厂标准精确还原原始材质实例")
		else:
			var exp_pat := int(pd.get("pattern", 0))
			var saw_armor_camo := false
			for p_ent: Array in cur["painted"]:
				var mi_p: MeshInstance3D = p_ent[0]
				var orig_p: Material = p_ent[1]
				var role_s: String = p_ent[2]
				check(mi_p.material_override != orig_p, "预设 [%s] 烤漆层 [%s] 使用独立材质副本" % [pid, role_s])
				var sm_p := mi_p.material_override as ShaderMaterial
				if role_s == "armor":
					check(int(sm_p.get_shader_parameter("camo_mode")) == exp_pat, "预设 [%s] 主装甲 camo_mode=%d" % [pid, exp_pat])
					saw_armor_camo = true
			check(saw_armor_camo, "预设 [%s] 主装甲迷彩已生效" % pid)

	# 确认全局共享材质缓存未被原地篡改
	for entry: Array in snap0["painted"]:
		var orig_sm := entry[1] as ShaderMaterial
		check(orig_sm.get_shader_parameter("base_color") == orig_colors[orig_sm.get_instance_id()], "全局共享基础材质颜色零污染")

	# 3. 从原厂标准直接点选迷彩/旧化/色板：自动升级为 custom 并持久化
	hub._select_paint_preset("default")
	check(MechPaint.is_factory_default(GameData.mech_paint), "已回到原厂标准")
	hub._set_paint_pattern(2)
	check(str(GameData.mech_paint.preset) == "custom" and int(GameData.mech_paint.pattern) == 2, "原厂状态下点击折线数码自动进入自定义模式")
	hub._set_paint_wear(2)
	hub._set_paint_channel("primary")
	hub._set_paint_color_hex("#8c7a5b")
	hub._set_paint_channel("accent")
	hub._set_paint_color_hex("#389ec4")
	check(str(GameData.mech_paint.primary) == "#8c7a5b" and str(GameData.mech_paint.accent) == "#389ec4" and int(GameData.mech_paint.wear) == 2, "自定义色板与重度战损写入成功")

	# 换装新模块后依然自动保持涂装且合批正常
	GameData.loadout["core"] = "core_fortress"
	hub.refresh()
	await frames(1)
	var after_swap := _collect_role_meshes(hub.preview_mech)
	var fortress_painted := false
	for p_ent: Array in after_swap["painted"]:
		var sm_f := (p_ent[0] as MeshInstance3D).material_override as ShaderMaterial
		if p_ent[2] == "armor" and int(sm_f.get_shader_parameter("camo_mode")) == 2:
			fortress_painted = true
	check(fortress_painted, "机库更换新模块后自动继承当前自定义迷彩")

	# 4. 存档保存与读取往返校验
	var saved_snap := GameData.mech_paint.duplicate()
	GameData.save_game()
	GameData.mech_paint = MechPaint.default_config()
	check(GameData.load_game(), "load_game 成功读取测试存档")
	check(GameData.mech_paint == saved_snap, "存档无损还原 mech_paint=%s" % JSON.stringify(GameData.mech_paint))

	# 5. 战区玩家机体（保持 occ_exempt=1.0）与 NPC 机体（不受玩家涂装影响）校验
	var p_mech := MechScript.new()
	add_child(p_mech)
	p_mech.setup(GameData.loadout, [])
	var p_meshes := _collect_role_meshes(p_mech.visual)
	var p_ok := false
	for p_ent: Array in p_meshes["painted"]:
		var sm_pm := (p_ent[0] as MeshInstance3D).material_override as ShaderMaterial
		check(float(sm_pm.get_shader_parameter("occ_exempt")) >= 0.99, "玩家机体涂装材质保留 occ_exempt=1.0")
		if p_ent[2] == "armor" and int(sm_pm.get_shader_parameter("camo_mode")) == 2:
			p_ok = true
	check(p_ok, "战区玩家机体已应用自定义折线数码涂装")

	var npc := NpcMechScript.new()
	add_child(npc)
	npc.faction = "rover"
	npc.setup(GameData.loadout, [])
	npc._paint()
	for n in npc.visual.find_children("*", "MeshInstance3D", true, false):
		var mi_n := n as MeshInstance3D
		if mi_n != null and mi_n.material_override is ShaderMaterial:
			var sm_n := mi_n.material_override as ShaderMaterial
			if sm_n.shader != null and sm_n.shader.resource_path.contains("mech_trim"):
				var cm_n = sm_n.get_shader_parameter("camo_mode")
				check(cm_n == null or int(cm_n) == 0, "NPC 游荡者机体不受玩家迷彩涂装影响")

	p_mech.queue_free()
	npc.queue_free()
	await frames(1)
	done()
