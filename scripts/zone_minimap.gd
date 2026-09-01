extends Control
class_name ZoneMinimap

## Pelo caminho, nao pelo nome da classe: nome global so existe depois que o
## editor varre o projeto, e some numa exportacao limpa.
const CartaDaZona := preload("res://scripts/carta_da_zona.gd")

@export var zone_manager: ZoneManager
@export var player: CharacterBody3D

var _title_label: Label
var _tier_label: Label
var _minimap_draw: Control
var _modal_backdrop: ColorRect
var _world_map_modal: PanelContainer
var _world_map_draw: Control
var _info_label: Label

var _current_zone_data: Dictionary = {}
var _minimap_frame_tex: Texture2D

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # A moldura do kit novo, ja vazada: e um anel dourado com o "N" da bussola,
    # e o radar aparece pelo buraco. A antiga era uma imagem de 1024 com um mapa
    # inteiro pintado dentro — quatro megabytes de memoria de video para mostrar
    # um mapa que nao era o do jogador.
    _minimap_frame_tex = load("res://textures/ui/moldura_mapa.png")
    _criar_minimap_hud()
    _criar_modal_mapa_mundi()
    
    if zone_manager:
        zone_manager.zone_changed.connect(_on_zone_changed)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_M, KEY_TAB]:
            toggle_world_map()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE and _world_map_modal.visible:
            toggle_world_map(false)
            get_viewport().set_input_as_handled()

func toggle_world_map(force_state = null) -> void:
    var next_state: bool = (not _world_map_modal.visible) if force_state == null else force_state
    _world_map_modal.visible = next_state
    _modal_backdrop.visible = next_state
    # O relógio circular e o banner pertencem a camadas diferentes do HUD; sem
    # ocultá-los, atravessavam o mapa aberto no celular.
    var relogio := get_tree().root.find_child("BarraDoDia", true, false) as Control
    if relogio:
        relogio.visible = not next_state
    if zone_manager and zone_manager._banner_container:
        zone_manager._banner_container.visible = not next_state
    if next_state:
        _atualizar_grid_mapa_mundi()

func _criar_minimap_hud() -> void:
    # Container no canto superior direito
    var hud_box := Control.new()
    hud_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    hud_box.anchor_left = 1.0
    hud_box.anchor_right = 1.0
    hud_box.anchor_top = 0.0
    hud_box.anchor_bottom = 0.0
    hud_box.offset_left = -215.0
    hud_box.offset_top = 16.0
    hud_box.offset_right = -15.0
    hud_box.offset_bottom = 240.0
    hud_box.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(hud_box)
    
    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    # Seis, e nao dois. O anel dourado e desenhado com quatro pixels de margem
    # dentro da area do radar, entao com separacao de dois o "Tier I" encostava
    # no aro e ficava lido por baixo do ouro. Visto na captura, nao medido: os
    # retangulos nao se cruzam, quem invade e o desenho dentro deles.
    vbox.add_theme_constant_override("separation", 6)
    hud_box.add_child(vbox)
    
    _title_label = Label.new()
    _title_label.text = "Zona"
    _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title_label.add_theme_font_size_override("font_size", 13)
    _title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
    _title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.95))
    _title_label.add_theme_constant_override("outline_size", 4)
    vbox.add_child(_title_label)
    
    _tier_label = Label.new()
    _tier_label.text = "Tier I"
    _tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tier_label.add_theme_font_size_override("font_size", 10)
    _tier_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
    _tier_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.12, 0.95))
    _tier_label.add_theme_constant_override("outline_size", 3)
    vbox.add_child(_tier_label)
    
    # Área de desenho do radar com a moldura artística
    # UM ESPACO DE VERDADE ANTES DO DISCO.
    #
    # Os retangulos do rotulo e do radar nao se cruzam — 54 contra 64 — e mesmo
    # assim, na captura, "Região inicial" aparece encostado no aro dourado: o
    # desenho da moldura tem brilho para fora do retangulo em que e pintada.
    # Medir dizia que estava bom e a tela dizia que nao; quem manda e a tela.
    var respiro := Control.new()
    respiro.custom_minimum_size = Vector2(0, 10)
    respiro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(respiro)

    _minimap_draw = Control.new()
    # Quadrado: a moldura e um circulo, e caixa achatada vira elipse.
    _minimap_draw.custom_minimum_size = Vector2(170, 170)
    _minimap_draw.mouse_filter = Control.MOUSE_FILTER_PASS
    _minimap_draw.draw.connect(_on_minimap_draw)
    _minimap_draw.gui_input.connect(func(ev: InputEvent):
        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
            toggle_world_map()
    )
    vbox.add_child(_minimap_draw)

    # O BOTAO DE MAPA SAIU, e o de trocar personagem tambem.
    #
    # "Mapa do Reino" duplicava o que o proprio disco ja faz: um toque no radar
    # abre o mapa. Botao que repete o gesto ao lado dele so ocupa canto de tela.
    # A troca de personagem virou um botao redondo com retrato, na fileira de
    # utilitarios do PlayerHUD, junto com missoes, mochila e ajustes — que e onde
    # o jogador procura "as coisas que eu abro".

