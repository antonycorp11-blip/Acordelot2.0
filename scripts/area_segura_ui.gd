extends RefCounted
## Mantem telas 16:9 inteiras dentro da area realmente utilizavel do celular.
## Navegadores em paisagem perdem alguns pixels para cantos arredondados,
## recorte da camera e barras do sistema; usar o viewport inteiro fazia esses
## pixels parecerem "vazamento" mesmo com a proporcao matematica correta.

const RECUO_RELATIVO := 0.032
const RECUO_MINIMO := 12.0


static func recuo(viewport: Vector2) -> float:
    return maxf(RECUO_MINIMO, minf(viewport.x, viewport.y) * RECUO_RELATIVO)


static func ajustar_base(base: Control, tamanho_design: Vector2, viewport: Vector2) -> void:
    if base == null or viewport.x <= 0.0 or viewport.y <= 0.0:
        return
    var margem := recuo(viewport)
    var area := Vector2(maxf(1.0, viewport.x - margem * 2.0),
        maxf(1.0, viewport.y - margem * 2.0))
    var fator := minf(area.x / tamanho_design.x, area.y / tamanho_design.y)
    base.scale = Vector2.ONE * fator
    base.position = (viewport - tamanho_design * fator) * 0.5


## Encosta um controle num canto da tela, ja com o recuo do aparelho.
##
## Existe para os controles do polegar — direcional, botao de voo, roda de
## combate — pararem de calcular a margem cada um por conta. Era assim que o
## botao de voo continuava colado em 36 px enquanto o direcional passou a
## respeitar o recuo: os dois se encontraram e ficaram um por cima do outro.
##
## `empilhar` afasta o controle do canto na vertical, para uma peca ficar acima
## da outra na mesma coluna.
static func encostar_no_canto(c: Control, tamanho: Vector2, viewport: Vector2,
        esquerda: bool, embaixo: bool, empilhar := 0.0) -> void:
    if c == null or viewport.x <= 0.0 or viewport.y <= 0.0:
        return
    var margem := recuo(viewport) + 10.0
    c.anchor_left = 0.0 if esquerda else 1.0
    c.anchor_right = c.anchor_left
    c.anchor_top = 1.0 if embaixo else 0.0
    c.anchor_bottom = c.anchor_top
    if esquerda:
        c.offset_left = margem
        c.offset_right = margem + tamanho.x
    else:
        c.offset_right = -margem
        c.offset_left = -margem - tamanho.x
    if embaixo:
        c.offset_bottom = -margem - empilhar
        c.offset_top = c.offset_bottom - tamanho.y
    else:
        c.offset_top = margem + empilhar
        c.offset_bottom = c.offset_top + tamanho.y


static func ajustar_container(container: Control, viewport: Vector2) -> void:
    if container == null:
        return
    var margem := recuo(viewport)
    container.offset_left = margem
    container.offset_top = margem
    container.offset_right = -margem
    container.offset_bottom = -margem
