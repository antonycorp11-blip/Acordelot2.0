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

# Banco de modelos, escolhidos tambem pelo CUSTO e nao so pela aparencia.
#
# Cada malha separada dentro de um modelo e uma chamada de desenho por copia
# plantada. O bordo japones tinha 2700 malhas e o carvalho 198: uma unica arvore
# dessas custava mais chamadas que a cena inteira deveria custar, e a medicao
# mostrou 2213 chamadas com 2,7 milhoes de primitivas — dois quadros e meio por
# segundo. O platano trazia 143 mil triangulos por copia.
#
# Ficaram os tres que sao baratos E bonitos: seis, duas e duas malhas.
const ARVORES_FLORESTA_3D := [
    {"path": "res://models/tree_gn.glb", "tag": "arvore_gigante", "altura": 10.5, "enterrar": 0.65},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 9.0, "enterrar": 0.50},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 9.5, "enterrar": 0.50},
    {"path": "res://models/mushroom_tree.glb", "tag": "cogumelo", "altura": 2.2, "enterrar": 0.20}
]

const ARVORES_MISTICAS_3D := [
    {"path": "res://models/tree_gn.glb", "tag": "arvore_gigante", "altura": 10.5, "enterrar": 0.65},
    {"path": "res://models/crystal_cluster_1787078933118.glb", "tag": "cristal_arcano", "altura": 3.6, "enterrar": 0.25},
    {"path": "res://models/mushroom_tree.glb", "tag": "cogumelo", "altura": 2.2, "enterrar": 0.20}
]

