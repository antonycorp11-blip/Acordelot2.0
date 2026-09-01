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


func _construir_dungeon() -> void:
    _dungeon = Node3D.new()
    _dungeon.name = "CavernaDaPrimeiraRessonancia"
    _dungeon.position = ORIGEM
    _dungeon.visible = false
    _dungeon.process_mode = Node.PROCESS_MODE_DISABLED
    add_child(_dungeon)

    # --- ESTÁGIO 1: ENTRADA & SALÕES COM CORREDORES AMPLIADOS ---
    # 1. Câmara de Entrada e Corredor Longo de Entrada (32 metros de imersão)
    _modulo(SALA_PEQUENA, Vector3(0, 0, 78))
    _corredor_z([68.0, 60.0, 52.0, 44.0])
    _modulo(PORTAO, Vector3(0, 0, 39))

    # 2. Grande Salão Central (60m x 40m)
    _salao(Vector3(0, 0, 18), 3, 2)

    # 3. Asa Leste: Corredor de transição + Câmara de Batalha + Câmara do Tesouro
    _corredor_x([32.0, 40.0], 18.0)
    _modulo(SALA_GRANDE_B, Vector3(50, 0, 18))
    _corredor_z([6.0, -2.0, -10.0], 50.0)
    _modulo(SALA_PEQUENA_B, Vector3(50, 0, -18))

    # 4. Asa Oeste: Corredor de transição + Câmara de Batalha + Câmara do Tesouro
    _corredor_x([-32.0, -40.0], 18.0)
    _modulo(SALA_GRANDE_B, Vector3(-50, 0, 18))
    _corredor_z([30.0, 38.0, 46.0], -50.0)
    _modulo(SALA_PEQUENA_B, Vector3(-50, 0, 54))

    # 5. Corredor Sul para a Arena do Chefe (32 metros de tensão)
    _corredor_z([-8.0, -16.0, -24.0, -32.0])
    _modulo(PORTAO, Vector3(0, 0, -39))

    # 6. Salão da Arena do Chefe (60m x 40m)
    _salao(Vector3(0, 0, -60), 3, 2)

    # --- LAJE VISUAL E COLISÃO CONTÍNUA (ZERO FRESTAS) ---
    # A laje cobre toda a extensão da masmorra com colisor e malha de rocha texturizada
    _laje_visual_e_solida(Vector3(0, -0.2, 10), Vector3(190, 0.4, 200))
    _cercar(Vector3(0, 0, 10), Vector2(190, 200))
    _vazio_preto()

    # --- ILUMINAÇÃO & TOCHAS DO ESTÁGIO 1 ---
    var tochas_estagio_1 := [
        [-4.7, 76.0, 0.0], [4.7, 76.0, PI],
        [-3.4, 64.0, 0.0], [3.4, 64.0, PI],
        [-3.4, 48.0, 0.0], [3.4, 48.0, PI],
        [-18.0, 34.0, 0.0], [18.0, 34.0, PI],
        [-18.0, 2.0, 0.0], [18.0, 2.0, PI],
        [32.0, 15.0, -PI * 0.5], [32.0, 21.0, PI * 0.5],
        [48.0, 24.0, 0.0], [48.0, 12.0, PI],
        [47.0, -2.0, 0.0], [53.0, -2.0, PI],
        [48.0, -14.0, 0.0], [48.0, -22.0, PI],
        [-32.0, 15.0, -PI * 0.5], [-32.0, 21.0, PI * 0.5],
        [-48.0, 24.0, 0.0], [-48.0, 12.0, PI],
        [-47.0, 38.0, 0.0], [-53.0, 38.0, PI],
        [-48.0, 50.0, 0.0], [-48.0, 58.0, PI],
        [-3.4, -12.0, 0.0], [3.4, -12.0, PI],
        [-3.4, -28.0, 0.0], [3.4, -28.0, PI],
        [-18.0, -44.0, 0.0], [18.0, -44.0, PI],
        [-18.0, -76.0, 0.0], [18.0, -76.0, PI],
        [0.0, -78.0, PI]
    ]
    for d in tochas_estagio_1:
        _tocha(Vector3(d[0], 0.0, d[1]), d[2])

    # --- CRISTAIS DE RESSONÂNCIA MÁGICA (ATMOSFERA) ---
    var cristais_e1 := [
        [Vector3(-3.2, 0.0, 72.0), 0.4, 0.9, Color(0.6, 0.4, 1.0)],
        [Vector3(3.2, 0.0, 56.0), 1.2, 1.1, Color(0.4, 0.7, 1.0)],
        [Vector3(-26.0, 0.0, 24.0), 0.8, 1.3, Color(0.8, 0.4, 1.0)],
        [Vector3(26.0, 0.0, 12.0), -0.5, 1.2, Color(0.4, 0.8, 1.0)],
        [Vector3(56.0, 0.0, 18.0), 0.3, 1.4, Color(1.0, 0.5, 0.8)],
        [Vector3(50.0, 0.0, -22.0), -1.1, 1.5, Color(0.4, 0.9, 1.0)],
        [Vector3(-56.0, 0.0, 18.0), 1.5, 1.4, Color(0.7, 0.3, 1.0)],
        [Vector3(-50.0, 0.0, 58.0), 0.6, 1.5, Color(0.9, 0.4, 0.9)],
        [Vector3(-3.2, 0.0, -20.0), 0.2, 1.0, Color(0.4, 0.6, 1.0)],
        [Vector3(3.2, 0.0, -32.0), -0.7, 1.1, Color(0.8, 0.3, 1.0)],
        [Vector3(-25.0, 0.0, -68.0), 0.5, 1.6, Color(1.0, 0.4, 0.7)],
        [Vector3(25.0, 0.0, -68.0), -0.8, 1.6, Color(0.4, 0.7, 1.0)],
    ]
    for cr in cristais_e1:
        _cristal(cr[0], cr[1], cr[2], cr[3])

    # --- SUPRIMENTOS & DECORAÇÕES REALISTAS ---
    _pilha_provisoes(Vector3(-3.2, 0.0, 68.0), 0.2)
    _pilha_provisoes(Vector3(3.2, 0.0, 48.0), -0.4)
    _pilha_provisoes(Vector3(-24.0, 0.0, 32.0), 0.6)
    _pilha_provisoes(Vector3(24.0, 0.0, 4.0), -0.3)
    _pilha_provisoes(Vector3(46.0, 0.0, 14.0), 0.5)
    _pilha_provisoes(Vector3(-46.0, 0.0, 22.0), -0.5)
    _pilha_provisoes(Vector3(46.0, 0.0, -14.0), 0.8)
    _pilha_provisoes(Vector3(-46.0, 0.0, 50.0), -0.8)
    _pilha_provisoes(Vector3(-3.2, 0.0, -16.0), 0.3)
    _pilha_provisoes(Vector3(3.2, 0.0, -28.0), -0.6)
    _pilha_provisoes(Vector3(-24.0, 0.0, -56.0), 0.4)
    _pilha_provisoes(Vector3(24.0, 0.0, -56.0), -0.4)

    _prop(CAVEIRA_MESH, Vector3(6.0, 0.04, -68.0), 0.4, 1.35)
    _prop(CAVEIRA_MESH, Vector3(-5.0, 0.04, -58.0), -0.7, 1.2)
    _prop(CAVEIRA_MESH, Vector3(48.0, 0.04, -16.0), 0.3, 1.25)
    _prop(CAVEIRA_MESH, Vector3(-48.0, 0.04, 52.0), -0.5, 1.25)

    # --- BAÚS DE RECOMPENSA DO ESTÁGIO 1 ---
    _bau(Vector3(-50.0, 0.0, 18.0), 250, false)
    _bau(Vector3(50.0, 0.0, 18.0), 350, true)
    _bau(Vector3(-50.0, 0.0, 54.0), 400, true)
    _bau(Vector3(50.0, 0.0, -18.0), 400, true)
    _bau(Vector3(0.0, 0.0, -74.0), 600, true)

    # --- MONSTROS DO ESTÁGIO 1 (SHIKERS & GOLEMS) ---
    # Golems de guarda logo no corredor de entrada (o jogador encontra imediatamente ao descer!)
    _shiker(Vector3(0.0, 1.1, 56.0), 3)
    _shiker(Vector3(0.0, 1.1, 40.0), 3)

    var salas_estagio_1 := [
        Vector3(-20, 0, 28), Vector3(0, 0, 28), Vector3(20, 0, 28),
        Vector3(-20, 0, 8), Vector3(20, 0, 8),
        Vector3(50, 0, 18), Vector3(-50, 0, 18),
        Vector3(50, 0, -18), Vector3(-50, 0, 54),
        Vector3(-20, 0, -50), Vector3(20, 0, -50),
        Vector3(-20, 0, -70), Vector3(20, 0, -70),
    ]
    for i in salas_estagio_1.size():
        var canto := Vector3(cos(float(i) * 1.7) * 4.0, 1.1, sin(float(i) * 2.3) * 4.0)
        # Nas salas centrais, alas laterais e antes do chefe
        var tipo_bicho := 3 if (i in [1, 5, 6, 7, 8, 11]) else (0 if i % 2 == 0 else 1)
        _shiker(salas_estagio_1[i] + canto, tipo_bicho)
    _vestir_salas(salas_estagio_1)

    # Chefe do Estágio 1 ladeado por Golems de Pedra
    _shiker(Vector3(-14.0, 1.1, -64.0), 3)
    _shiker(Vector3(14.0, 1.1, -64.0), 3)
    var chefe := _shiker(Vector3(0.0, 1.1, -64.0), 2)
    chefe.call_deferred("tornar_super_shiker")

    _construir_segundo_estagio()


