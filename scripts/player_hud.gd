extends Control
class_name PlayerHUD

@export var max_health: float = 1000.0
@export var current_health: float = 1000.0
@export var max_mana: float = 500.0
@export var current_mana: float = 500.0
@export var player_level: int = 12

var _hp_bar: ProgressBar
var _hp_label: Label
var _mana_bar: ProgressBar
var _mana_label: Label

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _construir_hud_vida()

func _construir_hud_vida() -> void:
    # Container no Canto Superior Esquerdo
    var hud_box := Control.new()
    hud_box.position = Vector2(20, 16)
    hud_box.custom_minimum_size = Vector2(300, 100)
    hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hud_box)
    
    # Textura da Moldura Artística de Ouro e Gemas
    var frame_tex: Texture2D = load("res://textures/ui/hud_vida_frame.png")
    if frame_tex:
        var frame_rect := TextureRect.new()
        frame_rect.texture = frame_tex
        frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        frame_rect.size = Vector2(290, 86)
        frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hud_box.add_child(frame_rect)
        
    # Barra de Vida Funcional sobreposta
    _hp_bar = ProgressBar.new()
    _hp_bar.position = Vector2(118, 28)
    _hp_bar.size = Vector2(136, 15)
    _hp_bar.min_value = 0.0
    _hp_bar.max_value = max_health
    _hp_bar.value = current_health
    _hp_bar.show_percentage = false
    
    var bg_hp := StyleBoxFlat.new()
    bg_hp.bg_color = Color(0.2, 0.05, 0.05, 0.65)
    bg_hp.corner_radius_bottom_left = 3
    bg_hp.corner_radius_bottom_right = 3
    bg_hp.corner_radius_top_left = 3
    bg_hp.corner_radius_top_right = 3
    _hp_bar.add_theme_stylebox_override("background", bg_hp)
    
    var fill_hp := StyleBoxFlat.new()
    fill_hp.bg_color = Color(0.9, 0.18, 0.22, 0.95)
    fill_hp.corner_radius_bottom_left = 3
    fill_hp.corner_radius_bottom_right = 3
    fill_hp.corner_radius_top_left = 3
    fill_hp.corner_radius_top_right = 3
    _hp_bar.add_theme_stylebox_override("fill", fill_hp)
    hud_box.add_child(_hp_bar)
    
    _hp_label = Label.new()
    _hp_label.position = Vector2(118, 26)
    _hp_label.size = Vector2(136, 18)
    _hp_label.text = "%d / %d" % [int(current_health), int(max_health)]
    _hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hp_label.add_theme_font_size_override("font_size", 10)
    _hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
    _hp_label.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0, 0.9))
    _hp_label.add_theme_constant_override("outline_size", 3)
    hud_box.add_child(_hp_label)
    
    # Barra de Mana Funcional
    _mana_bar = ProgressBar.new()
    _mana_bar.position = Vector2(118, 52)
    _mana_bar.size = Vector2(120, 11)
    _mana_bar.min_value = 0.0
    _mana_bar.max_value = max_mana
    _mana_bar.value = current_mana
    _mana_bar.show_percentage = false
    
    var bg_mana := StyleBoxFlat.new()
    bg_mana.bg_color = Color(0.05, 0.1, 0.2, 0.65)
    bg_mana.corner_radius_bottom_left = 2
    bg_mana.corner_radius_bottom_right = 2
    bg_mana.corner_radius_top_left = 2
    bg_mana.corner_radius_top_right = 2
    _mana_bar.add_theme_stylebox_override("background", bg_mana)
    
    var fill_mana := StyleBoxFlat.new()
    fill_mana.bg_color = Color(0.18, 0.65, 0.95, 0.95)
    fill_mana.corner_radius_bottom_left = 2
    fill_mana.corner_radius_bottom_right = 2
    fill_mana.corner_radius_top_left = 2
    fill_mana.corner_radius_top_right = 2
    _mana_bar.add_theme_stylebox_override("fill", fill_mana)
    hud_box.add_child(_mana_bar)

func curar(qtd: float) -> void:
    current_health = clampf(current_health + qtd, 0.0, max_health)
    _atualizar_barras()

func tomar_dano(qtd: float) -> void:
    current_health = clampf(current_health - qtd, 0.0, max_health)
    _atualizar_barras()

func _atualizar_barras() -> void:
    if _hp_bar and _hp_label:
        var tween := create_tween()
        tween.tween_property(_hp_bar, "value", current_health, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _hp_label.text = "%d / %d" % [int(current_health), int(max_health)]
