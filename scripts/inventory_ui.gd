extends Control
class_name InventoryUI

signal item_used(item_id: String)
signal item_equipped(item_id: String, slot: String)

var _modal_backdrop: ColorRect
var _inventory_modal: PanelContainer
var _equipment_grid: GridContainer
var _inventory_grid: GridContainer
var _gold_label: Label
var _details_card: PanelContainer
var _details_icon: Label
var _details_title: Label
var _details_tier: Label
var _details_stats: Label
var _details_desc: Label
var _btn_action: Button
var _selected_item: Dictionary = {}

var gold_amount: int = 1450

var equipped_slots := {
    "Elmo": {"id": "elmo_ferro", "name": "Elmo de Aço T4", "icon": "🪖", "tier": "Tier IV", "rarity": "Raro", "stats": "+35 Defesa  •  +120 Vida", "desc": "Forjado com aço puro das montanhas de Acordelot."},
    "Peitoral": {"id": "peitoral_guardiao", "name": "Armadura do Guardião", "icon": "🛡️", "tier": "Tier V", "rarity": "Épico", "stats": "+85 Defesa  •  +350 Vida", "desc": "Placas de mitral reforçadas com encantamento de proteção."},
    "Botas": {"id": "botas_couro", "name": "Botas de Andarilho", "icon": "👢", "tier": "Tier IV", "rarity": "Raro", "stats": "+22 Defesa  •  +14% Velocidade", "desc": "Couro resistente que garante agilidade em terrenos acidentados."},
    "Arma": {"id": "espada_akles", "name": "Espada de Akles", "icon": "⚔️", "tier": "Tier V", "rarity": "Lendário", "stats": "+125 Dano Físico  •  +18% Crítico", "desc": "Lâmina ancestral imbuída com o poder dos mestres da música."},
    "Escudo": {"id": "escudo_nobre", "name": "Escudo Imperial", "icon": "🔰", "tier": "Tier IV", "rarity": "Raro", "stats": "+45 Bloqueio  •  +90 Vida", "desc": "Escudo brasonado com a insígnia da Cidade Nobre."},
    "Anel": {"id": "anel_arcano", "name": "Anel da Floresta", "icon": "💍", "tier": "Tier IV", "rarity": "Raro", "stats": "+60 Mana  •  +10% Regen", "desc": "Gema de safira sintonizada com os fluxos de mana."}
}

var bag_items: Array = [
    {"id": "pocao_cura_g", "name": "Poção de Vida Maior", "icon": "🧪", "qtd": 5, "tier": "Tier IV", "rarity": "Incomum", "desc": "Restaura 450 pontos de vida instantaneamente.", "tipo": "consumivel"},
    {"id": "pocao_mana_g", "name": "Poção de Mana Maior", "icon": "✨", "qtd": 8, "tier": "Tier IV", "rarity": "Incomum", "desc": "Restaura 300 pontos de mana arcana.", "tipo": "consumivel"},
    {"id": "madeira_carvalho", "name": "Madeira de Carvalho", "icon": "🪵", "qtd": 32, "tier": "Tier IV", "rarity": "Comum", "desc": "Material nobre para forjas e construções.", "tipo": "material"},
    {"id": "minerio_ferro", "name": "Minério de Ferro", "icon": "⛏️", "qtd": 24, "tier": "Tier IV", "rarity": "Comum", "desc": "Minério bruto para barras de aço.", "tipo": "material"},
    {"id": "cristal_arcano", "name": "Cristal de Mana", "icon": "💎", "qtd": 7, "tier": "Tier V", "rarity": "Raro", "desc": "Gema pulsante usada em encantamentos.", "tipo": "material"},
    {"id": "carne_assada", "name": "Carne Assada", "icon": "🍖", "qtd": 12, "tier": "Tier III", "rarity": "Comum", "desc": "Alimento suculento que recupera 200 de vida.", "tipo": "consumivel"},
    {"id": "pergaminho_teleporte", "name": "Pergaminho de Retorno", "icon": "📜", "qtd": 3, "tier": "Tier IV", "rarity": "Raro", "desc": "Teleporta o herói para os portões da Capital.", "tipo": "consumivel"}
]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _construir_interface_inventario()

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

