extends Node3D

## Primeira DG: uma planta fixa e intencional, construída com peças modulares.
## Ela vive longe do mapa aberto e só é ativada quando o jogador entra.
const BICHO := preload("res://scripts/bicho.gd")
const BAU := preload("res://scripts/bau_dungeon.gd")

const SALA_PEQUENA := preload("res://assets/dungeon/kenney/room-small.glb")
const SALA_PEQUENA_B := preload("res://assets/dungeon/kenney/room-small-variation.glb")
const SALA_GRANDE := preload("res://assets/dungeon/kenney/room-large.glb")
const CORREDOR := preload("res://assets/dungeon/kenney/corridor-wide.glb")
const JUNCAO := preload("res://assets/dungeon/kenney/corridor-wide-junction.glb")
const PORTAO := preload("res://assets/dungeon/kenney/gate.glb")
const PORTA := preload("res://assets/dungeon/kenney/gate-door.glb")
const SALA_GRANDE_B := preload("res://assets/dungeon/kenney/room-large-variation.glb")
const CURVA := preload("res://assets/dungeon/kenney/corridor-wide-corner.glb")
const FUNDO_DE_SACO := preload("res://assets/dungeon/kenney/corridor-wide-end.glb")
const TOCHA_MESH := preload("res://assets/dungeon/quaternius/Torch.obj")
const CAIXOTE_MESH := preload("res://assets/dungeon/quaternius/Crate.obj")
const BARRIL_MESH := preload("res://assets/dungeon/quaternius/Barrel.obj")
const CAVEIRA_MESH := preload("res://assets/dungeon/quaternius/Skull.obj")
const BRILHO := preload("res://textures/brilho_poste.png")
const TEXTURA_ROCHA := preload("res://assets/dungeon/textures/rocha_caverna_1k.jpg")

const ORIGEM := Vector3(520.0, 0.0, 520.0)
const ENTRADA := Vector3(0.0, 1.15, 62.0)

var _jogador: CharacterBody3D
var _zona: Node3D
var _ambiente: WorldEnvironment
var _sol: DirectionalLight3D
var _minimapa: Control
var _barra_dia: Control
var _camera: Camera3D
var _dungeon: Node3D
var _botao: Button
var _dentro := false
var _posicao_de_retorno := Vector3.ZERO
var _ambiente_anterior: Environment
var _camera_transform_anterior := Transform3D.IDENTITY
var _camera_fov_anterior := 50.0
var _inimigos: Array[Node3D] = []
var _ate_atualizar_inimigos := 0.0
var _material_rocha: StandardMaterial3D
var _luz_da_caverna: DirectionalLight3D
var _ciclo: Node
var _ciclo_rodava := true


func _ready() -> void:
    _jogador = get_parent().get_node_or_null("Player") as CharacterBody3D
    _zona = get_parent().get_node_or_null("ZoneBuilder") as Node3D
    _ambiente = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
    _sol = get_parent().get_node_or_null("Sunlight") as DirectionalLight3D
    _ciclo = get_parent().get_node_or_null("CicloDiaNoite")
    _minimapa = get_parent().get_node_or_null("HUD/ZoneMinimap") as Control
    _barra_dia = get_parent().get_node_or_null("HUD/BarraDoDia") as Control
    _camera = get_parent().get_node_or_null("CameraRig/Camera3D") as Camera3D
    _construir_dungeon()
    _criar_botao_hud()


