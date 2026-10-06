shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D surface_detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 emission_color = vec3(0.0);
instance uniform float damage = 0.0;
instance uniform float heat = 0.0;
instance uniform float startup = 1.0;
varying vec3 object_position;
varying vec3 object_normal;
varying float roughness_data;
varying float metal_data;
void vertex() {
 object_position = VERTEX;
 object_normal = NORMAL;
 roughness_data = COLOR.a;
 metal_data = UV2.x;
}
void fragment() {
 vec3 weights = pow(abs(object_normal), vec3(4.0));
 weights /= max(weights.x + weights.y + weights.z, 0.001);
 vec3 detail = texture(surface_detail, object_position.yz * 1.6).rgb * weights.x;
 detail += texture(surface_detail, object_position.xz * 1.6).rgb * weights.y;
 detail += texture(surface_detail, object_position.xy * 1.6).rgb * weights.z;
 vec3 paint = COLOR.rgb * mix(0.86, 1.07, detail.r);
 float wear = detail.b * (0.15 + damage * 0.8);
 paint = mix(paint, vec3(0.10, 0.12, 0.13), wear);
 ALBEDO = paint * (1.0 - damage * 0.32);
 ROUGHNESS = clamp(roughness_data + (detail.g - 0.5) * 0.13 + damage * 0.2, 0.18, 0.96);
 METALLIC = metal_data;
 EMISSION = COLOR.rgb * emission_color * startup * (2.6 + heat * 1.4) * (1.0 - damage * 0.85);
}
