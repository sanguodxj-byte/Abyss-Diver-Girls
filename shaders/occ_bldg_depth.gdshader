shader_type spatial;
// 整栋遮挡建筑平滑虚化 Pass 1：仅写入建筑最外层朝向镜头的深度（ALPHA=0 不改写颜色），
// 配合 Pass 2 (occ_bldg_ghost.gdshader) 的 depth_test_default 实现零内部重影的均匀半透明建筑外壳。
render_mode blend_mix, depth_draw_always, depth_test_default, cull_back, unshaded;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