func _construir_dungeon() -> void:
    _dungeon = Node3D.new()
    _dungeon.name = "CavernaDaPrimeiraRessonancia"
    _dungeon.position = ORIGEM
    _dungeon.visible = false
    _dungeon.process_mode = Node.PROCESS_MODE_DISABLED
    add_child(_dungeon)

    # A PLANTA SEGUE O KIT, e nao o contrario.
    #
    # A caverna anterior foi desenhada sem medir as pecas, e por isso o jogador
    # ficava preso: o corredor deste kit tem parede ao NORTE e ao SUL, ou seja,
    # corre leste-oeste. Colocado sem giro no eixo principal, o que ficava na
    # frente de quem entrava era a lateral fechada dele — a "parede gigante".
    #
    # A segunda medida muda ainda mais: cada sala tem VAO DE PORTA no meio dos
    # quatro lados. Duas salas encostadas ja estao ligadas. E dai que sai o
    # salao: quatro salas grandes num quadrado dao quarenta metros de vao livre,
    # sem parede no meio. A caverna era so tubo de oito metros porque ninguem
    # tinha juntado salas.
    #
    # Nao ha mais caixa de colisao escrita a mao: a malha das pecas e a colisao,
    # entao onde ha porta ha passagem, e onde ha parede ha parede.
    _modulo(SALA_PEQUENA, Vector3(0, 0, 60))
    _corredor_z([50.0, 42.0])
    # TRES COLUNAS, e nao duas. A porta fica no MEIO de cada sala: com duas
    # colunas, o corredor do eixo chega em x=0, que e a emenda entre elas — e
    # emenda e parede dos dois lados. Com tres, a sala do meio esta no eixo e a
    # porta dela recebe o corredor. Era o que ainda prendia o jogador.
    _salao(Vector3(0, 0, 18), 3, 2)
    # As camaras laterais encostam nas salas das PONTAS, na mesma fileira: sala
    # vizinha so se abre quando os centros batem.
    _modulo(SALA_GRANDE_B, Vector3(40, 0, 8))
    _modulo(SALA_GRANDE_B, Vector3(-40, 0, 28))
    _modulo(SALA_PEQUENA_B, Vector3(40, 0, -8))
    _modulo(SALA_PEQUENA_B, Vector3(-40, 0, 44))
    _corredor_z([-6.0, -14.0])
    _salao(Vector3(0, 0, -38), 3, 2)

    _modulo(PORTAO, Vector3(0, 0, 54))
    _modulo(PORTAO, Vector3(0, 0, -17))

    _piso(Vector3(0, -0.18, 60), Vector3(12, 0.36, 12))
    _piso(Vector3(0, -0.18, 46), Vector3(8, 0.36, 20))
    _piso(Vector3(0, -0.18, 18), Vector3(60, 0.36, 40))
    _piso(Vector3(40, -0.18, 8), Vector3(20, 0.36, 20))
    _piso(Vector3(-40, -0.18, 28), Vector3(20, 0.36, 20))
    _piso(Vector3(40, -0.18, -8), Vector3(12, 0.36, 12))
    _piso(Vector3(-40, -0.18, 44), Vector3(12, 0.36, 12))
    _piso(Vector3(0, -0.18, -10), Vector3(8, 0.36, 20))
    _piso(Vector3(0, -0.18, -38), Vector3(60, 0.36, 40))
    _vazio_preto()

    for d in [[-4.7, 58.0, 0.0], [4.7, 58.0, PI], [-3.4, 46.0, 0.0], [3.4, 44.0, PI],
              [-17.0, 34.0, 0.0], [17.0, 34.0, PI], [-17.0, 2.0, 0.0], [17.0, 2.0, PI],
              [-38.0, 24.0, 0.0], [38.0, 24.0, PI], [-3.4, -10.0, 0.0], [3.4, -12.0, PI],
              [-17.0, -22.0, 0.0], [17.0, -22.0, PI], [-17.0, -54.0, 0.0], [17.0, -54.0, PI]]:
        _tocha(Vector3(d[0], 0.0, d[1]), d[2])

    for d in [[-14.0, 30.0, -0.2], [15.0, 26.0, 0.35], [-34.0, 22.0, -0.25],
              [33.0, 14.0, 0.1], [-28.0, -4.0, 0.3], [28.0, -6.0, -0.3],
              [-15.0, -30.0, 0.1], [16.0, -46.0, 0.45]]:
        _prop(CAIXOTE_MESH if int(absf(d[0])) % 2 == 0 else BARRIL_MESH,
            Vector3(d[0], 0.0, d[1]), d[2])
    _prop(CAVEIRA_MESH, Vector3(6.0, 0.04, -50.0), 0.4, 1.35)

    _bau(Vector3(-40.0, 0.0, 28.0), 250, false)
    _bau(Vector3(40.0, 0.0, 8.0), 350, true)
    _bau(Vector3(-40.0, 0.0, 44.0), 300, true)
    _bau(Vector3(40.0, 0.0, -8.0), 300, true)
    _bau(Vector3(0.0, 0.0, -54.0), 500, true)

    for onde in [Vector3(-2, 1.1, 44), Vector3(-12, 1.1, 28), Vector3(12, 1.1, 24),
                 Vector3(-8, 1.1, 8), Vector3(9, 1.1, 6), Vector3(-30, 1.1, 22),
                 Vector3(30, 1.1, 14), Vector3(-28, 1.1, -2), Vector3(28, 1.1, -4),
                 Vector3(-2, 1.1, -12), Vector3(-10, 1.1, -30), Vector3(10, 1.1, -30)]:
        _shiker(onde, 0 if int(onde.z) % 2 == 0 else 1)

    _construir_segundo_estagio()

    var chefe := _shiker(Vector3(0.0, 1.1, -44.0), 2)
    chefe.call_deferred("tornar_super_shiker")