func _criar_modal_mapa_mundi() -> void:
    _modal_backdrop = ColorRect.new()
    _modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    _modal_backdrop.color = Color(0.02, 0.03, 0.05, 0.75)
    _modal_backdrop.z_index = 1000
    _modal_backdrop.visible = false
    _modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _modal_backdrop.gui_input.connect(func(ev: InputEvent):
        if ev is InputEventMouseButton and ev.pressed:
            toggle_world_map(false)
    )
    add_child(_modal_backdrop)
    
    _world_map_modal = PanelContainer.new()
    # Margens proporcionais: cabe tanto em 1280x720 quanto em celulares mais
    # estreitos sem vazar pelas laterais.
    _world_map_modal.anchor_left = 0.06
    _world_map_modal.anchor_right = 0.94
    _world_map_modal.anchor_top = 0.06
    _world_map_modal.anchor_bottom = 0.94
    _world_map_modal.visible = false
    _world_map_modal.mouse_filter = Control.MOUSE_FILTER_STOP
    _world_map_modal.z_index = 1001
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.07, 0.09, 0.13, 0.98)
    style.border_width_bottom = 3
    style.border_width_left = 3
    style.border_width_right = 3
    style.border_width_top = 3
    style.border_color = Color(0.85, 0.72, 0.4, 1.0)
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    _world_map_modal.add_theme_stylebox_override("panel", style)
    add_child(_world_map_modal)
    
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    _world_map_modal.add_child(vbox)
    
    var header := HBoxContainer.new()
    vbox.add_child(header)
    
    var lbl_title := Label.new()
    lbl_title.text = "Mapa do Reino de Acordelot"
    lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lbl_title.add_theme_font_size_override("font_size", 16)
    lbl_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
    header.add_child(lbl_title)
    
    var btn_close := Button.new()
    btn_close.text = " ✕ "
    btn_close.pressed.connect(func(): toggle_world_map(false))
    header.add_child(btn_close)
    
    _world_map_draw = Control.new()
    _world_map_draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _world_map_draw.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _world_map_draw.custom_minimum_size = Vector2(560, 330)
    _world_map_draw.mouse_filter = Control.MOUSE_FILTER_STOP
    _world_map_draw.draw.connect(_desenhar_mapa_reino)
    _world_map_draw.gui_input.connect(_clicar_mapa_reino)
    vbox.add_child(_world_map_draw)
    
    _info_label = Label.new()
    _info_label.text = "O desenho é gerado das regiões, estradas e rios reais do mundo."
    _info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _info_label.add_theme_font_size_override("font_size", 12)
    _info_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
    vbox.add_child(_info_label)

## Guardada por zona: a carta e cara de desenhar e nao muda enquanto a zona for
## a mesma. Trocar de zona e voltar reaproveita a que ja existe.
var _cartas: Dictionary = {}
var _carta_atual: ImageTexture
var _zid_atual := ""
## Quantos metros cabem no disco. Menos que isto vira lupa e o jogador perde a
## nocao de onde esta; mais que isto e um borrao.
const JANELA := 52.0


## Guarda quem ja esta sendo desenhada: a carta agora leva varios quadros, e
## sem isto uma segunda chamada comecaria a mesma imagem de novo por cima.
var _desenhando := ""

