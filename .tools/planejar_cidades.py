#!/usr/bin/env python3
"""Desenha as plantas urbanas do Acordelot e grava data/city_layouts.json.

Gera as cidades e marcos arquitetonicos com planejamento radial e arquitetura
medieval detalhada:
- Capital Imperial de Acordelot (3 aneis, 8 avenidas, muralha completa, mansoes, mercado)
- Portoes Reais (fortaleza de guarnicao, baluartes e estandartes)
- Vila do Caminho & Mercado do Vale (feira livre, moinho, chales, carrocas)
- Vila Ribeirinha do Lago (porto lacustre, pontes, moinhos d'agua)
- Cidadela da Serra (forte de montanha, muralhas de pedra, torres)
- Salao do Forjador (polo de metalurgia, forjas e oficinas)
- Santuario das Notas Sagradas (circulo mistico com cristais ressonantes)

Rodar: python3 .tools/planejar_cidades.py
"""
import json
import math
import os
import random

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M = "res://models/"

# Largura livre de vias em metros
LARGURA_DA_AVENIDA = 6.5
LARGURA_DO_ANEL = 4.5
RECUO = 2.0

# Paletas de construcoes
CASAS_MEDIEVAIS = [
    "medieval_house_1", "medieval_house_3", "casa_vila",
    "casa_camponesa", "casa_chale", "casa_mercador"
]
NOBRES_E_MANSOES = [
    "medieval_house_3", "casa_nobre",
    "casa_sobrado", "medieval_house_1"
]
COMERCIO_E_OFICINAS = [
    "medieval_house_1", "casa_mercador", "loja_toldo",
    "medieval_house_3", "oficina_ferreiro"
]
CHALES_E_CAMPO = [
    "casa_chale", "medieval_house_1", "casa_camponesa",
    "celeiro", "casa_vila"
]

# O verde que entra DENTRO da cidade.
#
# Sao os modelos mais baratos que temos — de 900 a 2.900 triangulos, e nenhum
# deles traz textura, a cor vem do vertice. Isso importa porque cidade e onde a
# contagem de objetos ja e alta: plantar com a arvore texturada de 22 mil
# triangulos custaria mais que todas as casas do quarteirao juntas.
ARVORES_DE_RUA = ["arvore_frondosa", "arvore_carvalho", "arvore_pequena"]
ARVORES_DE_POMAR = ["arvore_pequena", "arvore_frondosa"]
# Grama de sobra e arbusto contado.
#
# O tufo de grama sao 900 triangulos; o arbusto sao 9.434 — dez vezes mais por
# uma peca que na tela ocupa quase o mesmo espaco. Com um arbusto a cada tres,
# a folhagem da Capital somava 269 mil triangulos, mais que todas as casas dela
# juntas. Um a cada seis mantem a variedade e devolve o orcamento.
MATO_DE_JARDIM = ["grass", "grass", "grass",
                  "fantasy_bush_1787078968444", "grass", "grass"]


def peca(ident, tag, modelo, x, z, giro=0.0, escala=1.0, y=0.0):
    return {
        "id": ident,
        "tag": tag,
        "model": M + modelo + ".glb",
        "position": [round(x, 2), round(z, 2)],
        "rotation": round(giro % 360.0, 1),
        "scale": escala,
        "y": y
    }


def _diferenca(a, b):
    return (a - b + 180.0) % 360.0 - 180.0


def _abertura(raio, largura):
    return math.degrees(math.atan2(largura * 0.5 + RECUO, max(raio, 1.0)))


def anel_de_casas(pecas, prefixo, raio, por_quarteirao, ruas, paleta, tag="casa"):
    lote = 0
    for indice in range(len(ruas)):
        comeco = ruas[indice]
        fim = ruas[(indice + 1) % len(ruas)]
        largura = (fim - comeco) % 360.0
        margem = _abertura(raio, LARGURA_DA_AVENIDA)
        util = largura - margem * 2.0
        if util <= 0.0:
            continue

        for k in range(por_quarteirao):
            passo = util / por_quarteirao
            angulo = comeco + margem + passo * (k + 0.5)
            rad = math.radians(angulo)
            modelo = paleta[lote % len(paleta)]
            escala = 1.0
            tag_atual = tag
            if modelo == "medieval_house":
                tag_atual = "mansao_medieval"
            elif modelo == "medieval_house_1":
                tag_atual = "casa_enxaimel_1"
            elif modelo == "medieval_house_3":
                tag_atual = "casa_enxaimel_2"
            
            pecas.append(peca(
                f"{prefixo}_{lote:02d}", tag_atual, modelo,
                math.cos(rad) * raio, math.sin(rad) * raio,
                giro=270.0 - angulo, escala=escala))
            lote += 1


def muralha_circular(pecas, raio, torres, portoes):
    for i in range(torres):
        angulo = i * (360.0 / torres)
        if any(abs(_diferenca(angulo, p)) < 15.0 for p in portoes):
            continue
        rad = math.radians(angulo)
        pecas.append(peca(f"torre_{i:02d}", "torre", "torre_redonda",
                          math.cos(rad) * raio, math.sin(rad) * raio,
                          giro=270.0 - angulo, escala=1.1))
    for i, angulo in enumerate(portoes):
        rad = math.radians(angulo)
        pecas.append(peca(f"portao_{i}", "muralha", "muralha_portao",
                          math.cos(rad) * raio, math.sin(rad) * raio,
                          giro=270.0 - angulo, escala=1.25))


def iluminar(pecas, raio, angulos, marca):
    for i, angulo in enumerate(angulos):
        rad = math.radians(angulo)
        pecas.append(peca(f"lamp_{marca}_{i:02d}", "lampiao", "lampiao",
                          math.cos(rad) * raio, math.sin(rad) * raio))


def arborizar(pecas, ruas, raios, marca="rua"):
    """Alinha arvores nas avenidas, uma de cada lado.

    Cidade sem uma arvore nao existe fora de maquete. E a arvore de rua nao vai
    solta no meio do quarteirao: ela acompanha a via, que e o que da ao olho a
    linha da avenida mesmo de longe, quando as casas ainda sao vultos.
    """
    conta = 0
    for angulo in ruas:
        rad = math.radians(angulo)
        # Perpendicular a avenida: e por onde a arvore se afasta do meio da rua.
        px, pz = -math.sin(rad), math.cos(rad)
        for raio in raios:
            for lado in (-1.0, 1.0):
                recuo = (LARGURA_DA_AVENIDA * 0.5 + 1.6) * lado
                x = math.cos(rad) * raio + px * recuo
                z = math.sin(rad) * raio + pz * recuo
                modelo = ARVORES_DE_RUA[conta % len(ARVORES_DE_RUA)]
                pecas.append(peca(
                    f"arvore_{marca}_{conta:02d}", "arvore_de_rua", modelo,
                    x, z, giro=(conta * 47) % 360, escala=1.0))
                conta += 1


def ajardinar(pecas, ruas, aneis, marca="quarteirao"):
    """Poe mato e arbusto nos FUNDOS dos quarteiroes.

    O buraco entre um anel de casas e o seguinte e quintal, nao praca: deixar
    terra pelada ali e o que faz a cidade parecer cenario montado sobre um campo
    em vez de construida nele. O mato entra justamente onde a casa nao vai.
    """
    conta = 0
    raios = [r for r, _, _ in aneis]
    fundos = [round((raios[i] + raios[i + 1]) * 0.5, 2)
              for i in range(len(raios) - 1)]
    if raios:
        fundos.append(round(raios[-1] + 4.5, 2))

    for raio in fundos:
        # Entre uma avenida e a seguinte, tres tufos — e nao encostados na via,
        # senao viram obstaculo bem onde o jogador anda.
        for indice in range(len(ruas)):
            comeco = ruas[indice]
            largura = (ruas[(indice + 1) % len(ruas)] - comeco) % 360.0
            margem = _abertura(raio, LARGURA_DA_AVENIDA + 3.0)
            util = largura - margem * 2.0
            if util <= 0.0:
                continue
            for k in range(2):
                angulo = comeco + margem + util * (k + 0.5) / 2.0
                rad = math.radians(angulo)
                # So grama nos quintais da cidade, com tamanhos diferentes.
                #
                # O arbusto foi tentado aqui e nao se pagou: doze deles sozinhos
                # somavam 113 mil triangulos, mais que a metade de toda a
                # folhagem da Capital, para uma peca que na tela ocupa quase o
                # mesmo lugar que um tufo de 900. A variedade sai da escala.
                escala = (0.85, 1.0, 1.25, 1.05)[conta % 4]
                pecas.append(peca(
                    f"verde_{marca}_{conta:02d}", "folhagem", "grass",
                    math.cos(rad) * raio, math.sin(rad) * raio,
                    giro=(conta * 61) % 360, escala=escala))
                conta += 1


