extends Node
## Estado persistente e unico do Akles.
## HUD, inventario, atributos, drops e sintese leem daqui; nenhum deles guarda
## uma copia particular dos mesmos numeros.

signal alterado
signal nivel_subiu(novo_nivel: int)
signal recurso_alterado(id: String, total: int)

const ARQUIVO := "user://progresso.cfg"
const ATRIBUTOS_INICIAIS := {
    "forca": 8,
    "destreza": 7,
    "vitalidade": 9,
    "ressonancia": 6,
    "percepcao": 6,
}
const RECURSOS_INICIAIS := {
    "claves": 0,
    "madeira": 0,
    "pedra": 0,
    "fragmento_do": 0,
    "fragmento_corrompido_do": 0,
    "fragmento_do_sustenido": 0,
    "fragmento_corrompido_do_sustenido": 0,
    "fragmento_re": 0,
    "fragmento_corrompido_re": 0,
    "fragmento_re_sustenido": 0,
    "fragmento_corrompido_re_sustenido": 0,
    "fragmento_mi": 0,
    "fragmento_corrompido_mi": 0,
    "fragmento_fa": 0,
    "fragmento_corrompido_fa": 0,
    "fragmento_fa_sustenido": 0,
    "fragmento_corrompido_fa_sustenido": 0,
    "fragmento_sol": 0,
    "fragmento_corrompido_sol": 0,
    "fragmento_sol_sustenido": 0,
    "fragmento_corrompido_sol_sustenido": 0,
    "fragmento_la": 0,
    "fragmento_corrompido_la": 0,
    "fragmento_la_sustenido": 0,
    "fragmento_corrompido_la_sustenido": 0,
    "fragmento_si": 0,
    "fragmento_corrompido_si": 0,
    "nota_do": 0,
    "nota_do_sustenido": 0,
    "nota_re": 0,
    "nota_re_sustenido": 0,
    "nota_mi": 0,
    "nota_fa": 0,
    "nota_fa_sustenido": 0,
    "nota_sol": 0,
    "nota_sol_sustenido": 0,
    "nota_la": 0,
    "nota_la_sustenido": 0,
    "nota_si": 0,
}

## Equipamentos nao mudam a aparencia. Sao seis acessorios de ressonancia.
const ACESSORIOS := {
    "amuleto_acorde": {
        "nome": "Amuleto do Primeiro Acorde", "arte": "equip/amuleto",
        "raridade": "Raro", "bonus": {"ressonancia": 2, "vitalidade": 1}},
    "anel_ouvido": {
        "nome": "Anel do Ouvido Atento", "arte": "equip/anel",
        "raridade": "Incomum", "bonus": {"percepcao": 2}},
}
const SLOTS_ACESSORIOS := ["Amuleto", "Anel I", "Anel II", "Broche", "Bracelete", "Talismã"]

var nivel := 1
var experiencia := 0
var pontos_de_atributo := 0
var atributos: Dictionary = ATRIBUTOS_INICIAIS.duplicate(true)
var recursos: Dictionary = RECURSOS_INICIAIS.duplicate(true)
var acessorios_equipados := {
    "Amuleto": "amuleto_acorde",
    "Anel I": "anel_ouvido",
}


func _ready() -> void:
    carregar()


func xp_para_nivel(qual: int = nivel) -> int:
    var n := maxi(qual - 1, 0)
    return 100 + n * 55 + n * n * 18


func ganhar_experiencia(quantidade: int) -> void:
    if quantidade <= 0:
        return
    experiencia += quantidade
    while experiencia >= xp_para_nivel():
        experiencia -= xp_para_nivel()
        nivel += 1
        pontos_de_atributo += 3
        nivel_subiu.emit(nivel)
    salvar()
    alterado.emit()


## Uma morte grava uma vez so. Salvar XP, eco e fragmento separadamente causaria
## exatamente o pequeno engasgo que o projeto ja sofreu na primeira recompensa.
func recompensar_batalha(xp: int, ganhos: Dictionary) -> void:
    experiencia += maxi(xp, 0)
    while experiencia >= xp_para_nivel():
        experiencia -= xp_para_nivel()
        nivel += 1
        pontos_de_atributo += 3
        nivel_subiu.emit(nivel)
    for id in ganhos:
        recursos[id] = maxi(0, int(recursos.get(id, 0)) + int(ganhos[id]))
        recurso_alterado.emit(str(id), int(recursos[id]))
    salvar()
    alterado.emit()


func investir_atributo(id: String) -> bool:
    if pontos_de_atributo <= 0 or not atributos.has(id):
        return false
    atributos[id] = int(atributos[id]) + 1
    pontos_de_atributo -= 1
    salvar()
    alterado.emit()
    return true


