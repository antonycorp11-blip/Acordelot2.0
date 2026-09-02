extends Node3D
class_name ProjetilCavaleiro

## O corte viaja de verdade: e uma instancia independente, com alcance e
## colisao por distancia. Nao e dano instantaneo escondido dentro de um efeito.
const BRILHO := preload("res://textures/brilho_poste.png")
const VELOCIDADE := 13.0
const DURACAO := 2.4

var _direcao := Vector3.FORWARD
var _dano := 20.0
var _dono: Node
var _alvo: Node3D
var _idade := 0.0
var _acertou := false

func configurar(direcao: Vector3, dano: float, dono: Node, alvo: Node3D,
        segunda_forma := false) -> void:
    _direcao = Vector3(direcao.x, 0.0, direcao.z).normalized()
    _dano = dano
    _dono = dono
    _alvo = alvo
    rotation.y = atan2(_direcao.x, _direcao.z)
    _montar(segunda_forma)

func _montar(segunda_forma: bool) -> void:
    var lamina := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(3.8 if segunda_forma else 3.0, 1.0)
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = BRILHO
    mat.albedo_color = Color(0.48, 0.76, 1.0, 0.92) if not segunda_forma \
        else Color(0.76, 0.42, 1.0, 0.96)
    mat.emission_enabled = true
    mat.emission = mat.albedo_color
    mat.emission_energy_multiplier = 2.8
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    quad.material = mat
    lamina.mesh = quad
    lamina.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(lamina)

    var luz := OmniLight3D.new()
    luz.light_color = mat.albedo_color
    luz.light_energy = 1.0
    luz.omni_range = 4.5
    luz.shadow_enabled = false
    add_child(luz)

func _physics_process(delta: float) -> void:
    _idade += delta
    global_position += _direcao * VELOCIDADE * delta
    if not _acertou and is_instance_valid(_alvo):
        var distancia := global_position.distance_to(_alvo.global_position + Vector3.UP)
        if distancia < 1.55:
            _acertou = true
            if is_instance_valid(_dono) and _dono.has_method("_bater_no_heroi"):
                _dono.call("_bater_no_heroi", _dano)
            queue_free()
            return
    if _idade >= DURACAO:
        queue_free()
