extends Node3D

## Primeira DG: planta expansiva, corredores longos e laje visual contínua.
## Vive longe do mapa aberto e só é ativada quando o jogador entra.
const BICHO := preload("res://scripts/bicho.gd")
const BAU := preload("res://scripts/bau_dungeon.gd")

const SALA_PEQUENA := preload("res://models/cc0/cave/room-small.glb")
const SALA_PEQUENA_B := preload("res://models/cc0/cave/room-small-variation.glb")
const SALA_GRANDE := preload("res://models/cc0/cave/room-large.glb")
const CORREDOR := preload("res://models/cc0/cave/corridor-wide.glb")
const JUNCAO := preload("res://models/cc0/cave/corridor-wide-junction.glb")
const PORTAO := preload("res://models/cc0/cave/gate.glb")
const PORTA := preload("res://models/cc0/cave/gate-metal-bars.glb")
const SALA_GRANDE_B := preload("res://models/cc0/cave/room-large-variation.glb")
const CURVA := preload("res://models/cc0/cave/corridor-wide-corner.glb")
const FUNDO_DE_SACO := preload("res://models/cc0/cave/corridor-wide-end.glb")

const TOCHA_MESH := preload("res://assets/dungeon/quaternius/Torch.obj")
const CAIXOTE_MESH := preload("res://assets/dungeon/quaternius/Crate.obj")
const BARRIL_MESH := preload("res://assets/dungeon/quaternius/Barrel.obj")
const CAVEIRA_MESH := preload("res://assets/dungeon/quaternius/Skull.obj")
const CRISTAL_MESH := preload("res://models/crystal_cluster_1787078933118.glb")
const SACO_MESH := preload("res://models/saco_vila.glb")
const BARRIS_VILA := preload("res://models/barris_vila.glb")
const CAIXOTES_VILA := preload("res://models/caixotes_vila.glb")

const BRILHO := preload("res://textures/brilho_poste.png")
const TEXTURA_ROCHA := preload("res://assets/dungeon/textures/rocha_caverna_1k.jpg")

const ORIGEM := Vector3(520.0, 0.0, 520.0)
const ENTRADA := Vector3(0.0, 1.15, 78.0)

var _jogador: CharacterBody3D
var _zona: Node3D
var _ambiente: WorldEnvironment
var _sol: DirectionalLight3D
var _minimapa: Control
var _barra_dia: Control
var _camera: Camera3D
var _dungeon: Node3D
var _botao: Button
var _placar: Label
var _botoes_dificuldade: Array[Button] = []
var _shikers_totais := 0
var _dentro := false
var _posicao_de_retorno := Vector3.ZERO
var _ambiente_anterior: Environment
var _camera_transform_anterior := Transform3D.IDENTITY
var _camera_fov_anterior := 50.0
var _inimigos: Array[Node3D] = []
var _ate_atualizar_inimigos := 0.0
var _material_rocha: StandardMaterial3D
var _material_cristal: StandardMaterial3D
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


## A PLANTA, num grid que fecha.
##
## A anterior nao fechava. Os modulos do kit medem 20 m (sala grande), 12 m
## (sala pequena) e 8 m (corredor), e a planta antiga punha corredor em x = 32 e
## 40 para alcancar uma sala centrada em x = 50: o corredor terminava em 44 e a
## sala comecava em 40, quatro metros DENTRO um do outro. Media isso em dez
## juncoes. Modulo dentro de modulo e parede dentro de parede — e como um
## corredor de quatro metros de vao livre passa a parecer um funil.
##
## Aqui cada peca encosta na seguinte com a folga de 0,23 m que o proprio kit
## desenhou, e nada mais. As contas estao anotadas em cada linha: sempre a
## borda de quem veio antes.
##
## A OUTRA METADE DO PROBLEMA ERA O BICHO. Dois golems nasciam no corredor de
## entrada, que tem 4 m de vao: com a capsula do golem no meio, sobrava um metro
## de cada lado e o jogador tinha de raspar na parede para passar. Nenhum bicho
## nasce em corredor agora — corredor e passagem, sala e onde se briga. E a
## posicao sai do CENTRO de um modulo de sala, com folga da parede, em vez do
## cos/sen de indice que a versao anterior usava e que nao sabia onde havia
## parede.

## Vao livre do corredor, medido na malha: as paredes comem quase metade dos 8 m
## do modulo. E o numero que decide que corredor nao e lugar de encontro.
const VAO_DO_CORREDOR := 4.1
## Folga da parede para qualquer coisa que nasca dentro de uma sala.
const FOLGA_DA_PAREDE := 3.5


