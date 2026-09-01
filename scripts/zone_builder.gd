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
var _fila_de_recursos: Array[String] = []
var _recurso_em_carga := ""
static var _recursos_aquecidos: Dictionary = {}

## O desenho regional pode ter até doze segmentos visíveis. A capital usa os
## dois eixos principais e duas ruas de bairro; seis segmentos cortavam as
## últimas vias e faziam o mapa e o chão discordarem.
const MAX_SEGMENTOS_DE_VIA := 12

var _terrain_mesh: MeshInstance3D
var _terrain_body: StaticBody3D
var _water_mesh: MeshInstance3D
var _portals_node: Node3D
var _props_node: Node3D
## Cruzamentos calculados uma vez antes da malha. O mesmo plano nivela o
## terreno, posiciona a ponte e cria sua colisao; assim as tres coisas nunca
## discordam sobre altura, direcao ou comprimento.
var _pontes_planejadas: Array = []
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

## Natureza CC0 curada do Stylized Nature MegaKit, reduzida para texturas de
## 1K. Cada modelo tem UV e imagens reais; as variações deixam a floresta de
## parecer uma plantação de uma única espécie sem recorrer a árvores pesadas.
const ARVORES_CC0 := [
    {"path": "res://models/cc0/nature/CommonTree_1.gltf", "altura_min": 7.8, "altura_max": 10.2},
    {"path": "res://models/cc0/nature/CommonTree_2.gltf", "altura_min": 7.4, "altura_max": 9.8},
    {"path": "res://models/cc0/nature/CommonTree_3.gltf", "altura_min": 6.8, "altura_max": 9.0},
    {"path": "res://models/cc0/nature/CommonTree_4.gltf", "altura_min": 7.0, "altura_max": 9.4},
    {"path": "res://models/cc0/nature/Pine_1.gltf", "altura_min": 8.2, "altura_max": 11.4},
    {"path": "res://models/cc0/nature/Pine_2.gltf", "altura_min": 8.0, "altura_max": 10.8},
    {"path": "res://models/cc0/nature/Pine_3.gltf", "altura_min": 8.8, "altura_max": 12.0},
    {"path": "res://models/cc0/nature/TwistedTree_1.gltf", "altura_min": 7.4, "altura_max": 9.6},
]
const TAMANHO_LOTE_NATUREZA := 32.0
static var _cenas_natureza_cc0: Dictionary = {}

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
        # Pequenos adereços CC0 têm posições desenhadas à mão num arquivo
        # separado. Assim a cidade continua planejada e o pacote externo pode
        # ser retirado sem tocar na planta estrutural das casas.
        var f_cc0 := FileAccess.open("res://data/urban_cc0_details.json", FileAccess.READ)
        if f_cc0:
            var detalhes = JSON.parse_string(f_cc0.get_as_text())
            if detalhes is Dictionary:
                for id in detalhes:
                    if _city_layouts.get("layouts", {}).has(id):
                        _city_layouts["layouts"][id].append_array(detalhes[id])

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

    _planejar_pontes()
    _construir_terreno()
    # Montar uma regiao inteira no mesmo quadro era o tranco sentido ao entrar
    # na cidade. O terreno nasce primeiro para o jogador nunca cair; o visual
    # restante e distribuido em poucos quadros.
    if is_inside_tree():
        await get_tree().process_frame

    # Rios e estradas pertencem ao plano da região, portanto nascem antes dos
    # edifícios. O leito já foi cavado pela mesma função de altura do terreno.
    _construir_rios()
    _construir_pontes_da_rede()
    _construir_meio_fio()
    
    if _zone_data.get("water", false):
        _construir_agua()

    await _construir_layout_urbano()
    _construir_marco_central()
    await _acender_a_povoacao()
    _plantar_os_npcs()
    _espalhar_os_adornos()
    if is_inside_tree():
        await get_tree().process_frame
    _construir_floresta_3d_real()
    _bloquear_macicos_densos()
    _plantar_vegetacao_baixa()
    _plantar_mato_pbr()
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
    return _altura_sem_rio_local(x, z, dados) - _profundidade_do_rio(Vector2(x, z), dados)


## Altura natural antes de cavar o canal. O rio usa esta linha como superfície;
## se consultasse calcular_altura(), cada margem receberia uma altura diferente
## do próprio buraco e a lâmina acompanharia o fundo como uma fita luminosa.
func _altura_sem_rio_local(x: float, z: float, dados: Dictionary) -> float:
    var bruto := _altura_natural_costurada(x, z, dados)
    # O coordenador consulta zonas que ainda nao foram construidas; nelas nao
    # existe plano local de ponte. Cada regiao construida usa seu proprio plano.
    if not _pontes_planejadas.is_empty():
        bruto = _nivelar_acessos_das_pontes(Vector2(x, z), bruto)
    return bruto


func _altura_natural_costurada(x: float, z: float, dados: Dictionary) -> float:
    var bruto := _relevo_da_zona(x, z, dados)
    var meia := TAMANHO_ZONA * 0.5
    var beira: float = maxf(absf(x), absf(z))
    if beira > meia - MARGEM_DE_COSTURA:
        var t: float = clampf((meia - beira) / MARGEM_DE_COSTURA, 0.0, 1.0)
        bruto *= t * t * (3.0 - 2.0 * t)
    return bruto


## Achata somente a pista e os acessos imediatos. O leito continua cavado em
## _altura_local(), portanto nivelar a estrada nao tampa o rio.
func _nivelar_acessos_das_pontes(p: Vector2, altura: float) -> float:
    var resultado := altura
    for ficha in _pontes_planejadas:
        var centro: Vector2 = ficha["ponto"]
        var direcao: Vector2 = ficha["direcao"]
        var relativo := p - centro
        var longitudinal := absf(relativo.dot(direcao))
        var lateral := absf(relativo.cross(direcao))
        var meio: float = float(ficha["comprimento"]) * 0.5
        if longitudinal > meio + 10.0 or lateral > 6.4:
            continue
        var peso_longo := 1.0 - smoothstep(meio + 4.0, meio + 10.0, longitudinal)
        var peso_lado := 1.0 - smoothstep(4.2, 6.4, lateral)
        resultado = lerpf(resultado, float(ficha["nivel"]), peso_longo * peso_lado)
    return resultado


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
    mat.set_shader_parameter("cor_funda", Color(0.025, 0.13, 0.26))
    mat.set_shader_parameter("cor_rasa", Color(0.10, 0.42, 0.58))
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
    # A malha entra alguns metros no barranco. O próprio terreno recorta essa
    # sobra e a água termina numa margem orgânica, nunca numa régua luminosa.
    var largura_superficie := largura + 2.8
    var material := ShaderMaterial.new()
    material.shader = load("res://materials/agua.gdshader")
    material.set_shader_parameter("cor_funda", Color(0.018, 0.11, 0.23))
    material.set_shader_parameter("cor_rasa", Color(0.075, 0.35, 0.50))

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
            var lateral := Vector2(-direcao.y, direcao.x) * largura_superficie
            var centro: Vector2 = amostras[i]
            for lado in [-1.0, 1.0]:
                var p: Vector2 = centro + lateral * float(lado)
                # Uma seção do rio tem uma só cota. Antes cada borda seguia o
                # próprio fundo cavado, produzindo uma fita torta e rasa.
                var y := _altura_sem_rio_local(centro.x, centro.y, _zone_data) \
                    - profundidade * 0.22
                st.set_color(Color(profundidade, 0.0, 0.0, 1.0))
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