func _preparar_carta(zid: String, z_data: Dictionary) -> void:
    _zid_atual = zid
    if _cartas.has(zid):
        _carta_atual = _cartas[zid]
        return
    if _desenhando == zid:
        return
    _carta_atual = null
    var construtor: Node = zone_manager.zone_builder if zone_manager else null
    if construtor == null or not construtor.has_method("deslocamento_da_celula"):
        return
    # Sem a regiao construida a carta sairia com relevo e ruas mas sem uma casa
    # sequer, e ficaria guardada assim. Melhor nao desenhar e tentar de novo.
    var regiao: Node3D = construtor._regioes.get(zid)
    if regiao == null or not is_instance_valid(regiao):
        return
    _desenhando = zid
    # Passa a arvore: e por ela que a carta devolve o quadro entre as faixas de
    # linha, em vez de segurar a tela por mais de um segundo.
    var pronta: ImageTexture = await CartaDaZona.desenhar(
        construtor, zid, z_data, regiao, get_tree())
    _desenhando = ""
    if pronta == null:
        return
    _cartas[zid] = pronta
    # A zona pode ter mudado enquanto a carta era desenhada.
    if _zid_atual == zid:
        _carta_atual = pronta
        # E PRECISO PEDIR O REDESENHO.
        #
        # O radar so repinta quando o jogador anda. A carta agora leva varios
        # quadros para ficar pronta, e se ela chega com o heroi parado — que e o
        # caso ao entrar numa zona — nada dispara o desenho e o disco fica preto
        # ate alguem dar um passo. Visto na captura; nenhum teste pegaria, porque
        # todos chamavam queue_redraw() na mao.
        if _minimap_draw:
            _minimap_draw.queue_redraw()


func _on_zone_changed(z_data: Dictionary) -> void:
    _current_zone_data = z_data
    _preparar_carta(String(z_data.get("id", "")), z_data)
    _title_label.text = z_data.get("name", "Zona")
    _tier_label.text = z_data.get("tier", "")
    _minimap_draw.queue_redraw()
    if _world_map_modal.visible:
        _atualizar_grid_mapa_mundi()

var _ate_tentar_carta := 0.0

## O RADAR NAO PRECISA DE SESSENTA DESENHOS POR SEGUNDO.
##
## Ele redesenhava a cada quadro: disco, poligono de trinta lados com textura,
## anel, seta e agora os marcos — tudo reconstruido mesmo com o jogador parado.
## Num disco de 170 px, doze atualizacoes por segundo sao indistinguiveis a olho
## e custam um quinto. Alem do ritmo, so redesenha se algo de fato mudou de
## lugar: parado no meio da conversa com um NPC, o radar nao gasta nada.
const RITMO_DO_RADAR := 1.0 / 12.0
const PASSO_QUE_IMPORTA := 0.35
const GIRO_QUE_IMPORTA := 0.05

var _ate_redesenhar := 0.0
var _onde_desenhei := Vector3(1e9, 1e9, 1e9)
var _giro_desenhado := 0.0
## Mesmo sem ninguem se mexer, o radar repinta neste intervalo.
const INTERVALO_PARADO := 0.5
var _ate_repintar := 0.0


func _process(delta: float) -> void:
    if _minimap_draw and _minimap_draw.is_visible_in_tree():
        _ate_redesenhar -= delta
        if _ate_redesenhar <= 0.0:
            _ate_redesenhar = RITMO_DO_RADAR
            _ate_repintar -= RITMO_DO_RADAR
            if player == null:
                _minimap_draw.queue_redraw()
            elif (player.global_position.distance_to(_onde_desenhei) > PASSO_QUE_IMPORTA
                    or absf(angle_difference(_giro_desenhado, player.rotation.y)) > GIRO_QUE_IMPORTA
                    or _ate_repintar <= 0.0):
                # Parado o radar tambem precisa respirar de vez em quando: bicho
                # anda, NPC anda e o anel do objetivo pulsa. Meio segundo entre
                # repinturas custa quase nada e mantem os marcos vivos.
                _onde_desenhei = player.global_position
                _giro_desenhado = player.rotation.y
                _ate_repintar = INTERVALO_PARADO
                _minimap_draw.queue_redraw()

    # A primeira zona ja esta carregada quando este no acorda, entao o sinal de
    # troca dela nunca chega — e a regiao pode ainda estar se montando. Insiste
    # de meio em meio segundo ate ter o que desenhar.
    if _carta_atual != null or zone_manager == null:
        return
    _ate_tentar_carta -= delta
    if _ate_tentar_carta > 0.0:
        return
    _ate_tentar_carta = 0.5
    var atual: Dictionary = zone_manager.zona_atual()
    if not atual.is_empty():
        _current_zone_data = atual
        _preparar_carta(String(atual.get("id", "")), atual)

