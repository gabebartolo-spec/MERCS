// A frame drawn unshaded, tinted by the sprite's modulate (vertex colour; the night tint),
// with nearest texels and alpha scissor. Billboard and upright depth come from the include.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

#include "res://presentation/world/upright_sprite.gdshaderinc"

void fragment() {
	vec4 albedo = texture(albedo_texture, UV) * COLOR;
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}
