extends Node3D
class_name EditorDeMapa
## Editor de mapa que roda DENTRO do jogo publicado, no navegador.
##
## Permite posicionar modelos 3D (do catálogo ou importados via GLB em tempo de execução),
## pintar ruas de calçamento ou terra em estilo SimCity com atualização do shader em tempo real,
## e controlar posição, escala, elevação e rotação completa nos três eixos (X, Y, Z).

const ARQUIVO := "user://mapa_editado.json"
const ARQUIVO_MASCARA_RUA := "user://road_mask_custom.png"
const DIRETORIO_CUSTOM := "user://modelos_custom/"

## Distância máxima do raio de mira até o chão.
const ALCANCE_DO_CLIQUE := 400.0

const WORLD_MIN := Vector2(-660.0, -540.0)
const WORLD_SIZE := Vector2(1320.0, 1200.0)

const RELEVO := preload("res://scripts/relevo.gd")

enum ModoEditor {
    OBJETOS = 0,
    RUA_PEDRA = 1,
    RUA_TERRA = 2,
    RUA_BORRACHA = 3,
}

@export var jogador: Node3D
@export var camera_do_jogo: Node3D

var ativo := false
var _pecas: Array[Dictionary] = []
var _nos: Array[Node3D] = []
var _selecionada := -1

var _modo: ModoEditor = ModoEditor.OBJETOS
var _modelo_atual := ""
var _tag_atual := ""
var _pincel := false
var _raio_pincel_rua := 2 # pixels (cada pixel = 2 metros)

var _camera: Camera3D
var _alvo := Vector3.ZERO
var _altura := 60.0
var _arrastando := false
var _ultimo_ponto_rua := Vector2(-1, -1)

# UI
var _painel: CanvasLayer
var _lista: ItemList
var _status: Label
var _painel_objetos: VBoxContainer
var _painel_ruas: VBoxContainer
var _inspector_peca: VBoxContainer

# Road painting textures
var _road_image: Image
var _road_texture: ImageTexture
var _streamer: Node3D

# JS / Web file bridge
var _js_file_callback: JavaScriptObject = null


func _ready() -> void:
    _camera = Camera3D.new()
    _camera.current = false
    _camera.far = 600.0
    add_child(_camera)

    DirAccess.make_dir_recursive_absolute(DIRETORIO_CUSTOM)

    get_window().files_dropped.connect(_ao_soltar_arquivos_janela)
    _configurar_web_file_drop()

    _inicializar_mascara_ruas()
    _montar_painel()
    _carregar_modelos_custom_salvos()
    carregar()
    _painel.visible = false


# ─────────────────────────────────────────────────────────────────── entrada

func alternar() -> void:
    ativo = not ativo
    _painel.visible = ativo
    _camera.current = ativo
    if ativo:
        _alvo = jogador.global_position if jogador else Vector3.ZERO
        _posicionar_camera()
        _sincronizar_textura_rua()
    elif camera_do_jogo:
        var c := camera_do_jogo.find_child("Camera3D", true, false) as Camera3D
        if c:
            c.current = true
    _atualizar_status()


func _unhandled_input(evento: InputEvent) -> void:
    if not ativo:
        return

    if evento is InputEventMouseButton:
        if evento.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(-0.12)
        elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(0.12)
        elif evento.button_index == MOUSE_BUTTON_LEFT:
            _arrastando = evento.pressed
            if evento.pressed:
                _ultimo_ponto_rua = Vector2(-1, -1)
                _clicar(evento.position)
            else:
                _ultimo_ponto_rua = Vector2(-1, -1)
        elif evento.button_index == MOUSE_BUTTON_RIGHT and evento.pressed:
            if _modo == ModoEditor.OBJETOS:
                _selecionar_em(evento.position)

    elif evento is InputEventMouseMotion:
        if not _arrastando:
            return
        if _modo != ModoEditor.OBJETOS:
            _pintar_rua_em(evento.position)
        elif _pincel and not _modelo_atual.is_empty():
            _plantar_em(evento.position)
        else:
            _mover_camera(evento.relative)

    elif evento is InputEventKey and evento.pressed:
        _tecla(evento.keycode)


