extends Node3D
class_name ZoneBuilder

const PortalScript = preload("res://scripts/zone_portal.gd")
const BichoScript = preload("res://scripts/bicho.gd")

signal portal_triggered(dest_zone_id: String, from_direction: String)

const TAMANHO_ZONA: float = 160.0 # 160m x 160m cluster
const SUBDIVISOES: int = 64        # Resolução de malha suave

var _zone_data: Dictionary = {}
var _city_layouts: Dictionary = {}

var _terrain_mesh: MeshInstance3D
var _terrain_body: StaticBody3D
var _water_mesh: MeshInstance3D
var _portals_node: Node3D
var _props_node: Node3D

# Banco Exclusivo de Novos Modelos 3D Reais com Texturas e Alturas Reais
const ARVORES_FLORESTA_3D := [
    {"path": "res://models/tree_gn.glb", "tag": "arvore_gigante", "altura": 17.0, "enterrar": 0.65},
    {"path": "res://models/oak_trees.glb", "tag": "carvalho_real", "altura": 15.0, "enterrar": 0.55},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 14.0, "enterrar": 0.50},
    {"path": "res://models/japanese_maple_tree.glb", "tag": "bordo_japones", "altura": 15.5, "enterrar": 0.55},
    {"path": "res://models/platano_tree.glb", "tag": "platano_real", "altura": 16.0, "enterrar": 0.60}
]

const ARVORES_MISTICAS_3D := [
    {"path": "res://models/mushroom_tree.glb", "tag": "cogumelo_arvore", "altura": 11.5, "enterrar": 0.45},
    {"path": "res://models/japanese_maple_tree.glb", "tag": "bordo_japones", "altura": 15.0, "enterrar": 0.55},
    {"path": "res://models/platano_tree.glb", "tag": "platano_real", "altura": 15.5, "enterrar": 0.60},
    {"path": "res://models/crystal_cluster_1787078933118.glb", "tag": "cristal_arcano", "altura": 4.5, "enterrar": 0.25}
]

const ARBUSTOS_3D := [
    {"path": "res://models/fantasy_bush_1787078968444.glb", "tag": "arbusto_3d", "altura": 2.8, "enterrar": 0.3}
]

func carregar_dados() -> void:
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
    
    if _zone_data.get("water", false):
        _construir_agua()
        
    _construir_layout_urbano()
    _construir_floresta_3d_real()
    _construir_barreiras_perimetro_arvores_reais()
    _construir_monstros()
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
            var i0: int = j * (SUBDIVISOES + 1) + i
            var i1: int = i0 + 1
            var i2: int = (j + 1) * (SUBDIVISOES + 1) + i
            var i3: int = i2 + 1
            
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
# 2. Lâmina d'água
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
# 3. Construções 3D da Cidade / Casas Medievais PBR
# -------------------------------------------------------------
func _construir_layout_urbano() -> void:
    var layout_id: String = str(_zone_data.get("layout_id", ""))
    if layout_id == "" or not _city_layouts.has(layout_id):
        return
        
    var layout: Dictionary = _city_layouts[layout_id]
    var pecas: Array = layout.get("pecas", [])
    
    for p in pecas:
        var tag: String = str(p.get("tag", ""))
        var modelo_info := _obter_modelo_urbano_info(p, tag)
        var modelo_path: String = modelo_info.get("path", "")
        if modelo_path == "":
            continue
            
        var altura_alvo: float = float(modelo_info.get("altura", 9.5))
        var escala_layout: float = float(p.get("escala", 1.0))
        
        var suporte := _instanciar_prop_3d(modelo_path, tag, altura_alvo, escala_layout)
        if not suporte:
            continue
            
        var px: float = float(p.get("x", 0.0))
        var pz: float = float(p.get("z", 0.0))
        var py: float = calcular_altura(px, pz) + float(p.get("y", 0.0)) - 0.25 # Assenta a base da casa firme no solo
        var giro: float = float(p.get("giro", 0.0))
        
        suporte.position = Vector3(px, py, pz)
        suporte.rotation.y = deg_to_rad(giro)
        
        _adicionar_colisor_prop(suporte, tag, escala_layout * (altura_alvo / 7.0))
        _props_node.add_child(suporte)