func quantidade(id: String) -> int:
    return int(recursos.get(id, 0))


func adicionar_recurso(id: String, quantidade: int) -> void:
    if quantidade == 0:
        return
    recursos[id] = maxi(0, int(recursos.get(id, 0)) + quantidade)
    salvar()
    recurso_alterado.emit(id, int(recursos[id]))
    alterado.emit()


func pode_pagar(custos: Dictionary) -> bool:
    for id in custos:
        if quantidade(str(id)) < int(custos[id]):
            return false
    return true


func pagar(custos: Dictionary) -> bool:
    if not pode_pagar(custos):
        return false
    for id in custos:
        recursos[id] = quantidade(str(id)) - int(custos[id])
        recurso_alterado.emit(str(id), int(recursos[id]))
    salvar()
    alterado.emit()
    return true


func sintetizar_nota(nota: String) -> bool:
    var fragmento := "fragmento_" + nota
    var custos := {fragmento: 5}
    if not pode_pagar(custos):
        return false
    for id in custos:
        recursos[id] = quantidade(str(id)) - int(custos[id])
        recurso_alterado.emit(str(id), int(recursos[id]))
    var pronta := "nota_" + nota
    recursos[pronta] = quantidade(pronta) + 1
    recurso_alterado.emit(pronta, int(recursos[pronta]))
    salvar()
    alterado.emit()
    return true


func purificar_fragmento(nota: String) -> bool:
    var corrompido := "fragmento_corrompido_" + nota
    if quantidade(corrompido) < 1:
        return false
    recursos[corrompido] = quantidade(corrompido) - 1
    recurso_alterado.emit(corrompido, int(recursos[corrompido]))
    var limpo := "fragmento_" + nota
    recursos[limpo] = quantidade(limpo) + 1
    recurso_alterado.emit(limpo, int(recursos[limpo]))
    salvar()
    alterado.emit()
    return true


func valor_atributo(id: String) -> int:
    var total := int(atributos.get(id, 0))
    for slot in acessorios_equipados:
        var acessorio: Dictionary = ACESSORIOS.get(str(acessorios_equipados[slot]), {})
        total += int((acessorio.get("bonus", {}) as Dictionary).get(id, 0))
    return total


func estatisticas() -> Dictionary:
    var forca := valor_atributo("forca")
    var destreza := valor_atributo("destreza")
    var vitalidade := valor_atributo("vitalidade")
    var ressonancia := valor_atributo("ressonancia")
    var percepcao := valor_atributo("percepcao")
    return {
        "ataque": 18 + nivel * 3 + forca * 4 + destreza,
        "vida_maxima": 160 + nivel * 14 + vitalidade * 22,
        "defesa": 4 + vitalidade * 2 + destreza,
        "critico": 3.0 + destreza * 0.55 + percepcao * 0.35,
        "dano_critico": 135.0 + forca * 1.5,
        "poder_harmonico": ressonancia * 5 + percepcao * 2 + nivel * 2,
        "coleta": 100.0 + percepcao * 2.0,
    }


func acessorio_no_slot(slot: String) -> Dictionary:
    var id := str(acessorios_equipados.get(slot, ""))
    var item: Dictionary = ACESSORIOS.get(id, {}).duplicate(true)
    if not item.is_empty():
        item["id"] = id
    return item


func salvar() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("personagem", "nivel", nivel)
    cfg.set_value("personagem", "experiencia", experiencia)
    cfg.set_value("personagem", "pontos", pontos_de_atributo)
    cfg.set_value("personagem", "atributos", atributos)
    cfg.set_value("inventario", "recursos", recursos)
    cfg.set_value("inventario", "acessorios", acessorios_equipados)
    cfg.save(ARQUIVO)


func carregar() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(ARQUIVO) != OK:
        return
    nivel = maxi(1, int(cfg.get_value("personagem", "nivel", nivel)))
    experiencia = maxi(0, int(cfg.get_value("personagem", "experiencia", experiencia)))
    pontos_de_atributo = maxi(0, int(cfg.get_value("personagem", "pontos", pontos_de_atributo)))
    var attrs = cfg.get_value("personagem", "atributos", {})
    if attrs is Dictionary:
        for id in ATRIBUTOS_INICIAIS:
            atributos[id] = int(attrs.get(id, ATRIBUTOS_INICIAIS[id]))
    var guardados = cfg.get_value("inventario", "recursos", {})
    if guardados is Dictionary:
        for id in RECURSOS_INICIAIS:
            recursos[id] = maxi(0, int(guardados.get(id, RECURSOS_INICIAIS[id])))
    var equipados = cfg.get_value("inventario", "acessorios", {})
    if equipados is Dictionary:
        acessorios_equipados = equipados.duplicate(true)
