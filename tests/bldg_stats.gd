extends "res://tests/lib/test_base.gd"
## 建筑密度统计：godot --headless --path . -- --bldg_stats
## 逐个地表战区打印布局建筑数（按区块字符）与街块覆盖率（建筑占地 / 街块面积），并检查楼与楼之间：
## 不重叠，且要么贴着（< 0.5 米，连排）、要么隔开至少 4 米（机甲能过的小巷），不留过不去的窄缝

const START := "none"
const WC = preload("res://scripts/world_city.gd")


func run() -> void:
	for mid: String in GameData.map_ids():
		var t0 := Time.get_ticks_usec()
		var Z: Dictionary = WC.zone_layout(mid)
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		var by := {}
		var area := {}
		for b: Dictionary in Z.bldgs:
			var ch := str(b.ch)
			by[ch] = int(by.get(ch, 0)) + 1
			area[ch] = float(area.get(ch, 0.0)) + float(b.sx) * float(b.sz)
		var barea := {}
		for blk: Dictionary in Z.blocks:
			var c := WC.centroid(blk.poly)
			if absf(c.x) > 180.0 or absf(c.y) > 180.0:
				continue
			var ch := str(blk.ch)
			barea[ch] = float(barea.get(ch, 0.0)) + WC.poly_area(blk.poly)
		var parts: Array = []
		for ch in barea:
			parts.append("%s:%d(%.0f%%)" % [ch, int(by.get(ch, 0)), 100.0 * float(area.get(ch, 0.0)) / maxf(1.0, barea[ch])])
		for ch in by:
			if not barea.has(ch):
				parts.append("%s:%d" % [ch, by[ch]])
		var bl: Array = Z.bldgs
		var over := 0
		var narrow := 0
		for i in bl.size():
			var a := WC.obb_corners(bl[i].c, bl[i].ang, bl[i].sx, bl[i].sz)
			for j in range(i + 1, bl.size()):
				if (bl[i].c as Vector2).distance_to(bl[j].c) > 60.0:
					continue
				var b := WC.obb_corners(bl[j].c, bl[j].ang, bl[j].sx, bl[j].sz)
				if WC.convex_overlap(a, b, -0.05):
					over += 1
				elif WC.convex_overlap(a, b, 3.95) and not WC.convex_overlap(a, b, 0.5):
					narrow += 1
		log_line("%s bldgs=%d layout=%.0fms overlap=%d narrow_gap=%d %s" % [mid, Z.bldgs.size(), dt, over, narrow, " ".join(parts)])
		check(over == 0 and narrow == 0, "%s 有 %d 处重叠、%d 处 0.5~4 米的窄缝" % [mid, over, narrow])
