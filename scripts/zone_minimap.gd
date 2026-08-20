extends Control
class_name ZoneMinimap

@export var zone_manager: ZoneManager
@export var player: CharacterBody3D

var _title_label: Label
var _tier_label: Label
var _minimap_draw: Control
var _modal_backdrop: ColorRect
var _world_map_modal: PanelContainer
var _grid_container: GridContainer
var _info_label: Label

var _current_zone_data: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    if next_state:
        _atualizar_grid_mapa_mundi()

func _criar_minimap_hud() -> void:
    # Painel no canto superior direito
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.offset_left = -225.0
    panel.offset_top = 18.0
    panel.offset_right = -18.0
    panel.offset_bottom = 240.0
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel)
    
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
    style.border_width_bottom = 2
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_color = Color(0.85, 0.72, 0.35, 0.95)
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    panel.add_theme_stylebox_override("panel", style)
    
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 3)
    panel.add_child(vbox)
    
    _title_label = Label.new()
    _title_label.text = "Carregando..."
    _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title_label.add_theme_font_size_override("font_size", 13)
    _title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
    vbox.add_child(_title_label)
    
    _tier_label = Label.new()
    _tier_label.text = "Zona"
    _tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tier_label.add_theme_font_size_override("font_size", 10)
    _tier_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
    vbox.add_child(_tier_label)
    
    # Área de desenho do radar em miniatura
    _minimap_draw = Control.new()
    _minimap_draw.custom_minimum_size = Vector2(190, 120)
    _minimap_draw.mouse_filter = Control.MOUSE_FILTER_PASS
    _minimap_draw.draw.connect(_on_minimap_draw)
    _minimap_draw.gui_input.connect(func(ev: InputEvent):
        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
            toggle_world_map()
    )
    vbox.add_child(_minimap_draw)
    
    var btn_mapa := Button.new()
    btn_mapa.text = "🗺️ Mapa do Reino (M)"
    btn_mapa.add_theme_font_size_override("font_size", 11)
    btn_mapa.pressed.connect(func(): toggle_world_map())
    vbox.add_child(btn_mapa)

func _criar_modal_mapa_mundi() -> void:
    _modal_backdrop = ColorRect.new()
    _modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    _modal_backdrop.color = Color(0.02, 0.03, 0.05, 0.75)
    _modal_backdrop.visible = false
    _modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _modal_backdrop.gui_input.connect(func(ev: InputEvent):
        if ev is InputEventMouseButton and ev.pressed:
            toggle_world_map(false)
    )
    add_child(_modal_backdrop)
    
    _world_map_modal = PanelContainer.new()
    _world_map_modal.anchor_left = 0.5
    _world_map_modal.anchor_right = 0.5
    _world_map_modal.anchor_top = 0.5
    _world_map_modal.anchor_bottom = 0.5
    _world_map_modal.offset_left = -310.0
    _world_map_modal.offset_top = -240.0
    _world_map_modal.offset_right = 310.0
    _world_map_modal.offset_bottom = 240.0
    _world_map_modal.visible = false
    _world_map_modal.mouse_filter = Control.MOUSE_FILTER_STOP
    
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
    lbl_title.text = "🗺️ Mapa do Reino de Acordelot"
    lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lbl_title.add_theme_font_size_override("font_size", 16)
    lbl_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
    header.add_child(lbl_title)
    
    var btn_close := Button.new()
    btn_close.text = " ✕ "
    btn_close.pressed.connect(func(): toggle_world_map(false))
    header.add_child(btn_close)
    
    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size = Vector2(580, 310)
    vbox.add_child(scroll)
    
    _grid_container = GridContainer.new()
    _grid_container.columns = 3
    _grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _grid_container.add_theme_constant_override("h_separation", 10)
    _grid_container.add_theme_constant_override("v_separation", 10)
    scroll.add_child(_grid_container)
    
    _info_label = Label.new()
    _info_label.text = "Atravesse os portais brilhantes ou clique em uma zona para viajar!"
    _info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _info_label.add_theme_font_size_override("font_size", 12)
    _info_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
    vbox.add_child(_info_label)

func _on_zone_changed(z_data: Dictionary) -> void:
    _current_zone_data = z_data
    _title_label.text = z_data.get("name", "Zona")
    _tier_label.text = z_data.get("tier", "")
    _minimap_draw.queue_redraw()
    if _world_map_modal.visible:
        _atualizar_grid_mapa_mundi()

func _process(_delta: float) -> void:
    if _minimap_draw and _minimap_draw.is_visible_in_tree():
        _minimap_draw.queue_redraw()

