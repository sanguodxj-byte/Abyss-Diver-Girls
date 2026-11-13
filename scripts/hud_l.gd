extends RefCounted
## 左下角 L 形状态栏与触控双摇杆部件：
##   HoloPortrait    —— 拐角：机甲正视图全息投影，部位按完好度着色（浅蓝→黄→橙→红→缺失）
##   AmmoColumn      —— 竖线：子弹贴图逐颗堆叠，开一枪弹壳弹出、整列向下滑一格；换弹时子弹从顶端逐颗落下（点击可手动换弹）
##   SkillSlot       —— 横线：Space / F 技能槽（贴图槽位 + 图标 + 扇形冷却 + 键帽，支持触控点击）
##   TouchStick      —— 虚拟摇杆：左摇杆移动、右摇杆瞄准/射击（支持多点触控与鼠标拖拽）
##   TouchBtn        —— 战术触控圆钮：冲刺 / 机能 / 换弹快捷触控键

const MV = preload("res://scripts/mech_visual.gd")

static func part_color(f: float) -> Color:
	return _pc(f)


static func _pc(f: float) -> Color:
	if f > 0.75:
		return Color(0.55, 0.86, 1.0)
	if f > 0.5:
		return Color(0.74, 0.62, 0.2)
	if f > 0.25:
		return Color(1.0, 0.55, 0.15)
	return Color(1.0, 0.2, 0.14)


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
uniform vec3 col = vec3(0.55, 0.86, 1.0);
uniform float flash = 0.0;
void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float band = 0.82 + 0.18 * step(0.5, fract(FRAGCOORD.y * 0.25));
	vec3 c = col * (0.34 + fr * 1.2) * band;
	ALBEDO = mix(c, vec3(1.0), flash * 0.7);
}
"""
	const POST := """
