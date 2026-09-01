extends Node
## O DIÁRIO DE ACORDELOT: três tarefas por dia, e um motivo para voltar amanhã.
##
## Não é um sistema de missões completo, e não deve virar um. É a FUNDAÇÃO: um
## catálogo de formas de tarefa, um sorteio por dia e um único ponto de entrada
## (`registrar`) que o resto do jogo chama quando algo acontece. Uma missão nova
## é uma linha no catálogo — não um script, uma cena e um gerenciador.
##
## NADA AQUI INVENTA VERBO NOVO. Toda tarefa se cumpre fazendo algo que o jogo já
## sabe fazer: cortar madeira, derrubar Shiker, ressoar um Eco, sintetizar nota,
## purificar fragmento, atravessar uma região, descer na DG. Missão que pede o
## que o jogo não tem é missão que não fecha.
##
## O ESTÁGIO DA HISTÓRIA MANDA NO SORTEIO. Cada forma pode exigir marcos já
## vividos e proibir marcos que já passaram. É o que impede o diário de pedir,
## alegremente, um favor a alguém que a história acabou de tirar de cena.

signal alterado
signal missao_concluida(missao: Dictionary)
signal dia_completo

const ARQUIVO := "user://diario.cfg"
const QUANTAS_POR_DIA := 3

## A recompensa de cada tarefa e a do dia fechado. Pequenas de propósito: o
## diário é um empurrão para sair andando, não uma fonte de progressão que torne
## o resto do jogo dispensável.
const CLAVES_POR_MISSAO := 45
const CLAVES_DO_DIA := 120

## As formas de tarefa.
##
## `tipo` + `alvo` é o que `registrar` compara. `base` e `por_nivel` dão a
## quantidade: quatro toras no nível 1 e nove no nível 12, sem tabela por nível.
## `exige` e `proibe` são marcos da história — vazios querem dizer "sempre".
const CATALOGO := [
    # ---------------------------------------------------- Ferreiro Dorn
    {"id": "dorn_lenha", "dono": "Ferreiro Dorn", "tipo": "coletar", "alvo": "madeira",
     "titulo": "Lenha para a forja", "base": 4, "por_nivel": 0.35,
     "texto": "Dorn não deixa a forja esfriar. Traga %d de madeira.",
     "exige": [], "proibe": []},
    {"id": "dorn_pedra", "dono": "Ferreiro Dorn", "tipo": "coletar", "alvo": "pedra",
     "titulo": "Pedra para o revestimento", "base": 3, "por_nivel": 0.30,
     "texto": "A parede da forja pede reparo. Traga %d de pedra.",
     "exige": [], "proibe": []},

    # ------------------------------------------------------- Sr. Antony
    {"id": "antony_patrulha", "dono": "Sr. Antony", "tipo": "derrotar", "alvo": "shiker",
     "titulo": "Patrulha nos arredores", "base": 3, "por_nivel": 0.45,
     "texto": "O cerco anda solto. Derrote %d Shikers perto de Acordelot.",
     "exige": [], "proibe": []},
    {"id": "antony_claves", "dono": "Sr. Antony", "tipo": "coletar", "alvo": "claves",
     "titulo": "O peso das Claves", "base": 60, "por_nivel": 14.0,
     "texto": "Recolha %d Claves do que restou dos Ecos corrompidos.",
     "exige": [], "proibe": []},
    {"id": "antony_ronda", "dono": "Sr. Antony", "tipo": "visitar", "alvo": "",
     "titulo": "Ronda pelas terras", "base": 2, "por_nivel": 0.0,
     "texto": "Passe por %d regiões diferentes do reino.",
     "exige": [], "proibe": []},

    # ----------------------------------------------------- Bardo Lucian
    {"id": "lucian_ecos", "dono": "Bardo Lucian", "tipo": "capturar_eco", "alvo": "",
     "titulo": "Escutar o que ficou", "base": 2, "por_nivel": 0.18,
     "texto": "Lucian quer ouvir de novo. Ressoe com %d Ecos.",
     "exige": [], "proibe": []},
    {"id": "lucian_condensar", "dono": "Bardo Lucian", "tipo": "sintetizar", "alvo": "",
     "titulo": "Condensar uma nota", "base": 1, "por_nivel": 0.08,
     "texto": "Leve %d nota condensada à Síntese.",
     "exige": [], "proibe": []},

    # ------------------------------------------------------------- Ecos
    {"id": "eco_purificar", "dono": "Os Ecos", "tipo": "purificar", "alvo": "",
     "titulo": "Fragmento puro", "base": 2, "por_nivel": 0.15,
     "texto": "Purifique %d fragmentos corrompidos.",
     "exige": [], "proibe": []},
    {"id": "eco_fragmentos", "dono": "Os Ecos", "tipo": "coletar", "alvo": "fragmento_do",
     "titulo": "Ressonância de Dó", "base": 4, "por_nivel": 0.30,
     "texto": "Reúna %d fragmentos de Dó.",
     "exige": [], "proibe": []},

    # ------------------------------------------------------- exploração
    {"id": "explorar_floresta", "dono": "Exploração", "tipo": "visitar", "alvo": "",
     "titulo": "Terras adiante", "base": 3, "por_nivel": 0.0,
     "texto": "Atravesse %d regiões sem voltar pelo mesmo caminho.",
     "exige": [], "proibe": []},

    # ---------------------------------------------------------- combate
    {"id": "combate_shikers", "dono": "Combate", "tipo": "derrotar", "alvo": "shiker",
     "titulo": "Silenciar a dissonância", "base": 6, "por_nivel": 0.7,
     "texto": "Derrote %d Shikers onde eles estiverem.",
     "exige": [], "proibe": []},
    {"id": "combate_golem", "dono": "Combate", "tipo": "derrotar", "alvo": "golem",
     "titulo": "A guarda de pedra", "base": 2, "por_nivel": 0.20,
     "texto": "Derrote %d Golems na caverna.",
     "exige": [], "proibe": []},
    {"id": "combate_dg", "dono": "Combate", "tipo": "dungeon", "alvo": "",
     "titulo": "Descer na Caverna", "base": 1, "por_nivel": 0.0,
     "texto": "Conclua %d incursão na DG da Caverna.",
     "exige": [], "proibe": []},
]

