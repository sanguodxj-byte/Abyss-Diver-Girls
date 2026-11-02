shader_type canvas_item;

// 立绘动画去黑底：视频以纯黑为背景，按亮度生成透明度，边缘留一段过渡避免硬锯齿。
uniform float key_threshold : hint_range(0.0, 0.35) = 0.16;
uniform float key_softness : hint_range(0.001, 0.3) = 0.12;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float lum = max(src.r, max(src.g, src.b));
	float a = smoothstep(key_threshold, key_threshold + key_softness, lum);
	COLOR = vec4(src.rgb, src.a * a);
}
