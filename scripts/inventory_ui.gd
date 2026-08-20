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
var _details_icon: Control
var _details_moldura: PanelContainer
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

## A cor da raridade, que e o que se le primeiro num inventario.
##
## Todo slot tinha a MESMA borda dourada, entao lendario e comum pareciam a
## mesma coisa e a grade virava uma parede de quadrados iguais. Cor por
## raridade e a convencao do genero justamente porque funciona antes da leitura:
## o jogador acha o item bom sem ler nome nenhum.
const CORES_DE_RARIDADE := {
    "Comum": Color(0.62, 0.66, 0.72),
    "Incomum": Color(0.38, 0.78, 0.44),
    "Raro": Color(0.34, 0.62, 0.95),
    "Épico": Color(0.68, 0.42, 0.92),
    "Lendário": Color(0.96, 0.68, 0.22),
}

static func _cor_da_raridade(raridade: String) -> Color:
    return CORES_DE_RARIDADE.get(raridade, CORES_DE_RARIDADE["Comum"])

## Sigla de tres letras a partir do nome do item.
##
## Substitui o emoji. Os icones eram todos emoji, e a fonte do jogo nao tem
## esses simbolos: no celular apareciam como quadradinhos vazios, um atras do
## outro. Tres letras sempre desenham, em qualquer aparelho.
static func _sigla(nome: String) -> String:
    var limpo := nome.strip_edges()
    var partes := limpo.split(" ", false)
    if partes.size() >= 2 and String(partes[0]).length() > 2:
        return (String(partes[0]).substr(0, 2) + String(partes[1]).substr(0, 1)).to_upper()
    return limpo.substr(0, 3).to_upper()

## Moldura de um slot, na cor da raridade.
static func _moldura(raridade: String, preenchido: bool) -> StyleBoxFlat:
    var cor := _cor_da_raridade(raridade)
    var estilo := StyleBoxFlat.new()
    estilo.bg_color = (Color(cor.r, cor.g, cor.b, 0.16) if preenchido
        else Color(0.10, 0.13, 0.18, 0.7))
    var espessura := 2 if preenchido else 1
    estilo.border_width_left = espessura
    estilo.border_width_right = espessura
    estilo.border_width_top = espessura
    estilo.border_width_bottom = espessura
    estilo.border_color = (cor if preenchido else Color(0.28, 0.34, 0.44, 0.55))
    for canto in ["corner_radius_top_left", "corner_radius_top_right",
                  "corner_radius_bottom_left", "corner_radius_bottom_right"]:
        estilo.set(canto, 7)
    estilo.content_margin_left = 4
    estilo.content_margin_right = 4
    return estilo