func _tecla(codigo: int) -> void:
    if _selecionada < 0:
        if codigo == KEY_ESCAPE:
            _modelo_atual = ""
            _atualizar_status()
        return

    var passo := 0.5
    var peca := _pecas[_selecionada]
    var rot: Array = _obter_rotacao_peca(peca)

    match codigo:
        KEY_A: peca["position"][0] -= passo
        KEY_D: peca["position"][0] += passo
        KEY_W: peca["position"][1] -= passo
        KEY_S: peca["position"][1] += passo
        # Rotação em Y (Yaw)
        KEY_Q:
            rot[1] = fposmod(rot[1] - 15.0, 360.0)
            peca["rotation"] = rot
        KEY_E:
            rot[1] = fposmod(rot[1] + 15.0, 360.0)
            peca["rotation"] = rot
        # Rotação em X (Pitch)
        KEY_Z:
            rot[0] = fposmod(rot[0] - 15.0, 360.0)
            peca["rotation"] = rot
        KEY_C:
            rot[0] = fposmod(rot[0] + 15.0, 360.0)
            peca["rotation"] = rot
        # Rotação em Z (Roll)
        KEY_T:
            rot[2] = fposmod(rot[2] - 15.0, 360.0)
            peca["rotation"] = rot
        KEY_G:
            rot[2] = fposmod(rot[2] + 15.0, 360.0)
            peca["rotation"] = rot
        # Nivelar rotação X e Z
        KEY_X:
            rot[0] = 0.0
            rot[2] = 0.0
            peca["rotation"] = rot
        # Elevação Y
        KEY_R: peca["y"] = float(peca.get("y", 0.0)) + 0.25
        KEY_F: peca["y"] = float(peca.get("y", 0.0)) - 0.25
        # Escala
        KEY_EQUAL, KEY_KP_ADD: peca["scale"] = float(peca["scale"]) * 1.1
        KEY_MINUS, KEY_KP_SUBTRACT: peca["scale"] = float(peca["scale"]) / 1.1
        KEY_DELETE, KEY_BACKSPACE:
            _apagar(_selecionada)
            return
        KEY_ESCAPE:
            _selecionada = -1
            _atualizar_status()
            return
        _:
            return
    _refazer(_selecionada)
    _atualizar_status()


# ─────────────────────────────────────────────────────────────────── camera

func _zoom(quanto: float) -> void:
    _altura = clampf(_altura * (1.0 + quanto), 8.0, 220.0)
    _posicionar_camera()


func _mover_camera(delta: Vector2) -> void:
    var escala := _altura * 0.0022
    _alvo += Vector3(-delta.x * escala, 0.0, -delta.y * escala)
    _posicionar_camera()


func _posicionar_camera() -> void:
    _camera.global_position = _alvo + Vector3(0.0, _altura, _altura * 0.78)
    _camera.look_at(_alvo, Vector3.UP)


func _ponto_no_chao(tela: Vector2) -> Vector3:
    var origem := _camera.project_ray_origin(tela)
    var direcao := _camera.project_ray_normal(tela)
    if direcao.y >= -0.001:
        return Vector3.INF
    var chao := RELEVO.altura(_alvo.x, _alvo.z)
    var distancia := (chao - origem.y) / direcao.y
    if distancia < 0.0 or distancia > ALCANCE_DO_CLIQUE:
        return Vector3.INF
    var ponto := origem + direcao * distancia
    ponto.y = RELEVO.altura(ponto.x, ponto.z)
    return ponto


# ────────────────────────────────────────────────────────────────── edicao de pecas

func _clicar(tela: Vector2) -> void:
    if _modo != ModoEditor.OBJETOS:
        _pintar_rua_em(tela)
    elif _modelo_atual.is_empty():
        _selecionar_em(tela)
    else:
        _plantar_em(tela)


