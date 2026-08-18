class_name ChunkBuilder
extends RefCounted
## Monta um pedaco de CHUNK_SIZE metros do mundo: chao + vegetacao.
##
## O mundo tem 110 celulas de 120 m. Montar por celula inteira poria na memoria
## do celular quatro vezes mais mundo do que cabe na tela, entao a unidade de
## carga e o pedaco pequeno — e so entra o que a camera enxerga.
##
## Nada e posicionado a mao: a semente vem da regiao mais as coordenadas do
## pedaco, entao o mesmo pedaco nasce igual toda vez que volta para a tela, e o
## mundo e o mesmo em toda maquina sem guardar milhares de coordenadas.

const CHUNK_SIZE := 30.0
## Praca limpa no centro de cada regiao: e onde da para andar e por NPC.
const CLEARING_RADIUS := 11.0

static var _scene_cache: Dictionary = {}
static var _prop_material: Material = null

## O TripoSR pinta o modelo em COR POR VERTICE, sem textura. Sem um material que
## leia essa cor como albedo, a arvore chega branca e o ambiente azul do ceu a
## deixa azulada. O material e um so para todo o mundo: alem de corrigir a cor,
## e uma troca de estado a menos por objeto desenhado.
static func prop_material() -> Material:
    if _prop_material == null:
        _prop_material = load("res://Material_TripoSR.tres")
    return _prop_material

## O pedaco e CENTRADO no seu indice, nao apoiado nele. Com a divisa em
## multiplos de 30 m, o centro da celula (multiplo de 120) caia exatamente na
## quina de quatro pedacos: o jogador nascia com meio corpo fora do chao e
## escorregava para fora do mundo antes do primeiro passo.
static func chunk_center(chunk: Vector2i) -> Vector3:
    return Vector3(chunk.x * CHUNK_SIZE, 0.0, chunk.y * CHUNK_SIZE)

static func build(chunk: Vector2i, ground_material: Material) -> Node3D:
    var center := chunk_center(chunk)
    var region := World.region_at(World.cell_at(center))

    var root := Node3D.new()
    root.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
    root.position = center
    root.add_child(_build_ground(ground_material))

    if region.is_empty():
        return root

    var rng := RandomNumberGenerator.new()
    rng.seed = hash([int(region.get("seed", 0)), chunk.x, chunk.y])
    for entry in region.get("props", []):
        _scatter(root, entry, rng, center)
    return root

static func _build_ground(material: Material) -> StaticBody3D:
    var ground := StaticBody3D.new()
    ground.name = "Ground"

    var mesh := PlaneMesh.new()
    mesh.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
    # A nevoa e calculada POR VERTICE no renderizador de celular. Num quadrado de
    # 30 m com quatro cantos, ela interpola em degrau e o terreno ganha um
    # xadrez de retangulos do tamanho do pedaco. Subdividir custa 81 vertices e
    # faz o degrau sumir.
    mesh.subdivide_width = 8
    mesh.subdivide_depth = 8
    mesh.material = material

    var mesh_node := MeshInstance3D.new()
    mesh_node.name = "Mesh"
    mesh_node.mesh = mesh
    # O chao RECEBE sombra mas nao projeta. Plano grande projetando sobre si
    # mesmo da acne de sombra, e a acne desenhava a grade dos pedacos no
    # terreno — justo a emenda que o shader em coordenada de mundo apaga.
    mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ground.add_child(mesh_node)

    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var shape := BoxShape3D.new()
    shape.size = Vector3(CHUNK_SIZE, 0.2, CHUNK_SIZE)
    collision.shape = shape
    collision.position = Vector3(0.0, -0.1, 0.0)
    ground.add_child(collision)
    return ground

static func _scatter(root: Node3D, entry: Dictionary, rng: RandomNumberGenerator,
                     center: Vector3) -> void:
    var tag := String(entry.get("tag", ""))
    var kind: Dictionary = World.catalog.get(tag, {})
    var models: Array = kind.get("models", [])
    if models.is_empty():
        push_warning("Etiqueta sem modelo no catalogo: " + tag)
        return

    # A paleta conta props por REGIAO. Aqui cabe a fatia deste pedaco, e a sobra
    # fracionada vira chance — senao toda paleta abaixo de 16 sumiria no zero.
    var per_region: float = float(entry.get("count", 0))
    var chunks_per_region := (World.REGION_SIZE / CHUNK_SIZE) * (World.REGION_SIZE / CHUNK_SIZE)
    var share := per_region / chunks_per_region
    var count := int(floor(share))
    if rng.randf() < share - float(count):
        count += 1

    var half := CHUNK_SIZE * 0.5
    var region_center := World.cell_center(World.cell_at(center))
    var scale_range: Array = kind.get("scale", [1.0, 1.0])

    for i in count:
        var offset := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
        # A praca e da REGIAO, entao a distancia se mede do centro dela, nao do
        # pedaco: senao cada pedaco abriria a propria clareira.
        if (center + offset - region_center).length() < CLEARING_RADIUS:
            continue

        var scene := _load_scene(String(models[rng.randi() % models.size()]))
        if scene == null:
            continue
        var prop := scene.instantiate()
        prop.position = offset + Vector3(0.0, float(kind.get("y", 0.0)), 0.0)
        prop.rotation.y = rng.randf_range(0.0, TAU)
        prop.scale = Vector3.ONE * rng.randf_range(float(scale_range[0]), float(scale_range[1]))
        root.add_child(prop)

        for mesh_node in prop.find_children("*", "MeshInstance3D", true, false):
            mesh_node.material_override = prop_material()

        if bool(kind.get("solid", false)):
            PropCollider.apply_to_asset(prop)

static func _load_scene(path: String) -> PackedScene:
    if not _scene_cache.has(path):
        _scene_cache[path] = load(path) as PackedScene
    return _scene_cache[path]
