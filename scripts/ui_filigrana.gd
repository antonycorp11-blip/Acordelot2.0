extends Control
class_name UiFiligrana

## A MOLDURA ORNAMENTADA, DESENHADA — NAO COLADA.
##
## Ate aqui os quatro cantos vinham de `moldura_canto_01.png`: uma peca de arte
## solta, posicionada por ancora e deslocamento dentro de um Control. O dono
## chamou o resultado de horrivel e disse que eu sempre encaixo mal, e ele esta
## certo nas duas coisas — a arte e fraca e o encaixe depende de eu acertar
## quatro pares de offsets contra um retangulo que muda de tamanho com a tela.
##
## Nas telas que ele aprovou o ornamento e PINTADO DENTRO da moldura: filete
## duplo correndo a borda inteira, cantoneira mais longa nas quinas e losango na
## junta. Isso e geometria, nao ilustracao — e geometria eu desenho a partir do
## proprio retangulo do no. Nao ha o que posicionar errado, nao pesa um byte no
## pacote e acompanha qualquer proporcao de tela.
##
## Desenha UMA VEZ e so redesenha quando muda de tamanho. Sem `_process`, sem
## animacao: o fundo de uma tela de menu nao precisa gastar quadro num aparelho
## que ja esta no limite.

## Recuo do filete de fora em relacao a borda do painel.
const RECUO := 11.0
## Distancia entre o filete de fora e o de dentro.
const VAO := 5.0
## Braco da cantoneira, medido no desenho aprovado.
const BRACO := 74.0
const BRACO_CURTO := 26.0
const LOSANGO := 5.0

@export var cor_fio := Color(0.72, 0.58, 0.30, 0.50)
@export var cor_forte := Color(0.95, 0.81, 0.46, 0.90)
## Quantas notas ficam boiando no fundo. Zero desliga.
## "fundo" desenha a pauta e as notas, e vive ATRAS do conteudo.
## "borda" desenha so o fio e as cantoneiras, e vive NA FRENTE de tudo.
##
## Precisam ser duas peças e nao uma: a pauta tem de ficar por tras dos paineis
## para nao riscar o texto, e o ornamento da moldura tem de ficar por cima deles
## para nao ser tapado pelo primeiro painel que encostar na borda — que foi
## exatamente o que aconteceu quando tentei desenhar os dois na mesma camada.
@export var modo := "borda"
@export var notas := 14
@export var cor_da_nota := Color(0.85, 0.72, 0.40, 0.10)


func _init(qual := "borda") -> void:
    modo = qual
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if modo == "fundo":
        z_index = -1


func _ready() -> void:
    resized.connect(queue_redraw)


func _draw() -> void:
    if size.x < 80.0 or size.y < 80.0:
        return
    if modo == "fundo":
        _pauta_de_fundo()
        _notas_soltas()
        return
    _fio(RECUO, cor_fio, 1.0)
    _fio(RECUO + VAO, Color(cor_fio.r, cor_fio.g, cor_fio.b, cor_fio.a * 0.45), 1.0)
    _cantoneiras()
    _losangos_do_meio()


## O filete que corre a borda inteira, a `recuo` pixels dela.
func _fio(recuo: float, cor: Color, grossura: float) -> void:
    var r := Rect2(Vector2(recuo, recuo), size - Vector2(recuo, recuo) * 2.0)
    if r.size.x <= 0.0 or r.size.y <= 0.0:
        return
    draw_rect(r, cor, false, grossura, true)


## A quina: braco longo por fora, braco curto por dentro e o losango na junta.
## E o desenho que da o ar de moldura sem nenhuma textura.
func _cantoneiras() -> void:
    var fora := Rect2(Vector2(RECUO, RECUO), size - Vector2(RECUO, RECUO) * 2.0)
    var dentro := Rect2(Vector2(RECUO + VAO, RECUO + VAO),
        size - Vector2(RECUO + VAO, RECUO + VAO) * 2.0)
    # [ponto da quina, rumo horizontal, rumo vertical]
    var quinas := [
        [fora.position, Vector2.RIGHT, Vector2.DOWN],
        [Vector2(fora.end.x, fora.position.y), Vector2.LEFT, Vector2.DOWN],
        [Vector2(fora.position.x, fora.end.y), Vector2.RIGHT, Vector2.UP],
        [fora.end, Vector2.LEFT, Vector2.UP],
    ]
    var quinas_dentro := [
        dentro.position,
        Vector2(dentro.end.x, dentro.position.y),
        Vector2(dentro.position.x, dentro.end.y),
        dentro.end,
    ]
    var braco: float = minf(BRACO, minf(size.x, size.y) * 0.22)
    for i in quinas.size():
        var q: Vector2 = quinas[i][0]
        var h: Vector2 = quinas[i][1]
        var v: Vector2 = quinas[i][2]
        draw_line(q, q + h * braco, cor_forte, 2.0, true)
        draw_line(q, q + v * braco, cor_forte, 2.0, true)
        var d: Vector2 = quinas_dentro[i]
        draw_line(d, d + h * BRACO_CURTO, cor_forte, 1.0, true)
        draw_line(d, d + v * BRACO_CURTO, cor_forte, 1.0, true)
        _losango(q + (h + v) * (braco * 0.5), LOSANGO + 1.0, cor_forte)