func _plantar_em(tela: Vector2) -> void:
    var ponto := _ponto_no_chao(tela)
    if ponto == Vector3.INF:
        return
    if _pincel:
        for peca in _pecas:
            var onde := Vector2(peca["position"][0], peca["position"][1])
            if onde.distance_to(Vector2(ponto.x, ponto.z)) < 2.0:
                return

    _pecas.append({
        "id": "%s_%d" % [_tag_atual, Time.get_ticks_msec()],
        "tag": _tag_atual, "model": _modelo_atual,
        "position": [snappedf(ponto.x, 0.25), snappedf(ponto.z, 0.25)],
        "rotation": [0.0, 0.0, 0.0], "scale": 1.0, "y": 0.0,
    })
    _nos.append(null)
    _refazer(_pecas.size() - 1)
    _selecionada = _pecas.size() - 1
    _atualizar_status()


func _selecionar_em(tela: Vector2) -> void:
    var ponto := _ponto_no_chao(tela)
    if ponto == Vector3.INF:
        return
    var melhor := -1
    var menor := 4.0
    for i in _pecas.size():
        var onde := Vector2(_pecas[i]["position"][0], _pecas[i]["position"][1])
        var d := onde.distance_to(Vector2(ponto.x, ponto.z))
        if d < menor:
            menor = d
            melhor = i
    _selecionada = melhor
    _atualizar_status()


func _obter_rotacao_peca(peca: Dictionary) -> Array:
    var rot = peca.get("rotation", [0.0, 0.0, 0.0])
    if typeof(rot) == TYPE_ARRAY:
        var rx: float = float(rot[0]) if rot.size() > 0 else 0.0
        var ry: float = float(rot[1]) if rot.size() > 1 else 0.0
        var rz: float = float(rot[2]) if rot.size() > 2 else 0.0
        return [rx, ry, rz]
    return [0.0, float(rot), 0.0]


func _refazer(indice: int) -> void:
    if _nos[indice] != null and is_instance_valid(_nos[indice]):
        _nos[indice].queue_free()
    var peca := _pecas[indice]
    var kind: Dictionary = World.catalog.get(String(peca["tag"]), {})
    var no := ChunkBuilder._criar(kind, RandomNumberGenerator.new(), String(peca["model"]))
    if no == null:
        return
    var x: float = peca["position"][0]
    var z: float = peca["position"][1]
    no.position = Vector3(x, RELEVO.altura(x, z) + float(peca.get("y", 0.0)), z)

    var rot := _obter_rotacao_peca(peca)
    no.rotation = Vector3(deg_to_rad(rot[0]), deg_to_rad(rot[1]), deg_to_rad(rot[2]))
    no.scale = Vector3.ONE * float(peca.get("scale", 1.0))
    add_child(no)
    _nos[indice] = no


func _apagar(indice: int) -> void:
    if _nos[indice] != null and is_instance_valid(_nos[indice]):
        _nos[indice].queue_free()
    _pecas.remove_at(indice)
    _nos.remove_at(indice)
    _selecionada = -1
    _atualizar_status()


# ────────────────────────────────────────────────────────────────── pintura de ruas (SimCity)

func _inicializar_mascara_ruas() -> void:
    if FileAccess.file_exists(ARQUIVO_MASCARA_RUA):
        _road_image = Image.load_from_file(ARQUIVO_MASCARA_RUA)
    if _road_image == null or _road_image.is_empty():
        var base := load("res://textures/road_mask.png") as Texture2D
        if base:
            _road_image = base.get_image()
        else:
            _road_image = Image.create(660, 600, false, Image.FORMAT_RGB8)
            _road_image.fill(Color.BLACK)
    _road_texture = ImageTexture.create_from_image(_road_image)


func _sincronizar_textura_rua() -> void:
    if _streamer == null:
        _streamer = get_parent().find_child("WorldStreamer", true, false)
    if _streamer and _streamer.has_method("set_road_mask_texture"):
        _streamer.set_road_mask_texture(_road_texture)


