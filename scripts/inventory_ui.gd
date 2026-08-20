extends Control
class_name InventoryUI

signal item_used(item_id: String)
signal item_equipped(item_id: String, slot: String)

var _modal_backdrop: ColorRect
var _inventory_modal: PanelContainer
var _equipment_grid: GridContainer
var _inventory_grid: GridContainer
var _gold_label: Label
var _details_title: Label
var _details_desc: Label
var _details_stats: Label
var _btn_action: Button
var _selected_item: Dictionary = {}
var _inv_bg_tex: Texture2D

var gold_amount: int = 1450

var equipped_slots := {
    "Elmo": {"id": "elmo_ferro", "name": "Capacete de Ferro", "icon": "🪖", "tier": "Tier IV", "rarity": "Raro", "stats": "+35 Defesa\n+120 Vida"},
    "Peitoral": {"id": "peitoral_guardiao", "name": "Armadura do Guardião", "icon": "🛡️", "tier": "Tier V", "rarity": "Épico", "stats": "+85 Defesa\n+350 Vida"},
    "Botas": {"id": "botas_couro", "name": "Botas de Andarilho", "icon": "👢", "tier": "Tier IV", "rarity": "Raro", "stats": "+22 Defesa\n+12% Velocidade"},
    "Arma": {"id": "espada_akles", "name": "Espada de Akles", "icon": "⚔️", "tier": "Tier V", "rarity": "Lendário", "stats": "+125 Dano Físico\n+18% Crítico"},
    "Escudo": {"id": "escudo_nobre", "name": "Escudo Imperial", "icon": "🔰", "tier": "Tier IV", "rarity": "Raro", "stats": "+45 Bloqueio\n+80 Vida"},
    "Anel": {"id": "anel_arcano", "name": "Anel da Floresta", "icon": "💍", "tier": "Tier IV", "rarity": "Raro", "stats": "+50 Mana\n+8% Regen Vida"}
}

var bag_items: Array = [
    {"id": "pocao_cura_g", "name": "Poção de Vida Maior", "icon": "🧪", "qtd": 5, "tier": "Tier IV", "rarity": "Incomum", "desc": "Restaura 450 pontos de vida instantaneamente.", "tipo": "consumivel"},
    {"id": "pocao_mana_g", "name": "Poção de Mana Maior", "icon": "✨", "qtd": 8, "tier": "Tier IV", "rarity": "Incomum", "desc": "Restaura 300 pontos de mana arcana.", "tipo": "consumivel"},
    {"id": "madeira_carvalho", "name": "Madeira de Carvalho", "icon": "🪵", "qtd": 32, "tier": "Tier IV", "rarity": "Comum", "desc": "Material nobre para forjas e construções.", "tipo": "material"},
    {"id": "minerio_ferro", "name": "Minério de Ferro", "icon": "⛏️", "qtd": 24, "tier": "Tier IV", "rarity": "Comum", "desc": "Minério bruto para barras de aço.", "tipo": "material"},
    {"id": "cristal_arcano", "name": "Cristal de Mana", "icon": "💎", "qtd": 7, "tier": "Tier V", "rarity": "Raro", "desc": "Gema pulsante usada em encantamentos.", "tipo": "material"},
    {"id": "carne_assada", "name": "Carne Assada", "icon": "🍖", "qtd": 12, "tier": "Tier III", "rarity": "Comum", "desc": "Alimento que regenera vida gradualmente.", "tipo": "consumivel"},
    {"id": "pergaminho_teleporte", "name": "Pergaminho de Retorno", "icon": "📜", "qtd": 3, "tier": "Tier IV", "rarity": "Raro", "desc": "Teleporta o herói para os portões da Capital.", "tipo": "consumivel"}
]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _inv_bg_tex = load("res://textures/ui/inventory_bg.png")
    _criar_modal_inventario()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_I, KEY_B]:
            toggle_inventory()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE and _inventory_modal.visible:
            toggle_inventory(false)
            get_viewport().set_input_as_handled()

func toggle_inventory(force_state = null) -> void:
    var next_state: bool = (not _inventory_modal.visible) if force_state == null else force_state
    _inventory_modal.visible = next_state
    _modal_backdrop.visible = next_state
    if next_state:
        _atualizar_ui_inventario()

