extends Node3D
class_name ZoneManager

signal zone_changed(zone_data: Dictionary)

@export var player: CharacterBody3D
@export var zone_builder: ZoneBuilder

var _zones_db: Dictionary = {}
var _current_zone_id: String = ""
var _is_transitioning := false

var _cartao: VBoxContainer
var _cartao_titulo: Label
var _cartao_tier: Label
var _fade_rect: ColorRect
var _zone_title_label: Label
var _zone_tier_label: Label
var _banner_container: VBoxContainer

func _ready() -> void:
    _carregar_db()
    _criar_ui_transicao()
    
    # MUNDO ABERTO: nao existe mais "carregar a zona atual". O construtor monta a
    # grade inteira a partir das saidas que ja estavam no banco e mantem viva a
    # vizinhanca de quem joga. Aqui so sobra perceber em que zona o jogador
    # esta, para anunciar o nome e avisar quem depende disso (minimapa, NPCs,
    # gerador de bichos).
    if zone_builder:
        zone_builder.montar_mundo(_zones_db, player)

    _current_zone_id = String(_zones_db.get("start_zone", "zone_floresta_despertar"))
    _posicionar_jogador("center")
    var inicial: Dictionary = _zones_db.get("zones", {}).get(_current_zone_id, {})
    _animar_banner_zona(inicial)
    zone_changed.emit(inicial)

func _carregar_db() -> void:
    # A primeira regiao tem planta geografica propria. O banco antigo fica no
    # projeto como retorno seguro, mas nao manda mais na posicao das terras.
    var f := FileAccess.open("res://data/acordelot_regiao_1.json", FileAccess.READ)
    if f == null:
        f = FileAccess.open("res://data/zones_db.json", FileAccess.READ)
    if f:
        _zones_db = JSON.parse_string(f.get_as_text())

func _criar_ui_transicao() -> void:
    var canvas := CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    
    # Tela de Fade preta
    _fade_rect = ColorRect.new()
    _fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fade_rect.color = Color(0, 0, 0, 0)
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(_fade_rect)
    
    # Banner central de entrada de zona estilo Albion Online
    _banner_container = VBoxContainer.new()
    _banner_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
    # SEM ISTO O NOME DA ZONA NAO FICA CENTRADO. Com ancora esquerda e direita
    # no meio, o container cresce ate o tamanho do texto — e cresce so para a
    # direita. O nome comecava no centro da tela e ia para o lado, em vez de
    # ficar em volta dele. Crescer para os dois lados resolve.
    _banner_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _banner_container.position.y = 80.0
    _banner_container.modulate.a = 0.0
    canvas.add_child(_banner_container)

    # Cartao de travessia, por cima do escurecimento.
    _cartao = VBoxContainer.new()
    _cartao.set_anchors_preset(Control.PRESET_FULL_RECT)
    _cartao.alignment = BoxContainer.ALIGNMENT_CENTER
    _cartao.modulate.a = 0.0
    _cartao.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(_cartao)

    var indo := Label.new()
    indo.text = "viajando para"
    indo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    indo.add_theme_font_size_override("font_size", 14)
    indo.add_theme_color_override("font_color", Color(0.55, 0.68, 0.85))
    _cartao.add_child(indo)

    _cartao_titulo = Label.new()
    _cartao_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _cartao_titulo.add_theme_font_size_override("font_size", 30)
    _cartao_titulo.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
    _cartao.add_child(_cartao_titulo)

    _cartao_tier = Label.new()
    _cartao_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _cartao_tier.add_theme_font_size_override("font_size", 15)
    _cartao_tier.add_theme_color_override("font_color", Color(0.62, 0.72, 0.88))
    _cartao.add_child(_cartao_tier)
    
    _zone_title_label = Label.new()
    _zone_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _zone_title_label.add_theme_font_size_override("font_size", 32)
    _zone_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
    _zone_title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.95))
    _zone_title_label.add_theme_constant_override("outline_size", 8)
    _banner_container.add_child(_zone_title_label)
    
    _zone_tier_label = Label.new()
    _zone_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _zone_tier_label.add_theme_font_size_override("font_size", 16)
    _zone_tier_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    _zone_tier_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.9))
    _zone_tier_label.add_theme_constant_override("outline_size", 6)
    _banner_container.add_child(_zone_tier_label)

