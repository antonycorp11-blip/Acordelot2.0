extends Node3D
## Raiz do mundo contínuo. Poe o jogador no mapa inicial do jogo 2D e mantem o
## HUD de teste, que e como se confere no celular se o streaming esta sadio.

@onready var _player: CharacterBody3D = $Player
@onready var _streamer: Node3D = $WorldStreamer
@onready var _status: Label = $DebugHud/Status

func _ready() -> void:
    _player.global_position = World.start_position()
    _streamer.ensure_ground_at(_player.global_position)
    if OS.get_cmdline_user_args().has("--shot"):
        _shoot_and_quit()

## Gancho de teste: roda o jogo com `-- --shot` e ele salva um quadro em
## user://shot.png e sai. E assim que se confere o mundo sem depender de alguem
## olhar a janela — captura de tela do sistema nao alcanca a janela do jogo.
func _shoot_and_quit() -> void:
    await get_tree().create_timer(4.0).timeout
    var camera := get_viewport().get_camera_3d()
    print("DEBUG jogador=", _player.global_position, " camera=", camera.global_position,
        " pedacos=", _streamer.loaded_count())
    var meshes := 0
    for chunk in _streamer.get_children():
        meshes += chunk.find_children("*", "MeshInstance3D", true, false).size()
    print("DEBUG malhas=", meshes)
    var image := get_viewport().get_texture().get_image()
    image.save_png("user://shot.png")
    print("SHOT ", ProjectSettings.globalize_path("user://shot.png"))
    get_tree().quit()

func _process(_delta: float) -> void:
    var cell := World.cell_at(_player.global_position)
    _status.text = "%s\ncelula (%d, %d) · pedacos %d · %d fps" % [
        World.region_name(cell), cell.x, cell.y,
        _streamer.loaded_count(), Engine.get_frames_per_second()]