## Pontes nascem da interseção real entre rua e rio. Assim uma mudança no
## traçado não deixa meio-fio flutuando nem exige coordenada duplicada à mão.
static func _cruzamento_2d(a: Vector2, b: Vector2, c: Vector2, d: Vector2):
    var r := b - a
    var s := d - c
    var denominador := r.cross(s)
    if absf(denominador) < 0.0001:
        return null
    var t := (c - a).cross(s) / denominador
    var u := (c - a).cross(r) / denominador
    if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
        return null
    return a + r * t


func _planejar_pontes() -> void:
    _pontes_planejadas.clear()
    var feitos := {}
    var largura: float = float(_zone_data.get("river_width", 5.0))
    # O canal cavado termina em largura + 4 m. A ponte precisa ultrapassar as
    # duas margens, senao suas pontas ficam suspensas sobre a parte inclinada.
    var comprimento := (largura + 4.0) * 2.0 + 2.0
    for rua in _zone_data.get("road_paths", []):
        for i in range(rua.size() - 1):
            var a := Vector2(float(rua[i][0]), float(rua[i][1]))
            var b := Vector2(float(rua[i + 1][0]), float(rua[i + 1][1]))
            var direcao := (b - a).normalized()
            for rio in _zone_data.get("river_paths", []):
                for j in range(rio.size() - 1):
                    var c := Vector2(float(rio[j][0]), float(rio[j][1]))
                    var d := Vector2(float(rio[j + 1][0]), float(rio[j + 1][1]))
                    var cruzamento = _cruzamento_2d(a, b, c, d)
                    if cruzamento == null:
                        continue
                    var ponto: Vector2 = cruzamento
                    var chave := "%d,%d" % [roundi(ponto.x), roundi(ponto.y)]
                    if feitos.has(chave):
                        continue
                    feitos[chave] = true
                    var amostra := comprimento * 0.5 + 6.0
                    var nivel := (
                        _altura_natural_costurada(ponto.x, ponto.y, _zone_data)
                        + _altura_natural_costurada(ponto.x + direcao.x * amostra,
                            ponto.y + direcao.y * amostra, _zone_data)
                        + _altura_natural_costurada(ponto.x - direcao.x * amostra,
                            ponto.y - direcao.y * amostra, _zone_data)
                    ) / 3.0
                    _pontes_planejadas.append({
                        "ponto": ponto, "direcao": direcao,
                        "nivel": nivel, "comprimento": comprimento,
                    })


func _construir_pontes_da_rede() -> void:
    if _pontes_planejadas.is_empty():
        return

    var de_pedra := str(_zone_data.get("road_surface", "terra")) == "pedra"
    var material := StandardMaterial3D.new()
    if de_pedra:
        material.albedo_texture = load("res://textures/flagstone_seamless.png")
        material.albedo_color = Color(0.48, 0.47, 0.44)
        material.uv1_scale = Vector3(0.55, 0.55, 0.55)
    else:
        material.albedo_texture = load("res://models/cc0/village/T_WoodTrim_BaseColor.png")
        material.albedo_color = Color(0.64, 0.52, 0.38)
        material.uv1_scale = Vector3(0.8, 0.8, 0.8)
    material.roughness = 0.96
    for ficha in _pontes_planejadas:
        _criar_ponte(ficha, material, de_pedra)


func _criar_ponte(ficha: Dictionary, material: StandardMaterial3D,
        de_pedra: bool) -> void:
    # A ponte anterior tinha 10,8 m de largura, 42 cm de espessura e paredes
    # macicas. No celular lia como uma plataforma suspensa. Esta acompanha a
    # largura visivel da estrada e repousa quase no nivel das margens.
    var largura_rua := 9.0 if de_pedra else 8.0
    var comprimento: float = float(ficha["comprimento"])
    var ponto: Vector2 = ficha["ponto"]
    var direcao_rua: Vector2 = ficha["direcao"]
    var ponte := Node3D.new()
    ponte.name = "ponte"
    # O topo fica dois centimetros acima do acesso, nao dezoito. A colisao e a
    # malha compartilham esta mesma raiz, eliminando degrau invisivel.
    ponte.position = Vector3(ponto.x, float(ficha["nivel"]) - 0.07, ponto.y)
    ponte.rotation.y = atan2(direcao_rua.x, direcao_rua.y)

    var tabuleiro := MeshInstance3D.new()
    var caixa := BoxMesh.new()
    caixa.size = Vector3(largura_rua, 0.18, comprimento)
    tabuleiro.mesh = caixa
    tabuleiro.material_override = material
    tabuleiro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ponte.add_child(tabuleiro)

    # Guias baixas marcam a borda sem esconder rio, cidade e personagem.
    for lado in [-1.0, 1.0]:
        var parapeito := MeshInstance3D.new()
        var viga := BoxMesh.new()
        viga.size = Vector3(0.16, 0.22, comprimento + 0.1)
        parapeito.mesh = viga
        parapeito.position = Vector3(lado * (largura_rua * 0.5 - 0.12), 0.16, 0.0)
        parapeito.material_override = material
        parapeito.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        ponte.add_child(parapeito)

    var corpo := StaticBody3D.new()
    var colisao := CollisionShape3D.new()
    var forma := BoxShape3D.new()
    forma.size = caixa.size
    colisao.shape = forma
    corpo.add_child(colisao)
    ponte.add_child(corpo)
    _props_node.add_child(ponte)


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
    material.albedo_color = Color(0.50, 0.49, 0.46)
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