## Uma fileira de corredores no eixo NORTE-SUL.
##
## O quarto de volta e obrigatorio: sem ele o corredor deita atravessado e a
## lateral fechada dele barra o caminho.
func _corredor_z(alturas: Array, x := 0.0) -> void:
    for z in alturas:
        _modulo(CORREDOR, Vector3(x, 0, float(z)), PI * 0.5)


## Um salao feito de salas encostadas.
##
## As portas ficam no meio de cada parede, entao salas vizinhas se abrem uma
## para a outra sozinhas — nao ha nada a recortar nem a esconder.
func _salao(centro: Vector3, colunas: int, linhas: int) -> void:
    var lado := 20.0
    for i in colunas:
        for j in linhas:
            _modulo(SALA_GRANDE, Vector3(
                centro.x + (float(i) - (colunas - 1) * 0.5) * lado, 0,
                centro.z + (float(j) - (linhas - 1) * 0.5) * lado))


## O SEGUNDO ESTAGIO, com o salao maior do jogo.
##
## Tres por duas salas: sessenta por quarenta metros de vao continuo. Fica cem
## metros ao norte, no mesmo no da caverna — sem cena nova e sem tela de espera.
const ESTAGIO_2 := Vector3(0.0, 0.0, -140.0)
const ENTRADA_ESTAGIO_2 := Vector3(0.0, 1.15, -112.0)

