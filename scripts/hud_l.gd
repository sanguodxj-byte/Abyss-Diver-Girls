extends RefCounted
## 左下角 L 形状态栏的三个部件：
##   HoloPortrait —— 拐角：机甲正视图全息投影，部位按完好度着色（浅蓝→黄→橙→红→缺失）
##   AmmoColumn  —— 竖线：子弹贴图逐颗堆叠，开一枪弹壳弹出、整列向下滑一格；换弹时子弹从顶端逐颗落下
##   SkillSlot   —— 横线：Space / F / E / R 技能槽（贴图槽位 + 图标 + 扇形冷却 + 键帽）

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

	func setup(m) -> void:
		mech = m
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pm := ShaderMaterial.new()
		var ps := Shader.new()
		ps.code = POST
		pm.shader = ps
		material = pm
		vp = SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
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
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 4.3
		cam.position = Vector3(0, 2.0, -12)
		cam.rotation_degrees = Vector3(0, 180, 0)
		vp.add_child(cam)
		cam.current = true

	func _assign(n: Node, slot: String) -> void:
		var s := slot
		if n.has_meta("slot") and n.get_meta("slot") in mats:
			s = n.get_meta("slot")
		if n is MeshInstance3D:
			n.material_override = mats[s]
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			meshes[s].append(n)
		elif n is Light3D or n is GPUParticles3D or n is CPUParticles3D or n is Decal:
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
		model.rotation.y = sin(t * 0.6) * 0.12
		for slot in mats:
			var f := part_frac(slot)
			var band := 4 if f > 0.75 else (3 if f > 0.5 else (2 if f > 0.25 else (1 if f > 0.0 else 0)))
			if shown.get(slot, 4) != band:
				shown[slot] = band
				flash[slot] = 1.0
				for mi in meshes[slot]:
					mi.visible = band > 0
			flash[slot] = max(0.0, flash[slot] - delta * 2.5)
			var c := _col(f)
			if band == 1:
				c = c * (0.65 + 0.35 * sin(t * 12.0))   # 红色档闪烁告警
			mats[slot].set_shader_parameter("col", Vector3(c.r, c.g, c.b))
			mats[slot].set_shader_parameter("flash", flash[slot])


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
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		font = ThemeDB.fallback_font
		var id: String = m.loadout.get(s, "")
		if id == "":
			return
		var a: Dictionary = GameData.AMMO[GameData.module(id).weapon]
		tex = load("res://assets/ui/%s.png" % a.tex)
		mag = int(m.mag[s])
		bh = bw * float(tex.get_height()) / float(tex.get_width())
		for i in int(m.ammo[s]):
			yoff.append(0.0)
		m.fired.connect(_on_fired)
		m.reloaded.connect(func(k): pass)
		resized.connect(_layout)
		_layout()

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
			draw_string(font, Vector2(4, size.y * 0.5), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.3))
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
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
			_vtext("损毁", Color(1.0, 0.3, 0.2))
		elif mech.reload_t[slot] > 0.0 and int(Time.get_ticks_msec() / 250) % 2 == 0:
			_vtext("装填", Color(0.74, 0.55, 0.14))

	func _vtext(s: String, c: Color) -> void:
		for i in s.length():
			draw_string(font, Vector2(size.x * 0.5 - 7, size.y * 0.35 + i * 18), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)


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
	var was_ready := true

	func setup(m, k: String, label: String) -> void:
		mech = m
		key = k
		cap_text = label
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		font = ThemeDB.fallback_font
		t_slot = load("res://assets/ui/slot.png")
		t_ready = load("res://assets/ui/slot_ready.png")
		t_cap = load("res://assets/ui/%s.png" % ("cap_wide" if label.length() > 1 else "cap"))
		var info: Dictionary = m.skill_info(k)
		icon = load("res://assets/ui/ic_%s.png" % info.icon)
		custom_minimum_size = Vector2(84, 96)

	func _process(delta: float) -> void:
		ready_flash = max(0.0, ready_flash - delta * 2.0)
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
		if ready or info.active:
			draw_texture_rect(t_ready, Rect2(o, Vector2(s, s)), false, Color(1, 1, 1, 0.35 + ready_flash * 0.65))
		# 键帽
		var cw: float = float(t_cap.get_width())
		var cpos := Vector2((size.x - cw) * 0.5, s - 8)
		draw_texture(t_cap, cpos)
		draw_string(font, cpos + Vector2(0, 14), cap_text, HORIZONTAL_ALIGNMENT_CENTER, cw, 12, Color(1, 1, 1))
		# 技能名（槽位上方）
		draw_string_outline(font, Vector2(0, -6), info.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0, -6), info.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(0.88, 0.88, 0.88) if info.ok else Color(0.45, 0.45, 0.45))


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
