extends Area3D
class_name ZonePortal

signal player_entered_portal(dest_zone_id: String, from_direction: String)

@export var dest_zone_id: String = ""
@export var direction: String = "north" # "north", "south", "east", "west"
@export var portal_label: String = "Portal"

var _mesh_ring: MeshInstance3D
var _label_3d: Label3D
var _light: OmniLight3D
var _active := true

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1 # detecta player
    
    # Cria a forma de colisão do portal
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(8.0, 5.0, 4.0)
    col.shape = shape
    col.position.y = 2.0
    add_child(col)
    
    # Conecta o sinal de corpo entrando
    body_entered.connect(_on_body_entered)
    
    _construir_visual()

func _construir_visual() -> void:
    # Portal mágico vertical estilo Albion
    var quad := QuadMesh.new()
    quad.size = Vector2(7.0, 6.0)
    
    _mesh_ring = MeshInstance3D.new()
    _mesh_ring.mesh = quad
    _mesh_ring.position = Vector3(0.0, 2.8, 0.0)
    
    var mat := ShaderMaterial.new()
    mat.shader = load("res://materials/zone_portal.gdshader")
    _mesh_ring.material_override = mat
    add_child(_mesh_ring)
    
    # Luz mágica ambiente
    _light = OmniLight3D.new()
    _light.light_color = Color(0.25, 0.75, 1.0)
    _light.light_energy = 2.2
    _light.omni_range = 9.0
    _light.position = Vector3(0.0, 2.5, 0.0)
    add_child(_light)
    
    # Placa 3D de destino flutuante
    _label_3d = Label3D.new()
    _label_3d.text = portal_label
    _label_3d.font_size = 28
    _label_3d.outline_size = 8
    _label_3d.modulate = Color(1.0, 0.95, 0.8)
    _label_3d.outline_modulate = Color(0.05, 0.1, 0.2, 0.9)
    _label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label_3d.position = Vector3(0.0, 6.2, 0.0)
    add_child(_label_3d)
    
    # Postes/Pedras laterais de marcação do portal
    _criar_postes_laterais()

func _criar_postes_laterais() -> void:
    var pillar_mat := StandardMaterial3D.new()
    pillar_mat.albedo_color = Color(0.35, 0.38, 0.42)
    pillar_mat.roughness = 0.9
    
    for side in [-3.8, 3.8]:
        var pillar := MeshInstance3D.new()
        var cyl := CylinderMesh.new()
        cyl.top_radius = 0.5
        cyl.bottom_radius = 0.65
        cyl.height = 4.5
        pillar.mesh = cyl
        pillar.material_override = pillar_mat
        pillar.position = Vector3(side, 2.25, 0.0)
        add_child(pillar)

func _process(delta: float) -> void:
    if _mesh_ring:
        # Leve pulso vertical
        _mesh_ring.position.y = 2.8 + sin(Time.get_ticks_msec() * 0.003) * 0.15

func _on_body_entered(body: Node3D) -> void:
    if not _active:
        return
    if body.is_in_group("player") or body.name == "Player":
        _active = false
        player_entered_portal.emit(dest_zone_id, direction)

func desativar_temporario(tempo: float = 2.0) -> void:
    _active = false
    await get_tree().create_timer(tempo).timeout
    _active = true