func _construir_segundo_estagio() -> void:
    var o := ESTAGIO_2

    _corredor_z([o.z + 28.0, o.z + 20.0])
    _salao(o + Vector3(0, 0, -10), 3, 2)
    _modulo(SALA_GRANDE_B, o + Vector3(-50, 0, -10))
    _modulo(SALA_GRANDE_B, o + Vector3(-70, 0, -10))
    _corredor_z([o.z - 34.0, o.z - 42.0])
    _salao(o + Vector3(0, 0, -66), 3, 2)

    _piso(o + Vector3(0, -0.18, 24), Vector3(8, 0.36, 20))
    _piso(o + Vector3(0, -0.18, -10), Vector3(60, 0.36, 40))
    _piso(o + Vector3(-60, -0.18, -10), Vector3(40, 0.36, 20))
    _piso(o + Vector3(0, -0.18, -38), Vector3(8, 0.36, 20))
    _piso(o + Vector3(0, -0.18, -66), Vector3(60, 0.36, 40))

    for d in [[-3.4, 24.0, 0.0], [3.4, 22.0, PI], [-27.0, 2.0, 0.0], [27.0, 2.0, PI],
              [-27.0, -22.0, 0.0], [27.0, -22.0, PI], [-58.0, -2.0, 0.0],
              [-78.0, -18.0, PI], [-3.4, -38.0, 0.0], [-17.0, -80.0, 0.0], [17.0, -80.0, PI]]:
        _tocha(o + Vector3(d[0], 0.0, d[1]), d[2])

    for d in [[-24.0, -6.0, 0.2], [23.0, -14.0, -0.3], [-54.0, -6.0, 0.4],
              [-66.0, -14.0, -0.2], [8.0, -60.0, 0.1], [-9.0, -72.0, 0.3]]:
        _prop(CAIXOTE_MESH if int(absf(d[0])) % 2 == 0 else BARRIL_MESH,
            o + Vector3(d[0], 0.0, d[1]), d[2])
    _prop(CAVEIRA_MESH, o + Vector3(-3.0, 0.04, -62.0), 0.7, 1.4)

    _bau(o + Vector3(-68.0, 0.0, -10.0), 600, true)
    _bau(o + Vector3(26.0, 0.0, -24.0), 400, true)
    _bau(o + Vector3(0.0, 0.0, -78.0), 900, true)

    for onde in [Vector3(-14, 1.1, 4), Vector3(14, 1.1, 2), Vector3(-26, 1.1, -12),
                 Vector3(26, 1.1, -8), Vector3(-2, 1.1, -22), Vector3(-52, 1.1, -8),
                 Vector3(-70, 1.1, -14), Vector3(4, 1.1, -40), Vector3(-8, 1.1, -60),
                 Vector3(8, 1.1, -60)]:
        _shiker(o + onde, 1)

    var guardiao := _shiker(o + Vector3(0.0, 1.1, -70.0), 2)
    guardiao.call_deferred("tornar_super_shiker")

    _porta_de_estagio(Vector3(0.0, 0.0, -58.0), ORIGEM + ENTRADA_ESTAGIO_2, "Descer")
    _porta_de_estagio(o + Vector3(0.0, 0.0, 32.0), ORIGEM + Vector3(0.0, 1.15, -30.0), "Subir")


## Uma porta que leva de um estagio a outro.
##
## Vao com folha, letreiro e area: encostou, muda de estagio. Nao ha
## carregamento porque nao ha cena nova — o segundo estagio ja esta construido,
## so longe.
func _porta_de_estagio(onde: Vector3, destino: Vector3, rotulo: String) -> void:
    _modulo(PORTA, onde)

    var aviso := Label3D.new()
    aviso.text = rotulo
    aviso.font_size = 34
    aviso.outline_size = 8
    aviso.modulate = Color(1.0, 0.86, 0.45)
    aviso.outline_modulate = Color(0.12, 0.06, 0.0, 0.95)
    aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    aviso.position = onde + Vector3.UP * 3.4
    _dungeon.add_child(aviso)

    var area := Area3D.new()
    area.collision_layer = 0
    area.collision_mask = 1
    area.position = onde
    var forma := CollisionShape3D.new()
    var caixa := BoxShape3D.new()
    caixa.size = Vector3(6.0, 4.0, 2.0)
    forma.shape = caixa
    forma.position.y = 2.0
    area.add_child(forma)
    area.body_entered.connect(func(corpo: Node3D):
        if not (corpo.is_in_group("jogador") or corpo.is_in_group("player")):
            return
        if _jogador == null:
            return
        _jogador.global_position = destino
        _jogador.velocity = Vector3.ZERO)
    _dungeon.add_child(area)


func _modulo(cena: PackedScene, onde: Vector3, giro := 0.0) -> void:
    var no := cena.instantiate() as Node3D
    no.position = onde
    no.rotation.y = giro
    var malhas := no.find_children("*", "MeshInstance3D", true, false)
    for malha in malhas:
        malha.material_override = _material_da_rocha()
        malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        malha.visibility_range_end = 70.0
        malha.visibility_range_end_margin = 6.0
    _dungeon.add_child(no)

    # A COLISAO E A PROPRIA MALHA. Medi o kit antes de confiar nisso: o miolo de
    # cada parede de sala tem vinte e quatro vertices — so o batente da porta —
    # contra mil e duzentos da parede inteira. Ou seja, ha vao em todos os
    # lados, e a malha nao lacra nada.
    for malha in malhas:
        (malha as MeshInstance3D).create_trimesh_collision()


