shader_type spatial;

uniform sampler2D wear_texture : source_color, filter_linear_mipmap;
uniform vec3 armor_tint : source_color = vec3(1.0);
uniform float damage : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float wear = texture(wear_texture, UV * 2.5).r;
	float plate = step(0.5, COLOR.r);
	ALBEDO = COLOR.rgb * mix(vec3(1.0), armor_tint, plate) * (0.87 + wear * 0.23) * (1.0 - damage * 0.62);
	METALLIC = 0.76;
	ROUGHNESS = 0.4 + wear * 0.19;
}