## Os marcos do radar: o que vale a pena procurar na tela, e em que cor.
##
## Cada um sai de um grupo que o mundo ja mantem — nao ha lista paralela para
## envelhecer. Sao poucos e pequenos de proposito: o radar tem 170 px, e um
## enxame de icones some com a geografia que ele existe para mostrar.
const MARCOS_DO_RADAR := [
    {"grupo": "npc", "cor": Color(1.00, 0.84, 0.42), "raio": 3.2, "teto": 12},
    {"grupo": "eco_capturavel", "cor": Color(0.52, 0.92, 1.00), "raio": 3.0, "teto": 12},
    {"grupo": "recurso_coletavel", "cor": Color(0.52, 0.88, 0.46), "raio": 2.4, "teto": 16},
    {"grupo": "bicho", "cor": Color(0.92, 0.35, 0.30), "raio": 2.6, "teto": 16},
]


func _on_minimap_draw() -> void:
    var rect := _minimap_draw.get_rect()
    var center := rect.size * 0.5
    var frame_size := 162.0
    var frame_rect := Rect2(center - Vector2(frame_size, frame_size) * 0.5, Vector2(frame_size, frame_size))
    var raio_util := frame_size * 0.5 - 8.0

    # 1. O disco por baixo. A moldura nova e so um anel — sem este fundo o radar
    # flutuaria solto sobre o mapa 3D e os pontos sumiriam na grama.
    #
    # ENQUANTO A CARTA NAO CHEGA, o disco usa a cor do bioma em vez de quase
    # preto. A carta leva alguns segundos para nascer (e desenhada aos poucos
    # para nao travar a tela), e nesse tempo um disco preto com pontinhos parecia
    # radar quebrado. Com o verde da floresta ou o cinza da serra ali, a chegada
    # do desenho e um detalhamento, nao um conserto.
    var fundo := Color(0.05, 0.07, 0.06, 0.82)
    if _carta_atual == null:
        var bioma := String(_current_zone_data.get("biome", ""))
        fundo = CartaDaZona.CHAO_DO_BIOMA.get(bioma, Color(0.26, 0.34, 0.22))
        fundo.a = 0.82
        fundo = fundo.darkened(0.25)
    _minimap_draw.draw_circle(center, frame_size * 0.5 - 4.0, fundo)

    # 1b. A CARTA DA REGIAO dentro do disco.
    #
    # Desenhada como poligono com coordenadas de textura em vez de retangulo:
    # retangulo deixaria as quinas para fora do anel, e recortar em circulo por
    # cima custaria outra passada. O poligono JA e o circulo.
    var desvio := Vector2.ZERO
    var centro_uv := Vector2(0.5, 0.5)
    var meia_janela := 0.0
    var origem := Vector3.ZERO
    var lado := 0.0
    var tem_janela := false

    if player and zone_manager and zone_manager.zone_builder:
        var construtor = zone_manager.zone_builder
        lado = float(construtor.TAMANHO_ZONA)
        origem = construtor.deslocamento_da_celula(
            construtor._celulas.get(_zid_atual, Vector2i.ZERO))
        var local := player.global_position - origem
        var alvo := Vector2((local.x + lado * 0.5) / lado, (local.z + lado * 0.5) / lado)
        meia_janela = JANELA / lado
        # Encostado na divisa, a janela para de acompanhar e quem anda e a seta:
        # seguir alem da borda mostraria a textura esticada, que e mentira.
        centro_uv = Vector2(
            clampf(alvo.x, meia_janela, 1.0 - meia_janela),
            clampf(alvo.y, meia_janela, 1.0 - meia_janela))
        desvio = (alvo - centro_uv) / meia_janela * raio_util
        tem_janela = true

        if _carta_atual:
            var raio_mapa := frame_size * 0.5 - 5.0
            var pontos := PackedVector2Array()
            var uvs := PackedVector2Array()
            for i in 30:
                var a := TAU * float(i) / 30.0
                var d := Vector2(cos(a), sin(a))
                pontos.append(center + d * raio_mapa)
                uvs.append(centro_uv + d * meia_janela)
            _minimap_draw.draw_colored_polygon(pontos, Color(1, 1, 1, 0.93), uvs, _carta_atual)

    # 2. Os marcos, por cima da carta e por baixo do anel: quem esta dentro da
    # janela aparece; quem esta fora simplesmente nao e desenhado, sem borda
    # entulhada de setas.
    if tem_janela:
        _desenhar_marcos(center, origem, lado, centro_uv, meia_janela, raio_util)
        _desenhar_objetivo(center, origem, lado, centro_uv, meia_janela, raio_util)

    # 3. O anel dourado com o "N" da bussola, por cima da borda do disco.
    if _minimap_frame_tex:
        _minimap_draw.draw_texture_rect(_minimap_frame_tex, frame_rect, false)

    # 4. Posicao e seta de direcao do jogador.
    if player:
        # A carta se move sob a seta, entao a seta mora no centro. So sai de la
        # quando a janela bate na borda da zona e trava.
        var p_radar := center + desvio

        _minimap_draw.draw_circle(p_radar, 4.5, Color(1.0, 0.95, 0.2))

        var rot_y: float = player.rotation.y
        var dir := Vector2(sin(rot_y), -cos(rot_y))
        _minimap_draw.draw_line(p_radar, p_radar + dir * 8.5, Color(1.0, 0.98, 0.7), 2.2)


