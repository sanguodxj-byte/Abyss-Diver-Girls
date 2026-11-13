extends RefCounted
## 自动生成（tests/worldmap_export.gd），勿手改：各战区转场口沿边位置（米），即 world_city.gd gate_compute 的结果。
## 城市群布局改动后重新运行 -- --worldmap_export；tests/worldmap.gd 会校验这张表与现算一致。

const GATES := {
	"bayport|S": 185.34,
	"bayport|W": 192.22,
	"canyon|N": 185.46,
	"canyon|W": 292.32,
	"dustfield|E": 292.32,
	"dustfield|N": 189.85,
	"greyport|E": 127.86,
	"greyport|N": 80.22,
	"greyport|S": 189.85,
	"ironbelt|N": 185.34,
	"ironbelt|S": 185.46,
	"ironbelt|W": 127.86,
	"redlake|E": 192.22,
	"redlake|S": 80.22,
}