func _material_da_rocha() -> StandardMaterial3D:
    if _material_rocha != null:
        return _material_rocha
    _material_rocha = StandardMaterial3D.new()
    _material_rocha.albedo_texture = TEXTURA_ROCHA
    _material_rocha.albedo_color = Color(0.68, 0.72, 0.78)
    _material_rocha.roughness = 0.94
    _material_rocha.metallic = 0.0
    # Projecao triplanar evita depender do pequeno atlas de cores do kit e
    # mantém pedra nítida em paredes, chão e peças giradas.
    _material_rocha.uv1_triplanar = true
    _material_rocha.uv1_scale = Vector3(0.48, 0.48, 0.48)
    _material_rocha.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return _material_rocha


func _piso(onde: Vector3, tamanho: Vector3) -> void:
    var corpo := StaticBody3D.new()
    corpo.position = onde
    var colisao := CollisionShape3D.new()
    var forma := BoxShape3D.new()
    forma.size = tamanho
    colisao.shape = forma
    corpo.add_child(colisao)
    _dungeon.add_child(corpo)


func _vazio_preto() -> void:
    var fundo := MeshInstance3D.new()
    var caixa := BoxMesh.new()
    caixa.size = Vector3(180, 0.2, 180)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.002, 0.003, 0.008)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    caixa.material = mat
    fundo.mesh = caixa
    fundo.position.y = -0.75
    fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _dungeon.add_child(fundo)


func _prop(malha: Mesh, onde: Vector3, giro := 0.0, escala := 1.0) -> void:
    var no := MeshInstance3D.new()
    no.mesh = malha
    no.position = onde
    no.rotation.y = giro
    no.scale = Vector3.ONE * escala
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    no.visibility_range_end = 36.0
    for superficie in range(malha.get_surface_count()):
        var mat := StandardMaterial3D.new()
        if malha == CAVEIRA_MESH:
            mat.albedo_color = Color(0.72, 0.67, 0.52)
            mat.roughness = 0.95
        elif malha == TOCHA_MESH and superficie > 0:
            mat.albedo_color = Color(1.0, 0.25, 0.04)
            mat.emission_enabled = true
            mat.emission = Color(1.0, 0.16, 0.02)
            mat.emission_energy_multiplier = 1.4
            mat.roughness = 0.6
        elif malha == TOCHA_MESH:
            mat.albedo_color = Color(0.18, 0.15, 0.17)
            mat.metallic = 0.45
            mat.roughness = 0.55
        else:
            mat.albedo_color = Color(0.34, 0.15, 0.055) if superficie % 2 == 0 else Color(0.16, 0.07, 0.035)
            mat.roughness = 0.92
        no.set_surface_override_material(superficie, mat)
    _dungeon.add_child(no)


func _tocha(onde: Vector3, giro: float) -> void:
    _prop(TOCHA_MESH, onde + Vector3.UP * 1.2, giro, 1.25)
    var brilho := MeshInstance3D.new()
    var quadro := QuadMesh.new()
    quadro.size = Vector2(3.0, 3.0)
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = BRILHO
    mat.albedo_color = Color(1.0, 0.42, 0.10, 0.85)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.25, 0.04)
    mat.emission_energy_multiplier = 1.5
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    quadro.material = mat
    brilho.mesh = quadro
    brilho.position = onde + Vector3.UP * 2.0
    brilho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _dungeon.add_child(brilho)

    # Uma luz pontual por tocha. Na caverna ela FAZ diferenca — diferente do
    # mundo aberto, aqui nao ha sol competindo, e e a luz que da volume as
    # paredes e diz onde o corredor vira.
    var luz := OmniLight3D.new()
    luz.light_color = Color(1.0, 0.72, 0.42)
    luz.light_energy = 2.6
    luz.omni_range = 13.0
    luz.omni_attenuation = 1.1
    luz.shadow_enabled = false
    luz.position = onde + Vector3.UP * 2.1
    _dungeon.add_child(luz)


