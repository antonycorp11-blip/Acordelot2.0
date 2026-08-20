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
    # Gancho de teste, irmao do --shot e do --hora: `-- --onde=0,240` nasce o
    # jogador naquela coordenada de mundo. Conferir uma cidade do outro lado do
    # mapa sem ele exigiria atravessar o mundo andando a cada captura.
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--onde="):
            var partes := arg.trim_prefix("--onde=").split(",")
            _player.global_position = Vector3(float(partes[0]), 16.0, float(partes[1]))
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--pos="):
            var parts := arg.substr(6).split(",")
            if parts.size() == 2:
                var px := float(parts[0])
                var pz := float(parts[1])
                _player.global_position = Vector3(px, Relevo.altura(px, pz) + 1.1, pz)

    if OS.has_feature("web"):
        var ambiente: Environment = $WorldEnvironment.environment
        ambiente.tonemap_exposure *= EXPOSICAO_NA_WEB
    _streamer.ensure_ground_at(_player.global_position)
    $MapLayer/MapButton.pressed.connect(_map.toggle)
    $MobileControls/AttackButton.pressed.connect(_player.atacar)
    $MobileControls/FlyButton.pressed.connect(_player.alternar_voo)
    # Botao de editor: um so, no canto, porque o editor e ferramenta de autor e
    # nao pode competir por espaco com os controles de jogo.
    var abrir := Button.new()
    abrir.text = "EDITOR"
    abrir.position = Vector2(12, 12)
    abrir.pressed.connect($EditorDeMapa.alternar)
    $MapLayer.add_child(abrir)

    if OS.get_cmdline_user_args().has("--shot"):
        _shoot_and_quit()


## Gancho de teste: roda o jogo com `-- --shot` e ele salva um quadro em
## user://shot.png e sai. E assim que se confere o mundo sem depender de alguem
## olhar a janela — captura de tela do sistema nao alcanca a janela do jogo.
func _shoot_and_quit() -> void:
    # Espera o mundo assentar: com o build a um pedaco por quadro, medir cedo
    # mede a montagem, nao o jogo.
    await get_tree().create_timer(8.0).timeout
    # Vista de planta: camera ortografica direto de cima.
    #
    # Existe para desenhar cidade. A camera do jogo olha a 52 graus, e de 52
    # graus nao da para julgar tracado urbano — casa esconde casa, e a distancia
    # entre duas ruas muda conforme a posicao na tela. Em projecao ortografica de
    # cima, o que se ve E a planta: as ruas ficam retas, os aneis ficam redondos
    # e o alinhamento dos lotes salta aos olhos.
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--planta"):
            var alcance := 130.0
            if "=" in arg:
                alcance = float(arg.split("=")[1])
            _vista_de_planta(alcance)
            await get_tree().create_timer(2.5).timeout

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

## Troca a camera do jogo por uma ortografica olhando o chao de cima.
##
## Ortografica e nao perspectiva: em perspectiva, dois quarteiroes de mesmo
## tamanho aparecem com tamanhos diferentes conforme a distancia do centro da
## tela, e e impossivel saber se o desalinhamento e do desenho ou da lente.
func _vista_de_planta(alcance: float) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = alcance
    camera.far = 400.0
    camera.global_position = _player.global_position + Vector3(0.0, 180.0, 0.0)
    camera.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    # O seguidor continuaria arrastando a camera de volta para o heroi.
    $CameraRig.set_process(false)
    # HUD fora: barra do dia, joystick e mapa nao pertencem a uma planta.
    $MobileControls.visible = false
    $DebugHud.visible = false
    $MapLayer.visible = false
    # Nevoa fora tambem. Ela e calculada pela distancia a camera, e a camera de
    # planta esta a 180 m: a cidade inteira sai lavada de cinza.
    var ambiente: Environment = $WorldEnvironment.environment
    ambiente.fog_enabled = false

func _hero_atacar() -> void:
    _player.atacar()

func _process(_delta: float) -> void:
    var cell := World.cell_at(_player.global_position)
    _status.text = "%s\ncelula (%d, %d) · pedacos %d · %d fps" % [
        World.region_name(cell), cell.x, cell.y,
        _streamer.loaded_count(), Engine.get_frames_per_second()]
