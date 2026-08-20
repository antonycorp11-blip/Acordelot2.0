extends Node3D
class_name ZoneBuilder

const PortalScript = preload("res://scripts/zone_portal.gd")

signal portal_triggered(dest_zone_id: String, from_direction: String)

const TAMANHO_ZONA: float = 160.0 # 160m x 160m cluster
const SUBDIVISOES: int = 64        # Resolução de malha suave

var _zone_data: Dictionary = {}
var _asset_catalog: Dictionary = {}
var _city_layouts: Dictionary = {}
var _tripo_material: Material = preload("res://Material_TripoSR.tres")

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
    var tipo_terreno: String = str(_zone_data.get("terrain_type", "colinas_suaves"))
    var d_centro: float = Vector2(x, z).length()
    
    match tipo_terreno:
        "plato_urbano":
            if d_centro < 45.0:
                return 0.0
            var t: float = clampf((d_centro - 45.0) / 30.0, 0.0, 1.0)
            var morro: float = (sin(x * 0.08) * cos(z * 0.08)) * 2.5
            return morro * t
            
        "bacia_lago":
            var depressao: float = -3.2 * exp(-(d_centro * d_centro) / (45.0 * 45.0))
            var relevo: float = (sin(x * 0.06) + cos(z * 0.06)) * 1.2
            return depressao + relevo
            
        "plato_montanha":
            var base: float = 3.5
            var rugoso: float = sin(x * 0.09) * cos(z * 0.09) * 2.0
            return base + rugoso
            
        "clareira_sagrada":
            var anel: float = sin(d_centro * 0.1) * 1.5
            return anel
            
        "colinas_sombrias":
            return sin(x * 0.08 + z * 0.05) * 2.5 + cos(x * 0.04 - z * 0.08) * 2.5
            
        _: # "colinas_suaves" (floresta inicial)
            return sin(x * 0.06) * 1.8 + cos(z * 0.06) * 1.6

func _construir_terreno() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    
    var step: float = TAMANHO_ZONA / float(SUBDIVISOES)
    var half: float = TAMANHO_ZONA * 0.5
    
    for j in range(SUBDIVISOES + 1):
        for i in range(SUBDIVISOES + 1):
            var x: float = -half + float(i) * step
            var z: float = -half + float(j) * step
            var y: float = calcular_altura(x, z)
            
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
            st.add_index(i1)
            st.add_index(i2)
            
            st.add_index(i1)
            st.add_index(i3)
            st.add_index(i2)
            
    st.generate_normals()
    var mesh := st.commit()
    
    _terrain_mesh = MeshInstance3D.new()
    _terrain_mesh.mesh = mesh
    _terrain_mesh.name = "TerrainMesh"
    
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/zoned_ground.gdshader")
    mat.set_shader_parameter("grass_texture", load("res://textures/grass_seamless.png"))
    mat.set_shader_parameter("dirt_texture", load("res://textures/dirt_seamless.png"))
    mat.set_shader_parameter("stone_texture", load("res://textures/flagstone_seamless.png"))
    mat.set_shader_parameter("rock_texture", load("res://textures/stone_seamless.png"))
    mat.set_shader_parameter("zone_size", Vector2(TAMANHO_ZONA, TAMANHO_ZONA))
    
    _terrain_mesh.material_override = mat
    add_child(_terrain_mesh)
    
    _terrain_body = StaticBody3D.new()
    _terrain_body.name = "TerrainCollision"
    var col := CollisionShape3D.new()
    col.shape = mesh.create_trimesh_shape()
    _terrain_body.add_child(col)
    add_child(_terrain_body)

