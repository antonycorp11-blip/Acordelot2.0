extends Node
## Estado persistente e unico do Akles.
## HUD, inventario, atributos, drops e sintese leem daqui; nenhum deles guarda
## uma copia particular dos mesmos numeros.

signal alterado
signal nivel_subiu(novo_nivel: int)
signal recurso_alterado(id: String, total: int)
## GANHO, nao total: quem escuta quer saber quanto ENTROU agora. O diario conta
## "traga 4 madeiras" somando entradas, e com o total ele nunca saberia se as
## quatro chegaram hoje ou ja estavam na bolsa.
signal recurso_ganho(id: String, quantidade: int)
signal nota_sintetizada(nota: String)
signal fragmento_purificado(nota: String)

const ARQUIVO := "user://progresso.cfg"
const NIVEL_MAXIMO := 60
const TRAVAS_DE_ASCENSAO := [20, 40]
const NIVEL_MAXIMO_SKILL := 10
const NIVEIS_DESBLOQUEIO_SKILLS := {
    "ataque_basico": 1, "skill_1": 2, "skill_2": 4, "skill_3": 6,
}
const CUSTO_PURIFICAR_FRAGMENTO := 25
const CUSTO_SINTETIZAR_NOTA := 100
const PARTITURAS := {
    "menor": {"nome": "Partitura Menor", "custo": 500, "xp": 100, "recurso": "partitura_menor"},
    "harmonica": {"nome": "Partitura Harmônica", "custo": 2000, "xp": 500, "recurso": "partitura_harmonica"},
    "magistral": {"nome": "Partitura Magistral", "custo": 5000, "xp": 1500, "recurso": "partitura_magistral"},
}
const REQUISITOS_ASCENSAO := {
    20: {"partitura_harmonica": 3, "selo_regente": 1},
    40: {"partitura_magistral": 5, "nucleo_maestro": 1},
}
const ATRIBUTOS_INICIAIS := {
    "forca": 8,
    "destreza": 7,
    "vitalidade": 9,
    "ressonancia": 6,
    "percepcao": 6,
}
const RECURSOS_INICIAIS := {
    "claves": 0,
    # Ferramenta durável de teste. Mais adiante ela será forjada na ferraria.
    "ressonador": 1,
    "madeira": 0,
    "pedra": 0,
    "partitura_menor": 0,
    "partitura_harmonica": 0,
    "partitura_magistral": 0,
    "selo_regente": 0,
    "nucleo_maestro": 0,
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
    "alma_eco_do": 0,
    "alma_eco_do_sustenido": 0,
    "alma_eco_re": 0,
    "alma_eco_re_sustenido": 0,
    "alma_eco_mi": 0,
    "alma_eco_fa": 0,
    "alma_eco_fa_sustenido": 0,
    "alma_eco_sol": 0,
    "alma_eco_sol_sustenido": 0,
    "alma_eco_la": 0,
    "alma_eco_la_sustenido": 0,
    "alma_eco_si": 0,
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
## Fontes reais do Poder de Luta. Ainda nao existem armaduras: o equipamento
## visivel e a arma; o restante sao acessorios, Eco e composicao harmonica.
var arma_equipada := "Espada do Despertar"
var nivel_da_arma := 1
var niveis_skills := {"ataque_basico": 1, "skill_1": 1, "skill_2": 1, "skill_3": 1}
var eco_equipado: Dictionary = {}
## Novos saves começam com Dó para validar a quarta skill. Saves de teste que
## já tinham os demais liberados são preservados; captura não apaga progresso.
var ecos_descobertos: Array = ["do"]
var acordes_equipados: Array = []
## Quando novos personagens jogaveis entrarem, cada ficha registra aqui seu
## Poder de Luta consolidado. Hoje a conta tem apenas Akles.
var poder_outros_personagens: Dictionary = {}
var ascensoes := {20: false, 40: false}
## OS MARCOS DA HISTORIA que ja foram vividos.
##
## Um dicionario de bandeiras, e nao um numero de capitulo, porque a historia nao
## e uma fila: um jogador pode ter conhecido o Lucian sem ter descido na caverna.
## Quem consulta hoje e o diario, para nao sortear uma tarefa alegre com alguem
## que a historia acabou de tirar de cena.
var marcos: Dictionary = {}


func marcar_historia(id: String, aconteceu := true) -> void:
    if bool(marcos.get(id, false)) == aconteceu:
        return
    marcos[id] = aconteceu
    salvar()
    alterado.emit()


func tem_marco(id: String) -> bool:
    return bool(marcos.get(id, false))


func _ready() -> void:
    carregar()


func xp_para_nivel(qual: int = nivel) -> int:
    var n := maxi(qual - 1, 0)
    return 100 + n * 55 + n * n * 18


func ganhar_experiencia(quantidade: int) -> void:
    if quantidade <= 0 or nivel >= NIVEL_MAXIMO:
        return
    experiencia += quantidade
    salvar()
    alterado.emit()


func pode_subir_nivel() -> bool:
    return nivel < NIVEL_MAXIMO and not esta_em_trava_de_ascensao() and experiencia >= xp_para_nivel()


func subir_nivel() -> bool:
    if not pode_subir_nivel():
        return false
    experiencia -= xp_para_nivel()
    nivel += 1
    pontos_de_atributo += 3
    nivel_subiu.emit(nivel)
    if nivel >= NIVEL_MAXIMO:
        nivel = NIVEL_MAXIMO
        experiencia = 0
    salvar()
    alterado.emit()
    return true


## Batalha nao concede mais XP direto. Shikers deixam Claves; o jogador decide
## quando transforma-las em Partituras e quando usa essas Partituras.
func recompensar_batalha(_xp: int, ganhos: Dictionary) -> void:
    for id in ganhos:
        recursos[id] = maxi(0, int(recursos.get(id, 0)) + int(ganhos[id]))
        recurso_alterado.emit(str(id), int(recursos[id]))
        if int(ganhos[id]) > 0:
            recurso_ganho.emit(str(id), int(ganhos[id]))
    salvar()
    alterado.emit()


func criar_partitura(tipo: String) -> bool:
    var receita: Dictionary = PARTITURAS.get(tipo, {})
    if receita.is_empty():
        return false
    var custo := int(receita.get("custo", 0))
    if quantidade("claves") < custo:
        return false
    recursos["claves"] = quantidade("claves") - custo
    var recurso := str(receita.get("recurso", ""))
    recursos[recurso] = quantidade(recurso) + 1
    recurso_alterado.emit("claves", int(recursos["claves"]))
    recurso_alterado.emit(recurso, int(recursos[recurso]))
    salvar()
    alterado.emit()
    return true


func usar_partitura(tipo: String) -> bool:
    var receita: Dictionary = PARTITURAS.get(tipo, {})
    if receita.is_empty() or nivel >= NIVEL_MAXIMO:
        return false
    var recurso := str(receita.get("recurso", ""))
    if quantidade(recurso) <= 0:
        return false
    recursos[recurso] = quantidade(recurso) - 1
    recurso_alterado.emit(recurso, int(recursos[recurso]))
    experiencia += int(receita.get("xp", 0))
    salvar()
    alterado.emit()
    return true


func esta_em_trava_de_ascensao() -> bool:
    return nivel in TRAVAS_DE_ASCENSAO and not bool(ascensoes.get(nivel, false))


func requisitos_da_ascensao() -> Dictionary:
    return (REQUISITOS_ASCENSAO.get(nivel, {}) as Dictionary).duplicate(true)


func tentar_ascensao() -> bool:
    if not esta_em_trava_de_ascensao():
        return false
    var custos := requisitos_da_ascensao()
    if not pode_pagar(custos):
        return false
    for id in custos:
        recursos[id] = quantidade(str(id)) - int(custos[id])
        recurso_alterado.emit(str(id), int(recursos[id]))
    ascensoes[nivel] = true
    salvar()
    alterado.emit()
    return true


func investir_atributo(id: String) -> bool:
    if pontos_de_atributo <= 0 or not atributos.has(id):
        return false
    atributos[id] = int(atributos[id]) + 1
    pontos_de_atributo -= 1
    salvar()
    alterado.emit()
    return true


func equipar_eco(dados: Dictionary) -> bool:
    var id := str(dados.get("id", ""))
    if id.is_empty() or id not in ecos_descobertos:
        return false
    eco_equipado = {
        "id": id, "nome": str(dados.get("nome", id.capitalize())),
        "forma": 1, "poder": int(dados.get("poder", 0)),
        "arte": str(dados.get("arte", "")),
        "habilidade": str(dados.get("habilidade", "")),
        "buff": str(dados.get("buff", "")),
    }
    salvar()
    alterado.emit()
    return true


func pontos_de_skill_disponiveis() -> int:
    var investidos := 0
    for valor in niveis_skills.values():
        investidos += maxi(0, int(valor) - 1)
    return maxi(0, nivel - 1 - investidos)


func skill_desbloqueada(id: String) -> bool:
    return nivel >= int(NIVEIS_DESBLOQUEIO_SKILLS.get(id, 1))


func subir_skill(id: String) -> bool:
    if not niveis_skills.has(id) or not skill_desbloqueada(id):
        return false
    if int(niveis_skills[id]) >= NIVEL_MAXIMO_SKILL or pontos_de_skill_disponiveis() <= 0:
        return false
    niveis_skills[id] = int(niveis_skills[id]) + 1
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
    if quantidade > 0:
        recurso_ganho.emit(id, quantidade)
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
    var custos := {fragmento: 5, "claves": CUSTO_SINTETIZAR_NOTA}
    if not pode_pagar(custos):
        return false
    for id in custos:
        recursos[id] = quantidade(str(id)) - int(custos[id])
        recurso_alterado.emit(str(id), int(recursos[id]))
    var pronta := "nota_" + nota
    recursos[pronta] = quantidade(pronta) + 1
    recurso_alterado.emit(pronta, int(recursos[pronta]))
    salvar()
    nota_sintetizada.emit(nota)
    alterado.emit()
    return true


func purificar_fragmento(nota: String) -> bool:
    var corrompido := "fragmento_corrompido_" + nota
    if quantidade(corrompido) < 1 or quantidade("claves") < CUSTO_PURIFICAR_FRAGMENTO:
        return false
    recursos[corrompido] = quantidade(corrompido) - 1
    recurso_alterado.emit(corrompido, int(recursos[corrompido]))
    recursos["claves"] = quantidade("claves") - CUSTO_PURIFICAR_FRAGMENTO
    recurso_alterado.emit("claves", int(recursos["claves"]))
    var limpo := "fragmento_" + nota
    recursos[limpo] = quantidade(limpo) + 1
    recurso_alterado.emit(limpo, int(recursos[limpo]))
    salvar()
    fragmento_purificado.emit(nota)
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


func poder_de_luta_detalhado() -> Dictionary:
    var soma_atributos := 0
    for id in ATRIBUTOS_INICIAIS:
        soma_atributos += valor_atributo(str(id))
    var poder_nivel := nivel * 100
    var poder_atributos := soma_atributos * 12
    var poder_arma := nivel_da_arma * 75 + 125
    var poder_acessorios := 0
    var raridades := {"Comum": 0, "Incomum": 20, "Raro": 50, "Épico": 90, "Lendário": 150}
    for slot in acessorios_equipados:
        var acessorio: Dictionary = ACESSORIOS.get(str(acessorios_equipados[slot]), {})
        if acessorio.is_empty():
            continue
        var bonus_total := 0
        for valor in (acessorio.get("bonus", {}) as Dictionary).values():
            bonus_total += int(valor)
        poder_acessorios += 55 + bonus_total * 20 + int(raridades.get(str(acessorio.get("raridade", "Comum")), 0))
    var poder_eco := int(eco_equipado.get("poder", 0))
    var poder_composicao := 0
    for acorde in acordes_equipados:
        if acorde is Dictionary:
            poder_composicao += int(acorde.get("poder", 0))
    var soma_skills := 0
    for valor in niveis_skills.values():
        soma_skills += int(valor)
    var poder_skills := soma_skills * 35
    return {
        "total": poder_nivel + poder_atributos + poder_arma + poder_acessorios + poder_eco + poder_composicao + poder_skills,
        "nivel": poder_nivel,
        "atributos": poder_atributos,
        "arma": poder_arma,
        "acessorios": poder_acessorios,
        "eco": poder_eco,
        "composicao": poder_composicao,
        "skills": poder_skills,
        "soma_atributos": soma_atributos,
        "soma_skills": soma_skills,
    }


func poder_de_luta_da_conta() -> int:
    var total := int(poder_de_luta_detalhado()["total"])
    for valor in poder_outros_personagens.values():
        if valor is Dictionary:
            total += int(valor.get("poder", 0))
        else:
            total += int(valor)
    return total


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
    cfg.set_value("personagem", "ascensoes", ascensoes)
    cfg.set_value("personagem", "marcos", marcos)
    cfg.set_value("poder", "arma", arma_equipada)
    cfg.set_value("poder", "nivel_arma", nivel_da_arma)
    cfg.set_value("poder", "skills", niveis_skills)
    cfg.set_value("poder", "eco", eco_equipado)
    cfg.set_value("poder", "ecos_descobertos", ecos_descobertos)
    cfg.set_value("poder", "acordes", acordes_equipados)
    cfg.set_value("poder", "outros_personagens", poder_outros_personagens)
    cfg.set_value("inventario", "recursos", recursos)
    cfg.set_value("inventario", "acessorios", acessorios_equipados)
    cfg.save(ARQUIVO)


func carregar() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(ARQUIVO) != OK:
        return
    nivel = clampi(int(cfg.get_value("personagem", "nivel", nivel)), 1, NIVEL_MAXIMO)
    experiencia = maxi(0, int(cfg.get_value("personagem", "experiencia", experiencia)))
    pontos_de_atributo = maxi(0, int(cfg.get_value("personagem", "pontos", pontos_de_atributo)))
    var attrs = cfg.get_value("personagem", "atributos", {})
    if attrs is Dictionary:
        for id in ATRIBUTOS_INICIAIS:
            atributos[id] = int(attrs.get(id, ATRIBUTOS_INICIAIS[id]))
    var marcos_salvos = cfg.get_value("personagem", "marcos", {})
    if marcos_salvos is Dictionary:
        marcos = marcos_salvos.duplicate(true)
    var guardados = cfg.get_value("inventario", "recursos", {})
    if guardados is Dictionary:
        for id in RECURSOS_INICIAIS:
            recursos[id] = maxi(0, int(guardados.get(id, RECURSOS_INICIAIS[id])))
    var equipados = cfg.get_value("inventario", "acessorios", {})
    if equipados is Dictionary:
        acessorios_equipados = equipados.duplicate(true)
    var asc_salvas = cfg.get_value("personagem", "ascensoes", {})
    if asc_salvas is Dictionary:
        for trava in TRAVAS_DE_ASCENSAO:
            ascensoes[trava] = bool(asc_salvas.get(trava, asc_salvas.get(str(trava), nivel > trava)))
    else:
        ascensoes[20] = nivel > 20
        ascensoes[40] = nivel > 40
    arma_equipada = str(cfg.get_value("poder", "arma", arma_equipada))
    nivel_da_arma = maxi(1, int(cfg.get_value("poder", "nivel_arma", nivel_da_arma)))
    var skills_salvas = cfg.get_value("poder", "skills", {})
    if skills_salvas is Dictionary:
        for id in niveis_skills:
            niveis_skills[id] = maxi(1, int(skills_salvas.get(id, niveis_skills[id])))
    var eco_salvo = cfg.get_value("poder", "eco", {})
    if eco_salvo is Dictionary:
        eco_equipado = eco_salvo.duplicate(true)
    var ecos_salvos = cfg.get_value("poder", "ecos_descobertos", ecos_descobertos)
    if ecos_salvos is Array:
        ecos_descobertos = ecos_salvos.duplicate()
    var acordes_salvos = cfg.get_value("poder", "acordes", [])
    if acordes_salvos is Array:
        acordes_equipados = acordes_salvos.duplicate(true)
    var outros_salvos = cfg.get_value("poder", "outros_personagens", {})
    if outros_salvos is Dictionary:
        poder_outros_personagens = outros_salvos.duplicate(true)
