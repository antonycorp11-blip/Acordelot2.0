extends Node
class_name CicloDiaNoite
## O relogio do mundo: move o sol, tinge o ceu e troca o sol pela lua.
##
## Tudo sai de UMA variavel, a hora. Guardar estados separados ("e noite", "esta
## anoitecendo") daria combinacao impossivel — ceu de dia com luz de noite — e o
## amanhecer e justo a parte que o jogador olha.
##
## As cores vem de uma tabela por horario, interpolada em circulo: 23h caminha
## para 0h pelo lado curto, senao o mundo daria uma volta de cor inteira ao
## virar o dia.

## Um dia inteiro em minutos reais. Curto de proposito enquanto se testa: o
## amanhecer e o entardecer sao os unicos momentos que valem olhar, e a 24 min
## por dia eles passam a cada 4.
@export var minutos_por_dia := 8.0
## Meia tarde: o mundo abre legivel E o entardecer chega em um minuto e meio,
## em vez de exigir quatro minutos de caminhada para o jogador ver que existe
## ciclo. Foi a queixa de quem testou no celular.
@export var hora_inicial := 15.5
## Parado, o ciclo congela na hora inicial — util para tirar print ou depurar
## uma cena sem o chao mudando de cor no meio.
@export var rodando := true

@export var sol: DirectionalLight3D
@export var ambiente: WorldEnvironment

var hora := 9.0
var _lampadas_acesas := false

var _luz: DirectionalLight3D
var _mundo: WorldEnvironment
var _ceu: ProceduralSkyMaterial
## O ceu desenhado (nuvens, estrelas, disco do sol). Substitui o degrade liso
## em tempo de execucao para nao mexer no arquivo de cena; se o shader faltar,
## o degrade antigo continua valendo e o jogo nao quebra.
var _ceu_pintado: ShaderMaterial

## hora -> [ceu_topo, ceu_horizonte, ambiente, nevoa, luz]
##
## As horas nao sao igualmente espacadas: o dia inteiro cabe em quatro marcos,
## mas o nascer e o por do sol levam tres cada um. E onde a cor muda rapido, e
## interpolar 6h direto para 12h passaria por cima do laranja.
const CORES := [
    # hora, ceu topo,               ceu horizonte,          ambiente,               nevoa,                  luz
    [0.0,  Color(0.025, 0.055, 0.16), Color(0.08, 0.13, 0.27), Color(0.46, 0.55, 0.82), Color(0.11, 0.15, 0.29), Color(0.62, 0.75, 1.00)],
    [4.5,  Color(0.05, 0.10, 0.22), Color(0.18, 0.18, 0.31), Color(0.48, 0.56, 0.82), Color(0.15, 0.18, 0.32), Color(0.66, 0.77, 1.00)],
    [6.0,  Color(0.18, 0.22, 0.42), Color(0.72, 0.42, 0.34), Color(0.44, 0.38, 0.42), Color(0.52, 0.40, 0.40), Color(1.00, 0.62, 0.38)],
    [7.5,  Color(0.20, 0.48, 0.84), Color(0.60, 0.76, 0.94), Color(0.68, 0.68, 0.66), Color(0.78, 0.77, 0.74), Color(1.00, 0.88, 0.72)],
    [12.0, Color(0.18, 0.50, 0.90), Color(0.52, 0.75, 0.96), Color(0.72, 0.75, 0.71), Color(0.76, 0.84, 0.88), Color(1.00, 0.96, 0.86)],
    [16.5, Color(0.18, 0.45, 0.82), Color(0.48, 0.70, 0.92), Color(0.71, 0.70, 0.65), Color(0.78, 0.80, 0.78), Color(1.00, 0.92, 0.78)],
    [18.5, Color(0.16, 0.24, 0.48), Color(0.94, 0.48, 0.26), Color(0.50, 0.40, 0.40), Color(0.62, 0.42, 0.36), Color(1.00, 0.54, 0.28)],
    [20.0, Color(0.07, 0.10, 0.24), Color(0.30, 0.20, 0.30), Color(0.46, 0.46, 0.66), Color(0.19, 0.19, 0.30), Color(0.74, 0.68, 0.92)],
    [21.5, Color(0.025, 0.055, 0.16), Color(0.08, 0.13, 0.27), Color(0.46, 0.55, 0.82), Color(0.12, 0.16, 0.29), Color(0.63, 0.76, 1.00)],
]

