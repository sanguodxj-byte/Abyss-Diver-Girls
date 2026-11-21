extends Node
## 外部驱动通过真正的 Windows 关闭消息验证退出；本脚本不自行 quit。
const START := "none"
var scenario := "menu"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="): scenario = a.get_slice("=", 1)
	_start.call_deferred()

func _start() -> void:
	var main = get_parent()
	match scenario:
		"menu", "busy": main.show_menu()
		"hub": main.show_hub()
		_:
			GameData.map_id = "redlake"
			main.show_hub()
			await main.start_raid()
			if scenario == "pause": main.raid.hud.toggle_pause()
			elif scenario == "first_person": main.raid.set_view_mode(1, false)
	await get_tree().create_timer(2.0, true).timeout
	print("[exit_probe] READY ", scenario)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[exit_probe] CLOSE_REQUEST")
		if scenario == "busy":
			# Native finite tasks reproduce shutdown with pending low-priority work.
			# They capture no script/node state and the pool owns them until shutdown.
			for i in 64:
				WorkerThreadPool.add_task(OS.delay_msec.bind(100), false, "Exit pending native task")

func _exit_tree() -> void:
	print("[exit_probe] EXIT_TREE")