func _criar_modal_inventario() -> void:
    _modal_backdrop = ColorRect.new()
    _modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    _modal_backdrop.color = Color(0.02, 0.03, 0.05, 0.75)
    _modal_backdrop.visible = false
    _modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _modal_backdrop.gui_input.connect(func(ev: InputEvent):
        if ev is InputEventMouseButton and ev.pressed:
            toggle_inventory(false)
    )
    add_child(_modal_backdrop)
    
    # Painel com a Arte Original de Fundo (inventory_bg.png)
    _inventory_modal = PanelContainer.new()
    _inventory_modal.anchor_left = 0.5
    _inventory_modal.anchor_right = 0.5
    _inventory_modal.anchor_top = 0.5
    _inventory_modal.anchor_bottom = 0.5
    _inventory_modal.offset_left = -350.0
    _inventory_modal.offset_top = -250.0
    _inventory_modal.offset_right = 350.0
    _inventory_modal.offset_bottom = 250.0
    _inventory_modal.visible = false
    _inventory_modal.mouse_filter = Control.MOUSE_FILTER_STOP
    
    var panel_style := StyleBoxTexture.new()
    if _inv_bg_tex:
        panel_style.texture = _inv_bg_tex
    else:
        var fb := StyleBoxFlat.new()
        fb.bg_color = Color(0.07, 0.09, 0.13, 0.98)
        _inventory_modal.add_theme_stylebox_override("panel", fb)
    if _inv_bg_tex:
        _inventory_modal.add_theme_stylebox_override("panel", panel_style)
    add_child(_inventory_modal)
    
    var main_margin := MarginContainer.new()
    main_margin.add_theme_constant_override("margin_top", 45)
    main_margin.add_theme_constant_override("margin_bottom", 25)
    main_margin.add_theme_constant_override("margin_left", 35)
    main_margin.add_theme_constant_override("margin_right", 35)
    _inventory_modal.add_child(main_margin)
    
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    main_margin.add_child(vbox)
    
    var header := HBoxContainer.new()
    vbox.add_child(header)
    
    var title := Label.new()
    title.text = "🎒 INVENTÁRIO DO HERÓI"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 15)
    title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
    header.add_child(title)
    
    _gold_label = Label.new()
    _gold_label.text = "🪙 1.450 Ouro"
    _gold_label.add_theme_font_size_override("font_size", 13)
    _gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    header.add_child(_gold_label)
    
    var btn_close := Button.new()
    btn_close.text = " ✕ "
    btn_close.pressed.connect(func(): toggle_inventory(false))
    header.add_child(btn_close)
    
    var content := HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 14)
    vbox.add_child(content)
    
    # 1. Equipamentos
    var eq_vbox := VBoxContainer.new()
    eq_vbox.custom_minimum_size = Vector2(165, 0)
    content.add_child(eq_vbox)
    
    var lbl_eq := Label.new()
    lbl_eq.text = "🛡️ Equipados"
    lbl_eq.add_theme_font_size_override("font_size", 12)
    lbl_eq.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    eq_vbox.add_child(lbl_eq)
    
    _equipment_grid = GridContainer.new()
    _equipment_grid.columns = 2
    _equipment_grid.add_theme_constant_override("h_separation", 6)
    _equipment_grid.add_theme_constant_override("v_separation", 6)
    eq_vbox.add_child(_equipment_grid)
    
    # 2. Mochila
    var bag_vbox := VBoxContainer.new()
    bag_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(bag_vbox)
    
    var lbl_bag := Label.new()
    lbl_bag.text = "📦 Mochila de Itens"
    lbl_bag.add_theme_font_size_override("font_size", 12)
    lbl_bag.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    bag_vbox.add_child(lbl_bag)
    
    var scroll_bag := ScrollContainer.new()
    scroll_bag.size_flags_vertical = Control.SIZE_EXPAND_FILL
    bag_vbox.add_child(scroll_bag)
    
    _inventory_grid = GridContainer.new()
    _inventory_grid.columns = 4
    _inventory_grid.add_theme_constant_override("h_separation", 6)
    _inventory_grid.add_theme_constant_override("v_separation", 6)
    scroll_bag.add_child(_inventory_grid)
    
    # 3. Detalhes
    var det_vbox := VBoxContainer.new()
    det_vbox.custom_minimum_size = Vector2(170, 0)
    det_vbox.add_theme_constant_override("separation", 6)
    content.add_child(det_vbox)
    
    _details_title = Label.new()
    _details_title.text = "Selecione um item"
    _details_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details_title.add_theme_font_size_override("font_size", 12)
    _details_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
    det_vbox.add_child(_details_title)
    
    _details_stats = Label.new()
    _details_stats.text = ""
    _details_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details_stats.add_theme_font_size_override("font_size", 11)
    _details_stats.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
    det_vbox.add_child(_details_stats)
    
    _details_desc = Label.new()
    _details_desc.text = ""
    _details_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _details_desc.add_theme_font_size_override("font_size", 11)
    _details_desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
    det_vbox.add_child(_details_desc)
    
    _btn_action = Button.new()
    _btn_action.text = "Usar Item"
    _btn_action.visible = false
    _btn_action.pressed.connect(_on_action_button_pressed)
    det_vbox.add_child(_btn_action)

