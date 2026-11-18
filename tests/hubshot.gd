extends "res://tests/lib/test_base.gd"
## 机库界面截图 → review/hubshot.png；另开设置页截存档位行 → review/hubshot_settings.png
func run() -> void:
	await wait(1.5)
	await shot("hubshot.png")
	main.hub._open_hub_settings("other")
	await wait(0.5)
	await shot("hubshot_settings.png")
