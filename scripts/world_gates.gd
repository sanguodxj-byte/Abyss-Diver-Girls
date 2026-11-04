extends RefCounted
## 自动生成（tests/worldmap_export.gd），勿手改：各战区转场口沿边位置（米），即 world_city.gd gate_compute 的结果。
## 城市群布局改动后重新运行 -- --worldmap_export；tests/worldmap.gd 会校验这张表与现算一致。

const GATES := {
	"canyon|N": 0.00,
	"canyon|W": -48.00,
	"dustfield|E": -48.00,
	"dustfield|N": -8.00,
	"greyport|E": 8.00,
	"greyport|N": 0.00,
	"greyport|S": -8.00,
	"ironbelt|S": 0.00,
	"ironbelt|W": 8.00,
	"redlake|S": 0.00,
}