## Onde um ponto do mundo cai dentro do disco, ou null se estiver fora da
## janela. Mesma conta da seta do jogador, para os dois nunca discordarem.
func _ponto_no_radar(alvo: Vector3, center: Vector2, origem: Vector3, lado: float,
        centro_uv: Vector2, meia_janela: float, raio_util: float) -> Variant:
    if lado <= 0.0 or meia_janela <= 0.0:
        return null
    var local := alvo - origem
    var uv := Vector2((local.x + lado * 0.5) / lado, (local.z + lado * 0.5) / lado)
    var fora := (uv - centro_uv) / meia_janela
    if fora.length() > 1.0:
        return null
    return center + fora * raio_util


func _desenhar_marcos(center: Vector2, origem: Vector3, lado: float,
        centro_uv: Vector2, meia_janela: float, raio_util: float) -> void:
    for marco in MARCOS_DO_RADAR:
        var cor: Color = marco["cor"]
        var raio: float = marco["raio"]
        var restam: int = marco["teto"]
        for no in get_tree().get_nodes_in_group(String(marco["grupo"])):
            if restam <= 0:
                break
            var corpo := no as Node3D
            if corpo == null or not is_instance_valid(corpo):
                continue
            var onde = _ponto_no_radar(corpo.global_position, center, origem, lado,
                centro_uv, meia_janela, raio_util)
            if onde == null:
                continue
            restam -= 1
            # Contorno escuro primeiro: sobre a mata da carta um ponto colorido
            # sozinho desaparece.
            _minimap_draw.draw_circle(onde, raio + 1.2, Color(0.03, 0.04, 0.05, 0.85))
            _minimap_draw.draw_circle(onde, raio, cor)


## O alvo da missao do dia, quando ha um com lugar no mundo. E o unico marco com
## anel: e o que o jogador procura, e precisa ganhar do resto na primeira olhada.
func _desenhar_objetivo(center: Vector2, origem: Vector3, lado: float,
        centro_uv: Vector2, meia_janela: float, raio_util: float) -> void:
    var diario := get_node_or_null("/root/Diario")
    if diario == null or not diario.has_method("alvo_no_mundo"):
        return
    var alvo = diario.alvo_no_mundo()
    if not (alvo is Vector3):
        return
    var onde = _ponto_no_radar(alvo, center, origem, lado, centro_uv, meia_janela, raio_util)
    if onde == null:
        return
    var pulso := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
    _minimap_draw.draw_circle(onde, 5.0, Color(1.0, 0.86, 0.35, 0.95))
    _minimap_draw.draw_circle(onde, 8.0 + pulso * 2.5,
        Color(1.0, 0.86, 0.35, 0.35 + pulso * 0.35), false, 2.0)


func _atualizar_grid_mapa_mundi() -> void:
    if _world_map_draw:
        _world_map_draw.queue_redraw()


