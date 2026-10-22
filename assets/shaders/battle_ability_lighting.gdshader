shader_type canvas_item;
render_mode blend_mix;

uniform vec2 focus = vec2(0.5, 0.5);
uniform vec4 tint : source_color = vec4(0.55, 0.82, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float aspect_ratio = 1.0;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.00001), 0.0, 1.0);
	return length(p - (a + ab * t));
}

void fragment() {
	vec2 p = (UV - focus) * vec2(aspect_ratio, 1.0);
	float glow = 1.0 - smoothstep(0.0, 0.72, length(p));
	float lightning = 0.0;

	for (int ray = 0; ray < 6; ray++) {
		float angle = TAU * float(ray) / 6.0 + phase * 0.13;
		vec2 direction = vec2(cos(angle), sin(angle));
		vec2 normal = vec2(-direction.y, direction.x);
		vec2 previous = vec2(0.0);
		for (int segment = 1; segment <= 9; segment++) {
			float step = float(segment) / 9.0;
			float jitter = sin(float(segment) * 13.7 + float(ray) * 8.1 + phase * 7.0) * 0.025;
			vec2 next = direction * (step * 0.68) + normal * jitter;
			float d = segment_distance(p, previous, next);
			lightning = max(lightning, 1.0 - smoothstep(0.002, 0.008, d));
			previous = next;
		}
	}

	float alpha = intensity * (0.12 + glow * 0.12 + lightning * 0.5);
	vec3 color = mix(tint.rgb, vec3(1.0), lightning * 0.8);
	COLOR = vec4(color, alpha);
}