# -------------------------------------------------------------
# 2. Grama 3D Volumétrica com Vento
# -------------------------------------------------------------
func _construir_grama_densa() -> void:
    var densidade: int = int(_zone_data.get("grass_density", 900))
    if densidade <= 0:
        return
        
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.instance_count = densidade
    
    var grass_quad := QuadMesh.new()
    grass_quad.size = Vector2(0.9, 0.9)
    grass_quad.center_offset = Vector3(0.0, 0.45, 0.0)
    mm.mesh = grass_quad
    
    _grass_multimesh = MultiMeshInstance3D.new()
    _grass_multimesh.name = "GrassMultiMesh"
    _grass_multimesh.multimesh = mm
    
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/zoned_grass_blade.gdshader")
    mat.set_shader_parameter("grass_albedo", load("res://textures/props/tufo_grama_1.png"))
    _grass_multimesh.material_override = mat
    
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zone"))) + 99
    
    var half: float = (TAMANHO_ZONA * 0.5) - 8.0
    var count: int = 0
    var tries: int = 0
    
    while count < densidade and tries < densidade * 3:
        tries += 1
        var rx: float = rng.randf_range(-half, half)
        var rz: float = rng.randf_range(-half, half)
        
        var dist_c: float = Vector2(rx, rz).length()
        if _zone_data.get("biome") == "cidade" and dist_c < 26.0:
            continue
            
        var ry: float = calcular_altura(rx, rz)
        if _zone_data.get("water", false) and ry < float(_zone_data.get("water_level", -2.0)) + 0.3:
            continue
            
        var scale_rnd: float = rng.randf_range(0.8, 1.2)
        var rot_y: float = rng.randf_range(0.0, TAU)
        
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
    var water_y: float = float(_zone_data.get("water_level", -2.0))
    var plane := PlaneMesh.new()
    plane.size = Vector2(TAMANHO_ZONA, TAMANHO_ZONA)
    
    _water_mesh = MeshInstance3D.new()
    _water_mesh.name = "WaterPlane"
    _water_mesh.mesh = plane
    _water_mesh.position = Vector3(0.0, water_y, 0.0)
    
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/agua.gdshader")
    mat.set_shader_parameter("cor_profunda", Color(0.14, 0.32, 0.5, 0.95))
    mat.set_shader_parameter("cor_superficie", Color(0.28, 0.68, 0.8, 0.8))
    _water_mesh.material_override = mat
    add_child(_water_mesh)

# -------------------------------------------------------------
# 4. Construções da Cidade / Layout Urbano
# -------------------------------------------------------------
func _construir_layout_urbano() -> void:
    var layout_id: String = str(_zone_data.get("layout_id", ""))
    if layout_id == "" or not _city_layouts.has(layout_id):
        return
        
    var layout: Dictionary = _city_layouts[layout_id]
    var pecas: Array = layout.get("pecas", [])
    
    for p in pecas:
        var tag: String = str(p.get("tag", ""))
        var kind: Dictionary = _asset_catalog.get(tag, {})
        var modelo_path: String = _obter_modelo_path(p, tag)
        if modelo_path == "":
            continue
            
        var suporte := _criar_suporte_prop(modelo_path, tag, kind, float(p.get("escala", 1.0)))
        if not suporte:
            continue
            
        var px: float = float(p.get("x", 0.0))
        var pz: float = float(p.get("z", 0.0))
        var py: float = calcular_altura(px, pz) + float(p.get("y", 0.0))
        var giro: float = float(p.get("giro", 0.0))
        
        suporte.position = Vector3(px, py, pz)
        suporte.rotation.y = deg_to_rad(giro)
        
        _adicionar_colisor_prop(suporte, tag, float(p.get("escala", 1.0)))
        _props_node.add_child(suporte)

# -------------------------------------------------------------
# 5. Vegetação e Props Orgânicos
# -------------------------------------------------------------
func _construir_props_bioma() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zone"))) + 42
    
    var n_arvores: int = int(_zone_data.get("tree_count", 30))
    var n_arbustos: int = int(_zone_data.get("bush_count", 15))
    
    var modelos_arvores = [
        {"path": "res://models/arvore_frondosa.glb", "tag": "arvore_frondosa"},
        {"path": "res://models/arvore_carvalho.glb", "tag": "arvore_carvalho"},
        {"path": "res://models/arvore_pequena.glb", "tag": "arvore_pequena"}
    ]
    var modelos_arbustos = [
        {"path": "res://models/fantasy_bush_1787078968444.glb", "tag": "arbusto"}
    ]
    
    _espalhar_props(rng, n_arvores, modelos_arvores, 55.0, true)
    _espalhar_props(rng, n_arbustos, modelos_arbustos, 65.0, false)

