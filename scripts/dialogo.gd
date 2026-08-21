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

## A folha e uma grade de 5 por 2. A ordem das caras e a que veio na arte, lida
## da esquerda para a direita: e ela que os dialogos citam pelo nome.
const COLUNAS := 5
const LINHAS := 2
const EXPRESSOES := {
    "neutro": 0, "feliz": 1, "rindo": 2, "surpresa": 3, "triste": 4,
    "calmo": 5, "serio": 6, "preocupado": 7, "duvida": 8, "pensativo": 9,
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
    _retrato = TextureRect.new()
    _retrato.custom_minimum_size = Vector2(190.0, 330.0)
    _retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _retrato.size_flags_vertical = Control.SIZE_SHRINK_END
    linha.add_child(_retrato)

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
    _falas = dados[id]
    if _falas.is_empty():
        return false
    _indice = 0
    _ativo = true
    _mostrar(true)
    _pintar()
    return true


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

    var indice: int = int(EXPRESSOES.get(expressao, 0))
    var largura: float = folha.get_width() / float(COLUNAS)
    var altura: float = folha.get_height() / float(LINHAS)

    var recorte := AtlasTexture.new()
    recorte.atlas = folha
    recorte.region = Rect2(
        (indice % COLUNAS) * largura,
        floori(indice / float(COLUNAS)) * altura,
        largura, altura)
    _atlas[chave] = recorte
    return recorte


func _mostrar(visivel: bool) -> void:
    _escuro.visible = visivel