# ------------------------------------------------------------------ A VILA
#
# So entram modelos COM TEXTURA. O resto do acervo e cor por vertice, que e
# literalmente o que massinha e: uma cor media por regiao, sem sujeira, sem
# madeira, sem telha. Nao ha planejamento urbano que salve isso.
#
# Com as tres casas novas o vocabulario passou de duas para cinco construcoes,
# todas texturizadas — o bastante para uma rua parecer rua sem repetir a mesma
# fachada de tres em tres metros.
#
# A MEDIDA MORA AQUI. O construtor normaliza cada modelo pela ALTURA (tabela
# ALTURA_POR_TAG do zone_builder.gd), e a planta so pode alinhar fachada e
# medir vao se souber quanto cada casa ocupa DEPOIS dessa conta. Por isso a
# frente e o fundo abaixo ja estao na escala final, em metros.
#
#            etiqueta          modelo              altura  frente  fundo
CASAS = {
    "casa_alta":   ("medieval_house_1",  9.8,  3.29,  4.81),
    "casa_larga":  ("medieval_house_3",  8.8,  9.75,  4.27),
    "casa_pedra":  ("casa_pedra",        8.4,  8.45,  6.19),
    "casarao":     ("casarao_madeira",  10.0,  7.15, 12.95),
    "solar":       ("casa_solar",       11.0, 12.42, 12.18),
}

# Para que lado o modelo olha, em graus, quando chega do disco.
#
# Nenhum GLB combinou com o vizinho: cada um foi modelado com a fachada virada
# para um lado, e o construtor nao tem como adivinhar onde esta a porta. Se ao
# abrir a vila uma casa estiver de costas para a rua, o conserto e UM numero
# aqui — 180 vira ela, 90 e 270 poem de lado — e nao mexer em lote nenhum.
GIRO_DA_FACHADA = {
    "casa_alta": 0.0, "casa_larga": 0.0,   # ja conferidas em tela
    "casa_pedra": 0.0, "casarao": 0.0, "solar": 0.0,
}

# Os props da vila. Mesma regra das casas: so entra o que tem textura, e a
# altura aqui e a MESMA da tabela ALTURA_POR_TAG do zone_builder.gd — e ela que
# leva o modelo do tamanho em que veio para o tamanho de verdade.
#
#         etiqueta        modelo
POCO = ("poco", "poco_vila")            # 2,4 m — o marco do largo
BANCO = ("banco", "banco_vila")         # 1,0 m
CARROCA = ("carroca", "carroca_vila")   # 1,8 m — 596 triangulos, a mais barata
BARRIS = ("barris", "barris_vila")      # 1,6 m
CAIXOTES = ("caixotes", "caixotes_vila")
SACO = ("saco", "saco_vila")
POSTE = ("poste", "poste_vila")         # 4,6 m — a luz da rua
TOCHA_PAREDE = ("tocha_parede", "tocha_vila")   # 1,3 m, pendurada na fachada

ARVORE_GRANDE = "tree_gn"         # 12 m, copa de 11 m — marco, nao enfeite
PINHEIRO = "pine_tree"            # 9,5 m, barata: 2,1 mil triangulos
COGUMELO = "mushroom_tree"        # 2,4 m, sub-bosque

# O plato da zona e plano ate 45 m do centro e desce dai para fora. Tudo o que
# for construcao mora dentro desse raio — casa em ladeira e o que fazia a vila
# parecer torta.
RAIO_PLANO = 44.0

# A rua principal corre no eixo Z porque e o eixo dos portais desta zona: o
# jogador entra pelo sul (z positivo) vindo da floresta e sai pelo norte para
# os Portoes Reais. A vila e uma PASSAGEM, e a rua dela e a estrada que a criou.
MEIA_RUA = 4.0          # a rua tem 8 m
FACHADA_X = 7.0         # a linha das fachadas: 3 m de calcada ate a rua
MEIA_PRACA = 9.0        # largo pequeno; doze metros ja lia como praca de cidade
LANE_Z = 0.0            # as travessas saem do largo
LANE_ATE = 28.0
MEIA_LANE = 3.0
CALCADA_X = 5.6         # onde as tochas ficam: fora da rua, antes da fachada


def vila_da_estrada():
    """A Vila do Caminho: uma rua, duas fileiras, um largo no meio.

    E o desenho de povoado de beira de estrada — o tipo que existe porque
    alguem parou onde dava para parar. Nao tem praca central com aneis em volta
    como cidade tem; tem UMA via, e tudo se organiza em relacao a ela.

    Tres regras seguram a leitura, e sao elas que separam "vila construida" de
    "objetos espalhados":

    1. LINHA DE FACHADA, nao linha de centro. O que o olho alinha e a PAREDE da
       frente, nao o meio da casa. Enquanto o recuo era medido pelo centro, o
       casarao de onze metros de fundo enfiava a fachada dentro da rua e as
       casas rasas ficavam recuadas demais. Agora cada casa entra o proprio
       fundo para tras a partir de x = 7 m, e as cinco fachadas caem na mesma
       linha por mais diferentes que sejam por dentro.

    2. TODA CASA OLHA PARA A RUA. Nao ha casa de lado, nao ha casa de costas.
       Quem entra pelo portal ve uma rua ladeada de portas, e sabe para onde ir
       sem que ninguem precise dizer.

    3. O VERDE NUNCA ENTRA NA FRENTE DA CASA. Pinheiro so atras da linha de
       fachada, formando fundo; arvore grande so nas pontas e no largo. Arvore
       entre a casa e a rua e o que apaga o desenho da via.
    """
    pecas = []

    # --- os lotes da rua, de sul (entrada) para norte (saida)
    #
    # Tres vazios de proposito. Sao TERRENOS RESERVADOS, nao esquecimento: a
    # vila precisa ter para onde crescer, e um vao na fileira e o que faz um
    # povoado parecer vivo em vez de encomendado pronto. Nos vaos vai cerca,
    # nao mato: terreno cercado le como lote de alguem.
    #
    # A ordem das casas nao e sorteio. A vila conta uma historia de sul para
    # norte: chega-se pelas casas simples, passa-se pelo largo com o solar de
    # telhado vermelho — a construcao mais rica, a que marca o centro — e sai-se
    # pelo casarao de madeira, que ja e quase celeiro, quase roca.
    # Sete casas, concentradas. Antes eram treze construcoes e quatro ruas:
    # isso ja lia como cidade pequena. A vila volta a ser um povoado de estrada,
    # com vazios naturais entre dois pequenos nucleos habitados.
    LOTES = {
        ("oeste",  28.0): "casa_pedra",
        ("oeste",   8.0): "casa_larga",
        ("oeste", -16.0): "casa_alta",
        ("oeste", -29.0): "casarao",
        ("leste",  28.0): "casa_alta",
        ("leste",   5.0): "casa_pedra",
        ("leste", -20.0): "solar",
    }

    for (lado, z), etiqueta in LOTES.items():
        modelo, _altura, _frente, fundo = CASAS[etiqueta]
        sinal = -1.0 if lado == "oeste" else 1.0
        # A fachada na linha; o corpo da casa cresce para tras dela.
        x = sinal * (FACHADA_X + fundo * 0.5)
        mao = "s" if z > 0 else "n"
        giro = (90.0 if sinal < 0 else 270.0) + GIRO_DA_FACHADA[etiqueta]
        pecas.append(peca(f"casa_{lado}_{mao}{abs(int(z)):02d}", etiqueta, modelo,
                          x, z, giro=giro))

    # --- o portal do sul: duas arvores grandes fazendo porta
    #
    # A vila nao tem muralha nem arco, e nao vai ter — nenhum dos dois existe
    # com textura no acervo. Mas duas copas de doze metros ladeando a estrada
    # fazem o mesmo trabalho: estreitam a vista e dizem "aqui comeca".
    for sinal in (-1.0, 1.0):
        pecas.append(peca(f"portao_verde_{'o' if sinal < 0 else 'l'}",
                          "arvore_marco", ARVORE_GRANDE,
                          sinal * 12.0, 44.5, giro=(0.0 if sinal < 0 else 180.0)))

    # --- o largo: uma arvore fora do meio
    #
    # O centro fica VAZIO. Largo com coisa no meio nao e largo, e rotatoria — e
    # aqui e onde as travessas cruzam a rua principal.
    pecas.append(peca("arvore_do_largo", "arvore_marco", ARVORE_GRANDE,
                      -15.0, 9.5, giro=35.0))

    # --- o fundo da rua: pinheiros atras da linha de fachada
    #
    # Foram de 13,5 para 21 m quando as casas novas entraram: o casarao tem onze
    # metros de fundo e o solar dez, e no lugar antigo o pinheiro nascia dentro
    # do telhado.
    for i, z in enumerate((30.0, 14.0, -18.0, -31.0)):
        for sinal in (-1.0, 1.0):
            pecas.append(peca(f"pinheiro_fundo_{i}_{'o' if sinal < 0 else 'l'}",
                              "pinheiro", PINHEIRO, sinal * 21.0, z,
                              giro=(i * 71 + (0 if sinal < 0 else 37)) % 360))

    # Copas laterais fecham o povoado sem sugerir novas ruas.
    for sinal in (-1.0, 1.0):
        for z in (16.0, -9.0):
            pecas.append(peca(f"pinheiro_lateral_{'o' if sinal < 0 else 'l'}_{int(z)}",
                              "pinheiro", PINHEIRO, sinal * 27.0, z,
                              giro=int(abs(z) * 19 + (0 if sinal < 0 else 87)) % 360))

    # --- a saida norte, mais discreta que a entrada
    for sinal in (-1.0, 1.0):
        pecas.append(peca(f"pinheiro_saida_{'o' if sinal < 0 else 'l'}",
                          "pinheiro", PINHEIRO, sinal * 9.5, -42.5,
                          giro=(0.0 if sinal < 0 else 180.0)))

    # --- a orla: sub-bosque marcando onde a vila acaba e a mata comeca
    borda = [(26.0, 30.0), (-26.0, 32.0), (30.0, 12.0), (-31.0, 14.0),
             (28.0, -16.0), (-27.0, -18.0), (24.0, -33.0), (-25.0, -31.0),
             (34.0, 0.0), (-34.0, -4.0)]
    for i, (x, z) in enumerate(borda):
        pecas.append(peca(f"cogumelo_{i:02d}", "cogumelo", COGUMELO,
                          x, z, giro=(i * 83) % 360,
                          escala=round(0.85 + (i % 4) * 0.14, 2)))

    # --- a vida da rua: poco, carroca, barris, caixotes, sacos, banco
    pecas += _props_da_vila()

    # --- os quintais: o que enche o fundo e as laterais das casas
    pecas += _quintais_da_vila()

    # O desenho viario vai para o shader do chao: rua no eixo Z, largo no meio,
    # duas travessas. Sem isto a rua e so a ausencia de casa, e o jogador nao
    # ve caminho nenhum.
    return pecas, {
        "avenidas": 2, "aneis": [MEIA_PRACA],
        # Esta planta foi desenhada SO com os modelos que tem textura, e conta
        # com isso. A marca vale para esta zona, nao para o mapa inteiro — as
        # outras cidades ainda dependem do acervo antigo e ficariam vazias.
        "so_com_textura": True,
        "vias": {
            "principal": [MEIA_RUA, 44.0],
            "largo": MEIA_PRACA,
            "travessas": [LANE_Z, 0.0, 0.0],
        },
        # Quem mora aqui. Por enquanto uma so: [id, x, z, giro, dialogo].
        "npcs": [["mirella", 6.2, -8.0, 250.0, "mirella_boas_vindas"]],
        "luzes": _postes_da_vila(),
        "tochas": _tochas_de_parede(),
        "adornos": _adornos_da_vila(),
    }