func _obter_modelo_urbano_info(p: Dictionary, tag: String) -> Dictionary:
    var houses = [
        {"path": "res://models/medieval_house_1.glb", "altura": 10.0},
        {"path": "res://models/medieval_house_3.glb", "altura": 9.5}
    ]
    
    if tag.begins_with("casa") or tag.begins_with("mansao") or tag.begins_with("sobrado") or tag.begins_with("predio"):
        return houses[hash(str(p.get("x", 0))) % houses.size()]
        
    if tag == "muralha" or tag == "muro":
        return {"path": "res://models/stone_wall_segment_1787079001245.glb", "altura": 3.8}
        
    if tag == "cristal":
        return {"path": "res://models/crystal_cluster_1787078933118.glb", "altura": 4.5}
        
    return houses[0]

# -------------------------------------------------------------
# 4. Floresta 100% 3D em Escala Real (Cidades Limpas)
# -------------------------------------------------------------
func _construir_floresta_3d_real() -> void:
    var is_cidade: bool = (_zone_data.get("biome") == "cidade" or str(_zone_data.get("layout_id", "")) != "")
    
    # Cidades ficam bem limpas para planejamento urbano (apenas 3 a 5 árvores decorativas no perímetro)
    var n_arvores: int = 4 if is_cidade else int(_zone_data.get("tree_count", 38))
    var n_arbustos: int = 4 if is_cidade else int(_zone_data.get("bush_count", 22))
    
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zone"))) + 77
    
    var biome: String = str(_zone_data.get("biome", "floresta"))
    var lista_arvores: Array = ARVORES_MISTICAS_3D if (biome == "sagrado" or biome == "sombria") else ARVORES_FLORESTA_3D
    
    var raio_min: float = 52.0 if is_cidade else 8.0
    _espalhar_props_3d(rng, n_arvores, lista_arvores, 64.0, true, 1.0, 1.35, raio_min)
    _espalhar_props_3d(rng, n_arbustos, ARBUSTOS_3D, 65.0, false, 0.9, 1.3, raio_min)

func _espalhar_props_3d(rng: RandomNumberGenerator, qtd: int, lista: Array, raio_max: float, solido: bool, sc_min: float, sc_max: float, dist_min: float) -> void:
    var water_y: float = float(_zone_data.get("water_level", -2.0))
    var tem_agua: bool = bool(_zone_data.get("water", false))
    
    for i in range(qtd):
        var item: Dictionary = lista[rng.randi() % lista.size()]
        var path: String = str(item["path"])
        var tag: String = str(item["tag"])
        var alt_base: float = float(item["altura"])
        var enterrar: float = float(item.get("enterrar", 0.5))
        
        var escala_extra: float = rng.randf_range(sc_min, sc_max)
        var suporte := _instanciar_prop_3d(path, tag, alt_base, escala_extra)
        if not suporte:
            continue
            
        var ang: float = rng.randf_range(0.0, TAU)
        var dist: float = rng.randf_range(dist_min, raio_max)
        var px: float = cos(ang) * dist
        var pz: float = sin(ang) * dist
        # Enterra o tronco/raízes no terreno para não ficarem flutuando
        var py: float = calcular_altura(px, pz) - (enterrar * escala_extra)
        
        if tem_agua and py < water_y + 0.5:
            suporte.queue_free()
            continue
            
        suporte.position = Vector3(px, py, pz)
        suporte.rotation.y = rng.randf_range(0.0, TAU)
        
        if solido:
            _adicionar_colisor_prop(suporte, tag, escala_extra * (alt_base / 12.0))
            
        _props_node.add_child(suporte)

