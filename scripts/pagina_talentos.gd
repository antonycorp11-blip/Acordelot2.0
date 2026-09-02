extends Control
class_name PaginaTalentos

## Quatro trilhas no desenho Stitch. So gasta pontos reais do Progresso; os
## marcos nao prometem passivas que ainda nao existem no combate.
const P := preload("res://scripts/ui_proto.gd")
const TALENTOS := [
    ["ataque_basico", "Cadencia Afiada", "Aprimora o golpe basico e a sincronia entre ataques.", "res://textures/ui/btn_ataque.png", Color("39bdf8")],
    ["skill_1", "Lamina Vibrante", "Converte ressonancia em uma aura defensiva ao redor do heroi.", "res://textures/ui/btn_skill1.png", Color("58d6c2")],
    ["skill_2", "Espada Gigante", "Amplia a lamina e alcanca varios inimigos no mesmo compasso.", "res://textures/ui/btn_skill2.png", Color("e6b94d")],
    ["skill_3", "Raio Harmonico", "Dispara um feixe harmonico que atravessa a linha inimiga.", "res://textures/ui/btn_skill3.png", Color("49c7ff")],
]

var _progresso: Node
var _escolhido := "skill_3"
var _pontos: Label
var _cartoes: Dictionary = {}
var _arte: TextureRect
var _det_nome: Label
var _det_nivel: Label
var _det_texto: Label
var _marcos: VBoxContainer
var _aprimorar: Button
var _custo: Label

func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)

func ao_abrir() -> void: _pintar()

func subtitulo_da_pagina() -> String: return "Trilhas de ressonancia"

func cabecalho_extra() -> Control:
    var caixa := HBoxContainer.new()
    caixa.add_theme_constant_override("separation", 10)
    caixa.add_child(P.sobrancelha("TRILHAS DE RESSONANCIA"))
    _pontos = P.rotulo("", 14, P.GOLD_BRIGHT)
    caixa.add_child(_pontos)
    return caixa

func _montar() -> void:
    var raiz := VBoxContainer.new()
    raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
    raiz.add_theme_constant_override("separation", 12)
    add_child(raiz)
    var lema := P.rotulo("Escolha um caminho. A harmonia que voce aprimora hoje molda o amanha.", 14, P.GOLD_BRIGHT)
    lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lema.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    raiz.add_child(lema)
    var corpo := HBoxContainer.new()
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    corpo.add_theme_constant_override("separation", 18)
    raiz.add_child(corpo)
    var trilhas := HBoxContainer.new()
    trilhas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    trilhas.add_theme_constant_override("separation", 12)
    corpo.add_child(trilhas)
    for dados in TALENTOS: trilhas.add_child(_cartao(dados))
    corpo.add_child(_montar_detalhe())

func _cartao(dados: Array) -> Button:
    var id := String(dados[0])
    var b := P.botao("", "item")
    b.custom_minimum_size = Vector2(210, 0)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.clip_contents = true
    b.pressed.connect(_escolher.bind(id))
    var col := VBoxContainer.new()
    col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
    col.alignment = BoxContainer.ALIGNMENT_CENTER
    col.add_theme_constant_override("separation", 9)
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(col)
    var halo := PanelContainer.new()
    halo.custom_minimum_size = Vector2(150, 150)
    halo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    halo.add_theme_stylebox_override("panel", P.estilo(Color("07152ae8"), Color(dados[4]), 2, 75))
    var img := P.arte(String(dados[3]), Vector2(124, 124))
    img.modulate = Color(1.15, 1.15, 1.22, 1)
    halo.add_child(img)
    col.add_child(halo)
    var nome := P.rotulo(String(dados[1]).to_upper(), 14, P.GOLD_BRIGHT, true)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nome.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    col.add_child(nome)
    var desc := P.rotulo(String(dados[2]), 10, P.MUTED, true)
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc.custom_minimum_size.y = 98
    col.add_child(desc)
    col.add_child(P.espaco_elastico())
    var marcos := HBoxContainer.new()
    marcos.alignment = BoxContainer.ALIGNMENT_CENTER
    marcos.add_theme_constant_override("separation", 14)
    for nivel in [3, 6, 9]:
        var selo := P.rotulo("◇\nNV.%d" % nivel, 9, P.MUTED)
        selo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        marcos.add_child(selo)
    col.add_child(marcos)
    _cartoes[id] = b
    return b

