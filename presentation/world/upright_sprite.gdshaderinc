// Shared by upright_sprite_lit.gdshader and upright_sprite_unlit.gdshader (Sprite3D
// material_override, built by SheetFrame; both use render_mode skip_vertex_transform).
// The quad faces the camera fully, keeping the node's scale, so a texel projects at one
// uniform size with no lean or shear (#36). Depth and light are taken where the figure
// really stands: each view ray is cut by the vertical plane through the node's origin
// (the feet) that faces the camera across the ground, or by the ground plane through the
// feet where that is nearer (toes and anything drawn below the pivot lie on the ground in
// front of the feet). A bare camera-facing quad leans back by the camera pitch: its upper
// half sinks into anything just behind the feet and is lit and shadowed from inside it,
// and the ground cuts off its toes. Screen position and texels come from the quad alone.

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

// Pulls the figure this far toward the camera so feet lying on the ground plane win the
// depth test against the ground instead of flickering with it.
const float GROUND_BIAS_M = 0.02;
// Below this a ray counts as parallel to a plane (a camera looking straight down has no
// "across the ground").
const float PARALLEL_EPSILON = 1e-6;
const float NO_HIT = 1e30;

varying vec3 feet_view;
varying vec3 upright_normal;
varying vec3 ground_normal;

// The ray parameter t where view_point * t meets the plane through feet with this normal,
// or NO_HIT when it never meets it in front of the camera.
float plane_hit(vec3 view_point, vec3 plane_normal, vec3 feet) {
	float along_ray = dot(view_point, plane_normal);
	if (abs(along_ray) < PARALLEL_EPSILON) {
		return NO_HIT;
	}
	float t = dot(feet, plane_normal) / along_ray;
	return t > 0.0 ? t : NO_HIT;
}

// Where the figure stands along the view ray through a point of the quad (view space).
vec3 standing_point(vec3 quad_point, vec3 feet, vec3 up_normal, vec3 floor_normal) {
	float t = min(plane_hit(quad_point, up_normal, feet), plane_hit(quad_point, floor_normal, feet));
	if (t >= NO_HIT) {
		return quad_point;
	}
	vec3 point = quad_point * t;
	return point - normalize(point) * GROUND_BIAS_M;
}

void vertex() {
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mat4 keep_scale = mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	mat4 modelview = VIEW_MATRIX * facing * keep_scale;
	vec3 quad_point = (modelview * vec4(VERTEX, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(quad_point, 1.0);
	vec3 back = INV_VIEW_MATRIX[2].xyz;
	upright_normal = mat3(VIEW_MATRIX) * vec3(back.x, 0.0, back.z);
	ground_normal = mat3(VIEW_MATRIX) * vec3(0.0, 1.0, 0.0);
	feet_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	// Lit per corner at the standing point; the normal map stays camera-facing.
	VERTEX = standing_point(quad_point, feet_view, upright_normal, ground_normal);
	NORMAL = normalize(mat3(modelview) * NORMAL);
	TANGENT = normalize(mat3(modelview) * TANGENT);
	BINORMAL = normalize(mat3(modelview) * BINORMAL);
}

// Depth of the standing point under this pixel, exact per pixel, in the renderer's
// convention. Any point on the pixel's view ray will do as the quad point.
float standing_depth(vec2 screen_uv, mat4 projection, mat4 inv_projection) {
	vec4 ray = inv_projection * vec4(screen_uv * 2.0 - 1.0, 0.5, 1.0);
	vec3 point = standing_point(ray.xyz / ray.w, feet_view, upright_normal, ground_normal);
	vec4 clip = projection * vec4(point, 1.0);
	float ndc_z = clip.z / clip.w;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return ndc_z * 0.5 + 0.5;
#else
	return ndc_z;
#endif
}
