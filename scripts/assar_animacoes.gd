extends Node
## Assa as animacoes do Mixamo numa biblioteca unica.
##
## RODAR ISTO DE NOVO exige copiar os FBX de volta para
## personagem/animacoes/ — eles vivem em "AcordeLot 2.0/mixamo/", FORA do
## projeto, porque cada um traz a malha inteira (16 MB) e a exportacao os
## empacotava mesmo excluidos: a build web ia a 170 MB e o GitHub recusava o
## envio. O jogo so precisa da biblioteca assada e de personagem/heroi_base.fbx.
##
## Cada FBX do Mixamo vem COM a malha inteira (16 MB por arquivo). Instanciar os
## sete no jogo carregaria sete copias do heroi na memoria e levaria 110 MB para
## a build web. Aqui fica so o movimento: a malha vem de um arquivo so.

const ANIMACOES := {
    "parado": "",
    "andar": "standard_walk",
    "correr": "running",
    "ataque": "sword_fight_one",
    "corte_dentro": "stable_sword_inward_slash",
    "corte_fora": "stable_sword_outward_slash",
    "ataque_pulo": "great_sword_jump_attack",
}

## Tira o avanco do quadril das animacoes de locomocao.
##
## Quem move o personagem no mundo e o codigo. Se a animacao TAMBEM andar, o
## corpo se afasta do proprio centro e volta de tranco a cada volta do laco. O
## sobe-e-desce (Y) fica: e ele que da peso ao passo.
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

func _ready() -> void:
    var biblioteca := AnimationLibrary.new()
    for nome in ANIMACOES:
        var arquivo: String = ANIMACOES[nome]
        var caminho := ("res://personagem/heroi_base.fbx" if arquivo.is_empty()
            else "res://personagem/animacoes/%s.fbx" % arquivo)
        var cena: PackedScene = load(caminho)
        var raiz := cena.instantiate()
        var tocador: AnimationPlayer = raiz.find_child("AnimationPlayer", true, false)
        var animacao: Animation = tocador.get_animation("mixamo_com").duplicate(true)
        # Parado, andar e correr tocam em laco; golpe toca uma vez e volta.
        animacao.loop_mode = (Animation.LOOP_LINEAR
            if nome in ["parado", "andar", "correr"] else Animation.LOOP_NONE)
        if nome in ["andar", "correr"]:
            _fixar_no_lugar(animacao)
        biblioteca.add_animation(nome, animacao)
        print("%-14s %5.2fs  %d trilhas" % [nome, animacao.length, animacao.get_track_count()])
        raiz.queue_free()

    var erro := ResourceSaver.save(biblioteca, "res://personagem/heroi_anims.res")
    print("biblioteca salva, erro=", erro)

    # Altura real do heroi: o Mixamo devolve em escala propria, e por essa
    # medida e que o modelo entra no mundo com o tamanho certo.
    var base := (load("res://personagem/heroi_base.fbx") as PackedScene).instantiate()
    add_child(base)
    await get_tree().process_frame
    var malha: MeshInstance3D = base.find_child("*", true, false) if false else null
    for node in base.find_children("*", "MeshInstance3D", true, false):
        malha = node
    var caixa := malha.get_aabb()
    print("altura da malha: ", caixa.size.y, "  caixa: ", caixa.size)
    get_tree().quit()