## Icone desenhado, no lugar do emoji.
##
## Os icones eram todos emoji e a fonte do jogo nao tem esses simbolos: no
## celular saiam como quadradinhos vazios. Desenhar em vetor resolve de vez —
## nao depende de fonte, escala sem borrar em qualquer tela e permite tingir a
## peca pela raridade.
class Icone extends Control:
    var tipo := "caixa"
    var cor := Color(0.8, 0.84, 0.9)

    func _init(qual: String, tinta: Color) -> void:
        tipo = qual
        cor = tinta
        custom_minimum_size = Vector2(30, 30)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var l := minf(size.x, size.y)
        var o := (size - Vector2(l, l)) * 0.5
        var escuro := cor.darkened(0.45)
        var claro := cor.lightened(0.35)

        match tipo:
            "espada":
                # Lamina em losango alongado, guarda e cabo: tres formas simples
                # que juntas ja se leem como espada em trinta pixels.
                draw_colored_polygon(PackedVector2Array([
                    o + Vector2(l * 0.5, l * 0.06), o + Vector2(l * 0.62, l * 0.30),
                    o + Vector2(l * 0.5, l * 0.66), o + Vector2(l * 0.38, l * 0.30)]), claro)
                draw_rect(Rect2(o + Vector2(l * 0.26, l * 0.62), Vector2(l * 0.48, l * 0.08)), escuro)
                draw_rect(Rect2(o + Vector2(l * 0.45, l * 0.70), Vector2(l * 0.10, l * 0.22)), escuro)
            "escudo":
                draw_colored_polygon(PackedVector2Array([
                    o + Vector2(l * 0.5, l * 0.08), o + Vector2(l * 0.86, l * 0.24),
                    o + Vector2(l * 0.72, l * 0.80), o + Vector2(l * 0.5, l * 0.94),
                    o + Vector2(l * 0.28, l * 0.80), o + Vector2(l * 0.14, l * 0.24)]), cor)
                draw_line(o + Vector2(l * 0.5, l * 0.18), o + Vector2(l * 0.5, l * 0.84), escuro, 2.0)
            "elmo":
                draw_circle(o + Vector2(l * 0.5, l * 0.46), l * 0.34, cor)
                draw_rect(Rect2(o + Vector2(l * 0.16, l * 0.46), Vector2(l * 0.68, l * 0.30)), cor)
                draw_rect(Rect2(o + Vector2(l * 0.44, l * 0.30), Vector2(l * 0.12, l * 0.46)), escuro)
            "peitoral":
                draw_colored_polygon(PackedVector2Array([
                    o + Vector2(l * 0.22, l * 0.16), o + Vector2(l * 0.78, l * 0.16),
                    o + Vector2(l * 0.70, l * 0.86), o + Vector2(l * 0.30, l * 0.86)]), cor)
                draw_line(o + Vector2(l * 0.5, l * 0.20), o + Vector2(l * 0.5, l * 0.82), escuro, 2.0)
            "botas":
                draw_rect(Rect2(o + Vector2(l * 0.30, l * 0.12), Vector2(l * 0.24, l * 0.52)), cor)
                draw_rect(Rect2(o + Vector2(l * 0.30, l * 0.62), Vector2(l * 0.48, l * 0.22)), escuro)
            "anel":
                draw_arc(o + Vector2(l * 0.5, l * 0.58), l * 0.28, 0.0, TAU, 22, cor, 3.5)
                draw_circle(o + Vector2(l * 0.5, l * 0.24), l * 0.11, claro)
            "pocao":
                draw_rect(Rect2(o + Vector2(l * 0.42, l * 0.10), Vector2(l * 0.16, l * 0.16)), escuro)
                draw_colored_polygon(PackedVector2Array([
                    o + Vector2(l * 0.38, l * 0.26), o + Vector2(l * 0.62, l * 0.26),
                    o + Vector2(l * 0.78, l * 0.62), o + Vector2(l * 0.70, l * 0.90),
                    o + Vector2(l * 0.30, l * 0.90), o + Vector2(l * 0.22, l * 0.62)]), cor)
                draw_circle(o + Vector2(l * 0.40, l * 0.68), l * 0.07, claro)
            "madeira":
                draw_rect(Rect2(o + Vector2(l * 0.12, l * 0.34), Vector2(l * 0.76, l * 0.32)), cor)
                draw_arc(o + Vector2(l * 0.16, l * 0.50), l * 0.12, 0.0, TAU, 16, escuro, 2.0)
            "minerio":
                draw_colored_polygon(PackedVector2Array([
                    o + Vector2(l * 0.5, l * 0.14), o + Vector2(l * 0.84, l * 0.44),
                    o + Vector2(l * 0.70, l * 0.86), o + Vector2(l * 0.30, l * 0.86),
                    o + Vector2(l * 0.16, l * 0.44)]), cor)
                draw_line(o + Vector2(l * 0.34, l * 0.44), o + Vector2(l * 0.62, l * 0.70), claro, 2.0)
            "cristal":
                draw_colored_polygon(PackedVector2Array([
                    o + Vector2(l * 0.5, l * 0.06), o + Vector2(l * 0.80, l * 0.42),
                    o + Vector2(l * 0.5, l * 0.94), o + Vector2(l * 0.20, l * 0.42)]), cor)
                draw_line(o + Vector2(l * 0.5, l * 0.06), o + Vector2(l * 0.5, l * 0.94), claro, 1.5)
            "carne":
                draw_circle(o + Vector2(l * 0.56, l * 0.46), l * 0.28, cor)
                draw_rect(Rect2(o + Vector2(l * 0.14, l * 0.62), Vector2(l * 0.44, l * 0.10)), claro)
            "pergaminho":
                draw_rect(Rect2(o + Vector2(l * 0.20, l * 0.14), Vector2(l * 0.60, l * 0.72)), cor)
                for i in 3:
                    var y := l * (0.30 + i * 0.16)
                    draw_line(o + Vector2(l * 0.30, y), o + Vector2(l * 0.70, y), escuro, 1.5)
            _:
                draw_rect(Rect2(o + Vector2(l * 0.18, l * 0.18), Vector2(l * 0.64, l * 0.64)), cor)

