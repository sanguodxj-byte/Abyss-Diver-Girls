extends "res://tests/lib/test_base.gd"
## 机库界面截图 → review/hubshot.png
func run() -> void:
	await wait(1.5)
	await shot("hubshot.png")
