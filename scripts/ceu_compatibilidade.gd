extends Node3D
class_name CeuCompatibilidade

## Nuvens, estrelas e lua em geometria barata. O shader de céu customizado não
## funciona de forma confiável no Compatibility/Web; estas três malhas funcionam.

var ciclo: Node
var _nuvens: MultiMeshInstance3D
var _estrelas: MultiMeshInstance3D
var _lua: MeshInstance3D
var _material_nuvens: StandardMaterial3D
var _material_estrelas: StandardMaterial3D
var _material_lua: StandardMaterial3D
var _camera: Camera3D
var _ate_atualizar := 0.0

func _ready() -> void:
    _criar_nuvens()
    _criar_estrelas()
    _criar_lua()

func _process(delta: float) -> void:
    if _camera == null:
        _camera = get_viewport().get_camera_3d()
    if _camera:
        global_position.x = _camera.global_position.x
        global_position.z = _camera.global_position.z
    _ate_atualizar -= delta
    if _ate_atualizar > 0.0:
        return
    _ate_atualizar = 0.20
    var hora := float(ciclo.hora) if ciclo else 12.0
    var noite := _forca_da_noite(hora)
    _estrelas.visible = noite > 0.06
    _lua.visible = noite > 0.06
    _material_nuvens.albedo_color = Color(
        lerpf(1.0, 0.38, noite), lerpf(1.0, 0.43, noite),
        lerpf(1.0, 0.58, noite), lerpf(0.68, 0.25, noite))
    _material_estrelas.albedo_color.a = noite
    _material_lua.albedo_color.a = noite

func _forca_da_noite(hora: float) -> float:
    if hora >= 20.0 or hora <= 4.5:
        return 1.0
    if hora > 18.0:
        return smoothstep(18.0, 20.0, hora)
    if hora < 6.5:
        return 1.0 - smoothstep(4.5, 6.5, hora)
    return 0.0

func _criar_nuvens() -> void:
    var esfera := SphereMesh.new()
    esfera.radius = 1.0
    esfera.height = 2.0
    esfera.radial_segments = 8
    esfera.rings = 4
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(1.0, 1.0, 1.0, 0.70)
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _material_nuvens = mat
    esfera.material = mat
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = esfera
    multi.instance_count = 42
    var rng := RandomNumberGenerator.new()
    rng.seed = 8262026
    for i in multi.instance_count:
        var grupo := i / 6
        var dentro := i % 6
        var angulo := TAU * float(grupo) / 7.0 + rng.randf_range(-0.10, 0.10)
        var raio := 79.0 + rng.randf_range(-6.0, 5.0)
        var centro := Vector3(cos(angulo) * raio, 27.0 + grupo * 1.8, sin(angulo) * raio)
        var desvio := Vector3((dentro - 2.5) * 3.8, rng.randf_range(-1.2, 1.4), rng.randf_range(-2.0, 2.0))
        var escala := Vector3(rng.randf_range(4.2, 7.0), rng.randf_range(1.2, 2.5), rng.randf_range(2.7, 4.8))
        multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(escala), centro + desvio))
        multi.set_instance_color(i, Color(0.88 + rng.randf() * 0.12, 0.92 + rng.randf() * 0.08, 1.0, 0.72))
    _nuvens = MultiMeshInstance3D.new()
    _nuvens.name = "Nuvens"
    _nuvens.multimesh = multi
    _nuvens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_nuvens)

func _criar_estrelas() -> void:
    var ponto := SphereMesh.new()
    ponto.radius = 0.15
    ponto.height = 0.3
    ponto.radial_segments = 5
    ponto.rings = 2
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0.80, 0.90, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.72, 0.84, 1.0)
    mat.emission_energy_multiplier = 3.0
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material_estrelas = mat
    ponto.material = mat
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = ponto
    multi.instance_count = 88
    var rng := RandomNumberGenerator.new()
    rng.seed = 12011997
    for i in multi.instance_count:
        var angulo := rng.randf_range(0.0, TAU)
        var raio := rng.randf_range(82.0, 101.0)
        var p := Vector3(cos(angulo) * raio, rng.randf_range(20.0, 58.0), sin(angulo) * raio)
        var s := rng.randf_range(0.75, 1.8)
        multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))
    _estrelas = MultiMeshInstance3D.new()
    _estrelas.name = "Estrelas"
    _estrelas.multimesh = multi
    _estrelas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_estrelas)

func _criar_lua() -> void:
    var esfera := SphereMesh.new()
    esfera.radius = 3.8
    esfera.height = 7.6
    esfera.radial_segments = 12
    esfera.rings = 6
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.82, 0.90, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.60, 0.75, 1.0)
    mat.emission_energy_multiplier = 1.8
    _material_lua = mat
    esfera.material = mat
    _lua = MeshInstance3D.new()
    _lua.name = "Lua"
    _lua.mesh = esfera
    _lua.position = Vector3(-58.0, 42.0, -69.0)
    _lua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_lua)
