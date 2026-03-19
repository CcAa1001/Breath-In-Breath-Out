shader_type canvas_item;

uniform vec2 mouse_pos = vec2(0.5, 0.5);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.15;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.35;
uniform float ambient_light : hint_range(0.0, 1.0) = 0.04;
uniform bool flashlight_on = false;

void fragment() {
	vec2 uv = UV;
	vec2 delta = uv - mouse_pos;
	// correct for 16:9 aspect ratio so light is circular
	delta.x *= (1920.0 / 1080.0);
	float dist = length(delta);
	float light = smoothstep(outer_radius, inner_radius, dist);
	float alpha = flashlight_on ? mix(1.0 - ambient_light, 0.0, light) : (1.0 - ambient_light);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
