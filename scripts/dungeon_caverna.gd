extends Node3D

## Primeira DG: planta expansiva, corredores longos e laje visual contínua.
## Vive longe do mapa aberto e só é ativada quando o jogador entra.
const BICHO := preload("res://scripts/bicho.gd")
const BAU := preload("res://scripts/bau_dungeon.gd")

# Do kit da caverna sobram os dois arcos: eles marcam a passagem entre estagios.
# Sala, corredor, juncao, curva e fundo de saco sairam junto com a planta antiga
# — eram tubos fechados com teto, que e o que fazia o heroi sumir atras deles.
const PORTAO := preload("res://models/cc0/cave/gate.glb")
const PORTA := preload("res://models/cc0/cave/gate-metal-bars.glb")

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
## O centro da camara de entrada da planta nova.
const ENTRADA := Vector3(0.0, 1.15, 84.0)

var _jogador: CharacterBody3D
var _zona: Node3D
var _ceu_do_mundo: Node3D
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


## A DG, REFEITA DO ZERO — SEM O KIT MODULAR.
##
## DUAS QUEIXAS, UMA CAUSA. Os modulos da caverna sao TUBOS FECHADOS: paredes dos
## dois lados e TETO. O corredor tinha 4,1 m de vao livre medidos na malha, e a
## camera olha de cima e de tras — entao a parede do lado de ca e o teto ficavam
## entre o olho e o heroi, e ele sumia. Nao era bug de codigo: era o formato das
## pecas contra o angulo da camera. Nenhum ajuste de posicao consertava isso.
##
## Aqui a planta e uma lista de RETANGULOS — salas e corredores — e a geometria
## nasce deles:
##
## 1. NAO HA TETO. Nenhum. A caverna se le pelo chao, pelas paredes do fundo e
##    pelo escuro em volta.
## 2. AS PAREDES SAO DE FACE UNICA, VIRADA PARA DENTRO. E o truque que resolve o
##    sumico: a parede do lado da camera tem a normal apontando para longe dela e
##    o proprio recorte de face a descarta; a do fundo aparece inteira. O jogador
##    ve a sala como uma caixa aberta, e nunca ha parede na frente dele. A
##    colisao continua nos quatro lados, invisivel.
## 3. ONDE DOIS RETANGULOS SE ENCOSTAM, NAO NASCE PAREDE. A abertura sai da
##    propria planta, sem porta desenhada a mao e sem vao que nao fecha.
## 4. CORREDOR DE 12 M, contra os 4,1 de antes.

const ALTURA_DA_PAREDE := 6.0
const ESPESSURA_DA_PAREDE := 1.4
const SOBREPOSICAO_DO_CHAO := 1.8
## Passo com que a borda de um retangulo e percorrida ao levantar parede. Menor
## que a largura do corredor, para uma abertura nunca sair mais larga que o vao.
const PASSO_DA_PAREDE := 2.0

var _material_parede: StandardMaterial3D
var _plano: Array = []
var _planta_minimapa: Array[Rect2] = []
var _ultimo_ponto_seguro := Vector3.ZERO
var _recuperacoes_no_teste := 0


## Um retangulo da planta: centro (x, z) e tamanho (largura, comprimento).
func _sala(x: float, z: float, largura: float, comprimento: float) -> Rect2:
    var r := Rect2(x - largura * 0.5, z - comprimento * 0.5, largura, comprimento)
    _plano.append(r)
    return r


## Guarda a planta completa em coordenadas locais da DG. O segundo estagio usa
## um deslocamento proprio, por isso nao bastava entregar `_plano` ao radar.
func _registrar_plano_no_mapa(desloc: Vector3) -> void:
    for item in _plano:
        var r: Rect2 = item
        _planta_minimapa.append(Rect2(
            r.position + Vector2(desloc.x, desloc.z), r.size))


