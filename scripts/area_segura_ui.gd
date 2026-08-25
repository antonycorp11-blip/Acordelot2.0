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


static func ajustar_container(container: Control, viewport: Vector2) -> void:
    if container == null:
        return
    var margem := recuo(viewport)
    container.offset_left = margem
    container.offset_top = margem
    container.offset_right = -margem
    container.offset_bottom = -margem
