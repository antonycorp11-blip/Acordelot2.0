extends Control
class_name ZoneMinimap

@export var zone_manager: ZoneManager
@export var player: CharacterBody3D

var _title_label: Label
var _tier_label: Label
var _minimap_draw: Control
var _world_map_modal: PanelContainer
var _grid_container: GridContainer

var _current_zone_data: Dictionary = {}

func _ready() -> void:
    _criar_minimap_hud()
    _criar_modal_mapa_mundi()
    
    if zone_manager:
        zone_manager.zone_changed.connect(_on_zone_changed)

func _criar_minimap_hud() -> void:
    # Painel no canto superior direito
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.offset_left = -220.0
    panel.offset_top = 18.0
    panel.offset_right = -18.0
    panel.offset_bottom = 230.0
    add_child(panel)
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.1, 0.14, 0.88)
    style.border_width_bottom = 2
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_color = Color(0.65, 0.55, 0.32, 0.9)
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    panel.add_theme_stylebox_override("panel", style)
    
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    panel.add_child(vbox)
    
    _title_label = Label.new()
    _title_label.text = "Zona"
    _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title_label.add_theme_font_size_override("font_size", 14)
    _title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
    vbox.add_child(_title_label)
    
    _tier_label = Label.new()
    _tier_label.text = "Tier"
    _tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tier_label.add_theme_font_size_override("font_size", 11)
    _tier_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
    vbox.add_child(_tier_label)
    
    # Área de desenho do radar de cluster
    _minimap_draw = Control.new()
    _minimap_draw.custom_minimum_size = Vector2(180, 110)
    _minimap_draw.draw.connect(_on_minimap_draw)
    vbox.add_child(_minimap_draw)
    
    # Botão de Abrir Mapa do Reino
    var btn_mapa := Button.new()
    btn_mapa.text = "🗺️ Mapa do Reino"
    btn_mapa.add_theme_font_size_override("font_size", 12)
    btn_mapa.pressed.connect(func():
        _world_map_modal.visible = not _world_map_modal.visible
        if _world_map_modal.visible:
            _atualizar_grid_mapa_mundi()
    )
    vbox.add_child(btn_mapa)

func _criar_modal_mapa_mundi() -> void:
    _world_map_modal = PanelContainer.new()
    _world_map_modal.set_anchors_preset(Control.PRESET_CENTER)
    _world_map_modal.custom_minimum_size = Vector2(560, 420)
    _world_map_modal.visible = false
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
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
    lbl_title.text = "🗺️ Mapa do Reino de Acordelot (Clusters de Zonas)"
    lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lbl_title.add_theme_font_size_override("font_size", 18)
    lbl_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
    header.add_child(lbl_title)
    
    var btn_close := Button.new()
    btn_close.text = " ✕ "
    btn_close.pressed.connect(func(): _world_map_modal.visible = false)
    header.add_child(btn_close)
    
    # Grade de Zonas estilo Albion
    _grid_container = GridContainer.new()
    _grid_container.columns = 3
    _grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _grid_container.add_theme_constant_override("h_separation", 8)
    _grid_container.add_theme_constant_override("v_separation", 8)
    vbox.add_child(_grid_container)

func _on_zone_changed(z_data: Dictionary) -> void:
    _current_zone_data = z_data
    _title_label.text = z_data.get("name", "Zona")
    _tier_label.text = z_data.get("tier", "")
    _minimap_draw.queue_redraw()

func _process(_delta: float) -> void:
    if _minimap_draw and _minimap_draw.is_visible_in_tree():
        _minimap_draw.queue_redraw()

func _on_minimap_draw() -> void:
    var rect := _minimap_draw.get_rect()
    var center := rect.size * 0.5
    var radius := 46.0
    
    # Fundo circular
    _minimap_draw.draw_circle(center, radius, Color(0.12, 0.16, 0.2, 0.85))
    _minimap_draw.draw_arc(center, radius, 0.0, TAU, 32, Color(0.65, 0.55, 0.32), 2.0)
    
    # Exits Norte, Sul, Leste, Oeste
    var exits: Dictionary = _current_zone_data.get("exits", {})
    if exits.get("north", "") != "":
        _minimap_draw.draw_circle(center + Vector2(0, -radius + 4), 4.5, Color(0.2, 0.8, 1.0))
    if exits.get("south", "") != "":
        _minimap_draw.draw_circle(center + Vector2(0, radius - 4), 4.5, Color(0.2, 0.8, 1.0))
    if exits.get("east", "") != "":
        _minimap_draw.draw_circle(center + Vector2(radius - 4, 0), 4.5, Color(0.2, 0.8, 1.0))
    if exits.get("west", "") != "":
        _minimap_draw.draw_circle(center + Vector2(-radius + 4, 0), 4.5, Color(0.2, 0.8, 1.0))
        
    # Ponto do Jogador no radar
    if player:
        var px: float = player.global_position.x
        var pz: float = player.global_position.z
        var half_zone: float = 80.0
        var norm_x: float = clampf(px / half_zone, -1.0, 1.0)
        var norm_z: float = clampf(pz / half_zone, -1.0, 1.0)
        var p_radar := center + Vector2(norm_x, norm_z) * (radius - 8.0)
        _minimap_draw.draw_circle(p_radar, 4.0, Color(1.0, 0.85, 0.2))

func _atualizar_grid_mapa_mundi() -> void:
    for c in _grid_container.get_children():
        c.queue_free()
        
    var db: Dictionary = zone_manager._zones_db.get("zones", {}) if zone_manager else {}
    var cur_id: String = _current_zone_data.get("id", "")
    
    for zid in db:
        var z: Dictionary = db[zid]
        var btn := Button.new()
        btn.text = "%s\n[%s]" % [z.get("name", ""), z.get("tier", "")]
        btn.custom_minimum_size = Vector2(165, 85)
        
        if zid == cur_id:
            var sel_style := StyleBoxFlat.new()
            sel_style.bg_color = Color(0.2, 0.35, 0.5, 0.9)
            sel_style.border_width_bottom = 2
            sel_style.border_width_left = 2
            sel_style.border_width_right = 2
            sel_style.border_width_top = 2
            sel_style.border_color = Color(1.0, 0.85, 0.3)
            btn.add_theme_stylebox_override("normal", sel_style)
            
        _grid_container.add_child(btn)
