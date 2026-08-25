extends "res://scripts/tela_ecos.gd"
## V3 do Santuário: catálogo compacto, retrato dedicado e evolução preparada.
## Equipar continua usando a coleção real do Progresso.

const FUNDO_V3 := "res://textures/ui/harmonia_celestial_v3.jpg"
const OURO := Color(0.94, 0.79, 0.42)
const AZUL := Color(0.30, 0.72, 1.0)

var _colecao_v3: Label
var _bonus_v3: Label


func _ready() -> void:
    super._ready()
    layer = 120


func _painel_v3(fundo := Color(0.015, 0.04, 0.078, 0.90), borda := Color(0.30, 0.43, 0.56), raio := 11) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _caixa(fundo, borda, 1, raio))
    return p


func _montar() -> void:
    var sombra := ColorRect.new()
    sombra.color = Color(0.002, 0.005, 0.014, 0.95)
    sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
    sombra.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(sombra)
    _base = Control.new()
    _base.size = TAMANHO
    sombra.add_child(_base)
    var arte := TextureRect.new()
    arte.texture = load(FUNDO_V3)
    arte.set_anchors_preset(Control.PRESET_FULL_RECT)
    arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    arte.stretch_mode = TextureRect.STRETCH_SCALE
    arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _base.add_child(arte)
    var margem := MarginContainer.new()
    margem.set_anchors_preset(Control.PRESET_FULL_RECT)
    margem.add_theme_constant_override("margin_left", 38)
    margem.add_theme_constant_override("margin_right", 38)
    margem.add_theme_constant_override("margin_top", 22)
    margem.add_theme_constant_override("margin_bottom", 26)
    _base.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 10)
    margem.add_child(coluna)
    coluna.add_child(_cabecalho_v3())
    var corpo := HBoxContainer.new()
    corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    corpo.add_theme_constant_override("separation", 16)
    coluna.add_child(corpo)
    corpo.add_child(_catalogo_v3())
    corpo.add_child(_detalhes_v3())
    coluna.add_child(_rodape_v3())
    _atualizar()


func _cabecalho_v3() -> Control:
    var linha := HBoxContainer.new()
    linha.custom_minimum_size.y = 66
    var titulo := VBoxContainer.new()
    titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(titulo)
    titulo.add_child(_texto("♫  SANTUÁRIO DOS ECOS", 30, OURO, true))
    titulo.add_child(_texto("COLEÇÃO, EVOLUÇÃO E QUARTA HABILIDADE", 12, Color(0.62, 0.70, 0.80)))
    var info := _texto("4ª SKILL  •  ECO EQUIPADO ACOMPANHA AKLES", 14, Color(0.58, 0.79, 0.96))
    info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(info)
    _fechar = _botao("×", 58)
    _fechar.custom_minimum_size.y = 58
    _fechar.add_theme_font_size_override("font_size", 30)
    linha.add_child(_fechar)
    return linha


func _catalogo_v3() -> Control:
    var painel := _painel_v3(Color(0.012, 0.032, 0.065, 0.92), Color(0.41, 0.34, 0.22))
    painel.custom_minimum_size.x = 735
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 8)
    painel.add_child(coluna)
    var grade := GridContainer.new()
    grade.columns = 4
    grade.add_theme_constant_override("h_separation", 8)
    grade.add_theme_constant_override("v_separation", 8)
    coluna.add_child(grade)
    for eco in _dados:
        grade.add_child(_carta_eco_v3(eco))
    var filtros := _texto("♫  TODOS        ◇  NASCENTE        ◇  CRESCENTE        ◇  ANCESTRAL", 14, Color(0.73, 0.70, 0.63), true)
    filtros.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(filtros)
    _colecao_v3 = _texto("", 13, Color(0.55, 0.80, 1.0))
    _colecao_v3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_colecao_v3)
    return painel


func _carta_eco_v3(eco: Dictionary) -> Control:
    var id := str(eco.get("id", ""))
    var caminho := str(eco.get("arte", ""))
    var b := _botao(str(eco.get("nota", id)), 170)
    b.custom_minimum_size.y = 190
    b.toggle_mode = true
    b.add_theme_stylebox_override("normal", _caixa(Color(0.018, 0.04, 0.075, 0.94), Color(0.30, 0.38, 0.48), 1, 9))
    b.add_theme_stylebox_override("pressed", _caixa(Color(0.035, 0.085, 0.15, 0.97), OURO, 2, 9))
    var pilha := VBoxContainer.new()
    pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
    pilha.offset_left = 6
    pilha.offset_right = -6
    pilha.offset_top = 30
    pilha.offset_bottom = -7
    pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(pilha)
    var icone := TextureRect.new()
    icone.custom_minimum_size = Vector2(0, 120)
    icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icone.texture = _retrato_eco(id, caminho)
    pilha.add_child(icone)
    var forma := _texto("FORMA 1  •  NASCENTE" if not caminho.is_empty() else "ARTE PENDENTE", 11, Color(0.60, 0.76, 0.90))
    forma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pilha.add_child(forma)
    _botoes[id] = b
    return b


