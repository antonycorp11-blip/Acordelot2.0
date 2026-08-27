extends Node3D
class_name ZoneBuilder

const PortalScript = preload("res://scripts/zone_portal.gd")
const BichoScript = preload("res://scripts/bicho.gd")
const RecursoColetavelScript = preload("res://scripts/recurso_coletavel.gd")
const EcoDoNascenteCena = preload("res://scenes/ecos/EcoDoNascente.tscn")
const ECOS_NOVOS := [
    {"id": "ambar", "nota": "do_sustenido", "frames": preload("res://resources/eco_ambar_frames.tres")},
    {"id": "rubi", "nota": "re", "frames": preload("res://resources/eco_rubi_frames.tres")},
    {"id": "cervo_dourado", "nota": "re_sustenido", "frames": preload("res://resources/eco_cervo_dourado_frames.tres")},
    {"id": "folha", "nota": "mi", "frames": preload("res://resources/eco_folha_frames.tres")},
    {"id": "agua", "nota": "fa", "frames": preload("res://resources/eco_agua_frames.tres")},
    {"id": "clave_azul", "nota": "fa_sustenido", "frames": preload("res://resources/eco_clave_azul_frames.tres")},
    {"id": "safira", "nota": "sol", "frames": preload("res://resources/eco_safira_frames.tres")},
    {"id": "ametista", "nota": "sol_sustenido", "frames": preload("res://resources/eco_ametista_frames.tres")},
    {"id": "draconico", "nota": "la", "frames": preload("res://resources/eco_draconico_frames.tres")},
    {"id": "celeste", "nota": "la_sustenido", "frames": preload("res://resources/eco_celeste_frames.tres")},
]

signal portal_triggered(dest_zone_id: String, from_direction: String)

const BIOMAS_SEM_NINHO := ["cidade", "sagrado"]
const TAMANHO_ZONA: float = 160.0 # 160m x 160m cluster
const SUBDIVISOES: int = 64        # Resolução de malha suave

var _zone_data: Dictionary = {}

## MUNDO ABERTO — sem portais, sem tela de carregamento.
##
## O no da cena vira COORDENADOR: nao constroi nada, so decide que regioes
## existem. Cada regiao e uma copia deste mesmo script, plantada no
## deslocamento da sua celula, construindo a zona dela em coordenadas locais
## exatamente como antes. Nenhuma das 1100 linhas de construcao precisou saber
## da mudanca.
var _e_regiao := false
var _celulas: Dictionary = {}
var _por_celula: Dictionary = {}
var _regioes: Dictionary = {}
var _zonas_db: Dictionary = {}
var jogador: Node3D
## Carrega a vizinha quando a divisa esta perto, e so descarrega bem depois:
## sem essa folga, andar em cima da linha ficaria montando e desmontando zona.
const PERTO_PARA_CARREGAR := 60.0
const LONGE_PARA_SOLTAR := 110.0
var _ate_arrumar := 0.0
var _city_layouts: Dictionary = {}

var _terrain_mesh: MeshInstance3D
var _terrain_body: StaticBody3D
var _water_mesh: MeshInstance3D
var _portals_node: Node3D
var _props_node: Node3D
static var _malha_grama_leve: ArrayMesh
static var _material_grama_leve: ShaderMaterial

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
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 10.0, "enterrar": 0.52},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 10.8, "enterrar": 0.55},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 8.4, "enterrar": 0.46}
]

const SUBBOSQUE_FLORESTA_3D := [
    {"path": "res://models/mushroom_tree.glb", "tag": "cogumelo", "altura": 2.0, "enterrar": 0.18},
    {"path": "res://models/mushroom_tree.glb", "tag": "cogumelo", "altura": 2.5, "enterrar": 0.22}
]

const ARVORES_MISTICAS_3D := [
    {"path": "res://models/tree_gn.glb", "tag": "arvore_gigante", "altura": 10.5, "enterrar": 0.65},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 9.2, "enterrar": 0.50},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 9.8, "enterrar": 0.52},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 10.4, "enterrar": 0.55},
    {"path": "res://models/pine_tree.glb", "tag": "pinheiro_real", "altura": 8.6, "enterrar": 0.47}
]

## Vazio de proposito.
##
## O unico arbusto do acervo (fantasy_bush) nao tem textura, e o cristal das
## zonas misticas tambem nao. Preencher com eles e o que fazia o mapa parecer
## massinha. Fica sem arbusto ate aparecer um com textura — falta de conteudo e
## melhor que conteudo errado.
const ARBUSTOS_3D := []

func carregar_dados() -> void:
    if _city_layouts.is_empty():
        var f_lay := FileAccess.open("res://data/city_layouts.json", FileAccess.READ)
        if f_lay:
            _city_layouts = JSON.parse_string(f_lay.get_as_text())
        # Plantas revisadas ficam separadas do arquivo histórico de 9 mil
        # linhas. Elas substituem somente os bairros redesenhados e tornam a
        # remoção dos assets antigos verificável e reversível.
        var f_novo := FileAccess.open("res://data/urban_refinement.json", FileAccess.READ)
        if f_novo:
            var revisao: Dictionary = JSON.parse_string(f_novo.get_as_text())
            for secao in ["pracas", "layouts"]:
                if not _city_layouts.has(secao):
                    _city_layouts[secao] = {}
                for id in revisao.get(secao, {}):
                    _city_layouts[secao][id] = revisao[secao][id]

func construir_zona(zone_data: Dictionary) -> void:
    _zone_data = zone_data
    carregar_dados()

    # Os ninhos pertencem a zona que esta saindo. Sem limpar esta lista, os
    # Shikers removidos junto com o mapa antigo voltavam trinta segundos depois
    # dentro da nova zona — inclusive dentro de Acordelot.
    _ninhos.clear()
    _ate_conferir = RITMO_DA_CONFERENCIA
    
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

    # Rios e estradas pertencem ao plano da região, portanto nascem antes dos
    # edifícios. O leito já foi cavado pela mesma função de altura do terreno.
    _construir_rios()
    _construir_meio_fio()
    
    if _zone_data.get("water", false):
        _construir_agua()
        
    _construir_layout_urbano()
    _acender_a_povoacao()
    _plantar_os_npcs()
    _espalhar_os_adornos()
    _construir_floresta_3d_real()
    _plantar_vegetacao_baixa()
    _plantar_arbustos_texturizados()
    _plantar_grama_texturizada_nova()
    _construir_detalhes_floresta_inicial()
    _construir_barreiras_perimetro_arvores_reais()
    # Vila, cidade e santuario nao criam ninho. O jogador reclamou de Shiker
    # dentro da vila: parte vinha do gerador que segue o heroi, parte nascia
    # aqui mesmo, plantada junto com as casas.
    if not BIOMAS_SEM_NINHO.has(String(_zone_data.get("biome", ""))):
        _construir_monstros()
    _construir_recursos_coletaveis()
    _plantar_ecos_musicais()
    if not _e_regiao:
        _construir_portais()


## Poucos pontos reutilizaveis em zonas naturais. Cidades ficam sem madeira,
## pedra ou fragmento brotando nas ruas; seus recursos virao de comercio/NPC.
func _construir_recursos_coletaveis() -> void:
    var urbana: bool = (_zone_data.get("biome") == "cidade" or str(_zone_data.get("layout_id", "")) != "")
    if urbana:
        return
    var receita := [
        ["madeira", Vector2(-22, 16), 2], ["madeira", Vector2(26, -18), 2],
        ["pedra", Vector2(20, 24), 2], ["pedra", Vector2(-28, -20), 2],
    ]
    var recursos := Node3D.new()
    recursos.name = "RecursosColetaveis"
    add_child(recursos)
    for dados in receita:
        var recurso: Node3D = RecursoColetavelScript.new()
        recurso.recurso_id = str(dados[0])
        recurso.quantidade = int(dados[2])
        var ponto: Vector2 = dados[1]
        recurso.position = Vector3(ponto.x, calcular_altura(ponto.x, ponto.y) + 0.05, ponto.y)
        recursos.add_child(recurso)


