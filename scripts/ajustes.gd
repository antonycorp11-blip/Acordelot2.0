extends CanvasLayer
class_name Ajustes
## A tela de ajustes: gráficos, áudio, câmera e controles.
##
## REGRA DESTA TELA: só entra opção que MEXE em alguma coisa.
##
## O jogo não tem trilha nem efeitos ainda — tem uma única voz de nota. Por isso
## aqui há "Volume", que age no barramento Master e é audível, e não há "Música"
## e "Efeitos": três controles onde só um faz efeito ensinam o jogador que os
## ajustes deste jogo são decorativos.
##
## O nível gráfico mexe em quatro coisas de verdade: a resolução interna do 3D,
## a sombra direcional (existir, alcance e tamanho do atlas), quantas nuvens o
## céu monta e o teto de quadros no navegador. A interface NÃO é reescalada em
## nenhum nível: menu, texto e ícone continuam na resolução do aparelho, porque
## quem escala é só o mundo — é por isso que este é o ajuste de desempenho mais
## barato que existe.

const ARQUIVO := "user://ajustes.cfg"
const KIT := "res://textures/ui/kit/"
const FONTE := "res://fontes/Cinzel.ttf"
const VirtualJoystickScript := preload("res://scripts/virtual_joystick.gd")

## Cada nível, e o que exatamente ele desliga.
##
## "nuvens" é o índice que o céu entende (0 = todas). "atlas" é o lado do mapa de
## sombras: 512 no celular simples é sombra grosseira, mas sombra grosseira lida
## de cima ainda ancora a casa no chão — e custa um quarto de 1024.
const NIVEIS := [
    {
        "nome": "Baixo", "dica": "Para celulares mais simples",
        "escala": 0.55, "sombra": false, "atlas": 512,
        "distancia_sombra": 14.0, "nuvens": 3,
    },
    {
        "nome": "Médio", "dica": "Equilíbrio entre fluidez e detalhe",
        "escala": 0.78, "sombra": true, "atlas": 1024,
        "distancia_sombra": 24.0, "nuvens": 2,
    },
    {
        "nome": "Alto", "dica": "Tudo na resolução do aparelho",
        "escala": 1.0, "sombra": true, "atlas": 2048,
        "distancia_sombra": 34.0, "nuvens": 0,
    },
]

## O que o resto do jogo consulta.
##
## O ciclo de dia e noite liga e desliga a sombra pela força do sol dez vezes por
## segundo. Sem este intermediário ele reacenderia, no quadro seguinte, a sombra
## que o jogador acabou de desligar nos ajustes — e a opção pareceria quebrada.
static var sombras_permitidas := true
static var nivel_atual := 1
static var automatico := false


## Lê a escolha do disco e aplica. Chamado na abertura do jogo, antes de
## qualquer tela existir.
static func aplicar_guardado(arvore: SceneTree) -> void:
    var arquivo := ConfigFile.new()
    var nivel := 1
    # Instalacao nova comeca no automatico: o alvo e navegador de celular, e o
    # aparelho de quem abre o jogo pela primeira vez e desconhecido.
    var auto := true
    var volume := 1.0
    var sensivel := 0.006
    if arquivo.load(ARQUIVO) == OK:
        nivel = int(arquivo.get_value("video", "nivel", 1))
        auto = bool(arquivo.get_value("video", "automatico", true))
        volume = float(arquivo.get_value("audio", "volume", 1.0))
        sensivel = float(arquivo.get_value("controles", "sensibilidade", 0.006))
        VirtualJoystickScript.zona_morta = clampf(
            float(arquivo.get_value("controles", "zona_morta", 0.10)), 0.03, 0.30)
        VirtualJoystickScript.tamanho = clampf(
            float(arquivo.get_value("controles", "tamanho_direcional", 210.0)), 170.0, 270.0)
        VirtualJoystickScript.opacidade = clampf(
            float(arquivo.get_value("controles", "opacidade_direcional", 1.0)), 0.25, 1.0)
    automatico = auto
    aplicar(arvore, nivel)
    definir_volume(volume)
    IsometricCamera.sensibilidade = clampf(sensivel, 0.002, 0.016)


