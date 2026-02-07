shader_type spatial;

render_mode blend_mix, cull_disabled, depth_prepass_alpha, specular_disabled, vertex_lighting;

uniform sampler2D albedo_texture: source_color, filter_nearest;

uniform bool snap_enabled = true;
uniform float snap_resolution : hint_range(60.0, 288.0, 1.0) = 148.0;

void vertex() {
	vec4 view_space_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_space_pos = PROJECTION_MATRIX * view_space_pos;
	
	if (snap_enabled) {
		vec2 ndc = clip_space_pos.xy / clip_space_pos.w;
		ndc = round(ndc * snap_resolution) / snap_resolution;
		clip_space_pos.xy = ndc * clip_space_pos.w;
	}
	
	POSITION = clip_space_pos;
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	ALBEDO = texture(albedo_texture, UV).rgb;
	ALPHA = texture(albedo_texture, UV).a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