func _construir_dungeon() -> void:
    _dungeon = Node3D.new()
    _dungeon.name = "CavernaDaPrimeiraRessonancia"
    _dungeon.position = ORIGEM
    _dungeon.visible = false
    _dungeon.process_mode = Node.PROCESS_MODE_DISABLED
    add_child(_dungeon)

    # ---------------------------------------------------------- ESTAGIO 1
    # ENTRADA -> corredor curto -> SALA A (primeiro encontro) -> corredor ->
    # SALAO B (com duas alas de tesouro) -> corredor -> ARENA DO CHEFE.
    _modulo(SALA_PEQUENA, Vector3(0, 0, 78))          # z 72,0 .. 84,0
    _corredor_z([68.0, 60.0])                         # z 55,9 .. 72,1
    _modulo(PORTAO, Vector3(0, 0, 56.0))              # o arco fica na emenda
    var sala_a := _salao(Vector3(0, 0, 36), 1, 2)     # 20x40   z 15,9 .. 56,1
    _corredor_z([12.0, 4.0])                          # z -0,1 .. 16,1
    var salao_b := _salao(Vector3(0, 0, -20), 3, 2)   # 60x40   z -40,1 .. 0,1

    # Alas: saem da borda x = +-30 do salao, alinhadas com a porta do modulo.
    #
    # Camara GRANDE, e nao a pequena. A sala de 12 m tem so 6 m de vao livre
    # depois das paredes: com um golem e um bau dentro, o jogador nao tinha por
    # onde circular para lutar — era o mesmo aperto do corredor, com porta.
    _corredor_x([34.0, 42.0], -10.0)                  # x 29,9 .. 46,1
    _modulo(SALA_GRANDE_B, Vector3(56, 0, -10))       # x 46,0 .. 66,0
    _corredor_x([-34.0, -42.0], -30.0)
    _modulo(SALA_GRANDE_B, Vector3(-56, 0, -30))

    _corredor_z([-44.0, -52.0])                       # z -56,1 .. -39,9
    _modulo(PORTAO, Vector3(0, 0, -56.0))
    var arena := _salao(Vector3(0, 0, -76), 3, 2)     # 60x40   z -96,1 .. -55,9

    _laje_visual_e_solida(Vector3(0, -0.2, -4), Vector3(156, 0.4, 196))
    _cercar(Vector3(0, 0, -4), Vector2(156, 196))
    _vazio_preto()

    _acender_as_salas(sala_a + salao_b + arena)
    _acender_o_corredor([Vector3(0, 0, 64), Vector3(0, 0, 8), Vector3(0, 0, -48)])
    _acender_o_corredor([Vector3(38, 0, -10), Vector3(-38, 0, -30)], true)
    _acender_as_salas([Vector3(56, 0, -10), Vector3(-56, 0, -30)])

    _enfeitar(sala_a, [Color(0.6, 0.4, 1.0), Color(0.4, 0.7, 1.0)])
    _enfeitar(salao_b, [Color(0.8, 0.4, 1.0), Color(0.4, 0.8, 1.0), Color(1.0, 0.5, 0.8)])
    _enfeitar(arena, [Color(1.0, 0.4, 0.7), Color(0.4, 0.7, 1.0)])
    _enfeitar([Vector3(56, 0, -10), Vector3(-56, 0, -30)], [Color(0.4, 0.9, 1.0)], 6.5)

    # BAUS: um por ala, e o do fundo da arena.
    _bau(Vector3(56.0, 0.0, -6.0), 350, true)
    _bau(Vector3(-56.0, 0.0, -26.0), 350, true)
    _bau(Vector3(0.0, 0.0, -90.0), 600, true)

    # MONSTROS. Nenhum em corredor; todos a partir do centro de um modulo.
    for onde in [Vector3(-5, 1.1, 48), Vector3(5, 1.1, 40), Vector3(-5, 1.1, 26)]:
        _shiker(onde, 0)                              # primeiro encontro, leve
    var guardas_b := [
        [Vector3(-20, 1.1, -12), 1], [Vector3(20, 1.1, -8), 0],
        [Vector3(-20, 1.1, -32), 3], [Vector3(0, 1.1, -33), 1],
        [Vector3(20, 1.1, -31), 3],
    ]
    for g in guardas_b:
        _shiker(g[0], int(g[1]))
    _shiker(Vector3(56, 1.1, -14), 3)                 # guarda de cada ala
    _shiker(Vector3(-56, 1.1, -34), 3)

    _shiker(Vector3(-20, 1.1, -68), 3)
    _shiker(Vector3(20, 1.1, -68), 3)
    _shiker(Vector3(-16, 1.1, -80), 1)
    _shiker(Vector3(16, 1.1, -80), 1)
    var chefe := _shiker(Vector3(0.0, 1.1, -80.0), 2)
    chefe.call_deferred("tornar_super_shiker")

    _vestir_salas(salao_b + arena)
    _construir_segundo_estagio()


## O SEGUNDO ESTAGIO: antessala, salao com duas criptas a oeste e o santuario.
const ESTAGIO_2 := Vector3(0.0, 0.0, -180.0)
const ENTRADA_ESTAGIO_2 := Vector3(0.0, 1.15, -144.0)

