@tool
extends SceneTree

const ANIMACOES := {
    "andar": "res://personagem/novo_monstro/Walking.fbx",
    "ataque_1": "res://personagem/novo_monstro/Fist Fight A.fbx",
    "ataque_2": "res://personagem/novo_monstro/Stable Sword Inward Slash.fbx",
    "morte": "res://personagem/novo_monstro/Dying.fbx",
}

func _fixar_no_lugar(animacao: Animation) -> void:
    for trilha in animacao.get_track_count():
        if animacao.track_get_type(trilha) != Animation.TYPE_POSITION_3D:
            continue
        var alvo := String(animacao.track_get_path(trilha))
        if not alvo.ends_with("Hips"):
            continue
        for chave in animacao.track_get_key_count(trilha):
            var valor: Vector3 = animacao.track_get_key_value(trilha, chave)
            animacao.track_set_key_value(trilha, chave, Vector3(0.0, valor.y, 0.0))

func _init() -> void:
    var biblioteca := AnimationLibrary.new()
    
    for nome in ANIMACOES:
        var caminho: String = ANIMACOES[nome]
        var cena: PackedScene = load(caminho)
        if cena == null:
            print("ERRO ao carregar ", caminho)
            continue
        var raiz := cena.instantiate()
        var tocador: AnimationPlayer = raiz.find_child("AnimationPlayer", true, false)
        if tocador == null or not tocador.has_animation("mixamo_com"):
            print("ERRO: animation player nao tem mixamo_com em ", caminho)
            continue
            
        var animacao: Animation = tocador.get_animation("mixamo_com").duplicate(true)
        animacao.loop_mode = Animation.LOOP_LINEAR if nome in ["andar", "parado"] else Animation.LOOP_NONE
        
        if nome == "andar":
            _fixar_no_lugar(animacao)
            var parado_anim := animacao.duplicate(true)
            parado_anim.loop_mode = Animation.LOOP_LINEAR
            for trilha in parado_anim.get_track_count():
                var t_type: Animation.TrackType = parado_anim.track_get_type(trilha)
                if t_type == Animation.TYPE_ROTATION_3D or t_type == Animation.TYPE_POSITION_3D:
                    var count: int = parado_anim.track_get_key_count(trilha)
                    if count > 0:
                        var k0 = parado_anim.track_get_key_value(trilha, 0)
                        for k in range(count):
                            var val = parado_anim.track_get_key_value(trilha, k)
                            if val is Quaternion:
                                parado_anim.track_set_key_value(trilha, k, (k0 as Quaternion).slerp(val as Quaternion, 0.15))
                            elif val is Vector3:
                                parado_anim.track_set_key_value(trilha, k, (k0 as Vector3).lerp(val as Vector3, 0.15))
            biblioteca.add_animation("parado", parado_anim)
            print("%-14s %5.2fs  %d trilhas (gerado para idle)" % ["parado", parado_anim.length, parado_anim.get_track_count()])

        biblioteca.add_animation(nome, animacao)
        print("%-14s %5.2fs  %d trilhas" % [nome, animacao.length, animacao.get_track_count()])
        raiz.queue_free()

    var erro: Error = ResourceSaver.save(biblioteca, "res://personagem/golem_anims.res")
    print("Biblioteca res://personagem/golem_anims.res salva com sucesso! Erro=", erro)
    quit(0)