## Põe um nível gráfico em vigor. Estática porque roda antes de a tela existir.
static func aplicar(arvore: SceneTree, nivel: int) -> void:
    nivel = clampi(nivel, 0, NIVEIS.size() - 1)
    nivel_atual = nivel
    var receita: Dictionary = NIVEIS[nivel]

    var vp := arvore.root
    vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    vp.scaling_3d_scale = float(receita["escala"])

    sombras_permitidas = bool(receita["sombra"])
    RenderingServer.directional_shadow_atlas_set_size(int(receita["atlas"]), true)
    for luz in arvore.root.find_children("*", "DirectionalLight3D", true, false):
        var sol := luz as DirectionalLight3D
        sol.directional_shadow_max_distance = float(receita["distancia_sombra"])
        # O ciclo reavalia isto pela hora do dia; aqui só se garante que a
        # escolha do jogador já valha neste quadro.
        if not sombras_permitidas:
            sol.shadow_enabled = false

    for ceu in arvore.root.find_children("CeuVivoCompatibilidade", "Node3D", true, false):
        if ceu.has_method("definir_qualidade"):
            ceu.definir_qualidade(int(receita["nuvens"]))


static func definir_volume(fracao: float) -> void:
    var f := clampf(fracao, 0.0, 1.0)
    var barramento := AudioServer.get_bus_index("Master")
    if barramento < 0:
        return
    AudioServer.set_bus_mute(barramento, f <= 0.001)
    # Em decibéis, não em porcentagem linear: a orelha ouve em escala
    # logarítmica, e um cursor linear em dB deixa a metade do curso inaudível.
    AudioServer.set_bus_volume_db(barramento, -60.0 if f <= 0.001 else linear_to_db(f))


var _escolhido := 1
var _camera_gta := false
var _medidor_ligado := false
var _volume := 1.0
var _sensibilidade := 0.006
var _botoes_camera: Array = []
var _botao_medidor: Button
var _botao_auto: Button
var _medidor: Label
var _ate_medir := 0.0
var _fundo: ColorRect
var _botoes: Array = []
var _rotulo_volume: Label
var _rotulo_sensibilidade: Label
var _rotulo_tamanho: Label
var _rotulo_zona_morta: Label
var _rotulo_opacidade: Label


func _ready() -> void:
    layer = 18
    var arquivo := ConfigFile.new()
    if arquivo.load(ARQUIVO) == OK:
        _escolhido = clampi(int(arquivo.get_value("video", "nivel", 1)), 0, NIVEIS.size() - 1)
        _camera_gta = bool(arquivo.get_value("video", "camera_gta", false))
        _medidor_ligado = bool(arquivo.get_value("video", "medidor", false))
        automatico = bool(arquivo.get_value("video", "automatico", true))
        _volume = clampf(float(arquivo.get_value("audio", "volume", 1.0)), 0.0, 1.0)
        _sensibilidade = clampf(float(arquivo.get_value("controles", "sensibilidade", 0.006)), 0.002, 0.016)
    _montar()
    visible = false
    set_process(false)
    call_deferred("_aplicar_guardado_na_cena")


# ------------------------------------------------------------------ montagem