func _atualizar_ui_inventario() -> void:
    _gold_label.text = "🪙 %s Ouro" % str(gold_amount)
    
    for c in _equipment_grid.get_children():
        c.queue_free()
        
    for slot_name in equipped_slots.keys():
        var eq_data: Dictionary = equipped_slots[slot_name]
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(76, 52)
        btn.text = "%s\n%s" % [eq_data.get("icon", ""), slot_name]
        btn.add_theme_font_size_override("font_size", 10)
        
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.1, 0.14, 0.2, 0.9)
        style.border_width_bottom = 2
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_width_top = 2
        style.border_color = Color(0.9, 0.75, 0.3)
        style.corner_radius_bottom_left = 6
        style.corner_radius_bottom_right = 6
        style.corner_radius_top_left = 6
        style.corner_radius_top_right = 6
        btn.add_theme_stylebox_override("normal", style)
        
        var captured_item: Dictionary = eq_data
        btn.pressed.connect(func(): _exibir_detalhes_item(captured_item, true))
        _equipment_grid.add_child(btn)
        
    for c in _inventory_grid.get_children():
        c.queue_free()
        
    for i in range(20):
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(58, 50)
        
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.08, 0.1, 0.15, 0.85)
        style.border_width_bottom = 1
        style.border_width_left = 1
        style.border_width_right = 1
        style.border_width_top = 1
        style.border_color = Color(0.3, 0.38, 0.46, 0.6)
        style.corner_radius_bottom_left = 6
        style.corner_radius_bottom_right = 6
        style.corner_radius_top_left = 6
        style.corner_radius_top_right = 6
        btn.add_theme_stylebox_override("normal", style)
        
        if i < bag_items.size():
            var item: Dictionary = bag_items[i]
            var qtd_txt := " (%d)" % int(item.get("qtd", 1)) if item.get("qtd", 1) > 1 else ""
            btn.text = "%s%s" % [item.get("icon", "📦"), qtd_txt]
            btn.add_theme_font_size_override("font_size", 13)
            
            var captured: Dictionary = item
            btn.pressed.connect(func(): _exibir_detalhes_item(captured, false))
        else:
            btn.text = ""
            btn.disabled = true
            
        _inventory_grid.add_child(btn)

func _exibir_detalhes_item(item: Dictionary, is_equipped: bool) -> void:
    _selected_item = item
    _details_title.text = "%s %s\n[%s - %s]" % [item.get("icon", ""), item.get("name", "Item"), item.get("tier", "T IV"), item.get("rarity", "Comum")]
    _details_stats.text = item.get("stats", "")
    _details_desc.text = item.get("desc", "Equipamento nobre forjado nos reinos de Acordelot.")
    
    if item.get("tipo", "") == "consumivel":
        _btn_action.visible = true
        _btn_action.text = "Consumir"
    elif is_equipped:
        _btn_action.visible = true
        _btn_action.text = "Desequipar"
    else:
        _btn_action.visible = false

func _on_action_button_pressed() -> void:
    if _selected_item.is_empty():
        return
    if _selected_item.get("tipo", "") == "consumivel":
        var qtd: int = int(_selected_item.get("qtd", 1))
        if qtd > 1:
            _selected_item["qtd"] = qtd - 1
        else:
            bag_items.erase(_selected_item)
        item_used.emit(str(_selected_item.get("id", "")))
        _atualizar_ui_inventario()
