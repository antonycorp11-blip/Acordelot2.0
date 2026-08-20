extends Node3D
class_name ZoneBuilder

const PortalScript = preload("res://scripts/zone_portal.gd")

signal portal_triggered(dest_zone_id: String, from_direction: String)

const TAMANHO_ZONA := 160.0 # 160m x 160m cluster
const SUBDIVISOES := 64      # Resolução de malha suave

var _zone_data: Dictionary = {}
var _asset_catalog: Dictionary = {}
var _city_layouts: Dictionary = {}

var _terrain_mesh: MeshInstance3D
var _terrain_body: StaticBody3D
var _grass_multimesh: MultiMeshInstance3D
var _water_mesh: MeshInstance3D
var _portals_node: Node3D
var _props_node: Node3D

func carregar_dados() -> void:
    if _asset_catalog.is_empty():
        var f_cat := FileAccess.open("res://data/asset_catalog.json", FileAccess.READ)
        if f_cat:
            _asset_catalog = JSON.parse_string(f_cat.get_as_text())
            
    if _city_layouts.is_empty():
        var f_lay := FileAccess.open("res://data/city_layouts.json", FileAccess.READ)
        if f_lay:
            _city_layouts = JSON.parse_string(f_lay.get_as_text())

func construir_zona(zone_data: Dictionary) -> void:
    _zone_data = zone_data
    carregar_dados()
    
    # Limpa nós anteriores
    for c in get_children():
        c.queue_free()
        
    _props_node = Node3D.new()
    _props_node.name = "Props"
    add_child(_props_node)
    
    _portals_node = Node3D.new()
    _portals_node.name = "Portals"
    add_child(_portals_node)
    
    _construir_terreno()
    _construir_grama_densa()
    
    if _zone_data.get("water", false):
        _construir_agua()
        
    _construir_layout_urbano()
    _construir_props_bioma()
    _construir_barreiras_perimetro()
    _construir_portais()

# -------------------------------------------------------------
# 1. Terreno com Altura e Shader Zoned
# -------------------------------------------------------------
func calcular_altura(x: float, z: float) -> float:
    var tipo_terreno: String = _zone_data.get("terrain_type", "colinas_suaves")
    var d_centro := Vector2(x, z).length()
    
    match tipo_terreno:
        "plato_urbano":
            # Cidade com platô central suave e leve elevação nas bordas
            if d_centro < 50.0:
                return 0.0
            var t: float = clampf((d_centro - 50.0) / 25.0, 0.0, 1.0)
            var morro: float = sin(x * 0.08) * cos(z * 0.08) * 3.5
            return morro * t
            
        "bacia_lago":
            # Depressão central com água
            var depressao := -3.5 * exp(-(d_centro * d_centro) / (45.0 * 45.0))
            var relevo := sin(x * 0.06) * 2.0 + cos(z * 0.06) * 2.0
            return depressao + relevo * 0.5
            
        "plato_montanha":
            # Platô elevado com encostas rochosas
            var base := 5.0
            var rugoso := sin(x * 0.1) * cos(z * 0.1) * 2.5 + sin(x * 0.25 + z * 0.25) * 1.2
            return base + rugoso
            
        "clareira_sagrada":
            # Clareira circular plana com anel elevado
            var anel := sin(d_centro * 0.12) * 2.0
            return anel
            
        "colinas_sombrias":
            # Relevo retorcido e vales
            return sin(x * 0.09 + z * 0.05) * 3.0 + cos(x * 0.04 - z * 0.1) * 3.5
            
        _: # "colinas_suaves" (floresta inicial)
            return sin(x * 0.07) * 2.2 + cos(z * 0.07) * 2.0 + sin((x + z) * 0.04) * 1.5