## Ecos 2.5D pacificos. Nesta primeira build a Floresta do Despertar funciona
## como vitrine: um exemplar de cada arte disponivel, sem duplicatas.
func _plantar_ecos_musicais() -> void:
    var zona := str(_zone_data.get("id", ""))
    if zona not in ["zone_floresta_despertar", "zone_floresta_sombria"]:
        return
    var pontos := [
        Vector2(4.5, 4.0), Vector2(-8.0, 8.0), Vector2(11.0, 10.0),
        Vector2(-15.0, 15.0), Vector2(18.0, 17.0), Vector2(-21.0, 4.0),
        Vector2(23.0, 3.0), Vector2(-18.0, -10.0), Vector2(18.0, -12.0),
        Vector2(-9.0, -20.0), Vector2(8.0, -22.0),
    ]
    var inicio := 0 if zona == "zone_floresta_despertar" else 5
    var fim := ECOS_NOVOS.size() if zona == "zone_floresta_despertar" else 10

    # O Eco de Do ja aprovado permanece perto do inicio.
    if zona == "zone_floresta_despertar":
        _instanciar_eco("do", null, pontos[0], 0.72)
    for indice in range(inicio, fim):
        var dados: Dictionary = ECOS_NOVOS[indice]
        var ponto: Vector2 = pontos[indice - inicio + 1] if zona == "zone_floresta_despertar" else pontos[indice - inicio]
        _instanciar_eco(str(dados["nota"]), dados["frames"], ponto, 0.68 + float(indice % 3) * 0.04)


func _instanciar_eco(id: String, frames: SpriteFrames, ponto: Vector2, altura: float) -> void:
    var eco := EcoDoNascenteCena.instantiate()
    eco.name = "Eco_" + id
    eco.passeio_natural = true
    eco.eco_id = id
    eco.capturavel = true
    eco.add_to_group("eco_capturavel")
    eco.raio_do_passeio = 3.25
    eco.altura_aparente_m = altura
    eco.definir_terreno(self)
    if frames != null:
        var sprite := eco.get_node("Visual/AnimatedSprite3D") as AnimatedSprite3D
        sprite.sprite_frames = frames
        sprite.visibility_range_end = 30.0
        eco.usar_particulas = false
    eco.position = Vector3(ponto.x, calcular_altura(ponto.x, ponto.y) + 0.03, ponto.y)
    _props_node.add_child(eco)

# -------------------------------------------------------------
# 1. Terreno com Altura e Shader Zoned
# -------------------------------------------------------------
## Altura no MUNDO. Numa regiao, x e z ja sao locais e a conta e direta; no
## coordenador, o ponto e trazido para dentro da celula antes de medir — assim
## quem pergunta (bicho nascendo, NPC assentando, eco pousando) nao precisa
## saber que o mundo virou grade.
func calcular_altura(x: float, z: float) -> float:
    if _e_regiao or _celulas.is_empty():
        return _altura_local(x, z, _zone_data)
    var celula := celula_do_ponto(x, z)
    var zid := String(_por_celula.get(_chave(celula), ""))
    if zid == "":
        return 0.0
    var dados: Dictionary = _zonas_db.get("zones", {}).get(zid, {})
    return _altura_local(x - float(celula.x) * TAMANHO_ZONA, z - float(celula.y) * TAMANHO_ZONA, dados)


## As bordas de toda zona sao rebaixadas ate zero.
##
## Cada zona desenha o relevo em volta do proprio centro, entao duas vizinhas
## chegavam na divisa com alturas diferentes e o encontro virava degrau — no
## mundo por portais isso nunca aparecia, porque nunca existiam duas ao mesmo
## tempo. Zerando os ultimos metros, qualquer par de zonas se encontra no mesmo
## nivel e o jogador atravessa sem ver a emenda.
const MARGEM_DE_COSTURA := 22.0

func _altura_local(x: float, z: float, dados: Dictionary) -> float:
    var bruto := _relevo_da_zona(x, z, dados)
    var meia := TAMANHO_ZONA * 0.5
    var beira: float = maxf(absf(x), absf(z))
    if beira > meia - MARGEM_DE_COSTURA:
        var t: float = clampf((meia - beira) / MARGEM_DE_COSTURA, 0.0, 1.0)
        bruto *= t * t * (3.0 - 2.0 * t)
    return bruto - _profundidade_do_rio(Vector2(x, z), dados)


## Distância de um ponto ao segmento, usada tanto pelo leito quanto pela água.
static func _distancia_ao_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
    var ab := b - a
    var tamanho2 := ab.length_squared()
    if tamanho2 < 0.0001:
        return p.distance_to(a)
    var t := clampf((p - a).dot(ab) / tamanho2, 0.0, 1.0)
    return p.distance_to(a + ab * t)


func _profundidade_do_rio(p: Vector2, dados: Dictionary) -> float:
    var caminhos: Array = dados.get("river_paths", [])
    if caminhos.is_empty():
        return 0.0
    var largura: float = float(dados.get("river_width", 5.0))
    var margem := 4.0
    var menor := 99999.0
    for caminho in caminhos:
        for i in range(caminho.size() - 1):
            var a := Vector2(float(caminho[i][0]), float(caminho[i][1]))
            var b := Vector2(float(caminho[i + 1][0]), float(caminho[i + 1][1]))
            menor = minf(menor, _distancia_ao_segmento(p, a, b))
    if menor >= largura + margem:
        return 0.0
    var peso := 1.0 - smoothstep(largura, largura + margem, menor)
    return float(dados.get("river_depth", 1.8)) * peso


func _relevo_da_zona(x: float, z: float, dados: Dictionary) -> float:
    var tipo_terreno: String = str(dados.get("terrain_type", "colinas_suaves"))
    var d_centro: float = Vector2(x, z).length()
    
    match tipo_terreno:
        "plato_urbano":
            # Acordelot ocupa quase toda a zona. O plato antigo acabava em
            # 45 m e punha os bairros novos e a muralha numa ladeira. So a
            # cidade principal ganha o raio maior; a vila continua compacta.
            var acorde_lot := str(dados.get("id", "")) == "zone_portoes"
            var raio_plano := 70.0 if acorde_lot else 45.0
            # A muralha e retangular. Medir pelo raio de um circulo deixaria
            # justamente os quatro cantos fora do plato, com segmentos
            # flutuando. Na cidade mede-se ate a borda do quadrado.
            var distancia_do_plato := maxf(absf(x), absf(z)) if acorde_lot else d_centro
            if distancia_do_plato < raio_plano:
                return 0.0
            var t: float = clampf((distancia_do_plato - raio_plano) / 10.0, 0.0, 1.0)
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
    _pintar_as_vias(mat)
    
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


## Rio real, estreito e seguindo o relevo. Cada faixa tem poucos vértices e
## compartilha o shader de água; não há física nem luz dinâmica por trecho.
func _construir_rios() -> void:
    var caminhos: Array = _zone_data.get("river_paths", [])
    if caminhos.is_empty():
        return
    var largura: float = float(_zone_data.get("river_width", 5.0))
    var profundidade: float = float(_zone_data.get("river_depth", 1.8))
    var material := ShaderMaterial.new()
    material.shader = load("res://materials/agua.gdshader")
    material.set_shader_parameter("cor_profunda", Color(0.055, 0.23, 0.36, 0.97))
    material.set_shader_parameter("cor_superficie", Color(0.18, 0.58, 0.76, 0.88))

    for caminho in caminhos:
        if caminho.size() < 2:
            continue
        var amostras: Array[Vector2] = []
        for indice in range(caminho.size() - 1):
            var a := Vector2(float(caminho[indice][0]), float(caminho[indice][1]))
            var b := Vector2(float(caminho[indice + 1][0]), float(caminho[indice + 1][1]))
            var passos := maxi(1, int(ceil(a.distance_to(b) / 4.0)))
            for passo in passos:
                amostras.append(a.lerp(b, float(passo) / float(passos)))
        amostras.append(Vector2(float(caminho[-1][0]), float(caminho[-1][1])))

        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in amostras.size():
            var anterior: Vector2 = amostras[maxi(i - 1, 0)]
            var seguinte: Vector2 = amostras[mini(i + 1, amostras.size() - 1)]
            var direcao := (seguinte - anterior).normalized()
            var lateral := Vector2(-direcao.y, direcao.x) * largura
            var centro: Vector2 = amostras[i]
            for lado in [-1.0, 1.0]:
                var p: Vector2 = centro + lateral * float(lado)
                var y := calcular_altura(p.x, p.y) + profundidade * 0.62 + 0.04
                st.set_uv(Vector2(float(i) * 0.18, 0.0 if lado < 0.0 else 1.0))
                st.add_vertex(Vector3(p.x, y, p.y))
        for i in range(amostras.size() - 1):
            var base := i * 2
            st.add_index(base); st.add_index(base + 2); st.add_index(base + 1)
            st.add_index(base + 1); st.add_index(base + 2); st.add_index(base + 3)
        st.generate_normals()
        var faixa := MeshInstance3D.new()
        faixa.name = "Rio"
        faixa.mesh = st.commit()
        faixa.material_override = material
        faixa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(faixa)