func _on_minimap_draw() -> void:
    var rect := _minimap_draw.get_rect()
    var center := rect.size * 0.5
    var radius := 50.0
    
    # 1. Fundo do radar com bioma
    var biome: String = str(_current_zone_data.get("biome", "floresta"))
    var biome_color := Color(0.12, 0.22, 0.14, 0.95)
    if biome == "cidade":
        biome_color = Color(0.24, 0.2, 0.16, 0.95)
    elif biome == "sombria":
        biome_color = Color(0.12, 0.1, 0.18, 0.95)
    elif biome == "sagrado":
        biome_color = Color(0.16, 0.18, 0.28, 0.95)
        
    _minimap_draw.draw_circle(center, radius, biome_color)
    _minimap_draw.draw_arc(center, radius, 0.0, TAU, 48, Color(0.85, 0.72, 0.35, 0.95), 2.5)
    
    # 2. Grade de relevo sutil
    _minimap_draw.draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(1.0, 1.0, 1.0, 0.08), 1.0)
    _minimap_draw.draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(1.0, 1.0, 1.0, 0.08), 1.0)
    
    # 3. Portais de Saída Cardinais com anel pulsante
    var pulse: float = sin(Time.get_ticks_msec() * 0.005) * 1.2
    var exits: Dictionary = _current_zone_data.get("exits", {})
    if exits.get("north", "") != "":
        _minimap_draw.draw_circle(center + Vector2(0, -radius + 4), 4.5 + pulse, Color(0.2, 0.85, 1.0, 0.9))
    if exits.get("south", "") != "":
        _minimap_draw.draw_circle(center + Vector2(0, radius - 4), 4.5 + pulse, Color(0.2, 0.85, 1.0, 0.9))
    if exits.get("east", "") != "":
        _minimap_draw.draw_circle(center + Vector2(radius - 4, 0), 4.5 + pulse, Color(0.2, 0.85, 1.0, 0.9))
    if exits.get("west", "") != "":
        _minimap_draw.draw_circle(center + Vector2(-radius + 4, 0), 4.5 + pulse, Color(0.2, 0.85, 1.0, 0.9))
        
    # 4. Rosa dos ventos (Norte)
    _minimap_draw.draw_string(ThemeDB.fallback_font, center + Vector2(-3, -radius + 14), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1.0, 0.85, 0.4))
    
    # 5. Posição e Seta de Direção do Jogador
    if player:
        var px: float = player.global_position.x
        var pz: float = player.global_position.z
        var half_zone: float = 80.0
        var norm_x: float = clampf(px / half_zone, -0.92, 0.92)
        var norm_z: float = clampf(pz / half_zone, -0.92, 0.92)
        var p_radar := center + Vector2(norm_x, norm_z) * (radius - 8.0)
        
        # Ponto do herói
        _minimap_draw.draw_circle(p_radar, 4.5, Color(1.0, 0.9, 0.2))
        
        # Seta de orientação
        var rot_y: float = player.rotation.y
        var dir := Vector2(sin(rot_y), -cos(rot_y))
        _minimap_draw.draw_line(p_radar, p_radar + dir * 8.0, Color(1.0, 0.95, 0.6), 2.0)

func _atualizar_grid_mapa_mundi() -> void:
    for c in _grid_container.get_children():
        c.queue_free()
        
    var db: Dictionary = zone_manager._zones_db.get("zones", {}) if zone_manager else {}
    var cur_id: String = _current_zone_data.get("id", "")
    
    for zid in db.keys():
        var zid_str: String = str(zid)
        var z: Dictionary = db[zid_str]
        var btn := Button.new()
        var is_current: bool = (zid_str == cur_id)
        
        var badge_text: String = "📍 VOCÊ ESTÁ AQUI" if is_current else str(z.get("tier", ""))
        btn.text = "%s\n%s" % [str(z.get("name", "")), badge_text]
        btn.custom_minimum_size = Vector2(175, 80)
        
        var style := StyleBoxFlat.new()
        if is_current:
            style.bg_color = Color(0.18, 0.38, 0.55, 0.95)
            style.border_width_bottom = 2
            style.border_width_left = 2
            style.border_width_right = 2
            style.border_width_top = 2
            style.border_color = Color(1.0, 0.85, 0.3)
        else:
            style.bg_color = Color(0.12, 0.16, 0.22, 0.9)
            style.border_width_bottom = 1
            style.border_width_left = 1
            style.border_width_right = 1
            style.border_width_top = 1
            style.border_color = Color(0.3, 0.4, 0.5, 0.6)
            
        style.corner_radius_bottom_left = 8
        style.corner_radius_bottom_right = 8
        style.corner_radius_top_left = 8
        style.corner_radius_top_right = 8
        btn.add_theme_stylebox_override("normal", style)
        
        var target_zid: String = zid_str
        btn.pressed.connect(func():
            if zone_manager and target_zid != cur_id:
                toggle_world_map(false)
                zone_manager.carregar_zona(target_zid, "center")
        )
        
        _grid_container.add_child(btn)
