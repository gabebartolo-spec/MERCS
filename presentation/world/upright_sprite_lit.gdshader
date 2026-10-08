// A factory sheet frame lit by the scene's lights through its normal map (#26): nearest
// texels, alpha scissor, matte, no specular glint. Billboard and upright depth come from
// the include.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://presentation/world/upright_sprite.gdshaderinc"

uniform sampler2D normal_texture : hint_normal, filter_nearest;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