## O que já aconteceu na história, do ponto de vista do diário.
##
## Exemplo de uso, para quando o roteiro chegar lá: uma tarefa alegre com Pipo
## leva `"exige": ["pipo_em_acordelot"]` e `"proibe": ["pipo_apagado"]`. Marcar
## `pipo_apagado` em Progresso tira essa tarefa do sorteio no mesmo instante,
## sem ninguém precisar lembrar de editar o catálogo naquele dia.

var missoes: Array = []
var dia_gravado := ""
var recompensa_do_dia_paga := false

var _progresso: Node = null
var _zonas_visitadas: Array = []


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _carregar()
    _conferir_o_dia()
    # As tarefas de COLETAR e de SINTETIZAR nao precisam de gancho espalhado
    # pelo jogo: Progresso ja e por onde todo recurso entra. Basta escutar.
    if _progresso:
        _progresso.recurso_ganho.connect(func(id: String, quanto: int):
            registrar("coletar", quanto, id))
        _progresso.nota_sintetizada.connect(func(_nota: String):
            registrar("sintetizar", 1, ""))
        _progresso.fragmento_purificado.connect(func(_nota: String):
            registrar("purificar", 1, ""))


# ------------------------------------------------------------------ o dia

## O dia é o do calendário do aparelho, não um contador de sessões: quem jogou
## ontem à noite e volta hoje de manhã tem tarefas novas, que é o que "diária"
## quer dizer para quem joga.
func _hoje() -> String:
    var d := Time.get_date_dict_from_system()
    return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


func _conferir_o_dia() -> void:
    var hoje := _hoje()
    if dia_gravado == hoje and not missoes.is_empty():
        return
    dia_gravado = hoje
    recompensa_do_dia_paga = false
    _zonas_visitadas.clear()
    _sortear()
    _gravar()
    alterado.emit()


func _sortear() -> void:
    var nivel: int = int(_progresso.nivel) if _progresso else 1
    var elegiveis: Array = []
    for forma in CATALOGO:
        if _permitida(forma):
            elegiveis.append(forma)

    # A semente é o dia: quem fecha e reabre o jogo encontra as MESMAS três
    # tarefas. Sorteio a cada abertura seria um botão de rerrolar disfarçado.
    var sorte := RandomNumberGenerator.new()
    sorte.seed = hash(dia_gravado)
    # Uma por "dono" enquanto der: três pedidos do Dorn no mesmo dia fazem o
    # diário parecer uma lista de compras, não o reino pedindo ajuda.
    var por_dono: Dictionary = {}
    for forma in elegiveis:
        var dono := str(forma["dono"])
        if not por_dono.has(dono):
            por_dono[dono] = []
        por_dono[dono].append(forma)

    var donos: Array = por_dono.keys()
    donos.sort()
    _embaralhar(donos, sorte)

    var escolhidas: Array = []
    for dono in donos:
        if escolhidas.size() >= QUANTAS_POR_DIA:
            break
        var lista: Array = por_dono[dono]
        escolhidas.append(lista[sorte.randi() % lista.size()])
    # Se houver menos donos que vagas, completa com o que sobrou.
    if escolhidas.size() < QUANTAS_POR_DIA:
        var resto: Array = []
        for forma in elegiveis:
            if forma not in escolhidas:
                resto.append(forma)
        _embaralhar(resto, sorte)
        for forma in resto:
            if escolhidas.size() >= QUANTAS_POR_DIA:
                break
            escolhidas.append(forma)

    missoes.clear()
    for forma in escolhidas:
        var quanto: int = maxi(1, int(round(
            float(forma["base"]) + float(forma["por_nivel"]) * float(nivel - 1))))
        missoes.append({
            "id": str(forma["id"]),
            "dono": str(forma["dono"]),
            "titulo": str(forma["titulo"]),
            "texto": str(forma["texto"]) % quanto,
            "tipo": str(forma["tipo"]),
            "alvo": str(forma["alvo"]),
            "meta": quanto,
            "feito": 0,
            "paga": false,
        })


