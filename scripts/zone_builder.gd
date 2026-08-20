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
            
            # Ordem dos vertices virada para CIMA.
            #
            # Invertida, dois defeitos aparecem juntos e parecem um so: o chao
            # some (a face de tras e descartada pelo renderizador) e o jogador
            # atravessa (malha de colisao concava so bloqueia pela frente).
            # Era o "nao tenho chao e caio direto".
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
    
    # Material Shader com 4 texturas PBR
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/zoned_ground.gdshader")
    mat.set_shader_parameter("grass_texture", load("res://textures/grass_seamless.png"))
    mat.set_shader_parameter("dirt_texture", load("res://textures/dirt_seamless.png"))
    mat.set_shader_parameter("stone_texture", load("res://textures/flagstone_seamless.png"))
    mat.set_shader_parameter("rock_texture", load("res://textures/stone_seamless.png"))
    mat.set_shader_parameter("zone_size", Vector2(TAMANHO_ZONA, TAMANHO_ZONA))
    # O chao precisa saber onde estao as saidas para desenhar a trilha ate elas.
    var ex: Dictionary = _zone_data.get("exits", {})
    mat.set_shader_parameter("saidas", Vector4(
        1.0 if String(ex.get("north", "")) != "" else 0.0,
        1.0 if String(ex.get("south", "")) != "" else 0.0,
        1.0 if String(ex.get("east", "")) != "" else 0.0,
        1.0 if String(ex.get("west", "")) != "" else 0.0))
    
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
    
    # Tufo de grama em MALHA, nao em plaquinha.
    #
    # A plaquinha denuncia que e plaquinha: de perto se ve o papel, e nenhuma
    # quantidade dela resolve. Com malha o tufo tem volume e recebe luz de todos
    # os lados, e continua barato — o agrupamento nao mudou, entao os milhares de
    # tufos seguem saindo numa chamada de desenho so.
    var tufo: Mesh = _malha_do_tufo()
    if tufo == null:
        return
    mm.mesh = tufo
    
    _grass_multimesh = MultiMeshInstance3D.new()
    _grass_multimesh.name = "GrassMultiMesh"
    _grass_multimesh.multimesh = mm
    
    _grass_multimesh.material_override = _material_de_prop()
    
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
            
        # O modelo do tufo mede 19 cm de altura no arquivo. Sem levar a escala
        # para a altura de grama de verdade, os mil e oitocentos tufos ficam la —
        # e invisiveis, que foi o que aconteceu.
        var scale_rnd := rng.randf_range(0.85, 1.35) * ALTURA_DO_TUFO / _altura_do_modelo_do_tufo()
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
    
    # Alturas em METROS, contra um heroi de 1,75 m. Arvore de mata e alta: nove a
    # quinze metros e o que faz a floresta cercar o jogador em vez de chegar na
    # cintura dele.
    _espalhar_props(rng, n_arvores, modelos_arvores, 9.0, 15.0, 55.0, true)
    _espalhar_props(rng, n_arbustos, modelos_arbustos, 1.1, 2.0, 65.0, false)
    _espalhar_props(rng, n_pedras, [
        "res://models/media_1787068829583.glb",
        "res://models/media_1787078448833.glb",
        "res://models/media_1787078454231.glb",
    ], 0.5, 1.6, 68.0, false)

## Altura da malha de um modelo ja instanciado, em unidades do proprio arquivo.
static func _altura_do_modelo(no: Node3D) -> float:
    var caixa := AABB()
    var achou := false
    for malha in no.find_children("*", "MeshInstance3D", true, false):
        var c: AABB = malha.get_aabb()
        caixa = c if not achou else caixa.merge(c)
        achou = true
    return maxf(caixa.size.y, 0.001) if achou else 1.0

## A malha de um tufo, tirada do GLB e guardada.
##
## MultiMesh precisa de UMA malha, nao de uma cena: abre-se o modelo, pega-se a
## malha de dentro e descarta-se o resto.
## Altura desejada do tufo no mundo, em metros.
const ALTURA_DO_TUFO := 0.55

static var _tufo: Mesh = null

## Altura do tufo COMO ESTA NO ARQUIVO, para converter em escala.
static func _altura_do_modelo_do_tufo() -> float:
    var malha := _malha_do_tufo()
    if malha == null:
        return 1.0
    return maxf(malha.get_aabb().size.y, 0.001)
static func _malha_do_tufo() -> Mesh:
    if _tufo != null:
        return _tufo
    if not ResourceLoader.exists("res://models/grass.glb"):
        return null
    var cena: Node3D = (load("res://models/grass.glb") as PackedScene).instantiate()
    for malha in cena.find_children("*", "MeshInstance3D", true, false):
        _tufo = malha.mesh
        break
    cena.queue_free()
    return _tufo

## Espalha props pelo bioma. esc_min e esc_max sao ALTURA EM METROS, nao fator.
##
## Eram fator de multiplicacao, e por isso nao havia arvore no mapa: os modelos
## do TripoSR chegam normalizados a mais ou menos uma unidade, entao "escala 1,8
## a 3,2" dava arvore de dois a tres metros — altura de arbusto. Pedindo a altura
## e dividindo pelo tamanho do arquivo, arvore de doze metros e doze metros.
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
            
        var alvo_m := rng.randf_range(esc_min, esc_max)
        var esc := alvo_m / _altura_do_modelo(inst)
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

