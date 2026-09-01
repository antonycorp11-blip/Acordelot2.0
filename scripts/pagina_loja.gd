extends Control
class_name PaginaLoja
## A loja AINDA NAO EXISTE, e esta pagina diz isso em vez de fingir.
##
## Um catalogo falso com botao de comprar que nao compra e pior que uma pagina
## honesta: ensina o jogador que os botoes deste jogo nao valem nada. Quando o
## comercio entrar, e aqui que ele nasce.
const T := preload("res://scripts/ui_tema.gd")

func _ready() -> void:
    var centro := CenterContainer.new()
    centro.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(centro)
    var p := T.coluna(28)
    centro.add_child(p)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 10)
    p.add_child(col)
    var t := T.rotulo("O comércio ainda não abriu", T.TITULO_SECAO, T.OURO_FORTE)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(t)
    var d := T.rotulo("Dorn e os mercadores de Acordelot ainda estão organizando o estoque.",
        T.CORPO, T.TEXTO_FRACO)
    d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    d.custom_minimum_size.x = 520
    col.add_child(d)