func _construir_interface_inventario() -> void:
    # 1. Fundo Escurecido com Blur
    _modal_backdrop = ColorRect.new()
    _modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    _modal_backdrop.color = Color(0.02, 0.03, 0.06, 0.78)
    _modal_backdrop.visible = false
    _modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _modal_backdrop.gui_input.connect(func(ev: InputEvent):
        if ev is InputEventMouseButton and ev.pressed:
            toggle_inventory(false)
    )
    add_child(_modal_backdrop)
    
    # 2. Painel Central Glassmorphism com Borda Dourada Nobre
    _inventory_modal = PanelContainer.new()
    _inventory_modal.set_anchors_preset(Control.PRESET_CENTER)
    _inventory_modal.anchor_left = 0.5
    _inventory_modal.anchor_right = 0.5
    _inventory_modal.anchor_top = 0.5
    _inventory_modal.anchor_bottom = 0.5
    _inventory_modal.offset_left = -340.0
    _inventory_modal.offset_top = -230.0
    _inventory_modal.offset_right = 340.0
    _inventory_modal.offset_bottom = 230.0
    _inventory_modal.visible = false
    _inventory_modal.mouse_filter = Control.MOUSE_FILTER_STOP
    
    var panel_box := StyleBoxFlat.new()
    panel_box.bg_color = Color(0.08, 0.10, 0.14, 0.96)
    panel_box.border_width_left = 2
    panel_box.border_width_right = 2
    panel_box.border_width_top = 2
    panel_box.border_width_bottom = 2
    panel_box.border_color = Color(0.85, 0.72, 0.35, 0.9)
    panel_box.corner_radius_top_left = 14
    panel_box.corner_radius_top_right = 14
    panel_box.corner_radius_bottom_left = 14
    panel_box.corner_radius_bottom_right = 14
    panel_box.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
    panel_box.shadow_size = 18
    _inventory_modal.add_theme_stylebox_override("panel", panel_box)
    add_child(_inventory_modal)
    
    var pad := MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 18)
    pad.add_theme_constant_override("margin_right", 18)
    pad.add_theme_constant_override("margin_top", 16)
    pad.add_theme_constant_override("margin_bottom", 16)
    _inventory_modal.add_child(pad)
    
    var root_vbox := VBoxContainer.new()
    root_vbox.add_theme_constant_override("separation", 14)
    pad.add_child(root_vbox)
    
    # 3. Cabeçalho Nobre
    var header := HBoxContainer.new()
    root_vbox.add_child(header)
    
    var title := Label.new()
    title.text = "🎒  INVENTÁRIO DO HERÓI"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 16)
    title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
    header.add_child(title)
    
    _gold_label = Label.new()
    _gold_label.text = "🪙 1.450 Ouro"
    _gold_label.add_theme_font_size_override("font_size", 14)
    _gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    header.add_child(_gold_label)
    
    var btn_close := Button.new()
    btn_close.text = "  ✕  "
    btn_close.add_theme_font_size_override("font_size", 13)
    btn_close.pressed.connect(func(): toggle_inventory(false))
    header.add_child(btn_close)
    
    # Linha divisória
    var div := HSeparator.new()
    root_vbox.add_child(div)
    
    # 4. Três Colunas: [Equipamentos] | [Mochila 4x5] | [Detalhes do Item]
    var content := HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 16)
    root_vbox.add_child(content)
    
    # Coluna 1: Equipados
    var eq_col := VBoxContainer.new()
    eq_col.custom_minimum_size = Vector2(170, 0)
    eq_col.add_theme_constant_override("separation", 8)
    content.add_child(eq_col)
    
    var eq_title := Label.new()
    eq_title.text = "🛡️  Equipamentos"
    eq_title.add_theme_font_size_override("font_size", 13)
    eq_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    eq_col.add_child(eq_title)
    
    _equipment_grid = GridContainer.new()
    _equipment_grid.columns = 2
    _equipment_grid.add_theme_constant_override("h_separation", 8)
    _equipment_grid.add_theme_constant_override("v_separation", 8)
    eq_col.add_child(_equipment_grid)
    
    # Coluna 2: Mochila
    var bag_col := VBoxContainer.new()
    bag_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bag_col.add_theme_constant_override("separation", 8)
    content.add_child(bag_col)
    
    var bag_title := Label.new()
    bag_title.text = "📦  Mochila (20 Slots)"
    bag_title.add_theme_font_size_override("font_size", 13)
    bag_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    bag_col.add_child(bag_title)
    
    _inventory_grid = GridContainer.new()
    _inventory_grid.columns = 4
    _inventory_grid.add_theme_constant_override("h_separation", 8)
    _inventory_grid.add_theme_constant_override("v_separation", 8)
    bag_col.add_child(_inventory_grid)
    
    # Coluna 3: Card de Detalhes
    _details_card = PanelContainer.new()
    _details_card.custom_minimum_size = Vector2(190, 0)
    
    var card_box := StyleBoxFlat.new()
    card_box.bg_color = Color(0.12, 0.15, 0.20, 0.9)
    card_box.border_width_left = 1
    card_box.border_width_right = 1
    card_box.border_width_top = 1
    card_box.border_width_bottom = 1
    card_box.border_color = Color(0.35, 0.45, 0.58, 0.7)
    card_box.corner_radius_top_left = 8
    card_box.corner_radius_top_right = 8
    card_box.corner_radius_bottom_left = 8
    card_box.corner_radius_bottom_right = 8
    _details_card.add_theme_stylebox_override("panel", card_box)
    content.add_child(_details_card)
    
    var card_margin := MarginContainer.new()
    card_margin.add_theme_constant_override("margin_left", 12)
    card_margin.add_theme_constant_override("margin_right", 12)
    card_margin.add_theme_constant_override("margin_top", 12)
    card_margin.add_theme_constant_override("margin_bottom", 12)
    _details_card.add_child(card_margin)
    
    var det_vbox := VBoxContainer.new()
    det_vbox.add_theme_constant_override("separation", 8)
    card_margin.add_child(det_vbox)
    
    _details_icon = Label.new()
    _details_icon.text = "📦"
    _details_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _details_icon.add_theme_font_size_override("font_size", 32)
    det_vbox.add_child(_details_icon)
    
    _details_title = Label.new()
    _details_title.text = "Selecione um item"
    _details_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _details_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details_title.add_theme_font_size_override("font_size", 13)
    _details_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
    det_vbox.add_child(_details_title)
    
    _details_tier = Label.new()
    _details_tier.text = ""
    _details_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _details_tier.add_theme_font_size_override("font_size", 11)
    _details_tier.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
    det_vbox.add_child(_details_tier)
    
    _details_stats = Label.new()
    _details_stats.text = ""
    _details_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details_stats.add_theme_font_size_override("font_size", 11)
    _details_stats.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
    det_vbox.add_child(_details_stats)
    
    _details_desc = Label.new()
    _details_desc.text = "Clique em qualquer item equipado ou na mochila para inspecionar seus atributos."
    _details_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _details_desc.add_theme_font_size_override("font_size", 10)
    _details_desc.add_theme_color_override("font_color", Color(0.75, 0.80, 0.85))
    det_vbox.add_child(_details_desc)
    
    _btn_action = Button.new()
    _btn_action.text = "Usar Item"
    _btn_action.visible = false
    _btn_action.custom_minimum_size = Vector2(0, 34)
    _btn_action.pressed.connect(_on_action_button_pressed)
    det_vbox.add_child(_btn_action)

