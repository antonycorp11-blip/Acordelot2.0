extends CanvasLayer
class_name Ajustes
## A tela de ajustes, hoje com um botao so: quanto do aparelho o jogo vai usar.
##
## O 3D passa a ser desenhado numa resolucao menor e ampliado na hora de
## mostrar. A INTERFACE NAO MUDA: menu, texto e icone continuam desenhados na
## resolucao cheia, porque quem escala e so o mundo. E por isso que este e o
## ajuste de desempenho mais barato que existe — a metade dos pixels do mundo
## custa quase metade do trabalho da GPU, e o jogador nao le texto borrado.
##
## Fica guardado em disco: quem escolheu Desempenho no celular fraco nao quer
## reescolher toda vez que abre.

const ARQUIVO := "user://ajustes.cfg"
const KIT := "res://textures/ui/kit/"
const FONTE := "res://fontes/Cinzel.ttf"

## Nome, escala do mundo 3D, e a explicacao que o jogador le.
const NIVEIS := [
    ["Qualidade", 1.0, "Tudo na resolução do aparelho"],
    ["Equilíbrio", 0.8, "Um pouco mais leve, quase igual"],
    ["Desempenho", 0.62, "Para celulares mais simples"],
    ["Celular simples", 0.50, "Máxima fluidez; HUD permanece nítida"],
]

var _escolhido := 1
var _fundo: ColorRect
var _botoes: Array = []


## Le a escolha do disco e aplica. Chamado na abertura do jogo, antes de
## qualquer tela existir.
static func aplicar_guardado(arvore: SceneTree) -> void:
    var arquivo := ConfigFile.new()
    var nivel := 1
    if arquivo.load(ARQUIVO) == OK:
        nivel = int(arquivo.get_value("video", "nivel", 1))
    nivel = clampi(nivel, 0, NIVEIS.size() - 1)
    var vp := arvore.root
    vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    vp.scaling_3d_scale = float(NIVEIS[nivel][1])


func _ready() -> void:
    layer = 18
    var arquivo := ConfigFile.new()
    if arquivo.load(ARQUIVO) == OK:
        _escolhido = clampi(int(arquivo.get_value("video", "nivel", 1)), 0, NIVEIS.size() - 1)
    _montar()
    visible = false


func _montar() -> void:
    _fundo = ColorRect.new()
    _fundo.color = Color(0.02, 0.02, 0.05, 0.72)
    _fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fundo.mouse_filter = Control.MOUSE_FILTER_STOP
    _fundo.gui_input.connect(func(e: InputEvent):
        if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
            mostrar(false))
    add_child(_fundo)

    var painel := NinePatchRect.new()
    painel.texture = load(KIT + "moldura_painel_grande.png")
    painel.patch_margin_left = 22
    painel.patch_margin_top = 68
    painel.patch_margin_right = 22
    painel.patch_margin_bottom = 64
    painel.set_anchors_preset(Control.PRESET_CENTER)
    painel.offset_left = -260
    painel.offset_right = 260
    painel.offset_top = -210
    painel.offset_bottom = 210
    _fundo.add_child(painel)

    var coluna := VBoxContainer.new()
    coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
    coluna.offset_left = 40
    coluna.offset_right = -40
    # Abaixo do ornamento do topo: encostado nele, o titulo era lido por cima do
    # ouro da moldura.
    coluna.offset_top = 78
    coluna.offset_bottom = -34
    coluna.add_theme_constant_override("separation", 7)
    painel.add_child(coluna)

    coluna.add_child(_rotulo("Desempenho", 26, Color(0.97, 0.84, 0.47)))
    coluna.add_child(_rotulo("Quanto do aparelho o jogo usa para desenhar o mundo. A interface não muda.", 14, Color(0.78, 0.80, 0.86), true))

    for i in NIVEIS.size():
        var b := _botao(str(NIVEIS[i][0]), i == _escolhido)
        b.pressed.connect(_escolher.bind(i))
        coluna.add_child(b)
        _botoes.append(b)

    var fechar := _botao("Fechar", false, "botao_vermelho")
    fechar.pressed.connect(func(): mostrar(false))
    coluna.add_child(fechar)


func _rotulo(txt: String, corpo: int, cor: Color, quebra := false) -> Label:
    var l := Label.new()
    l.text = txt
    l.add_theme_font_override("font", load(FONTE))
    l.add_theme_font_size_override("font_size", corpo)
    l.add_theme_color_override("font_color", cor)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
    return l


func _botao(rotulo: String, aceso: bool, arte := "") -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(0, 48)
    b.text = rotulo
    b.add_theme_font_override("font", load(FONTE))
    b.add_theme_font_size_override("font_size", 19)
    b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
    for estado in ["normal", "hover", "pressed", "focus"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())

    var fundo := NinePatchRect.new()
    fundo.texture = load(KIT + (arte if arte != "" else ("botao_roxo" if aceso else "botao_azul")) + ".png")
    fundo.patch_margin_left = 36
    fundo.patch_margin_top = 28
    fundo.patch_margin_right = 36
    fundo.patch_margin_bottom = 14
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.show_behind_parent = true
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(fundo)
    return b


func _escolher(i: int) -> void:
    _escolhido = i
    get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    get_viewport().scaling_3d_scale = float(NIVEIS[i][1])

    for k in _botoes.size():
        for filho in _botoes[k].get_children():
            if filho is NinePatchRect:
                (filho as NinePatchRect).texture = load(
                    KIT + ("botao_roxo" if k == i else "botao_azul") + ".png")

    var arquivo := ConfigFile.new()
    arquivo.set_value("video", "nivel", i)
    arquivo.save(ARQUIVO)


func mostrar(sim := true) -> void:
    visible = sim