func _construir_segundo_estagio() -> void:
    var o := ESTAGIO_2

    _corredor_z([o.z + 36.0, o.z + 28.0])                 # z o+23,9 .. o+40,1
    _modulo(PORTAO, o + Vector3(0, 0, 24.0))
    var antessala := _salao(o + Vector3(0, 0, 4), 1, 2)   # 20x40  z o-16,1 .. o+14,1
    _corredor_z([o.z - 20.0, o.z - 28.0])                 # z o-32,1 .. o-15,9
    var salao_c := _salao(o + Vector3(0, 0, -52), 3, 2)   # 60x40  z o-72,1 .. o-31,9

    # As criptas do oeste, uma atras da outra, saindo da borda x = -30.
    _corredor_x([-34.0, -42.0], o.z - 42.0)               # x -46,1 .. -29,9
    _modulo(SALA_GRANDE_B, o + Vector3(-56, 0, -42))      # x -66,0 .. -46,0
    _corredor_x([-70.0, -78.0], o.z - 42.0)               # x -82,1 .. -65,9
    _modulo(SALA_GRANDE_B, o + Vector3(-92, 0, -42))      # x -102,0 .. -82,0

    _corredor_z([o.z - 76.0, o.z - 84.0])                 # z o-88,1 .. o-71,9
    _modulo(PORTAO, o + Vector3(0, 0, -88.0))
    var santuario := _salao(o + Vector3(0, 0, -108), 3, 2)

    _laje_visual_e_solida(o + Vector3(-36, -0.2, -41), Vector3(144, 0.4, 186))
    _cercar(o + Vector3(-36, 0, -41), Vector2(144, 186))

    _acender_as_salas(antessala + salao_c + santuario
        + [o + Vector3(-56, 0, -42), o + Vector3(-92, 0, -42)])
    _acender_o_corredor([o + Vector3(0, 0, 32), o + Vector3(0, 0, -24),
        o + Vector3(0, 0, -80)])
    _acender_o_corredor([o + Vector3(-38, 0, -42), o + Vector3(-74, 0, -42)], true)

    _enfeitar(antessala, [Color(0.5, 0.8, 1.0), Color(0.9, 0.4, 1.0)])
    _enfeitar(salao_c, [Color(0.4, 0.9, 0.8), Color(1.0, 0.6, 0.3), Color(0.8, 0.3, 1.0)])
    _enfeitar([o + Vector3(-56, 0, -42), o + Vector3(-92, 0, -42)],
        [Color(1.0, 0.3, 0.9), Color(1.0, 0.8, 0.4)])
    _enfeitar(santuario, [Color(1.0, 0.8, 0.4), Color(0.4, 0.9, 1.0)])

    _bau(o + Vector3(-56.0, 0.0, -38.0), 500, true)
    _bau(o + Vector3(-92.0, 0.0, -44.0), 750, true)
    _bau(o + Vector3(26.0, 0.0, -62.0), 500, true)
    # O tesouro do fundo: e ele que registra a incursao como concluida.
    _bau(o + Vector3(0.0, 0.0, -122.0), 1000, true, true)

    _shiker(o + Vector3(-5, 1.1, 8), 4)
    _shiker(o + Vector3(5, 1.1, -6), 4)
    for g in [[Vector3(-20, 1.1, -44), 4], [Vector3(0, 1.1, -55), 2],
              [Vector3(20, 1.1, -40), 2], [Vector3(20, 1.1, -62), 4]]:
        _shiker(o + g[0], int(g[1]))
    _shiker(o + Vector3(-56, 1.1, -46), 5)
    _shiker(o + Vector3(-92, 1.1, -38), 4)
    _shiker(o + Vector3(-92, 1.1, -48), 5)

    _shiker(o + Vector3(-20, 1.1, -100), 4)
    _shiker(o + Vector3(20, 1.1, -100), 4)
    _shiker(o + Vector3(-16, 1.1, -112), 4)
    _shiker(o + Vector3(16, 1.1, -112), 4)
    var guardiao := _shiker(o + Vector3(0.0, 1.1, -112.0), 5)
    guardiao.call_deferred("tornar_super_shiker")

    _vestir_salas(salao_c + santuario)

    # Portas de transicao entre estagios, nas bordas de fundo de cada arena.
    _porta_de_estagio(Vector3(0.0, 0.0, -94.0), ORIGEM + ENTRADA_ESTAGIO_2,
        "DESCER AO SEGUNDO ESTAGIO")
    _porta_de_estagio(o + Vector3(0.0, 0.0, 12.0), ORIGEM + Vector3(0.0, 1.15, -70.0),
        "VOLTAR AO PRIMEIRO ESTAGIO")


## Duas tochas por sala, nas paredes laterais — derivadas da planta, e nao de uma
## lista escrita a mao. A lista antiga tinha 33 posicoes fixas que ja nao batiam
## com sala nenhuma depois que os modulos se moveram: havia tocha acesa no meio
## do nada e sala grande sem nenhuma.
func _acender_as_salas(centros: Array) -> void:
    for c in centros:
        var centro: Vector3 = c
        _tocha(centro + Vector3(-8.6, 0.0, 0.0), 0.0)
        _tocha(centro + Vector3(8.6, 0.0, 0.0), PI)


