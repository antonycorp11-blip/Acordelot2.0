extends Control
class_name PaginaEcos
## Os doze Ecos: quais foram descobertos e qual esta equipado.
const T := preload("res://scripts/ui_tema.gd")
const NOTAS := ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]
const ROTULO := {"do": "Dó", "do_sustenido": "Dó#", "re": "Ré", "re_sustenido": "Ré#",
    "mi": "Mi", "fa": "Fá", "fa_sustenido": "Fá#", "sol": "Sol",
    "sol_sustenido": "Sol#", "la": "Lá", "la_sustenido": "Lá#", "si": "Si"}
var _progresso: Node
var _colecao: Label
var _grade: GridContainer
var _escalas: HBoxContainer

func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)

func ao_abrir() -> void: _pintar()

func _montar() -> void:
    var col := VBoxContainer.new()
    col.set_anchors_preset(Control.PRESET_FULL_RECT)
    col.add_theme_constant_override("separation", 10)
    add_child(col)
    col.add_child(T.cabeca_de_painel("Vozes do Caminho", "Ecos"))
    _colecao = T.rotulo_simples("", 17, T.SOBRANCELHA)
    col.add_child(_colecao)
    # AS DUAS ESCALAS. Fechar as sete naturais e fechar as doze sao conquistas
    # separadas, e mostrar as duas em aberto e o que faz querer capturar a
    # proxima — inclusive as cromaticas, que sozinhas valem menos.
    _escalas = HBoxContainer.new()
    _escalas.add_theme_constant_override("separation", 8)
    col.add_child(_escalas)
    col.add_child(T.espaco(4))

    # SEM ROLAGEM E SEM SOBRA. Doze ecos em quatro por tres, e os cartoes
    # crescem para ocupar a area inteira — a tela deitada tinha altura de sobra
    # embaixo enquanto os cartoes ficavam espremidos no alto.
    _grade = GridContainer.new()
    _grade.columns = 4
    _grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grade.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _grade.add_theme_constant_override("h_separation", 14)
    _grade.add_theme_constant_override("v_separation", 14)
    col.add_child(_grade)


func _pintar() -> void:
    if _progresso == null or _grade == null: return
    for a in _grade.get_children():
        _grade.remove_child(a)
        a.queue_free()
    var achados: Array = _progresso.ecos_descobertos
    _colecao.text = "Cada Eco descoberto fortalece o Akles para sempre; o equipado dá o bônus inteiro."
    for antigo in _escalas.get_children():
        _escalas.remove_child(antigo)
        antigo.queue_free()
    var naturais := 0
    for nota in _progresso.NATURAIS:
        if nota in achados: naturais += 1
    var diatonica: bool = naturais >= _progresso.NATURAIS.size()
    var cromatica: bool = achados.size() >= _progresso.ECOS.size()
    _escalas.add_child(T.chip("Coleção  %d / 12" % achados.size(), T.SOBRANCELHA.lightened(0.3)))
    _escalas.add_child(T.chip("Escala diatônica  %d / 7" % naturais,
        T.GANHO if diatonica else T.SOBRANCELHA))
    _escalas.add_child(T.chip("Cromática  %d / 12" % achados.size(),
        T.GANHO if cromatica else T.SOBRANCELHA))
    var equipado := String(_progresso.eco_equipado.get("id", ""))
    for nota in NOTAS:
        _grade.add_child(_cartao(String(nota), achados, equipado))