shader_type canvas_item;
uniform vec3 tint = vec3(1.0);
void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float jitter = step(0.985, fract(sin(floor(t * 14.0)) * 43758.5)) * 0.006;
	uv.x += jitter * sin(uv.y * 60.0);
	vec4 c = texture(TEXTURE, uv);
	float r = texture(TEXTURE, uv + vec2(0.003, 0.0)).r;
	c.r = max(c.r, r * 0.8);
	float scan = 0.75 + 0.25 * sin((uv.y * 170.0 - t * 6.0));
	float roll = smoothstep(0.0, 0.08, abs(fract(uv.y - t * 0.25) - 0.5));
	float flick = 0.92 + 0.08 * sin(t * 37.0);
	c.rgb *= scan * flick * (0.85 + 0.15 * roll);
	c.a *= 0.95;
	COLOR = c;
}
"""

	func _on_resized() -> void:
		if vp != null and is_instance_valid(vp):
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
		vp.msaa_3d = Viewport.MSAA_2X
		vp.size = Vector2i(maxi(int(round(size.x)), 64), maxi(int(round(size.y)), 64))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		if not resized.is_connected(_on_resized):
			resized.connect(_on_resized)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		vp.add_child(env)
		model = MV.build(m.loadout, false)
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
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 4.1
		cam.position = Vector3(0, 1.95, -12)
		cam.rotation_degrees = Vector3(0, 180, 0)
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
			return Color(0.55, 0.86, 1.0)
		if f > 0.5:
			return Color(0.74, 0.62, 0.2)
		if f > 0.25:
			return Color(1.0, 0.55, 0.15)
		return Color(1.0, 0.2, 0.14)

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
		model.rotation.y = sin(t * 0.6) * 0.12
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

	func setup(m, s: String) -> void:
		mech = m
		slot = s
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		font = PixelUI.pixel_font()
		var id: String = m.loadout.get(s, "")
		if id == "":
			return
		var a: Dictionary = GameData.AMMO[GameData.module(id).weapon]
		tex = load("res://assets/ui/%s.png" % a.tex)
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

	func _gui_input(ev: InputEvent) -> void:
		if mech == null or mech.input_locked:
			return
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			mech.start_reload(slot)
			accept_event()

	func _layout() -> void:
		if mag <= 0:
			return
		pitch = minf(bh + 1.5, (size.y - 4.0) / float(mag))

	func _on_fired(s: String) -> void:
		if s != slot or yoff.is_empty():
			return
		# 底部那颗退壳弹出，其余整列下滑一格
		yoff.pop_front()
		for i in yoff.size():
			yoff[i] += pitch
		ejects.append({"p": Vector2(size.x * 0.5, size.y - bh * 0.5), "v": Vector2(randf_range(90, 150), randf_range(-170, -110)), "r": 0.0, "rv": randf_range(8, 16), "life": 0.7})

	func _process(delta: float) -> void:
		if mech == null or tex == null:
			return
		# 换弹：按进度把子弹逐颗补回，新子弹从弹槽顶端落下
		var want: int = int(mech.ammo[slot])
		if mech.reload_t[slot] > 0.0:
			want = int(round(float(mag) * (1.0 - mech.reload_frac(slot))))
		while yoff.size() < want:
			var i := yoff.size()
			yoff.append(size.y - (i + 1) * pitch)
		while yoff.size() > want and mech.reload_t[slot] <= 0.0:
			yoff.pop_back()
		for i in yoff.size():
			var y: float = yoff[i]
			if y > 0.0:
				yoff[i] = move_toward(y, 0.0, maxf(700.0 * delta, y * 16.0 * delta))
		for e in ejects:
			e.v.y += 900.0 * delta
			e.p += e.v * delta
			e.r += e.rv * delta
			e.life -= delta
		ejects = ejects.filter(func(e): return e.life > 0.0)
		queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var x := (size.x - bw) * 0.5
		var od: bool = mech.overdrive_t > 0.0
		for i in yoff.size():
			var y: float = size.y - (i + 1) * pitch - float(yoff[i]) + (pitch - bh) * 0.5
			var mod := Color(1, 1, 1)
			if od:
				mod = Color(1.3, 1.1, 0.6)
			draw_texture_rect(tex, Rect2(x, y, bw, bh), false, mod)
		for e in ejects:
			draw_set_transform(e.p, e.r, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-bw * 0.5, -bh * 0.5, bw, bh), false, Color(1, 1, 1, clampf(e.life / 0.3, 0.0, 1.0)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if mech.parts[slot] <= 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.03, 0.02, 0.62))
			var pad := Vector2(6, 12)
			draw_line(pad, size - pad, Color(1.0, 0.25, 0.18, 0.85), 2.0)
			draw_line(Vector2(size.x - pad.x, pad.y), Vector2(pad.x, size.y - pad.y), Color(1.0, 0.25, 0.18, 0.85), 2.0)
		elif mech.reload_t[slot] > 0.0:
			var prog := clampf(1.0 - mech.reload_frac(slot), 0.0, 1.0)
			var bh_r := (size.y - 4.0) * prog
			draw_rect(Rect2(Vector2(2, size.y - 2.0 - bh_r), Vector2(2.5, bh_r)), Color(0.95, 0.72, 0.22, 0.88))


# ====================================================================== 技能槽
class SkillSlot extends Control:
	var mech
	var key := "space"
	var cap_text := "SPACE"
	var icon: Texture2D
	var t_slot: Texture2D
	var t_ready: Texture2D
	var t_cap: Texture2D
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
		font = PixelUI.pixel_font()
		t_slot = load("res://assets/ui/slot.png")
		t_ready = load("res://assets/ui/slot_ready.png")
		t_cap = load("res://assets/ui/%s.png" % ("cap_wide" if label.length() > 1 else "cap"))
		var info: Dictionary = m.skill_info(k)
		icon = load("res://assets/ui/ic_%s.png" % info.icon)
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
		var o := Vector2((size.x - s) * 0.5, 0)
		draw_texture_rect(t_slot, Rect2(o, Vector2(s, s)), false)
		var ready: bool = info.ok and info.cd <= 0.0 and mech.can_spend(info.cost)
		if ready and not was_ready:
			ready_flash = 1.0
		was_ready = ready
		var ic := Color(0.74, 0.53, 0.11) if ready else Color(0.5, 0.5, 0.52)
		if not info.ok:
			ic = Color(0.3, 0.3, 0.32)
		if info.active:
			ic = Color(0.76, 0.68, 0.4)
		var isz := 42.0
		draw_texture_rect(icon, Rect2(o + Vector2((s - isz) * 0.5, (s - isz) * 0.5 - 2), Vector2(isz, isz)), false, ic)
		# 扇形冷却遮罩（12 点方向起顺时针退去）
		if info.cd > 0.0 and info.ok:
			var f: float = clampf(info.cd / maxf(info.cd_max, 0.01), 0.0, 1.0)
			var c := o + Vector2(s, s) * 0.5
			var pts := PackedVector2Array([c])
			var n := 28
			for i in n + 1:
				var a := -PI * 0.5 + TAU * (1.0 - f) + TAU * f * float(i) / float(n)
				var d := Vector2(cos(a), sin(a))
				var k: float = (s * 0.5 - 7.0) / maxf(absf(d.x), absf(d.y))
				pts.append(c + d * k)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
			var txt := "%.1f" % info.cd if info.cd < 10.0 else "%d" % int(info.cd)
			draw_string_outline(font, o + Vector2(0, s * 0.5 + 7), txt, HORIZONTAL_ALIGNMENT_CENTER, s, 12, 4, Color(0, 0, 0, 0.9))
			draw_string(font, o + Vector2(0, s * 0.5 + 7), txt, HORIZONTAL_ALIGNMENT_CENTER, s, 12, Color(1, 0.92, 0.75))
		if ready or info.active or press_flash > 0.0:
			draw_texture_rect(t_ready, Rect2(o, Vector2(s, s)), false, Color(1, 1, 1, clampf(0.35 + ready_flash * 0.65 + press_flash * 0.5, 0.0, 1.0)))
		# 键帽
		var cw: float = float(t_cap.get_width())
		var cpos := Vector2((size.x - cw) * 0.5, s - 8)
		draw_texture(t_cap, cpos)
		draw_string(font, cpos + Vector2(0, 14), cap_text, HORIZONTAL_ALIGNMENT_CENTER, cw, 12, Color(1, 1, 1))


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
			draw_rect(Rect2(i * 6.0, 0, 4.0, size.y), Color(0.74, 0.53, 0.11, a) if on else Color(1, 1, 1, 0.06))


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
		var col := Color(1.0, 0.30, 0.20, a) if over else (Color(0.86, 0.62, 0.18, a) if f > 0.75 else Color(0.46, 0.78, 0.64, a))
		for i in n:
			var on := float(i) / float(n) < f
			draw_rect(Rect2(i * 6.0, 0, 4.0, size.y), col if on else Color(1, 1, 1, 0.08))


# ====================================================================== 工业风双虚拟摇杆
class TouchStick extends Control:
	var title := "MOVE"
	var fire_mode := false       ## true = 右摇杆（推开超过阈值时亮起开火琥珀/橙红圈）
	var value := Vector2.ZERO    ## 归一化输出（模长 0..1）
	var touch_id := -1           ## >=0 多点触控 index；-2 鼠标拖拽；-1 空闲
	var outer_r := 64.0
	var knob_r := 25.0
	var deadzone := 0.12
	var fire_zone := 0.28
	var font: Font

	func _init(lbl := "MOVE", is_fire := false) -> void:
		title = lbl
		fire_mode = is_fire
		custom_minimum_size = Vector2(156, 156)
		size = Vector2(156, 156)
		mouse_filter = Control.MOUSE_FILTER_STOP
		font = PixelUI.pixel_font()

	func is_active() -> bool:
		return touch_id != -1

	func release() -> void:
		touch_id = -1
		value = Vector2.ZERO
		queue_redraw()

	func _hit(global_pt: Vector2) -> bool:
		var c := get_global_rect().get_center()
		return global_pt.distance_to(c) <= outer_r + 20.0

	func _update_from_global(global_pt: Vector2) -> void:
		var c := get_global_rect().get_center()
		var d := global_pt - c
		var max_r := maxf(outer_r - knob_r * 0.45, 24.0)
		if d.length() > max_r:
			d = d.normalized() * max_r
		var raw := d / max_r
		value = raw if raw.length() >= deadzone else Vector2.ZERO
		queue_redraw()

	func _input(ev: InputEvent) -> void:
		if not is_visible_in_tree():
			if touch_id != -1:
				release()
			return
		if ev is InputEventScreenTouch:
			if ev.pressed:
				if touch_id == -1 and _hit(ev.position):
					touch_id = ev.index
					_update_from_global(ev.position)
					get_viewport().set_input_as_handled()
			elif ev.index == touch_id:
				release()
				get_viewport().set_input_as_handled()
		elif ev is InputEventScreenDrag:
			if ev.index == touch_id:
				_update_from_global(ev.position)
				get_viewport().set_input_as_handled()
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if touch_id == -1 and _hit(ev.position):
					touch_id = -2
					_update_from_global(ev.position)
					get_viewport().set_input_as_handled()
			elif touch_id == -2:
				release()
				get_viewport().set_input_as_handled()
		elif ev is InputEventMouseMotion:
			if touch_id == -2:
				_update_from_global(ev.position)
				get_viewport().set_input_as_handled()

	func _draw() -> void:
		var c := size * 0.5
		var active := is_active()
		var firing := fire_mode and value.length() >= fire_zone
		var amber := Color(0.95, 0.42, 0.16) if firing else Color(0.76, 0.54, 0.12)
		var ring_a := 0.88 if active else 0.58
		# 装甲暗底盘 + 双层金属刻度环
		draw_circle(c, outer_r + 4.0, Color(0.03, 0.035, 0.04, 0.58 if active else 0.42))
		draw_arc(c, outer_r + 2.0, 0, TAU, 56, Color(0.18, 0.19, 0.22, ring_a), 5.0)
		draw_arc(c, outer_r - 1.5, 0, TAU, 56, Color(amber.r, amber.g, amber.b, 0.65 if active else 0.35), 1.6)
		# 四角琥珀强化弧段
		for q in 4:
			var a0 := q * PI * 0.5 + 0.32
			draw_arc(c, outer_r + 2.0, a0, a0 + PI * 0.5 - 0.64, 12, Color(amber.r, amber.g, amber.b, 0.72 if active else 0.4), 3.0)
		# 刻度线与十字基准线
		for k in 16:
			var a := k * TAU / 16.0
			var d := Vector2(cos(a), sin(a))
			var major := k % 4 == 0
			draw_line(c + d * (outer_r - (8.0 if major else 4.0)), c + d * (outer_r + 1.0), Color(amber.r, amber.g, amber.b, 0.68 if major else 0.28), 2.0 if major else 1.0)
		# 内圈死区 / 开火阈值环
		var inner_r := outer_r * (fire_zone if fire_mode else deadzone * 1.8)
		draw_arc(c, inner_r, 0, TAU, 36, Color(amber.r, amber.g, amber.b, 0.36 if firing else 0.18), 1.2)
		# 四向箭头导引
		for d: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
			var p: Vector2 = c + d * (outer_r - 13.0)
			var s := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([p + d * 4.5, p - d * 2.5 + s * 4.0, p - d * 2.5 - s * 4.0]), Color(amber.r, amber.g, amber.b, 0.55 if active else 0.32))
		# 摇杆推杆连线与帽头
		var max_r := maxf(outer_r - knob_r * 0.45, 24.0)
		var kp := c + value * max_r
		if value.length() > 0.02:
			draw_line(c, kp, Color(amber.r, amber.g, amber.b, 0.55), 3.0)
		draw_circle(kp + Vector2(0, 2), knob_r + 2.0, Color(0, 0, 0, 0.55))
		draw_circle(kp, knob_r, Color(0.14, 0.15, 0.17, 0.94))
		draw_arc(kp, knob_r, 0, TAU, 32, Color(amber.r, amber.g, amber.b, 0.95 if active else 0.68), 2.4)
		draw_circle(kp, knob_r * 0.42, Color(amber.r, amber.g, amber.b, 0.85 if active else 0.45))
		if fire_mode:
			# 右摇杆准星小十字
			for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(kp + dv * 4.0, kp + dv * 9.0, Color(1, 0.95, 0.85, 0.85), 1.5)


# ====================================================================== 战术触控圆钮（纯图标：冲刺 / 机能 / 换弹）
class TouchBtn extends Control:
	var mech
	var kind := "dash"           ## "dash" / "ability" / "reload"
	var press_t := 0.0
	var font: Font
	var _last_ms := -1000
	var _icon_id := ""
	var _icon: Texture2D

	func setup(m, k: String, _t: String, _s: String, rad := 29.0) -> void:
		mech = m
		kind = k
		custom_minimum_size = Vector2(rad * 2.0, rad * 2.0)
		size = Vector2(rad * 2.0, rad * 2.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		font = PixelUI.pixel_font()
		_icon_id = ""
		_icon = null

	func _sync_icon(icon_name: String) -> void:
		if _icon_id == icon_name:
			return
		_icon_id = icon_name
		_icon = load("res://assets/ui/ic_%s.png" % icon_name) if icon_name != "" else null

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
				mech.try_dash(mech.move_vec())
			"ability":
				mech.try_ability()
			"reload":
				mech.reload_all()

	func _gui_input(ev: InputEvent) -> void:
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			_trigger()
			accept_event()

	func _process(delta: float) -> void:
		press_t = maxf(0.0, press_t - delta * 5.0)
		queue_redraw()

	func _draw() -> void:
		if mech == null:
			return
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var cd_frac := 0.0
		var ok := true
		if kind in ["dash", "ability"]:
			var sk_k := "space" if kind == "dash" else "f"
			var info: Dictionary = mech.skill_info(sk_k)
			_sync_icon(str(info.icon))
			ok = bool(info.ok) and mech.can_spend(float(info.cost))
			if float(info.cd) > 0.0 and bool(info.ok):
				cd_frac = clampf(float(info.cd) / maxf(float(info.cd_max), 0.01), 0.0, 1.0)
		elif kind == "reload":
			cd_frac = maxf(mech.reload_frac("arm_l"), mech.reload_frac("arm_r"))
		var amber := Color(0.76, 0.54, 0.12) if ok else Color(0.42, 0.42, 0.45)
		draw_circle(c + Vector2(0, 2), r + 1.0, Color(0, 0, 0, 0.55))
		draw_circle(c, r, Color(0.09, 0.1, 0.12, 0.86).lerp(amber, press_t * 0.45))
		draw_arc(c, r, 0, TAU, 36, Color(amber.r, amber.g, amber.b, 0.85 if cd_frac <= 0.0 else 0.35), 2.2)
		if cd_frac > 0.0:
			draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cd_frac), 28, Color(0.95, 0.72, 0.22, 0.9), 3.0)
		if kind in ["dash", "ability"] and _icon != null:
			var isz := Vector2(r * 1.1, r * 1.1)
			draw_texture_rect(_icon, Rect2(c - isz * 0.5, isz), false, Color(0.96, 0.93, 0.86) if ok else Color(0.45, 0.45, 0.48))
		elif kind == "reload":
			var rr := r * 0.46
			var ic := Color(0.96, 0.93, 0.86, 0.92)
			draw_arc(c, rr, -0.4, TAU - 1.15, 20, ic, 2.2)
			var tip := c + Vector2(cos(-0.4), sin(-0.4)) * rr
			draw_colored_polygon(PackedVector2Array([tip + Vector2(2, 4), tip + Vector2(4, -3), tip + Vector2(-4, -1)]), ic)
