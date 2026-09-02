extends Control
class_name PaginaEcos

## Santuario no desenho Stitch: colecao compacta a esquerda e o Eco escolhido
## em grande escala. Raridade, funcao, licao e atributos saem do Progresso.
const P := preload("res://scripts/ui_proto.gd")
const NOTAS := ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa", "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]
const ROTULO := {"do":"Dó", "do_sustenido":"Dó#", "re":"Ré", "re_sustenido":"Ré#", "mi":"Mi", "fa":"Fá", "fa_sustenido":"Fá#", "sol":"Sol", "sol_sustenido":"Sol#", "la":"Lá", "la_sustenido":"Lá#", "si":"Si"}

var _progresso: Node
var _escolhido := "do"
var _grade: GridContainer
var _cartoes: Dictionary = {}
var _arte: TextureRect
var _nome: Label
var _meta: Label
var _licao: Label
var _atributos: VBoxContainer
var _equipar: Button
var _colecao: Label

func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)

func ao_abrir() -> void:
    if _progresso:
        var atual := String(_progresso.eco_equipado.get("id", ""))
        if atual != "": _escolhido = atual
    _pintar()

func subtitulo_da_pagina() -> String: return "Santuario dos Ecos"

func cabecalho_extra() -> Control:
    _colecao = P.rotulo("", 13, P.GOLD_BRIGHT)
    return _colecao

func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 20)
    add_child(linha)

    var esquerda := VBoxContainer.new()
    esquerda.custom_minimum_size.x = 570
    esquerda.add_theme_constant_override("separation", 12)
    linha.add_child(esquerda)
    esquerda.add_child(P.cabecalho("COLECAO", "Ecos ressoados", ""))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    esquerda.add_child(rol)
    _grade = GridContainer.new()
    _grade.columns = 4
    _grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grade.add_theme_constant_override("h_separation", 10)
    _grade.add_theme_constant_override("v_separation", 10)
    rol.add_child(_grade)
    for id in NOTAS:
        var c := _cartao(String(id))
        _grade.add_child(c)
        _cartoes[id] = c
    var rodape := P.rotulo("♪ TODOS    ✧ NASCENTE    × CRESCENTE    ✹ ANCESTRAL", 9, P.MUTED)
    esquerda.add_child(rodape)

    var detalhe := P.painel(Color("0a1730e8"))
    detalhe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(detalhe)
    var d := VBoxContainer.new()
    d.add_theme_constant_override("separation", 8)
    detalhe.add_child(P.recheio(d, 20))
    _nome = P.rotulo("", 28, P.IVORY)
    _nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _nome.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    d.add_child(_nome)
    _meta = P.rotulo("", 10, P.MUTED)
    _meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    d.add_child(_meta)
    var conteudo := HBoxContainer.new()
    conteudo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    conteudo.add_theme_constant_override("separation", 20)
    d.add_child(conteudo)
    var palco := VBoxContainer.new()
    palco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    conteudo.add_child(palco)
    _arte = P.arte("", Vector2(420, 380))
    _arte.size_flags_vertical = Control.SIZE_EXPAND_FILL
    palco.add_child(_arte)
    var sombra := P.rotulo("◜━━━━━━━━━━━━◝", 14, Color("315aa477"))
    sombra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    palco.add_child(sombra)

    var texto := VBoxContainer.new()
    texto.custom_minimum_size.x = 420
    texto.add_theme_constant_override("separation", 8)
    conteudo.add_child(texto)
    texto.add_child(P.sobrancelha("PERSONALIDADE MUSICAL"))
    _licao = P.rotulo("", 11, P.IVORY, true)
    texto.add_child(_licao)
    texto.add_child(P.risco())
    texto.add_child(P.sobrancelha("ATRIBUTOS FIXOS DA RARIDADE"))
    _atributos = VBoxContainer.new()
    _atributos.add_theme_constant_override("separation", 3)
    texto.add_child(_atributos)
    texto.add_child(P.espaco_elastico())
    _equipar = P.botao("EQUIPAR COMO 4ª SKILL", "gold")
    _equipar.custom_minimum_size.y = 54
    _equipar.pressed.connect(_equipar_eco)
    texto.add_child(_equipar)