func _pintar_rua_em(tela: Vector2) -> void:
    var ponto := _ponto_no_chao(tela)
    if ponto == Vector3.INF:
        return
    var w := _road_image.get_width()
    var h := _road_image.get_height()

    var px := int(clampf(((ponto.x - WORLD_MIN.x) / WORLD_SIZE.x) * w, 0, w - 1))
    var py := int(clampf(((ponto.z - WORLD_MIN.y) / WORLD_SIZE.y) * h, 0, h - 1))

    var destino := Vector2(px, py)
    if _ultimo_ponto_rua == Vector2(-1, -1):
        _ultimo_ponto_rua = destino

    # Interpola pontos entre o último e o atual para traçado contínuo
    var dist := _ultimo_ponto_rua.distance_to(destino)
    var passos := int(maxf(1.0, ceil(dist / 1.0)))
    for s in range(passos + 1):
        var t := float(s) / float(passos)
        var pos_interp := _ultimo_ponto_rua.lerp(destino, t)
        _aplicar_pincel_rua(int(pos_interp.x), int(pos_interp.y))

    _ultimo_ponto_rua = destino
    _road_texture.update(_road_image)


func _aplicar_pincel_rua(cx: int, cy: int) -> void:
    var w := _road_image.get_width()
    var h := _road_image.get_height()
    var r := _raio_pincel_rua

    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            var px := cx + dx
            var py := cy + dy
            if px < 0 or px >= w or py < 0 or py >= h:
                continue
            var d := sqrt(float(dx * dx + dy * dy))
            if d > float(r) + 0.3:
                continue
            var peso := clampf(1.0 - (d / (float(r) + 0.3)), 0.2, 1.0)
            var cor := _road_image.get_pixel(px, py)

            match _modo:
                ModoEditor.RUA_PEDRA:
                    # Calçamento de pedra: canal G alto, diminui R
                    cor.g = clampf(maxf(cor.g, peso), 0.0, 1.0)
                    cor.r = clampf(cor.r * (1.0 - peso * 0.8), 0.0, 1.0)
                ModoEditor.RUA_TERRA:
                    # Trilha de terra: canal R alto
                    if cor.g < 0.3:
                        cor.r = clampf(maxf(cor.r, peso), 0.0, 1.0)
                ModoEditor.RUA_BORRACHA:
                    # Borracha: zera rua para voltar grama natural
                    cor.r = clampf(cor.r * (1.0 - peso), 0.0, 1.0)
                    cor.g = clampf(cor.g * (1.0 - peso), 0.0, 1.0)

            _road_image.set_pixel(px, py, cor)


func _limpar_ruas_custom() -> void:
    var base := load("res://textures/road_mask.png") as Texture2D
    if base:
        _road_image = base.get_image()
        _road_texture.update(_road_image)
        if FileAccess.file_exists(ARQUIVO_MASCARA_RUA):
            DirAccess.remove_absolute(ARQUIVO_MASCARA_RUA)
        _avisar("Ruas restauradas ao mapa original.")


# ────────────────────────────────────────────────────────────────── importador GLB runtime

func _ao_soltar_arquivos_janela(arquivos: PackedStringArray) -> void:
    for arq in arquivos:
        var ext := arq.get_extension().to_lower()
        if ext == "glb" or ext == "gltf":
            var bytes := FileAccess.get_file_as_bytes(arq)
            if not bytes.is_empty():
                importar_glb_bytes(arq.get_file(), bytes)


func _configurar_web_file_drop() -> void:
    if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
        return

    _js_file_callback = JavaScriptBridge.create_callback(_ao_receber_glb_do_js)
    var window = JavaScriptBridge.get_interface("window")
    if window:
        window._godot_import_glb_b64 = _js_file_callback
        JavaScriptBridge.eval("""
        (function() {
            if (window._godot_glb_drop_installed) return;
            window._godot_glb_drop_installed = true;

            window.addEventListener('dragover', function(e) {
                e.preventDefault();
            });

            function processarArquivo(file) {
                if (!file.name.toLowerCase().endsWith('.glb') && !file.name.toLowerCase().endsWith('.gltf')) return;
                var reader = new FileReader();
                reader.onload = function(evt) {
                    var bytes = new Uint8Array(evt.target.result);
                    var binary = '';
                    var len = bytes.byteLength;
                    for (var i = 0; i < len; i += 8192) {
                        binary += String.fromCharCode.apply(null, bytes.subarray(i, Math.min(i + 8192, len)));
                    }
                    var b64 = btoa(binary);
                    if (window._godot_import_glb_b64) {
                        window._godot_import_glb_b64(file.name, b64);
                    }
                };
                reader.readAsArrayBuffer(file);
            }

            window.addEventListener('drop', function(e) {
                e.preventDefault();
                if (e.dataTransfer && e.dataTransfer.files) {
                    for (var i = 0; i < e.dataTransfer.files.length; i++) {
                        processarArquivo(e.dataTransfer.files[i]);
                    }
                }
            });

            window._godot_abrir_seletor_glb = function() {
                var input = document.createElement('input');
                input.type = 'file';
                input.accept = '.glb,.gltf';
                input.onchange = function(e) {
                    if (input.files && input.files.length > 0) {
                        processarArquivo(input.files[0]);
                    }
                };
                input.click();
            };
        })();
        """)