## Meio-fio baixo nas vias de pedra. É geometria simples e compartilhada,
## suficiente para a rua deixar de parecer uma estampa pintada no gramado.
func _construir_meio_fio() -> void:
    if str(_zone_data.get("road_surface", "terra")) != "pedra":
        return
    var caminhos: Array = _zone_data.get("road_paths", [])
    if caminhos.is_empty():
        return
    var material := StandardMaterial3D.new()
    material.albedo_texture = load("res://textures/flagstone_seamless.png")
    material.roughness = 0.94
    material.uv1_scale = Vector3(0.45, 0.45, 0.45)
    var largura_da_rua := 5.2
    for caminho in caminhos:
        for i in range(caminho.size() - 1):
            var a := Vector2(float(caminho[i][0]), float(caminho[i][1]))
            var b := Vector2(float(caminho[i + 1][0]), float(caminho[i + 1][1]))
            var delta := b - a
            if delta.length_squared() < 0.01:
                continue
            var dir := delta.normalized()
            var normal := Vector2(-dir.y, dir.x)
            for lado in [-1.0, 1.0]:
                var centro: Vector2 = (a + b) * 0.5 + normal * largura_da_rua * float(lado)
                var bloco := MeshInstance3D.new()
                bloco.name = "MeioFio"
                var caixa := BoxMesh.new()
                caixa.size = Vector3(0.34, 0.12, delta.length() + 0.35)
                caixa.material = material
                bloco.mesh = caixa
                bloco.position = Vector3(centro.x, calcular_altura(centro.x, centro.y) + 0.04, centro.y)
                bloco.rotation.y = atan2(dir.x, dir.y)
                bloco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                add_child(bloco)

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
    "casa": 8.8, "casa_enxaimel_1": 9.4, "casa_enxaimel_2": 8.8,
    # As cinco casas da Vila do Caminho. Os numeros NAO sao livres: a planta
    # alinha fachada e mede vao entre lotes com a pegada que a casa tem DEPOIS
    # de normalizada por esta altura. Mexer aqui sem mexer em CASAS, no
    # planejar_cidades.py, poe casa dentro de casa.
    "casa_alta": 9.8, "casa_larga": 8.8,
    "casa_pedra": 8.4, "casarao": 10.0, "solar": 11.0,
    # As tres de Acordelot. A torre e a mais alta da cidade de proposito: ela
    # faz o portao e fecha a praca, e marco precisa ser visto de longe.
    "casa_taipa": 9.4, "casa_torre": 13.5, "taverna": 13.0,
    # Os props da rua. Medidos pelo que a coisa mede no mundo: um barril tem
    # um metro de altura, um caixote oitenta centimetros, um saco meio metro.
    # Prop fora de escala e o erro que mais denuncia cenario montado as pressas.
    "poste": 4.6, "tocha_parede": 1.3, "barris": 1.6, "caixotes": 0.9,
    "saco": 0.6, "banco": 1.0, "carroca": 1.8,
    "mansao_medieval": 9.5, "sobrado": 9.0,
    "celeiro": 8.0, "moinho": 12.0, "oficina_ferreiro": 7.0, "loja_toldo": 5.0,
    "torre": 13.0, "muralha": 6.5, "muro": 4.0,
    "fonte": 3.0, "poco": 2.4, "lampiao": 4.2,
    "banca": 2.6, "mobilia": 1.6, "estatua": 2.8, "estandarte": 5.0,
    "ponte": 2.0, "cristal": 4.5,
    "arvore_de_rua": 7.0, "folhagem": 0.75,
}
const ALTURA_PADRAO := 7.0


## Manda para o chao onde passam as ruas desta zona.
##
## O planejador ja calcula a via principal, o largo e as travessas; ate aqui
## esses numeros morriam no arquivo. E a diferenca entre uma vila e um punhado
## de casas num gramado: o jogador tem de VER por onde andar.
func _pintar_as_vias(mat: ShaderMaterial) -> void:
    _pintar_caminhos_regionais(mat)
    var vias: Dictionary = _dados_da_praca().get("vias", {})
    if vias.is_empty():
        return

    var principal: Array = vias.get("principal", [0.0, 0.0])
    var travessas: Array = vias.get("travessas", [0.0, 0.0, 0.0])
    mat.set_shader_parameter("via_principal", Vector4(
        float(principal[0]), float(principal[1]),
        float(vias.get("largo", 0.0)), float(travessas[1])))
    mat.set_shader_parameter("via_travessa", Vector2(
        float(travessas[0]), float(travessas[2])))
    var secundarias: Array = vias.get("secundarias", [999.0, 999.0, 0.0, 0.0])
    mat.set_shader_parameter("vias_secundarias", Vector4(
        float(secundarias[0]), float(secundarias[1]),
        float(secundarias[2]), float(secundarias[3])))
    mat.set_shader_parameter("via_de_pedra", 1.0 if bool(vias.get("pedra", false)) else 0.0)


func _pintar_caminhos_regionais(mat: ShaderMaterial) -> void:
    var caminhos: Array = _zone_data.get("road_paths", [])
    var segmentos: Array[Vector4] = []
    for caminho in caminhos:
        for i in range(caminho.size() - 1):
            segmentos.append(Vector4(float(caminho[i][0]), float(caminho[i][1]),
                float(caminho[i + 1][0]), float(caminho[i + 1][1])))
            if segmentos.size() >= 6:
                break
        if segmentos.size() >= 6:
            break
    mat.set_shader_parameter("quantidade_caminhos", segmentos.size())
    mat.set_shader_parameter("caminho_de_pedra", 1.0 if str(_zone_data.get("road_surface", "terra")) == "pedra" else 0.0)
    for i in 6:
        mat.set_shader_parameter("caminho_%d" % i,
            segmentos[i] if i < segmentos.size() else Vector4(999.0, 999.0, 999.0, 999.0))


## Os nove modelos do acervo que tem UV e imagem de verdade.
##
## Tudo o mais e cor por vertice — uma cor media por regiao, sem sujeira, sem
## madeira, sem telha. E literalmente o que massinha e, e nenhuma quantidade de
## planejamento urbano conserta.
##
## A regra vale POR PLANTA, nao para o mapa inteiro: so entra em vigor onde o
## planejador marcou "so_com_textura". A Vila do Caminho foi redesenhada sob
## ela; as outras seis zonas ainda dependem do acervo antigo, e ligar o corte
## nelas apagaria de 156 pecas da Capital a totalidade das Notas Sagradas —
## cidades vazias de novo. Cada uma sai da massinha quando for redesenhada.
const COM_TEXTURA := [
    "medieval_house_1", "medieval_house_3",
    "casa_pedra", "casarao_madeira", "casa_solar",
    "casa_taipa", "casa_torre", "taverna",
    "muralha_texturizada",
    "poste_vila", "tocha_vila", "poco_vila", "barris_vila",
    "caixotes_vila", "carroca_vila", "saco_vila", "banco_vila",
    "tree_gn", "pine_tree", "mushroom_tree",
    "black_dragon", "monster", "monster_orc", "swamp_monster",
]


static func _tem_textura(caminho: String) -> bool:
    return caminho.get_file().get_basename() in COM_TEXTURA


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
        # Construção ou prop urbano sem textura nunca entra. As plantas novas
        # já só usam o acervo aprovado; a segunda guarda impede regressões se
        # um layout antigo for ligado por engano.
        if not _tem_textura(modelo_path):
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
        # _instanciar_prop_3d ja desloca a base real da malha para y=0. Um
        # segundo desconto enterrava bancos, caixas e outros props baixos.
        var py: float = calcular_altura(px, pz) + float(p.get("y", 0.0))

        suporte.position = Vector3(px, py, pz)
        suporte.rotation.y = deg_to_rad(float(p.get("rotation", 0.0)))
        _limitar_alcance(suporte)

        # Grama e mato nao ganham colisor: sao dezenas por cidade, e parar o
        # jogador num tufo de capim e o tipo de tropeco que ninguem entende.
        if tag != "folhagem":
            _adicionar_colisor_prop(suporte, tag, 1.0)
        _props_node.add_child(suporte)

