shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform vec3 cor_base : source_color = vec3(0.075, 0.24, 0.055);
uniform vec3 cor_ponta : source_color = vec3(0.24, 0.52, 0.13);
uniform float forca_vento = 0.055;
uniform float velocidade_vento = 1.35;

varying float altura_da_folha;

void vertex() {
    altura_da_folha = UV.y;
    float fase = NODE_POSITION_WORLD.x * 0.21 + NODE_POSITION_WORLD.z * 0.17;
    float vento = sin(TIME * velocidade_vento + fase) * forca_vento * UV.y;
    VERTEX.x += vento;
    VERTEX.z += vento * 0.42;
}

void fragment() {
    ALBEDO = mix(cor_base, cor_ponta, clamp(altura_da_folha, 0.0, 1.0));
    ROUGHNESS = 0.96;
    SPECULAR = 0.02;
}