func _construir_dungeon() -> void:
    _dungeon = Node3D.new()
    _dungeon.name = "CavernaDaPrimeiraRessonancia"
    _dungeon.position = ORIGEM
    _dungeon.visible = false
    _dungeon.process_mode = Node.PROCESS_MODE_DISABLED
    add_child(_dungeon)
    _plano.clear()
    _planta_minimapa.clear()

    # ---------------------------------------------------------- ESTAGIO 1
    # Norte (z alto) para sul: entrada, primeiro encontro, salao com duas alas
    # de tesouro, e a arena do chefe. Cada retangulo encosta no seguinte.
    var entrada := _sala(0, 84, 24, 24)          # z  72 ..  96
    _sala(0, 60, 12, 24)                          # z  48 ..  72   corredor
    var sala_a := _sala(0, 32, 32, 32)           # z  16 ..  48
    _sala(0, 4, 12, 24)                           # z  -8 ..  16   corredor
    var salao_b := _sala(0, -28, 44, 40)         # z -48 ..  -8
    _sala(34, -28, 24, 12)                        # ala leste, corredor
    var ala_leste := _sala(60, -28, 28, 28)
    _sala(-34, -28, 24, 12)                       # ala oeste, corredor
    var ala_oeste := _sala(-60, -28, 28, 28)
    _sala(0, -62, 12, 28)                         # z -76 .. -48   corredor
    var arena := _sala(0, -100, 48, 48)          # z -124 .. -76

    _registrar_plano_no_mapa(Vector3.ZERO)
    _erguer_o_plano(Vector3.ZERO)
    _vazio_preto()

    _acender(entrada, 1)
    _acender(sala_a, 2)
    _acender(salao_b, 3)
    _acender(ala_leste, 1)
    _acender(ala_oeste, 1)
    _acender(arena, 3)
    _acender_corredor(Vector3(0, 0, 60), 12.0)
    _acender_corredor(Vector3(0, 0, 4), 12.0)
    _acender_corredor(Vector3(0, 0, -62), 12.0)
    _acender_corredor(Vector3(34, 0, -28), 12.0, true)
    _acender_corredor(Vector3(-34, 0, -28), 12.0, true)

    _enfeitar(sala_a, [Color(0.6, 0.4, 1.0), Color(0.4, 0.7, 1.0)])
    _enfeitar(salao_b, [Color(0.8, 0.4, 1.0), Color(0.4, 0.8, 1.0)])
    _enfeitar(ala_leste, [Color(0.4, 0.9, 1.0)])
    _enfeitar(ala_oeste, [Color(1.0, 0.5, 0.8)])
    _enfeitar(arena, [Color(1.0, 0.4, 0.7), Color(0.4, 0.7, 1.0)])

    _bau(Vector3(60.0, 0.0, -22.0), 350, true)
    _bau(Vector3(-60.0, 0.0, -22.0), 350, true)
    _bau(Vector3(0.0, 0.0, -116.0), 600, true)

    # MONSTROS. Nenhum em corredor — corredor e passagem, sala e onde se briga.
    for onde in [Vector3(-9, 1.1, 40), Vector3(9, 1.1, 30), Vector3(-6, 1.1, 22)]:
        _ninho(onde, 0, 3, 4.5)
    for g in [[Vector3(-14, 1.1, -16), 1], [Vector3(14, 1.1, -14), 0],
              [Vector3(-15, 1.1, -40), 3], [Vector3(0, 1.1, -42), 1],
              [Vector3(15, 1.1, -38), 3]]:
        _ninho(g[0], int(g[1]), 4, 5.5)
    _ninho(Vector3(60, 1.1, -34), 3, 4, 5.0)
    _ninho(Vector3(-60, 1.1, -34), 3, 4, 5.0)
    _ninho(Vector3(-16, 1.1, -88), 3, 4, 5.0)
    _ninho(Vector3(16, 1.1, -88), 3, 4, 5.0)
    _ninho(Vector3(-13, 1.1, -106), 1, 3, 4.0)
    _ninho(Vector3(13, 1.1, -106), 1, 3, 4.0)
    var chefe := _shiker(Vector3(0.0, 1.1, -106.0), 2)
    chefe.call_deferred("tornar_super_shiker")

    _construir_segundo_estagio()


## O SEGUNDO ESTAGIO, com o maior salao do jogo.
const ESTAGIO_2 := Vector3(0.0, 0.0, -260.0)
## Antes era -196: dois metros FORA da antessala, cujo limite e -198. O heroi
## aparecia sobre o vazio preto e podia cair antes do primeiro quadro de fisica.
const ENTRADA_ESTAGIO_2 := Vector3(0.0, 1.15, -216.0)