## Marco legível para o coração da capital. O poço rural antigo funcionava na
## vila, mas diminuía a praça imperial; esta fonte usa só geometrias baratas e
## a mesma pedra das ruas, portanto combina sem introduzir outro asset pesado.
func _construir_marco_central() -> void:
    if not bool(_dados_da_praca().get("fonte_central", false)):
        return
    var fonte := Node3D.new()
    fonte.name = "fonte"
    fonte.position = Vector3(0.0, calcular_altura(0.0, 0.0), 0.0)

    var pedra := StandardMaterial3D.new()
    pedra.albedo_texture = load("res://textures/flagstone_seamless.png")
    pedra.albedo_color = Color(0.50, 0.49, 0.47)
    pedra.roughness = 0.96
    pedra.uv1_scale = Vector3(0.7, 0.7, 0.7)

    _anel_da_fonte(fonte, 5.2, 4.35, 0.55, 0.28, pedra)
    _anel_da_fonte(fonte, 2.2, 1.55, 0.34, 2.55, pedra)
    _cilindro_da_fonte(fonte, 0.82, 2.35, 1.45, pedra)
    _cilindro_da_fonte(fonte, 0.34, 1.05, 3.24, pedra)

    var agua := ShaderMaterial.new()
    agua.shader = load("res://materials/agua.gdshader")
    agua.set_shader_parameter("cor_funda", Color(0.025, 0.17, 0.31))
    agua.set_shader_parameter("cor_rasa", Color(0.11, 0.48, 0.64))
    _cilindro_da_fonte(fonte, 4.22, 0.07, 0.62, agua)
    _cilindro_da_fonte(fonte, 1.48, 0.06, 2.77, agua)

    var queda_material := StandardMaterial3D.new()
    queda_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    queda_material.albedo_color = Color(0.20, 0.68, 0.88)
    for x in [-0.42, 0.42]:
        _cilindro_da_fonte(fonte, 0.055, 1.45, 1.74, queda_material, Vector3(x, 0.0, 0.0))

    var corpo := StaticBody3D.new()
    var col := CollisionShape3D.new()
    var forma := CylinderShape3D.new()
    forma.radius = 5.1
    forma.height = 0.75
    col.shape = forma
    col.position.y = 0.38
    corpo.add_child(col)
    fonte.add_child(corpo)
    _props_node.add_child(fonte)


func _cilindro_da_fonte(raiz: Node3D, raio: float, altura: float, y: float,
        material: Material, deslocamento := Vector3.ZERO) -> void:
    var no := MeshInstance3D.new()
    var cilindro := CylinderMesh.new()
    cilindro.top_radius = raio
    cilindro.bottom_radius = raio
    cilindro.height = altura
    cilindro.radial_segments = 24
    no.mesh = cilindro
    no.position = Vector3(deslocamento.x, y, deslocamento.z)
    no.material_override = material
    raiz.add_child(no)


func _anel_da_fonte(raiz: Node3D, externo: float, interno: float, altura: float,
        y: float, material: Material) -> void:
    # Vinte e quatro blocos em UMA MultiMesh formam um anel aberto. A fonte
    # inteira não pode custar cinquenta chamadas só por ser redonda.
    var segmentos := 24
    var raio := (externo + interno) * 0.5
    var espessura := externo - interno
    var caixa := BoxMesh.new()
    caixa.size = Vector3(espessura, altura, TAU * raio / float(segmentos) * 1.08)
    caixa.material = material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = caixa
    multi.instance_count = segmentos
    for i in segmentos:
        var angulo := TAU * float(i) / float(segmentos)
        multi.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -angulo),
            Vector3(cos(angulo) * raio, y, sin(angulo) * raio)))
    var no := MultiMeshInstance3D.new()
    no.multimesh = multi
    raiz.add_child(no)

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
    "barril_cc0": 1.05, "caixote_cc0": 0.85, "banco_cc0": 0.95,
    "banca_cc0": 2.45, "carroca_cc0": 2.0, "cerca_cc0": 1.15,
    "oficina_cc0": 1.55, "estandarte_cc0": 3.8, "balde_cc0": 0.65,
    "bau_cc0": 0.9, "mesa_cc0": 0.9, "videira_cc0": 2.3,
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
            if segmentos.size() >= MAX_SEGMENTOS_DE_VIA:
                break
        if segmentos.size() >= MAX_SEGMENTOS_DE_VIA:
            break
    mat.set_shader_parameter("quantidade_caminhos", segmentos.size())
    mat.set_shader_parameter("caminho_de_pedra", 1.0 if str(_zone_data.get("road_surface", "terra")) == "pedra" else 0.0)
    for i in MAX_SEGMENTOS_DE_VIA:
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
    if caminho.begins_with("res://models/cc0/"):
        return true
    return caminho.get_file().get_basename() in COM_TEXTURA


const PROPS_DE_CALCADA := [
    "barris", "caixotes", "saco", "banco", "carroca", "banca",
    "barril_cc0", "caixote_cc0", "banco_cc0", "banca_cc0",
    "carroca_cc0", "balde_cc0", "bau_cc0", "mesa_cc0", "oficina_cc0",
]
## O distrito antigo tinha entulho suficiente para bloquear a avenida. Ficam
## exemplares para contar que a cidade e habitada, mas nao dezesseis pilhas do
## mesmo objeto ocupando a faixa de circulacao.
const LIMITE_ENTULHO_PORTOES := {
    "carroca": 4, "barris": 5, "caixotes": 5, "saco": 4, "cogumelo": 0,
}


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
    var pinheiros_planejados: Array[Vector3] = []
    var contagem_entulho := {}
    var construidas := 0

    for p in pecas:
        var tag: String = str(p.get("tag", ""))
        if str(_zone_data.get("id", "")) == "zone_portoes" \
                and LIMITE_ENTULHO_PORTOES.has(tag):
            var usados := int(contagem_entulho.get(tag, 0))
            if usados >= int(LIMITE_ENTULHO_PORTOES[tag]):
                continue
            contagem_entulho[tag] = usados + 1

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

        # Pinheiros repetidos usam MultiMesh. No distrito dos Portoes eram 52
        # cenas completas, com centenas de nos surgindo no mesmo quadro.
        var pos: Array = p.get("position", [0.0, 0.0])
        var px: float = float(pos[0]) if pos.size() > 0 else 0.0
        var pz: float = float(pos[1]) if pos.size() > 1 else 0.0
        if tag == "pinheiro":
            pinheiros_planejados.append(Vector3(px, calcular_altura(px, pz), pz))
            continue

        var altura_alvo: float = float(ALTURA_POR_TAG.get(tag, ALTURA_PADRAO))
        var escala_layout: float = float(p.get("scale", 1.0))

        var suporte := _instanciar_prop_3d(modelo_path, tag, altura_alvo, escala_layout)
        if not suporte:
            continue

        # A planta grava a posicao como [x, z] num par, e o giro em "rotation".
        # _instanciar_prop_3d ja desloca a base real da malha para y=0. Um
        # segundo desconto enterrava bancos, caixas e outros props baixos.
        var py: float = calcular_altura(px, pz) + float(p.get("y", 0.0))

        suporte.position = Vector3(px, py, pz)
        suporte.rotation.y = deg_to_rad(float(p.get("rotation", 0.0)))

        # A LINHA DE FACHADA é medida na casa, não na tabela.
        #
        # O planejador sempre quis alinhar a parede da frente, e para isso
        # subtraía o "fundo" anotado no catálogo. Só que o giro da casa troca
        # os eixos: uma casa virada 90° apresenta para a rua a LARGURA dela, e
        # o número subtraído continuava sendo o fundo. Daí a rua de Acordelot —
        # fachadas na mesma linha no papel, casas a distâncias diferentes do
        # calçamento na tela, com buracos de grama entre uma e outra.
        #
        # Aqui a medida sai da malha já girada, que é a única que sabe quanto a
        # casa realmente ocupa naquele ângulo. A planta só diz onde é a linha e
        # de que lado da rua o lote está.
        var fachada: Array = p.get("fachada", [])
        if fachada.size() >= 3:
            var girada: AABB = Transform3D(Basis(Vector3.UP, suporte.rotation.y),
                Vector3.ZERO) * _caixa_do_modelo(suporte)
            var linha := float(fachada[1])
            var lado := float(fachada[2])
            if str(fachada[0]) == "x":
                px = linha - (girada.position.x + girada.size.x) if lado < 0.0 \
                    else linha - girada.position.x
            else:
                pz = linha - (girada.position.z + girada.size.z) if lado < 0.0 \
                    else linha - girada.position.z
            py = calcular_altura(px, pz) + float(p.get("y", 0.0))
            suporte.position = Vector3(px, py, pz)

        # Reserva física das margens. A posição do centro não basta: uma casa
        # larga a onze metros do rio ainda podia pôr metade do telhado na água.
        # Mede a ocupação já girada e rejeita qualquer peça que invada o canal.
        var ocupacao: AABB = Transform3D(Basis(Vector3.UP, suporte.rotation.y),
            Vector3.ZERO) * _caixa_do_modelo(suporte)
        if tag in PROPS_DE_CALCADA:
            var raio_prop := maxf(ocupacao.size.x, ocupacao.size.z) * 0.5
            var fora_da_rua := _afastar_da_faixa_viaria(Vector2(px, pz), raio_prop)
            if fora_da_rua != Vector2(px, pz):
                px = fora_da_rua.x
                pz = fora_da_rua.y
                py = calcular_altura(px, pz) + float(p.get("y", 0.0))
                suporte.position = Vector3(px, py, pz)
        var folga_rio := maxf(ocupacao.size.x, ocupacao.size.z) * 0.52 + 1.5
        if _perto_da_rede(Vector2(px, pz), "river_paths",
                float(_zone_data.get("river_width", 5.0)) + folga_rio):
            suporte.free()
            continue

        _limitar_alcance(suporte)

        # Grama e mato nao ganham colisor: sao dezenas por cidade, e parar o
        # jogador num tufo de capim e o tipo de tropeco que ninguem entende.
        if tag not in ["folhagem", "barril_cc0", "caixote_cc0", "banco_cc0",
                "estandarte_cc0", "balde_cc0", "videira_cc0", "banca_cc0",
                "carroca_cc0", "bau_cc0", "mesa_cc0", "oficina_cc0"]:
            _adicionar_colisor_prop(suporte, tag, 1.0)
        _props_node.add_child(suporte)
        construidas += 1
        if construidas % 6 == 0 and is_inside_tree():
            await get_tree().process_frame

    if not pinheiros_planejados.is_empty():
        _plantar_pinheiros_em_lote(pinheiros_planejados,
            hash(str(_zone_data.get("id", "cidade"))) + 319)