## hora -> [energia da luz, energia do ambiente, energia da nevoa]
##
## O DIA tambem nao vai ao teto. Sol em 2.0 com ambiente em 0.95 e exposicao
## 1.35 estourava o verde no celular: o navegador entrega a cena mais clara que
## o desktop, e o que aqui era vivo la virava chapa branca. Os tres numeros
## desceram juntos — mexer so na exposicao lavaria a cor em vez de baixar o
## brilho.
##
## A noite NAO vai a zero, e nem perto disso. A primeira versao dava a lua 12%
## da forca do sol, que no papel parecia noite e na tela deu preto: o tom
## escuro do ambiente e o mapeamento de tons do jogo multiplicam para baixo, e
## o que sobrou nao acendia um pixel. Noite de jogo visto de cima e convencao,
## nao fotometria — o jogador precisa enxergar a trilha.
const FORCAS := [
    [0.0, 0.98, 0.66, 0.14],
    [4.5, 1.00, 0.68, 0.16],
    [6.0, 1.15, 0.60, 0.26],
    [7.5, 1.18, 0.60, 0.23],
    [12.0, 1.28, 0.62, 0.22],
    [16.5, 1.22, 0.61, 0.23],
    [18.5, 1.15, 0.59, 0.29],
    [20.0, 1.00, 0.62, 0.18],
    [21.5, 0.98, 0.66, 0.15],
]

## Onde a hora do mundo fica guardada entre uma sessao e outra.
##
## Sem isto o jogo abria SEMPRE as 15h30 — a hora escrita na cena. Quem fechava
## o jogo ao anoitecer voltava no meio da tarde, e o ciclo, que da a volta em
## oito minutos, parecia nao existir. Um arquivo de uma linha resolve; nao ha
## save de progresso no projeto e nao e este o momento de inventar um.
const RELOGIO := "user://relogio.cfg"
## De quanto em quanto tempo a hora vai para o disco. Gravar todo quadro seria
## escrever sessenta vezes por segundo para guardar um numero.
const INTERVALO_DE_GRAVACAO := 15.0
## O dia dura minutos; atualizar ceu, ambiente e rotacao da luz sessenta vezes
## por segundo nao muda o que o olho ve e invalida estado do renderizador. Dez
## vezes por segundo continua perfeitamente continuo e e bem mais barato.
const INTERVALO_VISUAL := 0.10

var _ate_gravar := INTERVALO_DE_GRAVACAO
var _ate_atualizar_visual := 0.0


func _ready() -> void:
    hora = hora_inicial
    _carregar_hora()
    # Gancho de teste, no mesmo estilo do --shot do game.gd: `-- --hora=18.5`
    # congela o mundo naquele horario. Sem isso, conferir o entardecer exigiria
    # rodar o jogo e esperar o ciclo chegar la.
    for argumento in OS.get_cmdline_user_args():
        if argumento.begins_with("--hora="):
            hora = argumento.trim_prefix("--hora=").to_float()
            rodando = false
    _luz = sol
    _mundo = ambiente
    if _mundo and _mundo.environment and _mundo.environment.sky:
        _ceu = _mundo.environment.sky.sky_material as ProceduralSkyMaterial
        # Ceu customizado por shader nao e suportado de forma confiavel pelo
        # renderizador Compatibility usado no navegador. O resultado era o
        # fallback cinza visto no celular. Nesse renderer mantemos o
        # ProceduralSkyMaterial nativo (azul, horizonte e disco do astro), que
        # e implementado pelo proprio Godot. O shader detalhado fica disponivel
        # apenas se um futuro build usar Mobile/Forward+.
        if RenderingServer.get_current_rendering_method() != "gl_compatibility":
            var desenho: Shader = load("res://materials/ceu.gdshader")
            if desenho:
                _ceu_pintado = ShaderMaterial.new()
                _ceu_pintado.shader = desenho
                _ceu_pintado.set_shader_parameter("forca_das_nuvens", 0.62)
                _mundo.environment.sky.sky_material = _ceu_pintado
    if _luz == null:
        push_warning("Ciclo sem sol: o mundo fica na luz que veio da cena")
    _aplicar()