# -------------------------------------------------------------
# 3b. A noite da povoacao e o que enfeita a rua
# -------------------------------------------------------------
## Acende as tochas da povoacao.
##
## Reusa a lampada e a mancha de chao do ChunkBuilder de proposito: sao os
## mesmos dois nos que o ciclo do dia ja liga e desliga pelos grupos "lampada"
## e "claro_de_poste". Uma luz propria daqui ficaria acesa ao meio-dia e apagada
## a meia-noite, porque ninguem a estaria escutando.
##
## A mancha no chao NAO e decoracao: no renderizador de compatibilidade — o
## unico que o navegador aceita — a OmniLight3D nao chega ao chao. Quem desenha
## a poca de luz que o jogador ve da camera de cima e ela.
func _acender_a_povoacao() -> void:
    var luzes: Array = _dados_da_praca().get("luzes", [])
    if luzes.is_empty():
        return
    for ponto in luzes:
        var px: float = float(ponto[0])
        var pz: float = float(ponto[1])
        var poste := _poste_de_luz()
        if poste == null:
            break
        poste.position = Vector3(px, calcular_altura(px, pz) - 0.05, pz)
        # O bracco da luminaria aponta para a rua, nao para a casa.
        poste.rotation.y = deg_to_rad(90.0 if px < 0.0 else 270.0)
        _props_node.add_child(poste)

    # As tochas de parede, que iluminam a PORTA e nao a via.
    for t in _dados_da_praca().get("tochas", []):
        if t.size() < 4:
            continue
        var tx: float = float(t[0])
        var tz: float = float(t[1])
        var tocha := _tocha_de_parede(float(t[3]))
        if tocha == null:
            break
        tocha.position = Vector3(tx, calcular_altura(tx, tz) - 0.05, tz)
        tocha.rotation.y = deg_to_rad(float(t[2]))
        _props_node.add_child(tocha)


## O poste da rua: o modelo, a lampada no alto e a poca de luz no chao.
const POSTE_ALTURA := 4.6

func _poste_de_luz() -> Node3D:
    var suporte := _instanciar_prop_3d("res://models/poste_vila.glb", "poste", POSTE_ALTURA)
    if suporte == null:
        return null

    var lampada := ChunkBuilder._lampada()
    # Na luminaria, no alto do poste — nao a 86 cm, que era a altura do poste
    # velho, tres vezes menor que este.
    lampada.position = Vector3(0.0, POSTE_ALTURA * 0.92, 0.0)
    lampada.omni_range = 12.0
    suporte.add_child(lampada)

    # A poca de luz um terco maior que a do poste de rua padrao. E ela que
    # decide se a rua da para andar: no tamanho original sobrava escuro demais
    # entre um poste e outro e o jogador perdia a via. Assim as pocas se
    # encostam pelas beiradas, e o que esta ATRAS das casas continua escuro —
    # que e onde a noite tem de continuar existindo.
    var claro := ChunkBuilder._claro_no_chao()
    claro.scale = Vector3(1.4, 1.0, 1.4)
    suporte.add_child(claro)
    suporte.add_child(_halo(2.6, Vector3(0.0, POSTE_ALTURA * 0.92, 0.0)))
    return suporte


## A tocha presa na fachada, com a luz curta que so lambe a parede.
##
## Alcance seis metros e meio contra doze do poste: se a tocha iluminasse tanto
## quanto ele, as duas somariam na calcada e a rua viraria dia. O trabalho dela
## e outro — dizer que ali tem porta.
func _tocha_de_parede(altura_na_parede: float) -> Node3D:
    var suporte := _instanciar_prop_3d("res://models/tocha_vila.glb", "tocha_parede", 1.3)
    if suporte == null:
        return null
    # Sobe pela fachada: no chao ela viraria fogueira, e fogueira encostada na
    # parede de madeira e outra historia.
    for filho in suporte.get_children():
        (filho as Node3D).position.y += altura_na_parede

    var lampada := ChunkBuilder._lampada()
    lampada.position = Vector3(0.0, altura_na_parede + 0.9, 0.0)
    lampada.omni_range = 6.5
    suporte.add_child(lampada)

    var claro := ChunkBuilder._claro_no_chao()
    # Poca pequena, aos pes da porta.
    claro.scale = Vector3(0.7, 1.0, 0.7)
    suporte.add_child(claro)
    suporte.add_child(_halo(1.5, Vector3(0.0, altura_na_parede + 0.85, 0.0)))
    return suporte


## O brilho no alto da luminaria.
##
## Existe pela mesma razao que a mancha no chao: no renderizador de
## compatibilidade — o unico que o navegador aceita — a OmniLight3D nao pinta
## nada em volta. Ela acende o proprio modelo de perto e para por ai. Sem este
## halo, a noite da vila era um poste escuro com uma poca de luz no chao e nada
## ligando os dois: a luz nao tinha fonte, e o jogador via a mancha sem ver a
## lampada.
##
## Aditivo e sem escrever profundidade, como a mancha do chao — e luz somada ao
## que ja esta na tela, nao um disco amarelo colado por cima. Entra no grupo
## "claro_de_poste" para o ciclo do dia apagar junto com o resto.
func _halo(tamanho: float, onde: Vector3) -> MeshInstance3D:
    var quadro := QuadMesh.new()
    quadro.size = Vector2(tamanho, tamanho)

    var material := StandardMaterial3D.new()
    material.albedo_texture = load("res://textures/brilho_poste.png")
    # Mais fraco que a mancha do chao: aqui sao duas ou tres copias na mesma
    # tela, e no brilho cheio o halo vira uma bola branca chapada.
    material.albedo_color = Color(0.62, 0.44, 0.20)
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    quadro.material = material

    var no := MeshInstance3D.new()
    no.name = "Halo"
    no.mesh = quadro
    no.position = onde
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    no.visible = ChunkBuilder.luzes_acesas
    no.add_to_group("claro_de_poste")
    return no


## Poe de pe quem mora na zona.
##
## A planta diz onde e quem; o resto e do proprio npc.gd. Aqui nao entra nada
## sobre Mirella em particular — no dia em que houver um ferreiro, ele e mais
## uma linha na lista de npcs da praca.
const NpcScript = preload("res://scripts/npc.gd")

func _plantar_os_npcs() -> void:
    for dados in _dados_da_praca().get("npcs", []):
        if dados.size() < 5:
            continue
        var npc := NpcScript.new()
        npc.name = "Npc_" + str(dados[0])
        npc.elenco = String(dados[0])
        npc.nome = String(dados[0]).capitalize()
        npc.dialogo = str(dados[4])
        # Sexto campo, opcional: NPC de missao nao passeia.
        npc.fixa = bool(dados[5]) if dados.size() > 5 else false
        var px: float = float(dados[1])
        var pz: float = float(dados[2])
        # Sem enterrar: o proprio npc.gd ja assenta a sola na origem dele, e o
        # desconto de dez centimetros que os props usam para nao flutuar punha
        # a Mirella com o pe dentro do chao.
        npc.position = Vector3(px, calcular_altura(px, pz), pz)
        npc.rotation.y = deg_to_rad(float(dados[3]))
        _props_node.add_child(npc)


## Espalha as estampas recortadas que a planta pediu: cerca, placa, flor, pedra.
##
## Uma malha multipla POR ESTAMPA, nao um no por adorno. Sao cinquenta e quatro
## cartoes, e cinquenta e quatro nos separados seriam cinquenta e quatro chamadas
## de desenho — num mapa que custou trabalho para descer de 2213 para 125. Como
## todos os cartoes de uma mesma estampa dividem o mesmo material, o motor
## desenha cada grupo de uma vez so: doze chamadas no lugar de cinquenta e
## quatro. O giro de cada um vai na transformacao da copia.
##
## Sem colisor, todas. Sao cartoes de dois triangulos na beira da rua e no vao
## entre casas; parar o jogador num tufo de flor e o tipo de tropeco invisivel
## que ninguem entende de onde veio.
func _espalhar_os_adornos() -> void:
    var adornos: Array = _dados_da_praca().get("adornos", [])
    if adornos.is_empty():
        return

    # Junta por estampa: a chave carrega o "fixo" junto porque cerca e flor
    # querem materiais diferentes — uma para de frente para a rua, a outra gira
    # com a camera.
    var grupos: Dictionary = {}
    for a in adornos:
        if a.size() < 6:
            continue
        var caminho: String = "res://textures/" + str(a[0]) + ".png"
        # As cercas antigas sao cartoes planos e nao combinam com as casas 3D.
        # Retira todas sem tocar nos demais adornos planejados.
        if caminho.to_lower().contains("cerca"):
            continue
        if not ResourceLoader.exists(caminho):
            continue
        var chave: String = caminho + ("|fixo" if bool(a[5]) else "|gira")
        if not grupos.has(chave):
            grupos[chave] = []
        grupos[chave].append(a)

    for chave in grupos:
        var partes: PackedStringArray = String(chave).split("|")
        var textura := load(partes[0]) as Texture2D
        if textura == null:
            continue
        var fixo: bool = partes[1] == "fixo"
        var lista: Array = grupos[chave]

        # A altura da primeira copia manda no tamanho do cartao; as outras
        # entram por escala na propria copia. Guardar uma malha por altura
        # devolveria as chamadas de desenho que a malha multipla economizou.
        var base_altura: float = float(lista[0][3])
        var proporcao: float = float(textura.get_width()) / maxf(float(textura.get_height()), 1.0)

        var quadro := QuadMesh.new()
        quadro.size = Vector2(base_altura * proporcao, base_altura)
        quadro.center_offset = Vector3(0.0, base_altura * 0.5, 0.0)
        quadro.material = _estampa_parada(textura) if fixo else ChunkBuilder._material_de_planta(textura)

        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = quadro
        multi.instance_count = lista.size()
        for i in lista.size():
            var a: Array = lista[i]
            var px: float = float(a[1])
            var pz: float = float(a[2])
            var fator: float = float(a[3]) / maxf(base_altura, 0.001)
            var base := Basis(Vector3.UP, deg_to_rad(float(a[4]))).scaled(Vector3.ONE * fator)
            multi.set_instance_transform(i, Transform3D(
                base, Vector3(px, calcular_altura(px, pz) - 0.05, pz)))

        var no := MultiMeshInstance3D.new()
        no.name = "Adornos"
        no.multimesh = multi
        no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _props_node.add_child(no)