## Tochas de corredor, uma de cada lado do vao. `deitado` vale para o corredor
## que corre em X.
func _acender_o_corredor(pontos: Array, deitado := false) -> void:
    for p in pontos:
        var onde: Vector3 = p
        if deitado:
            _tocha(onde + Vector3(0.0, 0.0, -3.4), -PI * 0.5)
            _tocha(onde + Vector3(0.0, 0.0, 3.4), PI * 0.5)
        else:
            _tocha(onde + Vector3(-3.4, 0.0, 0.0), 0.0)
            _tocha(onde + Vector3(3.4, 0.0, 0.0), PI)


## Cristal e pilha de provisoes dentro de cada sala, longe da parede e longe do
## meio (onde o jogador anda e onde o bicho nasce).
func _enfeitar(centros: Array, cores: Array, alcance := 6.5) -> void:
    var i := 0
    for c in centros:
        var centro: Vector3 = c
        var cor: Color = cores[i % cores.size()]
        var giro := float(i) * 1.3
        _cristal(centro + Vector3(cos(giro) * alcance, 0.0, sin(giro) * alcance),
            giro, 1.1 + float(i % 3) * 0.2, cor)
        _pilha_provisoes(centro + Vector3(-cos(giro) * alcance, 0.0, -sin(giro) * alcance),
            -giro)
        if i % 3 == 0:
            _prop(CAVEIRA_MESH, centro + Vector3(sin(giro) * alcance, 0.04,
                -cos(giro) * alcance), giro, 1.3)
        i += 1


## Laje visual e sólida: uma base contínua com colisão e malha de rocha texturizada.
## Garante zero frestas ou ausência visual de chão sob toda a masmorra.
func _laje_visual_e_solida(centro: Vector3, tamanho: Vector3) -> void:
    # 1. Colisão sólida
    var corpo := StaticBody3D.new()
    corpo.position = centro
    var colisao := CollisionShape3D.new()
    var forma := BoxShape3D.new()
    forma.size = tamanho
    colisao.shape = forma
    corpo.add_child(colisao)
    _dungeon.add_child(corpo)

    # 2. Malha visual com textura triplanar de rocha
    var visual := MeshInstance3D.new()
    var caixa_mesh := BoxMesh.new()
    caixa_mesh.size = tamanho
    visual.mesh = caixa_mesh
    visual.material_override = _material_da_rocha()
    visual.position = centro
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _dungeon.add_child(visual)


func _cercar(centro: Vector3, tamanho: Vector2) -> void:
    var meia_x: float = tamanho.x * 0.5
    var meia_z: float = tamanho.y * 0.5
    for lado in [Vector3(meia_x, 0, 0), Vector3(-meia_x, 0, 0)]:
        _parede_invisivel(centro + lado, Vector3(1.0, 12.0, tamanho.y))
    for lado in [Vector3(0, 0, meia_z), Vector3(0, 0, -meia_z)]:
        _parede_invisivel(centro + lado, Vector3(tamanho.x, 12.0, 1.0))


func _parede_invisivel(onde: Vector3, tamanho: Vector3) -> void:
    var corpo := StaticBody3D.new()
    corpo.position = onde + Vector3.UP * 6.0
    var colisao := CollisionShape3D.new()
    var forma := BoxShape3D.new()
    forma.size = tamanho
    colisao.shape = forma
    corpo.add_child(colisao)
    _dungeon.add_child(corpo)


func _vestir_salas(centros: Array) -> void:
    for i in centros.size():
        var c: Vector3 = centros[i]
        if i % 2 == 0:
            _modulo(PORTAO, c + Vector3(0, 0, 10.0))
        _tocha(c + Vector3(-8.6, 0, -2.0 + float(i % 3)), 0.0)
        _tocha(c + Vector3(8.6, 0, 2.0 - float(i % 3)), PI)
        var canto := Vector3(6.5 * (1.0 if i % 2 else -1.0), 0.0, -6.5)
        _prop(CAIXOTE_MESH if i % 3 else BARRIL_MESH, c + canto, float(i) * 0.7)
        if i % 4 == 0:
            _prop(CAVEIRA_MESH, c + Vector3(-canto.x * 0.8, 0.04, canto.z + 1.4),
                float(i) * 1.1, 1.15)


func _corredor_z(alturas: Array, x := 0.0) -> void:
    for z in alturas:
        _modulo(CORREDOR, Vector3(x, 0, float(z)), PI * 0.5)


func _corredor_x(posicoes_x: Array, z := 0.0) -> void:
    for x in posicoes_x:
        _modulo(CORREDOR, Vector3(float(x), 0, z), 0.0)