func _construir_segundo_estagio() -> void:
    var o := ESTAGIO_2
    _plano.clear()

    var antessala := _sala(0, 48, 28, 28)         # z  34 ..  62
    _sala(0, 22, 12, 24)                          # z  10 ..  34
    var salao_c := _sala(0, -14, 48, 48)          # z -38 ..  10
    _sala(-38, -14, 28, 12)                       # cripta oeste, corredor
    var cripta := _sala(-66, -14, 28, 28)
    _sala(-94, -14, 28, 12)
    var cripta_funda := _sala(-122, -14, 28, 28)
    _sala(0, -52, 12, 28)                         # z -66 .. -38
    var santuario := _sala(0, -92, 52, 52)        # z -118 .. -66

    _registrar_plano_no_mapa(o)
    _erguer_o_plano(o)
    _acender(antessala, 2, o)
    _acender(salao_c, 3, o)
    _acender(cripta, 1, o)
    _acender(cripta_funda, 1, o)
    _acender(santuario, 3, o)
    _acender_corredor(o + Vector3(0, 0, 22), 12.0)
    _acender_corredor(o + Vector3(0, 0, -52), 12.0)
    _acender_corredor(o + Vector3(-38, 0, -14), 12.0, true)
    _acender_corredor(o + Vector3(-94, 0, -14), 12.0, true)

    _enfeitar(antessala, [Color(0.5, 0.8, 1.0)], o)
    _enfeitar(salao_c, [Color(0.4, 0.9, 0.8), Color(1.0, 0.6, 0.3)], o)
    _enfeitar(cripta, [Color(1.0, 0.3, 0.9)], o)
    _enfeitar(cripta_funda, [Color(1.0, 0.8, 0.4)], o)
    _enfeitar(santuario, [Color(1.0, 0.8, 0.4), Color(0.4, 0.9, 1.0)], o)

    _bau(o + Vector3(-66.0, 0.0, -8.0), 500, true)
    _bau(o + Vector3(-122.0, 0.0, -14.0), 750, true)
    _bau(o + Vector3(18.0, 0.0, -30.0), 500, true)
    # O tesouro do fundo: e ele que registra a incursao como concluida.
    _bau(o + Vector3(0.0, 0.0, -110.0), 1000, true, true)

    _ninho(o + Vector3(-8, 1.1, 52), 4, 4, 5.0)
    _ninho(o + Vector3(8, 1.1, 42), 4, 4, 5.0)
    for g in [[Vector3(-16, 1.1, -4), 4], [Vector3(0, 1.1, -22), 2],
              [Vector3(16, 1.1, -2), 2], [Vector3(16, 1.1, -28), 4]]:
        _ninho(o + g[0], int(g[1]), 4, 5.5)
    _ninho(o + Vector3(-66, 1.1, -20), 5, 3, 5.0)
    _ninho(o + Vector3(-122, 1.1, -8), 4, 4, 5.0)
    _ninho(o + Vector3(-122, 1.1, -20), 5, 3, 5.0)
    _ninho(o + Vector3(-18, 1.1, -80), 4, 4, 5.0)
    _shiker(o + Vector3(18, 1.1, -80), 4)
    _shiker(o + Vector3(-14, 1.1, -98), 4)
    _shiker(o + Vector3(14, 1.1, -98), 4)
    var guardiao := _shiker(o + Vector3(0.0, 1.1, -98.0), 5)
    guardiao.call_deferred("tornar_super_shiker")

    _porta_de_estagio(Vector3(0.0, 0.0, -118.0), ORIGEM + ENTRADA_ESTAGIO_2,
        "DESCER AO SEGUNDO ESTAGIO")
    _porta_de_estagio(o + Vector3(0.0, 0.0, 56.0), ORIGEM + Vector3(0.0, 1.15, -118.0),
        "VOLTAR AO PRIMEIRO ESTAGIO")


# ---------------------------------------------------------------------------
# A GEOMETRIA, TIRADA DA PLANTA
# ---------------------------------------------------------------------------

## Chao, paredes e colisao de todos os retangulos da planta.
func _erguer_o_plano(desloc: Vector3) -> void:
    for r in _plano:
        _chao_do_retangulo(r, desloc)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for r in _plano:
        _paredes_do_retangulo(r, desloc, st)
    var malha := st.commit()
    if malha == null or malha.get_surface_count() == 0:
        return
    var paredes := MeshInstance3D.new()
    paredes.name = "ParedesDaCaverna"
    paredes.mesh = malha
    paredes.material_override = _material_da_parede()
    paredes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _dungeon.add_child(paredes)