func _embaralhar(lista: Array, sorte: RandomNumberGenerator) -> void:
    for i in range(lista.size() - 1, 0, -1):
        var j: int = sorte.randi() % (i + 1)
        var guarda = lista[i]
        lista[i] = lista[j]
        lista[j] = guarda


func _permitida(forma: Dictionary) -> bool:
    if _progresso == null or not _progresso.has_method("tem_marco"):
        return (forma.get("exige", []) as Array).is_empty()
    for marco in forma.get("exige", []):
        if not _progresso.tem_marco(str(marco)):
            return false
    for marco in forma.get("proibe", []):
        if _progresso.tem_marco(str(marco)):
            return false
    return true


# --------------------------------------------------------------- progresso

## O ÚNICO ponto de entrada. Quem cumpre a tarefa não sabe que o diário existe:
## chama isto com o que acabou de acontecer e segue a vida.
##
## `alvo` vazio no catálogo quer dizer "qualquer um" — a tarefa do Lucian conta
## qualquer Eco, e a do Dorn só conta madeira.
func registrar(tipo: String, quantidade: int = 1, alvo: String = "") -> void:
    if quantidade <= 0 or missoes.is_empty():
        return
    _conferir_o_dia()
    var mudou := false
    for missao in missoes:
        if missao["feito"] >= missao["meta"]:
            continue
        if str(missao["tipo"]) != tipo:
            continue
        var esperado := str(missao["alvo"])
        if esperado != "" and esperado != alvo:
            continue
        missao["feito"] = mini(int(missao["meta"]), int(missao["feito"]) + quantidade)
        mudou = true
        if int(missao["feito"]) >= int(missao["meta"]) and not bool(missao["paga"]):
            missao["paga"] = true
            if _progresso:
                _progresso.adicionar_recurso("claves", CLAVES_POR_MISSAO)
            missao_concluida.emit(missao)
    if not mudou:
        return
    if concluidas() >= missoes.size() and not recompensa_do_dia_paga:
        recompensa_do_dia_paga = true
        if _progresso:
            _progresso.adicionar_recurso("claves", CLAVES_DO_DIA)
            _progresso.adicionar_recurso("partitura_menor", 1)
        dia_completo.emit()
    _gravar()
    alterado.emit()


## Região visitada. Fica aqui, e não em quem chama, porque a regra é do diário:
## voltar para a mesma região não conta duas vezes.
func registrar_visita(zone_id: String) -> void:
    if zone_id == "" or zone_id in _zonas_visitadas:
        return
    _zonas_visitadas.append(zone_id)
    registrar("visitar", 1, "")


func concluidas() -> int:
    var conta := 0
    for missao in missoes:
        if int(missao["feito"]) >= int(missao["meta"]):
            conta += 1
    return conta


func rotulo_do_contador() -> String:
    return "%d/%d" % [concluidas(), missoes.size()]


## Onde procurar, quando a tarefa tem lugar no mundo. O minimapa usa isto para
## acender o anel do objetivo; devolve null quando a tarefa é "faça em qualquer
## lugar", que é a maioria delas.
func alvo_no_mundo() -> Variant:
    for missao in missoes:
        if int(missao["feito"]) >= int(missao["meta"]):
            continue
        if str(missao["tipo"]) != "visitar":
            continue
        var gerente := get_tree().root.find_child("ZoneManager", true, false)
        if gerente == null or gerente.zone_builder == null:
            return null
        var construtor = gerente.zone_builder
        for zid in construtor._celulas.keys():
            if str(zid) in _zonas_visitadas:
                continue
            return construtor.deslocamento_da_celula(construtor._celulas[zid])
    return null


# ------------------------------------------------------------------ disco

func _gravar() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("diario", "dia", dia_gravado)
    cfg.set_value("diario", "missoes", missoes)
    cfg.set_value("diario", "recompensa_paga", recompensa_do_dia_paga)
    cfg.set_value("diario", "zonas", _zonas_visitadas)
    cfg.save(ARQUIVO)


func _carregar() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(ARQUIVO) != OK:
        return
    dia_gravado = str(cfg.get_value("diario", "dia", ""))
    var guardadas = cfg.get_value("diario", "missoes", [])
    # Só aceita o que ainda tem a forma esperada: um save de uma versão anterior
    # do catálogo não pode derrubar o jogo na abertura.
    if guardadas is Array:
        for item in guardadas:
            if item is Dictionary and item.has("id") and item.has("meta") and item.has("feito"):
                missoes.append(item)
    recompensa_do_dia_paga = bool(cfg.get_value("diario", "recompensa_paga", false))
    var zonas = cfg.get_value("diario", "zonas", [])
    if zonas is Array:
        _zonas_visitadas = zonas.duplicate()