## A cor natural de cada coisa.
##
## O icone e tingido pelo QUE O ITEM E, e nao pela raridade — a raridade ja esta
## na moldura em volta. Com tudo tingido por raridade, pocao de vida e pocao de
## mana saiam identicas, e o jogador tinha de ler o nome para distinguir duas
## coisas que ele usa em combate, sem tempo de ler.
const CORES_NATURAIS := {
    "espada": Color(0.72, 0.78, 0.88), "escudo": Color(0.55, 0.68, 0.88),
    "elmo": Color(0.66, 0.71, 0.78), "peitoral": Color(0.60, 0.66, 0.76),
    "botas": Color(0.58, 0.42, 0.28), "anel": Color(0.92, 0.78, 0.34),
    "madeira": Color(0.58, 0.40, 0.24), "minerio": Color(0.60, 0.62, 0.66),
    "cristal": Color(0.42, 0.82, 0.92), "carne": Color(0.78, 0.36, 0.28),
    "pergaminho": Color(0.90, 0.86, 0.70),
}

## Cor de uma pocao pelo que ela restaura, nao pela raridade.
static func _cor_da_pocao(item: Dictionary) -> Color:
    var texto := (String(item.get("id", "")) + String(item.get("name", ""))
        + String(item.get("desc", ""))).to_lower()
    if "mana" in texto:
        return Color(0.36, 0.56, 0.95)
    return Color(0.88, 0.28, 0.32)

## A cor com que o icone e desenhado.
static func _cor_do_icone(item: Dictionary, figura: String) -> Color:
    if figura == "pocao":
        return _cor_da_pocao(item)
    return CORES_NATURAIS.get(figura, Color(0.72, 0.76, 0.82))

## Que desenho serve para cada item. Sai do proprio identificador, entao item
## novo so precisa de um nome coerente para ganhar icone.
static func _figura_do_item(item: Dictionary) -> String:
    var chave := String(item.get("id", "")) + " " + String(item.get("name", "")).to_lower()
    for palavra in ["espada", "escudo", "elmo", "peitoral", "botas", "anel",
                    "pocao", "poção", "madeira", "minerio", "minério",
                    "cristal", "carne", "pergaminho"]:
        if palavra in chave:
            match palavra:
                "poção": return "pocao"
                "minério": return "minerio"
                _: return palavra
    if "armadura" in chave: return "peitoral"
    return "caixa"

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
    # Largura pela TELA, nao fixa em 680 px.
    #
    # O painel media 680 px de largura fixa; num celular em pe isso e mais que a
    # tela inteira, e metade do inventario ficava para fora sem jeito de
    # alcancar. Aqui ele ocupa no maximo 92% do que existe.
    var meia: float = minf(340.0, get_viewport_rect().size.x * 0.46)
    _inventory_modal.offset_left = -meia
    _inventory_modal.offset_top = -230.0
    _inventory_modal.offset_right = meia
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
    eq_col.custom_minimum_size = Vector2(0, 0)
    eq_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
    _details_card.custom_minimum_size = Vector2(0, 0)
    _details_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
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
    
    # Moldura do retrato, na cor da raridade do item selecionado.
    _details_moldura = PanelContainer.new()
    _details_moldura.custom_minimum_size = Vector2(0, 88)
    _details_moldura.add_theme_stylebox_override("panel", _moldura("Comum", true))
    det_vbox.add_child(_details_moldura)

    _details_icon = Icone.new("caixa", Color(0.6, 0.66, 0.74))
    _details_icon.custom_minimum_size = Vector2(0, 80)
    _details_moldura.add_child(_details_icon)
    
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
    _gold_label.text = "%s de ouro" % str(gold_amount)
    
    for c in _equipment_grid.get_children():
        c.queue_free()
        
    for slot_name in equipped_slots.keys():
        var eq_data: Dictionary = equipped_slots[slot_name]
        var raridade := String(eq_data.get("rarity", "Comum"))
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(78, 56)
        btn.add_theme_font_size_override("font_size", 10)
        btn.add_theme_color_override("font_color", _cor_da_raridade(raridade).lightened(0.3))
        btn.tooltip_text = String(eq_data.get("name", ""))
        var moldura := _moldura(raridade, true)
        btn.add_theme_stylebox_override("normal", moldura)
        btn.add_theme_stylebox_override("hover", moldura)
        btn.add_theme_stylebox_override("pressed", moldura)
        
        var captured_item: Dictionary = eq_data
        btn.pressed.connect(func(): _exibir_detalhes_item(captured_item, true))
        _equipment_grid.add_child(btn)
        _vestir_slot(btn, eq_data, slot_name, raridade)
        
    for c in _inventory_grid.get_children():
        c.queue_free()
        
    for i in range(20):
        var vazio := i >= bag_items.size()
        var item: Dictionary = {} if vazio else bag_items[i]
        var raridade := String(item.get("rarity", "Comum"))

        var btn := Button.new()
        btn.custom_minimum_size = Vector2(60, 60)
        var moldura := _moldura(raridade, not vazio)
        btn.add_theme_stylebox_override("normal", moldura)
        btn.add_theme_stylebox_override("hover", moldura)
        btn.add_theme_stylebox_override("pressed", moldura)
        _inventory_grid.add_child(btn)

        if vazio:
            btn.disabled = true
            # Vazio precisa APARECER. Invisivel, a mochila parecia ter sete
            # lugares em vez de vinte, e nao se ve quanto espaco ainda ha.
            var oco := _moldura("Comum", false)
            oco.bg_color = Color(0.09, 0.11, 0.15, 0.55)
            oco.border_color = Color(0.26, 0.32, 0.42, 0.75)
            btn.add_theme_stylebox_override("normal", oco)
            btn.add_theme_stylebox_override("disabled", oco)
            continue

        _vestir_slot(btn, item, "", raridade)
        var guardado: Dictionary = item
        btn.pressed.connect(func(): _exibir_detalhes_item(guardado, false))