## Uma laje por retangulo, um pouco maior que ele para as emendas nao abrirem
## fresta na diagonal entre duas salas vizinhas.
func _chao_do_retangulo(r: Rect2, desloc: Vector3) -> void:
    var centro := desloc + Vector3(r.position.x + r.size.x * 0.5, -0.25,
        r.position.y + r.size.y * 0.5)
    # A sobreposicao fecha as emendas entre salas e corredores. As lajes usam a
    # mesma altura e material, entao ela e invisivel e evita frestas na colisao
    # do navegador.
    var tamanho := Vector3(r.size.x + SOBREPOSICAO_DO_CHAO, 0.5,
        r.size.y + SOBREPOSICAO_DO_CHAO)

    var corpo := StaticBody3D.new()
    corpo.position = centro
    var colisao := CollisionShape3D.new()
    var forma := BoxShape3D.new()
    forma.size = tamanho
    colisao.shape = forma
    corpo.add_child(colisao)
    _dungeon.add_child(corpo)

    var visual := MeshInstance3D.new()
    var caixa := BoxMesh.new()
    caixa.size = tamanho
    visual.mesh = caixa
    visual.material_override = _material_da_rocha()
    visual.position = centro
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _dungeon.add_child(visual)


## Percorre a borda do retangulo e levanta parede onde nao ha vizinho.
##
## EM TRECHOS, NAO EM PEDACOS. A primeira versao emitia um corpo, uma forma e uma
## malha a cada dois metros: cinco mil nos e 345 chamadas de desenho para uma
## caverna. Agora os passos vizinhos que sao parede viram UM trecho — uma caixa
## de colisao e um retangulo de face — e todas as faces do estagio entram numa
## malha unica, que e uma chamada de desenho para a caverna inteira.
func _paredes_do_retangulo(r: Rect2, desloc: Vector3, st: SurfaceTool) -> void:
    var lados := [
        [Vector2(0.0, -1.0), r.position.y, true],                    # norte (-z)
        [Vector2(0.0, 1.0), r.position.y + r.size.y, true],          # sul (+z)
        [Vector2(-1.0, 0.0), r.position.x, false],                   # oeste (-x)
        [Vector2(1.0, 0.0), r.position.x + r.size.x, false],         # leste (+x)
    ]
    for lado in lados:
        var fora: Vector2 = lado[0]
        var linha: float = lado[1]
        var ao_longo_de_x: bool = lado[2]
        var comeco: float = r.position.x if ao_longo_de_x else r.position.y
        var fim: float = comeco + (r.size.x if ao_longo_de_x else r.size.y)
        var inicio_do_trecho := -1.0
        var t := comeco
        while t < fim + 0.01:
            var acabou: bool = t >= fim - 0.01
            var meio: float = t + PASSO_DA_PAREDE * 0.5
            var ponto := Vector2(meio, linha) if ao_longo_de_x else Vector2(linha, meio)
            var tem_parede: bool = (not acabou) and not _dentro_do_plano(
                ponto + fora * (PASSO_DA_PAREDE * 0.6), r)
            if tem_parede and inicio_do_trecho < 0.0:
                inicio_do_trecho = t
            elif not tem_parede and inicio_do_trecho >= 0.0:
                _erguer_parede(inicio_do_trecho, minf(t, fim), linha, fora,
                    ao_longo_de_x, desloc, st)
                inicio_do_trecho = -1.0
            t += PASSO_DA_PAREDE


func _dentro_do_plano(p: Vector2, menos: Rect2) -> bool:
    for r in _plano:
        if r == menos:
            continue
        if r.has_point(p):
            return true
    return false


## Um trecho de parede: colisao solida e UMA face virada para dentro.
func _erguer_parede(de: float, ate: float, linha: float, fora: Vector2,
        ao_longo_de_x: bool, desloc: Vector3, st: SurfaceTool) -> void:
    var largura: float = ate - de
    if largura < 0.05:
        return
    var meio: float = (de + ate) * 0.5
    var ponto := Vector2(meio, linha) if ao_longo_de_x else Vector2(linha, meio)
    var centro := desloc + Vector3(ponto.x, ALTURA_DA_PAREDE * 0.5, ponto.y)
    var meia := Vector3(fora.x, 0.0, fora.y) * (ESPESSURA_DA_PAREDE * 0.5)

    var corpo := StaticBody3D.new()
    corpo.position = centro + meia
    var colisao := CollisionShape3D.new()
    var forma := BoxShape3D.new()
    forma.size = Vector3(largura, ALTURA_DA_PAREDE, ESPESSURA_DA_PAREDE) \
        if ao_longo_de_x else Vector3(ESPESSURA_DA_PAREDE, ALTURA_DA_PAREDE, largura)
    colisao.shape = forma
    corpo.add_child(colisao)
    _dungeon.add_child(corpo)

    # A FACE, escrita direto na malha do estagio. Normal para DENTRO: vista de
    # fora — que e onde a camera fica quando a parede esta entre ela e o heroi —
    # ela simplesmente nao e desenhada.
    var para_dentro := Vector3(-fora.x, 0.0, -fora.y)
    var ao_lado := Vector3(fora.y, 0.0, -fora.x) * (largura * 0.5)
    var alto := Vector3.UP * ALTURA_DA_PAREDE
    var base := centro - Vector3(0.0, ALTURA_DA_PAREDE * 0.5, 0.0)
    var a := base - ao_lado
    var b := base + ao_lado
    var c := b + alto
    var d := a + alto
    var repete: float = largura / 4.0
    _face(st, a, b, c, d, para_dentro, repete)


