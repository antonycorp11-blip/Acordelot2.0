extends Area3D
class_name PortalCaverna

## A BOCA DA CAVERNA, PLANTADA NO MUNDO ABERTO.
##
## Ate aqui a masmorra so existia por um botao na HUD — um retangulo roxo escrito
## "DG CAVERNA" flutuando na tela, que teleportava de qualquer lugar do mapa. Um
## lugar que se alcanca por um botao nao e um lugar: e um menu. Aqui a caverna
## volta a ter porta, e a porta fica no chao, entre as arvores, onde o jogador
## tropeca nela andando.
##
## O portal NAO engole quem encosta. Atravessar sozinho seria a mesma teleportada
## de antes, so que sem aviso: o jogador que anda distraido perderia o mundo de
## vista sem ter pedido nada. Chegar perto acende o convite, e quem entra e o
## botao de acao — o mesmo que ja serve para conversar com as NPCs.

const ARCO := preload("res://models/cc0/cave/gate.glb")
const TEXTURA_ROCHA := preload("res://assets/dungeon/textures/rocha_caverna_1k.jpg")
const BRILHO := preload("res://textures/brilho_poste.png")

## O quanto o arco cresce em relacao ao modelo cru, que tem 4,4 m de vao.
const ESCALA_DO_ARCO := 1.35
## Onde a mao alcanca. O bastante para o convite aparecer antes de o jogador
## estar dentro do arco, e pouco o suficiente para nao acender de longe.
const ALCANCE := 5.4

signal jogador_chegou(portal: Node)
signal jogador_saiu(portal: Node)

@export var titulo := "Caverna da Primeira Ressonância"
@export var subtitulo := ""

var _perto := false


func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    add_to_group("portal_dungeon")

    var forma := CollisionShape3D.new()
    var esfera := SphereShape3D.new()
    esfera.radius = ALCANCE
    forma.shape = esfera
    forma.position.y = 1.4
    add_child(forma)

    body_entered.connect(_ao_entrar)
    body_exited.connect(_ao_sair)

    _erguer_o_arco()
    _abrir_o_vao()
    _acender()
    _escrever()


func _erguer_o_arco() -> void:
    var arco := ARCO.instantiate() as Node3D
    arco.scale = Vector3.ONE * ESCALA_DO_ARCO
    var pedra := StandardMaterial3D.new()
    pedra.albedo_texture = TEXTURA_ROCHA
    pedra.albedo_color = Color(0.62, 0.60, 0.66)
    pedra.roughness = 0.95
    pedra.uv1_scale = Vector3(0.6, 0.6, 0.6)
    for malha in arco.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        mi.material_override = pedra
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # A 90 m o arco e meia duzia de pixels e continuava sendo desenhado em
        # cinco lugares do mapa ao mesmo tempo.
        mi.visibility_range_end = 90.0
        mi.visibility_range_end_margin = 10.0
    add_child(arco)


## O redemoinho dentro do vao. E o mesmo shader dos portais entre zonas, para o
## jogador nao ter de aprender um segundo desenho de "aqui se atravessa".
func _abrir_o_vao() -> void:
    var vao := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(4.0, 4.0)
    vao.mesh = quad
    vao.position = Vector3(0.0, 2.5, 0.0)
    vao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    vao.visibility_range_end = 90.0
    vao.visibility_range_end_margin = 10.0
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/zone_portal.gdshader")
    # Roxo de caverna, e nao o azul das travessias entre zonas: a cor separa
    # "voce muda de regiao" de "voce entra na masmorra".
    mat.set_shader_parameter("portal_color", Color(0.42, 0.16, 0.72, 0.78))
    mat.set_shader_parameter("rune_color", Color(1.0, 0.82, 0.45, 1.0))
    mat.set_shader_parameter("swirl_speed", 1.4)
    vao.material_override = mat
    add_child(vao)


func _acender() -> void:
    var luz := OmniLight3D.new()
    luz.light_color = Color(0.72, 0.42, 1.0)
    luz.light_energy = 2.2
    luz.omni_range = 9.0
    luz.position = Vector3(0.0, 2.4, 0.0)
    luz.shadow_enabled = false
    # Cinco portais acesos o tempo todo custam caro num aparelho que ja esta no
    # limite. A luz se apaga sozinha longe do jogador, e o arco continua la.
    luz.distance_fade_enabled = true
    luz.distance_fade_begin = 26.0
    luz.distance_fade_length = 10.0
    add_child(luz)

    var fagulhas := CPUParticles3D.new()
    fagulhas.amount = 18
    fagulhas.lifetime = 2.4
    fagulhas.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
    fagulhas.emission_ring_axis = Vector3.UP
    fagulhas.emission_ring_radius = 2.1
    fagulhas.emission_ring_inner_radius = 1.5
    fagulhas.emission_ring_height = 0.2
    fagulhas.direction = Vector3.UP
    fagulhas.spread = 8.0
    fagulhas.initial_velocity_min = 0.3
    fagulhas.initial_velocity_max = 1.0
    fagulhas.gravity = Vector3(0.0, 0.35, 0.0)
    fagulhas.scale_amount_min = 0.4
    fagulhas.scale_amount_max = 1.0
    fagulhas.visibility_range_end = 46.0
    var q := QuadMesh.new()
    q.size = Vector2(0.22, 0.22)
    var m := StandardMaterial3D.new()
    m.albedo_texture = BRILHO
    m.albedo_color = Color(0.82, 0.55, 1.0)
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    q.material = m
    fagulhas.mesh = q
    fagulhas.position.y = 0.2
    add_child(fagulhas)


func _escrever() -> void:
    var nome := Label3D.new()
    nome.text = titulo
    nome.font_size = 46
    nome.outline_size = 10
    nome.modulate = Color(1.0, 0.88, 0.55)
    nome.outline_modulate = Color(0.10, 0.04, 0.16, 0.95)
    nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nome.pixel_size = 0.0075
    nome.position = Vector3(0.0, 6.1, 0.0)
    nome.visibility_range_end = 70.0
    add_child(nome)

    if subtitulo.is_empty():
        return
    var abaixo := Label3D.new()
    abaixo.text = subtitulo
    abaixo.font_size = 34
    abaixo.outline_size = 8
    abaixo.modulate = Color(0.78, 0.72, 0.92)
    abaixo.outline_modulate = Color(0.10, 0.04, 0.16, 0.95)
    abaixo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    abaixo.pixel_size = 0.0075
    abaixo.position = Vector3(0.0, 5.6, 0.0)
    abaixo.visibility_range_end = 46.0
    add_child(abaixo)


func _ao_entrar(corpo: Node3D) -> void:
    if _perto or not (corpo.is_in_group("jogador") or corpo.is_in_group("player")):
        return
    _perto = true
    jogador_chegou.emit(self)


func _ao_sair(corpo: Node3D) -> void:
    if not _perto or not (corpo.is_in_group("jogador") or corpo.is_in_group("player")):
        return
    _perto = false
    jogador_saiu.emit(self)