func _process(delta: float) -> void:
    if not rodando:
        return
    hora = fposmod(hora + delta * (24.0 / (minutos_por_dia * 60.0)), 24.0)
    _ate_atualizar_visual -= delta
    if _ate_atualizar_visual <= 0.0:
        _ate_atualizar_visual = INTERVALO_VISUAL
        _aplicar()

    _ate_gravar -= delta
    if _ate_gravar <= 0.0:
        _ate_gravar = INTERVALO_DE_GRAVACAO
        _gravar_hora()


## O navegador nem sempre avisa que vai fechar; por isso a gravacao periodica
## acima e a rede de seguranca, e esta aqui e so o caso educado.
func _notification(o_que: int) -> void:
    if o_que == NOTIFICATION_WM_CLOSE_REQUEST or o_que == NOTIFICATION_APPLICATION_PAUSED:
        _gravar_hora()


func _carregar_hora() -> void:
    # O gancho de linha de comando manda mais que o disco: quem pediu --hora=18.5
    # quer aquele horario, nao o que ficou da ultima sessao.
    for argumento in OS.get_cmdline_user_args():
        if argumento.begins_with("--hora="):
            return
    var arquivo := ConfigFile.new()
    if arquivo.load(RELOGIO) != OK:
        return
    var guardada: float = float(arquivo.get_value("mundo", "hora", hora_inicial))
    hora = fposmod(guardada, 24.0)


func _gravar_hora() -> void:
    var arquivo := ConfigFile.new()
    arquivo.set_value("mundo", "hora", hora)
    arquivo.save(RELOGIO)

func _aplicar() -> void:
    var cor := _interpolar(CORES)
    var forca := _interpolar(FORCAS)

    if _luz:
        _luz.rotation_degrees = _direcao_da_luz()
        _luz.light_color = cor[4]
        _luz.light_energy = forca[0]
        # De madrugada a sombra dura custa o mesmo que ao meio-dia e nao aparece:
        # a luz da lua e fraca demais para desenhar contraste. Desligar devolve
        # o quadro inteiro do celular na metade do ciclo.
        #
        # E o nivel grafico manda por cima: quem escolheu Baixo desligou a
        # sombra, e sem esta condicao o ciclo a reacendia no proximo decimo de
        # segundo — a opcao parecia simplesmente nao funcionar.
        _luz.shadow_enabled = forca[0] > 0.45 and Ajustes.sombras_permitidas

    _acender_as_lampadas(forca[0] < 1.0)

    if _mundo == null or _mundo.environment == null:
        return
    var env := _mundo.environment
    env.ambient_light_color = cor[2]
    env.ambient_light_energy = forca[1]
    # O WebGL de alguns celulares entrega os meios-tons mais claros que o
    # desktop. Baixamos a exposicao somente quando o sol esta forte; de noite
    # ela volta a subir para nao apagar ruas, NPCs e postes.
    var claridade_do_dia: float = clampf((forca[0] - 1.05) / 0.18, 0.0, 1.0)
    env.tonemap_exposure = lerpf(1.08, 0.92, claridade_do_dia)
    # A camera baixa enxerga muito terreno distante e pouco domo. A nevoa
    # sobre esse terreno era cinza e acabava ocupando justamente a faixa que o
    # jogador chama de ceu. Ela agora se dissolve na cor do horizonte: azul de
    # dia, quente no amanhecer e azul-escuro a noite, nunca uma chapa cinza.
    env.fog_light_color = cor[1]
    env.fog_light_energy = minf(forca[2], 0.72)
    env.fog_density = 0.003
    env.fog_height_density = 0.008

    if _ceu_pintado:
        _ceu_pintado.set_shader_parameter("cor_topo", cor[0])
        _ceu_pintado.set_shader_parameter("cor_horizonte", cor[1])
        # As estrelas acendem pela LUZ, nao pelo relogio: assim o ceu escurece
        # junto com o mundo, inclusive nos minutos em que o sol ja se foi mas
        # ainda ha claridade.
        _ceu_pintado.set_shader_parameter("noite", clampf((1.18 - forca[0]) / 0.34, 0.0, 1.0))
    elif _ceu:
        _ceu.sky_top_color = cor[0]
        _ceu.sky_horizon_color = cor[1]
        # O chao do ceu acompanha o horizonte, so que abafado: e o que se ve
        # atras das arvores na linha do olhar, e se ficasse na cor do dia
        # apareceria uma faixa clara flutuando no meio da noite.
        _ceu.ground_horizon_color = cor[1] * 0.55
        _ceu.ground_bottom_color = cor[0] * 0.7

