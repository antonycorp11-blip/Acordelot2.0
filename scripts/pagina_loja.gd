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

    # O BAU APAGADO. Tela vazia com duas linhas de texto no meio parece pagina
    # que faltou carregar; com o icone grande e escurecido ela parece o que e —
    # um lugar que existe e ainda esta fechado.
    var vitrine := CenterContainer.new()
    vitrine.custom_minimum_size.y = 200
    col.add_child(vitrine)
    var moldura := Control.new()
    moldura.custom_minimum_size = Vector2(200, 200)
    vitrine.add_child(moldura)
    moldura.add_child(T.halo_redondo(T.OURO, 0.10))
    var bau := TextureRect.new()
    bau.texture = load("res://textures/ui/kit/nav/loja.png")
    bau.set_anchors_preset(Control.PRESET_FULL_RECT)
    bau.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bau.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    bau.modulate = Color(1, 1, 1, 0.30)
    bau.mouse_filter = Control.MOUSE_FILTER_IGNORE
    moldura.add_child(bau)
    col.add_child(T.espaco(8))

    var t := T.rotulo("O comércio ainda não abriu", T.TITULO_SECAO, T.OURO_FORTE)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(t)
    var d := T.rotulo("Dorn e os mercadores de Acordelot ainda estão organizando o estoque.",
        T.CORPO, T.TEXTO_FRACO, true)
    d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    d.custom_minimum_size.x = 520
    col.add_child(d)