func _espalhar_props(rng: RandomNumberGenerator, qtd: int, lista_modelos: Array, raio_max: float, solido: bool) -> void:
    var is_cidade: bool = (_zone_data.get("biome") == "cidade")
    var water_y: float = float(_zone_data.get("water_level", -2.0))
    var tem_agua: bool = bool(_zone_data.get("water", false))
    
    for i in range(qtd):
        var item: Dictionary = lista_modelos[rng.randi() % lista_modelos.size()]
        var path: String = str(item["path"])
        var tag: String = str(item["tag"])
        var kind: Dictionary = _asset_catalog.get(tag, {})
        
        var escala_extra: float = rng.randf_range(0.9, 1.2)
        var suporte := _criar_suporte_prop(path, tag, kind, escala_extra)
        if not suporte:
            continue
            
        var ang: float = rng.randf_range(0.0, TAU)
        var dist_min: float = 30.0 if is_cidade else 6.0
        var dist: float = rng.randf_range(dist_min, raio_max)
        var px: float = cos(ang) * dist
        var pz: float = sin(ang) * dist
        var py: float = calcular_altura(px, pz)
        
        if tem_agua and py < water_y + 0.4:
            suporte.queue_free()
            continue
            
        suporte.position = Vector3(px, py, pz)
        suporte.rotation.y = rng.randf_range(0.0, TAU)
        
        if solido:
            _adicionar_colisor_prop(suporte, tag, escala_extra)
            
        _props_node.add_child(suporte)