const ARBUSTOS_3D := [
    {"path": "res://models/fantasy_bush_1787078968444.glb", "tag": "arbusto_3d", "altura": 2.2, "enterrar": 0.3}
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
## Altura de cada tipo de peca em METROS.
##
## Os modelos vem normalizados, cada um numa escala propria — o poco chega do
## mesmo tamanho da torre. Quem da sentido a eles e esta tabela: o construtor
## mede a caixa do modelo e o estica ate a altura de verdade. Sem ela a cidade
## sai com casas de trinta metros ao lado de moinhos de dois.
const ALTURA_POR_TAG := {
    "casa": 7.5, "casa_enxaimel_1": 8.0, "casa_enxaimel_2": 7.5,
    "mansao_medieval": 9.5, "sobrado": 9.0,
    "celeiro": 8.0, "moinho": 12.0, "oficina_ferreiro": 7.0, "loja_toldo": 5.0,
    "torre": 13.0, "muralha": 6.5, "muro": 4.0,
    "fonte": 3.0, "poco": 2.4, "lampiao": 4.2,
    "banca": 2.6, "mobilia": 1.6, "estatua": 2.8, "estandarte": 5.0,
    "ponte": 2.0, "cristal": 4.5,
    "arvore_de_rua": 7.0, "folhagem": 0.75,
}
const ALTURA_PADRAO := 7.0


func _construir_layout_urbano() -> void:
    var layout_id: String = str(_zone_data.get("layout_id", ""))
    if layout_id == "":
        return

    # As plantas moram DENTRO de "layouts", nao na raiz do arquivo.
    #
    # Aqui se procurava o id na raiz do JSON, onde so existem "_nota", "pracas"
    # e "layouts". A busca nunca achava nada e a funcao voltava na primeira
    # linha: por isso toda cidade e toda vila estavam vazias, com o plano
    # inteiro gravado no disco e ninguem lendo.
    var todas: Dictionary = _city_layouts.get("layouts", {})
    if not todas.has(layout_id):
        return
    var pecas: Array = todas[layout_id]

    for p in pecas:
        var tag: String = str(p.get("tag", ""))

        # O MODELO VEM DA PLANTA, nao de um sorteio aqui dentro.
        #
        # Antes esta funcao ignorava p["model"] e devolvia sempre uma das duas
        # casas de enxaimel. As vinte e tres construcoes distintas que o
        # planejador escolhe — moinho, celeiro, forja, torre, banca, estatua —
        # chegavam todas como a mesma casa. Era planejamento urbano jogado fora
        # na ultima linha.
        var modelo_path: String = str(p.get("model", ""))
        if modelo_path == "" or not ResourceLoader.exists(modelo_path):
            continue

        var altura_alvo: float = float(ALTURA_POR_TAG.get(tag, ALTURA_PADRAO))
        var escala_layout: float = float(p.get("scale", 1.0))

        var suporte := _instanciar_prop_3d(modelo_path, tag, altura_alvo, escala_layout)
        if not suporte:
            continue

        # A planta grava a posicao como [x, z] num par, e o giro em "rotation".
        var pos: Array = p.get("position", [0.0, 0.0])
        var px: float = float(pos[0]) if pos.size() > 0 else 0.0
        var pz: float = float(pos[1]) if pos.size() > 1 else 0.0
        var py: float = calcular_altura(px, pz) + float(p.get("y", 0.0)) - 0.25

        suporte.position = Vector3(px, py, pz)
        suporte.rotation.y = deg_to_rad(float(p.get("rotation", 0.0)))
        _limitar_alcance(suporte)

        # Grama e mato nao ganham colisor: sao dezenas por cidade, e parar o
        # jogador num tufo de capim e o tipo de tropeco que ninguem entende.
        if tag != "folhagem":
            _adicionar_colisor_prop(suporte, tag, 1.0)
        _props_node.add_child(suporte)

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
    
    # Espacamento maior no cinturao.
    #
    # A 8,5 m eram 134 arvores so na moldura, e cada uma custa 22 mil triangulos:
    # a borda sozinha pesava mais que tudo dentro da zona. A 15 m sao menos da
    # metade, e como cada arvore agora e maior e o giro e sorteado, a parede de
    # copa continua fechada — o jogador nao ve o fim do mundo por causa disso.
    var num_passos: int = int(TAMANHO_ZONA / 15.0)
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

## As arvores BARATAS ficam no cinturao.
##
## A moldura tem dezenas de copias e o miolo tem poucas, entao o custo mora na
## borda: por copia, o pinheiro tem 2,1 mil triangulos e a outra tem 22,5 mil —
## dez vezes mais, para uma silhueta que o jogador ve de longe e contra a luz.
## O detalhe caro fica onde ele e olhado de perto.
const ARVORES_DE_BORDA := [
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 9.5, "enterrar": 0.50},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 10.5, "enterrar": 0.55},
]

func _criar_arvore_borda_3d(pos: Vector3, idx_seed: int) -> void:
    var item: Dictionary = ARVORES_DE_BORDA[idx_seed % ARVORES_DE_BORDA.size()]
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
## A cor dos props mora no VERTICE, nao em textura: 37 dos 46 modelos do jogo
## nao trazem imagem nenhuma dentro do arquivo.
##
## Ate aqui isso era lido por um shader proprio (ALBEDO = COLOR.rgb), que
## funciona no editor e deixava o mapa inteiro BRANCO no navegador do celular.
## Este material faz a mesma leitura pelo caminho da propria engine —
## vertex_color_use_as_albedo — que e o unico testado nos tres renderizadores.
##
## A prova esta na espada: ela ja usava esse caminho e nunca ficou branca,
## enquanto tudo que passava pelo shader ficava.
static var _material_de_cor: Material = preload("res://materials/prop_cor_de_vertice.tres")

const VENTO_LIGADO := true

static var _material_com_vento: ShaderMaterial = null

static func _obter_material_vento() -> ShaderMaterial:
    if _material_com_vento == null:
        _material_com_vento = ShaderMaterial.new()
        _material_com_vento.shader = load("res://materials/prop_vento.gdshader")
    return _material_com_vento

