extends RefCounted
const Prof = preload("res://scripts/prof.gd")
## 有界采样：仅保留当前 10 秒帧数据和每窗最慢 4 帧，长测不会堆积逐帧字典。
const PIPELINES := [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH,
	Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]
var samples := PackedFloat64Array()
var windows: Array = []
var slow: Array = []
var last := 0
var started := 0
var window_start := 0
var pipes := PackedInt64Array()
var vp: RID
var tag := ""
# 固定 0.1 ms 直方图，汇总长局分位数而不常驻保存每一帧。
var histogram := PackedInt64Array()


func begin(viewport: Viewport, label: String) -> void:
	tag = label
	vp = viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	samples.clear()
	windows.clear()
	slow.clear()
	histogram.resize(10002)
	histogram.fill(0)
	last = Time.get_ticks_usec()
	started = last
	window_start = last
	pipes = _pipelines()


func frame() -> bool:
	var now := Time.get_ticks_usec()
	var ms := (now - last) / 1000.0
	last = now
	samples.append(ms)
	histogram[mini(int(ceil(ms * 10.0)), histogram.size() - 1)] += 1
	var current := _pipelines()
	var delta := PackedInt64Array()
	for i in current.size(): delta.append(current[i] - pipes[i])
	pipes = current
	var profile: Array = Prof.take() if Prof.on else []
	if slow.size() < 4 or ms > float(slow[-1].ms):
		slow.append({"at_s": (now - started) / 1000000.0, "ms": ms, "pipelines": Array(delta),
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(vp),
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(vp)})
		if not profile.is_empty():
			slow[-1].profile_us = profile[0]
			slow[-1].profile_calls = profile[1]
		slow.sort_custom(func(a, b): return a.ms > b.ms)
		if slow.size() > 4: slow.resize(4)
	return now - window_start >= 10000000


func flush(state: Dictionary) -> Dictionary:
	if samples.is_empty(): return {}
	var total := 0.0
	var over33 := 0
	var over45 := 0
	var over100 := 0
	for ms in samples:
		total += ms
		if ms > 33.333: over33 += 1
		if ms > 45: over45 += 1
		if ms > 100: over100 += 1
	samples.sort()
	var record := {"tag": tag, "at_s": (last - started) / 1000000.0, "frames": samples.size(),
		"avg_ms": total / samples.size(), "p95_ms": samples[int(samples.size() * 0.95)],
		"p99_ms": samples[int(samples.size() * 0.99)], "max_ms": samples[-1],
		"over33": over33, "over45": over45, "over100": over100,
		"slow": slow.duplicate(true), "state": state, "memory": memory(), "pipeline_totals": Array(pipes)}
	windows.append(record)
	samples.clear()
	slow.clear()
	window_start = last
	return record


static func memory() -> Dictionary:
	return {"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0}


static func _pipelines() -> PackedInt64Array:
	var result := PackedInt64Array()
	for key in PIPELINES: result.append(int(Performance.get_monitor(key)))
	return result