def _postes_da_vila():
    """Onde a vila acende de noite.

    Dez postes, nao trinta. A conta nao e de gosto: cada poste e uma luz pontual
    mais uma mancha aditiva no chao, e mancha aditiva SOMA — quatro perto viram
    uma chapa branca e a noite acaba. Dez, espacados de doze a quinze metros,
    deixam a rua legivel com escuro entre um poste e outro, que e o que faz a
    vila continuar parecendo noite.

    A regra de posicao e uma so: poste mora na calcada, entre a rua e a fachada,
    e sempre AOS PARES nos dois lados da via. Luz de um lado so faz a rua parecer
    torta, e o jogador anda para o lado iluminado sem saber por que.
    """
    postes = []
    # A rua: dois pares ao norte do largo, dois ao sul. E o corredor de luz que
    # leva o jogador de um portal ao outro.
    for z in (27.0, 10.0, -12.0, -28.0):
        for sinal in (-1.0, 1.0):
            postes.append([round(sinal * CALCADA_X, 2), z])
    # O largo, onde as travessas cruzam: um par, marcando o cruzamento sem
    # fechar o vazio do meio.
    for sinal in (-1.0, 1.0):
        postes.append([round(sinal * CALCADA_X, 2), 0.0])
    return postes


def _quintais_da_vila():
    """O fundo e a lateral das casas — o que faltava para a vila parecer morada.

    A rua estava resolvida e o resto era gramado liso: passava-se por tras da
    fileira e nao havia nada, o que denuncia cenario de fachada, feito so para
    ser visto de frente.

    Quintal nao e deposito de enfeite. O que entra aqui e o que uma casa produz
    por existir: lenha empilhada, barril de agua encostado na parede dos fundos,
    caixote vazio que ninguem levou embora, e a arvore que ja estava no terreno
    quando a casa foi levantada. Por isso quase tudo fica ATRAS de uma casa
    especifica, a poucos metros da parede dela — coisa de quintal esta perto da
    porta dos fundos, nao no meio do campo.

    A faixa util e estreita: entre o fundo da casa (que vai ate uns doze metros
    do eixo) e os pinheiros de fundo, aos vinte e um. Sobra pouco mais de oito
    metros de cada lado, e e onde tudo isto mora.
    """
    lista = []

    def por(nome, alvo, x, z, giro=0.0, escala=1.0):
        tag, modelo = alvo
        lista.append(peca(nome, tag, modelo, x, z, giro=giro, escala=escala))

    # --- quintais da fileira oeste
    por("quintal_o_caixotes", CAIXOTES, -13.8, 37.6, giro=100.0)
    por("quintal_o_saco", SACO, -14.9, 35.4, giro=20.0)
    por("quintal_o_barris", BARRIS, -13.4, 16.8, giro=300.0, escala=0.9)
    por("quintal_o_caixotes2", CAIXOTES, -13.6, -22.4, giro=215.0)
    por("quintal_o_saco2", SACO, -14.2, -30.8, giro=75.0)
    por("quintal_o_barris2", BARRIS, -14.8, 27.5, giro=140.0, escala=0.85)

    # --- quintais da fileira leste
    por("quintal_l_caixotes", CAIXOTES, 13.6, 37.2, giro=280.0)
    por("quintal_l_barris", BARRIS, 13.2, 26.4, giro=55.0, escala=0.9)
    por("quintal_l_saco", SACO, 14.6, -36.2, giro=250.0)
    por("quintal_l_caixotes2", CAIXOTES, 20.4, -14.5, giro=15.0)
    por("quintal_l_barris3", BARRIS, 14.2, 15.0, giro=190.0, escala=0.8)

    # --- as arvores que ja estavam no terreno
    #
    # Nos quintais, nao na rua: arvore atras da casa da fundo verde a fileira
    # inteira quando o jogador olha a vila de lado, e e o que separa "casas num
    # gramado" de "casas com quintal".
    for ident, x, z, giro in (
            ("arvore_quintal_o1", -15.6, 24.5, 40.0),
            ("arvore_quintal_o2", -16.8, -2.0, 200.0),
            ("arvore_quintal_l1", 16.0, 30.0, 120.0),
            ("arvore_quintal_l2", 15.8, -27.5, 310.0)):
        lista.append(peca(ident, "pinheiro", PINHEIRO, x, z, giro=giro))

    # Uma copa grande no fundo do quintal do solar: a casa mais rica da vila e a
    # unica com sombra propria.
    lista.append(peca("arvore_do_solar", "arvore_marco", ARVORE_GRANDE,
                      22.0, -21.5, giro=65.0))

    # --- os vaos largos perto do largo e das pontas
    por("vao_o_caixotes", CAIXOTES, -12.0, 20.5, giro=130.0, escala=0.9)
    por("vao_l_barris", BARRIS, 13.5, -32.0, giro=25.0, escala=0.85)
    por("vao_o_saco", SACO, -12.5, -9.0, giro=300.0)
    por("vao_l_caixotes", CAIXOTES, 11.4, 8.5, giro=245.0, escala=0.9)

    # Duas copas fechando a vista onde o gramado corria solto ate a mata.
    for ident, x, z, giro in (("pinheiro_vao_o", -14.0, -4.0, 25.0),
                              ("pinheiro_vao_l", 12.8, -6.5, 200.0)):
        lista.append(peca(ident, "pinheiro", PINHEIRO, x, z, giro=giro))

    return lista


def _tochas_de_parede():
    """As tochas presas nas fachadas.

    O poste ilumina a VIA; a tocha ilumina a PORTA. Sao trabalhos diferentes e e
    por isso que existem as duas: sem a tocha, a casa a noite e um bloco escuro
    atras de uma rua acesa, e o jogador nao sabe onde ha porta para bater.

    Uma por casa, e so em seis das treze. Uma tocha em cada fachada daria uma
    parede de fogo — e chama nao e enfeite, e sinal: quem tem tocha acesa esta
    aberto. A taberna, a oficina, a casa do velho que nao dorme.

    Cada tocha e [x, z, giro, altura_na_parede].
    """
    return [
        [-7.05,  25.0,  90.0, 2.1],
        [-7.05,   5.0,  90.0, 2.1],
        [ 7.05,  25.0, 270.0, 2.1],
        [ 7.05, -15.0, 270.0, 2.3],
    ]


def _props_da_vila():
    """O que faz a rua parecer habitada.

    A regra que decide cada posicao e uma so: TODO PROP TEM DONO. Barril nao
    nasce no meio do campo — encosta na parede de quem o usa. Caixote fica na
    porta de quem recebeu a carga, saco ao lado do caixote, carroca parada onde
    daria para descarregar. Objeto solto no gramado le como coisa esquecida pelo
    programador, e e exatamente o que ele e.

    Por isso quase tudo mora na faixa entre a linha da fachada (7 m) e um metro
    atras dela, nos VAOS entre as casas — nunca na frente de uma porta, nunca na
    calcada onde o jogador anda, nunca no meio da rua.

    O poco e a excecao e o unico marco: fica na beira do largo, nao no centro,
    porque largo com coisa no meio vira rotatoria.
    """
    lista = []

    def por(nome, alvo, x, z, giro=0.0, escala=1.0):
        tag, modelo = alvo
        lista.append(peca(nome, tag, modelo, x, z, giro=giro, escala=escala))

    # --- o largo: o poco de um lado, o banco do outro, olhando para ele
    por("poco_da_vila", POCO, 8.6, -6.0, giro=200.0)
    por("banco_do_largo", BANCO, -7.6, -5.0, giro=90.0)
    por("carroca_do_largo", CARROCA, -9.6, 2.0, giro=115.0)

    # --- os vaos da fileira oeste
    por("barris_oeste", BARRIS, -8.2, 20.0, giro=25.0)
    por("caixotes_oeste", CAIXOTES, -8.4, 31.0, giro=70.0)
    por("saco_oeste", SACO, -7.4, 29.0, giro=15.0)
    por("caixotes_oeste_2", CAIXOTES, -8.0, -19.0, giro=200.0)
    por("saco_oeste_2", SACO, -7.6, -30.5, giro=340.0)

    # --- os vaos da fileira leste
    por("caixotes_leste", CAIXOTES, 8.3, 32.5, giro=250.0)
    por("barris_leste", BARRIS, 8.1, 18.5, giro=310.0)
    por("saco_leste", SACO, 7.7, 19.8, giro=120.0)
    por("barris_leste_2", BARRIS, 8.4, -30.5, giro=40.0, escala=0.9)

    # --- as travessas, onde as casas viram fundo de quintal
    por("carroca_travessa", CARROCA, -16.0, 3.0, giro=285.0)
    por("caixotes_travessa", CAIXOTES, 19.0, 7.6, giro=95.0)
    por("barris_travessa", BARRIS, 20.5, -11.8, giro=160.0, escala=0.85)
    por("saco_travessa", SACO, -19.0, -7.8, giro=60.0)

    return lista