## Acende e apaga os postes da vila.
##
## O gatilho e a forca do sol, nao a hora: assim as lampadas ja estao acesas
## quando o entardecer escurece o suficiente para precisar delas, em vez de
## esperarem um horario fixo com a vila no escuro.
##
## So mexe quando o estado VIRA. Percorrer o grupo a cada quadro para escrever o
## mesmo valor seria trabalho jogado fora sessenta vezes por segundo.
func _acender_as_lampadas(deve_acender: bool) -> void:
    if deve_acender == _lampadas_acesas:
        return
    _lampadas_acesas = deve_acender
    ChunkBuilder.luzes_acesas = deve_acender
    # No GL Compatibility do navegador a luz real quase nao chega ao chao; a
    # poca aditiva e o halo abaixo sao o que o jogador efetivamente enxerga.
    # Desligar somente a Omni no Web preserva a leitura noturna e remove dezenas
    # de luzes dinamicas da cidade.
    var luz_real := deve_acender and not OS.has_feature("web")
    for lampada in get_tree().get_nodes_in_group("lampada"):
        lampada.visible = luz_real
        lampada.light_energy = 6.5 if luz_real else 0.0
    for claro in get_tree().get_nodes_in_group("claro_de_poste"):
        claro.visible = deve_acender

## Onde esta o astro que ilumina agora.
##
## O sol nasce as 6h e se poe as 18h; fora disso quem ilumina e a lua, que faz o
## mesmo arco do lado oposto do ceu. E por isso que a luz nunca mergulha abaixo
## do horizonte: luz vinda de baixo do chao nao ilumina nada, e o mundo ficaria
## chapado na luz ambiente durante metade do ciclo.
func _direcao_da_luz() -> Vector3:
    var e_dia := hora >= 6.0 and hora < 18.0
    var fracao: float = (hora - 6.0) / 12.0 if e_dia else fposmod(hora - 18.0, 24.0) / 12.0
    # O piso de 22 graus nao e capricho de estetica, e o que torna o amanhecer
    # jogavel. A camera olha o CHAO, uma superficie virada para cima: com o
    # astro rente ao horizonte ela recebe o cosseno do angulo, quase nada, e o
    # mundo apagava por duas horas de cada ponta do dia mesmo com a luz forte.
    var altura: float = sin(fracao * PI) * 62.0 + 22.0
    var azimute: float = lerp(-100.0, 80.0, fracao) + (0.0 if e_dia else 180.0)
    return Vector3(-altura, azimute, 0.0)

## Le a tabela na hora atual. Cor e numero usam o mesmo caminho porque o que
## varia e so o tipo do valor — e Color e float respondem igual a lerp.
func _interpolar(tabela: Array) -> Array:
    var antes: Array = tabela[tabela.size() - 1]
    var depois: Array = tabela[0]
    for linha in tabela:
        if float(linha[0]) <= hora:
            antes = linha
        else:
            depois = linha
            break

    var inicio := float(antes[0])
    var fim := float(depois[0])
    # A ultima faixa cruza a meia-noite: 21.5h ate 0h sao 2.5 horas, nao -21.5.
    var vao := fposmod(fim - inicio, 24.0)
    var t := 0.0 if vao <= 0.0 else clampf(fposmod(hora - inicio, 24.0) / vao, 0.0, 1.0)
    # Suaviza a entrada e a saida de cada faixa. Sem isso a cor muda de
    # velocidade nos marcos da tabela e o ceu da um solavanco visivel.
    t = t * t * (3.0 - 2.0 * t)

    var saida := []
    for i in range(1, antes.size()):
        saida.append(lerp(antes[i], depois[i], t))
    return saida

## Para o HUD e para depurar: "06:30".
func hora_do_relogio() -> String:
    var h := int(hora)
    return "%02d:%02d" % [h, int((hora - float(h)) * 60.0)]
