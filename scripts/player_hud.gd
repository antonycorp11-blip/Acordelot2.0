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
var _level_label: Label

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _construir_hud_vida()

func _construir_hud_vida() -> void:
    # Painel no Canto Superior Esquerdo
    var container := PanelContainer.new()
    container.set_anchors_preset(Control.PRESET_TOP_LEFT)
    container.anchor_left = 0.0
    container.anchor_top = 0.0
    container.offset_left = 22.0
    container.offset_top = 18.0
    container.offset_right = 290.0
    container.offset_bottom = 96.0
    container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(container)
    
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.07, 0.09, 0.13, 0.88)
    panel_style.border_width_bottom = 2
    panel_style.border_width_left = 2
    panel_style.border_width_right = 2
    panel_style.border_width_top = 2
    panel_style.border_color = Color(0.85, 0.72, 0.35, 0.95)
    panel_style.corner_radius_bottom_left = 10
    panel_style.corner_radius_bottom_right = 10
    panel_style.corner_radius_top_left = 10
    panel_style.corner_radius_top_right = 10
    container.add_theme_stylebox_override("panel", panel_style)
    
    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 10)
    container.add_child(hbox)
    
    # Avatar / Ícone de Perfil com Nível
    var avatar_box := PanelContainer.new()
    avatar_box.custom_minimum_size = Vector2(56, 56)
    var av_style := StyleBoxFlat.new()
    av_style.bg_color = Color(0.12, 0.18, 0.26, 0.95)
    av_style.border_width_bottom = 2
    av_style.border_width_left = 2
    av_style.border_width_right = 2
    av_style.border_width_top = 2
    av_style.border_color = Color(1.0, 0.85, 0.4)
    av_style.corner_radius_bottom_left = 8
    av_style.corner_radius_bottom_right = 8
    av_style.corner_radius_top_left = 8
    av_style.corner_radius_top_right = 8
    avatar_box.add_theme_stylebox_override("panel", av_style)
    hbox.add_child(avatar_box)
    
    var av_vbox := VBoxContainer.new()
    av_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    avatar_box.add_child(av_vbox)
    
    var lbl_icon := Label.new()
    lbl_icon.text = "⚔️"
    lbl_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl_icon.add_theme_font_size_override("font_size", 20)
    av_vbox.add_child(lbl_icon)
    
    _level_label = Label.new()
    _level_label.text = "Nv. %d" % player_level
    _level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _level_label.add_theme_font_size_override("font_size", 10)
    _level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
    av_vbox.add_child(_level_label)
    
    # Barras de Vida e Mana
    var stats_vbox := VBoxContainer.new()
    stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    stats_vbox.add_theme_constant_override("separation", 5)
    hbox.add_child(stats_vbox)
    
    # Barra de Vida (HP)
    var hp_header := HBoxContainer.new()
    stats_vbox.add_child(hp_header)
    
    var lbl_hp_tag := Label.new()
    lbl_hp_tag.text = "VIDA"
    lbl_hp_tag.add_theme_font_size_override("font_size", 11)
    lbl_hp_tag.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
    hp_header.add_child(lbl_hp_tag)
    
    _hp_label = Label.new()
    _hp_label.text = "%d / %d" % [int(current_health), int(max_health)]
    _hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _hp_label.add_theme_font_size_override("font_size", 11)
    _hp_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95))
    hp_header.add_child(_hp_label)
    
    _hp_bar = ProgressBar.new()
    _hp_bar.custom_minimum_size = Vector2(175, 14)
    _hp_bar.min_value = 0.0
    _hp_bar.max_value = max_health
    _hp_bar.value = current_health
    _hp_bar.show_percentage = false
    
    var bg_hp := StyleBoxFlat.new()
    bg_hp.bg_color = Color(0.18, 0.08, 0.08, 0.8)
    bg_hp.corner_radius_bottom_left = 4
    bg_hp.corner_radius_bottom_right = 4
    bg_hp.corner_radius_top_left = 4
    bg_hp.corner_radius_top_right = 4
    _hp_bar.add_theme_stylebox_override("background", bg_hp)
    
    var fill_hp := StyleBoxFlat.new()
    fill_hp.bg_color = Color(0.85, 0.22, 0.25)
    fill_hp.corner_radius_bottom_left = 4
    fill_hp.corner_radius_bottom_right = 4
    fill_hp.corner_radius_top_left = 4
    fill_hp.corner_radius_top_right = 4
    _hp_bar.add_theme_stylebox_override("fill", fill_hp)
    stats_vbox.add_child(_hp_bar)
    
    # Barra de Mana
    _mana_bar = ProgressBar.new()
    _mana_bar.custom_minimum_size = Vector2(175, 8)
    _mana_bar.min_value = 0.0
    _mana_bar.max_value = max_mana
    _mana_bar.value = current_mana
    _mana_bar.show_percentage = false
    
    var bg_mana := StyleBoxFlat.new()
    bg_mana.bg_color = Color(0.08, 0.1, 0.18, 0.8)
    bg_mana.corner_radius_bottom_left = 3
    bg_mana.corner_radius_bottom_right = 3
    bg_mana.corner_radius_top_left = 3
    bg_mana.corner_radius_top_right = 3
    _mana_bar.add_theme_stylebox_override("background", bg_mana)
    
    var fill_mana := StyleBoxFlat.new()
    fill_mana.bg_color = Color(0.2, 0.6, 0.95)
    fill_mana.corner_radius_bottom_left = 3
    fill_mana.corner_radius_bottom_right = 3
    fill_mana.corner_radius_top_left = 3
    fill_mana.corner_radius_top_right = 3
    _mana_bar.add_theme_stylebox_override("fill", fill_mana)
    stats_vbox.add_child(_mana_bar)

func tomar_dano(qtd: float) -> void:
    current_health = clampf(current_health - qtd, 0.0, max_health)
    _atualizar_barras()

func curar(qtd: float) -> void:
    current_health = clampf(current_health + qtd, 0.0, max_health)
    _atualizar_barras()

func _atualizar_barras() -> void:
    if _hp_bar and _hp_label:
        var tween := create_tween()
        tween.tween_property(_hp_bar, "value", current_health, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _hp_label.text = "%d / %d" % [int(current_health), int(max_health)]
