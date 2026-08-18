extends Control
## Mapa do mundo inteiro, desenhado a partir da MESMA grade que constroi o
## terreno — não de uma imagem à parte que envelhece sozinha.
##
## Existe porque no celular a câmera isométrica mostra uns 60 m de um mundo de
## 1320 m: sem isto não há como saber onde se está nem para onde ir.

const BIOME_COLORS := {
    "floresta": Color(0.16, 0.34, 0.18),
    "sombria": Color(0.10, 0.16, 0.20),
    "clareira": Color(0.32, 0.50, 0.24),
    "cidade": Color(0.44, 0.38, 0.26),
    "ruina": Color(0.34, 0.30, 0.32),
    "caverna": Color(0.20, 0.18, 0.26),
    "sagrado": Color(0.36, 0.30, 0.48),
    "mata": Color(0.09, 0.16, 0.11),
}

@export var player: Node3D

var _cell_size := 0.0
var _origin := Vector2.ZERO
var _first := Vector2i.ZERO

func _ready() -> void:
    set_process(false)
    hide()

func _process(_delta: float) -> void:
    queue_redraw()

func toggle() -> void:
    visible = not visible
    set_process(visible)
    queue_redraw()

func _draw() -> void:
    if World.regions.is_empty():
        return

    var cells: Array = World.regions.keys()
    _first = cells[0]
    var last: Vector2i = cells[0]
    for cell in cells:
        _first = Vector2i(mini(_first.x, cell.x), mini(_first.y, cell.y))
        last = Vector2i(maxi(last.x, cell.x), maxi(last.y, cell.y))

    var columns := last.x - _first.x + 1
    var rows := last.y - _first.y + 1
    # Margem para o mapa nao encostar na borda do celular, onde o dedo cobre.
    var usable := size - Vector2(48.0, 48.0)
    _cell_size = minf(usable.x / columns, usable.y / rows)
    _origin = (size - Vector2(columns, rows) * _cell_size) * 0.5

    draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.05, 0.92))

    var font := ThemeDB.fallback_font
    for cell in cells:
        var region: Dictionary = World.regions[cell]
        var rect := Rect2(_cell_to_screen(cell), Vector2.ONE * _cell_size)
        var color: Color = BIOME_COLORS.get(region.get("biome", ""), Color.DIM_GRAY)
        draw_rect(rect.grow(-1.0), color)

        # Só os 20 cenários do jogo antigo levam nome; a mata em volta é fundo, e
        # escrever "Mata Fechada" noventa vezes esconderia justamente o que importa.
        if String(region["id"]).begins_with("mata_"):
            continue
        draw_rect(rect.grow(-1.0), color.lightened(0.25), false, 2.0)
        var label := String(region.get("name", ""))
        draw_multiline_string(font, rect.position + Vector2(6.0, 18.0), label,
            HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, 13, 3,
            Color(0.92, 0.95, 0.9, 0.95))

    if player:
        var here := _world_to_screen(player.global_position)
        draw_circle(here, 7.0, Color(1.0, 0.86, 0.3))
        draw_arc(here, 11.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.7, 0.9), 2.0)

func _cell_to_screen(cell: Vector2i) -> Vector2:
    return _origin + Vector2(cell - _first) * _cell_size

## O marcador anda DENTRO da célula, não pula de quadrado em quadrado: o mundo é
## contínuo, e um marcador que salta faria o mapa mentir sobre isso.
func _world_to_screen(position: Vector3) -> Vector2:
    var in_cells := Vector2(position.x, position.z) / World.REGION_SIZE
    return _origin + (in_cells - Vector2(_first) + Vector2(0.5, 0.5)) * _cell_size
