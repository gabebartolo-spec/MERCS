// Shared by upright_sprite_lit.gdshader and upright_sprite_unlit.gdshader (Sprite3D
// material_override, built by SheetFrame). The quad faces the camera fully, keeping the
// node's scale, so a texel projects at one uniform size with no lean or shear (#36). Its
// depth is written as if the figure stood upright: each corner is moved along its view
// ray onto the vertical plane through the node's origin (the feet) that faces the camera
// across the ground. A plane's depth is linear across the screen, so per-vertex depth is
// exact per pixel. Without this a camera-facing quad leans back by the camera pitch and
// its upper half sinks into anything just behind the feet. Only depth changes: lighting
// still reads the quad's own position, so pixels in open ground are unchanged.

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mat4 keep_scale = mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing * keep_scale;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vec3 view_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(view_vertex, 1.0);
	vec3 back = INV_VIEW_MATRIX[2].xyz;
	vec3 plane_normal = mat3(VIEW_MATRIX) * vec3(back.x, 0.0, back.z);
	vec3 feet = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float along_ray = dot(view_vertex, plane_normal);
	// A camera looking straight down has no "across the ground": keep the quad's depth.
	if (abs(along_ray) > 1e-6) {
		vec4 upright = PROJECTION_MATRIX * vec4(view_vertex * dot(feet, plane_normal) / along_ray, 1.0);
		POSITION.z = upright.z / upright.w * POSITION.w;
	}
}