## O painel inteiro cabe em qualquer tela porque o miolo ROLA.
##
## Antes eram offsets fixos de 520 por 420 com uma coluna dentro: em celular
## deitado sobrava moldura, em celular estreito os botões de baixo saíam pela
## borda da moldura. Com âncoras proporcionais e um ScrollContainer, o painel
## acompanha a tela e nenhum controle pode vazar — o pior caso vira rolagem.
func _montar() -> void:
    _fundo = ColorRect.new()
    _fundo.color = Color(0.02, 0.02, 0.05, 0.78)
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
    painel.anchor_left = 0.5
    painel.anchor_right = 0.5
    painel.anchor_top = 0.06
    painel.anchor_bottom = 0.94
    painel.offset_left = -285.0
    painel.offset_right = 285.0
    painel.mouse_filter = Control.MOUSE_FILTER_STOP
    _fundo.add_child(painel)

    var coluna := VBoxContainer.new()
    coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
    coluna.offset_left = 34
    coluna.offset_right = -34
    # Abaixo do ornamento do topo: encostado nele, o titulo era lido por cima do
    # ouro da moldura.
    coluna.offset_top = 74
    coluna.offset_bottom = -30
    coluna.add_theme_constant_override("separation", 8)
    painel.add_child(coluna)

    coluna.add_child(_rotulo("Ajustes", 27, Color(0.97, 0.84, 0.47)))

    var rolagem := ScrollContainer.new()
    rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    coluna.add_child(rolagem)

    var miolo := VBoxContainer.new()
    miolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    miolo.add_theme_constant_override("separation", 6)
    rolagem.add_child(miolo)

    # ------------------------------------------------------------- gráficos
    miolo.add_child(_titulo_de_secao("Gráficos"))
    miolo.add_child(_rotulo(
        "Quanto do aparelho o jogo usa para desenhar o mundo. A interface não muda.",
        13, Color(0.74, 0.77, 0.84), true))

    for i in NIVEIS.size():
        var b := _botao(str(NIVEIS[i]["nome"]), i == _escolhido and not automatico)
        b.tooltip_text = str(NIVEIS[i]["dica"])
        b.pressed.connect(_escolher.bind(i))
        miolo.add_child(b)
        _botoes.append(b)

    _botao_auto = _botao("AUTOMÁTICO", automatico)
    _botao_auto.tooltip_text = "O jogo escolhe o nível pelo desempenho medido"
    _botao_auto.pressed.connect(_alternar_automatico)
    miolo.add_child(_botao_auto)

    # ---------------------------------------------------------------- áudio
    miolo.add_child(_titulo_de_secao("Áudio"))
    _rotulo_volume = _rotulo("", 15, Color(0.86, 0.89, 0.94))
    miolo.add_child(_rotulo_volume)
    var cursor_volume := _cursor(0.0, 1.0, 0.05, _volume)
    cursor_volume.value_changed.connect(_mudar_volume)
    miolo.add_child(cursor_volume)
    _mostrar_volume()

    # --------------------------------------------------------------- câmera
    miolo.add_child(_titulo_de_secao("Câmera"))
    var linha_camera := HBoxContainer.new()
    linha_camera.add_theme_constant_override("separation", 8)
    miolo.add_child(linha_camera)
    for dados in [["DE CIMA", false], ["DE OMBRO", true]]:
        var b := _botao(str(dados[0]), bool(dados[1]) == _camera_gta)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(_escolher_camera.bind(bool(dados[1])))
        linha_camera.add_child(b)
        _botoes_camera.append(b)

    _rotulo_sensibilidade = _rotulo("", 15, Color(0.86, 0.89, 0.94))
    miolo.add_child(_rotulo_sensibilidade)
    var cursor_sensivel := _cursor(0.002, 0.016, 0.001, _sensibilidade)
    cursor_sensivel.value_changed.connect(_mudar_sensibilidade)
    miolo.add_child(cursor_sensivel)
    _mostrar_sensibilidade()

    # ------------------------------------------------------------ direcional
    miolo.add_child(_titulo_de_secao("Direcional"))
    _rotulo_tamanho = _rotulo("", 15, Color(0.86, 0.89, 0.94))
    miolo.add_child(_rotulo_tamanho)
    var cursor_tamanho := _cursor(170.0, 270.0, 5.0, VirtualJoystickScript.tamanho)
    cursor_tamanho.value_changed.connect(_mudar_tamanho)
    miolo.add_child(cursor_tamanho)

    _rotulo_zona_morta = _rotulo("", 15, Color(0.86, 0.89, 0.94))
    miolo.add_child(_rotulo_zona_morta)
    var cursor_zona := _cursor(0.03, 0.30, 0.01, VirtualJoystickScript.zona_morta)
    cursor_zona.value_changed.connect(_mudar_zona_morta)
    miolo.add_child(cursor_zona)

    _rotulo_opacidade = _rotulo("", 15, Color(0.86, 0.89, 0.94))
    miolo.add_child(_rotulo_opacidade)
    var cursor_op := _cursor(0.25, 1.0, 0.05, VirtualJoystickScript.opacidade)
    cursor_op.value_changed.connect(_mudar_opacidade)
    miolo.add_child(cursor_op)
    _mostrar_direcional()

    # -------------------------------------------------------------- medidor
    # O MEDIDOR. Enquanto a conversa sobre desempenho for "travou" de um lado e
    # "aqui roda" do outro, ninguem sai do lugar. Com quadros por segundo,
    # chamadas de desenho e triangulos na tela, o dono manda um numero e eu sei
    # exatamente onde atacar.
    miolo.add_child(_titulo_de_secao("Diagnóstico"))
    var b_medidor := _botao("MOSTRAR MEDIDOR", _medidor_ligado)
    b_medidor.pressed.connect(_alternar_medidor)
    miolo.add_child(b_medidor)
    _botao_medidor = b_medidor

    # O fechar fica FORA da rolagem: é a saída, e saída que exige rolar até o
    # fim é a maneira mais fácil de prender o jogador numa tela de opções.
    var fechar := _botao("Fechar", false, "botao_vermelho")
    fechar.pressed.connect(func(): mostrar(false))
    coluna.add_child(fechar)


