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
var _camera_gta := false
var _medidor_ligado := false
var _botoes_camera: Array = []
var _botao_medidor: Button
var _medidor: Label
var _ate_medir := 0.0
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
    _ajustar_ceu(arvore.root.world_3d, nivel)


func _ready() -> void:
    layer = 18
    var arquivo := ConfigFile.new()
    if arquivo.load(ARQUIVO) == OK:
        _escolhido = clampi(int(arquivo.get_value("video", "nivel", 1)), 0, NIVEIS.size() - 1)
        _camera_gta = bool(arquivo.get_value("video", "camera_gta", false))
        _medidor_ligado = bool(arquivo.get_value("video", "medidor", false))
    _montar()
    visible = false
    set_process(false)
    # A escolha guardada vale desde o primeiro quadro, sem o jogador ter de
    # abrir os ajustes para reaplicar.
    call_deferred("_aplicar_guardado_na_cena")


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

    coluna.add_child(_rotulo("Câmera", 19, Color(0.95, 0.83, 0.48)))
    var linha_camera := HBoxContainer.new()
    linha_camera.add_theme_constant_override("separation", 8)
    coluna.add_child(linha_camera)
    for dados in [["DE CIMA", false], ["DE OMBRO", true]]:
        var b := _botao(str(dados[0]), bool(dados[1]) == _camera_gta)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(_escolher_camera.bind(bool(dados[1])))
        linha_camera.add_child(b)
        _botoes_camera.append(b)

    # O MEDIDOR. Enquanto a conversa sobre desempenho for "travou" de um lado e
    # "aqui roda" do outro, ninguem sai do lugar. Com quadros por segundo,
    # chamadas de desenho e triangulos na tela, o dono manda um numero e eu sei
    # exatamente onde atacar — e da para comparar as duas cameras no mesmo
    # lugar do mapa, que e a pergunta que abriu esta conversa.
    var b_medidor := _botao("MOSTRAR MEDIDOR", _medidor_ligado)
    b_medidor.pressed.connect(_alternar_medidor)
    coluna.add_child(b_medidor)
    _botao_medidor = b_medidor

    var fechar := _botao("Fechar", false, "botao_vermelho")
    fechar.pressed.connect(func(): mostrar(false))
    coluna.add_child(fechar)


func _aplicar_guardado_na_cena() -> void:
    # O ceu so troca de material quando o ciclo dia/noite acorda, depois do
    # ajuste inicial — por isso a preferencia de nuvem e reaplicada aqui.
    _ajustar_ceu(get_viewport().world_3d, _escolhido)
    if _camera_gta:
        _escolher_camera(true)
    if _medidor_ligado:
        _medidor_ligado = false
        _alternar_medidor()


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


## Troca a camera e guarda a escolha.
func _escolher_camera(gta: bool) -> void:
    _camera_gta = gta
    var rig := get_tree().root.find_child("CameraRig", true, false)
    if rig and rig.has_method("usar_modo_gta"):
        rig.usar_modo_gta(gta)
    for i in _botoes_camera.size():
        _pintar_botao(_botoes_camera[i], (i == 1) == gta)
    _gravar()


func _alternar_medidor() -> void:
    _medidor_ligado = not _medidor_ligado
    if _medidor == null:
        _montar_medidor()
    _medidor.visible = _medidor_ligado
    set_process(_medidor_ligado)
    _pintar_botao(_botao_medidor, _medidor_ligado)
    _gravar()


func _montar_medidor() -> void:
    _medidor = Label.new()
    _medidor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _medidor.offset_left = -300.0
    _medidor.offset_right = -12.0
    _medidor.offset_top = 250.0
    # SEM ISTO O ROTULO NASCE COM ALTURA ZERO. Com ancora no topo, "offset_top"
    # sem "offset_bottom" deixa o retangulo invertido, e o texto existe mas nao
    # aparece — foi o que aconteceu na primeira tentativa.
    _medidor.offset_bottom = 360.0
    _medidor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _medidor.add_theme_font_size_override("font_size", 15)
    _medidor.add_theme_color_override("font_color", Color(0.68, 1.0, 0.72))
    _medidor.add_theme_color_override("font_outline_color", Color(0.0, 0.05, 0.0))
    _medidor.add_theme_constant_override("outline_size", 4)
    _medidor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var camada := CanvasLayer.new()
    camada.layer = 30
    add_child(camada)
    camada.add_child(_medidor)


## Meia dozena de leituras por segundo basta: o numero e para ler, nao para
## piscar, e consultar o monitor a cada quadro custaria justamente o que ele
## esta medindo.
func _process(delta: float) -> void:
    if not _medidor_ligado or _medidor == null:
        return
    _ate_medir -= delta
    if _ate_medir > 0.0:
        return
    _ate_medir = 0.25
    var fps := Performance.get_monitor(Performance.TIME_FPS)
    var chamadas := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    var primitivas := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
    var objetos := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
    _medidor.text = "%d fps\n%d chamadas\n%s triangulos\n%d nos" % [
        int(fps), int(chamadas), _milhar_simples(int(primitivas)), int(objetos)]
    _medidor.add_theme_color_override("font_color",
        Color(0.68, 1.0, 0.72) if fps >= 45.0 else (Color(1.0, 0.86, 0.45) if fps >= 28.0 else Color(1.0, 0.52, 0.45)))
    if OS.get_cmdline_user_args().has("--medir"):
        print("MEDIDOR ", _medidor.text.replace("\n", " | "))


func _milhar_simples(valor: int) -> String:
    var texto := str(valor)
    var saida := ""
    var conta := 0
    for i in range(texto.length() - 1, -1, -1):
        saida = texto[i] + saida
        conta += 1
        if conta % 3 == 0 and i > 0:
            saida = "." + saida
    return saida


func _pintar_botao(b: Button, aceso: bool) -> void:
    for filho in b.get_children():
        if filho is NinePatchRect:
            (filho as NinePatchRect).texture = load(
                KIT + ("botao_roxo" if aceso else "botao_azul") + ".png")


func _gravar() -> void:
    var arquivo := ConfigFile.new()
    arquivo.set_value("video", "nivel", _escolhido)
    arquivo.set_value("video", "camera_gta", _camera_gta)
    arquivo.set_value("video", "medidor", _medidor_ligado)
    arquivo.save(ARQUIVO)


func _escolher(i: int) -> void:
    _escolhido = i
    get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    get_viewport().scaling_3d_scale = float(NIVEIS[i][1])
    _ajustar_ceu(get_viewport().world_3d, i)

    for k in _botoes.size():
        for filho in _botoes[k].get_children():
            if filho is NinePatchRect:
                (filho as NinePatchRect).texture = load(
                    KIT + ("botao_roxo" if k == i else "botao_azul") + ".png")

    _escolhido = i
    _gravar()


func mostrar(sim := true) -> void:
    visible = sim


## Os modos leves reduzem as nuvens, mas nunca deixam o ceu vazio. A camera nao
## olha para cima, então o pouco horizonte visível precisa continuar parecendo
## céu mesmo no celular simples.
static func _ajustar_ceu(mundo: World3D, nivel: int) -> void:
    if mundo == null or mundo.environment == null or mundo.environment.sky == null:
        return
    var ceu := mundo.environment.sky.sky_material as ShaderMaterial
    if ceu == null:
        return
    var forcas := [0.78, 0.62, 0.42, 0.28]
    ceu.set_shader_parameter("forca_das_nuvens", forcas[clampi(nivel, 0, forcas.size() - 1)])