func _construir_terreno() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    
    var step := TAMANHO_ZONA / float(SUBDIVISOES)
    var half := TAMANHO_ZONA * 0.5
    
    # Gera vértices e triângulos
    for j in range(SUBDIVISOES + 1):
        for i in range(SUBDIVISOES + 1):
            var x := -half + i * step
            var z := -half + j * step
            var y := calcular_altura(x, z)
            
            var uv := Vector2(float(i) / float(SUBDIVISOES), float(j) / float(SUBDIVISOES))
            st.set_uv(uv)
            st.add_vertex(Vector3(x, y, z))
            
    for j in range(SUBDIVISOES):
        for i in range(SUBDIVISOES):
            var i0 := j * (SUBDIVISOES + 1) + i
            var i1 := i0 + 1
            var i2 := (j + 1) * (SUBDIVISOES + 1) + i
            var i3 := i2 + 1
            
            st.add_index(i0)
            st.add_index(i2)
            st.add_index(i1)
            
            st.add_index(i1)
            st.add_index(i2)
            st.add_index(i3)
            
    st.generate_normals()
    var mesh := st.commit()
    
    _terrain_mesh = MeshInstance3D.new()
    _terrain_mesh.mesh = mesh
    _terrain_mesh.name = "TerrainMesh"
    
    # Material Shader com 4 texturas PBR
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/zoned_ground.gdshader")
    mat.set_shader_parameter("grass_texture", load("res://textures/grass_seamless.png"))
    mat.set_shader_parameter("dirt_texture", load("res://textures/dirt_seamless.png"))
    mat.set_shader_parameter("stone_texture", load("res://textures/flagstone_seamless.png"))
    mat.set_shader_parameter("rock_texture", load("res://textures/stone_seamless.png"))
    mat.set_shader_parameter("zone_size", Vector2(TAMANHO_ZONA, TAMANHO_ZONA))
    
    _terrain_mesh.material_override = mat
    add_child(_terrain_mesh)
    
    # Colisão do Terreno
    _terrain_body = StaticBody3D.new()
    _terrain_body.name = "TerrainCollision"
    var col := CollisionShape3D.new()
    col.shape = mesh.create_trimesh_shape()
    _terrain_body.add_child(col)
    add_child(_terrain_body)

# -------------------------------------------------------------
# 2. Grama 3D Volumétrica Densa com MultiMesh & Vento
# -------------------------------------------------------------
func _construir_grama_densa() -> void:
    var densidade: int = _zone_data.get("grass_density", 1200)
    if densidade <= 0:
        return
        
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.instance_count = densidade
    
    # Malha de tufo em cruz (2 quads cruzados em 90 graus)
    var grass_quad := QuadMesh.new()
    grass_quad.size = Vector2(1.1, 1.3)
    grass_quad.center_offset = Vector3(0.0, 0.65, 0.0)
    mm.mesh = grass_quad
    
    _grass_multimesh = MultiMeshInstance3D.new()
    _grass_multimesh.name = "GrassMultiMesh"
    _grass_multimesh.multimesh = mm
    
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/zoned_grass_blade.gdshader")
    mat.set_shader_parameter("grass_albedo", load("res://textures/props/tufo_grama_1.png"))
    _grass_multimesh.material_override = mat
    
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(_zone_data.get("id", "zone")) + 99
    
    var half := (TAMANHO_ZONA * 0.5) - 8.0
    var count := 0
    var tries := 0
    
    while count < densidade and tries < densidade * 3:
        tries += 1
        var rx := rng.randf_range(-half, half)
        var rz := rng.randf_range(-half, half)
        
        # Evita estradas centrais nas cidades
        var dist_c := Vector2(rx, rz).length()
        if _zone_data.get("biome") == "cidade" and dist_c < 28.0:
            continue
            
        var ry := calcular_altura(rx, rz)
        # Evita debaixo d'água
        if _zone_data.get("water", false) and ry < _zone_data.get("water_level", -2.0) + 0.3:
            continue
            
        var scale_rnd := rng.randf_range(0.85, 1.35)
        var rot_y := rng.randf_range(0.0, TAU)
        
        var t := Transform3D()
        t = t.scaled(Vector3(scale_rnd, scale_rnd, scale_rnd))
        t = t.rotated(Vector3.UP, rot_y)
        t.origin = Vector3(rx, ry, rz)
        
        mm.set_instance_transform(count, t)
        count += 1
        
    mm.visible_instance_count = count
    add_child(_grass_multimesh)

