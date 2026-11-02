extends Node
## 测试基类。tests\<名字>.gd 写 extends "res://tests/lib/test_base.gd" 并实现协程 run()；运行参数为 -- --<名字>。
## main.gd 按测试脚本的常量 START 先进入 "hub"（默认）、"menu" 或 "none"，再把测试节点加为它的子节点（self.main）。
## 结果约定：成功打印「[名字] DONE」并以退出码 0 结束；失败打印「[名字] FAIL 原因」并以退出码 1 结束。
## run() 正常返回即视为成功；超过常量 TIMEOUT 秒（真实时间，默认 300）按失败处理。
## 截图：await shot("文件名.png") 存到项目根目录的 review 文件夹（扁平，不建子目录）；无界面运行时不截图、直接返回。

const REVIEW_DIR := "res://review"

var test_name := ""
var main
var _finished := false
var _log: ErrorLog


## 测试期间出现的脚本错误一律判失败（协程里的脚本错误会中断 run()，不能当作正常结束）；
## 无界面运行时引擎报的 ERROR 也判失败，与门禁的判定一致。
class ErrorLog extends Logger:
	var strict := false
	var errors: Array = []
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT or (strict and (error_type == ERROR_TYPE_ERROR or error_type == ERROR_TYPE_SHADER)):
			_m.lock()
			errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
			_m.unlock()

	func take() -> Array:
		_m.lock()
		var out := errors.duplicate()
		errors.clear()
		_m.unlock()
		return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	test_name = get_script().resource_path.get_file().get_basename()
	main = get_parent()
	_log = ErrorLog.new()
	_log.strict = headless()
	OS.add_logger(_log)
	var limit := float(get_script().get_script_constant_map().get("TIMEOUT", 300.0))
	get_tree().create_timer(limit, true, false, true).timeout.connect(func(): fail("超时 %d 秒" % int(limit)))
	_start.call_deferred()


func _process(_d: float) -> void:
	_check_log()


func _exit_tree() -> void:
	if _log:
		OS.remove_logger(_log)
		_log = null


func _check_log() -> void:
	if _log == null or _finished:
		return
	var e: Array = _log.take()
	if not e.is_empty():
		fail("运行中出现错误：" + "；".join(e.slice(0, 3)))


func _start() -> void:
	await run()
	_check_log()
	if not _finished:
		done()


## 子类实现的测试流程
func run() -> void:
	await get_tree().process_frame


func done() -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	print("[%s] DONE" % test_name)
	get_tree().quit(0)


func fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	print("[%s] FAIL %s" % [test_name, reason])
	get_tree().quit(1)


## 条件不成立时判失败；返回条件本身（if not check(...): return）
func check(cond: bool, reason: String) -> bool:
	if not cond:
		fail(reason)
	return cond


func log_line(text: String) -> void:
	print("[%s] %s" % [test_name, text])


## 截图存为 review\<file>；vp 为空时截主视口
func shot(file: String, vp: Viewport = null) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var v: Viewport = vp if vp != null else get_viewport()
	var img := v.get_texture().get_image()
	if img == null:
		fail("截图失败：%s" % file)
		return
	var dir := ProjectSettings.globalize_path(REVIEW_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(dir.path_join(file))
	if err != OK:
		fail("截图保存失败（%d）：%s" % [err, file])


static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


## 等待游戏时间（随 Engine.time_scale 缩放，暂停时也计时）
func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout


## 等待真实时间（按系统时钟计，不受 time_scale 影响；启动后头几帧的帧间隔很长，计时器会提前到期，所以不用计时器）
func wait_real(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## 每帧检查 cond，成立返回 true；超过 limit 秒（游戏时间）返回 false
func until(cond: Callable, limit := 30.0) -> bool:
	var t := 0.0
	while not cond.call():
		if t > limit:
			return false
		await get_tree().process_frame
		t += get_process_delta_time()
	return true


## 从机库出击，等到空投结束、机甲可以操作；lo 不为空时先换上这套装配。返回 raid，失败时返回 null
func deploy(lo := {}) -> Node:
	if not lo.is_empty():
		GameData.loadout = lo.duplicate()
	if main.hub == null:
		main.show_hub()
	main.hub.deploy_requested.emit()
	var ok: bool = await until(func(): return main.raid != null and main.raid.mech != null and not main.raid.mech.input_locked, 20.0)
	return main.raid if ok else null