# As estampas recortadas do acervo. Sao pintadas a mao, com alfa — a mesma
# familia de arte das casas, e nada aqui e cor-por-vertice.
# Mora em props/, e nao em cidade/, por causa da EXPORTACAO: a pasta cidade
# inteira esta na lista de exclusao do build web — sao as texturas do acervo
# velho. A cerca e a unica de la que o jogo usa hoje, entao mudou de casa em vez
# de trazer as trinta e oito irmas junto.
CERCA = "props/cerca_tabua"
PLACA = "props/placa_madeira"
FLORES = ["props/flores_1", "props/flores_2", "props/flores_3"]
PEDRAS = ["props/pedra_1", "props/pedra_2", "props/pedra_3"]
CAPIM = ["props/tufo_grama_1", "props/tufo_grama_2",
         "props/tufo_grama_3", "props/tufo_grama_4"]


def _adornos_da_vila():
    """A decoracao, e o pouco que ela tem de ser.

    Duas coisas guiam o que entra: a decoracao explica o lugar, ou nao entra.
    Cerca fecha o terreno reservado e diz "isto aqui tem dono"; a placa no
    portal sul diz "chegou"; flor e capim so nascem onde ninguem pisa — na
    beira da mata, no vao entre casas, nunca no meio da rua nem na calcada.

    O que NAO entra: enfeite de meio de rua, mato na frente de porta, pedra na
    calcada. Tudo isso polui a leitura da via, que e a coisa que a vila tem.

    Cada adorno e: [estampa, x, z, altura_em_metros, giro, fixo].
    "fixo" e para o que tem lado — cerca e placa se alinham com a rua; flor,
    pedra e capim giram com a camera, senao somem de perfil.
    """
    adornos = []

    # --- os tres lotes reservados, cercados
    #
    # A cerca fica NA LINHA DA FACHADA, continuando a parede das casas vizinhas.
    # E o que transforma um buraco na fileira em terreno: a rua segue fechada,
    # so que por cerca em vez de casa.
    for lado, z_centro in (("oeste", 25.0), ("leste", 14.0), ("leste", -25.0)):
        sinal = -1.0 if lado == "oeste" else 1.0
        for k in range(-2, 3):
            adornos.append([CERCA, round(sinal * FACHADA_X, 2),
                            round(z_centro + k * 2.1, 2), 1.5, 90.0, True])

    # --- a placa do portal sul, virada para quem chega
    adornos.append([PLACA, 6.0, 40.0, 2.6, 270.0, True])

    # --- flores e capim nos vaos, atras da linha da fachada
    #
    # Posicoes escolhidas a mao, nao sorteadas: sorteio poe flor no meio da
    # porta uma hora, e ninguem revisa cem numeros aleatorios.
    verdes = [
        (FLORES[0], -19.5, 30.0), (CAPIM[0], -20.5, 27.0),
        (FLORES[1], 19.0, 31.5), (CAPIM[1], 17.0, 11.5),
        (FLORES[2], -20.0, -6.0), (CAPIM[2], -21.0, -30.0),
        (FLORES[0], 21.0, -30.0), (CAPIM[3], 19.5, -22.0),
        (FLORES[1], -13.0, 43.0), (CAPIM[0], 13.5, 43.5),
        (FLORES[2], -12.0, -44.0), (CAPIM[1], 12.5, -43.5),
    ]
    for i, (tex, x, z) in enumerate(verdes):
        alt = 0.85 if "flores" in tex else 1.0
        adornos.append([tex, x, z, alt, float((i * 47) % 360), False])

    # --- as cercas de quintal e o mato dos fundos
    #
    # A cerca dos fundos fecha o lote por tras, na mesma linha em toda a
    # fileira: e ela que diz onde a casa acaba e a mata comeca, e sem esse
    # limite o quintal se dissolve no gramado. Fica aos dezessete metros e meio,
    # atras da casa mais funda e na frente dos pinheiros.
    # Cada lado tem a sua linha e os seus lotes: a leste o solar avanca dez
    # metros para dentro do quintal e a cerca teve de recuar um metro; a oeste o
    # casarao de madeira OCUPA o fundo do lote do norte, e ali nao ha quintal
    # para cercar — cerca dentro de celeiro e o tipo de coisa que so aparece
    # depois, na tela.
    for sinal, x_cerca, lotes in ((-1.0, 17.5, (35.0, 25.5, -23.0)),
                                  (1.0, 18.5, (35.0, 25.5, -23.0, -35.0))):
        for z_centro in lotes:
            for k in range(-2, 3):
                adornos.append([CERCA, round(sinal * x_cerca, 2),
                                round(z_centro + k * 2.1, 2), 1.4, 90.0, True])

    # O mato encostado na cerca e no fundo das paredes, onde ninguem varre.
    fundos = [(-13.0, 33.0), (-14.0, 20.0), (-13.5, -18.0), (-14.5, -27.0),
              (13.5, 33.5), (14.0, 21.5), (13.0, -20.0), (14.5, -32.0),
              (-19.5, 30.0), (19.5, 27.0), (-19.5, -20.0), (19.5, -33.0),
              (-16.0, -8.0), (16.5, 12.5)]
    for i, (x, z) in enumerate(fundos):
        tex = CAPIM[i % len(CAPIM)] if i % 2 else FLORES[i % len(FLORES)]
        adornos.append([tex, x, z, 1.0 if i % 2 else 0.85,
                        float((i * 53) % 360), False])

    # Pedras miudas nos cantos de quintal, onde a enxada nunca chegou.
    for i, (x, z) in enumerate([(-15.0, 39.5), (15.5, 17.5), (-19.8, -28.0),
                                (19.0, -3.5), (-19.0, 8.0), (16.5, 40.0)]):
        adornos.append([PEDRAS[i % len(PEDRAS)], x, z,
                        0.6 + 0.12 * (i % 3), float((i * 71) % 360), False])

    # --- as pedras
    #
    # Pedra e o que da idade ao chao. Espalhei em TRES anEis, nao a esmo: as
    # grandes na borda da mata, onde o terreno comeca a descer e a pedra
    # aflorando explica por que ninguem construiu ali; as medias nos cantos
    # entre as casas e a orla; e nenhuma na calcada nem na rua, porque pedra no
    # caminho de quem anda e tropeco, nao paisagem.
    pedras = [
        # a orla, onde a vila acaba
        (PEDRAS[0], -28.0, 20.0, 1.25), (PEDRAS[1], 29.0, -24.0, 1.15),
        (PEDRAS[2], -30.0, -12.0, 1.3), (PEDRAS[0], 27.5, 4.0, 1.1),
        (PEDRAS[1], -31.5, 34.0, 1.2), (PEDRAS[2], 32.0, 26.0, 1.0),
        (PEDRAS[0], -29.0, -34.0, 1.35), (PEDRAS[1], 30.5, -37.0, 1.1),
        # os cantos, entre o fundo das casas e a mata
        (PEDRAS[2], -24.5, 13.5, 0.85), (PEDRAS[0], 25.0, 12.0, 0.8),
        (PEDRAS[1], -25.5, -16.0, 0.9), (PEDRAS[2], 24.5, -18.5, 0.75),
        # duas na beira do largo, marcando onde o gramado comeca
        (PEDRAS[0], 13.0, -2.0, 0.7), (PEDRAS[1], -12.5, -1.0, 0.65),
    ]
    for i, (tex, x, z, alt) in enumerate(pedras):
        adornos.append([tex, x, z, alt, float((i * 63) % 360), False])

    # --- os arbustos e o mato dos cantos
    #
    # O verde vai onde o pe nao passa: encostado no fundo das casas, no vao das
    # cercas, na dobra entre a travessa e a mata. E o que tira o ar de maquete
    # do gramado limpo, sem nunca entrar na frente de uma porta.
    moitas = [
        (-24.5, 24.0), (25.5, 22.0), (-26.0, -8.0), (29.0, -11.0),
        (-23.0, 36.0), (23.5, 38.0), (-24.0, -26.0), (25.0, -28.5),
        (-17.5, 15.5), (18.0, -16.5), (-18.5, -37.0), (17.5, 34.0),
    ]
    for i, (x, z) in enumerate(moitas):
        tex = CAPIM[i % len(CAPIM)] if i % 3 else FLORES[i % len(FLORES)]
        adornos.append([tex, x, z, 1.05 if i % 3 else 0.9,
                        float((i * 41) % 360), False])

    # --- a segunda passada: o gramado que sobrou
    #
    # A primeira rodada tratou fundo de casa e orla da mata e deixou de fora o
    # que o jogador mais ve: a faixa de grama ENTRE a calcada e o quintal. Vista
    # da camera de cima, era um tapete verde liso do tamanho de duas casas.
    #
    # O remedio nao e espalhar mais coisa por igual — e AGRUPAR. Mato nasce em
    # touceira e pedra vem acompanhada de pedrinha: tres coisas juntas leem como
    # canto de terreno, e as mesmas tres espalhadas leem como enfeite jogado.
    touceiras = [
        (-10.5, 30.0), (10.8, 29.0), (-11.0, 6.5), (11.2, 4.0),
        (-10.6, -19.5), (10.9, -24.0), (-12.0, 43.0), (12.2, 44.0),
        (-9.8, -43.0), (10.2, -44.5), (-13.8, 24.5), (13.6, 33.0),
    ]
    for i, (x, z) in enumerate(touceiras):
        adornos.append([CAPIM[i % len(CAPIM)], x, z, 1.05, float((i * 37) % 360), False])
        adornos.append([CAPIM[(i + 2) % len(CAPIM)], round(x + 1.1, 2),
                        round(z - 0.9, 2), 0.72, float((i * 91) % 360), False])
        adornos.append([FLORES[i % len(FLORES)], round(x - 0.9, 2),
                        round(z + 1.2, 2), 0.68, float((i * 53) % 360), False])

    for i, (x, z) in enumerate([(-15.6, 33.5), (12.6, 12.5), (-12.8, -10.0),
                                (14.6, -37.0), (-10.9, -30.0), (13.2, 21.0)]):
        adornos.append([PEDRAS[i % len(PEDRAS)], x, z, 0.78, float((i * 61) % 360), False])
        adornos.append([PEDRAS[(i + 1) % len(PEDRAS)], round(x + 0.85, 2),
                        round(z + 0.7, 2), 0.42, float((i * 113) % 360), False])

    return adornos