func _instanciar_prop_3d(path: String, tag: String, altura_alvo: float, escala_mult: float = 1.0) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    var res := load(path)
    if not (res is PackedScene):
        return null
        
    var modelo: Node3D = (res as PackedScene).instantiate()
    if not modelo:
        return null
        
    _corrigir_materiais_prop(modelo, tag)
        
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

func _corrigir_materiais_prop(modelo: Node3D, tag: String) -> void:
    var tem_vento: bool = tag.begins_with("arbusto") or tag.begins_with("folhagem") or tag.begins_with("grama")
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var m_inst := malha as MeshInstance3D
        if not m_inst or not m_inst.mesh:
            continue
        var precisa_override := false
        for s in range(m_inst.mesh.get_surface_count()):
            var mat: Material = m_inst.get_active_material(s)
            var fmt: int = m_inst.mesh.surface_get_format(s)
            var has_vc: bool = (fmt & Mesh.ARRAY_FORMAT_COLOR) != 0
            var has_tex: bool = false
            if mat is StandardMaterial3D:
                var sm := mat as StandardMaterial3D
                has_tex = (sm.albedo_texture != null)
            if has_vc and not has_tex:
                precisa_override = true
                break
        if precisa_override:
            if tem_vento and VENTO_LIGADO:
                m_inst.material_override = _obter_material_vento()
            else:
                m_inst.material_override = _material_de_cor

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

## Diz a cada malha ate onde vale a pena desenha-la.
##
## A zona tem 160 m e a camera enxerga uns 40: sem isto o outro lado do mapa e
## desenhado a cada quadro sem ninguem ver. O alcance sai do TAMANHO da peca —
## arvore de quinze metros aparece de longe, tufo de meio metro nao faz falta a
## quarenta — porque um numero fixo ou apaga a arvore cedo demais ou carrega o
## capim longe demais.
##
## Isto ja existia e foi perdido numa alteracao posterior. Com a cidade cheia
## passando a ter 187 pecas, e o que segura o quadro no celular fraco.
static func _limitar_alcance(no: Node3D) -> void:
    var caixa := AABB()
    var achou := false
    for malha in no.find_children("*", "MeshInstance3D", true, false):
        var m := malha as MeshInstance3D
        var local: AABB = m.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou:
        return
    var altura: float = caixa.size.y * no.scale.y
    var alcance: float = clampf(altura * 6.0, 28.0, 95.0)
    for malha in no.find_children("*", "MeshInstance3D", true, false):
        malha.visibility_range_end = alcance
        malha.visibility_range_end_margin = alcance * 0.14
        malha.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _adicionar_colisor_prop(node: Node3D, tag: String, escala: float) -> void:
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    
    if tag.begins_with("arvore") or tag.begins_with("carvalho") or tag.begins_with("pinheiro") or tag.begins_with("cogumelo_arvore"):
        var shape := CylinderShape3D.new()
        shape.radius = 0.9 * clampf(escala, 0.8, 1.8)
        shape.height = 5.0 * clampf(escala, 0.8, 2.0)
        col.shape = shape
        col.position.y = shape.height * 0.5
    elif tag.begins_with("casa") or tag.begins_with("mansao") or tag.begins_with("sobrado") \
            or tag in ["celeiro", "moinho", "oficina_ferreiro", "loja_toldo", "torre", "muralha"]:
        # A caixa vem do modelo JA POSICIONADO, nao de um 6,5 x 6 x 6,5 fixo.
        #
        # O palpite fixo servia quando toda casa era a mesma casa. Agora que a
        # planta escolhe entre moinho, celeiro, torre e cinco casas de tamanhos
        # diferentes, um numero unico ou deixa parede invisivel sobrando ou
        # deixa o jogador entrar dentro do moinho.
        var medida := _caixa_do_modelo(node)
        var box := BoxShape3D.new()
        box.size = Vector3(
            maxf(medida.size.x, 0.8), maxf(medida.size.y, 1.0), maxf(medida.size.z, 0.8))
        col.shape = box
        col.position = medida.position + medida.size * 0.5
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