func _atualizar_ui_inventario() -> void:
    _gold_label.text = "🪙 %s Ouro" % str(gold_amount)
    
    for c in _equipment_grid.get_children():
        c.queue_free()
        
    for slot_name in equipped_slots.keys():
        var eq_data: Dictionary = equipped_slots[slot_name]
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(76, 54)
        btn.text = "%s\n%s" % [eq_data.get("icon", ""), slot_name]
        btn.add_theme_font_size_override("font_size", 11)
        
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.14, 0.18, 0.25, 0.95)
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.border_color = Color(0.9, 0.75, 0.3, 0.9)
        style.corner_radius_top_left = 6
        style.corner_radius_top_right = 6
        style.corner_radius_bottom_left = 6
        style.corner_radius_bottom_right = 6
        btn.add_theme_stylebox_override("normal", style)
        
        var captured_item: Dictionary = eq_data
        btn.pressed.connect(func(): _exibir_detalhes_item(captured_item, true))
        _equipment_grid.add_child(btn)
        
    for c in _inventory_grid.get_children():
        c.queue_free()
        
    for i in range(20):
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(58, 54)
        
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.10, 0.13, 0.18, 0.85)
        style.border_width_left = 1
        style.border_width_right = 1
        style.border_width_top = 1
        style.border_width_bottom = 1
        style.border_color = Color(0.3, 0.38, 0.48, 0.6)
        style.corner_radius_top_left = 6
        style.corner_radius_top_right = 6
        style.corner_radius_bottom_left = 6
        style.corner_radius_bottom_right = 6
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
    _details_icon.text = str(item.get("icon", "📦"))
    _details_title.text = str(item.get("name", "Item"))
    _details_tier.text = "%s  •  %s" % [str(item.get("tier", "T IV")), str(item.get("rarity", "Comum"))]
    _details_stats.text = str(item.get("stats", ""))
    _details_desc.text = str(item.get("desc", "Item nobre das terras de Acordelot."))
    
    if item.get("tipo", "") == "consumivel":
        _btn_action.visible = true
        _btn_action.text = "🧪 Consumir"
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
