shader_type canvas_item;

uniform int color_depth : hint_range(1, 8) = 5;
uniform bool dithering = true;
uniform int resolution_scale = 4;
uniform sampler2D SCREEEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

const mat4 pattern = mat4(
vec4(-4, +0, -3, +1),
vec4(+2, -2, +3, -1),
vec4(-3, +1, -4, +0),
vec4(+3, -1, +2, -2)
);

int dithering_pattern(ivec2 fragcoord) {
int x = fragcoord.x % 4;
int y = fragcoord.y % 4;

vec4 pattern_vec4;

if (y == 0) pattern_vec4 = pattern[0];
else if (y == 1) pattern_vec4 = pattern[1];
else if (y == 2) pattern_vec4 = pattern[2];
else if (y == 3) pattern_vec4 = pattern[3];

float pattern_int;

if (x == 0) pattern_int = pattern_vec4.x;
else if (x == 1) pattern_int = pattern_vec4.y;
else if (x == 2) pattern_int = pattern_vec4.z;
else if (x == 3) pattern_int = pattern_vec4.w;

return int(pattern_int);
}

void fragment() {
ivec2 uv = ivec2(FRAGCOORD.xy / float(resolution_scale));
vec4 color = texelFetch(SCREEEN_TEXTURE, uv * resolution_scale, 0);

// Convert from [0.0, 1.0] range to [0, 255] range
ivec4 c = ivec4(round(color * 255.0));

// Apply the dithering pattern
if (dithering) {
c += ivec4(dithering_pattern(uv));
}

// Truncate from 8 bits to color_depth bits
c >>= (8 - color_depth);

// Convert back to [0.0, 1.0] range
COLOR = vec4(c) / float(1 << color_depth);
}