# -------------------------------------------------------------
# 3. Lâmina d'água
# -------------------------------------------------------------
func _construir_agua() -> void:
    var water_y: float = _zone_data.get("water_level", -2.0)
    var plane := PlaneMesh.new()
    plane.size = Vector2(TAMANHO_ZONA, TAMANHO_ZONA)
    plane.subdivide_width = 16
    plane.subdivide_depth = 16
    
    _water_mesh = MeshInstance3D.new()
    _water_mesh.name = "WaterPlane"
    _water_mesh.mesh = plane
    _water_mesh.position = Vector3(0.0, water_y, 0.0)
    
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/agua.gdshader")
    mat.set_shader_parameter("cor_profunda", Color(0.12, 0.28, 0.45, 0.95))
    mat.set_shader_parameter("cor_superficie", Color(0.25, 0.65, 0.75, 0.8))
    _water_mesh.material_override = mat
    add_child(_water_mesh)

# -------------------------------------------------------------
# 4. Construções da Cidade / Layout Urbano
# -------------------------------------------------------------
func _construir_layout_urbano() -> void:
    var layout_id: String = _zone_data.get("layout_id", "")
    if layout_id == "" or not _city_layouts.has(layout_id):
        return
        
    var layout: Dictionary = _city_layouts[layout_id]
    var pecas: Array = layout.get("pecas", [])
    
    for p in pecas:
        var tag: String = p.get("tag", "")
        var modelo_path := _obter_modelo_path(p, tag)
        if modelo_path == "":
            continue
            
        var inst := _instanciar_modelo(modelo_path)
        if not inst:
            continue
            
        var px: float = p.get("x", 0.0)
        var pz: float = p.get("z", 0.0)
        var py: float = calcular_altura(px, pz) + float(p.get("y", 0.0))
        var giro: float = p.get("giro", 0.0)
        var esc: float = p.get("escala", 1.0)
        
        inst.position = Vector3(px, py, pz)
        inst.rotation.y = deg_to_rad(giro)
        inst.scale = Vector3(esc, esc, esc)
        
        _adicionar_colisor_prop(inst, tag, esc)
        _props_node.add_child(inst)

# -------------------------------------------------------------
# 5. Vegetação e Props Orgânicos
# -------------------------------------------------------------
func _construir_props_bioma() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(_zone_data.get("id", "zone")) + 42
    
    var n_arvores: int = _zone_data.get("tree_count", 30)
    var n_arbustos: int = _zone_data.get("bush_count", 15)
    var n_pedras: int = _zone_data.get("rock_count", 10)
    
    var modelos_arvores = [
        "res://models/arvore_frondosa.glb",
        "res://models/arvore_carvalho.glb",
        "res://models/arvore_pequena.glb"
    ]
    var modelos_arbustos = [
        "res://models/fantasy_bush_1787078968444.glb"
    ]
    
    # Árvores
    _espalhar_props(rng, n_arvores, modelos_arvores, 1.8, 3.2, 55.0, true)
    # Arbustos
    _espalhar_props(rng, n_arbustos, modelos_arbustos, 1.0, 1.8, 65.0, false)

func _espalhar_props(rng: RandomNumberGenerator, qtd: int, modelos: Array, esc_min: float, esc_max: float, raio_max: float, solido: bool) -> void:
    var is_cidade: bool = (_zone_data.get("biome") == "cidade")
    var water_y: float = _zone_data.get("water_level", -2.0)
    var tem_agua: bool = _zone_data.get("water", false)
    
    for i in range(qtd):
        var path: String = modelos[rng.randi() % modelos.size()]
        var inst := _instanciar_modelo(path)
        if not inst:
            continue
            
        var ang := rng.randf_range(0.0, TAU)
        var dist_min := 35.0 if is_cidade else 6.0
        var dist := rng.randf_range(dist_min, raio_max)
        var px := cos(ang) * dist
        var pz := sin(ang) * dist
        var py := calcular_altura(px, pz)
        
        if tem_agua and py < water_y + 0.4:
            inst.queue_free()
            continue
            
        var esc := rng.randf_range(esc_min, esc_max)
        inst.position = Vector3(px, py, pz)
        inst.rotation.y = rng.randf_range(0.0, TAU)
        inst.scale = Vector3(esc, esc, esc)
        
        if solido:
            _adicionar_colisor_prop(inst, "arvore", esc)
            
        _props_node.add_child(inst)

