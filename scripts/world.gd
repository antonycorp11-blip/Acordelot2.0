extends Node
## Mapa-mundo do Acordelot em 3D.
##
## A grade do jogo 2D (gridPos) virou a planta de um terreno unico: a celula
## (col, row) ocupa o quadrado de REGION_SIZE metros naquela posicao. Nao ha
## teleporte entre cenarios — o jogador atravessa a fronteira andando, e quem
## troca e o streamer, carregando a regiao vizinha antes dela aparecer.

const REGION_SIZE := 120.0

var regions: Dictionary = {}
var catalog: Dictionary = {}
var start_cell := Vector2i.ZERO

func _ready() -> void:
    var world_data := _load_json("res://data/regions.json")
    catalog = _load_json("res://data/asset_catalog.json").get("tags", {})

    var start_id: String = world_data.get("start_map", "")
    for region in world_data.get("regions", []):
        var cell := Vector2i(int(region["col"]), int(region["row"]))
        regions[cell] = region
        if region["id"] == start_id:
            start_cell = cell

func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Falta o arquivo de mundo: " + path)
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("JSON invalido em " + path)
        return {}
    return parsed

## Centro da celula em metros. A celula (0,0) fica na origem do mundo.
func cell_center(cell: Vector2i) -> Vector3:
    return Vector3(cell.x * REGION_SIZE, 0.0, cell.y * REGION_SIZE)

func cell_at(position: Vector3) -> Vector2i:
    return Vector2i(
        int(round(position.x / REGION_SIZE)),
        int(round(position.z / REGION_SIZE))
    )

func region_at(cell: Vector2i) -> Dictionary:
    return regions.get(cell, {})

func region_name(cell: Vector2i) -> String:
    return region_at(cell).get("name", "")

## Onde o jogador nasce: o centro da Floresta do Despertar, o mapa inicial do
## jogo 2D. O y deixa a capsula acima do chao para o primeiro quadro nao afundar.
func start_position() -> Vector3:
    return cell_center(start_cell) + Vector3(0.0, 1.1, 0.0)
