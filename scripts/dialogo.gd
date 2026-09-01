extends CanvasLayer
class_name Dialogo
## A caixa de conversa: escurece a cena, mostra quem fala e troca o retrato.
##
## Uma fala e uma linha de dados — quem fala, com que cara, e o que diz. O
## sistema nao sabe nada sobre Mirella nem sobre a vila: para um NPC novo basta
## uma entrada em data/dialogos.json e uma folha de retratos em
## textures/dialogo/. Nada aqui precisa mudar.
##
## Os retratos vem em FOLHA, nao em arquivo por expressao: as dez caras de um
## personagem sao uma imagem so, cortada por AtlasTexture. Dez arquivos por
## personagem seriam dez importacoes e dez texturas na memoria de video para
## mostrar uma de cada vez.

signal terminou

## CADA FOLHA TEM A SUA GRADE.
##
## A da Mirella e do Akles veio em cinco por dois; a do Renaldo, em tres por
## tres. Fixar a grade numa constante so funcionava enquanto havia um formato —
## com o segundo personagem, o recorte cairia no meio da cara errada. Aqui cada
## folha declara o proprio tamanho e a ordem em que as expressoes foram
## desenhadas, lida da esquerda para a direita.
const FOLHAS := {
    "mirella": {
        "colunas": 5, "linhas": 2,
        "caras": ["neutro", "feliz", "rindo", "surpresa", "triste",
                  "calmo", "serio", "preocupado", "duvida", "pensativo"],
    },
    "akles": {
        "colunas": 5, "linhas": 2,
        "caras": ["neutro", "feliz", "rindo", "surpresa", "triste",
                  "calmo", "serio", "preocupado", "duvida", "pensativo"],
    },
    "renaldo": {
        "colunas": 3, "linhas": 3,
        "caras": ["serio", "feliz", "desconfiado",
                  "surpresa", "bravo", "triste",
                  "de_lado", "neutro", "preocupado"],
    },
}
const FOLHA_PADRAO := {
    "colunas": 5, "linhas": 2,
    "caras": ["neutro", "feliz", "rindo", "surpresa", "triste",
              "calmo", "serio", "preocupado", "duvida", "pensativo"],
}

var _falas: Array = []
var _indice := 0
var _ativo := false

var _escuro: ColorRect
var _retrato: TextureRect
var _nome: Label
var _texto: Label
var _dica: Label
var _atlas: Dictionary = {}


func _ready() -> void:
    # Acima do HUD: a conversa cobre os botoes enquanto dura.
    layer = 20
    _montar()
    _mostrar(false)


func _montar() -> void:
    _escuro = ColorRect.new()
    # Escuro, nao preto. O jogo continua visivel atras — a vila com as tochas
    # acesas e metade do clima da cena, e apagar tudo transformaria a conversa
    # numa tela de menu.
    _escuro.color = Color(0.02, 0.02, 0.05, 0.55)
    _escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
    _escuro.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_escuro)

    var caixa := PanelContainer.new()
    caixa.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    caixa.offset_left = 24.0
    caixa.offset_right = -24.0
    caixa.offset_top = -230.0
    caixa.offset_bottom = -24.0
    var fundo := StyleBoxFlat.new()
    fundo.bg_color = Color(0.06, 0.05, 0.08, 0.92)
    fundo.border_color = Color(0.72, 0.58, 0.28)
    fundo.set_border_width_all(2)
    fundo.set_corner_radius_all(10)
    fundo.set_content_margin_all(16)
    caixa.add_theme_stylebox_override("panel", fundo)
    _escuro.add_child(caixa)

    var linha := HBoxContainer.new()
    linha.add_theme_constant_override("separation", 18)
    caixa.add_child(linha)

    # O retrato SAI da caixa para cima. Rosto e tronco contidos numa faixa de
    # duzentos pixels ficariam do tamanho de um icone; deixando a figura subir
    # ela ganha presenca de personagem em cena.
    # O RETRATO SOBE PARA FORA DA CAIXA.
    #
    # Ele estava ancorado pelo pe dentro da linha de texto, e a figura ficava
    # afundada na caixa: aparecia so o tronco, com a cabeca na altura do nome.
    # Como Control nao desenha para fora do proprio retangulo sem ajuda, quem
    # sobe e o no: margem negativa no topo tira a figura da caixa e a poe em
    # pe sobre ela, que e a composicao de todo jogo do genero.
    var berco := Control.new()
    berco.custom_minimum_size = Vector2(210.0, 190.0)
    berco.mouse_filter = Control.MOUSE_FILTER_IGNORE
    linha.add_child(berco)

    _retrato = TextureRect.new()
    _retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    _retrato.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _retrato.offset_top = -300.0
    _retrato.offset_bottom = 16.0
    _retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
    berco.add_child(_retrato)

    var coluna := VBoxContainer.new()
    coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    coluna.add_theme_constant_override("separation", 8)
    linha.add_child(coluna)

    _nome = Label.new()
    _nome.add_theme_font_size_override("font_size", 26)
    _nome.add_theme_color_override("font_color", Color(0.96, 0.82, 0.45))
    coluna.add_child(_nome)

    _texto = Label.new()
    _texto.add_theme_font_size_override("font_size", 20)
    _texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
    coluna.add_child(_texto)

    _dica = Label.new()
    _dica.text = "toque para continuar"
    _dica.add_theme_font_size_override("font_size", 14)
    _dica.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
    _dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    coluna.add_child(_dica)

    # O toque em qualquer lugar da tela avanca. Botao proprio seria mais um
    # alvo para acertar no celular, e a conversa ja ocupa a tela inteira.
    _escuro.gui_input.connect(func(evento: InputEvent):
        if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
            avancar())