func _cartao(id: String) -> Button:
    var b := P.botao("", "item")
    b.custom_minimum_size = Vector2(132, 164)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.clip_contents = true
    b.pressed.connect(_escolher.bind(id))
    var col := VBoxContainer.new()
    col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
    col.alignment = BoxContainer.ALIGNMENT_CENTER
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(col)
    var face := P.arte("res://textures/ui/ecos/%s.png" % id, Vector2(94, 94))
    face.name = "Face"
    col.add_child(face)
    var nome := P.rotulo(String(ROTULO.get(id, id)), 13, P.IVORY)
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(nome)
    var estado := P.rotulo("", 8, P.MUTED)
    estado.name = "Estado"
    estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(estado)
    return b

func _escolher(id: String) -> void:
    _escolhido = id
    _pintar()

func _pintar() -> void:
    if _progresso == null or _arte == null: return
    var achados: Array = _progresso.ecos_descobertos
    var equipado := String(_progresso.eco_equipado.get("id", ""))
    if _colecao: _colecao.text = "COLECAO  %d / %d   ·   4ª SKILL: %s" % [achados.size(), NOTAS.size(), "ATIVA" if equipado != "" else "VAZIA"]
    for id in _cartoes:
        var b: Button = _cartoes[id]
        var tem: bool = id in achados
        var ficha: Dictionary = _progresso.ficha_do_eco(String(id))
        var cor: Color = P.RARIDADE.get(String(ficha.get("raridade", "Comum")), P.MUTED)
        var ativo := String(id) == _escolhido
        b.add_theme_stylebox_override("normal", P.estilo(Color(cor, 0.08) if tem else Color("07101fbb"), P.GOLD_BRIGHT if ativo else Color(cor, 0.65), 2 if ativo else 1, 4))
        var face := b.find_child("Face", true, false) as TextureRect
        if face: face.modulate = Color.WHITE if tem else Color(0.22, 0.25, 0.32, 0.55)
        var estado := b.find_child("Estado", true, false) as Label
        if estado: estado.text = ("EQUIPADO" if String(id) == equipado else String(ficha.get("raridade", "Comum")).to_upper()) if tem else "NAO RESSOADO"

    var ficha: Dictionary = _progresso.ficha_do_eco(_escolhido)
    var tem: bool = _escolhido in achados
    _arte.texture = _textura_aproximada(_escolhido)
    _arte.modulate = Color.WHITE if tem else Color(0.22, 0.25, 0.33, 0.65)
    _nome.text = String(ficha.get("nome", ROTULO.get(_escolhido, _escolhido))).to_upper()
    _meta.text = "%s  ·  %s  ·  %s" % [String(ficha.get("raridade", "—")).to_upper(), String(ficha.get("grau", "—")), String(ficha.get("funcao", "—")).to_upper()]
    _licao.text = String(ficha.get("licao", ""))
    for velho in _atributos.get_children(): velho.queue_free()
    var bonus: Dictionary = ficha.get("bonus", {})
    if bonus.is_empty(): _atributos.add_child(P.rotulo("Nenhum bonus registrado.", 10, P.MUTED))
    for chave in bonus:
        _atributos.add_child(P.linha_de_status("✦", _nome_atributo(String(chave)), "+%s" % _numero(bonus[chave])))
    _equipar.disabled = not tem or _escolhido == equipado
    _equipar.text = "EQUIPADO" if _escolhido == equipado else ("EQUIPAR COMO 4ª SKILL" if tem else "AINDA NAO RESSOADO")

func _equipar_eco() -> void:
    if _progresso and _progresso.equipar_eco({"id": _escolhido}):
        var shell := get_tree().root.find_child("UiShell", true, false)
        if shell and shell.has_method("avisar"): shell.avisar("Eco equipado", _nome.text.capitalize())

## Os recortes 320x240 guardam a criatura na metade inferior. Mostrar a folha
## inteira a deixava minuscula no grande palco do Stitch; o Atlas recorta so a
## area comum das criaturas sem regravar nem degradar nenhuma imagem.
func _textura_aproximada(id: String) -> Texture2D:
    var caminho := "res://textures/ui/ecos/%s.png" % id
    if not ResourceLoader.exists(caminho): return null
    var atlas := AtlasTexture.new()
    atlas.atlas = load(caminho)
    atlas.region = Rect2(45, 55, 230, 180)
    atlas.filter_clip = true
    return atlas

func _nome_atributo(chave: String) -> String:
    return {"vida_maxima":"Vida maxima", "poder_harmonico":"Poder harmonico", "dano_critico":"Dano critico", "critico":"Chance critica", "ataque":"Ataque", "defesa":"Defesa"}.get(chave, chave.capitalize())

func _numero(valor) -> String:
    var f := float(valor)
    return str(int(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f