func _titulo_de_secao(texto: String) -> Control:
    var caixa := VBoxContainer.new()
    caixa.add_theme_constant_override("separation", 2)
    var espaco := Control.new()
    espaco.custom_minimum_size = Vector2(0, 8)
    caixa.add_child(espaco)
    caixa.add_child(_rotulo(texto, 19, Color(0.95, 0.83, 0.48)))
    var risco := ColorRect.new()
    risco.color = Color(0.72, 0.58, 0.30, 0.45)
    risco.custom_minimum_size = Vector2(0, 1)
    caixa.add_child(risco)
    return caixa


func _cursor(minimo: float, maximo: float, passo: float, valor: float) -> HSlider:
    var c := HSlider.new()
    c.min_value = minimo
    c.max_value = maximo
    c.step = passo
    c.value = valor
    c.custom_minimum_size = Vector2(0, 30)
    c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return c


func _aplicar_guardado_na_cena() -> void:
    # O céu só existe depois que o mundo acorda, então a preferência de nuvem é
    # reaplicada aqui, com a cena já montada.
    aplicar(get_tree(), _escolhido)
    definir_volume(_volume)
    IsometricCamera.sensibilidade = _sensibilidade
    _aplicar_no_direcional()
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
    b.custom_minimum_size = Vector2(0, 46)
    b.text = rotulo
    b.add_theme_font_override("font", load(FONTE))
    b.add_theme_font_size_override("font_size", 18)
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


# -------------------------------------------------------------------- ações

func _escolher(i: int) -> void:
    _escolhido = i
    automatico = false
    aplicar(get_tree(), i)
    _repintar_niveis()
    _gravar()


func _alternar_automatico() -> void:
    automatico = not automatico
    if automatico:
        # Começa do meio: subir a partir daqui é uma decisão medida, e cair de
        # Alto para Baixo na frente do jogador é justamente o que se quer evitar.
        _escolhido = 1
        aplicar(get_tree(), _escolhido)
    _repintar_niveis()
    _gravar()


func _repintar_niveis() -> void:
    for k in _botoes.size():
        _pintar_botao(_botoes[k], k == _escolhido and not automatico)
    if _botao_auto:
        _pintar_botao(_botao_auto, automatico)


## Chamado pelo medidor adaptativo quando o modo automático está ligado.
func nivel_sugerido(novo: int) -> void:
    if not automatico:
        return
    novo = clampi(novo, 0, NIVEIS.size() - 1)
    if novo == _escolhido:
        return
    _escolhido = novo
    aplicar(get_tree(), novo)
    _repintar_niveis()