func _bau(onde: Vector3, recompensa: int, ouro: bool) -> void:
    var bau := BAU.new()
    bau.position = onde
    bau.recompensa_claves = recompensa
    bau.dourado = ouro
    _dungeon.add_child(bau)


func _shiker(onde: Vector3, tipo: int) -> Node3D:
    var inimigo := BICHO.new()
    inimigo.position = onde
    inimigo.monster_type = tipo
    _dungeon.add_child(inimigo)
    _inimigos.append(inimigo)
    inimigo.process_mode = Node.PROCESS_MODE_DISABLED
    return inimigo


func _process(delta: float) -> void:
    if not _dentro or _jogador == null:
        return
    _ate_atualizar_inimigos -= delta
    if _ate_atualizar_inimigos > 0.0:
        return
    _ate_atualizar_inimigos = 0.35
    for inimigo in _inimigos:
        if not is_instance_valid(inimigo):
            continue
        var distancia := inimigo.global_position.distance_to(_jogador.global_position)
        inimigo.visible = distancia < 46.0
        inimigo.process_mode = Node.PROCESS_MODE_INHERIT if distancia < 30.0 else Node.PROCESS_MODE_DISABLED


func _criar_botao_hud() -> void:
    var hud := get_parent().get_node_or_null("HUD")
    if hud == null:
        return
    _botao = Button.new()
    _botao.name = "BtnDungeon"
    _botao.text = "DG\nCAVERNA"
    _botao.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _botao.position = Vector2(18, 118)
    _botao.size = Vector2(108, 58)
    _botao.add_theme_font_size_override("font_size", 15)
    _botao.add_theme_color_override("font_color", Color(1.0, 0.87, 0.50))
    _botao.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.08))
    _botao.add_theme_constant_override("outline_size", 4)
    var caixa := StyleBoxFlat.new()
    caixa.bg_color = Color(0.035, 0.025, 0.09, 0.94)
    caixa.border_color = Color(0.70, 0.48, 0.16, 0.96)
    caixa.set_border_width_all(2)
    caixa.set_corner_radius_all(12)
    _botao.add_theme_stylebox_override("normal", caixa)
    _botao.add_theme_stylebox_override("hover", caixa)
    _botao.add_theme_stylebox_override("pressed", caixa)
    _botao.pressed.connect(_alternar)
    hud.add_child(_botao)


func _alternar() -> void:
    if _dentro:
        _sair()
    else:
        _entrar()


func _entrar() -> void:
    if _jogador == null:
        return
    _posicao_de_retorno = _jogador.global_position
    _dentro = true
    _dungeon.visible = true
    _dungeon.process_mode = Node.PROCESS_MODE_INHERIT
    if _zona:
        _zona.visible = false
        _zona.process_mode = Node.PROCESS_MODE_DISABLED
    if _sol:
        _sol.visible = false
    if _minimapa:
        _minimapa.visible = false
    if _barra_dia:
        _barra_dia.visible = false
    if _camera:
        _camera_transform_anterior = _camera.transform
        _camera_fov_anterior = _camera.fov
        # MAIS LATERAL que a de cima do mundo aberto: a caverna e feita de
        # paredes, e camera muito no alto so mostra o chao delas. Baixando o
        # olho de 42 para 32 graus, a parede aparece e o corredor ganha
        # profundidade.
        _camera.position = Vector3(0.0, 8.6, 13.8)
        _camera.fov = 55.0
    # O RELOGIO PARA NA PORTA DA CAVERNA.
    #
    # Aqui estava o motivo de a caverna nao clarear por mais que eu subisse a
    # energia do ambiente: o ciclo do dia reescreve cor, energia e nevoa do
    # WorldEnvironment A CADA QUADRO. A caverna trocava o ambiente e, no quadro
    # seguinte, levava a noite de volta por cima. Debaixo da terra nao ha
    # amanhecer para simular, entao o relogio simplesmente descansa.
    if _ciclo:
        _ciclo_rodava = bool(_ciclo.get("rodando"))
        _ciclo.set("rodando", false)

    _aplicar_ambiente_da_caverna()
    var destino := ENTRADA
    if OS.get_cmdline_user_args().has("--boss"):
        destino = Vector3(0.0, 1.15, -52.0)
    if OS.get_cmdline_user_args().has("--parede"):
        destino = Vector3(0.0, 1.15, 20.0)
    _jogador.global_position = ORIGEM + destino
    _jogador.velocity = Vector3.ZERO
    _botao.text = "SAIR\nDA DG"