func _ao_receber_glb_do_js(args: Array) -> void:
    if args.size() < 2:
        return
    var nome: String = String(args[0])
    var b64: String = String(args[1])
    var bytes := Marshalls.base64_to_raw(b64)
    if not bytes.is_empty():
        importar_glb_bytes(nome, bytes)


func abrir_seletor_de_arquivo() -> void:
    if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
        JavaScriptBridge.eval("if (window._godot_abrir_seletor_glb) window._godot_abrir_seletor_glb();")
    else:
        var dialog := FileDialog.new()
        dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
        dialog.access = FileDialog.ACCESS_FILESYSTEM
        dialog.filters = PackedStringArray(["*.glb ; Modelos GLB", "*.gltf ; Modelos GLTF"])
        dialog.file_selected.connect(func(caminho):
            var bytes := FileAccess.get_file_as_bytes(caminho)
            if not bytes.is_empty():
                importar_glb_bytes(caminho.get_file(), bytes)
            dialog.queue_free()
        )
        dialog.canceled.connect(func(): dialog.queue_free())
        add_child(dialog)
        dialog.popup_centered_ratio(0.7)


func importar_glb_bytes(nome_arquivo: String, bytes: PackedByteArray) -> bool:
    if bytes.is_empty():
        return false
    if not nome_arquivo.ends_with(".glb") and not nome_arquivo.ends_with(".gltf"):
        nome_arquivo += ".glb"

    var caminho := DIRETORIO_CUSTOM + nome_arquivo
    var f := FileAccess.open(caminho, FileAccess.WRITE)
    if f:
        f.store_buffer(bytes)
        f.close()

    var packed := ChunkBuilder._carregar_glb_bytes(bytes)
    if packed == null:
        _avisar("Erro ao ler modelo GLB: " + nome_arquivo)
        return false

    ChunkBuilder.registrar_cena_custom(caminho, packed)

    if not World.catalog.has("custom"):
        World.catalog["custom"] = {"models": [], "altura": 0.0, "is_custom": true, "solid": true}
    if not World.catalog["custom"]["models"].has(caminho):
        World.catalog["custom"]["models"].append(caminho)

    var rotulo := "custom · " + nome_arquivo.get_basename()
    var ja_tem := false
    for i in _lista.item_count:
        if _lista.get_item_text(i) == rotulo:
            ja_tem = true
            _lista.select(i)
            _escolher(i)
            break

    if not ja_tem:
        _lista.add_item(rotulo)
        var novo_idx := _lista.item_count - 1
        _lista.set_item_metadata(novo_idx, ["custom", caminho])
        _lista.select(novo_idx)
        _escolher(novo_idx)

    _avisar("Modelo importado: " + nome_arquivo)
    return true


func _carregar_modelos_custom_salvos() -> void:
    var dir := DirAccess.open(DIRETORIO_CUSTOM)
    if dir == null:
        return
    dir.list_dir_begin()
    var arq := dir.get_next()
    while not arq.is_empty():
        if not dir.current_is_dir() and (arq.ends_with(".glb") or arq.ends_with(".gltf")):
            var caminho := DIRETORIO_CUSTOM + arq
            var packed := ChunkBuilder._carregar_glb_de_arquivo(caminho)
            if packed:
                ChunkBuilder.registrar_cena_custom(caminho, packed)
                if not World.catalog.has("custom"):
                    World.catalog["custom"] = {"models": [], "altura": 0.0, "is_custom": true, "solid": true}
                if not World.catalog["custom"]["models"].has(caminho):
                    World.catalog["custom"]["models"].append(caminho)
                _lista.add_item("custom · " + arq.get_basename())
                _lista.set_item_metadata(_lista.item_count - 1, ["custom", caminho])
        arq = dir.get_next()
    dir.list_dir_end()


