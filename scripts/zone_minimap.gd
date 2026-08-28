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
var _botao_personagem: Button

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
    vbox.add_theme_constant_override("separation", 2)
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

    # Troca de personagem imediatamente abaixo do mapa: longe das skills e
    # dentro da mesma coluna utilitária, com área de toque confortável.
    _botao_personagem = Button.new()
    _botao_personagem.text = "Trocar para Wins"
    _botao_personagem.custom_minimum_size = Vector2(170, 34)
    _botao_personagem.add_theme_font_size_override("font_size", 12)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.035, 0.09, 0.17, 0.94)
    normal.border_color = Color(0.76, 0.60, 0.28, 0.95)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(8)
    _botao_personagem.add_theme_stylebox_override("normal", normal)
    var pressionado := normal.duplicate() as StyleBoxFlat
    pressionado.bg_color = Color(0.12, 0.32, 0.52, 0.98)
    _botao_personagem.add_theme_stylebox_override("pressed", pressionado)
    _botao_personagem.pressed.connect(_trocar_personagem)
    vbox.add_child(_botao_personagem)
    if player and player.has_signal("personagem_trocado"):
        player.personagem_trocado.connect(_ao_trocar_personagem)
    
    var btn_mapa := Button.new()
    # Sem emoji: a fonte do jogo nao tem esses desenhos e o celular mostra
    # um quadradinho vazio no lugar.
    btn_mapa.text = "Mapa do Reino  (M)"
    btn_mapa.add_theme_font_size_override("font_size", 11)
    btn_mapa.pressed.connect(func(): toggle_world_map())
    vbox.add_child(btn_mapa)

func _trocar_personagem() -> void:
    if player and player.has_method("trocar_personagem"):
        player.trocar_personagem()

func _ao_trocar_personagem(id: String, _nome: String) -> void:
    if _botao_personagem:
        _botao_personagem.text = "Trocar para Akles" if id == "wins" else "Trocar para Wins"

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


func _preparar_carta(zid: String, z_data: Dictionary) -> void:
    _zid_atual = zid
    if _cartas.has(zid):
        _carta_atual = _cartas[zid]
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
    _carta_atual = CartaDaZona.desenhar(construtor, zid, z_data, regiao)
    _cartas[zid] = _carta_atual


func _on_zone_changed(z_data: Dictionary) -> void:
    _current_zone_data = z_data
    _preparar_carta(String(z_data.get("id", "")), z_data)
    _title_label.text = z_data.get("name", "Zona")
    _tier_label.text = z_data.get("tier", "")
    _minimap_draw.queue_redraw()
    if _world_map_modal.visible:
        _atualizar_grid_mapa_mundi()

var _ate_tentar_carta := 0.0

func _process(delta: float) -> void:
    if _minimap_draw and _minimap_draw.is_visible_in_tree():
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

func _on_minimap_draw() -> void:
    var rect := _minimap_draw.get_rect()
    var center := rect.size * 0.5
    var frame_size := 162.0
    var frame_rect := Rect2(center - Vector2(frame_size, frame_size) * 0.5, Vector2(frame_size, frame_size))
    
    # 1. O disco escuro por baixo. A moldura nova e so um anel — sem este fundo
    # o radar flutuaria solto sobre o mapa 3D e os pontos sumiriam na grama.
    _minimap_draw.draw_circle(center, frame_size * 0.5 - 4.0, Color(0.05, 0.07, 0.06, 0.82))

    # 1b. A CARTA DA REGIAO dentro do disco.
    #
    # Desenhada como poligono com coordenadas de textura em vez de retangulo:
    # retangulo deixaria as quinas para fora do anel, e recortar em circulo por
    # cima custaria outra passada. O poligono JA e o circulo.
    var desvio := Vector2.ZERO
    if _carta_atual and player and zone_manager and zone_manager.zone_builder:
        var construtor = zone_manager.zone_builder
        var lado: float = float(construtor.TAMANHO_ZONA)
        var origem: Vector3 = construtor.deslocamento_da_celula(
            construtor._celulas.get(_zid_atual, Vector2i.ZERO))
        var local := player.global_position - origem
        var alvo := Vector2((local.x + lado * 0.5) / lado, (local.z + lado * 0.5) / lado)
        var meia_janela := JANELA / lado
        # Encostado na divisa, a janela para de acompanhar e quem anda e a seta:
        # seguir alem da borda mostraria a textura esticada, que e mentira.
        var centro_uv := Vector2(
            clampf(alvo.x, meia_janela, 1.0 - meia_janela),
            clampf(alvo.y, meia_janela, 1.0 - meia_janela))
        desvio = (alvo - centro_uv) / meia_janela * (frame_size * 0.5 - 8.0)

        var raio_mapa := frame_size * 0.5 - 5.0
        var pontos := PackedVector2Array()
        var uvs := PackedVector2Array()
        for i in 30:
            var a := TAU * float(i) / 30.0
            var d := Vector2(cos(a), sin(a))
            pontos.append(center + d * raio_mapa)
            uvs.append(centro_uv + d * meia_janela)
        _minimap_draw.draw_colored_polygon(pontos, Color(1, 1, 1, 0.93), uvs, _carta_atual)

    
    # 2. O anel dourado com o "N" da bussola, por cima da borda do disco.
    if _minimap_frame_tex:
        _minimap_draw.draw_texture_rect(_minimap_frame_tex, frame_rect, false)
        
    var radius := 62.0
    
    # 3. Posição e Seta de Direção do Jogador
    if player:
        var px: float = player.global_position.x
        var pz: float = player.global_position.z
        # A carta se move sob a seta, entao a seta mora no centro. So sai de la
        # quando a janela bate na borda da zona e trava.
        var p_radar := center + desvio
        
        _minimap_draw.draw_circle(p_radar, 4.5, Color(1.0, 0.95, 0.2))
        
        var rot_y: float = player.rotation.y
        var dir := Vector2(sin(rot_y), -cos(rot_y))
        _minimap_draw.draw_line(p_radar, p_radar + dir * 8.5, Color(1.0, 0.98, 0.7), 2.2)

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