## Um losango no meio de cada borda. E o detalhe que quebra a linha reta e faz o
## filete parecer trabalhado em vez de contorno de caixa.
func _losangos_do_meio() -> void:
    var r := Rect2(Vector2(RECUO, RECUO), size - Vector2(RECUO, RECUO) * 2.0)
    var meio_x := r.position.x + r.size.x * 0.5
    var meio_y := r.position.y + r.size.y * 0.5
    for p in [Vector2(meio_x, r.position.y), Vector2(meio_x, r.end.y),
            Vector2(r.position.x, meio_y), Vector2(r.end.x, meio_y)]:
        _losango(p, LOSANGO, cor_forte)
        _losango(p, LOSANGO * 0.45, Color(0.02, 0.04, 0.08, 0.9))


func _losango(centro: Vector2, raio: float, cor: Color) -> void:
    draw_colored_polygon(PackedVector2Array([
        centro + Vector2(0, -raio), centro + Vector2(raio, 0),
        centro + Vector2(0, raio), centro + Vector2(-raio, 0)]), cor)


## CINCO LINHAS DE PAUTA ATRAVESSANDO O FUNDO.
##
## Todas as telas aprovadas tem isto: a pauta musical passando por tras do
## conteudo, quase apagada. E o que amarra a interface ao assunto do jogo sem
## custar uma imagem — e um jogo de educacao musical nao deveria ter fundo
## generico de RPG.
func _pauta_de_fundo() -> void:
    var cor := Color(0.62, 0.72, 0.92, 0.055)
    var alto := size.y * 0.30
    var passo := 13.0
    for i in 5:
        var y := alto + float(i) * passo
        draw_line(Vector2(RECUO + 30.0, y), Vector2(size.x - RECUO - 30.0, y), cor, 1.0, true)
    var baixo := size.y * 0.72
    for i in 5:
        var y := baixo + float(i) * passo
        draw_line(Vector2(RECUO + 90.0, y), Vector2(size.x - RECUO - 60.0, y),
            Color(cor.r, cor.g, cor.b, cor.a * 0.7), 1.0, true)


## Notas boiando, desenhadas como forma e nao como letra.
##
## Tentar escrever "♪" num Label depende de a fonte ter o glifo — e a fonte
## padrao do motor nao tem: foi assim que o botao de fechar virou um quadrado
## vazio na tela. Cabeca, haste e bandeira desenhadas nunca dao tofu.
func _notas_soltas() -> void:
    if notas <= 0:
        return
    var sorte := RandomNumberGenerator.new()
    # Semente fixa: as notas ficam SEMPRE no mesmo lugar. Fundo que se
    # reembaralha a cada redimensionamento chama atencao para si.
    sorte.seed = 20260902
    for i in notas:
        var p := Vector2(
            lerpf(RECUO + 40.0, size.x - RECUO - 40.0, sorte.randf()),
            lerpf(RECUO + 40.0, size.y - RECUO - 40.0, sorte.randf()))
        var escala: float = lerpf(0.7, 1.5, sorte.randf())
        var dupla: bool = sorte.randf() > 0.55
        _nota(p, escala, dupla, sorte.randf_range(-0.25, 0.25))


func _nota(onde: Vector2, escala: float, dupla: bool, giro: float) -> void:
    var cor := cor_da_nota
    var haste := 26.0 * escala
    var cabeca := 5.0 * escala
    draw_set_transform(onde, giro, Vector2.ONE)
    # A cabeca e uma elipse inclinada: circulo achatado pela transformacao.
    draw_set_transform(onde, giro, Vector2(1.35, 1.0))
    draw_circle(Vector2.ZERO, cabeca, cor)
    draw_set_transform(onde, giro, Vector2.ONE)
    draw_line(Vector2(cabeca * 1.25, 0.0), Vector2(cabeca * 1.25, -haste), cor,
        maxf(1.0, 1.4 * escala), true)
    if dupla:
        # A segunda cabeca e a barra que liga as duas: a colcheia dupla.
        var longe := 17.0 * escala
        draw_set_transform(onde + Vector2(longe, 0.0), giro, Vector2(1.35, 1.0))
        draw_circle(Vector2.ZERO, cabeca, cor)
        draw_set_transform(onde, giro, Vector2.ONE)
        draw_line(Vector2(longe + cabeca * 1.25, 0.0),
            Vector2(longe + cabeca * 1.25, -haste), cor, maxf(1.0, 1.4 * escala), true)
        draw_line(Vector2(cabeca * 1.25, -haste + 1.0),
            Vector2(longe + cabeca * 1.25, -haste + 1.0), cor, maxf(1.5, 2.2 * escala), true)
    else:
        # A bandeira da colcheia solta, em tres tracos curtos.
        for k in 3:
            var y := -haste + float(k) * 3.0 * escala
            draw_line(Vector2(cabeca * 1.25, y),
                Vector2(cabeca * 1.25 + (7.0 - float(k) * 1.4) * escala, y + 4.0 * escala),
                cor, maxf(1.0, 1.2 * escala), true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