# ------------------------------------------------------------ ACORDELOT
#
# A cidade que o jogador ve depois da vila, e que precisa ser LIDA em vinte
# segundos: onde entrou, para onde a rua vai, onde e o centro. Tudo aqui serve a
# isso, e nada e simetrico por simetria.
#
# O eixo e o Z, como na vila e pelo mesmo motivo: e o eixo dos portais desta
# zona. Entra-se pelo sul, vindo da vila, e sai-se ao norte para a Capital.
#
#            etiqueta          modelo          altura  frente  fundo
CASAS_DA_CIDADE = {
    # Alturas e pegadas ampliadas juntas: a porta volta a ler como passagem
    # para um personagem de 1,75 m, sem o planejador deixar casas se cruzarem.
    "casa_alta":   ("medieval_house_1",  9.8,  3.29,  4.81),
    "casa_larga":  ("medieval_house_3",  8.8,  9.75,  4.27),
    "casa_pedra":  ("casa_pedra",        8.4,  8.45,  6.19),
    "casarao":     ("casarao_madeira",  10.0,  7.15, 12.95),
    "solar":       ("casa_solar",       11.0, 12.42, 12.18),
    "casa_taipa":  ("casa_taipa",        9.4,  5.06, 11.94),
    "casa_torre":  ("casa_torre",       13.5,  8.63, 11.07),
    "taverna":     ("taverna",          13.0,  7.75, 10.19),
}

# A rua da cidade e mais larga que a da vila — dez metros contra oito. A
# diferenca de escala e o que diz "aqui e maior" sem precisar de placa.
MEIA_RUA_CIDADE = 5.0
FACHADA_CIDADE = 9.0
PRACA_Z = 0.0
PRACA_RAIO = 17.0
LANE_CIDADE = 3.5
MURALHA_ACORDELOT = "muralha_texturizada"