## Move apenas props pequenos para a calcada. Casas, muralhas, fontes e postes
## permanecem exatamente onde o plano urbano os colocou.
func _afastar_da_faixa_viaria(p: Vector2, raio_prop: float) -> Vector2:
    var melhor_distancia := INF
    var melhor_ponto := Vector2.ZERO
    var melhor_direcao := Vector2.RIGHT
    for caminho in _zone_data.get("road_paths", []):
        for i in range(caminho.size() - 1):
            var a := Vector2(float(caminho[i][0]), float(caminho[i][1]))
            var b := Vector2(float(caminho[i + 1][0]), float(caminho[i + 1][1]))
            var ab := b - a
            if ab.length_squared() < 0.001:
                continue
            var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
            var proximo := a + ab * t
            var distancia := p.distance_to(proximo)
            if distancia < melhor_distancia:
                melhor_distancia = distancia
                melhor_ponto = proximo
                melhor_direcao = ab.normalized()
    var distancia_segura := 6.2 + raio_prop + 0.7
    if melhor_distancia >= distancia_segura or melhor_distancia == INF:
        # Longe da estrada da regiao, mas ainda pode estar em cima da avenida da
        # propria vila — que e outra lista, e ate aqui ninguem a consultava.
        if _sobre_a_via_urbana(p, raio_prop + 0.6):
            return _empurrar_para_fora_da_via(p, raio_prop + 0.6)
        return p
    var normal := (p - melhor_ponto).normalized()
    if normal.length_squared() < 0.01:
        normal = Vector2(-melhor_direcao.y, melhor_direcao.x)
        if (roundi(p.x) + roundi(p.y)) % 2 == 0:
            normal = -normal
    return melhor_ponto + normal * distancia_segura


## Sai da rua da vila pelo lado mais curto.
##
## As vias urbanas sao faixas alinhadas aos eixos, entao "o lado mais curto" e
## so comparar quanto falta para cada borda — nao ha curva para projetar.
func _empurrar_para_fora_da_via(p: Vector2, folga: float) -> Vector2:
    var destino := p
    for _passo in 4:
        if not _sobre_a_via_urbana(destino, folga):
            return destino
        var vias: Dictionary = _dados_da_praca().get("vias", {})
        var principal: Array = vias.get("principal", [0.0, 0.0])
        var meia_rua: float = float(principal[0]) + folga + 0.4
        # Empurra para o lado em que ja esta; ficar exatamente no eixo manda
        # para a direita, e duas pecas no mesmo eixo nao se empilham porque a
        # paridade da coordenada decide.
        var lado: float = signf(destino.x)
        if is_zero_approx(lado):
            lado = 1.0 if (roundi(destino.y) % 2 == 0) else -1.0
        destino.x = lado * meia_rua
        var raio_do_largo := float(vias.get("largo", 0.0))
        if raio_do_largo > 0.01 and destino.length() < raio_do_largo + folga:
            destino = destino.normalized() * (raio_do_largo + folga + 0.4)
    return destino

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
    var feitas := 0
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
        feitas += 1
        if feitas % 6 == 0 and is_inside_tree():
            await get_tree().process_frame

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
        feitas += 1
        if feitas % 6 == 0 and is_inside_tree():
            await get_tree().process_frame


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
        var posicoes: Array[Vector3] = []
        for i in range(n_arvores):
            var p := _sortear_ponto_de_floresta(rng, raio_min)
            posicoes.append(Vector3(p.x, calcular_altura(p.x, p.y), p.y))
        _plantar_arvores_cc0_em_lotes(posicoes, hash(str(_zone_data.get("id", "zona"))))
    if not is_cidade:
        var subbosque: int = clampi(int(round(float(n_arvores) * 0.20)), 10, 18)
        _espalhar_props_3d(rng, subbosque, SUBBOSQUE_FLORESTA_3D,
            66.0, false, 0.82, 1.22, 5.0)
    _espalhar_props_3d(rng, n_arbustos, ARBUSTOS_3D, 65.0, false, 0.9, 1.3, raio_min)