## A zona inicial e carregada no _ready do proprio ZoneManager, que roda ANTES
## do _ready de quem o contem — quem se conecta ao sinal depois perde a primeira
## emissao. Este getter e como o resto do jogo alcanca o estado que ja passou.
func zona_atual() -> Dictionary:
    return _zones_db.get("zones", {}).get(_current_zone_id, {})


## Andar de uma zona para outra nao chama ninguem: o chao ja esta la. Este
## _process so olha em que celula o jogador esta e, quando muda, anuncia.
func _process(_delta: float) -> void:
    if player == null or zone_builder == null or not zone_builder.has_method("zona_no_ponto"):
        return
    var aqui := String(zone_builder.zona_no_ponto(player.global_position.x, player.global_position.z))
    if aqui == "" or aqui == _current_zone_id:
        return
    _current_zone_id = aqui
    var z_data: Dictionary = _zones_db.get("zones", {}).get(aqui, {})
    _animar_banner_zona(z_data)
    zone_changed.emit(z_data)


## Viagem rapida pelo mapa-mundi. Nao reconstroi nada: leva o jogador ate a
## celula da zona pedida e deixa o proprio mundo carregar o que estiver perto.
func carregar_zona(zone_id: String, _entrada_dir: String = "center") -> void:
    var zones: Dictionary = _zones_db.get("zones", {})
    if not zones.has(zone_id) or player == null or zone_builder == null:
        return
    var destino: Vector3 = zone_builder.deslocamento_da_celula(
        zone_builder._celulas.get(zone_id, Vector2i.ZERO))
    # Congela a física durante o streaming. Sem isso, a viagem pelo mapa punha
    # o herói numa célula ainda vazia e ele caía antes do chão ficar pronto.
    player.set_physics_process(false)
    destino.y = zone_builder.calcular_altura(destino.x, destino.z) + 4.0
    player.global_position = destino
    player.velocity = Vector3.ZERO
    var tentativas := 0
    while not zone_builder._regioes.has(zone_id) and tentativas < 100:
        await get_tree().create_timer(0.10).timeout
        tentativas += 1
    destino.y = zone_builder.calcular_altura(destino.x, destino.z) + 1.2
    player.global_position = destino
    player.velocity = Vector3.ZERO
    player.set_physics_process(true)

func _posicionar_jogador(entrada_dir: String) -> void:
    if not player or not zone_builder:
        return
        
    var half: float = 62.0
    var target_pos := Vector3.ZERO
    
    match entrada_dir:
        "north":
            # Veio do Norte, entra pelo Sul
            target_pos = Vector3(0.0, 0.0, half)
        "south":
            # Veio do Sul, entra pelo Norte
            target_pos = Vector3(0.0, 0.0, -half)
        "east":
            # Veio do Leste, entra pelo Oeste
            target_pos = Vector3(-half, 0.0, 0.0)
        "west":
            # Veio do Oeste, entra pelo Leste
            target_pos = Vector3(half, 0.0, 0.0)
        _:
            # Centro da zona
            target_pos = Vector3(0.0, 0.0, 0.0)
            
    target_pos += zone_builder.deslocamento_da_celula(
        zone_builder._celulas.get(_current_zone_id, Vector2i.ZERO))
    target_pos.y = zone_builder.calcular_altura(target_pos.x, target_pos.z) + 1.2
    player.global_position = target_pos
    player.velocity = Vector3.ZERO

func _animar_banner_zona(z_data: Dictionary) -> void:
    _zone_title_label.text = z_data.get("name", "Nova Região")
    _zone_tier_label.text = z_data.get("tier", "Zona Neutra")
    
    var tween := create_tween()
    tween.tween_property(_banner_container, "modulate:a", 1.0, 0.4)
    tween.tween_interval(2.2)
    tween.tween_property(_banner_container, "modulate:a", 0.0, 0.6)
