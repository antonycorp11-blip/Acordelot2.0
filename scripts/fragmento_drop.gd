extends Node3D
## Fragmento musical no mundo. Shikers usam a forma corrompida; os futuros
## Ecos Musicais poderao reutilizar o mesmo drop com `corrompido = false`.
##
## A malha e o objeto do mundo; o PNG original fica reservado para inventario
## e sintese. Nao ha fisica nem luz: a coleta usa distancia e a aura e um unico
## quad aditivo, para o primeiro punhado de drops nao travar o navegador.

const ALTURAS := [
    "do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si",
]
const MODELOS := [
    preload("res://models/itens_notas/fragmento_do.glb"),
    preload("res://models/itens_notas/fragmento_do_sustenido.glb"),
    preload("res://models/itens_notas/fragmento_re.glb"),
    preload("res://models/itens_notas/fragmento_re_sustenido.glb"),
    preload("res://models/itens_notas/fragmento_mi.glb"),
    preload("res://models/itens_notas/fragmento_fa.glb"),
    preload("res://models/itens_notas/fragmento_fa_sustenido.glb"),
    preload("res://models/itens_notas/fragmento_sol.glb"),
    preload("res://models/itens_notas/fragmento_sol_sustenido.glb"),
    preload("res://models/itens_notas/fragmento_la.glb"),
    preload("res://models/itens_notas/fragmento_la_sustenido.glb"),
    preload("res://models/itens_notas/fragmento_si.glb"),
]
const BRILHO := preload("res://textures/brilho_poste.png")

@export var altura_id := "do"
@export var quantidade := 1
@export var corrompido := true

const RAIO_DE_COLETA := 1.55
const TEMPO_DE_VIDA := 40.0
var _modelo: Node3D
var _jogador: Node3D
var _tempo := 0.0
var _fase := 0.0
var _proxima_busca := 0.0
var _coletado := false
var _base_y := 0.18

static var _material_limpo: StandardMaterial3D
static var _malha_aura_limpa: QuadMesh


func _ready() -> void:
    add_to_group("fragmento_drop")
    _montar_modelo()
    _montar_aura()


func _process(delta: float) -> void:
    if _coletado:
        return
    _tempo += delta
    _fase += delta
    if _modelo:
        _modelo.position.y = _base_y + sin(_fase * 2.4) * 0.08
        _modelo.rotation.y += delta * 0.75
    if _tempo >= TEMPO_DE_VIDA:
        queue_free()
        return
    _proxima_busca -= delta
    if _proxima_busca > 0.0:
        return
    _proxima_busca = 0.10
    if _jogador == null or not is_instance_valid(_jogador):
        _jogador = get_tree().get_first_node_in_group("player") as Node3D
    if _jogador and global_position.distance_to(_jogador.global_position) <= RAIO_DE_COLETA:
        _coletar()


func _montar_modelo() -> void:
    var indice := maxi(ALTURAS.find(altura_id), 0)
    _modelo = (MODELOS[indice] as PackedScene).instantiate()
    _modelo.name = "Cristal_" + altura_id
    add_child(_modelo)

    if _material_limpo == null:
        _material_limpo = StandardMaterial3D.new()
        _material_limpo.vertex_color_use_as_albedo = true
        _material_limpo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _material_limpo.roughness = 0.7
    # A corrupcao nao recolore a nota: sua identidade cromatica continua
    # reconhecivel. O roxo pertence apenas a aura e as particulas externas.
    var material := _material_limpo
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        (malha as MeshInstance3D).material_override = material
        (malha as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _normalizar_tamanho()


func _normalizar_tamanho() -> void:
    var caixa := AABB()
    var achou := false
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local := _ate_a_raiz(mi, _modelo) * mi.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou or caixa.size.y <= 0.001:
        return
    var escala := clampf(0.90 / caixa.size.y, 0.05, 5.0)
    _modelo.scale = Vector3.ONE * escala
    _base_y = 0.18 - caixa.position.y * escala
    _modelo.position = Vector3(0.0, _base_y, 0.0)


func _ate_a_raiz(no: Node3D, raiz: Node3D) -> Transform3D:
    var acumulado := Transform3D.IDENTITY
    var atual: Node3D = no
    while atual != null and atual != raiz:
        acumulado = atual.transform * acumulado
        atual = atual.get_parent() as Node3D
    return acumulado


func _montar_aura() -> void:
    if corrompido:
        _montar_particulas_roxas()
        return
    if _malha_aura_limpa == null:
        _malha_aura_limpa = _criar_aura(Color(0.30, 0.76, 1.0, 0.58), Color(0.15, 0.55, 0.90))
    var aura := MeshInstance3D.new()
    aura.name = "AuraHarmonica"
    aura.mesh = _malha_aura_limpa
    aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(aura)


func _montar_particulas_roxas() -> void:
    var particulas := GPUParticles3D.new()
    particulas.name = "ParticulasDeCorrupcao"
    particulas.amount = 7
    particulas.lifetime = 1.8
    particulas.randomness = 0.75
    particulas.visibility_aabb = AABB(Vector3(-0.8, -0.2, -0.8), Vector3(1.6, 1.8, 1.6))
    particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var processo := ParticleProcessMaterial.new()
    processo.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    processo.emission_sphere_radius = 0.38
    processo.direction = Vector3.UP
    processo.spread = 45.0
    processo.initial_velocity_min = 0.08
    processo.initial_velocity_max = 0.22
    processo.gravity = Vector3.ZERO
    processo.color = Color(0.70, 0.28, 1.0, 0.78)
    particulas.process_material = processo
    var ponto := QuadMesh.new()
    ponto.size = Vector2(0.045, 0.045)
    var material := StandardMaterial3D.new()
    material.albedo_texture = BRILHO
    material.albedo_color = Color(0.72, 0.34, 1.0, 0.78)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    ponto.material = material
    particulas.draw_pass_1 = ponto
    add_child(particulas)


func _criar_aura(cor: Color, emissao: Color) -> QuadMesh:
    var malha := QuadMesh.new()
    malha.size = Vector2(1.45, 1.45)
    malha.orientation = PlaneMesh.FACE_Y
    malha.center_offset = Vector3(0.0, 0.055, 0.0)
    var material := StandardMaterial3D.new()
    material.albedo_texture = BRILHO
    material.albedo_color = cor
    material.emission_enabled = true
    material.emission = emissao
    material.emission_energy_multiplier = 1.35
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    malha.material = material
    return malha


func _coletar() -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    _coletado = true
    var prefixo := "fragmento_corrompido_" if corrompido else "fragmento_"
    progresso.adicionar_recurso(prefixo + altura_id, quantidade)
    var tw := create_tween()
    tw.tween_property(self, "scale", Vector3.ONE * 1.35, 0.08)
    tw.tween_property(self, "scale", Vector3.ZERO, 0.16)
    tw.tween_callback(queue_free)
