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
signal escala_forjada(escala: String)

const ARQUIVO := "user://progresso.cfg"
const NIVEL_MAXIMO := 60
const TRAVAS_DE_ASCENSAO := [20, 40]
const NIVEL_MAXIMO_SKILL := 10
const NIVEIS_DESBLOQUEIO_SKILLS := {
    "ataque_basico": 1, "skill_1": 2, "skill_2": 4, "skill_3": 6,
}
const CUSTO_PURIFICAR_FRAGMENTO := 25
const FRAGMENTOS_POR_NOTA := 30
const CUSTO_SINTETIZAR_NOTA := 0
const PARTITURAS := {
    "menor": {"nome": "Partitura Menor", "custo": 500, "xp": 100, "recurso": "partitura_menor"},
    "harmonica": {"nome": "Partitura Harmônica", "custo": 2000, "xp": 500, "recurso": "partitura_harmonica"},
    "magistral": {"nome": "Partitura Magistral", "custo": 5000, "xp": 1500, "recurso": "partitura_magistral"},
}
const REQUISITOS_ASCENSAO := {
    20: {"partitura_harmonica": 3, "selo_regente": 1},
    40: {"partitura_magistral": 5, "nucleo_maestro": 1,
        "emblema_nota_silenciada": 1},
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
    "acorde_cura": 0,
    "acorde_vigor": 0,
    "escala_do_maior": 0,
    "escala_sol_maior": 0,
    "escala_la_menor": 0,
    "selo_regente": 0,
    "nucleo_maestro": 0,
    "emblema_nota_silenciada": 0,
    "pocao_cura": 0,
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

## CADA HEROI TEM A PROPRIA FICHA.
##
## Ate aqui o Progresso era do Akles e a Wins herdava tudo: mesmo nivel, mesmos
## atributos, mesmo Poder de Luta. Ela chegava upada sem nunca ter jogado, o que
## esvazia a troca de personagem — se os dois sao a mesma ficha com outra roupa,
## nao ha decisao nenhuma em escolher.
##
## O QUE E SEPARADO e o que se conquista jogando COM aquele heroi: nivel,
## experiencia, atributos, niveis de skill, arma e ascensoes.
##
## O QUE E COMPARTILHADO e o que pertence ao jogador, nao ao personagem: a
## mochila, os Ecos descobertos, os acordes e os marcos da historia. Uma Clave
## nao muda de dono quando voce troca de heroi.
const CAMPOS_DA_FICHA := ["nivel", "experiencia", "pontos_de_atributo",
    "atributos", "niveis_skills", "arma_equipada", "nivel_da_arma", "ascensoes"]
const HEROIS := ["akles", "wins"]

var personagem := "akles"
var _fichas: Dictionary = {}


func _ficha_nova() -> Dictionary:
    return {
        "nivel": 1, "experiencia": 0, "pontos_de_atributo": 0,
        "atributos": ATRIBUTOS_INICIAIS.duplicate(true),
        "niveis_skills": {"ataque_basico": 1, "skill_1": 1, "skill_2": 1, "skill_3": 1},
        "arma_equipada": "Espada do Despertar", "nivel_da_arma": 1,
        "ascensoes": {20: false, 40: false},
    }


func _guardar_ficha() -> void:
    var f := {}
    for campo in CAMPOS_DA_FICHA:
        var v = get(campo)
        f[campo] = v.duplicate(true) if v is Dictionary else v
    _fichas[personagem] = f


func _vestir_ficha(id: String) -> void:
    if not _fichas.has(id):
        _fichas[id] = _ficha_nova()
    var f: Dictionary = _fichas[id]
    for campo in CAMPOS_DA_FICHA:
        var v = f.get(campo)
        set(campo, v.duplicate(true) if v is Dictionary else v)
    personagem = id


## Chamada pelo Player quando o heroi em campo muda.
func trocar_personagem(id: String) -> void:
    if id == personagem or not id in HEROIS:
        return
    _guardar_ficha()
    _vestir_ficha(id)
    salvar()
    alterado.emit()


## A Wins e nova; a arma dela nao e a espada do Akles.
func nome_do_heroi(id := "") -> String:
    return "Wins" if (id if id != "" else personagem) == "wins" else "Akles"


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
    # A ficha do heroi em campo passa a ser a fonte; a do outro fica guardada.
    if _fichas.is_empty():
        _guardar_ficha()
    for id in HEROIS:
        if not _fichas.has(id):
            _fichas[id] = _ficha_nova()


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
    # O PODER DO ECO SAI DA TABELA, NAO DE QUEM CHAMOU.
    #
    # A tela de Ecos mandava "poder = 60 + descobertos * 8" — um numero de
    # regra de jogo calculado dentro de um botao de interface. Agora o Progresso
    # decide, a partir da funcao harmonica da nota, e a tela so mostra.
    var ficha: Dictionary = ECOS.get(id, {})
    var soma := 0.0
    for chave in ficha.get("bonus", {}):
        soma += float(ficha["bonus"][chave])
    eco_equipado = {
        "id": id, "nome": str(ficha.get("nome", dados.get("nome", id.capitalize()))),
        "forma": 1, "poder": int(soma),
        "raridade": str(ficha.get("raridade", "Comum")),
        "funcao": str(ficha.get("funcao", "")),
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
    # Regra central do sistema musical: trinta fragmentos da MESMA altura
    # condensam uma nota. Claves nao entram nesta etapa; elas continuam sendo
    # usadas para purificacao, partituras e acordes.
    var custos := {fragmento: FRAGMENTOS_POR_NOTA}
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


# ------------------------------------------------------------------ acordes
## TRES NOTAS SOAM JUNTAS E VIRAM UM ACORDE.
##
## O jogo se chama AcordeLot e ate aqui acorde era so o nome. Aqui ele e a
## receita: a triade maior de Do — primeiro, terceiro e quinto graus, Do-Mi-Sol
## — vira o frasco que devolve vida. A menor troca o Mi por Mi bemol e, como o
## jogo trabalha com sustenidos, o Re# ocupa esse lugar: mesma altura, outro
## nome. Quem monta o acorde no jogo esta montando o acorde de verdade.
##
## E a unica cura carregavel que existe. Antes so havia roubo de vida preso a um
## buff de dez segundos.
const ACORDES := {
    "acorde_cura": {
        "nome": "Acorde de Cura", "graus": "I · III · V",
        "notas": ["do", "mi", "sol"],
        "escala": "escala_do_maior",
        "licao": "Tríade maior de Dó: a fundamental, a terça e a quinta.",
        "custo_claves": 150, "efeito": "Restaura 45% da vida.",
    },
    "acorde_vigor": {
        "nome": "Acorde de Vigor", "graus": "I · III · V",
        "notas": ["la", "do", "mi"],
        "escala": "escala_la_menor",
        "licao": "Tríade de Lá menor: tônica, terça menor e quinta justa.",
        "custo_claves": 260, "efeito": "Restaura 25% da vida e concede escudo.",
    },
}

## A escala e a matriz persistente que libera acordes. Ela consome as sete
## notas uma unica vez; depois os acordes daquela familia podem ser montados.
const ESCALAS := {
    "escala_do_maior": {
        "nome": "Dó maior", "notas": ["do", "re", "mi", "fa", "sol", "la", "si"],
        "intervalos": "T · T · S · T · T · T · S",
        "recompensa": "Libera o Acorde de Cura",
    },
    "escala_sol_maior": {
        "nome": "Sol maior", "notas": ["sol", "la", "si", "do", "re", "mi", "fa_sustenido"],
        "intervalos": "T · T · S · T · T · T · S",
        "recompensa": "Amplifica habilidades de ressonância",
    },
    "escala_la_menor": {
        "nome": "Lá menor", "notas": ["la", "si", "do", "re", "mi", "fa", "sol"],
        "intervalos": "T · S · T · T · S · T · T",
        "recompensa": "Libera o Acorde de Vigor",
    },
}


func pode_forjar_escala(id: String) -> bool:
    if not ESCALAS.has(id):
        return false
    for nota in ESCALAS[id]["notas"]:
        if quantidade("nota_" + String(nota)) < 1:
            return false
    return true


func forjar_escala(id: String) -> bool:
    if not pode_forjar_escala(id):
        return false
    for nota in ESCALAS[id]["notas"]:
        var recurso := "nota_" + String(nota)
        recursos[recurso] = quantidade(recurso) - 1
        recurso_alterado.emit(recurso, int(recursos[recurso]))
    recursos[id] = quantidade(id) + 1
    recurso_alterado.emit(id, int(recursos[id]))
    salvar()
    escala_forjada.emit(id)
    alterado.emit()
    return true

## Quanto de vida cada acorde devolve, em fracao do maximo.
const CURA_DO_ACORDE := {"acorde_cura": 0.45, "acorde_vigor": 0.25}


func pode_montar_acorde(id: String) -> bool:
    if not ACORDES.has(id):
        return false
    var receita: Dictionary = ACORDES[id]
    if quantidade(String(receita.get("escala", ""))) < 1:
        return false
    if quantidade("claves") < int(receita["custo_claves"]):
        return false
    for nota in receita["notas"]:
        if quantidade("nota_" + String(nota)) < 1:
            return false
    return true


func montar_acorde(id: String) -> bool:
    if not pode_montar_acorde(id):
        return false
    var receita: Dictionary = ACORDES[id]
    recursos["claves"] = quantidade("claves") - int(receita["custo_claves"])
    for nota in receita["notas"]:
        recursos["nota_" + String(nota)] = quantidade("nota_" + String(nota)) - 1
    recursos[id] = quantidade(id) + 1
    salvar()
    alterado.emit()
    return true


## Consome um acorde e devolve quanto de vida ele vale, em fracao do maximo.
## Quem chama aplica na HUD — o Progresso nao conhece barra de vida.
func usar_acorde(id: String) -> float:
    if not ACORDES.has(id) or quantidade(id) < 1:
        return 0.0
    recursos[id] = quantidade(id) - 1
    salvar()
    alterado.emit()
    return float(CURA_DO_ACORDE.get(id, 0.0))


# --------------------------------------------------------------- os doze Ecos
## O ECO VALE PELO QUE A NOTA DELE E DENTRO DA ESCALA.
##
## Aqui a raridade nao foi sorteada: ela sai da funcao harmonica. Numa
## tonalidade, as notas nao tem o mesmo peso — a tonica e o repouso, a dominante
## e a tensao que pede resolucao, a sensivel puxa de volta para a tonica, e as
## notas cromaticas (os sustenidos) sao de passagem, ficam de fora do campo
## diatonico. Essa hierarquia e uma das primeiras coisas que se aprende em
## harmonia, e virou a hierarquia de poder do jogo: quem coleciona percebe a
## regra antes de alguem explicar.
##
## O bonus tambem segue a funcao, nao so o numero:
##   tonica      -> vida e defesa      (repouso, o que sustenta)
##   dominante   -> ataque e critico   (tensao, o que ataca)
##   subdominante-> poder harmonico    (o afastamento, a preparacao)
##   sensivel    -> dano critico       (o puxao agudo para a tonica)
##   cromaticas  -> ressonancia/coleta (notas de passagem, quem transita)
const ECOS := {
    "do": {"nome": "Dó", "grau": "I", "funcao": "Tônica", "raridade": "Lendário",
        "licao": "O repouso da tonalidade. Toda frase quer voltar para cá.",
        "bonus": {"vida_maxima": 170, "defesa": 18, "ataque": 12, "poder_harmonico": 20}},
    "re": {"nome": "Ré", "grau": "II", "funcao": "Supertônica", "raridade": "Raro",
        "licao": "Prepara a dominante. Raramente é destino, quase sempre caminho.",
        "bonus": {"vida_maxima": 45, "ataque": 9, "defesa": 6, "poder_harmonico": 10}},
    "mi": {"nome": "Mi", "grau": "III", "funcao": "Mediante", "raridade": "Raro",
        "licao": "É ela que decide se o acorde soa maior ou menor.",
        "bonus": {"ataque": 12, "critico": 1.2, "vida_maxima": 35, "poder_harmonico": 8}},
    "fa": {"nome": "Fá", "grau": "IV", "funcao": "Subdominante", "raridade": "Épico",
        "licao": "Afasta do repouso sem criar tensão. É o segundo pilar do tom.",
        "bonus": {"poder_harmonico": 34, "vida_maxima": 80, "defesa": 9, "ataque": 10}},
    "sol": {"nome": "Sol", "grau": "V", "funcao": "Dominante", "raridade": "Épico",
        "licao": "A maior tensão da tonalidade. Existe para resolver na tônica.",
        "bonus": {"ataque": 24, "critico": 2.2, "dano_critico": 15, "vida_maxima": 40}},
    "la": {"nome": "Lá", "grau": "VI", "funcao": "Superdominante", "raridade": "Raro",
        "licao": "O relativo menor mora aqui: mesma armadura, outro humor.",
        "bonus": {"vida_maxima": 60, "critico": 1.0, "ataque": 8, "poder_harmonico": 10}},
    "si": {"nome": "Si", "grau": "VII", "funcao": "Sensível", "raridade": "Épico",
        "licao": "Fica a meio tom da tônica e puxa para ela. Nunca descansa.",
        "bonus": {"dano_critico": 26, "critico": 2.0, "ataque": 14, "poder_harmonico": 12}},
    "do_sustenido": {"nome": "Dó#", "grau": "#I", "funcao": "Cromática", "raridade": "Incomum",
        "licao": "Fora do campo diatônico: nota de passagem entre Dó e Ré.",
        "bonus": {"poder_harmonico": 12, "vida_maxima": 25, "ataque": 4}},
    "re_sustenido": {"nome": "Ré#", "grau": "#II", "funcao": "Cromática", "raridade": "Incomum",
        "licao": "Entre Ré e Mi. Colore a passagem sem pertencer ao tom.",
        "bonus": {"poder_harmonico": 12, "critico": 0.6, "ataque": 5}},
    "fa_sustenido": {"nome": "Fá#", "grau": "#IV", "funcao": "Cromática", "raridade": "Incomum",
        "licao": "O trítono a partir de Dó — o intervalo mais instável da escala.",
        "bonus": {"ataque": 8, "dano_critico": 8, "poder_harmonico": 8}},
    "sol_sustenido": {"nome": "Sol#", "grau": "#V", "funcao": "Cromática", "raridade": "Incomum",
        "licao": "Entre Sol e Lá. Empresta tensão a quem passa por ela.",
        "bonus": {"critico": 0.8, "ataque": 6, "vida_maxima": 22}},
    "la_sustenido": {"nome": "Lá#", "grau": "#VI", "funcao": "Cromática", "raridade": "Incomum",
        "licao": "Vizinha da sensível. Aparece quando a música muda de tom.",
        "bonus": {"dano_critico": 10, "poder_harmonico": 9, "vida_maxima": 20}},
}

## O QUE A COLECAO INTEIRA VALE.
##
## Um eco equipado por vez faria o jogador guardar o Dó e nunca mais capturar
## nada. Entao cada Eco DESCOBERTO paga um pouco para sempre, e fechar a escala
## paga de novo: dominar as sete naturais e uma conquista de verdade em musica,
## e as doze fecham o cromatismo.
const POR_ECO_DESCOBERTO := {"vida_maxima": 10, "poder_harmonico": 3, "ataque": 2}
const NATURAIS := ["do", "re", "mi", "fa", "sol", "la", "si"]
const BONUS_ESCALA_DIATONICA := {"vida_maxima": 90, "ataque": 14, "poder_harmonico": 25, "defesa": 8}
const BONUS_ESCALA_CROMATICA := {"vida_maxima": 160, "ataque": 26, "poder_harmonico": 45,
    "defesa": 14, "critico": 2.0, "dano_critico": 20}


## Soma tudo que os Ecos dao: o equipado por inteiro, mais o pouco de cada um
## que ja foi descoberto, mais os fechamentos de escala.
func bonus_dos_ecos() -> Dictionary:
    var total := {"ataque": 0.0, "vida_maxima": 0.0, "defesa": 0.0,
        "critico": 0.0, "dano_critico": 0.0, "poder_harmonico": 0.0}

    var equipado := str(eco_equipado.get("id", ""))
    if ECOS.has(equipado):
        for chave in ECOS[equipado]["bonus"]:
            total[chave] = total.get(chave, 0.0) + float(ECOS[equipado]["bonus"][chave])

    for id in ecos_descobertos:
        for chave in POR_ECO_DESCOBERTO:
            total[chave] = total.get(chave, 0.0) + float(POR_ECO_DESCOBERTO[chave])

    if tem_a_escala_diatonica():
        for chave in BONUS_ESCALA_DIATONICA:
            total[chave] = total.get(chave, 0.0) + float(BONUS_ESCALA_DIATONICA[chave])
    if ecos_descobertos.size() >= ECOS.size():
        for chave in BONUS_ESCALA_CROMATICA:
            total[chave] = total.get(chave, 0.0) + float(BONUS_ESCALA_CROMATICA[chave])
    return total


func tem_a_escala_diatonica() -> bool:
    for nota in NATURAIS:
        if nota not in ecos_descobertos:
            return false
    return true


## A ficha do Eco, para a interface mostrar sem inventar numero.
func ficha_do_eco(id: String) -> Dictionary:
    return ECOS.get(id, {})


func estatisticas() -> Dictionary:
    var forca := valor_atributo("forca")
    var destreza := valor_atributo("destreza")
    var vitalidade := valor_atributo("vitalidade")
    var ressonancia := valor_atributo("ressonancia")
    var percepcao := valor_atributo("percepcao")
    # O QUE OS ECOS DAO ENTRA AQUI, e nao num numero solto de vitrine. Antes o
    # eco equipado so somava um "poder" que a propria tela de Ecos inventava —
    # sessenta mais oito por eco descoberto, calculado dentro do botao. Agora o
    # bonus e do dominio do Progresso, sai da tabela de funcao harmonica e
    # aparece de verdade em ataque, vida, defesa e critico.
    var eco := bonus_dos_ecos()
    return {
        "ataque": 18 + nivel * 3 + forca * 4 + destreza + int(eco["ataque"]),
        "vida_maxima": 160 + nivel * 14 + vitalidade * 22 + int(eco["vida_maxima"]),
        "defesa": 4 + vitalidade * 2 + destreza + int(eco["defesa"]),
        "critico": 3.0 + destreza * 0.55 + percepcao * 0.35 + eco["critico"],
        "dano_critico": 135.0 + forca * 1.5 + eco["dano_critico"],
        "poder_harmonico": ressonancia * 5 + percepcao * 2 + nivel * 2 + int(eco["poder_harmonico"]),
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
    # As duas fichas viajam juntas: sem isto, a do heroi que esta fora de campo
    # se perderia no proximo carregamento e a Wins voltaria do zero toda vez.
    _guardar_ficha()
    _salvar_fichas()
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


func _salvar_fichas() -> void:
    var cfg := ConfigFile.new()
    if FileAccess.file_exists(ARQUIVO):
        cfg.load(ARQUIVO)
    for id in _fichas:
        cfg.set_value("herois", String(id), _fichas[id])
    cfg.set_value("herois", "atual", personagem)
    cfg.save(ARQUIVO)


func _carregar_fichas(cfg: ConfigFile) -> void:
    for id in HEROIS:
        # Padrao vazio, e nao `null`: o ConfigFile reclama em voz alta quando a
        # secao ainda nao existe, e ela nao existe no primeiro jogo de ninguem.
        var f = cfg.get_value("herois", id, {})
        if f is Dictionary and not f.is_empty():
            _fichas[id] = f
    var atual := String(cfg.get_value("herois", "atual", "akles"))
    if _fichas.has(atual):
        _vestir_ficha(atual)


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
    # AS FICHAS POR HEROI TEM A ULTIMA PALAVRA.
    #
    # O bloco acima le o formato antigo, de um personagem so — e ele continua
    # valendo como a ficha do Akles em saves feitos antes da separacao. Se o
    # arquivo ja tiver fichas por heroi, elas sobrescrevem, e a do heroi em
    # campo volta a ser a fonte.
    _carregar_fichas(cfg)