func _detalhes_v3() -> Control:
    var painel := _painel_v3(Color(0.012, 0.035, 0.075, 0.91), Color(0.41, 0.34, 0.22), 13)
    painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 7)
    painel.add_child(coluna)
    _nome = _texto("", 30, OURO, true)
    _nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_nome)
    _forma = _texto("", 14, Color(0.60, 0.80, 0.98))
    _forma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_forma)
    var detalhe := HBoxContainer.new()
    detalhe.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detalhe.add_theme_constant_override("separation", 15)
    coluna.add_child(detalhe)
    var palco := _painel_v3(Color(0.014, 0.05, 0.10, 0.66), Color(0.32, 0.63, 0.90), 150)
    palco.custom_minimum_size.x = 305
    detalhe.add_child(palco)
    _preview = TextureRect.new()
    _preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    palco.add_child(_preview)
    var textos := VBoxContainer.new()
    textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    textos.add_theme_constant_override("separation", 11)
    detalhe.add_child(textos)
    _personalidade = _bloco_texto_v3("PERSONALIDADE", Color(0.82, 0.76, 0.58))
    textos.add_child(_personalidade)
    _habilidade = _bloco_texto_v3("SKILL 4", Color(0.53, 0.82, 1.0))
    textos.add_child(_habilidade)
    _buff = _bloco_texto_v3("PASSIVA", Color(0.82, 0.67, 0.98))
    textos.add_child(_buff)
    coluna.add_child(_evolucao_v3())
    _estado = _texto("", 14, Color(0.93, 0.84, 0.58))
    _estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(_estado)
    _equipar = _botao("EQUIPAR COMO 4ª SKILL", 440)
    _equipar.custom_minimum_size.y = 56
    _equipar.add_theme_stylebox_override("normal", _caixa(Color(0.28, 0.20, 0.07, 0.96), OURO, 2, 9))
    coluna.add_child(_equipar)
    return painel


func _bloco_texto_v3(titulo: String, cor: Color) -> Label:
    var l := _texto(titulo, 14, cor, true)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l


func _evolucao_v3() -> Control:
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 4)
    var titulo := _texto("—  EVOLUÇÃO DO ECO  —", 15, OURO, true)
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coluna.add_child(titulo)
    var linha := HBoxContainer.new()
    linha.alignment = BoxContainer.ALIGNMENT_CENTER
    linha.add_theme_constant_override("separation", 9)
    coluna.add_child(linha)
    for dados in [["NASCENTE", "1 / 3", true], ["CRESCENTE", "BLOQUEADO", false], ["ANCESTRAL", "BLOQUEADO", false]]:
        var p := _painel_v3(Color(0.025, 0.065, 0.12, 0.94) if dados[2] else Color(0.025, 0.03, 0.045, 0.90), OURO if dados[2] else Color(0.25, 0.27, 0.31), 8)
        p.custom_minimum_size = Vector2(155, 72)
        var txt := _texto("%s\n%s" % [dados[0], dados[1]], 13, OURO if dados[2] else Color(0.48, 0.50, 0.55), true)
        txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        p.add_child(txt)
        linha.add_child(p)
    return coluna


func _rodape_v3() -> Control:
    var painel := _painel_v3(Color(0.012, 0.03, 0.062, 0.94), Color(0.41, 0.34, 0.22), 8)
    painel.custom_minimum_size.y = 62
    _bonus_v3 = _texto("BÔNUS DA COLEÇÃO     ♡ Vida máxima +150     ⚔ Ataque +25     ◇ Defesa +20     ✦ Chance crítica +2,5%", 15, Color(0.80, 0.82, 0.88), true)
    _bonus_v3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _bonus_v3.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    painel.add_child(_bonus_v3)
    return painel


func _atualizar() -> void:
    super._atualizar()
    if _progresso and _colecao_v3:
        _colecao_v3.text = "COLEÇÃO  %d / 12     •     bônus de coleção preparados" % _progresso.ecos_descobertos.size()


func mostrar(sim := true) -> void:
    super.mostrar(sim)
    if sim and _base:
        _base.modulate.a = 0.0
        create_tween().tween_property(_base, "modulate:a", 1.0, 0.22)