# ────────────────────────────────────────────────────────── disco e painel

func salvar() -> void:
    var arquivo := FileAccess.open(ARQUIVO, FileAccess.WRITE)
    if arquivo == null:
        _avisar("Erro: não consegui salvar pecas")
        return
    arquivo.store_string(JSON.stringify({"pecas": _pecas}, " "))
    arquivo.close()

    if _road_image and not _road_image.is_empty():
        _road_image.save_png(ARQUIVO_MASCARA_RUA)

    _avisar("Salvo no navegador — %d peças + ruas gravadas" % _pecas.size())


func carregar() -> void:
    if not FileAccess.file_exists(ARQUIVO):
        return
    var arquivo := FileAccess.open(ARQUIVO, FileAccess.READ)
    var dados = JSON.parse_string(arquivo.get_as_text())
    if typeof(dados) != TYPE_DICTIONARY:
        return
    for peca in dados.get("pecas", []):
        _pecas.append(peca)
        _nos.append(null)
        _refazer(_pecas.size() - 1)


func exportar() -> void:
    var payload := {
        "pecas": _pecas,
        "total_pecas": _pecas.size(),
        "instrucoes": "Copie as peças para city_layouts.json. As ruas foram gravadas na máscara."
    }
    DisplayServer.clipboard_set(JSON.stringify(payload, " "))
    _avisar("JSON copiado para a área de transferência (%d peças)" % _pecas.size())