## O centro dos maciços é mata fechada, não um campo com árvores decorativas.
## Um cilindro por núcleo custa muito menos que colisão em cada galho e impede
## atravessar os cantos que não levam a lugar algum. Trilhas e clareiras ficam
## livres porque seus centros já são excluídos pelo desenho regional.
func _bloquear_macicos_densos() -> void:
    if str(_zone_data.get("biome", "")) not in ["floresta", "sombria"]:
        return
    for item in _zone_data.get("forest_clusters", []):
        if item.size() < 3:
            continue
        var p := Vector2(float(item[0]), float(item[1]))
        var raio := clampf(float(item[2]) * 0.34, 5.0, 9.0)
        if _perto_da_rede(p, "road_paths", raio + 2.5) or _dentro_de_clareira(p, raio):
            continue
        var corpo := StaticBody3D.new()
        corpo.name = "MataFechada"
        corpo.position = Vector3(p.x, calcular_altura(p.x, p.y), p.y)
        var col := CollisionShape3D.new()
        var forma := CylinderShape3D.new()
        forma.radius = raio
        forma.height = 5.0
        col.shape = forma
        col.position.y = 2.5
        corpo.add_child(col)
        _props_node.add_child(corpo)


## Árvores divididas por espécie E por pedaço espacial. Um MultiMesh único
## atravessando 160 m nunca sai da tela: se uma árvore estiver visível, o lote
## inteiro é enviado à GPU. Em lotes de 32 m só a vizinhança da câmera desenha,
## que é o que permite aumentar variedade mantendo o alvo móvel.
func _plantar_arvores_cc0_em_lotes(posicoes: Array[Vector3], semente: int) -> void:
    if posicoes.is_empty():
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = semente
    var grupos: Dictionary = {}
    var floresta_inicial := str(_zone_data.get("id", "")) == "zone_floresta_despertar"
    # Mais pinheiros e arvores comuns baratas no macico principal: a copa fica
    # fechada sem multiplicar a variante retorcida de quase 10 mil triangulos.
    var variantes_leves := [4, 5, 6, 4, 5, 6, 2, 3, 0, 1, 7]
    for i in posicoes.size():
        var variante: int = int(variantes_leves[
            rng.randi_range(0, variantes_leves.size() - 1)]) \
            if floresta_inicial else rng.randi_range(0, ARVORES_CC0.size() - 1)
        var p := posicoes[i]
        var cx := int(floor((p.x + TAMANHO_ZONA * 0.5) / TAMANHO_LOTE_NATUREZA))
        var cz := int(floor((p.z + TAMANHO_ZONA * 0.5) / TAMANHO_LOTE_NATUREZA))
        var chave := "%d:%d:%d" % [cx, cz, variante]
        if not grupos.has(chave):
            grupos[chave] = {"variante": variante, "copias": []}
        var ficha: Dictionary = ARVORES_CC0[variante]
        grupos[chave]["copias"].append({
            "pos": p,
            "giro": rng.randf_range(0.0, TAU),
            "altura": rng.randf_range(float(ficha["altura_min"]), float(ficha["altura_max"])),
        })

    var colisao_indice := 0
    for chave in grupos:
        var grupo: Dictionary = grupos[chave]
        var ficha: Dictionary = ARVORES_CC0[int(grupo["variante"])]
        var caminho := str(ficha["path"])
        if not _cenas_natureza_cc0.has(caminho):
            _cenas_natureza_cc0[caminho] = load(caminho)
        var cena := _cenas_natureza_cc0[caminho] as PackedScene
        if cena == null:
            continue
        var modelo := cena.instantiate() as Node3D
        var caixa := _caixa_do_modelo(modelo)
        if caixa.size.y < 0.001:
            modelo.free()
            continue
        var copias: Array = grupo["copias"]
        for candidato in modelo.find_children("*", "MeshInstance3D", true, false):
            var origem := candidato as MeshInstance3D
            if origem.mesh == null:
                continue
            var local := _ate_a_raiz(origem, modelo)
            var multi := MultiMesh.new()
            multi.transform_format = MultiMesh.TRANSFORM_3D
            multi.mesh = origem.mesh
            multi.instance_count = copias.size()
            for j in copias.size():
                var copia: Dictionary = copias[j]
                var fator: float = float(copia["altura"]) / caixa.size.y
                var base_modelo := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * fator),
                    Vector3(0.0, -caixa.position.y * fator - 0.06, 0.0))
                var suporte := Transform3D(Basis(Vector3.UP, float(copia["giro"])), copia["pos"])
                multi.set_instance_transform(j, suporte * base_modelo * local)
            var lote := MultiMeshInstance3D.new()
            lote.name = "BosqueCC0"
            lote.multimesh = multi
            lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            lote.visibility_range_end = 68.0
            lote.visibility_range_end_margin = 6.0
            _props_node.add_child(lote)

        # Um colisor a cada três árvores mantém o maciço difícil de atravessar
        # sem criar centenas de corpos físicos em todas as zonas carregadas.
        for copia in copias:
            if colisao_indice % 3 == 0:
                var corpo := StaticBody3D.new()
                corpo.position = copia["pos"]
                var col := CollisionShape3D.new()
                var forma := CylinderShape3D.new()
                forma.radius = 0.72
                forma.height = 4.5
                col.shape = forma
                col.position.y = 2.25
                corpo.add_child(col)
                _props_node.add_child(corpo)
            colisao_indice += 1
        modelo.free()


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
        lote.visibility_range_end = 78.0
        lote.visibility_range_end_margin = 7.0
        _props_node.add_child(lote)

    # Colisor sem malha: não aumenta draw calls e mantém árvores como obstáculo.
    for i in posicoes.size():
        # Um colisor a cada quatro, somado aos nucleos macicos, preserva a
        # leitura de mata/limite sem criar cinquenta corpos numa unica cidade.
        if i % 4 != 0:
            continue
        var pos := posicoes[i]
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
## Esta malha tem quinze triângulos por tufo: podemos cobrir o terreno inteiro
## com milhares de cópias e continuar bem abaixo do custo antigo.
##
## O sorteio NÃO é uniforme. Espalhar tufos iguais por 152 metros dava um campo
## de confete: pontinhos escuros de espaçamento constante até o horizonte. Grama
## de verdade cresce em manchas, com falhas entre elas, e é assim que a gente
## planta aqui — a maior parte em touceiras, o resto solto para fechar o tapete.
func _plantar_vegetacao_baixa() -> void:
    _preparar_grama_leve()
    if _malha_grama_leve == null:
        return
    # Longe, o shader recolhe a lâmina até ela sumir; então densidade alta não
    # custa preenchimento, só o tapete perto do jogador ficar cheio de verdade.
    var quantidade := clampi(int(_zone_data.get("grass_density", 900)) * 2, 1500, 5000)
    if str(_zone_data.get("biome", "")) == "cidade":
        quantidade = mini(quantidade, 350)
    var lotes: Dictionary = {}
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zona"))) + 1907
    # Uma touceira a cada doze tufos: manchas de uns três metros, densas por
    # dentro, com chao aparecendo entre elas.
    var manchas := maxi(quantidade / 16, 8)
    var centros: Array[Vector2] = []
    for _m in manchas:
        centros.append(Vector2(rng.randf_range(-76.0, 76.0), rng.randf_range(-76.0, 76.0)))
    var largura_rio := float(_zone_data.get("river_width", 5.0)) + 2.0
    for i in quantidade:
        var p := Vector2.ZERO
        var tentativas := 0
        while tentativas < 8:
            if i % 4 == 3:
                # Um quarto solto no campo: sem ele as manchas viram ilhas.
                p = Vector2(rng.randf_range(-76.0, 76.0), rng.randf_range(-76.0, 76.0))
            else:
                var centro: Vector2 = centros[rng.randi_range(0, centros.size() - 1)]
                var raio := 2.6 * sqrt(rng.randf())
                var giro := rng.randf_range(0.0, TAU)
                p = centro + Vector2(cos(giro), sin(giro)) * raio
                p.x = clampf(p.x, -76.0, 76.0)
                p.y = clampf(p.y, -76.0, 76.0)
            if not (_perto_da_rede(p, "river_paths", largura_rio)
                    or _perto_da_rede(p, "road_paths", 7.0)):
                break
            tentativas += 1
        var escala := rng.randf_range(0.68, 1.34)
        var inclinacao := Basis(Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized(),
            rng.randf_range(0.0, 0.16))
        var base := inclinacao * Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
            Vector3(escala, escala * rng.randf_range(0.82, 1.22), escala))
        var transformacao := Transform3D(base,
            Vector3(p.x, calcular_altura(p.x, p.y) - 0.015, p.y))
        # Matiz por tufo: nenhum gramado real tem um verde só, e a variação é o
        # que impede o tapete de virar uma estampa repetida.
        var tom := rng.randf_range(0.82, 1.15)
        var cor := Color(tom * rng.randf_range(0.92, 1.06), tom,
            tom * rng.randf_range(0.86, 1.02))
        var cx := int(floor((p.x + TAMANHO_ZONA * 0.5) / TAMANHO_LOTE_NATUREZA))
        var cz := int(floor((p.y + TAMANHO_ZONA * 0.5) / TAMANHO_LOTE_NATUREZA))
        var chave := "%d:%d" % [cx, cz]
        if not lotes.has(chave):
            lotes[chave] = []
        lotes[chave].append([transformacao, cor])

    for chave in lotes:
        var instancias: Array = lotes[chave]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.use_colors = true
        multi.mesh = _malha_grama_leve
        multi.instance_count = instancias.size()
        for i in instancias.size():
            multi.set_instance_transform(i, instancias[i][0])
            multi.set_instance_color(i, instancias[i][1])
        var tufos := MultiMeshInstance3D.new()
        tufos.name = "TapeteDeGrama3D"
        tufos.multimesh = multi
        tufos.material_override = _material_grama_leve
        tufos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        tufos.visibility_range_end = 42.0
        tufos.visibility_range_end_margin = 5.0
        _props_node.add_child(tufos)