def cidade_de_acordelot():
    """Acordelot ocupa a zona inteira, mas continua facil de ler.

    A rua sul-norte une os dois portais, a avenida oeste chega ao terceiro
    portal e as duas ruas de bairro dividem a cidade em quadras. A muralha fica
    a dez metros dos portais: quem troca de zona ja chega aos portoes, sem
    atravessar um campo vazio antes da cidade comecar.
    """
    pecas = []

    def por(nome, etiqueta, x, z, giro=0.0, escala=1.0):
        modelo = CASAS_DA_CIDADE[etiqueta][0]
        pecas.append(peca(nome, etiqueta, modelo, x, z, giro=giro, escala=escala))

    def prop(nome, alvo, x, z, giro=0.0, escala=1.0):
        tag, modelo = alvo
        pecas.append(peca(nome, tag, modelo, x, z, giro=giro, escala=escala))

    # 1. Muralha nos 63 m: quase na borda da zona. Sul e norte deixam abertura
    # central; oeste deixa a abertura do portal do Forjador; leste e fechado.
    for eixo in ("sul", "norte"):
        z = 63.0 if eixo == "sul" else -63.0
        for i, x in enumerate((-57.9, -23.3, 23.3, 57.9)):
            pecas.append(peca(f"muralha_{eixo}_{i}", "muralha", MURALHA_ACORDELOT,
                              x, z, giro=0.0))
    for i, z in enumerate((-52.0, -17.0, 18.0, 53.0)):
        pecas.append(peca(f"muralha_leste_{i}", "muralha", MURALHA_ACORDELOT,
                          63.0, z, giro=90.0))
    for i, z in enumerate((-57.9, -23.3, 23.3, 57.9)):
        pecas.append(peca(f"muralha_oeste_{i}", "muralha", MURALHA_ACORDELOT,
                          -63.0, z, giro=90.0))

    # 2. Torres que tornam as tres aberturas marcos visuais. Ficam recuadas em
    # relacao ao portal de zona (72 m): o jogador ganha um patio de chegada e
    # nao nasce com o portao fisico colado na camera.
    for eixo, z in (("sul", 50.0), ("norte", -50.0)):
        for sinal, lado in ((-1.0, "o"), (1.0, "l")):
            por(f"torre_{eixo}_{lado}", "casa_torre", sinal * 11.5, z,
                giro=(90.0 if sinal < 0 else 270.0))
    por("torre_oeste_s", "casa_torre", -50.0, 11.5, giro=180.0)
    por("torre_oeste_n", "casa_torre", -50.0, -11.5, giro=0.0)

    # 3. Eixo principal, da Vila do Caminho ao portal norte.
    oeste = [(38.0, "casa_pedra"), (16.0, "casa_taipa"),
             (-17.0, "casa_larga"), (-38.0, "casarao")]
    leste = [(38.0, "taverna"), (16.0, "casa_larga"),
             (-17.0, "casa_pedra"), (-38.0, "solar")]
    for lado, sinal, lotes in (("o", -1.0, oeste), ("l", 1.0, leste)):
        for i, (z, etiqueta) in enumerate(lotes):
            fundo = CASAS_DA_CIDADE[etiqueta][3]
            por(f"eixo_{lado}_{i}", etiqueta,
                sinal * (FACHADA_CIDADE + fundo * 0.5), z,
                giro=(90.0 if sinal < 0 else 270.0))

    # 4. Tres avenidas horizontais. Duas formam bairros completos; a central
    # liga a praca ao portao oeste. As casas olham para a rua, nunca ao acaso.
    padrao = ["casa_pedra", "casa_taipa", "casa_larga", "taverna",
              "casa_alta", "solar", "casarao"]
    for faixa, rua_z, linhas in (("sul", 30.0, (39.5, 22.5)),
                                 ("centro", 0.0, (11.5, -11.5)),
                                 ("norte", -31.0, (-23.5, -40.5))):
        xs = (-47.0, -30.0, 30.0, 47.0)
        for linha_i, casa_z in enumerate(linhas):
            for i, x in enumerate(xs):
                # A ponta oeste da avenida central e o patio do portao: as
                # duas torres ocupam esses lotes e precisam de espaco livre.
                if faixa == "centro" and x == -47.0:
                    continue
                etiqueta = padrao[(i + linha_i * 2 + int(abs(rua_z))) % len(padrao)]
                giro = 180.0 if casa_z > rua_z else 0.0
                por(f"bairro_{faixa}_{linha_i}_{i}", etiqueta, x, casa_z, giro=giro)

    # Oito lotes de borda fecham os quatro grandes vazios entre os bairros e a
    # muralha. Continuam orientados para as ruas internas e deixam os três
    # portões completamente livres.
    for nome, etiqueta, x, z, giro in (
            ("borda_sul_o", "casa_pedra", -20.5, 51.5, 180.0),
            ("borda_sul_l", "casa_alta", 20.5, 52.0, 180.0),
            ("borda_norte_o", "casa_larga", -21.0, -52.0, 0.0),
            ("borda_norte_l", "casa_pedra", 21.0, -51.5, 0.0),
            ("borda_oeste_s", "casa_taipa", -54.0, 32.0, 90.0),
            ("borda_oeste_n", "casa_alta", -54.0, -32.0, 90.0),
            ("borda_leste_s", "casa_larga", 54.0, 31.5, 270.0),
            ("borda_leste_n", "casarao", 53.5, -32.0, 270.0)):
        por(nome, etiqueta, x, z, giro=giro)

    # 5. PRACA IMPERIAL. Ela e o coracao da MESMA Acordelot, nao outra zona.
    # O eixo x=0 continua livre de sul a norte: quem entra pelo portao enxerga
    # a praca e consegue atravessa-la sem desviar de banco, poco ou carroca.
    # O poco texturizado ocupa um dos quadrantes como marco temporario; a futura
    # fonte imperial pode substitui-lo sem mudar a planta.
    prop("marco_praca_imperial", POCO, 8.5, 0.0, giro=200.0, escala=1.08)
    for nome, x, z, giro in (
            ("banco_imperial_so", -10.8, 8.0, 70.0),
            ("banco_imperial_se", 10.8, 8.0, 290.0),
            ("banco_imperial_no", -10.8, -8.0, 110.0),
            ("banco_imperial_ne", 10.8, -8.0, 250.0)):
        prop(nome, BANCO, x, z, giro=giro, escala=0.92)

    # Feira na borda oeste e abastecimento na borda leste. Sao grupos, nao
    # enfeites soltos: carroca + carga leem como comercio em funcionamento.
    for nome, alvo, x, z, giro, escala in (
            ("feira_carroca", CARROCA, -14.2, -4.5, 105.0, 0.9),
            ("feira_caixotes", CAIXOTES, -15.2, -1.8, 25.0, 0.85),
            ("feira_sacos", SACO, -13.8, -0.2, 330.0, 0.82),
            ("abastecimento_barris", BARRIS, 14.8, 6.0, 210.0, 0.82),
            ("abastecimento_caixas", CAIXOTES, 15.2, 8.2, 115.0, 0.78)):
        prop(nome, alvo, x, z, giro=giro, escala=escala)

    # 5b. Fundos habitados dos quarteiroes. O mapa ja tinha trinta predios,
    # mas entre uma fachada e a seguinte ainda havia grandes tapetes vazios.
    # Estes grupos ficam encostados nas construcoes e fora das vias: deposito
    # atras da taverna, carga junto das casas e carroca nos patios. Sao pontos
    # deliberados, nao distribuicao procedural.
    for nome, alvo, x, z, giro, escala in (
            ("patio_sul_o_carroca", CARROCA, -47.0, 47.0, 175.0, 0.88),
            ("patio_sul_o_caixas", CAIXOTES, -44.5, 46.2, 80.0, 0.82),
            ("patio_sul_o_sacos", SACO, -42.8, 46.8, 25.0, 0.78),
            ("patio_sul_l_barris", BARRIS, 46.5, 47.0, 205.0, 0.84),
            ("patio_sul_l_caixas", CAIXOTES, 43.8, 46.5, 105.0, 0.80),
            ("patio_sul_l_saco", SACO, 42.0, 47.2, 310.0, 0.76),
            ("patio_norte_o_barris", BARRIS, -47.0, -47.5, 30.0, 0.84),
            ("patio_norte_o_caixas", CAIXOTES, -44.3, -47.0, 135.0, 0.80),
            ("patio_norte_l_carroca", CARROCA, 47.0, -47.5, 350.0, 0.88),
            ("patio_norte_l_sacos", SACO, 44.0, -47.0, 70.0, 0.78),
            ("fundo_eixo_so_barris", BARRIS, -18.0, 38.5, 260.0, 0.82),
            ("fundo_eixo_so_caixas", CAIXOTES, -19.8, 39.5, 145.0, 0.78),
            ("fundo_eixo_sl_carroca", CARROCA, 19.0, 38.5, 185.0, 0.86),
            ("fundo_eixo_sl_saco", SACO, 21.0, 39.5, 20.0, 0.76),
            ("fundo_eixo_no_caixas", CAIXOTES, -18.5, -39.0, 55.0, 0.80),
            ("fundo_eixo_no_barris", BARRIS, -20.5, -38.5, 285.0, 0.82),
            ("fundo_eixo_nl_caixas", CAIXOTES, 19.0, -39.0, 220.0, 0.80),
            ("fundo_eixo_nl_sacos", SACO, 21.0, -38.0, 95.0, 0.76),
            ("beco_o_carroca", CARROCA, -54.0, 0.0, 90.0, 0.84),
            ("beco_o_caixotes", CAIXOTES, -53.0, 3.0, 15.0, 0.78),
            ("beco_l_barris", BARRIS, 53.0, 0.0, 180.0, 0.82),
            ("beco_l_sacos", SACO, 53.5, -2.2, 260.0, 0.76)):
        prop(nome, alvo, x, z, giro=giro, escala=escala)

    # Pequenos jardins internos quebram os grandes vazios entre telhado e
    # muralha. Pinheiro e usado porque tem textura, duas malhas e custo baixo.
    for i, (x, z) in enumerate(((-22.0, 48.5), (22.0, 48.5),
                                (-22.0, -49.0), (22.0, -49.0),
                                (-54.0, 18.0), (-54.0, -18.0),
                                (54.0, 18.0), (54.0, -18.0),
                                (-22.0, 18.0), (22.0, 18.0),
                                (-22.0, -18.0), (22.0, -18.0))):
        pecas.append(peca(f"jardim_interno_{i:02d}", "pinheiro", PINHEIRO,
                          x, z, giro=(i * 67) % 360,
                          escala=0.72 + (i % 3) * 0.07))

    # Props de trabalho agrupados por bairro, nao espalhados no gramado.
    for nome, alvo, x, z, giro in (
            ("oficina_barris", BARRIS, 37.0, -25.5, 210.0),
            ("oficina_caixotes", CAIXOTES, 39.0, -28.0, 95.0),
            ("oficina_carroca", CARROCA, 50.5, -25.0, 15.0),
            ("residencia_saco", SACO, -37.0, 24.0, 140.0),
            ("residencia_barris", BARRIS, -48.0, 25.0, 260.0),
            ("mercado_caixotes", CAIXOTES, 35.0, 5.5, 40.0)):
        prop(nome, alvo, x, z, giro=giro)

    # Fundos e laterais ocupados. Cada conjunto encosta numa construcao e conta
    # uma historia curta (estoque, entrega, quintal), em vez de tentar esconder
    # o vazio com dezenas de objetos aleatorios.
    for nome, alvo, x, z, giro, escala in (
            ("quintal_so_barris", BARRIS, -39.5, 47.5, 35.0, 0.88),
            ("quintal_so_caixas", CAIXOTES, -36.8, 48.0, 120.0, 0.82),
            ("quintal_se_carroca", CARROCA, 38.5, 48.5, 190.0, 0.9),
            ("quintal_se_sacos", SACO, 35.8, 47.5, 15.0, 0.8),
            ("quintal_no_caixas", CAIXOTES, -38.0, -48.5, 55.0, 0.85),
            ("quintal_no_barris", BARRIS, -35.5, -48.0, 280.0, 0.85),
            ("quintal_ne_carroca", CARROCA, 39.0, -48.0, 350.0, 0.9),
            ("quintal_ne_saco", SACO, 36.0, -47.5, 80.0, 0.8),
            ("rua_oeste_carga", CAIXOTES, -48.5, 30.5, 20.0, 0.82),
            ("rua_oeste_barris", BARRIS, -50.5, 28.5, 240.0, 0.82),
            ("rua_leste_carga", CAIXOTES, 49.5, 30.0, 200.0, 0.82),
            ("rua_leste_sacos", SACO, 51.0, 27.8, 95.0, 0.8),
            ("oficina_norte_barris", BARRIS, 39.0, -35.0, 150.0, 0.86),
            ("oficina_norte_caixas", CAIXOTES, 41.5, -35.5, 45.0, 0.82),
            ("residencia_norte_sacos", SACO, -39.0, -35.0, 300.0, 0.8)):
        prop(nome, alvo, x, z, giro=giro, escala=escala)

    # 6. Arvores dos dois lados da muralha. O lado de dentro suaviza pedra e
    # telhado; o de fora liga a cidade a floresta antes do portal carregar.
    arv_id = 0
    for z in (-48.0, -30.0, 28.0, 47.0):
        for x in (-72.0, -55.0, 55.0, 72.0):
            pecas.append(peca(f"arvore_muro_lateral_{arv_id}", "pinheiro", PINHEIRO,
                              x, z, giro=(arv_id * 61) % 360,
                              escala=0.9 + (arv_id % 3) * 0.08))
            arv_id += 1
    for x in (-48.0, -31.0, 31.0, 48.0):
        for z in (-72.0, -55.0, 55.0, 72.0):
            pecas.append(peca(f"arvore_muro_horizontal_{arv_id}", "pinheiro", PINHEIRO,
                              x, z, giro=(arv_id * 47) % 360,
                              escala=0.9 + (arv_id % 3) * 0.08))
            arv_id += 1

    # Pequenos bosques nos quatro cantos internos: fecham o fundo das quadras e
    # escondem a linha dura entre telhados e muralha, sem invadir as ruas.
    for x, z in ((-53.0, 44.0), (-44.0, 52.0), (53.0, 44.0), (44.0, 52.0),
                 (-53.0, -44.0), (-44.0, -52.0), (53.0, -44.0), (44.0, -52.0)):
        pecas.append(peca(f"arvore_canto_interno_{arv_id}", "pinheiro", PINHEIRO,
                          x, z, giro=(arv_id * 71) % 360,
                          escala=0.78 + (arv_id % 3) * 0.06))
        arv_id += 1

    # Sub-bosque em grupos curtos perto das copas, barato e com textura.
    for i, (x, z) in enumerate(((-56.0, 46.0), (56.0, 44.0), (-54.0, -46.0),
                                (54.0, -47.0), (-45.0, 55.0), (44.0, 55.0),
                                (-44.0, -55.0), (45.0, -55.0))):
        pecas.append(peca(f"cogumelo_muralha_{i}", "cogumelo", COGUMELO, x, z,
                          giro=(i * 83) % 360, escala=0.9 + (i % 3) * 0.1))

    return pecas, {
        "avenidas": 4,
        "aneis": [PRACA_RAIO],
        "so_com_textura": True,
        "vias": {
            "principal": [MEIA_RUA_CIDADE, 67.0],
            "largo": PRACA_RAIO,
            "travessas": [PRACA_Z, LANE_CIDADE + 1.0, 67.0],
            "secundarias": [30.0, -31.0, LANE_CIDADE, 55.0],
            # Rua de PEDRA. Na vila o chao e terra pisada; aqui e calcamento, e
            # e essa diferenca que diz ao jogador que ele mudou de lugar.
            "pedra": True,
        },
        "luzes": _postes_de_acordelot(),
        "tochas": _tochas_de_acordelot(),
        "adornos": _adornos_de_acordelot(),
    }


