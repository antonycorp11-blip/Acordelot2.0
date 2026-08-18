class_name PropCollider
extends RefCounted
## Colisor automatico para modelo vindo do TripoSR.
##
## Os GLB gerados nao trazem colisao, e um por um a mao nao escala para um mundo
## contínuo. A caixa sai da AABB da malha: tronco (alto e fino) ganha uma caixa
## estreita, para o jogador passar rente a arvore sem esbarrar na copa.

static func apply_to_asset(asset: Node3D) -> void:
    for mesh_node in asset.find_children("*", "MeshInstance3D", true, false):
        apply_to_mesh(mesh_node)

static func apply_to_mesh(mesh_node: MeshInstance3D) -> void:
    if mesh_node.mesh == null:
        return

    var bounds := mesh_node.get_aabb()
    var body := StaticBody3D.new()
    body.name = "GeneratedStaticBody"
    body.collision_layer = 1
    body.collision_mask = 1
    mesh_node.add_child(body)

    var collision := CollisionShape3D.new()
    collision.name = "GeneratedCollision"
    collision.position = bounds.get_center()
    body.add_child(collision)

    var horizontal_size := maxf(bounds.size.x, bounds.size.z)
    var shape := BoxShape3D.new()
    if bounds.size.y >= horizontal_size * 0.70:
        shape.size = Vector3(bounds.size.x * 0.28, bounds.size.y * 0.90, bounds.size.z * 0.28)
    else:
        shape.size = Vector3(bounds.size.x * 0.90, bounds.size.y * 0.90, bounds.size.z * 0.90)
    collision.shape = shape
