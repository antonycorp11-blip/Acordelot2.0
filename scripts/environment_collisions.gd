extends Node3D
## Da colisao aos modelos postos a mao na cena (a floresta do prototipo).
## O mundo contínuo usa o mesmo colisor por PropCollider, direto no streamer.

func _ready() -> void:
    for asset in get_children():
        PropCollider.apply_to_asset(asset)
