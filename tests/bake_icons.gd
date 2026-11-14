extends "res://tests/lib/test_base.gd"
## Runs the offline 3D item icon baker (non-headless Vulkan only) and emits contact sheets.
const START := "none"
const TIMEOUT := 240.0
const Baker = preload("res://tools/bake_icons.gd")


func run() -> void:
	if headless():
		log_line("skip bake_icons in headless")
		return
	var res: Dictionary = await Baker.bake_all(self, func(msg: String): log_line(msg))
	if not bool(res.get("ok", false)):
		fail(str(res.get("error", "unknown bake error")))
		return
	var mod_ids: Array[String] = res["module_ids"]
	var item_ids: Array[String] = res["item_ids"]
	var images: Dictionary = res["images"]
	var err1: Error = await Baker.render_contact_sheet(self, mod_ids, images, "res://review/bake_sheet_modules.png", 8)
	if not check(err1 == OK, "Failed writing bake_sheet_modules.png (%d)" % err1):
		return
	var err2: Error = await Baker.render_contact_sheet(self, item_ids, images, "res://review/bake_sheet_items.png", 8)
	if not check(err2 == OK, "Failed writing bake_sheet_items.png (%d)" % err2):
		return
	log_line("Baked %d items (%d modules, %d items) + contact sheets OK" % [int(res["count"]), mod_ids.size(), item_ids.size()])