## Uma arvore da mata que fecha a zona.
##
## O cinturao antigo plantava a MESMA arvore, do MESMO tamanho, a cada 5,5 m
## exatos nas quatro bordas: lia como cerca de estaca, nao como mata. Aqui cada
## uma sorteia especie, tamanho, giro e um desvio para dentro e para os lados —
## borda de floresta e irregular, e e a irregularidade que a faz desaparecer
## como limite e virar paisagem.
func _criar_arvore_borda(pos: Vector3) -> void:
    const ESPECIES := [
        "res://models/arvore_frondosa.glb",
        "res://models/arvore_carvalho.glb",
        "res://models/arvore_pequena.glb",
    ]
    if _rng_borda == null:
        _rng_borda = RandomNumberGenerator.new()
        _rng_borda.seed = hash(_zone_data.get("id", "zona")) + 7

    # Uma em cada seis nao nasce: o vao quebra o ritmo do passo fixo.
    if _rng_borda.randf() < 0.16:
        return

    var inst := _instanciar_modelo(ESPECIES[_rng_borda.randi() % ESPECIES.size()])
    if not inst:
        return

    # Desvio para DENTRO da zona, nunca para fora: para fora abriria buraco na
    # parede de mata e o jogador veria o fim do mundo.
    var para_dentro := _rng_borda.randf_range(0.0, 5.0)
    var ao_longo := _rng_borda.randf_range(-2.2, 2.2)
    var eixo_x: bool = absf(pos.x) > absf(pos.z)
    if eixo_x:
        pos.x -= signf(pos.x) * para_dentro
        pos.z += ao_longo
    else:
        pos.z -= signf(pos.z) * para_dentro
        pos.x += ao_longo
    pos.y = calcular_altura(pos.x, pos.z)

    inst.position = pos
    inst.rotation.y = _rng_borda.randf_range(0.0, TAU)
    # Doze a dezoito metros: e esta parede de copa que impede o jogador de ver o
    # fim do mundo por cima do portal.
    var esc := _rng_borda.randf_range(12.0, 18.0) / _altura_do_modelo(inst)
    inst.scale = Vector3(esc, esc, esc)
    _adicionar_colisor_prop(inst, "arvore", esc)
    _props_node.add_child(inst)

var _rng_borda: RandomNumberGenerator = null

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
    if not (res is PackedScene):
        return null
    var no := res.instantiate() as Node3D

    # As malhas do TripoSR nao tem textura: a cor viaja POR VERTICE. Sem um
    # material que leia essa cor como albedo, elas chegam BRANCAS — era o que
    # parecia "pedra branca" no mapa, e sao os arbustos e as arvores.
    # SEMPRE sobrepoe, sem perguntar se ja ha material.
    #
    # A primeira versao so aplicava quando a malha vinha sem material — e nao
    # veio nenhuma. O gerador de 3D grava um material dentro do proprio GLB, mas
    # e um StandardMaterial3D branco: o formato glTF nao tem como dizer "use a
    # cor do vertice como albedo", e essa e justamente a chave que faz a malha
    # do TripoSR aparecer colorida. Por isso tudo continuava branco.
    for malha in no.find_children("*", "MeshInstance3D", true, false):
        malha.material_override = _material_de_prop()
    return no

static var _mat_prop: Material = null
static func _material_de_prop() -> Material:
    if _mat_prop == null:
        _mat_prop = load("res://Material_TripoSR.tres")
    return _mat_prop

func _adicionar_colisor_prop(node: Node3D, tag: String, escala: float) -> void:
    # A caixa de colisao sai da MALHA, nao de um numero escrito a mao.
    #
    # Antes o raio era constante por familia — 0,8 m para tudo que nao fosse
    # arvore — multiplicado pela escala sorteada. Um arbusto pequeno ganhava um
    # cilindro de metro e meio invisivel em volta, e o jogador esbarrava longe do
    # que via. Medindo a malha, o colisor tem o tamanho do que esta na tela.
    var caixa := AABB()
    var achou := false
    for malha in node.find_children("*", "MeshInstance3D", true, false):
        var c: AABB = malha.get_aabb()
        caixa = c if not achou else caixa.merge(c)
        achou = true
    if not achou:
        return

    var largura: float = maxf(caixa.size.x, caixa.size.z) * escala
    var altura: float = caixa.size.y * escala
    if altura < 0.05:
        return

    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()

    if tag.begins_with("casa") or tag.begins_with("mansao") or tag.begins_with("sobrado"):
        var box := BoxShape3D.new()
        box.size = Vector3(caixa.size.x * escala, altura, caixa.size.z * escala)
        col.shape = box
    else:
        var cil := CylinderShape3D.new()
        # Tronco e mais estreito que a copa: para arvore vale um quinto da
        # largura, senao o jogador esbarra na sombra da folhagem.
        cil.radius = maxf(0.15, largura * (0.20 if tag.begins_with("arvore") else 0.42))
        cil.height = altura
        col.shape = cil

    col.position.y = altura * 0.5
    body.add_child(col)
    node.add_child(body)