## Poe dentro do botao o icone desenhado, o rotulo e a quantidade.
##
## Tudo entra como filho que IGNORA o mouse: se qualquer um deles capturasse o
## clique, o botao embaixo pararia de responder e o slot ficaria morto.
func _vestir_slot(botao: Button, item: Dictionary, rotulo: String, raridade: String) -> void:
    var cor := _cor_da_raridade(raridade)

    var figura := _figura_do_item(item)
    var icone := Icone.new(figura, _cor_do_icone(item, figura))
    icone.set_anchors_preset(Control.PRESET_FULL_RECT)
    icone.offset_left = 8
    icone.offset_right = -8
    icone.offset_top = 5
    icone.offset_bottom = -16 if rotulo != "" else -12
    botao.add_child(icone)

    if rotulo != "":
        var nome := Label.new()
        nome.text = rotulo
        nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        nome.add_theme_font_size_override("font_size", 9)
        nome.add_theme_color_override("font_color", cor.lightened(0.35))
        nome.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        nome.offset_top = -14
        nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
        botao.add_child(nome)

    var quantos := int(item.get("qtd", 1))
    if quantos > 1:
        var conta := Label.new()
        conta.text = str(quantos)
        conta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        conta.add_theme_font_size_override("font_size", 11)
        conta.add_theme_color_override("font_color", Color(0.97, 0.95, 0.88))
        conta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
        conta.add_theme_constant_override("outline_size", 4)
        conta.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        conta.offset_top = -16
        conta.offset_right = -5
        conta.mouse_filter = Control.MOUSE_FILTER_IGNORE
        botao.add_child(conta)

    botao.tooltip_text = String(item.get("name", ""))

func _exibir_detalhes_item(item: Dictionary, is_equipped: bool) -> void:
    var cor_item := _cor_da_raridade(String(item.get("rarity", "Comum")))
    if _details_icon:
        var figura_det := _figura_do_item(item)
        _details_icon.tipo = figura_det
        _details_icon.cor = _cor_do_icone(item, figura_det)
        _details_icon.queue_redraw()
    if _details_moldura:
        _details_moldura.add_theme_stylebox_override(
            "panel", _moldura(String(item.get("rarity", "Comum")), true))
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
