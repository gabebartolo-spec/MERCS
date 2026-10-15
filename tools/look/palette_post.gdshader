shader_type canvas_item;
// Look-target post (the palette contract applied to the whole frame): every pixel of the logical
// viewport is snapped to the nearest colour of the option's master palette, measured in OKLab so
// darks and lights are matched as the eye sees them. dither > 0 adds a 4x4 ordered (Bayer) offset per
// logical pixel before the match; 0 is a plain nearest match. A colour's penalty is added to its
// distance: heraldry, blood and fire are reserved (06 section 2: saturated colour only on faction cloth
// and flame),
// so lit wood or mud never snaps to them. Deterministic: no noise, no time.

const int MAX_COLOURS = 64;
uniform vec3 palette_lab[MAX_COLOURS];
uniform vec3 palette_rgb[MAX_COLOURS];
uniform float palette_penalty[MAX_COLOURS];
uniform int colour_count = 0;
uniform float dither = 0.0;
uniform vec2 logical_size = vec2(960.0, 540.0);

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_oklab(vec3 srgb) {
	vec3 c = to_linear(srgb);
	float l = pow(0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b, 1.0 / 3.0);
	float m = pow(0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b, 1.0 / 3.0);
	float s = pow(0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b, 1.0 / 3.0);
	return vec3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

float bayer4(ivec2 p) {
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[(p.y % 4) * 4 + (p.x % 4)]) + 0.5) / 16.0 - 0.5;
}

void fragment() {
	vec3 src = texture(TEXTURE, UV).rgb;
	vec3 lab = to_oklab(clamp(src, 0.0, 1.0));
	ivec2 cell = ivec2(floor(UV * logical_size));
	lab.x += bayer4(cell) * dither * 0.08;
	float best = 1e9;
	vec3 out_rgb = src;
	for (int i = 0; i < MAX_COLOURS; i++) {
		if (i >= colour_count) {
			break;
		}
		vec3 d = lab - palette_lab[i];
		float e = dot(d, d) + palette_penalty[i];
		if (e < best) {
			best = e;
			out_rgb = palette_rgb[i];
		}
	}
	COLOR = vec4(out_rgb, 1.0);
}