## Material de estampa que NAO gira com a camera.
##
## Cerca que mira o jogador deixa de ser cerca: o vao que ela fechava abre
## quando ele anda de lado. O que tem alinhamento na planta — cerca, placa —
## precisa ficar parado onde foi posto.
var _estampas_paradas: Dictionary = {}

func _estampa_parada(textura: Texture2D) -> StandardMaterial3D:
    if _estampas_paradas.has(textura):
        return _estampas_paradas[textura]
    var material := StandardMaterial3D.new()
    material.albedo_texture = textura
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    material.alpha_scissor_threshold = 0.5
    # Visivel dos dois lados: o jogador passa pelos dois lados da cerca.
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    _estampas_paradas[textura] = material
    return material


## Os dados da praca desta zona — vias, luzes e adornos moram todos ali.
func _dados_da_praca() -> Dictionary:
    var layout_id: String = str(_zone_data.get("layout_id", ""))
    if layout_id == "":
        return {}
    var pracas: Dictionary = _city_layouts.get("pracas", {})
    return pracas.get(layout_id, {})


# -------------------------------------------------------------
# 4. Floresta 100% 3D em Escala Real (Cidades Limpas)
# -------------------------------------------------------------
func _construir_floresta_3d_real() -> void:
    var is_cidade: bool = (_zone_data.get("biome") == "cidade" or str(_zone_data.get("layout_id", "")) != "")
    
    # Na floresta a maioria agora e pinheiro texturizado e leve. Isso permite
    # ter muito mais silhuetas sem multiplicar a arvore gigante de 22 mil
    # triangulos. Cidade recebe apenas verde planejado na planta.
    var n_arvores: int = 0 if is_cidade else int(_zone_data.get("tree_count", 64))
    var n_arbustos: int = 4 if is_cidade else int(_zone_data.get("bush_count", 22))
    
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zone"))) + 77
    
    var raio_min: float = 52.0 if is_cidade else 8.0
    if n_arvores > 0:
        # Quatro árvores grandes funcionam como marcos; a massa da floresta é
        # pinheiro agrupado. Antes 82 árvores viravam mais de 160 desenhos.
        var marcos: int = mini(4, maxi(2, int(n_arvores / 20)))
        _espalhar_props_3d(rng, marcos, [ARVORES_FLORESTA_3D[0]],
            62.0, true, 0.92, 1.12, raio_min)
        var posicoes: Array[Vector3] = []
        for i in range(n_arvores - marcos):
            var p := _sortear_ponto_de_floresta(rng, raio_min)
            posicoes.append(Vector3(p.x, calcular_altura(p.x, p.y) - 0.5, p.y))
        _plantar_pinheiros_em_lote(posicoes, hash(str(_zone_data.get("id", "zona"))))
    if not is_cidade:
        var subbosque: int = clampi(int(round(float(n_arvores) * 0.20)), 10, 18)
        _espalhar_props_3d(rng, subbosque, SUBBOSQUE_FLORESTA_3D,
            66.0, false, 0.82, 1.22, 5.0)
    _espalhar_props_3d(rng, n_arbustos, ARBUSTOS_3D, 65.0, false, 0.9, 1.3, raio_min)


## Todas as cópias de cada malha do pinheiro vão numa única chamada. Mantém a
## textura original e só cria colisores cilíndricos baratos para os troncos.
func _plantar_pinheiros_em_lote(posicoes: Array[Vector3], semente: int) -> void:
    if posicoes.is_empty():
        return
    var cena := load("res://models/pine_tree.glb") as PackedScene
    if cena == null:
        return
    var modelo := cena.instantiate() as Node3D
    var caixa := _caixa_do_modelo(modelo)
    if caixa.size.y < 0.001:
        modelo.free()
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = semente
    var giros: Array[float] = []
    var fatores: Array[float] = []
    for i in posicoes.size():
        giros.append(rng.randf_range(0.0, TAU))
        fatores.append(rng.randf_range(8.4, 10.8) / caixa.size.y)

    for candidato in modelo.find_children("*", "MeshInstance3D", true, false):
        var origem := candidato as MeshInstance3D
        if origem.mesh == null:
            continue
        var local := _ate_a_raiz(origem, modelo)
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = origem.mesh
        multi.instance_count = posicoes.size()
        for i in posicoes.size():
            var fator := fatores[i]
            var modelo_local := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * fator),
                Vector3(0.0, -caixa.position.y * fator, 0.0))
            var suporte := Transform3D(Basis(Vector3.UP, giros[i]), posicoes[i])
            multi.set_instance_transform(i, suporte * modelo_local * local)
        var lote := MultiMeshInstance3D.new()
        lote.name = "PinheirosEmLote"
        lote.multimesh = multi
        lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        lote.visibility_range_end = 96.0
        lote.visibility_range_end_margin = 8.0
        _props_node.add_child(lote)

    # Colisor sem malha: não aumenta draw calls e mantém árvores como obstáculo.
    for pos in posicoes:
        var corpo := StaticBody3D.new()
        corpo.position = pos
        var col := CollisionShape3D.new()
        var forma := CylinderShape3D.new()
        forma.radius = 0.65
        forma.height = 4.8
        col.shape = forma
        col.position.y = 2.4
        corpo.add_child(col)
        _props_node.add_child(corpo)
    modelo.free()


## Cobertura de grama 3D de verdade, mas desenhada para celular.
##
## O GLB anterior tinha 900 triângulos por tufo. Mesmo limitado a 460 cópias,
## custava 414 mil triângulos por região e ainda deixava grandes áreas lisas.
## Esta malha tem dez triângulos por tufo: podemos cobrir o terreno inteiro com
## milhares de cópias e continuar bem abaixo do custo antigo.
func _plantar_vegetacao_baixa() -> void:
    _preparar_grama_leve()
    if _malha_grama_leve == null:
        return
    var quantidade := clampi(int(_zone_data.get("grass_density", 900)) * 3, 1200, 7800)
    if str(_zone_data.get("biome", "")) == "cidade":
        quantidade = mini(quantidade, 350)
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = _malha_grama_leve
    multi.instance_count = quantidade
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zona"))) + 1907
    for i in quantidade:
        # Uniforme de propósito: clareiras também são gramadas. Árvores usam
        # maciços, mas o tapete vegetal precisa unir visualmente todo o chão.
        var p := Vector2(rng.randf_range(-76.0, 76.0), rng.randf_range(-76.0, 76.0))
        var tentativas := 0
        while (_perto_da_rede(p, "river_paths", float(_zone_data.get("river_width", 5.0)) + 2.0)
                or _perto_da_rede(p, "road_paths", 7.0)) and tentativas < 8:
            p = Vector2(rng.randf_range(-76.0, 76.0), rng.randf_range(-76.0, 76.0))
            tentativas += 1
        var escala := rng.randf_range(0.72, 1.26)
        var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * escala)
        multi.set_instance_transform(i, Transform3D(base,
            Vector3(p.x, calcular_altura(p.x, p.y) - 0.015, p.y)))
    var tufos := MultiMeshInstance3D.new()
    tufos.name = "TapeteDeGrama3D"
    tufos.multimesh = multi
    tufos.material_override = _material_grama_leve
    tufos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Um MultiMesh ocupa a zona toda; limitar pela distância do NÓ fazia todo
    # o gramado desaparecer quando o jogador se afastava do centro da região.
    tufos.visibility_range_end = 0.0
    _props_node.add_child(tufos)