func _montar_painel() -> void:
    _painel = CanvasLayer.new()
    _painel.layer = 20
    add_child(_painel)

    var fundo := PanelContainer.new()
    fundo.position = Vector2(12, 60)
    fundo.custom_minimum_size = Vector2(250, 600)
    _painel.add_child(fundo)

    var caixa := VBoxContainer.new()
    caixa.custom_minimum_size = Vector2(240, 0)
    fundo.add_child(caixa)

    # 1. Seletor de Modo
    var lbl_modo := Label.new()
    lbl_modo.text = "FERRAMENTAS"
    lbl_modo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caixa.add_child(lbl_modo)

    var grade_modos := GridContainer.new()
    grade_modos.columns = 2
    caixa.add_child(grade_modos)

    var btn_m_obj := Button.new()
    btn_m_obj.text = "📦 Modelos 3D"
    btn_m_obj.pressed.connect(func(): _trocar_modo(ModoEditor.OBJETOS))
    grade_modos.add_child(btn_m_obj)

    var btn_m_pedra := Button.new()
    btn_m_pedra.text = "🏛️ Rua de Pedra"
    btn_m_pedra.pressed.connect(func(): _trocar_modo(ModoEditor.RUA_PEDRA))
    grade_modos.add_child(btn_m_pedra)

    var btn_m_terra := Button.new()
    btn_m_terra.text = "🌿 Trilha Terra"
    btn_m_terra.pressed.connect(func(): _trocar_modo(ModoEditor.RUA_TERRA))
    grade_modos.add_child(btn_m_terra)

    var btn_m_borr := Button.new()
    btn_m_borr.text = "🧹 Borracha Rua"
    btn_m_borr.pressed.connect(func(): _trocar_modo(ModoEditor.RUA_BORRACHA))
    grade_modos.add_child(btn_m_borr)

    caixa.add_child(HSeparator.new())

    # 2. Painel de Objetos / Modelos
    _painel_objetos = VBoxContainer.new()
    caixa.add_child(_painel_objetos)

    var btn_importar := Button.new()
    btn_importar.text = "📂 + Importar GLB / GLTF"
    btn_importar.pressed.connect(abrir_seletor_de_arquivo)
    _painel_objetos.add_child(btn_importar)

    _lista = ItemList.new()
    _lista.custom_minimum_size = Vector2(240, 210)
    for tag in World.catalog:
        var kind: Dictionary = World.catalog[tag]
        for caminho in kind.get("models", []) + kind.get("sprites", []):
            _lista.add_item("%s · %s" % [tag, String(caminho).get_file().get_basename()])
            _lista.set_item_metadata(_lista.item_count - 1, [tag, caminho])
    _lista.item_selected.connect(_escolher)
    _painel_objetos.add_child(_lista)

    var pincel := CheckBox.new()
    pincel.text = "Pincel (arrastar planta)"
    pincel.toggled.connect(func(v): _pincel = v)
    _painel_objetos.add_child(pincel)

    # 3. Painel de Ruas
    _painel_ruas = VBoxContainer.new()
    _painel_ruas.visible = false
    caixa.add_child(_painel_ruas)

    var lbl_rua := Label.new()
    lbl_rua.text = "Largura da Rua / Pincel:"
    _painel_ruas.add_child(lbl_rua)

    var grade_raio := HBoxContainer.new()
    _painel_ruas.add_child(grade_raio)

    for r_opt in [[1, "2m"], [2, "4m"], [3, "6m"], [4, "8m"]]:
        var b_raio := Button.new()
        b_raio.text = r_opt[1]
        b_raio.pressed.connect(func(): _raio_pincel_rua = r_opt[0]; _avisar("Pincel: " + r_opt[1]))
        grade_raio.add_child(b_raio)

    var btn_limpar_rua := Button.new()
    btn_limpar_rua.text = "Restaurar Mapa Original"
    btn_limpar_rua.pressed.connect(_limpar_ruas_custom)
    _painel_ruas.add_child(btn_limpar_rua)

    # 4. Inspector de Peça Selecionada (Rotação 3D X, Y, Z + Altura + Escala)
    _inspector_peca = VBoxContainer.new()
    _inspector_peca.visible = false
    caixa.add_child(_inspector_peca)

    var lbl_insp := Label.new()
    lbl_insp.text = "Ajustar Peça Selecionada:"
    _inspector_peca.add_child(lbl_insp)

    # Rotação X, Y, Z
    var grid_rot := GridContainer.new()
    grid_rot.columns = 3
    _inspector_peca.add_child(grid_rot)

    var b_x_men := Button.new()
    b_x_men.text = "X -15° (Z)"
    b_x_men.pressed.connect(func(): _ajustar_rotacao_selecionada(0, -15.0))
    grid_rot.add_child(b_x_men)

    var b_x_mai := Button.new()
    b_x_mai.text = "X +15° (C)"
    b_x_mai.pressed.connect(func(): _ajustar_rotacao_selecionada(0, 15.0))
    grid_rot.add_child(b_x_mai)

    var b_x_zero := Button.new()
    b_x_zero.text = "Nivelar (X)"
    b_x_zero.pressed.connect(func(): _ajustar_rotacao_selecionada(-1, 0.0))
    grid_rot.add_child(b_x_zero)

    var b_y_men := Button.new()
    b_y_men.text = "Y -15° (Q)"
    b_y_men.pressed.connect(func(): _ajustar_rotacao_selecionada(1, -15.0))
    grid_rot.add_child(b_y_men)

    var b_y_mai := Button.new()
    b_y_mai.text = "Y +15° (E)"
    b_y_mai.pressed.connect(func(): _ajustar_rotacao_selecionada(1, 15.0))
    grid_rot.add_child(b_y_mai)

    var b_del := Button.new()
    b_del.text = "🗑️ Apagar"
    b_del.pressed.connect(func(): if _selecionada >= 0: _apagar(_selecionada))
    grid_rot.add_child(b_del)

    var b_z_men := Button.new()
    b_z_men.text = "Z -15° (T)"
    b_z_men.pressed.connect(func(): _ajustar_rotacao_selecionada(2, -15.0))
    grid_rot.add_child(b_z_men)

    var b_z_mai := Button.new()
    b_z_mai.text = "Z +15° (G)"
    b_z_mai.pressed.connect(func(): _ajustar_rotacao_selecionada(2, 15.0))
    grid_rot.add_child(b_z_mai)

    var b_dup := Button.new()
    b_dup.text = "📋 Duplicar"
    b_dup.pressed.connect(_duplicar_selecionada)
    grid_rot.add_child(b_dup)

    caixa.add_child(HSeparator.new())

    # 5. Ações Globais
    for rotulo in ["💾 Salvar", "📤 Exportar JSON", "🎮 Jogar"]:
        var botao := Button.new()
        botao.text = rotulo
        botao.pressed.connect(_acao.bind(rotulo))
        caixa.add_child(botao)

    _status = Label.new()
    _status.custom_minimum_size = Vector2(240, 80)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD
    caixa.add_child(_status)