const CORES_MAPA := {
    "floresta": Color(0.12, 0.28, 0.14), "campos": Color(0.42, 0.43, 0.19),
    "cidade": Color(0.40, 0.34, 0.26), "serra": Color(0.30, 0.30, 0.27),
    "sagrado": Color(0.18, 0.32, 0.30), "sombria": Color(0.12, 0.17, 0.19),
    "ruina": Color(0.24, 0.21, 0.22)
}

const EDIFICIOS_MAPA := ["casa", "casa_alta", "casa_larga", "casa_pedra",
    "casarao", "solar", "casa_taipa", "casa_torre", "taverna", "celeiro",
    "moinho", "oficina_ferreiro", "loja_toldo", "torre", "muralha", "muro"]


func _limites_do_reino() -> Vector4:
    var limites: Array = zone_manager._zones_db.get("world_bounds", [-2, -2, 1, 1])
    return Vector4(float(limites[0]), float(limites[1]), float(limites[2]), float(limites[3]))


func _retangulo_da_celula(celula: Vector2i) -> Rect2:
    var limites := _limites_do_reino()
    var colunas := limites.z - limites.x + 1.0
    var linhas := limites.w - limites.y + 1.0
    var tamanho := Vector2(_world_map_draw.size.x / colunas, _world_map_draw.size.y / linhas)
    return Rect2(Vector2((float(celula.x) - limites.x) * tamanho.x,
        (float(celula.y) - limites.y) * tamanho.y), tamanho)


func _ponto_na_celula(retangulo: Rect2, ponto: Array) -> Vector2:
    return retangulo.position + Vector2(
        (float(ponto[0]) + 80.0) / 160.0 * retangulo.size.x,
        (float(ponto[1]) + 80.0) / 160.0 * retangulo.size.y)


func _desenhar_composicao_regional(r: Rect2, zid: String, dados: Dictionary) -> void:
    # Maciços reais quando a zona os declara; pontos determinísticos nas demais
    # florestas. É cartografia, não uma câmera extra renderizando o mundo.
    var macicos: Array = dados.get("forest_clusters", [])
    for macico in macicos:
        var centro := _ponto_na_celula(r, [macico[0], macico[1]])
        var raio := float(macico[2]) / 160.0 * minf(r.size.x, r.size.y) * 1.45
        _world_map_draw.draw_circle(centro, maxf(raio, 2.0), Color(0.06, 0.20, 0.10, 0.72))
    if macicos.is_empty() and str(dados.get("biome", "")) in ["floresta", "sombria"]:
        var rng := RandomNumberGenerator.new()
        rng.seed = hash(zid)
        for i in 14:
            var p := r.position + Vector2(rng.randf_range(5.0, r.size.x - 5.0),
                rng.randf_range(5.0, r.size.y - 5.0))
            _world_map_draw.draw_circle(p, rng.randf_range(1.4, 2.7), Color(0.05, 0.18, 0.09, 0.75))


func _desenhar_edificios_regiao(r: Rect2, dados: Dictionary) -> void:
    if zone_manager == null or zone_manager.zone_builder == null:
        return
    var layout_id := str(dados.get("layout_id", ""))
    var layouts: Dictionary = zone_manager.zone_builder._city_layouts.get("layouts", {})
    for item in layouts.get(layout_id, []):
        var tag := str(item.get("tag", ""))
        if tag not in EDIFICIOS_MAPA:
            continue
        var pos: Array = item.get("position", [])
        if pos.size() < 2:
            continue
        var centro := _ponto_na_celula(r, pos)
        var tamanho := Vector2(maxf(r.size.x / 36.0, 2.4), maxf(r.size.y / 23.0, 2.4))
        var bloco := Rect2(centro - tamanho * 0.5, tamanho)
        _world_map_draw.draw_rect(bloco.grow(0.8), Color(0.13, 0.09, 0.06, 0.95), true)
        _world_map_draw.draw_rect(bloco, Color(0.67, 0.42, 0.22), true)