## Comeca uma conversa pelo nome dela no data/dialogos.json.
func comecar(id: String) -> bool:
    var arquivo := FileAccess.open("res://data/dialogos.json", FileAccess.READ)
    if arquivo == null:
        return false
    var dados: Dictionary = JSON.parse_string(arquivo.get_as_text())
    if dados == null or not dados.has(id):
        return false
    _falas = (dados[id] as Array).duplicate(true)
    if _falas.is_empty():
        return false
    # A TAREFA DO DIA SAI PELA BOCA DE QUEM ESTA NA FRENTE.
    #
    # O diario funcionava, mas so aparecia num contador no canto da tela: as
    # tarefas tinham dono na lore — Dorn, o Sr. Antony, o bardo — e nenhum deles
    # dizia nada. Quem esta no mundo hoje sao a Mirella e o Renaldo, entao sao
    # eles que passam o recado, na propria folha de retrato deles. Quando os
    # outros entrarem, e so casar o "dono" da tarefa com o elenco da NPC aqui.
    var recado := _recado_do_diario()
    if recado != "":
        var ultima: Dictionary = (_falas[_falas.size() - 1] as Dictionary).duplicate()
        ultima["texto"] = recado
        _falas.append(ultima)
    _indice = 0
    _ativo = true
    _mostrar(true)
    _pintar()
    return true


## O que falta hoje, em uma frase. Vazio quando nao ha diario ou ja fechou o dia.
func _recado_do_diario() -> String:
    var diario := get_node_or_null("/root/Diario")
    if diario == null or diario.missoes.is_empty():
        return ""
    if diario.concluidas() >= diario.missoes.size():
        return "O reino já teve o que precisava de você hoje. Descanse — amanhã há mais."
    for missao in diario.missoes:
        if int(missao["feito"]) >= int(missao["meta"]):
            continue
        return "A propósito: %s %s (%d de %d)" % [
            str(missao["dono"]).to_lower() if str(missao["dono"]).begins_with("Os ") else "%s pediu:" % str(missao["dono"]),
            str(missao["texto"]), int(missao["feito"]), int(missao["meta"])]
    return ""


func avancar() -> void:
    if not _ativo:
        return
    _indice += 1
    if _indice >= _falas.size():
        encerrar()
        return
    _pintar()


func encerrar() -> void:
    _ativo = false
    _mostrar(false)
    terminou.emit()


func esta_ativo() -> bool:
    return _ativo


func _pintar() -> void:
    var fala: Dictionary = _falas[_indice]
    _nome.text = str(fala.get("nome", ""))
    _texto.text = str(fala.get("texto", ""))
    _retrato.texture = _cara(str(fala.get("retrato", "")), str(fala.get("expressao", "neutro")))
    _assentar_retrato()
    _dica.text = "toque para continuar" if _indice < _falas.size() - 1 else "toque para encerrar"


## Recorta uma expressao da folha do personagem.
##
## Guardado por chave: a mesma cara costuma voltar varias vezes na conversa, e
## recortar de novo criaria um recurso novo a cada fala.
func _cara(quem: String, expressao: String) -> Texture2D:
    if quem == "":
        return null
    var chave := quem + "/" + expressao
    if _atlas.has(chave):
        return _atlas[chave]

    var caminho := "res://textures/dialogo/%s.png" % quem
    if not ResourceLoader.exists(caminho):
        return null
    var folha := load(caminho) as Texture2D

    var ficha: Dictionary = FOLHAS.get(quem, FOLHA_PADRAO)
    var colunas: int = int(ficha["colunas"])
    var caras: Array = ficha["caras"]
    var indice: int = caras.find(expressao)
    if indice < 0:
        indice = 0

    var largura: float = folha.get_width() / float(colunas)
    var altura: float = folha.get_height() / float(int(ficha["linhas"]))

    var recorte := AtlasTexture.new()
    recorte.atlas = folha
    recorte.region = Rect2(
        (indice % colunas) * largura,
        floori(indice / float(colunas)) * altura,
        largura, altura)
    _atlas[chave] = recorte
    return recorte


## Poe o retrato de PE sobre a caixa, seja qual for o formato da folha.
##
## O quadro tinha altura fixa e a figura era centrada nele: com a folha da
## Mirella, alta e estreita, isso funcionava por acidente; com a do Renaldo, que
## e mais larga que alta, a figura encolhia ate caber na largura e sobrava vao
## embaixo — o retrato flutuando. Aqui a altura do quadro passa a sair da
## PROPORCAO da imagem, e o pe fica sempre na mesma linha.
const LARGURA_DO_RETRATO := 210.0

func _assentar_retrato() -> void:
    if _retrato == null or _retrato.texture == null:
        return
    var t := _retrato.texture
    var proporcao: float = float(t.get_width()) / maxf(float(t.get_height()), 1.0)
    var altura: float = LARGURA_DO_RETRATO / maxf(proporcao, 0.05)
    _retrato.offset_top = -altura + 16.0
    _retrato.offset_bottom = 16.0


func _mostrar(visivel: bool) -> void:
    _escuro.visible = visivel