func _trocar_modo(novo_modo: ModoEditor) -> void:
    _modo = novo_modo
    _painel_objetos.visible = (_modo == ModoEditor.OBJETOS)
    _painel_ruas.visible = (_modo != ModoEditor.OBJETOS)
    _selecionada = -1
    _atualizar_status()


func _ajustar_rotacao_selecionada(eixo: int, delta_graus: float) -> void:
    if _selecionada < 0 or _selecionada >= _pecas.size():
        return
    var peca := _pecas[_selecionada]
    var rot := _obter_rotacao_peca(peca)
    if eixo == -1:
        rot[0] = 0.0
        rot[2] = 0.0
    else:
        rot[eixo] = fposmod(rot[eixo] + delta_graus, 360.0)
    peca["rotation"] = rot
    _refazer(_selecionada)
    _atualizar_status()


func _duplicar_selecionada() -> void:
    if _selecionada < 0 or _selecionada >= _pecas.size():
        return
    var origem := _pecas[_selecionada]
    var nova := origem.duplicate(true)
    nova["id"] = "%s_%d" % [nova.get("tag", "dup"), Time.get_ticks_msec()]
    nova["position"] = [origem["position"][0] + 1.5, origem["position"][1] + 1.5]
    _pecas.append(nova)
    _nos.append(null)
    _refazer(_pecas.size() - 1)
    _selecionada = _pecas.size() - 1
    _atualizar_status()


func _escolher(indice: int) -> void:
    var dados: Array = _lista.get_item_metadata(indice)
    _tag_atual = dados[0]
    _modelo_atual = dados[1]
    _selecionada = -1
    _atualizar_status()


func _acao(rotulo: String) -> void:
    match rotulo:
        "💾 Salvar": salvar()
        "📤 Exportar JSON": exportar()
        "🎮 Jogar": alternar()


func _avisar(texto: String) -> void:
    _status.text = texto
    await get_tree().create_timer(2.5).timeout
    _atualizar_status()


func _atualizar_status() -> void:
    _inspector_peca.visible = (_selecionada >= 0 and _modo == ModoEditor.OBJETOS)

    var linhas: Array[String] = []
    match _modo:
        ModoEditor.OBJETOS:
            linhas.append("Modo: 📦 Objetos (%d peças)" % _pecas.size())
            if not _modelo_atual.is_empty():
                linhas.append("Plantando: " + _modelo_atual.get_file().get_basename())
            if _selecionada >= 0:
                var r := _obter_rotacao_peca(_pecas[_selecionada])
                linhas.append("Sel: WASD move | QE(Y) ZC(X) TG(Z) gira | RF alt | +- esc | Del apaga | Rot:[%.0f,%.0f,%.0f]" % [r[0], r[1], r[2]])
            else:
                linhas.append("Clique planta | Botão dir. seleciona | Arrastar move câmera | Arraste .GLB para importar")
        ModoEditor.RUA_PEDRA:
            linhas.append("Modo: 🏛️ Pintar Calçamento de Pedra")
            linhas.append("Arraste com o botão esquerdo para traçar ruas de pedra")
        ModoEditor.RUA_TERRA:
            linhas.append("Modo: 🌿 Pintar Trilha de Terra")
            linhas.append("Arraste para traçar caminhos rurais / terra batida")
        ModoEditor.RUA_BORRACHA:
            linhas.append("Modo: 🧹 Borracha de Estrada")
            linhas.append("Arraste para apagar calçamento/trilha e restaurar grama")

    _status.text = "\n".join(linhas)