func _desenhar_mapa_reino() -> void:
    if zone_manager == null or _world_map_draw == null:
        return
    var fonte := ThemeDB.fallback_font
    var zonas: Dictionary = zone_manager._zones_db.get("zones", {})
    var atual := str(_current_zone_data.get("id", ""))
    # Células sem terra são mar: a região começa na costa ocidental, como no
    # conceito, sem inventar mais uma zona jogável para preencher o retângulo.
    _world_map_draw.draw_rect(Rect2(Vector2.ZERO, _world_map_draw.size), Color(0.055, 0.16, 0.25), true)
    for zid in zonas.keys():
        var dados: Dictionary = zonas[zid]
        var grade: Array = dados.get("grid_pos", [0, 0])
        var celula := Vector2i(int(grade[0]), int(grade[1]))
        var r := _retangulo_da_celula(celula).grow(-0.5)
        var cor: Color = CORES_MAPA.get(str(dados.get("biome", "")), Color(0.25, 0.30, 0.22))
        _world_map_draw.draw_rect(r, cor, true)
        _world_map_draw.draw_rect(r.grow(-3.0), cor.lightened(0.10), false, 1.0)
        _desenhar_composicao_regional(r, str(zid), dados)

        # O que aparece aqui é a mesma polilinha usada pelo shader do chão e
        # pela malha de água do mundo 3D.
        for rio in dados.get("river_paths", []):
            var pontos := PackedVector2Array()
            for p in rio:
                pontos.append(_ponto_na_celula(r, p))
            if pontos.size() > 1:
                _world_map_draw.draw_polyline(pontos, Color(0.025, 0.12, 0.22), 7.0, true)
                _world_map_draw.draw_polyline(pontos, Color(0.10, 0.48, 0.72), 4.2, true)
        for estrada in dados.get("road_paths", []):
            var pontos := PackedVector2Array()
            for p in estrada:
                pontos.append(_ponto_na_celula(r, p))
            if pontos.size() > 1:
                var cor_via := Color(0.72, 0.69, 0.60) if str(dados.get("road_surface", "terra")) == "pedra" else Color(0.58, 0.42, 0.25)
                _world_map_draw.draw_polyline(pontos, Color(0.16, 0.12, 0.08), 5.0, true)
                _world_map_draw.draw_polyline(pontos, cor_via, 2.7, true)

        _desenhar_edificios_regiao(r, dados)

        var borda := Color(1.0, 0.78, 0.28) if str(zid) == atual else Color(0.62, 0.52, 0.33, 0.65)
        _world_map_draw.draw_rect(r, borda, false, 2.5 if str(zid) == atual else 1.0)
        var nome := str(dados.get("name", zid))
        var faixa := Rect2(r.position + Vector2(3.0, r.size.y - 18.0), Vector2(r.size.x - 6.0, 15.0))
        _world_map_draw.draw_rect(faixa, Color(0.025, 0.035, 0.05, 0.82), true)
        _world_map_draw.draw_string(fonte, faixa.position + Vector2(4, 12), nome,
            HORIZONTAL_ALIGNMENT_LEFT, faixa.size.x - 8, 10, Color(0.98, 0.91, 0.70))

    if player:
        var limites := _limites_do_reino()
        var origem := Vector2(limites.x * 160.0 - 80.0, limites.y * 160.0 - 80.0)
        var total := Vector2((limites.z - limites.x + 1.0) * 160.0,
            (limites.w - limites.y + 1.0) * 160.0)
        var uv := (Vector2(player.global_position.x, player.global_position.z) - origem) / total
        var p := Vector2(uv.x * _world_map_draw.size.x, uv.y * _world_map_draw.size.y)
        _world_map_draw.draw_circle(p, 6.0, Color(1.0, 0.90, 0.20))
        _world_map_draw.draw_circle(p, 9.0, Color(1.0, 0.90, 0.20), false, 2.0)


func _clicar_mapa_reino(evento: InputEvent) -> void:
    if not (evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT):
        return
    var limites := _limites_do_reino()
    var pos: Vector2 = evento.position
    var celula := Vector2i(int(floor(pos.x / _world_map_draw.size.x * (limites.z - limites.x + 1.0) + limites.x)),
        int(floor(pos.y / _world_map_draw.size.y * (limites.w - limites.y + 1.0) + limites.y)))
    var zid := str(zone_manager.zone_builder._por_celula.get("%d,%d" % [celula.x, celula.y], ""))
    if zid != "":
        toggle_world_map(false)
        zone_manager.carregar_zona(zid, "center")