# -------------------------------------------------------------
# 6. Barreiras Naturais de Perímetro
# -------------------------------------------------------------
func _construir_barreiras_perimetro() -> void:
    var exits: Dictionary = _zone_data.get("exits", {})
    var half: float = (TAMANHO_ZONA * 0.5) - 4.0
    var portal_gap: float = 14.0
    var kind_arvore: Dictionary = _asset_catalog.get("arvore_frondosa", {"altura": 7.0})
    
    var num_passos: int = int(TAMANHO_ZONA / 7.0)
    for step in range(num_passos):
        var pos_along: float = -half + float(step) * 7.0
        
        # Norte
        if exits.get("north", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda(Vector3(pos_along, calcular_altura(pos_along, -half), -half), kind_arvore)
        # Sul
        if exits.get("south", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda(Vector3(pos_along, calcular_altura(pos_along, half), half), kind_arvore)
        # Oeste
        if exits.get("west", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda(Vector3(-half, calcular_altura(-half, pos_along), pos_along), kind_arvore)
        # Leste
        if exits.get("east", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda(Vector3(half, calcular_altura(half, pos_along), pos_along), kind_arvore)

func _criar_arvore_borda(pos: Vector3, kind: Dictionary) -> void:
    var suporte := _criar_suporte_prop("res://models/arvore_frondosa.glb", "arvore_frondosa", kind, 1.1)
    if not suporte:
        return
    suporte.position = pos
    _adicionar_colisor_prop(suporte, "arvore", 1.1)
    _props_node.add_child(suporte)

# -------------------------------------------------------------
# 7. Portais de Transição
# -------------------------------------------------------------
func _construir_portais() -> void:
    var exits: Dictionary = _zone_data.get("exits", {})
    var dist: float = (TAMANHO_ZONA * 0.5) - 8.0
    
    var configs = [
        {"dir": "north", "dest": exits.get("north", ""), "pos": Vector3(0.0, 0.0, -dist), "rot": 0.0},
        {"dir": "south", "dest": exits.get("south", ""), "pos": Vector3(0.0, 0.0, dist), "rot": 180.0},
        {"dir": "east",  "dest": exits.get("east", ""),  "pos": Vector3(dist, 0.0, 0.0), "rot": 90.0},
        {"dir": "west",  "dest": exits.get("west", ""),  "pos": Vector3(-dist, 0.0, 0.0), "rot": -90.0},
    ]
    
    for cfg in configs:
        var dest_id: String = str(cfg["dest"])
        if dest_id == "":
            continue
            
        var portal = PortalScript.new()
        portal.dest_zone_id = dest_id
        portal.direction = str(cfg["dir"])
        portal.name = "Portal_" + str(cfg["dir"]).capitalize()
        
        var target_pos: Vector3 = cfg["pos"]
        target_pos.y = calcular_altura(target_pos.x, target_pos.z)
        portal.position = target_pos
        portal.rotation.y = deg_to_rad(float(cfg["rot"]))
        
        portal.player_entered_portal.connect(func(did: String, fdir: String):
            portal_triggered.emit(did, fdir)
        )
        _portals_node.add_child(portal)

# -------------------------------------------------------------
# Helpers de Medição, Material e Apoio de Pé no Chão
# -------------------------------------------------------------
func _criar_suporte_prop(path: String, tag: String, kind: Dictionary, escala_mult: float = 1.0) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    var res := load(path)
    if not (res is PackedScene):
        return null
        
    var modelo: Node3D = (res as PackedScene).instantiate()
    if not modelo:
        return null
        
    var suporte := Node3D.new()
    suporte.name = tag
    
    # Aplica Material_TripoSR com vertex_color_use_as_albedo caso não seja modelo com textura PBR customizada
    var keep_mat: bool = bool(kind.get("keep_materials", false)) or tag.begins_with("casa_enxaimel") or tag.begins_with("mansao") or tag == "grama_3d"
    if not keep_mat:
        for mesh_node in modelo.find_children("*", "MeshInstance3D", true, false):
            mesh_node.material_override = _tripo_material
            
    suporte.add_child(modelo)
    
    # Mede a caixa AABB real do modelo para alinhar perfeitamente no chão e escalar
    var caixa: AABB = _caixa_do_modelo(modelo)
    var fator: float = 1.0
    var altura_alvo: float = float(kind.get("altura", 0.0))
    if altura_alvo > 0.0 and caixa.size.y > 0.0001:
        fator = (altura_alvo / caixa.size.y) * escala_mult
    else:
        fator = escala_mult
        
    modelo.scale = Vector3.ONE * fator
    # Apoia o pé do modelo no chão (y = 0 local do suporte)
    modelo.position.y = -caixa.position.y * fator
    
    return suporte

func _caixa_do_modelo(modelo: Node3D) -> AABB:
    var caixa := AABB()
    var achou := false
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var local: AABB = _ate_a_raiz(malha, modelo) * malha.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    return caixa if achou else AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))

func _ate_a_raiz(no: Node3D, raiz: Node3D) -> Transform3D:
    var acumulado := Transform3D.IDENTITY
    var atual: Node3D = no
    while atual != null and atual != raiz:
        acumulado = atual.transform * acumulado
        atual = atual.get_parent() as Node3D
    return acumulado

func _obter_modelo_path(p: Dictionary, tag: String) -> String:
    var m_nome: String = str(p.get("modelo", ""))
    if m_nome != "":
        var glb := "res://models/%s.glb" % m_nome
        if ResourceLoader.exists(glb):
            return glb
            
    if _asset_catalog.has(tag):
        var c_models: Array = _asset_catalog[tag].get("models", [])
        if not c_models.is_empty() and ResourceLoader.exists(str(c_models[0])):
            return str(c_models[0])
    return ""

func _adicionar_colisor_prop(node: Node3D, tag: String, escala: float) -> void:
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    
    if tag.begins_with("arvore"):
        shape.radius = 0.5 * escala
        shape.height = 3.5 * escala
        col.position.y = shape.height * 0.5
    elif tag.begins_with("casa") or tag.begins_with("mansao") or tag.begins_with("sobrado"):
        var box := BoxShape3D.new()
        box.size = Vector3(5.5 * escala, 5.0 * escala, 5.5 * escala)
        col.shape = box
        col.position.y = box.size.y * 0.5
        body.add_child(col)
        node.add_child(body)
        return
    else:
        shape.radius = 0.6 * escala
        shape.height = 1.4 * escala
        col.position.y = shape.height * 0.5
        
    col.shape = shape
    body.add_child(col)
    node.add_child(body)
