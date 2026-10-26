shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_mul = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR * tint;
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	if (dissolve > 0.0 && hash(floor(UV * 64.0)) < dissolve) {
		c.a = 0.0;
	}
	c.a *= alpha_mul;
	COLOR = c;
}