func _mudar_volume(valor: float) -> void:
    _volume = valor
    definir_volume(_volume)
    _mostrar_volume()
    _gravar()


func _mostrar_volume() -> void:
    if _rotulo_volume:
        _rotulo_volume.text = "Volume  %d%%" % int(round(_volume * 100.0))


func _mudar_sensibilidade(valor: float) -> void:
    _sensibilidade = valor
    IsometricCamera.sensibilidade = valor
    _mostrar_sensibilidade()
    _gravar()


func _mostrar_sensibilidade() -> void:
    if _rotulo_sensibilidade:
        var fracao: float = (_sensibilidade - 0.002) / 0.014
        _rotulo_sensibilidade.text = "Sensibilidade da câmera  %d%%" % int(round(fracao * 100.0))


func _direcional() -> Node:
    return get_tree().root.find_child("VirtualJoystick", true, false)


func _mudar_tamanho(valor: float) -> void:
    VirtualJoystickScript.tamanho = valor
    _aplicar_no_direcional()


func _mudar_zona_morta(valor: float) -> void:
    VirtualJoystickScript.zona_morta = valor
    _aplicar_no_direcional()


func _mudar_opacidade(valor: float) -> void:
    VirtualJoystickScript.opacidade = valor
    _aplicar_no_direcional()


func _aplicar_no_direcional() -> void:
    var j := _direcional()
    if j and j.has_method("aplicar_preferencias"):
        j.aplicar_preferencias()
    _mostrar_direcional()
    _gravar()


func _mostrar_direcional() -> void:
    if _rotulo_tamanho:
        _rotulo_tamanho.text = "Tamanho do direcional  %d px" % int(VirtualJoystickScript.tamanho)
    if _rotulo_zona_morta:
        _rotulo_zona_morta.text = "Zona morta  %d%%" % int(round(VirtualJoystickScript.zona_morta * 100.0))
    if _rotulo_opacidade:
        _rotulo_opacidade.text = "Transparência  %d%%" % int(round(VirtualJoystickScript.opacidade * 100.0))


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
    # A ESQUERDA, e nao mais a direita.
    #
    # No canto direito ele caia exatamente em cima da coluna do minimapa: o
    # rotulo ocupava y 250 a 372 e ali moram "Trocar para Wins", "Mapa do
    # Reino", "MISSOES" e os dois botoes de mochila e engrenagem. Quem deixava
    # o medidor ligado ficava com quatro botoes ilegiveis por baixo do numero.
    # A faixa esquerda abaixo do botao da DG esta livre em toda proporcao.
    _medidor.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _medidor.offset_left = 18.0
    _medidor.offset_right = 320.0
    _medidor.offset_top = 190.0
    # SEM ISTO O ROTULO NASCE COM ALTURA ZERO. Com ancora no topo, "offset_top"
    # sem "offset_bottom" deixa o retangulo invertido, e o texto existe mas nao
    # aparece — foi o que aconteceu na primeira tentativa.
    _medidor.offset_bottom = 320.0
    _medidor.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
    _medidor.text = "%d fps\n%d chamadas\n%s triangulos\n%d nos\n%s%s" % [
        int(fps), int(chamadas), _milhar_simples(int(primitivas)), int(objetos),
        str(NIVEIS[nivel_atual]["nome"]), "  (auto)" if automatico else ""]
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
    arquivo.set_value("video", "automatico", automatico)
    arquivo.set_value("video", "camera_gta", _camera_gta)
    arquivo.set_value("video", "medidor", _medidor_ligado)
    arquivo.set_value("audio", "volume", _volume)
    arquivo.set_value("controles", "sensibilidade", _sensibilidade)
    arquivo.set_value("controles", "zona_morta", VirtualJoystickScript.zona_morta)
    arquivo.set_value("controles", "tamanho_direcional", VirtualJoystickScript.tamanho)
    arquivo.set_value("controles", "opacidade_direcional", VirtualJoystickScript.opacidade)
    arquivo.save(ARQUIVO)


func mostrar(sim := true) -> void:
    visible = sim
