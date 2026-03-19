shader_type canvas_item;

uniform vec2 light_pos = vec2(0.5, 0.5);

// notification light — small tight pulse on phone spot
uniform float notif_inner : hint_range(0.0, 0.5) = 0.03;
uniform float notif_outer : hint_range(0.0, 0.5) = 0.06;
uniform bool notif_on = false;

// flashlight — wider beam with soft glow ring
uniform float flash_inner : hint_range(0.0, 0.5) = 0.06;
uniform float flash_outer : hint_range(0.0, 0.5) = 0.10;
uniform float flash_glow  : hint_range(0.0, 0.5) = 0.16;
uniform bool flash_on = false;

void fragment() {
    vec2 uv = UV;
    vec2 delta = uv - light_pos;
    delta.x *= (1920.0 / 1080.0);
    float dist = length(delta);
    float light = 0.0;

    if (notif_on) {
        light = smoothstep(notif_outer, notif_inner, dist);
    }

    if (flash_on) {
        float bright = smoothstep(flash_outer, flash_inner, dist);
        float glow   = smoothstep(flash_glow,  flash_outer, dist) * 0.5;
        light = clamp(bright + glow, 0.0, 1.0);
    }

    COLOR = vec4(0.0, 0.0, 0.0, 1.0 - light);
}