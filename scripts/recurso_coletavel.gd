extends Node3D
## Recurso leve do mundo. Nao tem fisica nem Area3D: uma verificacao curta de
## distancia basta e evita dezenas de corpos ativos no navegador.

@export var recurso_id := "madeira"
@export var quantidade := 1
@export var respawn_segundos := 45.0

const RAIO := 1.35
var _jogador: Node3D
var _ativo := true
var _proxima_verificacao := 0.0


func _ready() -> void:
    add_to_group("recurso_coletavel")
    _montar_visual()


func _process(delta: float) -> void:
    if not _ativo:
        return
    _proxima_verificacao -= delta
    if _proxima_verificacao > 0.0:
        return
    _proxima_verificacao = 0.12
    if _jogador == null or not is_instance_valid(_jogador):
        _jogador = get_tree().get_first_node_in_group("player") as Node3D
    if _jogador and global_position.distance_to(_jogador.global_position) <= RAIO:
        _coletar()


func _montar_visual() -> void:
    var malha := MeshInstance3D.new()
    malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat := StandardMaterial3D.new()
    mat.roughness = 0.9
    match recurso_id:
        "madeira":
            var tronco := CylinderMesh.new()
            tronco.top_radius = 0.22
            tronco.bottom_radius = 0.26
            tronco.height = 1.25
            malha.mesh = tronco
            malha.rotation.z = PI * 0.5
            malha.position.y = 0.30
            mat.albedo_color = Color(0.30, 0.16, 0.07)
        "pedra":
            var rocha := SphereMesh.new()
            rocha.radius = 0.48
            rocha.height = 0.65
            malha.mesh = rocha
            malha.position.y = 0.30
            malha.scale = Vector3(1.15, 0.75, 0.9)
            mat.albedo_color = Color(0.36, 0.38, 0.42)
        _:
            var frag := QuadMesh.new()
            frag.size = Vector2(0.7, 0.9)
            malha.mesh = frag
            malha.position.y = 0.8
            mat.albedo_texture = load("res://textures/ui/kit/item/nota.png")
            mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
            mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            mat.albedo_color = Color(0.88, 0.66, 1.0)
    malha.material_override = mat
    add_child(malha)


func _coletar() -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    progresso.adicionar_recurso(recurso_id, quantidade)
    _ativo = false
    visible = false
    var tempo := get_tree().create_timer(respawn_segundos)
    tempo.timeout.connect(func():
        if is_instance_valid(self):
            _ativo = true
            visible = true)