## O SEGUNDO ESTAGIO, com o salao maior do jogo.
const ESTAGIO_2 := Vector3(0.0, 0.0, -180.0)
const ENTRADA_ESTAGIO_2 := Vector3(0.0, 1.15, -142.0)

func _construir_segundo_estagio() -> void:
    var o := ESTAGIO_2

    # 1. Corredor longo de descida ao Estágio 2 (32m)
    _corredor_z([o.z + 36.0, o.z + 28.0, o.z + 20.0, o.z + 12.0])
    _modulo(PORTAO, o + Vector3(0, 0, 7))

    # 2. Grande Salão Principal do Estágio 2 (60m x 40m)
    _salao(o + Vector3(0, 0, -14), 3, 2)

    # 3. Criptas e Câmaras Ocultas no Oeste com corredor de transição
    _corredor_x([o.x - 32.0, o.x - 40.0], o.z - 14.0)
    _modulo(SALA_GRANDE_B, o + Vector3(-52, 0, -14))
    _corredor_x([o.x - 64.0, o.x - 72.0], o.z - 14.0)
    _modulo(SALA_GRANDE_B, o + Vector3(-84, 0, -14))

    # 4. Corredor longo para a Câmara do Guardião Ancestral (32m)
    _corredor_z([o.z - 40.0, o.z - 48.0, o.z - 56.0, o.z - 64.0])
    _modulo(PORTAO, o + Vector3(0, 0, -69))

    # 5. Santuário do Guardião Ancestral (60m x 40m)
    _salao(o + Vector3(0, 0, -90), 3, 2)

    # --- LAJE VISUAL E FÍSICA DO ESTÁGIO 2 ---
    _laje_visual_e_solida(o + Vector3(-20, -0.2, -30), Vector3(230, 0.4, 200))
    _cercar(o + Vector3(-20, 0, -30), Vector2(230, 200))

    # --- ILUMINAÇÃO & TOCHAS DO ESTÁGIO 2 ---
    var tochas_estagio_2 := [
        [-3.4, 32.0, 0.0], [3.4, 32.0, PI],
        [-3.4, 16.0, 0.0], [3.4, 16.0, PI],
        [-27.0, -2.0, 0.0], [27.0, -2.0, PI],
        [-27.0, -26.0, 0.0], [27.0, -26.0, PI],
        [-34.0, -10.0, -PI * 0.5], [-34.0, -18.0, PI * 0.5],
        [-52.0, -2.0, 0.0], [-52.0, -26.0, PI],
        [-66.0, -10.0, -PI * 0.5], [-66.0, -18.0, PI * 0.5],
        [-84.0, -2.0, 0.0], [-84.0, -26.0, PI],
        [-3.4, -44.0, 0.0], [3.4, -44.0, PI],
        [-3.4, -60.0, 0.0], [3.4, -60.0, PI],
        [-27.0, -78.0, 0.0], [27.0, -78.0, PI],
        [-27.0, -102.0, 0.0], [27.0, -102.0, PI],
        [0.0, -108.0, PI]
    ]
    for d in tochas_estagio_2:
        _tocha(o + Vector3(d[0], 0.0, d[1]), d[2])

    # --- CRISTAIS DO ESTÁGIO 2 (FORMAÇÕES RARAS) ---
    var cristais_e2 := [
        [Vector3(3.2, 0.0, 24.0), 0.7, 1.2, Color(0.5, 0.8, 1.0)],
        [Vector3(-3.2, 0.0, 14.0), -0.5, 1.1, Color(0.9, 0.4, 1.0)],
        [Vector3(26.0, 0.0, -14.0), 0.3, 1.6, Color(0.4, 0.9, 0.8)],
        [Vector3(-52.0, 0.0, -6.0), 1.2, 1.5, Color(1.0, 0.6, 0.3)],
        [Vector3(-84.0, 0.0, -14.0), -0.8, 1.8, Color(1.0, 0.3, 0.9)],
        [Vector3(-3.2, 0.0, -46.0), 0.4, 1.2, Color(0.4, 0.7, 1.0)],
        [Vector3(3.2, 0.0, -58.0), -0.9, 1.3, Color(0.8, 0.3, 1.0)],
        [Vector3(-25.0, 0.0, -96.0), 0.6, 1.8, Color(1.0, 0.8, 0.4)],
        [Vector3(25.0, 0.0, -96.0), -0.6, 1.8, Color(0.4, 0.9, 1.0)],
    ]
    for cr in cristais_e2:
        _cristal(o + cr[0], cr[1], cr[2], cr[3])

    # --- DECORAÇÕES DO ESTÁGIO 2 ---
    _pilha_provisoes(o + Vector3(-3.2, 0.0, 26.0), 0.3)
    _pilha_provisoes(o + Vector3(3.2, 0.0, 18.0), -0.4)
    _pilha_provisoes(o + Vector3(-24.0, 0.0, -8.0), 0.2)
    _pilha_provisoes(o + Vector3(23.0, 0.0, -18.0), -0.3)
    _pilha_provisoes(o + Vector3(-54.0, 0.0, -8.0), 0.4)
    _pilha_provisoes(o + Vector3(-78.0, 0.0, -18.0), -0.2)
    _pilha_provisoes(o + Vector3(-3.2, 0.0, -42.0), 0.5)
    _pilha_provisoes(o + Vector3(3.2, 0.0, -54.0), -0.3)
    _pilha_provisoes(o + Vector3(-24.0, 0.0, -84.0), 0.4)
    _pilha_provisoes(o + Vector3(24.0, 0.0, -84.0), -0.4)

    _prop(CAVEIRA_MESH, o + Vector3(-6.0, 0.04, -94.0), 0.7, 1.4)
    _prop(CAVEIRA_MESH, o + Vector3(5.0, 0.04, -98.0), -0.4, 1.3)
    _prop(CAVEIRA_MESH, o + Vector3(-82.0, 0.04, -14.0), 0.2, 1.5)

    # --- BAÚS DO ESTÁGIO 2 ---
    _bau(o + Vector3(-84.0, 0.0, -14.0), 750, true)
    _bau(o + Vector3(26.0, 0.0, -24.0), 500, true)
    # O tesouro do fundo: e ele que registra a incursao como concluida.
    _bau(o + Vector3(0.0, 0.0, -102.0), 1000, true, true)

    # --- MONSTROS DO ESTÁGIO 2 (GOLEMS CRISTALINOS & COLOSSOS) ---
    var salas_estagio_2 := [
        Vector3(-20, 0, -4), Vector3(20, 0, -4), Vector3(-20, 0, -24),
        Vector3(20, 0, -24), Vector3(0, 0, -14), Vector3(-52, 0, -14),
        Vector3(-84, 0, -14), Vector3(-20, 0, -80), Vector3(20, 0, -80),
        Vector3(-20, 0, -100), Vector3(20, 0, -100),
    ]
    for i in salas_estagio_2.size():
        var canto := Vector3(cos(float(i) * 2.1) * 5.0, 1.1, sin(float(i) * 1.3) * 5.0)
        # Distribui Golems Cristalinos (4), Shikers Anciãos (2) e Colossos (5)
        var tipo_bicho := 4 if (i in [0, 2, 5, 7]) else (5 if (i in [6, 10]) else 2)
        _shiker(o + salas_estagio_2[i] + canto, tipo_bicho)
    var absolutos_2 := []
    for v in salas_estagio_2:
        absolutos_2.append(o + v)
    _vestir_salas(absolutos_2)

    # Guardião Ancestral ladeado por Colossos
    _shiker(o + Vector3(-16.0, 1.1, -94.0), 4)
    _shiker(o + Vector3(16.0, 1.1, -94.0), 4)
    var guardiao := _shiker(o + Vector3(0.0, 1.1, -94.0), 5)
    guardiao.call_deferred("tornar_super_shiker")

    # Portas de transição entre estágios
    _porta_de_estagio(Vector3(0.0, 0.0, -80.0), ORIGEM + ENTRADA_ESTAGIO_2,
        "⬇  DESCER AO SEGUNDO ESTÁGIO")
    _porta_de_estagio(o + Vector3(0.0, 0.0, 40.0), ORIGEM + Vector3(0.0, 1.15, -48.0),
        "⬆  VOLTAR AO PRIMEIRO ESTÁGIO")


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


func _salao(centro: Vector3, colunas: int, linhas: int) -> void:
    var lado := 20.0
    for i in colunas:
        for j in linhas:
            _modulo(SALA_GRANDE, Vector3(
                centro.x + (float(i) - (colunas - 1) * 0.5) * lado, 0,
                centro.z + (float(j) - (linhas - 1) * 0.5) * lado))


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