func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
        normal: Vector3, repete: float) -> void:
    for v in [[a, Vector2(0.0, 1.0)], [b, Vector2(repete, 1.0)], [c, Vector2(repete, 0.0)],
              [a, Vector2(0.0, 1.0)], [c, Vector2(repete, 0.0)], [d, Vector2(0.0, 0.0)]]:
        st.set_normal(normal)
        st.set_uv(v[1])
        st.add_vertex(v[0])


## Rocha de parede: a mesma pedra do chao, mas de face unica. O recorte de face
## nao pode ser desligado aqui — e ele que faz a parede da frente sumir.
func _material_da_parede() -> StandardMaterial3D:
    if _material_parede != null:
        return _material_parede
    _material_parede = StandardMaterial3D.new()
    _material_parede.albedo_texture = TEXTURA_ROCHA
    # Mesma correcao do chao, um tom acima: a parede e o que da a leitura da
    # sala e precisa se destacar do piso.
    _material_parede.albedo_color = Color(0.50, 0.51, 1.0)
    _material_parede.roughness = 0.96
    _material_parede.uv1_scale = Vector3(0.5, 0.5, 0.5)
    _material_parede.uv1_triplanar = true
    _material_parede.cull_mode = BaseMaterial3D.CULL_BACK
    _material_parede.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return _material_parede


const RECUO_DA_TOCHA := 0.16
const RECUO_DO_PROP := 2.0


## Coloca a tocha na face real da parede. Se naquele ponto houver outro
## retangulo da planta, existe uma porta/corredor e a tocha nao e criada.
func _tocha_na_parede(face: Vector3, fora: Vector2, dona: Rect2,
        desloc: Vector3, giro: float) -> void:
    if _dentro_do_plano(Vector2(face.x, face.z) + fora * 1.05, dona):
        return
    var para_dentro := Vector3(-fora.x, 0.0, -fora.y)
    _tocha(desloc + face + para_dentro * RECUO_DA_TOCHA, giro)


## Tochas nas paredes de uma sala, tantas por lado.
func _acender(r: Rect2, por_lado: int, desloc := Vector3.ZERO) -> void:
    var x0: float = r.position.x
    var z0: float = r.position.y
    for i in por_lado:
        var f: float = (float(i) + 1.0) / (float(por_lado) + 1.0)
        _tocha_na_parede(Vector3(x0 + r.size.x * f, 0.0, z0),
            Vector2(0.0, -1.0), r, desloc, 0.0)
        _tocha_na_parede(Vector3(x0 + r.size.x * f, 0.0, z0 + r.size.y),
            Vector2(0.0, 1.0), r, desloc, PI)
        _tocha_na_parede(Vector3(x0, 0.0, z0 + r.size.y * f),
            Vector2(-1.0, 0.0), r, desloc, -PI * 0.5)
        _tocha_na_parede(Vector3(x0 + r.size.x, 0.0, z0 + r.size.y * f),
            Vector2(1.0, 0.0), r, desloc, PI * 0.5)


func _acender_corredor(onde: Vector3, vao: float, deitado := false) -> void:
    if deitado:
        _tocha(onde + Vector3(0.0, 0.0, -vao * 0.5 + RECUO_DA_TOCHA), -PI * 0.5)
        _tocha(onde + Vector3(0.0, 0.0, vao * 0.5 - RECUO_DA_TOCHA), PI * 0.5)
    else:
        _tocha(onde + Vector3(-vao * 0.5 + RECUO_DA_TOCHA, 0.0, 0.0), 0.0)
        _tocha(onde + Vector3(vao * 0.5 - RECUO_DA_TOCHA, 0.0, 0.0), PI)


