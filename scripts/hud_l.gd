extends RefCounted
## 左下角 L 形状态栏与触控双摇杆部件：
##   HoloPortrait    —— 拐角：机甲正视图全息投影，部位按完好度着色（浅蓝→黄→橙→红→缺失）
##   AmmoColumn      —— 竖线：子弹贴图逐颗堆叠，开一枪弹壳弹出、整列向下滑一格；换弹时子弹从顶端逐颗落下（点击可手动换弹）
##   SkillSlot       —— 横线：Space / F 技能槽（贴图槽位 + 图标 + 扇形冷却 + 键帽，支持触控点击）
##   TouchStick      —— 虚拟摇杆：左摇杆移动、右摇杆瞄准/射击（支持多点触控与鼠标拖拽）
##   TouchBtn        —— 战术触控圆钮：冲刺 / 机能 / 换弹快捷触控键

const MV = preload("res://scripts/mech_visual.gd")
const Icons = preload("res://scripts/item_icons.gd")

static func part_color(f: float) -> Color:
	return _pc(f)


static func _pc(f: float) -> Color:
	if f > 0.75:
		return Color(0.76, 0.82, 0.80)
	if f > 0.5:
		return Color(0.84, 0.58, 0.22)
	if f > 0.25:
		return Color(0.82, 0.38, 0.14)
	return Color(0.78, 0.22, 0.18)


# ====================================================================== 全息投影
class HoloPortrait extends SubViewportContainer:
	var mech
	var vp: SubViewport
	var model: Node3D
	var mats := {}       ## slot -> ShaderMaterial
	var meshes := {}     ## slot -> [MeshInstance3D]
	var shown := {}      ## slot -> 上次显示的颜色档位（变化时闪烁）
	var flash := {}
	var t := 0.0
	var _rt_acc := 0.0

	const HOLO := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 col = vec3(0.74, 0.80, 0.78);
uniform float flash = 0.0;
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	vec3 key_l = normalize(vec3(0.55, 0.74, 0.42));
	vec3 fill_l = normalize(vec3(-0.62, 0.22, 0.68));
	float ndl = clamp(dot(n, key_l) * 0.5 + 0.5, 0.0, 1.0);
	float fill = max(dot(n, fill_l), 0.0);
	float rim = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 2.1);
	float spec = pow(max(dot(reflect(-key_l, n), v), 0.0), 12.0) * 0.30;
	float seam = clamp(length(fwidth(n)) * 0.65, 0.0, 0.48);
	vec3 base = (col * (0.14 + 0.76 * pow(ndl, 1.9) + 0.16 * fill + rim * 0.48) + vec3(spec)) * (1.0 - seam * 0.52);
	ALBEDO = mix(base, vec3(1.0, 0.92, 0.76), flash * 0.75);
}
"""
	const POST := """
