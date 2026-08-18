extends Node3D
## Carrega SO o pedaco de mundo que a camera enxerga.
##
## O alvo e celular e navegador: um anel de mundo em volta do jogador poria na
## memoria varias vezes mais terreno do que cabe na tela. Aqui o teste e o
## proprio tronco de visao da camera — o que esta atras dela nao existe.
##
## A camera e fixa no estilo Albion (nao gira com o jogador), entao o que sai da
## tela so volta quando o jogador anda para la, e a margem de MARGIN_CHUNKS ja
## monta o pedaco antes dele entrar em cena.

## Pedacos a mais em volta do que a camera ve. Alem da folga para o mundo
## aparecer ja montado, e o que cobre a copa da arvore alta cujo TRONCO ficou
## fora da tela — o teste e feito no chao, entao a arvore da divisa precisa dele.
const MARGIN_CHUNKS := 1
## Teto de construcao por quadro. Mais que isso e engasgo visivel no celular.
const BUILDS_PER_FRAME := 1

@export var player: Node3D

var _chunks: Dictionary = {}
var _build_queue: Array[Vector2i] = []
var _ground_material: ShaderMaterial

func _ready() -> void:
    _ground_material = ShaderMaterial.new()
    _ground_material.shader = load("res://materials/forest_ground.gdshader")
    _ground_material.set_shader_parameter(
        "grass_texture", load("res://textures/grass_seamless.png"))
    _ground_material.set_shader_parameter(
        "dirt_texture", load("res://textures/dirt_seamless.png"))

## Monta na hora o pedaco sob uma posicao. O mundo nasce um pedaco por quadro
## para nao engasgar, mas o jogador ja cai desde o primeiro: sem o chao dele
## pronto ANTES do primeiro passo de fisica, ele despenca durante a montagem.
func ensure_ground_at(position: Vector3) -> void:
    _build(_chunk_at(position))

func _process(_delta: float) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null or player == null:
        return

    var visible_chunks := _visible_chunks(camera)
    # O pedaco onde o jogador pisa entra sempre, mesmo que um quadro de camera
    # o deixe de fora: sem chao ali, o jogador cai do mundo.
    visible_chunks[_chunk_at(player.global_position)] = true

    for chunk in visible_chunks:
        if not _chunks.has(chunk) and not _build_queue.has(chunk):
            _build_queue.append(chunk)

    # O pedaco onde o jogador esta fura a fila: e o unico cuja falta faz o jogo
    # quebrar, e nao apenas o cenario aparecer tarde.
    var player_chunk := _chunk_at(player.global_position)
    if _build_queue.has(player_chunk):
        _build_queue.erase(player_chunk)
        _build_queue.push_front(player_chunk)

    for chunk in _chunks.keys():
        if not visible_chunks.has(chunk):
            _chunks[chunk].queue_free()
            _chunks.erase(chunk)

    _build_queue = _build_queue.filter(func(chunk): return visible_chunks.has(chunk))

    for i in BUILDS_PER_FRAME:
        if _build_queue.is_empty():
            break
        _build(_build_queue.pop_front())

func _build(chunk: Vector2i) -> void:
    if _chunks.has(chunk):
        return
    var node := ChunkBuilder.build(chunk, _ground_material)
    add_child(node)
    _chunks[chunk] = node

func _chunk_at(position: Vector3) -> Vector2i:
    return Vector2i(int(round(position.x / ChunkBuilder.CHUNK_SIZE)),
                    int(round(position.z / ChunkBuilder.CHUNK_SIZE)))

## Pedacos que a camera enxerga, como conjunto (Dictionary usado como Set).
##
## O chao e plano e a camera e fixa, entao da para ser exato em vez de testar
## caixa contra tronco: joga-se um raio por canto da tela ate o plano y = 0 e o
## que a camera ve e o retangulo que cabe esses quatro pontos. Sem chute de
## orientacao de normal — que foi o que carregou mundo nenhum na primeira versao.
func _visible_chunks(camera: Camera3D) -> Dictionary:
    var viewport_size := camera.get_viewport().get_visible_rect().size
    var corners: Array[Vector2] = [
        Vector2.ZERO,
        Vector2(viewport_size.x, 0.0),
        Vector2(0.0, viewport_size.y),
        viewport_size,
    ]

    var ground_points: Array[Vector3] = []
    for corner in corners:
        ground_points.append(_ray_to_ground(camera, corner))

    var minimum := ground_points[0]
    var maximum := ground_points[0]
    for point in ground_points:
        minimum = minimum.min(point)
        maximum = maximum.max(point)

    var first := _chunk_at(minimum) - Vector2i(MARGIN_CHUNKS, MARGIN_CHUNKS)
    var last := _chunk_at(maximum) + Vector2i(MARGIN_CHUNKS, MARGIN_CHUNKS)

    var found := {}
    for x in range(first.x, last.x + 1):
        for y in range(first.y, last.y + 1):
            found[Vector2i(x, y)] = true
    return found

## Onde o raio de um ponto da tela encontra o chao. Canto que aponta para cima
## (o horizonte) nunca cruza y = 0: nesse caso vale o alcance da camera, senao o
## mundo carregado iria ao infinito.
func _ray_to_ground(camera: Camera3D, screen_point: Vector2) -> Vector3:
    var origin := camera.project_ray_origin(screen_point)
    var direction := camera.project_ray_normal(screen_point)
    if direction.y < -0.001:
        var distance := -origin.y / direction.y
        if distance <= camera.far:
            return origin + direction * distance
    return origin + direction * camera.far

## Quantos pedacos estao vivos — o HUD de teste mostra isso no celular.
func loaded_count() -> int:
    return _chunks.size()