# -------------------------------------------------------------
# 5. Barreiras Naturais de Borda com Árvores 3D Gigantes
# -------------------------------------------------------------
func _construir_barreiras_perimetro_arvores_reais() -> void:
    var exits: Dictionary = _zone_data.get("exits", {})
    var half: float = (TAMANHO_ZONA * 0.5) - 6.0
    var portal_gap: float = 16.0
    
    var num_passos: int = int(TAMANHO_ZONA / 8.5)
    for step in range(num_passos):
        var pos_along: float = -half + float(step) * 8.5
        
        # Norte
        if exits.get("north", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda_3d(Vector3(pos_along, calcular_altura(pos_along, -half), -half), step + 1)
        # Sul
        if exits.get("south", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda_3d(Vector3(pos_along, calcular_altura(pos_along, half), half), step + 2)
        # Oeste
        if exits.get("west", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda_3d(Vector3(-half, calcular_altura(-half, pos_along), pos_along), step + 3)
        # Leste
        if exits.get("east", "") == "" or abs(pos_along) > portal_gap:
            _criar_arvore_borda_3d(Vector3(half, calcular_altura(half, pos_along), pos_along), step + 4)

func _criar_arvore_borda_3d(pos: Vector3, idx_seed: int) -> void:
    var item: Dictionary = ARVORES_FLORESTA_3D[idx_seed % ARVORES_FLORESTA_3D.size()]
    var path: String = str(item["path"])
    var tag: String = str(item["tag"])
    var alt_base: float = float(item["altura"]) * 1.2
    var enterrar: float = float(item.get("enterrar", 0.6))
    
    var suporte := _instanciar_prop_3d(path, tag, alt_base, 1.0)
    if not suporte:
        return
    # Enterra as raízes para ficarem bem firmes no declive da borda
    pos.y -= enterrar
    suporte.position = pos
    _adicionar_colisor_prop(suporte, "arvore", alt_base / 10.0)
    _props_node.add_child(suporte)

# -------------------------------------------------------------
# 6. Portais de Transição
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
        portal.portal_label = "Portal para " + _obter_nome_zona(dest_id)
        portal.name = "Portal_" + str(cfg["dir"]).capitalize()
        
        var target_pos: Vector3 = cfg["pos"]
        target_pos.y = calcular_altura(target_pos.x, target_pos.z)
        portal.position = target_pos
        portal.rotation.y = deg_to_rad(float(cfg["rot"]))
        
        portal.player_entered_portal.connect(func(did: String, fdir: String):
            portal_triggered.emit(did, fdir)
        )
        _portals_node.add_child(portal)

func _obter_nome_zona(zid: String) -> String:
    var zdb = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones_db.json"))
    if zdb and zdb.has("zones") and zdb["zones"].has(zid):
        return zdb["zones"][zid].get("name", "Destino")
    return zid

# -------------------------------------------------------------
# Instanciação 3D Real com Medição AABB e Assentamento no Chão
# -------------------------------------------------------------
func _instanciar_prop_3d(path: String, tag: String, altura_alvo: float, escala_mult: float = 1.0) -> Node3D:
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
    suporte.add_child(modelo)
    
    # Medição da caixa AABB orientada real
    var caixa: AABB = _caixa_do_modelo(modelo)
    var fator: float = 1.0
    if altura_alvo > 0.0 and caixa.size.y > 0.0001:
        fator = (altura_alvo / caixa.size.y) * escala_mult
    else:
        fator = escala_mult
        
    modelo.scale = Vector3.ONE * fator
    # Assenta a base exatamente no chão (y = 0 local)
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

func _adicionar_colisor_prop(node: Node3D, tag: String, escala: float) -> void:
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    
    if tag.begins_with("arvore") or tag.begins_with("carvalho") or tag.begins_with("pinheiro") or tag.begins_with("cogumelo_arvore"):
        var shape := CylinderShape3D.new()
        shape.radius = 0.9 * clampf(escala, 0.8, 1.8)
        shape.height = 5.0 * clampf(escala, 0.8, 2.0)
        col.shape = shape
        col.position.y = shape.height * 0.5
    elif tag.begins_with("casa") or tag.begins_with("mansao") or tag.begins_with("sobrado"):
        var box := BoxShape3D.new()
        box.size = Vector3(6.5 * escala, 6.0 * escala, 6.5 * escala)
        col.shape = box
        col.position.y = box.size.y * 0.5
    else:
        var shape := CylinderShape3D.new()
        shape.radius = 0.7 * escala
        shape.height = 2.0 * escala
        col.shape = shape
        col.position.y = shape.height * 0.5
        
    body.add_child(col)
    node.add_child(body)
    
func _construir_monstros() -> void:
    var is_cidade: bool = (_zone_data.get("biome") == "cidade" or str(_zone_data.get("layout_id", "")) != "")
    if is_cidade:
        return
        
    var qtd_monstros := 16
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zone"))) + 555
    
    for i in range(qtd_monstros):
        var bicho = BichoScript.new()
        bicho.monster_type = i % 4
        bicho.name = "Bicho_%d" % i
        
        var ang: float = rng.randf_range(0.0, TAU)
        var dist: float = rng.randf_range(14.0, 65.0)
        var px: float = cos(ang) * dist
        var pz: float = sin(ang) * dist
        var py: float = calcular_altura(px, pz)
        
        if _zone_data.get("water", false) and py < float(_zone_data.get("water_level", -2.0)) + 0.4:
            continue
            
        bicho.position = Vector3(px, py + 0.1, pz)
        _props_node.add_child(bicho)