## Cristal e provisoes encostados na parede, longe do meio — que e onde o
## jogador anda e onde o bicho nasce.
func _enfeitar(r: Rect2, cores: Array, desloc := Vector3.ZERO) -> void:
    var cantos := [
        Vector2(r.position.x + RECUO_DO_PROP, r.position.y + RECUO_DO_PROP),
        Vector2(r.end.x - RECUO_DO_PROP, r.position.y + RECUO_DO_PROP),
        Vector2(r.position.x + RECUO_DO_PROP, r.end.y - RECUO_DO_PROP),
        Vector2(r.end.x - RECUO_DO_PROP, r.end.y - RECUO_DO_PROP),
    ]
    for i in cantos.size():
        var c: Vector2 = cantos[i]
        var onde := desloc + Vector3(c.x, 0.0, c.y)
        if i % 2 == 0:
            _cristal(onde, float(i) * 1.3, 1.1 + float(i % 3) * 0.2,
                cores[i % cores.size()])
        else:
            _pilha_provisoes(onde, float(i) * 0.9)
    _prop(CAVEIRA_MESH, desloc + Vector3(r.position.x + RECUO_DO_PROP + 1.2,
        0.04, r.end.y - 1.1), 0.4, 1.3)






func _porta_de_estagio(onde: Vector3, destino: Vector3, rotulo: String) -> void:
    _modulo(PORTA, onde)

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
    # A TINTA CORRIGE A TEXTURA, que nao e cinza. Medida, `rocha_caverna_1k.jpg`
    # tem media R=80 G=78 B=28: uma pedra OLIVA. Multiplicada por um cinza
    # azulado ela continuava esverdeada, e o chao da caverna parecia gramado —
    # era essa a queixa de "a DG esta ruim" tanto quanto os corredores.
    #
    # Levantar so o azul devolve o cinza: 0,40 x 80, 0,41 x 78 e 1,0 x 28 dao
    # tres numeros quase iguais. Fica mais escuro, e a luz da caverna compensa.
    _material_rocha.albedo_color = Color(0.42, 0.43, 1.0)
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


## UM NINHO NO LUGAR DE UM BICHO SOLTO.
##
## A caverna tinha um monstro por marca — quinze no mapa inteiro. Numa sala de
## vinte metros isso e um bicho a cada tanto, e o jogador atravessa a briga sem
## nunca estar cercado. O ninho espalha companheiros em volta da marca e SO
## aceita ponto que esteja sobre o piso da sala, entao ninguem nasce dentro da
## pedra nem no corredor.
func _ninho(centro: Vector3, tipo: int, quantos := 3, raio := 5.0) -> void:
    _shiker(centro, tipo)
    var voltas := 0
    var postos := 0
    while postos < quantos - 1 and voltas < quantos * 8:
        voltas += 1
        var angulo: float = TAU * float(voltas) / 7.0 + randf() * 0.9
        var d: float = raio * (0.45 + randf() * 0.55)
        var ponto := centro + Vector3(cos(angulo) * d, 0.0, sin(angulo) * d)
        if not _sobre_piso_da_dg(ponto, 1.2):
            continue
        _shiker(ponto, tipo)
        postos += 1


func _shiker(onde: Vector3, tipo: int) -> Node3D:
    var inimigo := BICHO.new()
    inimigo.position = onde
    inimigo.monster_type = tipo
    # DENTRO DA CAVERNA ELE ENXERGA MAIS LONGE.
    #
    # No campo aberto o jogador ve o bicho de longe e escolhe a briga. No
    # corredor ele so aparece na curva, e com o raio do campo aberto era preciso
    # encostar nele para acordar — o combate da DG virava uma sequencia de
    # sustos em cima do proprio corpo. O corredor tem parede: ver mais longe
    # aqui e ver ate a esquina, nao ver o mapa inteiro.
    inimigo.raio_de_atencao = 19.0
    _dungeon.add_child(inimigo)
    _inimigos.append(inimigo)
    inimigo.process_mode = Node.PROCESS_MODE_DISABLED
    return inimigo


func _sobre_piso_da_dg(local: Vector3, margem := 0.55) -> bool:
    var ponto := Vector2(local.x, local.z)
    for r in _planta_minimapa:
        var area: Rect2 = r.grow(-margem)
        if area.size.x > 0.0 and area.size.y > 0.0 and area.has_point(ponto):
            return true
    return false


func _dentro_da_planta_da_dg(local: Vector3) -> bool:
    var ponto := Vector2(local.x, local.z)
    for r in _planta_minimapa:
        if r.grow(0.9).has_point(ponto):
            return true
    return false