## Monta um salao e DEVOLVE o centro de cada modulo.
##
## Devolver a lista e o que permite tocha, cristal e bicho sairem da propria
## planta. Antes cada um tinha a sua lista de coordenadas escrita a mao, e as
## tres desencontravam da geometria assim que um modulo saia do lugar.
func _salao(centro: Vector3, colunas: int, linhas: int) -> Array:
    var lado := 20.0
    var centros: Array = []
    for i in colunas:
        for j in linhas:
            var onde := Vector3(
                centro.x + (float(i) - (colunas - 1) * 0.5) * lado, 0,
                centro.z + (float(j) - (linhas - 1) * 0.5) * lado)
            _modulo(SALA_GRANDE, onde)
            centros.append(onde)
    return centros


func _porta_de_estagio(onde: Vector3, destino: Vector3, rotulo: String) -> void:
    _modulo(PORTA, onde)
    _tocha(onde + Vector3(-3.2, 0.0, 0.0), 0.0)
    _tocha(onde + Vector3(3.2, 0.0, 0.0), PI)

    var aviso := Label3D.new()
    aviso.text = rotulo
    aviso.font_size = 52
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
    _material_rocha.uv1_triplanar = true
    _material_rocha.uv1_scale = Vector3(0.48, 0.48, 0.48)
    _material_rocha.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return _material_rocha


func _vazio_preto() -> void:
    var fundo := MeshInstance3D.new()
    var caixa := BoxMesh.new()
    caixa.size = Vector3(300, 0.2, 300)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.002, 0.003, 0.008)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    caixa.material = mat
    fundo.mesh = caixa
    fundo.position.y = -1.2
    fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _dungeon.add_child(fundo)


func _prop(malha: Mesh, onde: Vector3, giro := 0.0, escala := 1.0) -> void:
    var no := MeshInstance3D.new()
    no.mesh = malha
    no.position = onde
    no.rotation.y = giro
    no.scale = Vector3.ONE * escala
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    no.visibility_range_end = 40.0
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


## Instancia formação de cristais mágicos de ressonância com brilho suave
func _cristal(onde: Vector3, giro := 0.0, escala := 1.0, cor := Color(0.6, 0.4, 1.0)) -> void:
    var no := CRISTAL_MESH.instantiate() as Node3D
    no.position = onde
    no.rotation.y = giro
    no.scale = Vector3.ONE * escala
    var malhas := no.find_children("*", "MeshInstance3D", true, false)
    for m in malhas:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = cor
        mat.roughness = 0.18
        mat.metallic = 0.1
        mat.emission_enabled = true
        mat.emission = cor
        mat.emission_energy_multiplier = 0.85
        m.material_override = mat
        m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        m.visibility_range_end = 45.0
    _dungeon.add_child(no)

    var luz := OmniLight3D.new()
    luz.light_color = cor
    luz.light_energy = 0.9
    luz.omni_range = 6.0
    luz.omni_attenuation = 1.5
    luz.shadow_enabled = false
    luz.position = onde + Vector3.UP * 0.8
    _dungeon.add_child(luz)


## Pilhas compostas de suprimentos e provisões
func _pilha_provisoes(onde: Vector3, giro := 0.0) -> void:
    _prop(CAIXOTE_MESH, onde, giro, 1.0)
    _prop(BARRIL_MESH, onde + Vector3(1.1 * cos(giro), 0.0, 1.1 * sin(giro)), giro + 0.6, 0.95)
    var saco := SACO_MESH.instantiate() as Node3D
    saco.position = onde + Vector3(-0.9 * sin(giro), 0.0, 0.9 * cos(giro))
    saco.rotation.y = giro - 0.5
    saco.scale = Vector3.ONE * 0.85
    _dungeon.add_child(saco)


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

    var luz := OmniLight3D.new()
    luz.light_color = Color(1.0, 0.72, 0.42)
    luz.light_energy = 2.6
    luz.omni_range = 13.0
    luz.omni_attenuation = 1.1
    luz.shadow_enabled = false
    luz.position = onde + Vector3.UP * 2.1
    _dungeon.add_child(luz)


func _bau(onde: Vector3, recompensa: int, ouro: bool, fecha_a_dg := false) -> void:
    var bau := BAU.new()
    bau.position = onde
    bau.recompensa_claves = recompensa
    bau.dourado = ouro
    bau.conclui_dg = fecha_a_dg
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
    _atualizar_placar()
    for inimigo in _inimigos:
        if not is_instance_valid(inimigo):
            continue
        var distancia := inimigo.global_position.distance_to(_jogador.global_position)
        inimigo.visible = distancia < 50.0
        inimigo.process_mode = Node.PROCESS_MODE_INHERIT if distancia < 32.0 else Node.PROCESS_MODE_DISABLED