## O CARTAO E O RETRATO.
##
## A versao anterior era uma caixa com a sigla da nota em letra grande, um par
## de linhas de texto e um botao ornamentado achatado dentro — quatro elementos
## disputando um espaco onde ha uma unica coisa que vale ser vista: o retrato do
## Eco, que estava em `textures/ui/ecos` desde sempre, 320x240, sem uso.
##
## Aqui a imagem OCUPA o cartao. O nome mora sobre um vegue escuro no rodape, o
## cartao inteiro e o botao (nao ha botao dentro do botao) e quem ainda nao foi
## ressoado aparece como silhueta apagada. E o formato de tela de colecao: a
## grade se le pela arte, e a arte nao estica porque o recorte cobre e corta em
## vez de deformar.
func _cartao(id: String, achados: Array, equipado: String) -> Control:
    var tem: bool = id in achados
    var e_o_equipado: bool = id == equipado

    var caixa := Control.new()
    caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caixa.size_flags_vertical = Control.SIZE_EXPAND_FILL
    caixa.custom_minimum_size = Vector2(0, 132)

    var recorte := Control.new()
    recorte.set_anchors_preset(Control.PRESET_FULL_RECT)
    recorte.clip_contents = true
    recorte.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caixa.add_child(recorte)

    var fundo := ColorRect.new()
    fundo.color = Color(0.035, 0.055, 0.10, 1.0)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    recorte.add_child(fundo)

    var caminho := "res://textures/ui/ecos/%s.png" % id
    if ResourceLoader.exists(caminho):
        var face := TextureRect.new()
        face.texture = load(caminho)
        face.set_anchors_preset(Control.PRESET_FULL_RECT)
        face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        # COBRIR E CORTAR, nunca deformar: o retrato e 4:3 e o cartao e mais
        # largo que isso.
        face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        face.mouse_filter = Control.MOUSE_FILTER_IGNORE
        face.modulate = Color(1, 1, 1, 1) if tem else Color(0.20, 0.24, 0.34, 1)
        recorte.add_child(face)
    else:
        var sigla := T.rotulo(String(ROTULO.get(id, id)), T.TITULO_PAGINA,
            T.OURO_FORTE if tem else Color(0.24, 0.29, 0.38))
        sigla.add_theme_font_override("font", T.fonte_display())
        sigla.set_anchors_preset(Control.PRESET_FULL_RECT)
        sigla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sigla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        recorte.add_child(sigla)

    # O vegue: sem ele o nome branco cai em cima da parte clara do retrato.
    var vegue := Gradient.new()
    vegue.set_color(0, Color(0.01, 0.02, 0.05, 0.0))
    vegue.set_color(1, Color(0.01, 0.02, 0.05, 0.92))
    var tex := GradientTexture2D.new()
    tex.gradient = vegue
    tex.width = 8
    tex.height = 128
    tex.fill_from = Vector2(0.0, 0.0)
    tex.fill_to = Vector2(0.0, 1.0)
    var sombra := TextureRect.new()
    sombra.texture = tex
    sombra.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    sombra.anchor_top = 0.42
    sombra.offset_top = 0.0
    sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sombra.stretch_mode = TextureRect.STRETCH_SCALE
    sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
    recorte.add_child(sombra)

    var rodape := VBoxContainer.new()
    rodape.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    rodape.offset_left = 12.0
    rodape.offset_right = -12.0
    rodape.offset_top = -56.0
    rodape.offset_bottom = -10.0
    rodape.alignment = BoxContainer.ALIGNMENT_END
    rodape.add_theme_constant_override("separation", 0)
    rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caixa.add_child(rodape)

    var ficha: Dictionary = _progresso.ficha_do_eco(id)
    var raridade := String(ficha.get("raridade", "Comum"))
    var cor_da_raridade: Color = T.RARIDADE.get(raridade, T.RARIDADE["Comum"])

    var nome := T.rotulo(String(ROTULO.get(id, id)), T.NOME_ITEM,
        T.OURO_FORTE if tem else Color(0.55, 0.60, 0.70))
    nome.add_theme_font_override("font", T.fonte_titulo())
    nome.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.03, 0.9))
    nome.add_theme_constant_override("outline_size", 5)
    rodape.add_child(nome)

    var alma: int = _progresso.quantidade("alma_eco_" + id)
    var estado := T.rotulo("Equipado" if e_o_equipado else (
        "%s · %s" % [raridade, String(ficha.get("funcao", ""))] if tem
        else "Não ressoado"), T.LEGENDA,
        T.OURO if e_o_equipado else (cor_da_raridade.lightened(0.25) if tem else T.TEXTO_FRACO))
    estado.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.03, 0.9))
    estado.add_theme_constant_override("outline_size", 4)
    rodape.add_child(estado)

    var aro := Panel.new()
    aro.set_anchors_preset(Control.PRESET_FULL_RECT)
    aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # A BORDA E A RARIDADE. Assim a hierarquia da escala se le na grade inteira
    # de uma olhada, antes de qualquer texto.
    aro.add_theme_stylebox_override("panel", T.painel(
        Color(0, 0, 0, 0),
        T.OURO if e_o_equipado else (cor_da_raridade if tem else Color(0.15, 0.19, 0.27)),
        12, 3 if e_o_equipado else (2 if tem else 1), 0))
    caixa.add_child(aro)

    # O CARTAO INTEIRO E O BOTAO. Botao dentro de cartao era mais um retangulo
    # na tela para dizer o que o proprio cartao ja diz.
    var toque := Button.new()
    toque.set_anchors_preset(Control.PRESET_FULL_RECT)
    toque.focus_mode = Control.FOCUS_NONE
    toque.disabled = not tem or e_o_equipado
    # A LICAO E O BONUS moram no toque demorado: quem quiser so jogar, joga;
    # quem quiser entender por que o Sol vale mais que o Sol#, tem onde ler.
    var partes: Array[String] = []
    partes.append("%s  ·  %s (%s)" % [raridade, String(ficha.get("funcao", "")),
        String(ficha.get("grau", ""))])
    partes.append(String(ficha.get("licao", "")))
    var linhas: Array[String] = []
    for chave in ficha.get("bonus", {}):
        linhas.append("+%s %s" % [str(ficha["bonus"][chave]), String(chave).replace("_", " ")])
    if not linhas.is_empty():
        partes.append("Equipado concede:  " + ",  ".join(linhas))
    if not tem:
        partes.append("Ressoe este Eco no mundo para descobri-lo.")
    toque.tooltip_text = "\n".join(partes)
    for estado_do_botao in ["normal", "hover", "pressed", "focus", "disabled"]:
        toque.add_theme_stylebox_override(estado_do_botao, StyleBoxEmpty.new())
    toque.add_theme_stylebox_override("hover", T.painel(Color(1.0, 0.86, 0.45, 0.10), T.OURO, 12, 2, 0))
    toque.pressed.connect(func():
        _progresso.equipar_eco({"id": id})
        var casca := get_tree().root.find_child("UiShell", true, false)
        if casca and casca.has_method("avisar"):
            casca.avisar("Eco equipado", "%s — %s (%s)" % [
                String(ROTULO.get(id, id)), String(ficha.get("funcao", "")), raridade]))
    caixa.add_child(toque)
    return caixa