## Ultima rede de seguranca. A geometria foi selada, mas se uma fisica web
## atravessar uma emenda o jogador volta ao ultimo piso valido, em vez de cair
## indefinidamente no vazio.
func _proteger_contra_queda() -> void:
    var local := _jogador.global_position - ORIGEM
    if local.y < -1.8 or not _dentro_da_planta_da_dg(local):
        if OS.get_cmdline_user_args().has("--parede") and _recuperacoes_no_teste < 3:
            print("DG recuperou jogador fora da planta em ", local,
                " para ", _ultimo_ponto_seguro - ORIGEM)
        _recuperacoes_no_teste += 1
        _jogador.global_position = _ultimo_ponto_seguro
        _jogador.velocity = Vector3.ZERO
        return
    if local.y < 2.6 and _sobre_piso_da_dg(local):
        _ultimo_ponto_seguro = Vector3(_jogador.global_position.x,
            ORIGEM.y + 1.15, _jogador.global_position.z)


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


func _physics_process(_delta: float) -> void:
    if _dentro and _jogador:
        _proteger_contra_queda()


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
## A CAVERNA MEDE QUEM ENTRA.
##
## A tabela era fixa: numeros escritos para o comeco do jogo, multiplicados por
## uma constante. O heroi cresce sem teto — nivel, atributo, Eco, talento — e a
## caverna ficava parada, ate virar hitkill. Agora o multiplicador nasce do
## PODER DE LUTA no momento de entrar, e estes tres valores sao so o quanto
## acima ou abaixo do seu proprio nivel voce quer brigar.
## [nome, peso, espolio, nivel recomendado, poder recomendado, descricao]
const DIFICULDADES := [
    ["SERENA", 0.70, 1.0, 1, 700, "Abaixo do seu poder. Para conhecer a caverna."],
    ["DISSONANTE", 1.0, 1.5, 8, 2000, "Na medida do seu poder. Recompensa cheia."],
    ["CACOFONIA", 1.55, 2.4, 15, 4200, "Acima do seu poder. Espólio dobrado."],
]

## O QUE A CAVERNA QUER DE CADA BICHO, por tipo de monstro.
##
## `GOLPES` e quantos golpes do heroi ele deve aguentar; `SEGUNDOS` e em quanto
## tempo ele derrubaria o heroi sozinho, coladinho, sem ninguem se mexer. Os dois
## sao lidos com o ataque, a vida e a DEFESA reais de quem esta entrando, entao
## a briga tem o mesmo peso no nivel 5 e no 50 — que era o pedido.
##
## O Colosso derruba em quinze segundos: com tres deles numa sala, ficar parado
## e morte em cinco. E ai que entra desviar e escolher quem cai primeiro.
## Subiram os dois. Matar tudo em dois ou tres golpes tirava qualquer decisao da
## briga, e o tempo para ser derrubado era longo demais para exigir desvio. A
## vida sobe menos que o dano de proposito: o objetivo e briga perigosa, nao
## briga demorada.
const GOLPES := [4, 6, 9, 7, 10, 14]
const SEGUNDOS := [32.0, 26.0, 18.0, 22.0, 15.0, 10.0]
## Quanto tempo passa entre dois golpes de um bicho, medido: animacao + pausa.
const CADENCIA := 2.4

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
func _milhar_dg(valor: int) -> String:
    var texto := str(valor)
    var saida := ""
    var conta := 0
    for k in range(texto.length() - 1, -1, -1):
        saida = texto[k] + saida
        conta += 1
        if conta % 3 == 0 and k > 0:
            saida = "." + saida
    return saida


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
    # O cartao mostra o que a caverna vai VALER para este heroi, e nao a
    # constante da tabela: e a diferenca entre "×1,45" e "vida ×3,1  dano ×5,2".
    # O CARTAO DIZ SO O QUE ORIENTA A ESCOLHA.
    #
    # Ele chegou a mostrar quantos golpes um Shiker aguenta e em quantos
    # segundos um Colosso derruba: numero de balanceamento, que e trabalho meu e
    # nao do jogador. O que ajuda a decidir "eu aguento esta?" e o nivel e o
    # poder recomendados — e o proprio poder de agora, ao lado, para comparar.
    var prog_cartao := get_node_or_null("/root/Progresso")
    var meu := 0
    if prog_cartao and prog_cartao.has_method("poder_de_luta_detalhado"):
        meu = int(prog_cartao.poder_de_luta_detalhado()["total"])
    numeros.text = "poder %s+   ·   o seu: %s" % [_milhar_dg(int(d[4])), _milhar_dg(meu)]
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