func _montar_detalhe() -> Control:
    var painel := P.painel(Color("07152af2"))
    painel.custom_minimum_size.x = 430
    var rolagem := ScrollContainer.new()
    rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    painel.add_child(rolagem)
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 10)
    rolagem.add_child(P.recheio(col, 18))
    _arte = P.arte("", Vector2(120, 120))
    _arte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    col.add_child(_arte)
    _det_nome = P.rotulo("", 25, P.GOLD_BRIGHT)
    _det_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _det_nome.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    col.add_child(_det_nome)
    _det_nivel = P.rotulo("", 11, P.CYAN)
    _det_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(_det_nivel)
    _det_texto = P.rotulo("", 12, P.IVORY, true)
    _det_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _det_texto.custom_minimum_size.y = 58
    col.add_child(_det_texto)
    col.add_child(P.risco())
    var titulo := P.sobrancelha("MARCOS DA TRILHA")
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(titulo)
    _marcos = VBoxContainer.new()
    _marcos.add_theme_constant_override("separation", 5)
    col.add_child(_marcos)
    col.add_child(P.espaco_elastico())
    _aprimorar = P.botao("APRIMORAR", "gold")
    _aprimorar.custom_minimum_size.y = 54
    _aprimorar.pressed.connect(_subir)
    col.add_child(_aprimorar)
    _custo = P.rotulo("", 11, P.GOLD_BRIGHT)
    _custo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(_custo)
    return painel

func _escolher(id: String) -> void:
    _escolhido = id
    _pintar()

func _subir() -> void:
    if _progresso: _progresso.subir_skill(_escolhido)

func _dados(id: String) -> Array:
    for dados in TALENTOS:
        if String(dados[0]) == id: return dados
    return TALENTOS[0]

func _pintar() -> void:
    if _progresso == null or _arte == null: return
    var livres: int = _progresso.pontos_de_skill_disponiveis()
    if _pontos: _pontos.text = "♪  %d PONTO%s" % [livres, "S" if livres != 1 else ""]
    for id in _cartoes:
        var b: Button = _cartoes[id]
        var ativo := String(id) == _escolhido
        b.add_theme_stylebox_override("normal", P.estilo(Color("10264ae8") if ativo else Color("07101fdc"), P.GOLD_BRIGHT if ativo else Color("806439"), 2 if ativo else 1, 3))
    var dados := _dados(_escolhido)
    var nivel: int = int(_progresso.niveis_skills.get(_escolhido, 1))
    var teto: int = int(_progresso.NIVEL_MAXIMO_SKILL)
    var liberado: bool = _progresso.skill_desbloqueada(_escolhido)
    _arte.texture = load(String(dados[3]))
    _det_nome.text = String(dados[1]).to_upper()
    _det_nivel.text = "NIVEL %d / %d  ·  %s" % [nivel, teto, "DESBLOQUEADA" if liberado else "BLOQUEADA"]
    _det_texto.text = String(dados[2])
    for velho in _marcos.get_children(): velho.queue_free()
    for marco in [3, 6, 9]:
        var atingido: bool = nivel >= int(marco)
        var linha := P.linha_de_status("✦" if atingido else "◇", "Marco de potencia do nivel %d" % marco, "ALCANCADO" if atingido else "BLOQUEADO")
        linha.modulate = Color.WHITE if atingido else Color(0.55, 0.58, 0.66, 0.75)
        _marcos.add_child(linha)
    _aprimorar.text = "APRIMORAR PARA NV.%d" % mini(nivel + 1, teto)
    _aprimorar.disabled = not liberado or livres <= 0 or nivel >= teto
    _custo.text = "♪  1 PONTO DE SKILL" if nivel < teto else "TRILHA COMPLETA"