## A lâmina em si: base larga, curvada para frente e terminando em ponta.
##
## O quadrilátero reto de antes lia como espinho, não como folha — e cinco
## espinhos juntos liam como um arbusto seco em miniatura. Dois segmentos e uma
## curva custam um triângulo a mais por lâmina e mudam a silhueta inteira.
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
        # A folha tomba para o lado oposto ao da largura: assim a curva aparece
        # de perfil, que é como a câmera de ombro vê o gramado.
        var tombo := Vector3(-lateral.z, 0.0, lateral.x)
        var centro := Vector3(centros[i].x, 0.0, centros[i].y)
        var altura := 0.28 + float(i % 3) * 0.05
        var curva := altura * (0.30 + float(i % 2) * 0.12)
        var meia_base := 0.052
        var meia_meio := 0.036
        # Nível 0 (chão), nível 1 (meio, já inclinado) e a ponta.
        var a0 := centro - lateral * meia_base
        var b0 := centro + lateral * meia_base
        var meio := centro + Vector3.UP * (altura * 0.55) + tombo * (curva * 0.28)
        var a1 := meio - lateral * meia_meio
        var b1 := meio + lateral * meia_meio
        var ponta := centro + Vector3.UP * altura + tombo * curva
        st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a0)
        st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(b0)
        st.set_uv(Vector2(1.0, 0.55)); st.add_vertex(b1)
        st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a0)
        st.set_uv(Vector2(1.0, 0.55)); st.add_vertex(b1)
        st.set_uv(Vector2(0.0, 0.55)); st.add_vertex(a1)
        st.set_uv(Vector2(0.0, 0.55)); st.add_vertex(a1)
        st.set_uv(Vector2(1.0, 0.55)); st.add_vertex(b1)
        st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(ponta)
    st.generate_normals()
    _malha_grama_leve = st.commit()
    _material_grama_leve = ShaderMaterial.new()
    _material_grama_leve.shader = load("res://materials/grama_leve.gdshader")


## Mato de verdade, do pacote novo em models/vegetacao/mato_pbr.glb.
##
## Até aqui o "arbusto texturizado" era um remendo: o acervo não tinha arbusto
## com UV, então a moita era a malha de FOLHAS do pinheiro deitada no chão —
## agulha de conífera fazendo papel de mato. O pacote novo trouxe duas peças
## fotografadas e recortadas em alfa: um tufo de capim alto e uma erva de folha
## larga com flor amarela. Cada peça custa menos de 400 triângulos e vem com
## recorte por limiar, que no celular não paga ordenação de transparência.
##
## A erva entra duas vezes, em escalas diferentes: pequena ela é o mato rasteiro
## que quebra o tapete verde; grande ela é o arbusto que o mundo não tinha.
func _plantar_mato_pbr() -> void:
    if str(_zone_data.get("biome", "")) == "cidade":
        return
    var cena := load("res://models/vegetacao/mato_pbr.glb") as PackedScene
    if cena == null:
        return
    var amostra := cena.instantiate() as Node3D
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(str(_zone_data.get("id", "zona"))) + 5507
    var arbustos := int(_zone_data.get("bush_count", 22))
    _semear_mato(amostra, "tufo_alto", 700, 0.55, 0.95, 34.0, rng)
    # A erva é uma roseta de folha larga: medida pela altura ela viraria um
    # disco de dois metros e meio de diâmetro. Esta é medida pela largura.
    _semear_mato(amostra, "erva_flor", 400, 0.45, 0.75, 26.0, rng, true)
    _semear_mato(amostra, "erva_flor", arbustos * 2, 1.10, 1.70, 44.0, rng, true)
    _semear_moita_na_trilha(amostra, rng)
    amostra.queue_free()


## A moita densa, só na beira das trilhas.
##
## É a peça mais bonita do pacote e a mais cara: 4.130 triângulos, dez vezes o
## tufo. Espalhada pela região ela sozinha custaria mais que toda a grama. Mas
## a trilha é onde o jogador anda e onde ele olha de perto — vinte e seis moitas
## ladeando o caminho aparecem mais do que trezentas perdidas no meio do mato.
func _semear_moita_na_trilha(amostra: Node3D, rng: RandomNumberGenerator) -> void:
    var trilhas: Array = _zone_data.get("road_paths", [])
    if trilhas.is_empty():
        return
    _semear_mato(amostra, "moita_baixa", 26, 0.70, 1.15, 30.0, rng, true, true)


