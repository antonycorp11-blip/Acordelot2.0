extends Node3D
## Raiz do mundo contínuo. Poe o jogador no mapa inicial do jogo 2D e mantem o
## HUD de teste, que e como se confere no celular se o streaming esta sadio.

@onready var _player: CharacterBody3D = $Player
@onready var _streamer: Node3D = $WorldStreamer
@onready var _status: Label = $DebugHud/Status
@onready var _map: Control = $MapLayer/WorldMap

## O navegador do celular entrega a cena visivelmente mais clara que o desktop,
## com a MESMA build: o caminho de cor do WebGL nao bate com o do OpenGL nativo.
## Perseguir isso parametro por parametro seria caça a fantasma; compensar na
## exposicao, so no alvo web, e verificavel no aparelho em um minuto.
const EXPOSICAO_NA_WEB := 0.52

func _ready() -> void:
    _player.global_position = World.start_position()

    if OS.has_feature("web"):
        var ambiente: Environment = $WorldEnvironment.environment
        ambiente.tonemap_exposure *= EXPOSICAO_NA_WEB
    _streamer.ensure_ground_at(_player.global_position)
    $MapLayer/MapButton.pressed.connect(_map.toggle)
    $MobileControls/AttackButton.pressed.connect(_player.atacar)
    if OS.get_cmdline_user_args().has("--shot"):
        _shoot_and_quit()

## Gancho de teste: roda o jogo com `-- --shot` e ele salva um quadro em
## user://shot.png e sai. E assim que se confere o mundo sem depender de alguem
## olhar a janela — captura de tela do sistema nao alcanca a janela do jogo.
func _shoot_and_quit() -> void:
    # Espera o mundo assentar: com o build a um pedaco por quadro, medir cedo
    # mede a montagem, nao o jogo.
    await get_tree().create_timer(8.0).timeout
    # Camera colada no heroi: e a unica forma de julgar como a espada esta na mao.
    if OS.get_cmdline_user_args().has("--perto"):
        $CameraRig.definir_zoom(0.2)
        _hero_atacar()
        await get_tree().create_timer(0.5).timeout

    if OS.get_cmdline_user_args().has("--map"):
        _map.toggle()
        await get_tree().process_frame
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

func _hero_atacar() -> void:
    _player.atacar()

func _process(_delta: float) -> void:
    var cell := World.cell_at(_player.global_position)
    _status.text = "%s\ncelula (%d, %d) · pedacos %d · %d fps" % [
        World.region_name(cell), cell.x, cell.y,
        _streamer.loaded_count(), Engine.get_frames_per_second()]
