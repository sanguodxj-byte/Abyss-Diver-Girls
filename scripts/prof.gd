extends RefCounted
## 轻量分项计时器（性能剖析用）：on 为 false 时只多一次布尔判断。
## 用法：var t := Prof.t0()；……；Prof.add("bug.perceive", t)。perf_prof 测试打开 on 并按帧读取、清零。

static var on := false
static var acc := {}     # 键 -> 本帧累计微秒
static var cnt := {}     # 键 -> 本帧调用次数


static func t0() -> int:
	return Time.get_ticks_usec() if on else 0


static func add(key: String, t: int) -> void:
	if not on:
		return
	acc[key] = acc.get(key, 0) + Time.get_ticks_usec() - t
	cnt[key] = cnt.get(key, 0) + 1


static func take() -> Array:
	var a := acc
	var c := cnt
	acc = {}
	cnt = {}
	return [a, c]