static func _preparar_grama_leve() -> void:
    if _malha_grama_leve != null:
        return
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var centros := [
        Vector2(0.0, 0.0), Vector2(0.23, 0.18), Vector2(-0.25, 0.14),
        Vector2(0.18, -0.24), Vector2(-0.18, -0.22)]
    for i in centros.size():
        var angulo := float(i) * 1.256637
        var lateral := Vector3(cos(angulo), 0.0, sin(angulo))
        var centro := Vector3(centros[i].x, 0.0, centros[i].y)
        var meia_base := 0.105
        var meia_ponta := 0.018
        var altura := 0.34 + float(i % 3) * 0.055
        var a := centro - lateral * meia_base
        var b := centro + lateral * meia_base
        var c := centro + lateral * meia_ponta + Vector3.UP * altura
        var d := centro - lateral * meia_ponta + Vector3.UP * altura
        st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a)
        st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(b)
        st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(c)
        st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a)
        st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(c)
        st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(d)
    st.generate_normals()
    _malha_grama_leve = st.commit()
    _material_grama_leve = ShaderMaterial.new()
    _material_grama_leve.shader = load("res://materials/grama_leve.gdshader")


## O acervo não possui um arbusto 3D texturizado: o arquivo com esse nome não
## tem UV nem imagem. Para não voltar às massas brancas, reutilizamos somente a
## malha de FOLHAS texturizadas do pinheiro, pequena e assentada como moita.
## Todas as moitas continuam custando uma única chamada de desenho.
func _plantar_arbustos_texturizados() -> void:
    var quantidade := int(_zone_data.get("bush_count", 0))
    if quantidade <= 0 or str(_zone_data.get("biome", "")) == "cidade":
        return
    var cena := load("res://models/pine_tree.glb") as PackedScene
    if cena == null:
        return
    var amostra := cena.instantiate() as Node3D
    var folhas: MeshInstance3D = null
    for candidato in amostra.find_children("*", "MeshInstance3D", true, false):
        if str(candidato.name).to_lower().contains("leav"):
            folhas = candidato as MeshInstance3D
            break
    if folhas == null or folhas.mesh == null:
        amostra.queue_free()
        return
    var caixa := _caixa_do_modelo(amostra)
    var local := _ate_a_raiz(folhas, amostra)
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = folhas.mesh
    multi.instance_count = quantidade
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zona"))) + 4821
    for i in quantidade:
        var p := _sortear_ponto_de_floresta(rng, 4.0)
        var altura := rng.randf_range(0.75, 1.35)
        var fator := altura / maxf(caixa.size.y, 0.01)
        var deformacao := Vector3(rng.randf_range(1.15, 1.65), rng.randf_range(0.72, 0.95), rng.randf_range(1.15, 1.65))
        var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * fator * deformacao)
        var suporte := Transform3D(base,
            Vector3(p.x, calcular_altura(p.x, p.y) - caixa.position.y * fator * deformacao.y, p.y))
        multi.set_instance_transform(i, suporte * local)
    var lote := MultiMeshInstance3D.new()
    lote.name = "ArbustosTexturizados"
    lote.multimesh = multi
    lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lote.visibility_range_end = 42.0
    lote.visibility_range_end_margin = 5.0
    _props_node.add_child(lote)
    amostra.queue_free()


## Touceiras PBR do pacote novo. O cenário completo de floresta recebido tem
## milhares de malhas e não pode entrar inteiro no Web; esta peça tem só duas
## superfícies e é repetida em lotes, preservando as texturas originais.
func _plantar_grama_texturizada_nova() -> void:
    if str(_zone_data.get("id", "")) != "zone_floresta_despertar":
        return
    var cena := load("res://models/vegetacao/grama_reeds.glb") as PackedScene
    if cena == null:
        return
    var amostra := cena.instantiate() as Node3D
    var caixa := _caixa_do_modelo(amostra)
    if caixa.size.y < 0.001:
        amostra.queue_free()
        return
    var quantidade := 84
    var rng := RandomNumberGenerator.new()
    rng.seed = 948271
    var posicoes: Array[Vector3] = []
    var escalas: Array[float] = []
    var giros: Array[float] = []
    var rios: Array = _zone_data.get("river_paths", [])
    for i in quantidade:
        var p := Vector2.ZERO
        if i < 52 and not rios.is_empty():
            # Vegetação úmida acompanha as margens, mas não nasce dentro d'água.
            var rio: Array = rios[0]
            var trecho := rng.randi_range(0, rio.size() - 2)
            var a := Vector2(float(rio[trecho][0]), float(rio[trecho][1]))
            var b := Vector2(float(rio[trecho + 1][0]), float(rio[trecho + 1][1]))
            var dir := (b - a).normalized()
            var normal := Vector2(-dir.y, dir.x)
            var lado := -1.0 if i % 2 == 0 else 1.0
            p = a.lerp(b, rng.randf()) + normal * lado * rng.randf_range(5.2, 8.5)
        else:
            p = _sortear_ponto_de_floresta(rng, 5.0)
        if _perto_da_rede(p, "road_paths", 5.8):
            p = _sortear_ponto_de_floresta(rng, 5.0)
        posicoes.append(Vector3(p.x, calcular_altura(p.x, p.y), p.y))
        escalas.append(rng.randf_range(0.38, 0.72) / caixa.size.y)
        giros.append(rng.randf_range(0.0, TAU))

    for candidato in amostra.find_children("*", "MeshInstance3D", true, false):
        var origem := candidato as MeshInstance3D
        if origem.mesh == null:
            continue
        var local := _ate_a_raiz(origem, amostra)
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = origem.mesh
        multi.instance_count = quantidade
        for i in quantidade:
            var fator := escalas[i]
            var modelo_local := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * fator),
                Vector3(0.0, -caixa.position.y * fator, 0.0))
            var suporte := Transform3D(Basis(Vector3.UP, giros[i]), posicoes[i])
            multi.set_instance_transform(i, suporte * modelo_local * local)
        var lote := MultiMeshInstance3D.new()
        lote.name = "GramaPBRNova"
        lote.multimesh = multi
        lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        lote.visibility_range_end = 0.0
        _props_node.add_child(lote)
    amostra.queue_free()


## A Floresta Inicial não é uma distribuição circular aleatória. Os maciços,
## clareiras e trilhas vêm do plano regional e permanecem iguais em toda carga.
func _sortear_ponto_de_floresta(rng: RandomNumberGenerator, dist_min: float) -> Vector2:
    var macicos: Array = _zone_data.get("forest_clusters", [])
    for tentativa in 24:
        var p := Vector2.ZERO
        if macicos.is_empty():
            var angulo := rng.randf_range(0.0, TAU)
            var distancia := rng.randf_range(dist_min, 68.0)
            p = Vector2(cos(angulo), sin(angulo)) * distancia
        else:
            var escolhido: Array = macicos[rng.randi_range(0, macicos.size() - 1)]
            var raio := float(escolhido[2]) * sqrt(rng.randf())
            var angulo := rng.randf_range(0.0, TAU)
            p = Vector2(float(escolhido[0]), float(escolhido[1])) \
                + Vector2(cos(angulo), sin(angulo)) * raio
        if absf(p.x) > 72.0 or absf(p.y) > 72.0:
            continue
        if _perto_da_rede(p, "river_paths", float(_zone_data.get("river_width", 5.0)) + 3.0):
            continue
        if _perto_da_rede(p, "road_paths", 7.0):
            continue
        if _dentro_de_clareira(p, 2.0):
            continue
        return p
    return Vector2(rng.randf_range(-68.0, 68.0), rng.randf_range(-68.0, 68.0))


func _dentro_de_clareira(p: Vector2, margem: float = 0.0) -> bool:
    for item in _zone_data.get("clearings", []):
        var centro := Vector2(float(item[0]), float(item[1]))
        if p.distance_to(centro) < float(item[2]) + margem:
            return true
    return false