shader_type canvas_item;
uniform vec3 tint = vec3(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float vig = 1.0 - dot(UV - 0.5, UV - 0.5) * 0.42;
	float micro = 0.97 + 0.03 * sin(UV.y * 280.0 - TIME * 2.5);
	c.rgb *= tint * vig * micro;
	c.a *= 0.88;
	COLOR = c;
}
"""

	func _on_resized() -> void:
		if vp != null and is_instance_valid(vp):
			var cap := 220 if OS.has_feature("mobile") else 360
			var mult := 1.5 if OS.has_feature("mobile") else 2.2
			vp.size = Vector2i(maxi(int(round(size.x * mult)), cap), maxi(int(round(size.y * mult)), cap))
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	func setup(m) -> void:
		mech = m
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if vp != null and is_instance_valid(vp):
			vp.queue_free()
			vp = null
		mats.clear()
		meshes.clear()
		shown.clear()
		flash.clear()
		var pm := ShaderMaterial.new()
		var ps := Shader.new()
		ps.code = POST
		pm.shader = ps
		material = pm
		vp = SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("mobile") else Viewport.MSAA_4X
		var cap := 220 if OS.has_feature("mobile") else 360
		var mult := 1.5 if OS.has_feature("mobile") else 2.2
		vp.size = Vector2i(maxi(int(round(size.x * mult)), cap), maxi(int(round(size.y * mult)), cap))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		if not resized.is_connected(_on_resized):
			resized.connect(_on_resized)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		vp.add_child(env)
		model = MV.build(m.loadout, false, false)
		model.rotation.y = -0.48
		vp.add_child(model)
		var sh := Shader.new()
		sh.code = HOLO
		for slot in ["core", "legs", "arm_l", "arm_r", "back", "gen"]:
			var sm := ShaderMaterial.new()
			sm.shader = sh
			mats[slot] = sm
			meshes[slot] = []
			flash[slot] = 0.0
		_assign(model, "core")
		_merge_slots()
		var box := AABB()
		var has_box := false
		for slot in meshes:
			for mmi: MeshInstance3D in meshes[slot]:
				if mmi.mesh != null:
					var b := mmi.mesh.get_aabb()
					box = b if not has_box else box.merge(b)
					has_box = true
		if not has_box:
			box = AABB(Vector3(-1.3, 0.0, -1.0), Vector3(2.6, 3.2, 2.0))
		var center := box.get_center() + Vector3(0.0, box.size.y * 0.02, 0.0)
		var rad := maxf(maxf(box.size.x, box.size.z) * 0.62, box.size.y * 0.56)
		var fov := 26.0
		var dist := maxf((rad / tan(deg_to_rad(fov * 0.5))) * 1.12, 5.2)
		var cam_pos := center + Vector3(0.0, box.size.y * 0.42, -dist)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = fov
		cam.transform = Transform3D(Basis.looking_at((center - cam_pos).normalized(), Vector3.UP), cam_pos)
		vp.add_child(cam)
		cam.current = true

	func _rel_xf(n: Node3D, top: Node3D) -> Transform3D:
		var xf := Transform3D.IDENTITY
		var cur: Node = n
		while cur != null and cur != top:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		return xf

	func _append_mesh_surface(mesh: Mesh, surf_idx: int, xf: Transform3D, out_v: PackedVector3Array, out_n: PackedVector3Array) -> void:
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surf_idx) != Mesh.PRIMITIVE_TRIANGLES:
			return
		var arrays := mesh.surface_get_arrays(surf_idx)
		if arrays.is_empty():
			return
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if src_v.is_empty():
			return
		var has_n: bool = arrays[Mesh.ARRAY_NORMAL] != null and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == src_v.size()
		var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if has_n else PackedVector3Array()
		var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var det := xf.basis.determinant()
		var flip := det < 0.0
		var nbasis := xf.basis.inverse().transposed() if absf(det) > 1e-8 else xf.basis
		var count := src_i.size() if not src_i.is_empty() else src_v.size()
		for k in range(0, count - 2, 3):
			var i0 := src_i[k] if not src_i.is_empty() else k
			var i1 := src_i[k + (2 if flip else 1)] if not src_i.is_empty() else (k + (2 if flip else 1))
			var i2 := src_i[k + (1 if flip else 2)] if not src_i.is_empty() else (k + (1 if flip else 2))
			var v0 := xf * src_v[i0]
			var v1 := xf * src_v[i1]
			var v2 := xf * src_v[i2]
			var n0: Vector3
			var n1: Vector3
			var n2: Vector3
			if has_n:
				n0 = (nbasis * src_n[i0]).normalized()
				n1 = (nbasis * src_n[i1]).normalized()
				n2 = (nbasis * src_n[i2]).normalized()
			else:
				var fn := (v2 - v0).cross(v1 - v0).normalized()
				n0 = fn
				n1 = fn
				n2 = fn
			out_v.append(v0)
			out_v.append(v1)
			out_v.append(v2)
			out_n.append(n0)
			out_n.append(n1)
			out_n.append(n2)

	func _merge_slots() -> void:
		var merged_slots := {}
		for slot in meshes:
			var list: Array = meshes[slot]
			if list.is_empty():
				merged_slots[slot] = []
				continue
			var out_v := PackedVector3Array()
			var out_n := PackedVector3Array()
			for mi: MeshInstance3D in list:
				if mi.mesh == null or not mi.visible:
					continue
				var xf := _rel_xf(mi, model)
				for si in mi.mesh.get_surface_count():
					_append_mesh_surface(mi.mesh, si, xf, out_v, out_n)
			if out_v.is_empty():
				merged_slots[slot] = []
				continue
			var am := ArrayMesh.new()
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = out_v
			arrays[Mesh.ARRAY_NORMAL] = out_n
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mmi := MeshInstance3D.new()
			mmi.mesh = am
			mmi.material_override = mats[slot]
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			merged_slots[slot] = [mmi]
		for ch in model.get_children():
			model.remove_child(ch)
			ch.free()
		for slot in merged_slots:
			meshes[slot] = merged_slots[slot]
			for mmi in meshes[slot]:
				model.add_child(mmi)

	func _assign(n: Node, slot: String) -> void:
		var s := slot
		if n.has_meta("slot") and n.get_meta("slot") in mats:
			s = n.get_meta("slot")
		if n is MeshInstance3D:
			n.material_override = mats[s]
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			meshes[s].append(n)
		elif n is Light3D or n is GPUParticles3D or n is CPUParticles3D or n is Decal or n is Label3D or n is Sprite3D:
			n.visible = false
		for c in n.get_children():
			_assign(c, s)

	func _col(f: float) -> Color:
		if f > 0.75:
			return Color(0.64, 0.72, 0.72)
		if f > 0.5:
			return Color(0.84, 0.58, 0.22)
		if f > 0.25:
			return Color(0.82, 0.38, 0.14)
		return Color(0.78, 0.22, 0.18)

	func part_frac(slot: String) -> float:
		if slot == "core":
			return clampf(mech.hp / mech.max_hp, 0.0, 1.0)
		return float(mech.parts.get(slot, 1.0))

	func _process(delta: float) -> void:
		if mech == null or model == null:
			return
		t += delta
		_rt_acc += delta
		var dirty := _rt_acc >= 0.05
		model.rotation.y = -0.48 + sin(t * 0.55) * 0.14
		for slot in mats:
			var f := part_frac(slot)
			var band := 4 if f > 0.75 else (3 if f > 0.5 else (2 if f > 0.25 else (1 if f > 0.0 else 0)))
			if shown.get(slot, 4) != band:
				shown[slot] = band
				flash[slot] = 1.0
				dirty = true
				for mi in meshes[slot]:
					mi.visible = band > 0
			if flash[slot] > 0.0:
				flash[slot] = max(0.0, flash[slot] - delta * 2.5)
				dirty = true
			var c := _col(f)
			if band == 1:
				c = c * (0.65 + 0.35 * sin(t * 12.0))   # 红色档闪烁告警
				dirty = true
			mats[slot].set_shader_parameter("col", Vector3(c.r, c.g, c.b))
			mats[slot].set_shader_parameter("flash", flash[slot])
		if dirty and vp != null:
			_rt_acc = 0.0
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# ====================================================================== 子弹栏
class AmmoColumn extends Control:
	var mech
	var slot := "arm_l"
	var tex: Texture2D
	var mag := 0
	var yoff: Array = []          ## 每颗子弹相对最终位置的上浮量（>0 = 还在上方，正在滑落）
	var ejects: Array = []
	var bw := 36.0
	var bh := 8.0
	var pitch := 9.0
	var font: Font
	var _was_broken := false
	var _was_od := false
	var _was_reloading := false

	func setup(m, s: String) -> void:
		mech = m
		slot = s
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		font = PixelUI.pixel_font()
		ejects.clear()
		_was_broken = float(m.parts.get(s, 1.0)) <= 0.0
		_was_od = m.overdrive_t > 0.0
		_was_reloading = float(m.reload_t.get(s, 0.0)) > 0.0
		var id: String = m.loadout.get(s, "")
		if id == "":
			mag = 0
			tex = null
			yoff.clear()
			visible = false
			queue_redraw()
			return
		var w := str(GameData.module(id).get("weapon", "mg"))
		if not GameData.weapon_uses_ammo(w):
			# 激光 / 近战工程臂不占弹匣，由能量条与技能槽反馈
			mag = 0
			tex = null
			yoff.clear()
			visible = false
			queue_redraw()
			return
		visible = true
		var a: Dictionary = GameData.AMMO.get(w, {})
		tex = load("res://assets/ui/%s.png" % str(a.get("tex", "ammo_mg")))
		mag = int(m.mag[s])
		bh = bw * float(tex.get_height()) / float(tex.get_width())
		yoff.clear()
		for i in int(m.ammo[s]):
			yoff.append(0.0)
		if not m.fired.is_connected(_on_fired):
			m.fired.connect(_on_fired)
		if not resized.is_connected(_layout):
			resized.connect(_layout)
		_layout()
		queue_redraw()

	func preferred_height(max_h := 224.0, min_h := 28.0) -> float:
		if not visible or tex == null or mag <= 0:
			return 0.0
		var nat_pitch := bh + 1.5
		var need := float(maxi(mag - 1, 0)) * nat_pitch + bh + 4.0
		return clampf(ceilf(need), min_h, max_h)

	func _gui_input(ev: InputEvent) -> void:
		if mech == null or mech.input_locked:
			return
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			mech.start_reload(slot)
			accept_event()

	func _layout() -> void:
		if mag <= 0:
			return
		var nat_pitch := bh + 1.5
		if mag == 1:
			pitch = nat_pitch
		else:
			pitch = clampf((size.y - 4.0 - bh) / float(mag - 1), 0.5, nat_pitch)

	func _on_fired(s: String) -> void:
		if s != slot or yoff.is_empty() or mech.overdrive_t > 0.0:
			return
		# 底部那颗退壳弹出，其余整列下滑一格
		yoff.pop_front()
		for i in yoff.size():
			yoff[i] += pitch
		ejects.append({"p": Vector2(size.x * 0.5, size.y - 2.0 - bh * 0.5), "v": Vector2(randf_range(90, 150), randf_range(-170, -110)), "r": 0.0, "rv": randf_range(8, 16), "life": 0.7})

	func _process(delta: float) -> void:
		if not is_instance_valid(mech) or tex == null or not visible:
			return
		var cur_mag: int = int(mech.mag[slot])
		var reloading: bool = mech.reload_t[slot] > 0.0
		var broken: bool = mech.parts[slot] <= 0.0
		var od: bool = mech.overdrive_t > 0.0
		var dirty: bool = reloading or reloading != _was_reloading or broken != _was_broken or od != _was_od
		_was_reloading = reloading
		_was_broken = broken
		_was_od = od
		if cur_mag != mag:
			mag = cur_mag
			_layout()
			dirty = true
		# 换弹：按进度把子弹逐颗补回，新子弹从弹槽顶端落下
		var want: int = int(mech.ammo[slot])
		if mech.reload_t[slot] > 0.0:
			want = int(round(float(mag) * (1.0 - mech.reload_frac(slot))))
		while yoff.size() < want:
			var i := yoff.size()
			yoff.append(maxf(0.0, size.y - 4.0 - bh - float(i) * pitch))
			dirty = true
		while yoff.size() > want and mech.reload_t[slot] <= 0.0:
			yoff.pop_back()
			dirty = true
		for i in yoff.size():
			var y: float = yoff[i]
			if y > 0.0:
				yoff[i] = move_toward(y, 0.0, maxf(700.0 * delta, y * 16.0 * delta))
				dirty = true
		dirty = dirty or not ejects.is_empty()
		for e in ejects:
			e.v.y += 900.0 * delta
			e.p += e.v * delta
			e.r += e.rv * delta
			e.life -= delta
		ejects = ejects.filter(func(e): return e.life > 0.0)
		if dirty: queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var x := (size.x - bw) * 0.5
		var od: bool = mech.overdrive_t > 0.0
		for i in yoff.size():
			var y: float = size.y - 2.0 - bh - float(i) * pitch - float(yoff[i])
			var mod := Color(1, 1, 1)
			if od:
				mod = Color(1.18, 0.92, 0.58)
			draw_texture_rect(tex, Rect2(x, y, bw, bh), false, mod)
		for e in ejects:
			draw_set_transform(e.p, e.r, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-bw * 0.5, -bh * 0.5, bw, bh), false, Color(1, 1, 1, clampf(e.life / 0.3, 0.0, 1.0)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if mech.parts[slot] <= 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.04, 0.03, 0.65))
			var pad := Vector2(minf(6.0, size.x * 0.2), minf(12.0, size.y * 0.22))
			draw_line(pad, size - pad, Color(0.80, 0.24, 0.18, 0.88), 2.0)
			draw_line(Vector2(size.x - pad.x, pad.y), Vector2(pad.x, size.y - pad.y), Color(0.80, 0.24, 0.18, 0.88), 2.0)
		elif mech.reload_t[slot] > 0.0:
			var prog := clampf(1.0 - mech.reload_frac(slot), 0.0, 1.0)
			var bh_r := (size.y - 4.0) * prog
			draw_rect(Rect2(Vector2(2, size.y - 2.0 - bh_r), Vector2(3.5, bh_r)), Color(0.84, 0.56, 0.20, 0.95))


# ====================================================================== 技能槽
class SkillSlot extends Control:
	var mech
	var key := "space"
	var cap_text := "SPACE"
	var icon: Texture2D
	var font: Font
	var ready_flash := 0.0
	var press_flash := 0.0
	var was_ready := true
	var _last_trig_ms := -1000

	func setup(m, k: String, label: String) -> void:
		mech = m
		key = k
		cap_text = label
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		font = PixelUI.pixel_font()
		var info: Dictionary = m.skill_info(k)
		icon = Icons.ui_icon(str(info.get("icon", "dash")))
		custom_minimum_size = Vector2(84, 96)

	func trigger() -> void:
		if mech == null or mech.input_locked or mech.dead:
			return
		var now := Time.get_ticks_msec()
		if now - _last_trig_ms < 80:
			return
		_last_trig_ms = now
		press_flash = 1.0
		match key:
			"space":
				mech.try_dash(mech.move_vec())
			"f":
				mech.try_ability()

	func _gui_input(ev: InputEvent) -> void:
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			trigger()
			accept_event()

	func _process(delta: float) -> void:
		ready_flash = max(0.0, ready_flash - delta * 2.0)
		press_flash = max(0.0, press_flash - delta * 5.0)
		queue_redraw()

	func _draw() -> void:
		var info: Dictionary = mech.skill_info(key)
		var s := 76.0
		var o := Vector2((size.x - s) * 0.5, 0.0)
		var box := Rect2(o, Vector2(s, s))
		var ready: bool = info.ok and info.cd <= 0.0 and mech.can_spend(info.cost)
		if ready and not was_ready:
			ready_flash = 1.0
		was_ready = ready
		var amber := Color(0.78, 0.48, 0.16)
		var amber_hi := Color(0.87, 0.59, 0.25)
		var steel_hi := Color(0.46, 0.49, 0.52)
		# 半透明废土工业凹槽（叠加在横轨背板上保持通透均匀，避免双层厚重黑块）
		var fill_c := Color(0.024, 0.028, 0.034, 0.34).lerp(amber_hi, press_flash * 0.28)
		draw_rect(box, fill_c)
		draw_line(o + Vector2(2, 2), o + Vector2(s - 2, 2), Color(steel_hi.r, steel_hi.g, steel_hi.b, 0.22), 1.0)
		var border_c := amber_hi if (info.active or press_flash > 0.05) else (Color(0.38, 0.41, 0.43, 0.82) if ready else Color(0.20, 0.22, 0.24, 0.76))
		draw_rect(box, border_c, false, 1.5)
		if ready or info.active:
			var a := 8.0
			var bc := Color(amber_hi.r, amber_hi.g, amber_hi.b, clampf(0.76 + ready_flash * 0.24, 0.0, 1.0))
			draw_line(o, o + Vector2(a, 0), bc, 2.0, true)
			draw_line(o, o + Vector2(0, a), bc, 2.0, true)
			draw_line(o + Vector2(s, 0), o + Vector2(s - a, 0), bc, 2.0, true)
			draw_line(o + Vector2(s, 0), o + Vector2(s, a), bc, 2.0, true)
			draw_line(o + Vector2(0, s), o + Vector2(a, s), bc, 2.0, true)
			draw_line(o + Vector2(0, s), o + Vector2(0, s - a), bc, 2.0, true)
			draw_line(o + Vector2(s, s), o + Vector2(s - a, s), bc, 2.0, true)
			draw_line(o + Vector2(s, s), o + Vector2(s, s - a), bc, 2.0, true)
		var ic := Color(0.86, 0.58, 0.24) if ready else Color(0.46, 0.49, 0.50)
		if not info.ok:
			ic = Color(0.30, 0.32, 0.34)
		if info.active:
			ic = Color(0.92, 0.91, 0.86)
		var isz := 42.0
		if icon != null:
			draw_texture_rect(icon, Rect2(o + Vector2((s - isz) * 0.5, (s - isz) * 0.5 - 2.0), Vector2(isz, isz)), false, ic)
		# 扇形冷却遮罩（12 点方向起顺时针退去）
		if info.cd > 0.0 and info.ok:
			var f: float = clampf(info.cd / maxf(info.cd_max, 0.01), 0.0, 1.0)
			var c := o + Vector2(s, s) * 0.5
			var pts := PackedVector2Array([c])
			var n := 28
			for i in n + 1:
				var a := -PI * 0.5 + TAU * (1.0 - f) + TAU * f * float(i) / float(n)
				var d := Vector2(cos(a), sin(a))
				var k: float = (s * 0.5 - 4.0) / maxf(absf(d.x), absf(d.y))
				pts.append(c + d * k)
			draw_colored_polygon(pts, Color(0.04, 0.045, 0.05, 0.78))
			var txt := "%.1f" % info.cd if info.cd < 10.0 else "%d" % int(info.cd)
			draw_string_outline(font, o + Vector2(0, s * 0.5 + 7), txt, HORIZONTAL_ALIGNMENT_CENTER, s, 12, 3, Color(0, 0, 0, 0.92))
			draw_string(font, o + Vector2(0, s * 0.5 + 7), txt, HORIZONTAL_ALIGNMENT_CENTER, s, 12, Color(0.90, 0.89, 0.84))
		# 工业灰黑阳极氧化金属冲压键帽（浅灰白丝印高对比）
		var text_w := font.get_string_size(cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var cw := clampf(text_w + 16.0, 28.0, s - 6.0)
		var ch := 18.0
		var cpos := Vector2((size.x - cw) * 0.5, s - 7.0)
		var crect := Rect2(cpos, Vector2(cw, ch))
		draw_rect(crect, Color(0.14, 0.16, 0.18, 0.78) if info.ok else Color(0.09, 0.10, 0.11, 0.74))
		draw_rect(crect, Color(0.40, 0.43, 0.46, 0.84) if info.ok else Color(0.24, 0.26, 0.28, 0.78), false, 1.0)
		draw_rect(Rect2(cpos.x, cpos.y + ch - 2.5, cw, 2.5), amber_hi if (ready or info.active) else Color(0.24, 0.26, 0.28, 0.80))
		draw_string(font, cpos + Vector2(0, 12.5), cap_text, HORIZONTAL_ALIGNMENT_CENTER, cw, 11, Color(0.88, 0.89, 0.86) if info.ok else Color(0.44, 0.46, 0.46))


# ====================================================================== 能源条（横轨底部刻槽里）
class EnergyStrip extends Control:
	var mech
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if mech == null:
			return
		var f: float = clampf(mech.energy / mech.max_energy, 0.0, 1.0)
		var n := int(size.x / 6.0)
		var a := 1.0
		if mech.emergency > 0.0 or mech.energy_seconds_left() < 45.0:
			a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		for i in n:
			var on := float(i) / float(n) < f
			draw_rect(Rect2(i * 6.0, 0, 4.0, size.y), Color(0.84, 0.56, 0.20, a) if on else Color(0.78, 0.80, 0.78, 0.08))


# ====================================================================== 货舱负重条（拐角底槽，纯图形）
class CargoStrip extends Control:
	var mech
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if mech == null:
			return
		var cap: float = maxf(mech.cargo_cap(), 1.0)
		var f: float = clampf(mech.cargo_weight() / cap, 0.0, 1.0)
		var n := maxi(1, int(size.x / 6.0))
		var over: bool = mech.speed_mult() < 0.99
		var a := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.015) if over else 1.0
		var col := Color(0.80, 0.24, 0.18, a) if over else (Color(0.84, 0.56, 0.22, a) if f > 0.75 else Color(0.56, 0.70, 0.62, a))
		for i in n:
			var on := float(i) / float(n) < f
			draw_rect(Rect2(i * 6.0, 0, 4.0, size.y), col if on else Color(0.78, 0.80, 0.78, 0.09))


# ====================================================================== 工业风双虚拟摇杆
class TouchStick extends Control:
	var title := "MOVE"
	var fire_mode := false       ## true = 右摇杆（三称推开超过阈值开火；一称按住即开火且支持拖移压枪）
	var fp_mode := false         ## true = 第一人称模式（按下即开火 + 拖移增量转动视角）
	var value := Vector2.ZERO    ## 归一化输出（模长 0..1）
	var touch_id := -1           ## >=0 多点触控 index；-2 鼠标拖拽；-1 空闲
	var outer_r := 116.0
	var knob_r := 48.0
	var deadzone := 0.10
	var fire_zone := 0.45
	var font: Font
	var _drag_delta := Vector2.ZERO
	var _last_pt := Vector2.ZERO
	var _touch_seen_ms := -10000

	func _init(lbl := "MOVE", is_fire := false) -> void:
		title = lbl
		fire_mode = is_fire
		custom_minimum_size = Vector2(268, 268)
		size = Vector2(268, 268)
		mouse_filter = Control.MOUSE_FILTER_STOP
		font = PixelUI.pixel_font()

	func is_active() -> bool:
		return touch_id != -1

	func is_firing() -> bool:
		if not fire_mode or not is_active():
			return false
		return true if fp_mode else value.length() >= fire_zone

	func consume_drag_delta() -> Vector2:
		var d := _drag_delta
		_drag_delta = Vector2.ZERO
		return d

	func release() -> void:
		touch_id = -1
		value = Vector2.ZERO
		_drag_delta = Vector2.ZERO
		queue_redraw()

	func _hit(global_pt: Vector2) -> bool:
		var c := get_global_rect().get_center()
		return global_pt.distance_to(c) <= outer_r + 12.0

	func _update_from_global(global_pt: Vector2) -> void:
		var c := get_global_rect().get_center()
		var d := global_pt - c
		var max_r := maxf(outer_r - knob_r * 0.45, 24.0)
		if d.length() > max_r:
			d = d.normalized() * max_r
		var raw := d / max_r
		value = raw if raw.length() >= deadzone else Vector2.ZERO
		queue_redraw()

	func _notification(what: int) -> void:
		if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
			if touch_id != -1:
				release()
		elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
			if touch_id != -1:
				release()

	func _process(_delta: float) -> void:
		if touch_id == -1:
			return
		if not is_visible_in_tree():
			release()
			return
		if touch_id == -2 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			release()

	func _input(ev: InputEvent) -> void:
		if not is_visible_in_tree():
			if touch_id != -1:
				release()
			return
		if ev is InputEventScreenTouch:
			if not ev.pressed or ev.canceled:
				if ev.index == touch_id or touch_id == -2:
					release()
				return
			if touch_id != -2:
				_touch_seen_ms = Time.get_ticks_msec()
			if touch_id == -1 and _hit(ev.position):
				touch_id = ev.index
				_last_pt = ev.position
				_drag_delta = Vector2.ZERO
				_update_from_global(ev.position)
				get_viewport().set_input_as_handled()
		elif ev is InputEventScreenDrag:
			if ev.index == touch_id:
				_touch_seen_ms = Time.get_ticks_msec()
				_drag_delta += ev.position - _last_pt
				_last_pt = ev.position
				_update_from_global(ev.position)
				get_viewport().set_input_as_handled()
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if not ev.pressed:
				if touch_id == -2:
					release()
				return
			if Time.get_ticks_msec() - _touch_seen_ms < 500:
				return
			if touch_id == -1 and _hit(ev.position):
				touch_id = -2
				_last_pt = ev.position
				_drag_delta = Vector2.ZERO
				_update_from_global(ev.position)
				get_viewport().set_input_as_handled()
		elif ev is InputEventMouseMotion:
			if touch_id == -2:
				if (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
					release()
					return
				_drag_delta += ev.position - _last_pt
				_last_pt = ev.position
				_update_from_global(ev.position)
				get_viewport().set_input_as_handled()

	func _draw() -> void:
		var c := size * 0.5
		var active := is_active()
		var firing := is_firing()
		var amber := Color(0.84, 0.40, 0.16) if firing else Color(0.78, 0.48, 0.16)
		var ring_a := 0.56 if active else 0.30
		# 半透明底盘 + 双层金属刻度环（不遮挡下方战场画面）
		draw_circle(c, outer_r + 5.0, Color(0.03, 0.035, 0.04, 0.28 if active else 0.16))
		draw_arc(c, outer_r + 2.5, 0, TAU, 64, Color(0.18, 0.19, 0.22, ring_a), 6.0)
		draw_arc(c, outer_r - 2.0, 0, TAU, 64, Color(amber.r, amber.g, amber.b, 0.52 if active else 0.26), 2.0)
		# 四角琥珀强化弧段
		for q in 4:
			var a0 := q * PI * 0.5 + 0.32
			draw_arc(c, outer_r + 2.5, a0, a0 + PI * 0.5 - 0.64, 14, Color(amber.r, amber.g, amber.b, 0.60 if active else 0.30), 3.6)
		# 刻度线与十字基准线
		for k in 16:
			var a := k * TAU / 16.0
			var d := Vector2(cos(a), sin(a))
			var major := k % 4 == 0
			draw_line(c + d * (outer_r - (11.0 if major else 5.5)), c + d * (outer_r + 1.5), Color(amber.r, amber.g, amber.b, 0.52 if major else 0.20), 2.2 if major else 1.2)
		# 内圈死区 / 开火阈值环
		if not (fire_mode and fp_mode):
			var inner_r := outer_r * (fire_zone if fire_mode else deadzone * 1.8)
			draw_arc(c, inner_r, 0, TAU, 44, Color(amber.r, amber.g, amber.b, 0.28 if firing else 0.14), 1.4)
		# 四向箭头导引
		for d: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
			var p: Vector2 = c + d * (outer_r - 22.0)
			var s := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([p + d * 8.0, p - d * 4.5 + s * 7.2, p - d * 4.5 - s * 7.2]), Color(amber.r, amber.g, amber.b, 0.48 if active else 0.24))
		# 摇杆推杆连线与半透明帽头
		var max_r := maxf(outer_r - knob_r * 0.45, 42.0)
		var kp := c if (fire_mode and fp_mode) else c + value * max_r
		if not (fire_mode and fp_mode) and value.length() > 0.02:
			draw_line(c, kp, Color(amber.r, amber.g, amber.b, 0.46), 4.0)
		var kr := knob_r * (1.16 if (fire_mode and fp_mode) else 1.0)
		draw_circle(kp + Vector2(0, 2.5), kr + 2.5, Color(0, 0, 0, 0.28 if active else 0.16))
		draw_circle(kp, kr, Color(0.18, 0.12, 0.09, 0.54) if firing else Color(0.14, 0.15, 0.17, 0.48 if active else 0.32))
		draw_arc(kp, kr, 0, TAU, 44, Color(amber.r, amber.g, amber.b, 0.78 if active else 0.46), 3.0)
		draw_circle(kp, kr * 0.42, Color(amber.r, amber.g, amber.b, 0.68 if active else 0.34))
		if fire_mode:
			for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(kp + dv * 6.8, kp + dv * (19.0 if fp_mode else 16.0), Color(0.94, 0.90, 0.84, 0.72 if active else 0.46), 2.4 if fp_mode else 2.0)


# ====================================================================== 战术触控圆钮（纯图标：冲刺 / 机能 / 换弹 / 瞄准 / 开火 / 视角）
class TouchBtn extends Control:
	var mech
	var hud
	var kind := "dash"           ## "dash" / "ability" / "reload" / "aim" / "fire" / "view"
	var press_t := 0.0
	var font: Font
	var _last_ms := -1000
	var _icon_id := ""
	var _icon: Texture2D
	var _hold_touch_id := -1
	var _touch_seen_ms := -10000

	func setup(m, k: String, _t: String, _s: String, rad := 29.0, h = null) -> void:
		mech = m
		hud = h
		kind = k
		custom_minimum_size = Vector2(rad * 2.0, rad * 2.0)
		size = Vector2(rad * 2.0, rad * 2.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		font = PixelUI.pixel_font()
		_icon_id = ""
		_icon = null

	func is_held() -> bool:
		return _hold_touch_id != -1

	func release() -> void:
		_hold_touch_id = -1
		queue_redraw()

	func _hit_pt(global_pt: Vector2) -> bool:
		var c := get_global_rect().get_center()
		var r := minf(size.x, size.y) * 0.5 + 4.0
		return global_pt.distance_to(c) <= r

	func _notification(what: int) -> void:
		if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
			if _hold_touch_id != -1:
				release()
		elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
			if _hold_touch_id != -1:
				release()

	func _sync_icon(icon_name: String) -> void:
		if _icon_id == icon_name:
			return
		_icon_id = icon_name
		_icon = Icons.ui_icon(icon_name) if icon_name != "" else null

	func _trigger() -> void:
		if mech == null or mech.input_locked or mech.dead:
			return
		var now := Time.get_ticks_msec()
		if now - _last_ms < 80:
			return
		_last_ms = now
		press_t = 1.0
		match kind:
			"dash":
				if hud != null and hud.has_method("clear_touch_aim"):
					hud.clear_touch_aim()
				mech.try_dash(mech.move_vec())
			"ability":
				mech.try_ability()
			"reload":
				mech.reload_all()
			"aim":
				if hud != null and hud.has_method("toggle_touch_aim"):
					hud.toggle_touch_aim()
			"view":
				if mech.raid != null and mech.raid.has_method("toggle_view_mode"):
					mech.raid.toggle_view_mode()

	func _input(ev: InputEvent) -> void:
		if not is_visible_in_tree():
			if _hold_touch_id != -1:
				release()
			return
		if kind != "fire":
			if ev is InputEventScreenTouch and ev.pressed and not ev.canceled and _hit_pt(ev.position):
				_touch_seen_ms = Time.get_ticks_msec()
				_trigger()
				get_viewport().set_input_as_handled()
			return
		if ev is InputEventScreenTouch:
			if not ev.pressed or ev.canceled:
				if ev.index == _hold_touch_id or _hold_touch_id == -2:
					release()
				return
			if _hold_touch_id != -2:
				_touch_seen_ms = Time.get_ticks_msec()
			if _hold_touch_id == -1 and _hit_pt(ev.position):
				_hold_touch_id = ev.index
				press_t = 1.0
				get_viewport().set_input_as_handled()
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if not ev.pressed:
				if _hold_touch_id == -2:
					release()
				return
			if Time.get_ticks_msec() - _touch_seen_ms < 500:
				return
			if _hold_touch_id == -1 and _hit_pt(ev.position):
				_hold_touch_id = -2
				press_t = 1.0
				get_viewport().set_input_as_handled()

	func _gui_input(ev: InputEvent) -> void:
		if kind == "fire":
			return
		if ev is InputEventScreenTouch:
			if ev.pressed and not ev.canceled:
				_touch_seen_ms = Time.get_ticks_msec()
				_trigger()
				accept_event()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if Time.get_ticks_msec() - _touch_seen_ms < 500:
				return
			_trigger()
			accept_event()

	func _process(delta: float) -> void:
		if _hold_touch_id == -2 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			release()
		press_t = maxf(0.0, press_t - delta * 5.0)
		queue_redraw()

	func _draw() -> void:
		if mech == null:
			return
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var cd_frac := 0.0
		var ok := true
		var active_state := false
		if kind in ["dash", "ability"]:
			var sk_k := "space" if kind == "dash" else "f"
			var info: Dictionary = mech.skill_info(sk_k)
			_sync_icon(str(info.icon))
			ok = bool(info.ok) and mech.can_spend(float(info.cost))
			if float(info.cd) > 0.0 and bool(info.ok):
				cd_frac = clampf(float(info.cd) / maxf(float(info.cd_max), 0.01), 0.0, 1.0)
		elif kind == "reload":
			cd_frac = maxf(mech.reload_frac("arm_l"), mech.reload_frac("arm_r"))
		elif kind == "aim":
			active_state = hud != null and bool(hud.get("touch_aim_on"))
		elif kind == "fire":
			active_state = is_held()
		elif kind == "view":
			active_state = mech.raid != null and mech.raid.has_method("is_first_person") and mech.raid.is_first_person()
		var boost := maxf(press_t, 1.0 if active_state else 0.0)
		var amber := Color(0.92, 0.52, 0.16) if active_state else (Color(0.78, 0.48, 0.16) if ok else Color(0.42, 0.44, 0.46))
		draw_circle(c + Vector2(0, 2), r + 1.0, Color(0, 0, 0, lerpf(0.16, 0.30, boost)))
		var bg_col := Color(0.085, 0.092, 0.098).lerp(amber, 0.24 if active_state else press_t * 0.42)
		draw_circle(c, r, Color(bg_col.r, bg_col.g, bg_col.b, lerpf(0.26, 0.46, boost)))
		var border_a := lerpf(0.42 if cd_frac <= 0.0 else 0.22, 0.72, boost)
		draw_arc(c, r, 0, TAU, 44, Color(amber.r, amber.g, amber.b, border_a), 2.6 if active_state else 2.2, true)
		if cd_frac > 0.0:
			draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cd_frac), 32, Color(0.84, 0.56, 0.22, 0.56), 3.0, true)
		var icon_a := lerpf(0.50 if ok else 0.26, 0.80, boost)
		var ic := Color(0.94, 0.92, 0.86, icon_a) if ok else Color(0.45, 0.45, 0.48, icon_a)
		if kind in ["dash", "ability"] and _icon != null:
			var isz := Vector2(r * 1.1, r * 1.1)
			var tex_c := Color(0.90, 0.90, 0.86, icon_a) if ok else Color(0.45, 0.45, 0.48, icon_a)
			draw_texture_rect(_icon, Rect2(c - isz * 0.5, isz), false, tex_c)
		elif kind == "reload":
			var rr := r * 0.46
			draw_arc(c, rr, -0.4, TAU - 1.15, 24, ic, 2.4)
			var tip := c + Vector2(cos(-0.4), sin(-0.4)) * rr
			draw_colored_polygon(PackedVector2Array([tip + Vector2(2.5, 4.8), tip + Vector2(4.8, -3.5), tip + Vector2(-4.8, -1.2)]), ic)
		elif kind == "aim":
			var rr := r * 0.44
			draw_arc(c, rr, 0, TAU, 28, ic, 2.0, true)
			for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + dv * (rr * 0.45), c + dv * (rr * 1.38), ic, 2.0)
			draw_circle(c, 2.6, Color(amber.r, amber.g, amber.b, icon_a) if active_state else ic)
		elif kind == "fire":
			var rr := r * 0.42
			draw_arc(c, rr, 0, TAU, 28, ic, 2.2, true)
			for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + dv * (rr * 0.35), c + dv * (rr * 1.32), ic, 2.2)
			draw_circle(c, 3.6, Color(amber.r, amber.g, amber.b, icon_a))
		elif kind == "view":
			var ew := r * 0.54
			var eh := r * 0.32
			draw_arc(c + Vector2(0, eh * 0.25), ew, -PI * 0.85, -PI * 0.15, 18, ic, 2.0, true)
			draw_arc(c - Vector2(0, eh * 0.25), ew, PI * 0.15, PI * 0.85, 18, ic, 2.0, true)
			draw_circle(c, r * 0.18, Color(amber.r, amber.g, amber.b, icon_a) if active_state else ic)