# -------------------------------------------------------------
# 6. Barreiras Naturais de Perímetro
# -------------------------------------------------------------
func _construir_barreiras_perimetro() -> void:
    # Cria cinturão de árvores densas nas bordas, deixando aberturas apenas nos portais
    var exits: Dictionary = _zone_data.get("exits", {})
    var half := (TAMANHO_ZONA * 0.5) - 4.0
    var portal_gap := 14.0
    
    var arvore_path := "res://models/arvore_frondosa.glb"
    
    for step in range(int(TAMANHO_ZONA / 5.5)):
        var pos_along := -half + step * 5.5
        
        # Borda Norte (Z = -half)
        if exits.get("north", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda(Vector3(pos_along, calcular_altura(pos_along, -half), -half))
            
        # Borda Sul (Z = +half)
        if exits.get("south", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda(Vector3(pos_along, calcular_altura(pos_along, half), half))
            
        # Borda Oeste (X = -half)
        if exits.get("west", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda(Vector3(-half, calcular_altura(-half, pos_along), pos_along))
            
        # Borda Leste (X = +half)
        if exits.get("east", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda(Vector3(half, calcular_altura(half, pos_along), pos_along))

func _criar_arvore_borda(pos: Vector3) -> void:
    var inst := _instanciar_modelo("res://models/arvore_frondosa.glb")
    if not inst:
        return
    inst.position = pos
    var esc := 2.6
    inst.scale = Vector3(esc, esc, esc)
    _adicionar_colisor_prop(inst, "arvore", esc)
    _props_node.add_child(inst)

# -------------------------------------------------------------
# 7. Portais de Transição
# -------------------------------------------------------------
func _construir_portais() -> void:
    var exits: Dictionary = _zone_data.get("exits", {})
    var dist := (TAMANHO_ZONA * 0.5) - 8.0
    
    var configs = [
        {"dir": "north", "dest": exits.get("north", ""), "pos": Vector3(0.0, 0.0, -dist), "rot": 0.0},
        {"dir": "south", "dest": exits.get("south", ""), "pos": Vector3(0.0, 0.0, dist), "rot": 180.0},
        {"dir": "east",  "dest": exits.get("east", ""),  "pos": Vector3(dist, 0.0, 0.0), "rot": 90.0},
        {"dir": "west",  "dest": exits.get("west", ""),  "pos": Vector3(-dist, 0.0, 0.0), "rot": -90.0},
    ]
    
    for cfg in configs:
        var dest_id: String = cfg["dest"]
        if dest_id == "":
            continue
            
        var portal = PortalScript.new()
        portal.dest_zone_id = dest_id
        portal.direction = cfg["dir"]
        portal.name = "Portal_" + cfg["dir"].capitalize()
        
        var target_pos: Vector3 = cfg["pos"]
        target_pos.y = calcular_altura(target_pos.x, target_pos.z)
        portal.position = target_pos
        portal.rotation.y = deg_to_rad(cfg["rot"])
        
        portal.player_entered_portal.connect(func(did: String, fdir: String):
            portal_triggered.emit(did, fdir)
        )
        _portals_node.add_child(portal)

# -------------------------------------------------------------
# Helpers de Instanciação e Colisão
# -------------------------------------------------------------
func _obter_modelo_path(p: Dictionary, tag: String) -> String:
    var m_nome: String = p.get("modelo", "")
    if m_nome != "":
        var glb := "res://models/%s.glb" % m_nome
        if ResourceLoader.exists(glb):
            return glb
            
    if _asset_catalog.has(tag):
        var c_models: Array = _asset_catalog[tag].get("models", [])
        if not c_models.is_empty() and ResourceLoader.exists(c_models[0]):
            return c_models[0]
    return ""

func _instanciar_modelo(path: String) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    var res := load(path)
    if res is PackedScene:
        return res.instantiate() as Node3D
    return null

func _adicionar_colisor_prop(node: Node3D, tag: String, escala: float) -> void:
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    
    if tag.begins_with("arvore"):
        shape.radius = 0.55 * escala
        shape.height = 3.5 * escala
        col.position.y = shape.height * 0.5
    elif tag.begins_with("casa") or tag.begins_with("mansao") or tag.begins_with("sobrado"):
        var box := BoxShape3D.new()
        box.size = Vector3(6.5 * escala, 6.0 * escala, 6.5 * escala)
        col.shape = box
        col.position.y = box.size.y * 0.5
        body.add_child(col)
        node.add_child(body)
        return
    else:
        shape.radius = 0.8 * escala
        shape.height = 1.6 * escala
        col.position.y = shape.height * 0.5
        
    col.shape = shape
    body.add_child(col)
    node.add_child(body)