## Pedras com textura real, todas em um único lote. Elas marcam o riacho e as
## bordas das clareiras sem adicionar dezenas de nós ou materiais exclusivos.
func _construir_detalhes_floresta_inicial() -> void:
    if str(_zone_data.get("id", "")) != "zone_floresta_despertar":
        return
    var quantidade := int(_zone_data.get("rock_count", 28))
    var pedra := SphereMesh.new()
    pedra.radius = 0.75
    pedra.height = 1.15
    pedra.radial_segments = 8
    pedra.rings = 4
    var material := StandardMaterial3D.new()
    material.albedo_texture = load("res://textures/stone_seamless.png")
    material.roughness = 0.94
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    pedra.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = pedra
    multi.instance_count = quantidade
    var rng := RandomNumberGenerator.new()
    rng.seed = 741903
    for i in quantidade:
        var p := Vector2.ZERO
        for tentativa in 18:
            if i < int(quantidade * 0.55):
                var caminhos: Array = _zone_data.get("river_paths", [])
                var rio: Array = caminhos[0]
                var trecho := rng.randi_range(0, rio.size() - 2)
                var a := Vector2(float(rio[trecho][0]), float(rio[trecho][1]))
                var b := Vector2(float(rio[trecho + 1][0]), float(rio[trecho + 1][1]))
                p = a.lerp(b, rng.randf()) + Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0))
            else:
                p = Vector2(rng.randf_range(-68.0, 68.0), rng.randf_range(-68.0, 68.0))
            if not _perto_da_rede(p, "road_paths", 6.5) and not _dentro_de_clareira(p, 1.5):
                break
        var escala := Vector3(rng.randf_range(0.55, 1.25), rng.randf_range(0.38, 0.82), rng.randf_range(0.60, 1.35))
        var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(escala)
        multi.set_instance_transform(i, Transform3D(base, Vector3(p.x, calcular_altura(p.x, p.y) + 0.10, p.y)))
    var lote := MultiMeshInstance3D.new()
    lote.name = "PedrasDaFloresta"
    lote.multimesh = multi
    lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lote.visibility_range_end = 52.0
    lote.visibility_range_end_margin = 6.0
    _props_node.add_child(lote)


func _perto_da_rede(p: Vector2, chave: String, largura: float) -> bool:
    for caminho in _zone_data.get(chave, []):
        for i in range(caminho.size() - 1):
            var a := Vector2(float(caminho[i][0]), float(caminho[i][1]))
            var b := Vector2(float(caminho[i + 1][0]), float(caminho[i + 1][1]))
            if _distancia_ao_segmento(p, a, b) < largura:
                return true
    return false

func _espalhar_props_3d(rng: RandomNumberGenerator, qtd: int, lista: Array, raio_max: float, solido: bool, sc_min: float, sc_max: float, dist_min: float) -> void:
    # Lista vazia e uma resposta valida agora: quando todos os modelos de um
    # tipo sao descartados por nao terem textura, o certo e nao espalhar nada.
    if lista.is_empty():
        return
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
    var num_passos: int = int(ceil((half * 2.0) / 12.0)) + 1
    var borda: Array[Vector3] = []
    for step in range(num_passos):
        # Distribui do primeiro ao ultimo canto. Antes havia dez passos de 8,5
        # m: a conta terminava no MEIO da borda e deixava a outra metade nua.
        var pos_along: float = lerpf(-half, half, float(step) / float(num_passos - 1))
        
        # No mundo continuo o lado com vizinha fica ABERTO: a fresta de 16 m
        # servia para caber um portal, e portal nao existe mais.
        var so_o_fim_do_mundo := _e_regiao

        # Norte
        if exits.get("north", "") == "" or (not so_o_fim_do_mundo and abs(pos_along) > portal_gap):
            borda.append(Vector3(pos_along, calcular_altura(pos_along, -half) - 0.5, -half))
        # Sul
        if exits.get("south", "") == "" or (not so_o_fim_do_mundo and abs(pos_along) > portal_gap):
            borda.append(Vector3(pos_along, calcular_altura(pos_along, half) - 0.5, half))
        # Oeste
        if exits.get("west", "") == "" or (not so_o_fim_do_mundo and abs(pos_along) > portal_gap):
            borda.append(Vector3(-half, calcular_altura(-half, pos_along) - 0.5, pos_along))
        # Leste
        if exits.get("east", "") == "" or (not so_o_fim_do_mundo and abs(pos_along) > portal_gap):
            borda.append(Vector3(half, calcular_altura(half, pos_along) - 0.5, pos_along))
    _plantar_pinheiros_em_lote(borda, hash(str(_zone_data.get("id", "borda"))) + 991)

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

    _regular_custo(modelo, tag)
    return suporte


## Quem projeta sombra e ate onde cada coisa e desenhada.
##
## A vila cheia media 327 malhas, 789 mil triangulos e 295 delas projetando
## sombra. O numero que doi e o ultimo: a luz direcional redesenha TODO objeto
## que projeta sombra, entao 295 sombreadores custam um segundo desenho da cena
## quase inteira a cada quadro, so para a sombra. Em GPU integrada e no
## navegador e a diferenca entre correr e engasgar.
##
## A regra e de leitura, nao de economia cega: sombra que o jogador percebe e a
## da CASA e a da ARVORE — massas grandes cujo escuro no chao ancora o objeto no
## terreno. Ninguem olha para a sombra de um saco de estopa; ela some e a cena
## continua igual, com um desenho a menos.
const PROJETA_SOMBRA := [
    "casa_alta", "casa_larga", "casa_pedra", "casarao", "solar",
    "casa_taipa", "casa_torre", "taverna",
    "arvore_marco", "arvore_gigante",
    "torre", "moinho", "celeiro", "muralha",
]

## Ate que distancia cada tamanho de coisa continua sendo desenhado, em metros.
##
## Prop pequeno visto de trinta metros na camera de cima ocupa uns poucos
## pixels: o motor paga o desenho inteiro para pintar quase nada. A margem de
## cinco metros faz o sumico ser um esmaecer, nao um estalo.
const ALCANCE_POR_TAG := {
    "saco": 32.0, "caixotes": 38.0, "barris": 42.0, "banco": 38.0,
    "tocha_parede": 45.0, "carroca": 55.0, "cogumelo": 45.0, "folhagem": 30.0,
    "poste": 75.0, "poco": 75.0, "pinheiro": 90.0, "pinheiro_real": 90.0,
}


func _regular_custo(modelo: Node3D, tag: String) -> void:
    var projeta: bool = tag in PROJETA_SOMBRA
    var alcance: float = float(ALCANCE_POR_TAG.get(tag, 0.0))
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        if not projeta:
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if alcance > 0.0:
            mi.visibility_range_end = alcance
            mi.visibility_range_end_margin = 5.0
            mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

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
func _limitar_alcance(no: Node3D) -> void:
    # Mede depois de aplicar a escala do filho. A versao anterior lia a caixa
    # normalizada do GLB (quase 1 m), concluia que toda casa era um objeto
    # pequeno e a apagava a 28 m. A cidade existia, mas sumia antes de entrar
    # no quadro — exatamente a aparencia de grandes areas vazias.
    var caixa := _caixa_do_modelo(no)
    if caixa.size.length_squared() < 0.001:
        return
    var maior_dimensao: float = maxf(caixa.size.y, maxf(caixa.size.x, caixa.size.z))
    var alcance: float = clampf(maior_dimensao * 7.5, 36.0, 110.0)
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
    
## Os pontos onde monstro nasce, e quem esta vivo em cada um.
##
## Nao ha lista de inimigos no mapa nem estado salvo: cada ninho lembra so o seu
## ponto, o tipo que nasce ali e quando o proximo pode vir.
var _ninhos: Array = []

## Quanto tempo o ninho fica vazio antes de repor. Meio minuto e o bastante para
## o jogador sentir que limpou a area, e curto o bastante para a zona nao virar
## um campo morto quando ele voltar.
const ESPERA_DO_RENASCIMENTO := 90.0
## Nao nasce em cima de quem esta jogando: vinte metros e alem do raio em que o
## bicho enxerga, entao ele aparece longe e caminha ate la.
const LONGE_DO_JOGADOR := 20.0
## De quanto em quanto tempo os ninhos sao conferidos. Um por segundo basta e
## nao pesa nada.
const RITMO_DA_CONFERENCIA := 1.0

var _ate_conferir := RITMO_DA_CONFERENCIA