func _criar_botao_hud() -> void:
    var hud := get_parent().get_node_or_null("HUD")
    if hud == null:
        return
    _botao = Button.new()
    _botao.name = "BtnDungeon"
    _botao.text = "DG\nCAVERNA"
    if _placar:
        _placar.visible = false
    _botao.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _botao.position = Vector2(18, 118)
    _botao.size = Vector2(108, 58)
    _botao.add_theme_font_size_override("font_size", 16)
    _botao.add_theme_color_override("font_color", Color(1.0, 0.87, 0.50))
    _botao.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.08))
    _botao.add_theme_constant_override("outline_size", 4)
    var moldura := NinePatchRect.new()
    moldura.texture = load("res://textures/ui/kit/botao_roxo.png")
    moldura.patch_margin_left = 36
    moldura.patch_margin_top = 28
    moldura.patch_margin_right = 36
    moldura.patch_margin_bottom = 14
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    moldura.show_behind_parent = true
    moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _botao.add_child(moldura)
    for estado in ["normal", "hover", "pressed", "focus"]:
        _botao.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    _botao.pressed.connect(_pedir_entrada)
    hud.add_child(_botao)

    _placar = Label.new()
    _placar.name = "PlacarDungeon"
    _placar.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _placar.offset_left = -190.0
    _placar.offset_right = 190.0
    _placar.offset_top = 14.0
    _placar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _placar.add_theme_font_size_override("font_size", 20)
    _placar.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
    _placar.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0))
    _placar.add_theme_constant_override("outline_size", 5)
    _placar.visible = false
    hud.add_child(_placar)


## Nome, fator de vida, fator de espolio, nivel recomendado e a explicacao.
##
## O nivel recomendado nao existia e era a pergunta que a tela nao respondia:
## "eu aguento esta?". Sem ela a escolha de dificuldade e chute, e chute errado
## na Cacofonia custa a incursao inteira.
const DIFICULDADES := [
    ["SERENA", 0.75, 1.0, 1, "Para conhecer a caverna. Shikers com menos vida."],
    ["DISSONANTE", 1.0, 1.4, 5, "O equilibrio da caverna. Recompensa cheia."],
    ["CACOFONIA", 1.6, 2.2, 12, "Batem mais forte e aguentam mais. Espolio dobrado."],
]

const KIT_UI := "res://textures/ui/kit/"
const FONTE_UI := "res://fontes/Cinzel.ttf"
const OURO_UI := Color(0.97, 0.84, 0.47)
const TEXTO_UI := Color(0.84, 0.88, 0.94)
const APAGADO_UI := Color(0.62, 0.67, 0.76)

var _dificuldade := 1
var _tela_entrada: CanvasLayer
var _cartoes_dificuldade: Array[Control] = []


func _pedir_entrada() -> void:
    if _dentro:
        _sair()
        return
    if _tela_entrada == null:
        _montar_tela_entrada()
    _atualizar_cartoes()
    _tela_entrada.visible = true


## A TELA DE ENTRADA DA DG.
##
## A anterior era um painel de 660 por 480 pixels FIXOS, centralizado, com seis
## botoes, seis linhas de explicacao e mais dois botoes de acao empilhados
## dentro. Em 1280 de largura passava raspando; em celular deitado, onde a altura
## util cai para uns 380 pixels de tela esticada, o "ENTRAR" simplesmente ficava
## abaixo da borda do painel. Nao era falta de capricho no espacamento: era um
## retangulo de tamanho fixo com conteudo que nao cabe nele.
##
## Aqui o painel e proporcional a tela, o miolo ROLA e as duas acoes ficam fora
## da rolagem — o mesmo desenho da tela de ajustes e do diario, pela mesma razao
## e com a mesma moldura do kit, para as tres pararem de parecer telas de jogos
## diferentes.
func _montar_tela_entrada() -> void:
    _tela_entrada = CanvasLayer.new()
    _tela_entrada.layer = 60
    add_child(_tela_entrada)

    var fundo := ColorRect.new()
    fundo.color = Color(0.01, 0.01, 0.03, 0.86)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    _tela_entrada.add_child(fundo)

    var painel := NinePatchRect.new()
    painel.texture = load(KIT_UI + "moldura_painel_grande.png")
    painel.patch_margin_left = 22
    painel.patch_margin_top = 68
    painel.patch_margin_right = 22
    painel.patch_margin_bottom = 64
    painel.anchor_left = 0.5
    painel.anchor_right = 0.5
    painel.anchor_top = 0.05
    painel.anchor_bottom = 0.95
    painel.offset_left = -320.0
    painel.offset_right = 320.0
    painel.mouse_filter = Control.MOUSE_FILTER_STOP
    fundo.add_child(painel)

    var coluna := VBoxContainer.new()
    coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
    coluna.offset_left = 36
    coluna.offset_right = -36
    coluna.offset_top = 72
    coluna.offset_bottom = -28
    coluna.add_theme_constant_override("separation", 4)
    painel.add_child(coluna)

    coluna.add_child(_letra("Caverna da Primeira Ressonância", 25, OURO_UI))
    coluna.add_child(_letra("Floresta do Despertar  •  Masmorra", 13, APAGADO_UI))

    var rolagem := ScrollContainer.new()
    rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    coluna.add_child(rolagem)

    var miolo := VBoxContainer.new()
    miolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    miolo.add_theme_constant_override("separation", 8)
    rolagem.add_child(miolo)

    miolo.add_child(_letra(
        "Dois estágios sob a floresta. Shikers guardam os corredores, dois Super "
        + "Shikers guardam o fundo, e os baús trazem Claves e fragmentos corrompidos.",
        13, TEXTO_UI))
    miolo.add_child(_letra("Recompensas: Claves  •  Fragmentos corrompidos  •  Partituras",
        13, Color(0.80, 0.86, 0.72)))

    miolo.add_child(_secao("Dificuldade"))
    _cartoes_dificuldade.clear()
    _botoes_dificuldade.clear()
    for i in DIFICULDADES.size():
        var cartao := _cartao_dificuldade(i)
        miolo.add_child(cartao)
        _cartoes_dificuldade.append(cartao)

    var acoes := HBoxContainer.new()
    acoes.alignment = BoxContainer.ALIGNMENT_CENTER
    acoes.add_theme_constant_override("separation", 12)
    coluna.add_child(acoes)

    var entrar := _botao_kit("ENTRAR NA CAVERNA", "botao_dourado")
    entrar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    entrar.pressed.connect(func():
        _tela_entrada.visible = false
        _entrar())
    acoes.add_child(entrar)

    var voltar := _botao_kit("VOLTAR", "botao_vermelho")
    voltar.custom_minimum_size.x = 150
    voltar.pressed.connect(func(): _tela_entrada.visible = false)
    acoes.add_child(voltar)