## O que um bicho deste tipo deve valer para o heroi que esta entrando.
## Devolve [vida, dano por golpe ja considerando a defesa dele].
func alvos_do_bicho(tipo: int, qual := -1) -> Array:
    var tier: float = float(DIFICULDADES[qual if qual >= 0 else _dificuldade][1])
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null or not progresso.has_method("estatisticas"):
        return [200.0, 20.0]
    var e: Dictionary = progresso.estatisticas()
    var ataque: float = maxf(float(e.get("ataque", 50)), 1.0)
    var vida_heroi: float = maxf(float(e.get("vida_maxima", 300)), 1.0)
    var defesa: float = maxf(float(e.get("defesa", 0)), 0.0)
    var i: int = clampi(tipo, 0, GOLPES.size() - 1)

    var vida: float = ataque * float(GOLPES[i]) * tier
    # O dano e calculado ANTES da defesa cortar: o alvo e o que o jogador vai
    # sentir, nao o numero cru. Sem isto, defesa alta zerava a ameaca.
    var passa: float = 100.0 / (100.0 + defesa)
    var por_segundo: float = vida_heroi / (SEGUNDOS[i] / tier)
    var dano: float = por_segundo * CADENCIA / maxf(passa, 0.05)
    return [vida, dano]


func _aplicar_dificuldade() -> void:
    for inimigo in _inimigos:
        if not is_instance_valid(inimigo):
            continue
        if inimigo.has_method("calibrar"):
            var alvo := alvos_do_bicho(int(inimigo.monster_type))
            inimigo.calibrar(float(alvo[0]), float(alvo[1]))


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
    var trilha_dg := get_node_or_null("/root/Trilha")
    if trilha_dg:
        trilha_dg.definir_clima("caverna")
    if _jogador == null:
        return
    _posicao_de_retorno = _jogador.global_position
    _dentro = true
    # A caverna tem chao proprio e nao segue o relevo do mundo aberto: com a
    # garantia ligada, o heroi seria puxado para a superficie assim que descesse.
    _jogador.chao_garantido = false
    _dungeon.visible = true
    _dungeon.process_mode = Node.PROCESS_MODE_INHERIT
    if _zona:
        _zona.visible = false
        _zona.process_mode = Node.PROCESS_MODE_DISABLED
    if _sol:
        _sol.visible = false
    # O CEU E GEOMETRIA, nao fundo. Nuvem, estrela e lua sao malhas que seguem a
    # camera: o fundo preto do ambiente da caverna nao as apaga, e ficava uma
    # nuvem passando no alto da masmorra. Some junto com o resto do mundo.
    if _ceu_do_mundo == null:
        _ceu_do_mundo = get_parent().get_node_or_null("CeuVivoCompatibilidade") as Node3D
    if _ceu_do_mundo:
        _ceu_do_mundo.visible = false
    if _minimapa:
        _minimapa.visible = true
        if _minimapa.has_method("entrar_modo_dungeon"):
            _minimapa.call("entrar_modo_dungeon", _planta_minimapa, ORIGEM,
                "Caverna da Primeira Ressonancia")
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
    _ultimo_ponto_seguro = ORIGEM + destino
    _jogador.velocity = Vector3.ZERO
    _botao.text = "SAIR\nDA DG"
    _aplicar_dificuldade()
    _shikers_totais = maxi(_shikers_totais, _contar_shikers())
    if _placar:
        _placar.visible = true
    _atualizar_placar()


func _sair() -> void:
    var trilha_fora := get_node_or_null("/root/Trilha")
    if trilha_fora:
        trilha_fora.definir_clima("mundo")
    _dentro = false
    _jogador.chao_garantido = true
    _jogador.global_position = _posicao_de_retorno + Vector3.UP * 0.4
    _jogador.velocity = Vector3.ZERO
    _dungeon.visible = false
    _dungeon.process_mode = Node.PROCESS_MODE_DISABLED
    if _zona:
        _zona.visible = true
        _zona.process_mode = Node.PROCESS_MODE_INHERIT
    if _sol:
        _sol.visible = true
    if _ceu_do_mundo:
        _ceu_do_mundo.visible = true
    if _luz_da_caverna:
        _luz_da_caverna.visible = false
    if _minimapa:
        _minimapa.visible = true
        if _minimapa.has_method("sair_modo_dungeon"):
            _minimapa.call("sair_modo_dungeon")
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
    env.ambient_light_energy = 1.55
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