func _process(delta: float) -> void:
    if not _e_regiao and not _celulas.is_empty():
        _ate_arrumar -= delta
        if _ate_arrumar <= 0.0:
            _ate_arrumar = 0.4
            _arrumar_vizinhanca()

    if _ninhos.is_empty():
        return
    _ate_conferir -= delta
    if _ate_conferir > 0.0:
        return
    _ate_conferir = RITMO_DA_CONFERENCIA
    _repor_monstros()


func _repor_monstros() -> void:
    var jogador := get_tree().get_first_node_in_group("jogador") as Node3D
    var agora := Time.get_ticks_msec() / 1000.0

    for ninho in _ninhos:
        if is_instance_valid(ninho["bicho"]):
            continue
        # Marca a hora da morte na primeira vez que o ninho e visto vazio.
        if float(ninho["volta_em"]) <= 0.0:
            ninho["volta_em"] = agora + ESPERA_DO_RENASCIMENTO
            continue
        if agora < float(ninho["volta_em"]):
            continue
        if jogador and jogador.global_position.distance_to(ninho["onde"]) < LONGE_DO_JOGADOR:
            continue

        var bicho = BichoScript.new()
        bicho.monster_type = int(ninho["tipo"])
        bicho.position = ninho["onde"]
        _props_node.add_child(bicho)
        ninho["bicho"] = bicho
        ninho["volta_em"] = 0.0


func _construir_monstros() -> void:
    var is_cidade: bool = (_zone_data.get("biome") == "cidade" or str(_zone_data.get("layout_id", "")) != "")
    if is_cidade:
        return
        
    # Poucos ninhos intencionais por região. As vizinhas também ficam
    # carregadas no mundo aberto; dez por célula viravam uma horda invisível.
    var qtd_monstros := clampi(int(_zone_data.get("monster_count", 3)), 0, 5)
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zone"))) + 555
    
    for i in range(qtd_monstros):
        var bicho = BichoScript.new()
        # Floresta comum recebe Shikers: maioria comum, um forte e elite rara.
        bicho.monster_type = 1 if i == qtd_monstros - 1 and qtd_monstros >= 4 else 0
        bicho.name = "Bicho_%d" % i
        
        var ang: float = rng.randf_range(0.0, TAU)
        var dist: float = rng.randf_range(30.0, 65.0)
        var px: float = cos(ang) * dist
        var pz: float = sin(ang) * dist
        var py: float = calcular_altura(px, pz)
        
        if _zone_data.get("water", false) and py < float(_zone_data.get("water_level", -2.0)) + 0.4:
            continue
            
        bicho.position = Vector3(px, py + 0.1, pz)
        _props_node.add_child(bicho)
        # O ponto fica guardado: e dele que o proximo Shiker nasce quando este
        # morrer. Sem isso a zona esvaziava para sempre — os dezesseis nasciam
        # uma vez, na construcao, e nunca mais.
        _ninhos.append({"onde": bicho.position, "tipo": bicho.monster_type,
                        "bicho": bicho, "volta_em": 0.0})


# ---------------------------------------------------------------------------
# COORDENACAO DO MUNDO ABERTO
#
# Nada aqui constroi cenario. Isto decide QUAIS zonas existem agora, e quem
# constroi continua sendo o mesmo codigo de sempre, uma copia por regiao.
# ---------------------------------------------------------------------------

func _chave(c: Vector2i) -> String:
    return "%d,%d" % [c.x, c.y]


## De ponto do mundo para celula. Cada celula ocupa TAMANHO_ZONA e e centrada
## no multiplo, por isso arredonda em vez de truncar.
func celula_do_ponto(x: float, z: float) -> Vector2i:
    return Vector2i(int(round(x / TAMANHO_ZONA)), int(round(z / TAMANHO_ZONA)))


func deslocamento_da_celula(c: Vector2i) -> Vector3:
    return Vector3(float(c.x) * TAMANHO_ZONA, 0.0, float(c.y) * TAMANHO_ZONA)


func zona_no_ponto(x: float, z: float) -> String:
    return String(_por_celula.get(_chave(celula_do_ponto(x, z)), ""))


## Deriva o mapa a partir das SAIDAS que ja existiam.
##
## Cada zona ja declarava quem fica ao norte, ao sul, a leste e a oeste — era
## isso que o portal consultava. Percorrendo esse grafo em largura a partir da
## zona inicial, cada zona ganha uma coordenada de grade, e o mundo aberto sai
## do desenho que o jogo ja tinha. Nenhuma zona foi movida ou redesenhada.
func montar_mundo(db: Dictionary, quem_joga: Node3D) -> void:
    _zonas_db = db
    jogador = quem_joga
    _celulas.clear()
    _por_celula.clear()

    var zonas: Dictionary = db.get("zones", {})
    var inicio := String(db.get("start_zone", ""))
    if not zonas.has(inicio):
        return

    # A planta nova declara a coordenada de cada região explicitamente. Isso é
    # o que permite desenhar Acordelot como no conceito, em vez de reconstruir
    # um corredor vertical a partir do antigo grafo de portais.
    var tem_planta := true
    for zid in zonas.keys():
        var dados: Dictionary = zonas[zid]
        var grade: Array = dados.get("grid_pos", [])
        if grade.size() < 2:
            tem_planta = false
            break
        var celula := Vector2i(int(grade[0]), int(grade[1]))
        if _por_celula.has(_chave(celula)):
            push_warning("Duas regiões ocupam a célula " + _chave(celula))
            continue
        _celulas[String(zid)] = celula
        _por_celula[_chave(celula)] = String(zid)

    if tem_planta:
        _arrumar_vizinhanca()
        return

    # Compatibilidade com mapas antigos sem grid_pos.
    _celulas.clear()
    _por_celula.clear()
    const PASSO := {"north": Vector2i(0, -1), "south": Vector2i(0, 1),
        "east": Vector2i(1, 0), "west": Vector2i(-1, 0)}

    var fila: Array = [inicio]
    _celulas[inicio] = Vector2i.ZERO
    _por_celula[_chave(Vector2i.ZERO)] = inicio
    while not fila.is_empty():
        var atual: String = fila.pop_front()
        var saidas: Dictionary = zonas.get(atual, {}).get("exits", {})
        for lado in PASSO.keys():
            var vizinha := String(saidas.get(lado, ""))
            if vizinha == "" or _celulas.has(vizinha) or not zonas.has(vizinha):
                continue
            var celula: Vector2i = _celulas[atual] + PASSO[lado]
            # Duas zonas apontando para o mesmo lugar: fica a primeira. O grafo
            # nasceu para portais, onde ninguem via as duas ao mesmo tempo, e
            # tem uma contradicao dessas.
            if _por_celula.has(_chave(celula)):
                continue
            _celulas[vizinha] = celula
            _por_celula[_chave(celula)] = vizinha
            fila.push_back(vizinha)

    _arrumar_vizinhanca()


## Distancia do ponto ate o RETANGULO da celula, nao ate o centro dela: quem
## esta encostado na divisa de uma zona grande esta perto dela, mesmo que o
## centro fique a cem metros.
func _distancia_ate_celula(ponto: Vector3, c: Vector2i) -> float:
    var meia := TAMANHO_ZONA * 0.5
    var centro := deslocamento_da_celula(c)
    var dx: float = maxf(absf(ponto.x - centro.x) - meia, 0.0)
    var dz: float = maxf(absf(ponto.z - centro.z) - meia, 0.0)
    return sqrt(dx * dx + dz * dz)


func _arrumar_vizinhanca() -> void:
    if jogador == null or not is_instance_valid(jogador):
        return
    var onde := jogador.global_position

    for zid in _celulas.keys():
        var perto := _distancia_ate_celula(onde, _celulas[zid])
        if perto <= PERTO_PARA_CARREGAR and not _regioes.has(zid):
            # Uma por vez. Montar duas zonas no mesmo quadro e justamente o
            # tranco que o mundo por portais escondia atras da tela preta.
            _construir_regiao(zid)
            return
        if perto > LONGE_PARA_SOLTAR and _regioes.has(zid):
            _soltar_regiao(zid)
            return


func _construir_regiao(zid: String) -> void:
    var dados: Dictionary = _zonas_db.get("zones", {}).get(zid, {})
    if dados.is_empty():
        return
    var regiao := ZoneBuilder.new()
    regiao.name = zid
    regiao._e_regiao = true
    regiao.position = deslocamento_da_celula(_celulas[zid])
    add_child(regiao)
    regiao.construir_zona(dados)
    _regioes[zid] = regiao


func _soltar_regiao(zid: String) -> void:
    var regiao: Node = _regioes.get(zid)
    if is_instance_valid(regiao):
        regiao.queue_free()
    _regioes.erase(zid)