## Um cartao por dificuldade, e a escolhida se ANUNCIA.
##
## Antes as tres eram botoes iguais e a selecionada mudava de um azul-escuro para
## um roxo-escuro — dois tons que, no brilho de um celular ao sol, sao a mesma
## coisa. Aqui a escolhida ganha aro dourado, fundo mais claro e um losango aceso
## na frente do nome: tres sinais, e nenhum deles depende de distinguir tom.
func _cartao_dificuldade(i: int) -> Control:
    var d: Array = DIFICULDADES[i]
    var cartao := PanelContainer.new()
    cartao.mouse_filter = Control.MOUSE_FILTER_STOP

    var dentro := VBoxContainer.new()
    dentro.add_theme_constant_override("separation", 2)
    cartao.add_child(dentro)

    var topo := HBoxContainer.new()
    topo.add_theme_constant_override("separation", 8)
    dentro.add_child(topo)

    var marca := Label.new()
    marca.name = "Marca"
    marca.text = "◆"
    marca.add_theme_font_size_override("font_size", 15)
    topo.add_child(marca)

    var nome := Label.new()
    nome.name = "Nome"
    nome.text = str(d[0])
    nome.add_theme_font_override("font", load(FONTE_UI))
    nome.add_theme_font_size_override("font_size", 18)
    nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topo.add_child(nome)

    var nivel := Label.new()
    nivel.text = "nível %d+" % int(d[3])
    nivel.add_theme_font_size_override("font_size", 12)
    nivel.add_theme_color_override("font_color", APAGADO_UI)
    topo.add_child(nivel)

    var numeros := Label.new()
    numeros.text = "vida ×%.2f      espólio ×%.1f" % [float(d[1]), float(d[2])]
    numeros.add_theme_font_size_override("font_size", 13)
    numeros.add_theme_color_override("font_color", Color(0.76, 0.82, 0.90))
    dentro.add_child(numeros)

    var conta := Label.new()
    conta.text = str(d[4])
    conta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    conta.add_theme_font_size_override("font_size", 12)
    conta.add_theme_color_override("font_color", APAGADO_UI)
    dentro.add_child(conta)

    # O cartao inteiro e a area de toque: num celular, alvo de toque menor que o
    # cartao que se ve e a receita para o jogador achar que a tela travou.
    var toque := Button.new()
    toque.flat = true
    toque.set_anchors_preset(Control.PRESET_FULL_RECT)
    toque.focus_mode = Control.FOCUS_NONE
    for estado in ["normal", "hover", "pressed", "focus"]:
        toque.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    toque.pressed.connect(_escolher_dificuldade.bind(i))
    cartao.add_child(toque)
    _botoes_dificuldade.append(toque)
    return cartao


func _secao(texto: String) -> Control:
    var caixa := VBoxContainer.new()
    caixa.add_theme_constant_override("separation", 2)
    var espaco := Control.new()
    espaco.custom_minimum_size = Vector2(0, 6)
    caixa.add_child(espaco)
    caixa.add_child(_letra(texto, 17, OURO_UI))
    var risco := ColorRect.new()
    risco.color = Color(0.72, 0.58, 0.30, 0.45)
    risco.custom_minimum_size = Vector2(0, 1)
    caixa.add_child(risco)
    return caixa