func _sair() -> void:
    _dentro = false
    _jogador.global_position = _posicao_de_retorno + Vector3.UP * 0.4
    _jogador.velocity = Vector3.ZERO
    _dungeon.visible = false
    _dungeon.process_mode = Node.PROCESS_MODE_DISABLED
    if _zona:
        _zona.visible = true
        _zona.process_mode = Node.PROCESS_MODE_INHERIT
    if _sol:
        _sol.visible = true
    if _luz_da_caverna:
        _luz_da_caverna.visible = false
    if _minimapa:
        _minimapa.visible = true
    if _barra_dia:
        _barra_dia.visible = true
    if _camera:
        _camera.transform = _camera_transform_anterior
        _camera.fov = _camera_fov_anterior
    if _ambiente and _ambiente_anterior:
        _ambiente.environment = _ambiente_anterior
    if _ciclo:
        _ciclo.set("rodando", _ciclo_rodava)
    _botao.text = "DG\nCAVERNA"


func _aplicar_ambiente_da_caverna() -> void:
    if _ambiente == null:
        return
    if _ambiente_anterior == null:
        _ambiente_anterior = _ambiente.environment
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.001, 0.002, 0.008)
    env.background_energy_multiplier = 0.05
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    # SEM ISTO A COR NAO VALE NADA. O ambiente por cor so entra na conta quando
    # a contribuicao do ceu vai a zero; com o padrao em 1, o motor continua
    # tirando a luz do fundo — que aqui e quase preto. Foi por isso que subir a
    # energia do ambiente nao clareou a caverna.
    env.ambient_light_sky_contribution = 0.0
    # CLAREOU. A caverna estava num escuro que nao e clima, e sim dificuldade de
    # leitura: o jogador perdia parede, bau e bicho no mesmo breu. Caverna de
    # jogo e convencao, nao fotometria — o preto fica nos cantos, e o caminho
    # precisa ser visto.
    env.ambient_light_color = Color(0.34, 0.40, 0.55)
    env.ambient_light_energy = 1.25
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.12
    env.fog_enabled = true
    env.fog_light_color = Color(0.10, 0.14, 0.24)
    env.fog_light_energy = 0.45
    # Nevoa mais rala: a densidade antiga apagava a sala inteira a doze metros,
    # e sala que nao se ve nao se explora.
    env.fog_density = 0.009
    _ambiente.environment = env

    # A LUZ DE PRESENCA da caverna.
    #
    # Ambiente sozinho chapa tudo: ilumina por igual e nao desenha volume, entao
    # parede e chao viram a mesma mancha. Uma direcional fraca, vinda de cima e
    # de lado, devolve sombra propria as pedras — e como o sol do mundo fica
    # escondido enquanto se joga aqui, ela nao briga com nada.
    if _luz_da_caverna == null:
        _luz_da_caverna = DirectionalLight3D.new()
        _luz_da_caverna.name = "LuzDaCaverna"
        _luz_da_caverna.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
        _luz_da_caverna.light_color = Color(0.62, 0.70, 0.92)
        _luz_da_caverna.light_energy = 0.85
        _luz_da_caverna.shadow_enabled = false
        add_child(_luz_da_caverna)
    _luz_da_caverna.visible = true