def _postes_de_acordelot():
    """Corredores de luz marcam os tres caminhos que levam a portais."""
    postes = []
    for z in (51.0, 29.0, 10.0, -18.0, -42.0):
        for sinal in (-1.0, 1.0):
            postes.append([round(sinal * 6.8, 2), z])
    for x in (-49.0, -29.0, 29.0, 49.0):
        postes.append([x, -5.2])
        postes.append([x, 5.2])
    return postes


def _tochas_de_acordelot():
    """Tochas nas fachadas que importam: portao, taverna e a casa da praca.

    Uma por marco, e so nos marcos. Tocha em toda porta vira parede de fogo e
    para de significar coisa alguma.
    """
    return [
        [-7.0, 50.0, 90.0, 2.5], [7.0, 50.0, 270.0, 2.5],
        [-7.0, -50.0, 90.0, 2.5], [7.0, -50.0, 270.0, 2.5],
        [-50.0, 7.0, 180.0, 2.5], [-50.0, -7.0, 0.0, 2.5],
        [9.0, 38.0, 270.0, 2.2], [-9.0, -38.0, 90.0, 2.2],
    ]


def _adornos_de_acordelot():
    """Cerca, mato e pedra — o mesmo vocabulario da vila, na escala da cidade.

    A regra que vale aqui e a que aprendemos la: nada na rua, nada na calcada,
    nada na frente de porta. E agrupado, porque tres coisas juntas leem como
    canto de terreno e as mesmas tres espalhadas leem como enfeite jogado.
    """
    adornos = []

    # Placas nas tres entradas.
    adornos += [[PLACA, 7.0, 58.0, 2.8, 270.0, True],
                [PLACA, -58.0, 7.0, 2.8, 0.0, True],
                [PLACA, 7.0, -58.0, 2.8, 270.0, True]]

    # Cercas curtas fecham quintais, sem formar outra muralha invisivel.
    for x, z, giro in ((-37.0, 47.0, 0.0), (38.0, 47.0, 0.0),
                       (-38.0, -48.0, 0.0), (38.0, -48.0, 0.0),
                       (-50.0, 16.0, 90.0), (50.0, -16.0, 90.0)):
        for k in range(-2, 3):
            dx = k * 2.1 if giro == 0.0 else 0.0
            dz = k * 2.1 if giro == 90.0 else 0.0
            adornos.append([CERCA, round(x + dx, 2), round(z + dz, 2),
                            1.4, giro, True])

    # Vegetacao agrupada nas faces interna e externa da muralha.
    touceiras = []
    for z in (-49.0, -29.0, 27.0, 48.0):
        touceiras += [(-69.0, z), (-57.0, z), (57.0, z), (69.0, z)]
    for x in (-48.0, -30.0, 30.0, 48.0):
        touceiras += [(x, -69.0), (x, -57.0), (x, 57.0), (x, 69.0)]
    # Cantos de quadra que ficariam grandes gramados lisos.
    touceiras += [(-21.0, 47.0), (21.0, 47.0), (-21.0, -48.0), (21.0, -48.0),
                   (-52.0, 25.0), (52.0, 25.0), (-52.0, -25.0), (52.0, -25.0)]
    for i, (x, z) in enumerate(touceiras):
        adornos.append([CAPIM[i % len(CAPIM)], x, z, 1.05, float((i * 37) % 360), False])
        adornos.append([CAPIM[(i + 1) % len(CAPIM)], round(x + 1.2, 2),
                        round(z - 1.0, 2), 0.7, float((i * 91) % 360), False])
        adornos.append([FLORES[i % len(FLORES)], round(x - 1.0, 2),
                        round(z + 1.3, 2), 0.68, float((i * 53) % 360), False])

    # Pedras nas bases externas da muralha, sempre com uma menor ao lado.
    for i, (x, z) in enumerate([(-70.0, 38.0), (70.0, 39.0), (-70.0, -39.0),
                                (70.0, -38.0), (-42.0, 70.0), (42.0, 70.0),
                                (-42.0, -70.0), (42.0, -70.0)]):
        adornos.append([PEDRAS[i % len(PEDRAS)], x, z, 0.85, float((i * 61) % 360), False])
        adornos.append([PEDRAS[(i + 1) % len(PEDRAS)], round(x + 0.9, 2),
                        round(z + 0.8, 2), 0.45, float((i * 113) % 360), False])

    return adornos


def cidade_radial(avenidas, aneis, raio_da_muralha, portoes, marcos, monumento=("monumento", "fonte", "fonte_musical", 1.6)):
    pecas = []
    if monumento:
        m_id, m_tag, m_model, m_scale = monumento
        pecas.append(peca(m_id, m_tag, m_model, 0, 0, escala=m_scale))

    ruas = [i * (360.0 / avenidas) for i in range(avenidas)]
    iluminar(pecas, 7.5, ruas[:min(4, avenidas)], "praca")

    for indice, (raio, por_quarteirao, paleta) in enumerate(aneis):
        anel_de_casas(pecas, f"anel{indice}", raio, por_quarteirao, ruas, paleta)

    for marco in marcos:
        ident, tag, modelo, angulo, raio, escala = marco[:6]
        y_off = marco[6] if len(marco) > 6 else 0.0
        rad = math.radians(angulo)
        pecas.append(peca(ident, tag, modelo,
                          math.cos(rad) * raio, math.sin(rad) * raio,
                          giro=270.0 - angulo, escala=escala, y=y_off))

    if raio_da_muralha > 0.0:
        muralha_circular(pecas, raio_da_muralha,
                         torres=max(8, avenidas * 2), portoes=portoes)

    # O verde entra por ultimo, quando ja se sabe onde as casas ficaram.
    raios_de_anel = [r for r, _, _ in aneis]
    if raios_de_anel:
        meio = [round((raios_de_anel[i] + raios_de_anel[i + 1]) * 0.5, 2)
                for i in range(len(raios_de_anel) - 1)]
        arborizar(pecas, ruas, meio or [raios_de_anel[0] * 0.6])
    ajardinar(pecas, ruas, aneis)

    raios = [r for r, _, _ in aneis]
    entre = [round((raios[i] + raios[i + 1]) * 0.5, 1) for i in range(len(raios) - 1)] if len(raios) > 1 else []
    if raios:
        entre.append(round(raios[-1] + 5.0, 1))
    return pecas, {"avenidas": avenidas, "aneis": entre[:3]}


