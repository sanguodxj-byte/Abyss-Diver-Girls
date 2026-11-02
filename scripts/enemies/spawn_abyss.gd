extends RefCounted
## 零号深渊井的虫群布置：常规虫群按分布表铺开，终章期间深渊母皇伏在竖井底部的弹坑里。
## 本章还没解锁时只铺常规虫群，玩家不会在非终章状态下碰到母皇。

const Util = preload("res://scripts/enemies/spawn_util.gd")


static func spawn(raid, drop: Vector3) -> void:
	Util.fill(raid, drop)
	if Story.has_flag("ch7_done"):
		return
	Util.place_boss(raid, "abyss_queen", ["C", "S"], 110.0, drop)