## Uma espécie, uma chamada de desenho.
##
## `alcance` é onde a peça termina de encolher: quem cuida da distância é o
## shader, instância por instância, e não o nó — limitar o NÓ apagava o lote
## inteiro de uma vez quando o jogador andava para a beira da região.
func _semear_mato(amostra: Node3D, nome: String, quantidade: int,
        medida_min: float, medida_max: float, alcance: float,
        rng: RandomNumberGenerator, pela_largura: bool = false,
        na_trilha: bool = false) -> void:
    if quantidade <= 0:
        return
    var origem: MeshInstance3D = null
    for candidato in amostra.find_children("*", "MeshInstance3D", true, false):
        if str(candidato.name).to_lower().begins_with(nome):
            origem = candidato as MeshInstance3D
            break
    if origem == null or origem.mesh == null:
        return
    var local := _ate_a_raiz(origem, amostra)
    var caixa_mundo: AABB = local * origem.mesh.get_aabb()
    if caixa_mundo.size.y < 0.001:
        return
    var medida_media := (medida_min + medida_max) * 0.5
    var referencia_base := maxf(caixa_mundo.size.x, caixa_mundo.size.z) if pela_largura \
        else caixa_mundo.size.y
    var altura_tipica := caixa_mundo.size.y * medida_media / maxf(referencia_base, 0.001)

    var lotes: Dictionary = {}
    var largura_rio := float(_zone_data.get("river_width", 5.0)) + 2.5
    for i in quantidade:
        # Metade nos maciços, metade no campo aberto: o mato do plano regional
        # nasce junto com as árvores, mas clareira sem mato nenhum lê como
        # gramado de jardim, não como floresta.
        var p := _ponto_na_beira_da_trilha(rng) if na_trilha \
            else _ponto_de_mato(rng, i % 2 == 0)
        var tentativas := 0
        while (not na_trilha
                and (_perto_da_rede(p, "road_paths", 5.0)
                    or _perto_da_rede(p, "river_paths", largura_rio))
                and tentativas < 6):
            p = _ponto_de_mato(rng, i % 2 == 0)
            tentativas += 1
        var medida := rng.randf_range(medida_min, medida_max)
        var fator := medida / maxf(referencia_base, 0.001)
        var largura := fator * rng.randf_range(0.85, 1.25)
        var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
            Vector3(largura, fator, largura))
        var suporte := Transform3D(base,
            Vector3(p.x, calcular_altura(p.x, p.y) - caixa_mundo.position.y * fator, p.y))
        var cx := int(floor((p.x + TAMANHO_ZONA * 0.5) / TAMANHO_LOTE_NATUREZA))
        var cz := int(floor((p.y + TAMANHO_ZONA * 0.5) / TAMANHO_LOTE_NATUREZA))
        var chave := "%d:%d" % [cx, cz]
        if not lotes.has(chave):
            lotes[chave] = []
        lotes[chave].append(suporte * local)

    var material := _material_do_mato(origem, altura_tipica, alcance)
    for chave in lotes:
        var instancias: Array = lotes[chave]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = origem.mesh
        multi.instance_count = instancias.size()
        for i in instancias.size():
            multi.set_instance_transform(i, instancias[i])
        var lote := MultiMeshInstance3D.new()
        lote.name = "Mato_" + nome
        lote.multimesh = multi
        lote.material_override = material
        lote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        lote.visibility_range_end = alcance + 8.0
        lote.visibility_range_end_margin = 4.0
        _props_node.add_child(lote)


## Um ponto na margem da trilha, do lado de fora da terra batida.
##
## O chão pinta a estrada até uns cinco metros e meio do eixo, com uma franja de
## ruído por cima. A moita começa depois disso: dentro da faixa ela nasceria no
## meio da passagem, e é a passagem que faz a trilha ser trilha.
func _ponto_na_beira_da_trilha(rng: RandomNumberGenerator) -> Vector2:
    var trilhas: Array = _zone_data.get("road_paths", [])
    if trilhas.is_empty():
        return _ponto_de_mato(rng, false)
    var trilha: Array = trilhas[rng.randi_range(0, trilhas.size() - 1)]
    if trilha.size() < 2:
        return _ponto_de_mato(rng, false)
    var trecho := rng.randi_range(0, trilha.size() - 2)
    var a := Vector2(float(trilha[trecho][0]), float(trilha[trecho][1]))
    var b := Vector2(float(trilha[trecho + 1][0]), float(trilha[trecho + 1][1]))
    var direcao := (b - a).normalized()
    var normal := Vector2(-direcao.y, direcao.x)
    var lado := -1.0 if rng.randi() % 2 == 0 else 1.0
    var p := a.lerp(b, rng.randf()) + normal * lado * rng.randf_range(5.8, 8.6)
    p.x = clampf(p.x, -76.0, 76.0)
    p.y = clampf(p.y, -76.0, 76.0)
    return p


## Onde uma peça de mato pode nascer: no maciço planejado ou solta no campo.
func _ponto_de_mato(rng: RandomNumberGenerator, no_macico: bool) -> Vector2:
    if no_macico:
        return _sortear_ponto_de_floresta(rng, 3.5)
    return Vector2(rng.randf_range(-74.0, 74.0), rng.randf_range(-74.0, 74.0))


## O shader do mato, alimentado pela textura que veio no próprio GLB.
##
## O material importado já traz recorte por limiar e face dupla; o que ele não
## tem é vento nem encolhimento por distância, e é só isso que trocamos.
func _material_do_mato(origem: MeshInstance3D, altura_tipica: float,
        alcance: float) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/mato_pbr.gdshader")
    var importado := origem.mesh.surface_get_material(0)
    if importado is BaseMaterial3D:
        var padrao := importado as BaseMaterial3D
        mat.set_shader_parameter("textura", padrao.albedo_texture)
        mat.set_shader_parameter("corte", maxf(padrao.alpha_scissor_threshold, 0.25))
    mat.set_shader_parameter("altura_mundo", altura_tipica)
    mat.set_shader_parameter("distancia_cheia", alcance * 0.62)
    mat.set_shader_parameter("distancia_nula", alcance)
    return mat


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
        lote.visibility_range_end = 50.0
        lote.visibility_range_end_margin = 5.0
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
            # Concentra as copas no nucleo planejado. Antes o raio inteiro
            # espalhava pouco mais de cem arvores por sete manchas enormes e o
            # resultado ainda parecia campo aberto.
            var raio := float(escolhido[2]) * 0.76 * sqrt(rng.randf())
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


