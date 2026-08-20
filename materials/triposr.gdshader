shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.05;

void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
