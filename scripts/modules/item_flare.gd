extends RefCounted
## 撤离引导烟幕：在撤离区里点起一柱橙色烟，把读条时间压短。
## 同一个撤离点只能引导一次；站在区外使用不会消耗。

const A = preload("res://scripts/art.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")

const SMOKE := Color(1.0, 0.62, 0.24)


static func use(mech, _id) -> bool:
	var raid = mech.raid
	if raid == null or not is_instance_valid(raid):
		return false
	var zone = raid.extract_target
	if zone == null or not is_instance_valid(zone):
		mech.message.emit("不在撤离区内")
		Audio.play_sfx("use_denied")
		return false
	if zone.has_meta("flare_used"):
		mech.message.emit("这个撤离点已经引导过了")
		Audio.play_sfx("use_denied")
		return false
	zone.set_meta("flare_used", true)
	var before := float(zone.need)
	zone.need = maxf(1.5, before * 0.55)
	var tree: SceneTree = raid.get_tree()
	var e = A.emitter(zone, Vector3(0, 0.4, 0), {"amount": 42, "life": 2.6, "size": 2.4, "tex": A.smoke_tex(), "additive": false, "dir": Vector3.UP, "spread": 22.0,
		"vmin": 2.2, "vmax": 4.5, "gravity": Vector3(0, 0.6, 0), "box": Vector3(0.6, 0.1, 0.6),
		"c0": Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.75), "c1": Color(0.8, 0.45, 0.2, 0.0), "grow0": 0.4, "grow1": 2.4})
	FX.light(raid, zone.global_position + Vector3(0, 1.2, 0), SMOKE, 3.5, 9.0, 0.6)
	FX.ring(raid, zone.global_position, SMOKE, zone.radius, 0.6)
	var eid: int = e.get_instance_id()
	tree.create_timer(7.0).timeout.connect(func():
		var o = instance_from_id(eid)
		if o != null:
			o.emitting = false
		tree.create_timer(2.8).timeout.connect(func():
			var o2 = instance_from_id(eid)
			if o2 != null:
				o2.queue_free()))
	mech.message.emit("%s：撤离读条 %.1f 到 %.1f 秒" % [zone.title, before, zone.need])
	Audio.play_sfx("flare_ignite", zone.global_position)
	return true
