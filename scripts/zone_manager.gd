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
    
    if zone_builder:
        zone_builder.portal_triggered.connect(_on_portal_triggered)
        
    # Inicializa na zona inicial
    var start_id: String = _zones_db.get("start_zone", "zone_floresta_despertar")
    carregar_zona(start_id, "center")

func _carregar_db() -> void:
    var f := FileAccess.open("res://data/zones_db.json", FileAccess.READ)
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

func carregar_zona(zone_id: String, entrada_dir: String = "center") -> void:
    var zones: Dictionary = _zones_db.get("zones", {})
    if not zones.has(zone_id):
        print("Erro: Zona não encontrada:", zone_id)
        return
        
    _current_zone_id = zone_id
    var z_data: Dictionary = zones[zone_id]
    
    if zone_builder:
        zone_builder.construir_zona(z_data)
        
    _posicionar_jogador(entrada_dir)
    _animar_banner_zona(z_data)
    zone_changed.emit(z_data)

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
            
    target_pos.y = zone_builder.calcular_altura(target_pos.x, target_pos.z) + 1.2
    player.global_position = target_pos
    player.velocity = Vector3.ZERO

func _on_portal_triggered(dest_zone_id: String, from_direction: String) -> void:
    if _is_transitioning:
        return
    _is_transitioning = true
    
    # A tela do meio da travessia NAO fica vazia.
    #
    # Preto puro por meio segundo le como falha: o jogador nao sabe se travou,
    # se saiu do jogo ou se esta carregando. Escrever para onde ele esta indo
    # transforma o vazio em informacao, e e o que todo jogo com carregamento
    # entre areas faz. Nao custa nada: e o mesmo retangulo com um texto por cima.
    var zonas: Dictionary = _zones_db.get("zones", {})
    var destino: Dictionary = zonas.get(dest_zone_id, {})
    _cartao_titulo.text = String(destino.get("name", "Viajando..."))
    _cartao_tier.text = String(destino.get("tier", ""))

    var tween := create_tween()
    tween.tween_property(_fade_rect, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
    tween.parallel().tween_property(_cartao, "modulate:a", 1.0, 0.35)
    await tween.finished

    carregar_zona(dest_zone_id, from_direction)

    var tween_in := create_tween()
    tween_in.tween_property(_cartao, "modulate:a", 0.0, 0.25)
    tween_in.tween_property(_fade_rect, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
    await tween_in.finished
    _is_transitioning = false

func _animar_banner_zona(z_data: Dictionary) -> void:
    _zone_title_label.text = z_data.get("name", "Nova Região")
    _zone_tier_label.text = z_data.get("tier", "Zona Neutra")
    
    var tween := create_tween()
    tween.tween_property(_banner_container, "modulate:a", 1.0, 0.4)
    tween.tween_interval(2.2)
    tween.tween_property(_banner_container, "modulate:a", 0.0, 0.6)