CIDADES = {
    # 1. 🏰 Capital Imperial de Acordelot (col 0, row 0)
    "custom_1785869541494_557": dict(
        raio=52.0,
        planta=cidade_radial(
            avenidas=8,
            aneis=[
                (14.5, 2, NOBRES_E_MANSOES),
                (25.5, 3, COMERCIO_E_OFICINAS),
                (36.5, 4, CASAS_MEDIEVAIS)
            ],
            raio_da_muralha=49.0,
            portoes=[0.0, 90.0, 180.0, 270.0],
            marcos=[
                ("palacio_norte", "sobrado", "casa_nobre", 0.0, 36.0, 1.35),
                ("torre_real_leste", "torre", "torre_guarda", 90.0, 36.0, 1.3),
                ("mansao_sul", "casa_enxaimel_2", "medieval_house_3", 180.0, 36.0, 1.15),
                ("bastiao_oeste", "torre", "torre_guarda", 270.0, 36.0, 1.3),
                ("banca_mercado_1", "banca", "banca_verde", 38.0, 20.0, 1.0),
                ("banca_mercado_2", "banca", "banca_vermelha", 52.0, 20.0, 1.0),
                ("banca_mercado_3", "banca", "banca_feira", 128.0, 20.0, 1.0),
                ("estatua_leao_1", "estatua", "leao_sentado", 75.0, 10.0, 1.1),
                ("estatua_leao_2", "estatua", "leao_de_pe", 105.0, 10.0, 1.1),
                ("estatua_leao_3", "estatua", "leao_sentado", 255.0, 10.0, 1.1),
                ("estatua_leao_4", "estatua", "leao_de_pe", 285.0, 10.0, 1.1),
                ("poco_real", "poco", "poco", 225.0, 10.0, 1.0),
                ("carroca_mercador", "mobilia", "carroca", 310.0, 19.0, 1.0),
                ("barris_mercado", "mobilia", "barris", 325.0, 19.0, 1.0),
            ],
            monumento=("fonte_imperial", "fonte", "fonte_musical", 1.7)
        )
    ),

    # 2. 🛡️ Portões Reais & Fortaleza da Guarda (col 0, row 1)
    "custom_1785880661560_858": dict(
        # ACORDELOT. Deixou de ser a fortaleza radial gerada por formula: a
        # cidade principal do jogo precisa ser DESENHADA, porque o jogador tem
        # de entender onde entrou, para onde a rua vai e onde e o centro.
        raio=70.0,
        planta=cidade_de_acordelot()
    ),

    # 3. 🏘️ Vila do Caminho & Mercado do Vale (col 0, row 2)
    "custom_1785884200706_430": dict(
        # A VILA DO CAMINHO. Nao e cidade pequena — e outro desenho.
        #
        # Cidade cresce em anel em volta de uma praca. Vila de estrada cresce ao
        # longo da VIA, porque foi a via que a criou. O raio aqui e o do plato
        # plano da zona, para nenhuma casa cair em ladeira.
        raio=44.0,
        planta=vila_da_estrada()
    ),

    # 4. 🎼 Salão do Forjador — Altar das Escalas (col -1, row 1)
    "custom_1786501580114_289": dict(
        raio=28.0,
        planta=cidade_radial(
            avenidas=4,
            aneis=[
                (12.0, 2, COMERCIO_E_OFICINAS),
                (20.0, 3, CASAS_MEDIEVAIS)
            ],
            raio_da_muralha=0.0,
            portoes=[],
            marcos=[
                ("grande_forja", "oficina_ferreiro", "oficina_ferreiro", 45.0, 18.0, 1.2),
                ("fundicao_sul", "oficina_ferreiro", "oficina_ferreiro", 225.0, 18.0, 1.1),
                ("deposito_barris", "mobilia", "barris", 135.0, 9.0, 1.0),
                ("carroca_minerios", "mobilia", "carroca", 315.0, 9.0, 1.0),
            ],
            monumento=("altar_das_escalas", "fonte", "fonte_musical", 1.4)
        )
    ),

    # 5. ⛵ Vila Ribeirinha — Enseada do Lago (col 4, row -1)
    "custom_1786572518911_723": dict(
        raio=34.0,
        planta=cidade_radial(
            avenidas=4,
            aneis=[
                (13.0, 2, CHALES_E_CAMPO),
                (22.0, 3, CASAS_MEDIEVAIS)
            ],
            raio_da_muralha=0.0,
            portoes=[],
            marcos=[
                ("moinho_d_agua", "moinho", "moinho", 45.0, 24.0, 1.15),
                ("ponte_pedra_norte", "ponte_pedra", "ponte_pedra", 0.0, 25.0, 1.1),
                ("ponte_madeira_sul", "ponte_madeira", "ponte_madeira", 180.0, 25.0, 1.1),
                ("mercado_peixes_1", "banca", "banca_verde", 130.0, 8.5, 1.0),
                ("mercado_peixes_2", "banca", "banca_feira", 150.0, 8.5, 1.0),
                ("barris_cais", "mobilia", "barris", 230.0, 8.5, 1.0),
            ],
            monumento=("fonte_dos_pescadores", "fonte", "fonte_praca", 1.3)
        )
    ),

    # 6. ⛰️ Cidadela da Serra & Forte dos Ventos (col 1, row -3)
    "custom_1786572340509_998": dict(
        raio=36.0,
        planta=cidade_radial(
            avenidas=4,
            aneis=[
                (13.0, 2, NOBRES_E_MANSOES),
                (23.0, 3, CASAS_MEDIEVAIS)
            ],
            raio_da_muralha=33.0,
            portoes=[90.0, 270.0],
            marcos=[
                ("torre_vigia_norte", "torre", "torre_guarda", 0.0, 28.0, 1.35),
                ("torre_vigia_sul", "torre", "torre_guarda", 180.0, 28.0, 1.35),
                ("forja_forte", "oficina_ferreiro", "oficina_ferreiro", 45.0, 18.0, 1.1),
                ("estandarte_forte_1", "estandarte", "estandarte_agudo", 80.0, 9.0, 1.0),
                ("estandarte_forte_2", "estandarte", "estandarte_grave", 100.0, 9.0, 1.0),
            ],
            monumento=("farol_da_serra", "torre", "torre_redonda", 1.5)
        )
    ),

    # 7. ✦ Santuário das Notas Sagradas (col 0, row -3)
    "notas_sagradas": dict(
        raio=32.0,
        planta=cidade_radial(
            avenidas=8,
            aneis=[
                (15.0, 1, ["crystal_cluster_1787078933118"])
            ],
            raio_da_muralha=0.0,
            portoes=[],
            marcos=[
                ("cristal_monolito_0", "crystal", "crystal_cluster_1787078933118", 0.0, 24.0, 1.8),
                ("cristal_monolito_1", "crystal", "crystal_cluster_1787078933118", 45.0, 24.0, 1.8),
                ("cristal_monolito_2", "crystal", "crystal_cluster_1787078933118", 90.0, 24.0, 1.8),
                ("cristal_monolito_3", "crystal", "crystal_cluster_1787078933118", 135.0, 24.0, 1.8),
                ("cristal_monolito_4", "crystal", "crystal_cluster_1787078933118", 180.0, 24.0, 1.8),
                ("cristal_monolito_5", "crystal", "crystal_cluster_1787078933118", 225.0, 24.0, 1.8),
                ("cristal_monolito_6", "crystal", "crystal_cluster_1787078933118", 270.0, 24.0, 1.8),
                ("cristal_monolito_7", "crystal", "crystal_cluster_1787078933118", 315.0, 24.0, 1.8),
                ("lampiao_sagrado_1", "lampiao", "lampiao", 22.5, 9.0, 1.0),
                ("lampiao_sagrado_2", "lampiao", "lampiao", 112.5, 9.0, 1.0),
                ("lampiao_sagrado_3", "lampiao", "lampiao", 202.5, 9.0, 1.0),
                ("lampiao_sagrado_4", "lampiao", "lampiao", 292.5, 9.0, 1.0),
            ],
            monumento=("altar_harmonia", "fonte", "fonte_musical", 1.8)
        )
    ),
}


def main():
    destino = os.path.join(RAIZ, "data", "city_layouts.json")
    anterior = {}
    if os.path.exists(destino):
        with open(destino) as arquivo_anterior:
            anterior = json.load(arquivo_anterior)
    # Nesta etapa so a Vila do Caminho e Acordelot foram redesenhadas. Os
    # layouts radiais antigos usam hash do processo e mudariam de lugar a cada
    # execucao mesmo sem terem sido pedidos; preserva-los impede uma alteracao
    # acidental nas outras cinco zonas.
    alvos = {"custom_1785880661560_858", "custom_1785884200706_430"}

    saida = {
        "_nota": ("GERADO por .tools/planejar_cidades.py — nao editar a mao, o "
                  "proximo run sobrescreve. E plano radial, nao sorteio: praca no "
                  "centro, avenidas em raio, aneis concentricos, e o quarteirao "
                  "ocupando a fatia entre duas avenidas. Mexer no desenho e mexer "
                  "no script."),
        "pracas": {}, "layouts": {},
    }
    for ident, cidade in CIDADES.items():
        if (ident not in alvos and
                ident in anterior.get("pracas", {}) and
                ident in anterior.get("layouts", {})):
            saida["pracas"][ident] = anterior["pracas"][ident]
            saida["layouts"][ident] = anterior["layouts"][ident]
            print(f'{ident:26s}  preservada sem alteracao')
            continue
        pecas, geometria = cidade["planta"]
        saida["pracas"][ident] = {
            "raio": cidade["raio"],
            "avenidas": geometria["avenidas"],
            "aneis": geometria["aneis"]
        }
        # O desenho viario explicito, quando a planta tem um. E o que o shader
        # do chao usa para pintar a rua; sem ele a via e so a ausencia de casa.
        if "vias" in geometria:
            saida["pracas"][ident]["vias"] = geometria["vias"]
        # O GUARDA DOS PORTOES. Nao entra na planta da cidade porque nao e
        # construcao: gente entra pela lista de npcs, e a lista mora na praca.
        # Fixo, com "True" no sexto campo — quem guarda um portao nao passeia.
        if ident == "custom_1785880661560_858":
            saida["pracas"][ident]["npcs"] = [
                ["renaldo", 2.6, 48.0, 190.0, "renaldo_portao", True]]

        if geometria.get("so_com_textura"):
            saida["pracas"][ident]["so_com_textura"] = True
        # As tochas e a decoracao da povoacao. Moram na praca e nao na lista de
        # pecas porque nao sao modelos 3D: sao luz e estampa recortada, e quem
        # os monta no construtor e outro caminho.
        for chave in ("luzes", "tochas", "adornos", "npcs"):
            if geometria.get(chave):
                saida["pracas"][ident][chave] = geometria[chave]
        saida["layouts"][ident] = pecas
        alcance = max(math.hypot(*p["position"]) for p in pecas)
        print(f'{ident:26s}  {len(pecas):3d} pecas  alcance {alcance:4.1f}m  '
              f'praca {cidade["raio"]:4.1f}m  '
              f'{geometria["avenidas"]} avenidas, aneis {geometria["aneis"]}')

    with open(destino, "w") as arquivo:
        json.dump(saida, arquivo, ensure_ascii=False, indent=1)
    print(f"Sucesso: {len(CIDADES)} cidades e marcos gravados em data/city_layouts.json")


if __name__ == "__main__":
    main()