func _botao_kit(rotulo: String, arte: String) -> Button:
    var b := Button.new()
    b.text = rotulo
    b.custom_minimum_size = Vector2(0, 52)
    b.add_theme_font_override("font", load(FONTE_UI))
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84))
    for estado in ["normal", "hover", "pressed", "focus"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    var moldura := NinePatchRect.new()
    moldura.texture = load(KIT_UI + arte + ".png")
    moldura.patch_margin_left = 36
    moldura.patch_margin_top = 28
    moldura.patch_margin_right = 36
    moldura.patch_margin_bottom = 14
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    moldura.show_behind_parent = true
    moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(moldura)
    return b


func _letra(txt: String, corpo: int, cor: Color) -> Label:
    var l := Label.new()
    l.text = txt
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_override("font", load(FONTE_UI))
    l.add_theme_font_size_override("font_size", corpo)
    l.add_theme_color_override("font_color", cor)
    return l


func _escolher_dificuldade(qual: int) -> void:
    _dificuldade = qual
    _atualizar_cartoes()


func _atualizar_cartoes() -> void:
    for i in _cartoes_dificuldade.size():
        var cartao: PanelContainer = _cartoes_dificuldade[i]
        var escolhido: bool = i == _dificuldade
        var estilo := StyleBoxFlat.new()
        estilo.bg_color = Color(0.14, 0.11, 0.05, 0.96) if escolhido else Color(0.045, 0.065, 0.11, 0.92)
        estilo.border_color = OURO_UI if escolhido else Color(0.34, 0.40, 0.50, 0.85)
        estilo.set_border_width_all(2 if escolhido else 1)
        estilo.set_corner_radius_all(9)
        estilo.content_margin_left = 14
        estilo.content_margin_right = 14
        estilo.content_margin_top = 9
        estilo.content_margin_bottom = 11
        cartao.add_theme_stylebox_override("panel", estilo)
        var marca := cartao.find_child("Marca", true, false) as Label
        if marca:
            marca.add_theme_color_override("font_color",
                OURO_UI if escolhido else Color(0.30, 0.36, 0.44))
        var nome := cartao.find_child("Nome", true, false) as Label
        if nome:
            nome.add_theme_color_override("font_color",
                Color(1.0, 0.95, 0.80) if escolhido else Color(0.72, 0.78, 0.86))


func _aplicar_dificuldade() -> void:
    var fator: float = float(DIFICULDADES[_dificuldade][1])
    for inimigo in _inimigos:
        if not is_instance_valid(inimigo):
            continue
        if inimigo.has_method("ajustar_por_dificuldade"):
            inimigo.ajustar_por_dificuldade(fator)


func _alternar() -> void:
    if _dentro:
        _sair()
    else:
        _entrar()


func _contar_shikers() -> int:
    var vivos := 0
    for b in get_tree().get_nodes_in_group("bicho"):
        if is_instance_valid(b) and (b as Node3D).global_position.distance_to(ORIGEM) < 400.0:
            vivos += 1
    return vivos


func _atualizar_placar() -> void:
    if _placar == null or not _dentro:
        return
    var vivos := _contar_shikers()
    _shikers_totais = maxi(_shikers_totais, vivos)
    if vivos == 0:
        _placar.text = "CAVERNA LIMPA  —  volte para receber o espolio"
    else:
        _placar.text = "SHIKERS RESTANTES   %d / %d" % [vivos, _shikers_totais]


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
        _camera.position = Vector3(0.0, 8.6, 13.8)
        _camera.fov = 55.0
    if _ciclo:
        _ciclo_rodava = bool(_ciclo.get("rodando"))
        _ciclo.set("rodando", false)

    _aplicar_ambiente_da_caverna()
    var destino := ENTRADA
    if OS.get_cmdline_user_args().has("--boss"):
        destino = Vector3(0.0, 1.15, -64.0)
    if OS.get_cmdline_user_args().has("--parede"):
        destino = Vector3(0.0, 1.15, 78.0)
    if OS.get_cmdline_user_args().has("--dg2"):
        destino = ENTRADA_ESTAGIO_2 + Vector3(0.0, 0.0, -14.0)
    _jogador.global_position = ORIGEM + destino
    _jogador.velocity = Vector3.ZERO
    _botao.text = "SAIR\nDA DG"
    _aplicar_dificuldade()
    _shikers_totais = maxi(_shikers_totais, _contar_shikers())
    if _placar:
        _placar.visible = true
    _atualizar_placar()


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
    env.ambient_light_sky_contribution = 0.0
    env.ambient_light_color = Color(0.36, 0.42, 0.58)
    env.ambient_light_energy = 1.3
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.12
    env.fog_enabled = true
    env.fog_light_color = Color(0.10, 0.14, 0.24)
    env.fog_light_energy = 0.45
    env.fog_density = 0.008
    _ambiente.environment = env

    if _luz_da_caverna == null:
        _luz_da_caverna = DirectionalLight3D.new()
        _luz_da_caverna.name = "LuzDaCaverna"
        _luz_da_caverna.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
        _luz_da_caverna.light_color = Color(0.62, 0.70, 0.92)
        _luz_da_caverna.light_energy = 0.85
        _luz_da_caverna.shadow_enabled = false
        add_child(_luz_da_caverna)
    _luz_da_caverna.visible = true