## AS RUAS DA VILA, e nao so as estradas da regiao.
##
## `road_paths` sao as vias que cruzam a regiao; a malha urbana — avenida
## principal, largo, travessas e ruas de bairro — vem da planta da praca e vive
## noutro lugar do arquivo. Tudo que evitava estrada consultava so a primeira
## lista, entao pedra e arbusto podiam nascer no meio da avenida da capital sem
## nada reclamar: a rua estava PINTADA no chao ali, mas nenhum teste sabia dela.
##
## A geometria aqui e a MESMA que `_pintar_as_vias` manda ao shader do chao e
## que a carta do minimapa risca. Se as tres discordassem, o jogador veria rua
## num lugar, entulho noutro e o mapa apontando um terceiro.
func _sobre_a_via_urbana(p: Vector2, folga: float) -> bool:
    var vias: Dictionary = _dados_da_praca().get("vias", {})
    if vias.is_empty():
        return false
    var principal: Array = vias.get("principal", [0.0, 0.0])
    if principal.size() < 2:
        return false
    var meia_rua := float(principal[0])
    if meia_rua < 0.01:
        return false
    if absf(p.x) < meia_rua + folga and absf(p.y) < float(principal[1]) + folga:
        return true
    var raio_do_largo := float(vias.get("largo", 0.0))
    if raio_do_largo > 0.01 and p.length() < raio_do_largo + folga:
        return true
    var travessas: Array = vias.get("travessas", [0.0, 0.0, 0.0])
    if travessas.size() >= 3:
        var meia_t: float = float(principal[1]) if travessas.size() < 2 else float(travessas[1])
        if absf(p.y - float(travessas[0])) < meia_t + folga \
                and absf(p.x) < float(travessas[2]) + folga:
            return true
    var secundarias: Array = vias.get("secundarias", [999.0, 999.0, 0.0, 0.0])
    if secundarias.size() >= 4 and float(secundarias[0]) < 900.0:
        for onde in [float(secundarias[0]), float(secundarias[1])]:
            if absf(p.y - onde) < float(secundarias[2]) + folga \
                    and absf(p.x) < float(secundarias[3]) + folga:
                return true
    return false


## A faixa que precisa ficar limpa para o jogador passar.
##
## Um so lugar respondendo "da para andar aqui?" — estrada da regiao E rua da
## vila. Quem planta qualquer coisa pergunta a esta funcao, e nao a metade dela.
const FOLGA_DA_CIRCULACAO := 2.2

func _bloqueia_circulacao(p: Vector2, folga := FOLGA_DA_CIRCULACAO) -> bool:
    return _perto_da_rede(p, "road_paths", 6.0 + folga) or _sobre_a_via_urbana(p, folga)

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

        # O PONTO PRIMEIRO, O MODELO DEPOIS.
        #
        # Antes o modelo era carregado e montado e so entao se olhava onde ele
        # tinha caido; se fosse na agua, ia para o lixo inteiro. Pior: NINGUEM
        # olhava se tinha caido na rua. Este sorteio nao consultava estrada nem
        # via urbana, entao pedra e arbusto nasciam no meio do caminho — e a
        # regra da casa e que rota de circulacao fica limpa.
        #
        # Oito tentativas: com o mapa cheio de mata e so as faixas de rua
        # proibidas, a primeira ou a segunda quase sempre serve, e desistir do
        # adorno e melhor que planta-lo em cima da estrada.
        var px := 0.0
        var pz := 0.0
        var py := 0.0
        var achou := false
        for _tentativa in 8:
            var ang: float = rng.randf_range(0.0, TAU)
            var dist: float = rng.randf_range(dist_min, raio_max)
            px = cos(ang) * dist
            pz = sin(ang) * dist
            if _bloqueia_circulacao(Vector2(px, pz)):
                continue
            # Enterra o tronco/raízes no terreno para não ficarem flutuando
            py = calcular_altura(px, pz) - (enterrar * escala_extra)
            if tem_agua and py < water_y + 0.5:
                continue
            achou = true
            break
        if not achou:
            continue

        var suporte := _instanciar_prop_3d(path, tag, alt_base, escala_extra)
        if not suporte:
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
            borda.append(Vector3(pos_along, calcular_altura(pos_along, -half), -half))
        # Sul
        if exits.get("south", "") == "" or (not so_o_fim_do_mundo and abs(pos_along) > portal_gap):
            borda.append(Vector3(pos_along, calcular_altura(pos_along, half), half))
        # Oeste
        if exits.get("west", "") == "" or (not so_o_fim_do_mundo and abs(pos_along) > portal_gap):
            borda.append(Vector3(-half, calcular_altura(-half, pos_along), pos_along))
        # Leste
        if exits.get("east", "") == "" or (not so_o_fim_do_mundo and abs(pos_along) > portal_gap):
            borda.append(Vector3(half, calcular_altura(half, pos_along), pos_along))
    _plantar_arvores_cc0_em_lotes(borda, hash(str(_zone_data.get("id", "borda"))) + 991)

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
        _aquecer_proximo_recurso()
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
    # O coordenador também precisa conhecer as plantas: o minimapa consulta
    # esta instância, não as cópias regionais. Aproveitamos a mesma leitura para
    # iniciar o carregamento assíncrono dos modelos antes de eles entrarem na tela.
    carregar_dados()
    _preparar_fila_de_recursos()

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


## Lê malhas e texturas em segundo plano enquanto o jogador ainda explora a
## primeira floresta. Quando a cidade entra no alcance, load() encontra tudo no
## cache e não congela o quadro na primeira casa, banca ou carroça.
func _preparar_fila_de_recursos() -> void:
    _fila_de_recursos.clear()
    var vistos := {}
    var layouts: Dictionary = _city_layouts.get("layouts", {})
    var prioridade := ["vila_caminho_v2", "acordelot_centro_v2",
        "mercado_caminho_v2", "arredores_v2"]
    for id in prioridade:
        for item in layouts.get(id, []):
            var caminho := str(item.get("model", ""))
            if caminho == "" or vistos.has(caminho) or not ResourceLoader.exists(caminho):
                continue
            if not _tem_textura(caminho):
                continue
            vistos[caminho] = true
            if not ResourceLoader.has_cached(caminho):
                _fila_de_recursos.append(caminho)
    for arvore in ARVORES_CC0:
        var caminho := str(arvore.get("path", ""))
        if caminho != "" and not vistos.has(caminho) and ResourceLoader.exists(caminho):
            vistos[caminho] = true
            if not ResourceLoader.has_cached(caminho):
                _fila_de_recursos.append(caminho)


func _aquecer_proximo_recurso() -> void:
    if _recurso_em_carga == "":
        while not _fila_de_recursos.is_empty():
            var caminho: String = _fila_de_recursos.pop_front()
            if ResourceLoader.has_cached(caminho):
                continue
            if ResourceLoader.load_threaded_request(caminho, "", true) == OK:
                _recurso_em_carga = caminho
            break
        return

    var progresso := []
    var estado := ResourceLoader.load_threaded_get_status(_recurso_em_carga, progresso)
    if estado == ResourceLoader.THREAD_LOAD_LOADED:
        _recursos_aquecidos[_recurso_em_carga] = ResourceLoader.load_threaded_get(_recurso_em_carga)
        _recurso_em_carga = ""
    elif estado in [ResourceLoader.THREAD_LOAD_FAILED,
            ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
        _recurso_em_carga = ""


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
