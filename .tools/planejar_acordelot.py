#!/usr/bin/env python3
"""Redesenha o centro de Acordelot em data/urban_refinement.json.

A planta anterior era uma GRADE DE OBJETOS, nao uma cidade: vinte e quatro
casas em x = -52, -34, -16, 16, 34, 52 e z = -50, -18, 18, 50, com giro
alternando 0, 90, 180 e 270 dentro da mesma fileira. As ruas pintadas no chao
passavam em z = 0 e z = +-34 — ou seja, nenhuma casa fazia esquina com rua
nenhuma: cada fileira ficava sedeze metros longe do calcamento, de lado ou de
costas para ele. Dai a leitura de "casas jogadas no campo" mesmo com a rua
desenhada por baixo.

O desenho novo parte da rua, e nao do desenho da grade:

1. TRES RUAS E UM LARGO. A avenida corre em x = 0 de portal a portal, a
   travessa cruza em z = 0 dentro do largo, e duas ruas de bairro passam em
   z = +-44. Toda casa pertence a uma delas.
2. FACHADA NA LINHA, dos dois lados. Cada rua recebe duas fileiras de frente
   para ela. O alinhamento vai no campo "fachada" e quem resolve e o
   construtor, medindo a caixa da malha JA GIRADA — a tabela de fundo nao
   serve, porque casa virada 90 graus apresenta a largura para a rua.
3. NADA DE COSTAS PARA A AVENIDA. As quatro casas das pontas olham para o eixo
   central, senao a rua mais importante da cidade seria ladeada so por muros
   laterais de casas de esquina.
4. O MIOLO DO QUARTEIRAO E QUINTAL. Carroca, barris e caixotes ficam atras das
   fileiras, onde ninguem passa — e e isso que faz o fundo parecer usado em vez
   de sobra de terreno.

Rodar: python3 .tools/planejar_acordelot.py
"""
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "data", "urban_refinement.json")
IDENT = "acordelot_centro_v2"
M = "res://models/"

# A PEGADA REAL DE CADA CASA, em metros, DEPOIS de normalizada pela altura-alvo
# da tabela ALTURA_POR_TAG do zone_builder. Medida no proprio GLB, nao chutada:
# e ela que decide o espacamento do quarteirao. Casa girada 90 graus apresenta a
# LARGURA para a rua na direcao do eixo da rua, por isso as duas medidas.
#   tag: (largura em x local, fundo em z local)
PEGADA = {
    "casa_pedra": (8.46, 6.20),
    "casa_larga": (9.75, 4.27),
    "casa_alta": (3.29, 4.82),
    "solar": (12.43, 12.17),
    "casa_taipa": (5.06, 11.89),
    "casarao": (7.15, 12.95),
    "taverna": (7.74, 10.15),
}
MODELO = {
    "casa_pedra": "casa_pedra", "casa_larga": "medieval_house_3",
    "casa_alta": "medieval_house_1", "solar": "casa_solar",
    "casa_taipa": "casa_taipa", "casarao": "casarao_madeira",
    "taverna": "taverna",
}
# Quanto de quintal entre duas casas da mesma fileira. Dois metros e meio le
# como vila apertada de verdade; abaixo disso as paredes se encostam e acima de
# quatro volta a virar casa solta no campo.
VAO_ENTRE_CASAS = 2.5

# A malha viaria, em metros. Meia-largura de cada via e alcance dela.
MEIA_AVENIDA = 6.0
MEIA_TRAVESSA = 5.5
MEIA_BAIRRO = 4.0
LARGO = 15.0
RUA_BAIRRO = 46.0

# Recuo da parede da frente ate o EIXO da rua. Some a meia-largura e sobra a
# calcada: tres metros na travessa, cinco nas ruas de bairro.
FACHADA_TRAVESSA = 9.0
FACHADA_BAIRRO = 9.0
FACHADA_AVENIDA = 10.0

# Sete construcoes texturizadas, distribuidas para nao repetir vizinho.
CASAS = [
    ("casa_pedra", "casa_pedra"),
    ("casa_larga", "medieval_house_3"),
    ("casa_alta", "medieval_house_1"),
    ("solar", "casa_solar"),
    ("casa_taipa", "casa_taipa"),
    ("casarao", "casarao_madeira"),
    ("taverna", "taverna"),
]


def casa(nome_indice, x, z, giro, fachada):
    etiqueta, modelo = CASAS[nome_indice % len(CASAS)]
    return {
        "tag": etiqueta,
        "model": M + modelo + ".glb",
        "position": [round(x, 2), round(z, 2)],
        "rotation": giro,
        "fachada": [fachada[0], round(float(fachada[1]), 2), float(fachada[2])],
    }


def casa_do_quarteirao(tag, x, z, giro, fachada):
    """Uma casa da vila, com a linha de fachada que o construtor vai respeitar."""
    return {
        "tag": tag,
        "model": M + MODELO[tag] + ".glb",
        "position": [round(x, 2), round(z, 2)],
        "rotation": giro,
        "fachada": [fachada[0], round(float(fachada[1]), 2), float(fachada[2])],
    }


def fileira(tags, eixo, linha, lado, giro, inicio, sentido):
    """UM QUARTEIRAO: casas ombro a ombro ao longo de uma rua.

    O passo entre duas casas sai da PEGADA das duas, nao de um numero fixo: e o
    que permite encostar um solar de 12,4 m num casebre de 3,3 m sem deixar
    buraco de gramado no meio nem enfiar parede dentro de parede. Era esse
    numero fixo — vinte e dois metros entre casas — que fazia a vila parecer
    duas fileiras de casas isoladas em vez de rua.

    `eixo` diz se a rua corre em x ou em z; `linha` e a coordenada da fachada;
    `lado` diz de que lado da linha o lote esta.
    """
    pecas = []
    andar = float(inicio)
    anterior = None
    for tag in tags:
        largura = PEGADA[tag][0] if eixo == "z" else PEGADA[tag][0]
        if anterior is not None:
            andar += sentido * ((anterior + largura) * 0.5 + VAO_ENTRE_CASAS)
        if eixo == "z":
            # Rua corre em x; a fachada e uma linha em z.
            pecas.append(casa_do_quarteirao(tag, andar, linha + 6.0 * lado, giro,
                                            ("z", linha, lado)))
        else:
            # Rua corre em z; a fachada e uma linha em x.
            pecas.append(casa_do_quarteirao(tag, linha + 6.0 * lado, andar, giro,
                                            ("x", linha, lado)))
        anterior = largura
    return pecas


def prop(tag, modelo, x, z, giro=0):
    return {"tag": tag, "model": M + modelo + ".glb",
            "position": [round(x, 2), round(z, 2)], "rotation": giro}


def fileiras():
    """As seis fileiras de fachada, mais as quatro casas da avenida.

    O PASSO SAI DA PEGADA, nao de uma regua. As posicoes eram fixas em
    x = -55, -37, -19, 19, 37 e 55: dezoito metros entre vizinhos para casas de
    sete metros e meio de largura media, ou seja, dez metros de gramado entre
    uma parede e outra em toda a capital. Uma cidade nao tem lote vago a cada
    casa. Com o passo saindo da largura das duas vizinhas mais um vao de 2,5 m,
    cabe mais gente na mesma rua e a fileira le como quarteirao.

    Os quarteiroes comecam em |x| = 14 porque a avenida tem 6 m de meia largura
    e o largo tem raio 15: adiante disso a casa estaria em cima da praca.
    """
    pecas = []

    # (tags a oeste, tags a leste, linha da fachada, lado, giro, |x| inicial)
    #
    # O |x| INICIAL NAO E O MESMO EM TODA FILEIRA. As duas de fora, em z = +-55,
    # correm ao lado das quatro casas que olham para a avenida, plantadas em
    # x = +-16 e z = +-58. Comecando as duas em 14, a primeira casa da fileira
    # caia em cima da casa da esquina — medido, ate 4,7 m de parede dentro de
    # parede. Elas comecam mais para fora e a esquina fica livre.
    #
    # As duas da travessa comecam em 20 pelo mesmo tipo de motivo: o largo tem
    # raio 15, e uma casa larga plantada em 14 punha a quina de dentro em cima
    # do calcamento da praca.
    quarteiroes = [
        # travessa z = 0, dentro do largo
        (["casa_pedra", "casa_alta", "casa_larga", "casa_taipa"],
         ["taverna", "casarao", "casa_pedra", "casa_alta"], -FACHADA_TRAVESSA, -1.0, 0, 20.0),
        (["casarao", "casa_larga", "casa_pedra", "casa_alta"],
         ["casa_taipa", "solar", "casa_larga"], FACHADA_TRAVESSA, 1.0, 180, 20.0),
        # rua de bairro norte, z = -46
        (["casa_alta", "casa_pedra", "taverna", "casa_larga"],
         ["casa_larga", "casa_taipa", "casarao", "casa_pedra"],
         -RUA_BAIRRO + FACHADA_BAIRRO, 1.0, 180, 14.0),
        (["casa_taipa", "casa_larga", "casa_pedra"],
         ["casa_pedra", "casa_alta", "solar"],
         -RUA_BAIRRO - FACHADA_BAIRRO, -1.0, 0, 27.0),
        # rua de bairro sul, z = +46
        (["solar", "casa_pedra", "casa_larga", "casa_alta"],
         ["casa_alta", "taverna", "casa_taipa", "casa_larga"],
         RUA_BAIRRO - FACHADA_BAIRRO, -1.0, 0, 14.0),
        (["casa_larga", "casa_alta", "casa_pedra"],
         ["casarao", "casa_larga", "casa_pedra"],
         RUA_BAIRRO + FACHADA_BAIRRO, 1.0, 180, 27.0),
    ]
    for oeste, leste, linha, lado, giro, inicio in quarteiroes:
        pecas += fileira(oeste, "z", linha, lado, giro, -inicio, -1)
        pecas += fileira(leste, "z", linha, lado, giro, inicio, 1)

    # As quatro casas que olham para a avenida, nas pontas norte e sul — os
    # unicos trechos do eixo central onde sobra fundo de quarteirao.
    semente = 0
    for z in (-58.0, 58.0):
        for sinal in (-1.0, 1.0):
            giro = 90 if sinal < 0 else 270
            pecas.append(casa(semente, sinal * (FACHADA_AVENIDA + 6.0), z, giro,
                              ("x", sinal * FACHADA_AVENIDA, sinal)))
            semente += 2
    return pecas


def quintais():
    """Carga e mobilia no miolo dos quarteiroes, nunca na calcada."""
    pecas = [prop("poco", "poco_vila", 0.0, 0.0, 0)]
    for x, z, giro in ((-11.5, 11.5, 315), (11.5, 11.5, 45),
                       (-11.5, -11.5, 225), (11.5, -11.5, 135)):
        pecas.append(prop("banco", "banco_vila", x, z, giro))
    for tag, modelo, x, z, giro in (
            ("carroca", "carroca_vila", -44.0, -27.0, 100),
            ("barris", "barris_vila", -41.0, -25.5, 25),
            ("caixotes", "caixotes_vila", 43.0, -27.0, 200),
            ("barris", "barris_vila", 26.0, 27.0, 310),
            ("caixotes", "caixotes_vila", -26.0, 27.0, 70),
            ("carroca", "carroca_vila", 45.0, 26.5, 280)):
        pecas.append(prop(tag, modelo, x, z, giro))
    # Pinheiros fecham os quatro cantos, fora de qualquer fileira.
    for x in (-64.0, 64.0):
        for z in (-64.0, 64.0):
            pecas.append(prop("pinheiro", "pine_tree", x, z, 0))
    return pecas


def luzes():
    """Corredor de luz nas tres ruas, sempre no mesmo recuo do eixo."""
    pontos = []
    for z in (-60, -36, -12, 12, 36, 60):
        pontos += [[-8, z], [8, z]]
    for x in (-46, -24, 24, 46):
        pontos += [[x, -7], [x, 7]]
    for z_rua in (-RUA_BAIRRO, RUA_BAIRRO):
        for x in (-30, 30):
            pontos += [[x, int(z_rua - 5)], [x, int(z_rua + 5)]]
    return pontos


# ---------------------------------------------------------------------------
# AS TRES VILAS
#
# A planta anterior delas era literalmente duas colunas de casas em x = +-15 e
# +-16, uma a cada vinte e dois metros ao longo da avenida. Medido: vizinho mais
# proximo a 22 m e 285 m2 de terreno por casa. Isso nao e vila, e um corredor de
# casas isoladas — e era a queixa exata de "enormes terrenos vazios entre uma
# casa e outra".
#
# Aqui cada vila tem NUCLEOS: quarteiroes curtos de tres a quatro casas ombro a
# ombro numa rua, com quintal atras, e vazio de verdade entre um nucleo e outro.
# O vazio deixa de ser terreno abandonado e vira o campo em volta do povoado.
# ---------------------------------------------------------------------------

VILAS = {
    "vila_caminho_v2": {
        "raio": 48.0,
        "vias": {"principal": [4.5, 50.0], "largo": 10.0,
                 "travessas": [0.0, 4.0, 42.0], "pedra": False},
        # (tags, eixo, linha da fachada, lado, giro, x/z inicial, sentido)
        "quarteiroes": [
            (["casa_pedra", "casa_alta", "casa_larga"], "z", -9.0, -1.0, 0, -14.0, -1),
            (["taverna", "casa_taipa"], "z", -9.0, -1.0, 0, 14.0, 1),
            (["casarao", "casa_pedra"], "z", 9.0, 1.0, 180, -14.0, -1),
            (["casa_larga", "solar"], "z", 9.0, 1.0, 180, 14.0, 1),
            (["casa_taipa", "casa_alta"], "x", -10.0, -1.0, 90, -30.0, -1),
            (["casa_larga"], "x", 10.0, 1.0, 270, 30.0, 1),
        ],
        "quintais": [("carroca", -26.0, -20.0, 100), ("barris", -23.0, -18.5, 25),
                     ("caixotes", 25.0, -19.0, 200), ("barris", 24.0, 20.0, 310),
                     ("caixotes", -25.0, 21.0, 70), ("banco", -8.5, 8.5, 315),
                     ("banco", 8.5, 8.5, 45)],
        "pinheiros": [(-40.0, -40.0), (40.0, -40.0), (-40.0, 40.0), (40.0, 40.0)],
        "npcs": [["mirella", 6.2, -8.0, 250.0, "mirella_boas_vindas"]],
    },
    "mercado_caminho_v2": {
        "raio": 48.0,
        "vias": {"principal": [5.0, 48.0], "largo": 13.0,
                 "travessas": [0.0, 5.0, 44.0], "pedra": False},
        "quarteiroes": [
            (["taverna", "casa_larga", "casa_alta"], "z", -11.0, -1.0, 0, -17.0, -1),
            (["casa_pedra", "casa_taipa"], "z", -11.0, -1.0, 0, 17.0, 1),
            (["casarao", "casa_pedra"], "z", 11.0, 1.0, 180, -17.0, -1),
            (["solar", "casa_larga"], "z", 11.0, 1.0, 180, 17.0, 1),
            (["casa_alta", "casa_taipa"], "x", -11.0, -1.0, 90, -30.0, -1),
        ],
        "quintais": [("carroca", -27.0, -21.0, 110), ("carroca", 27.0, 21.0, 290),
                     ("barris", -24.0, -19.0, 30), ("caixotes", 25.0, -20.0, 210),
                     ("banco", -10.0, 10.0, 315), ("banco", 10.0, 10.0, 45)],
        "pinheiros": [(-40.0, -38.0), (40.0, -38.0), (-40.0, 38.0), (40.0, 38.0)],
        "npcs": [],
    },
    "arredores_v2": {
        "raio": 52.0,
        "vias": {"principal": [4.5, 58.0], "largo": 10.0,
                 "travessas": [8.0, 4.0, 44.0], "pedra": False},
        # Povoado de fora dos muros: dois nucleos pequenos e uma granja isolada,
        # que e o que "arredores" quer dizer — nao uma terceira vila igual.
        "quarteiroes": [
            (["casa_pedra", "casa_alta", "casa_larga"], "z", -1.0, -1.0, 0, -15.0, -1),
            (["casarao", "casa_taipa"], "z", -1.0, -1.0, 0, 15.0, 1),
            (["casa_larga", "casa_pedra"], "z", 17.0, 1.0, 180, -15.0, -1),
            (["solar"], "z", 17.0, 1.0, 180, 15.0, 1),
            (["casa_alta", "casa_taipa"], "x", -10.0, -1.0, 90, -34.0, -1),
        ],
        "quintais": [("carroca", -26.0, -26.0, 95), ("barris", -23.0, -24.0, 20),
                     ("caixotes", 26.0, -25.0, 205), ("carroca", 27.0, 30.0, 285),
                     ("banco", -9.0, 26.0, 315), ("banco", 9.0, 26.0, 45)],
        "pinheiros": [(-42.0, -42.0), (42.0, -42.0), (-42.0, 44.0), (42.0, 44.0)],
        "npcs": [],
    },
}


def montar_vila(dados):
    pecas = []
    for tags, eixo, linha, lado, giro, inicio, sentido in dados["quarteiroes"]:
        pecas += fileira(tags, eixo, linha, lado, giro, inicio, sentido)
    for tag, x, z, giro in dados["quintais"]:
        pecas.append(prop(tag, tag.replace("carroca", "carroca_vila")
                          .replace("barris", "barris_vila")
                          .replace("caixotes", "caixotes_vila")
                          .replace("banco", "banco_vila"), x, z, giro))
    pecas.append(prop("poco", "poco_vila", 0.0, 0.0, 0))
    for x, z in dados["pinheiros"]:
        pecas.append(prop("pinheiro", "pine_tree", x, z, 0))
    return pecas


def luzes_da_vila(dados):
    """Postes ao longo das ruas que a vila realmente tem."""
    vias = dados["vias"]
    meia = vias["principal"][0]
    alcance = vias["principal"][1]
    pontos = []
    z = -alcance + 12.0
    while z <= alcance - 12.0:
        if abs(z) > vias["largo"] - 2.0:
            pontos += [[round(-meia - 2.5, 1), round(z, 1)],
                       [round(meia + 2.5, 1), round(z, 1)]]
        z += 22.0
    tz, tmeia, talcance = vias["travessas"]
    x = -talcance + 14.0
    while x <= talcance - 14.0:
        if abs(x) > vias["largo"] - 2.0:
            pontos += [[round(x, 1), round(tz - tmeia - 2.5, 1)],
                       [round(x, 1), round(tz + tmeia + 2.5, 1)]]
        x += 24.0
    return pontos


def main():
    with open(DESTINO) as arquivo:
        dados = json.load(arquivo)

    praca = dados["pracas"][IDENT]
    praca["raio"] = 70.0
    praca["so_com_textura"] = True
    praca["vias"] = {
        "principal": [MEIA_AVENIDA, 70.0],
        "largo": LARGO,
        "travessas": [0.0, MEIA_TRAVESSA, 70.0],
        "secundarias": [RUA_BAIRRO, -RUA_BAIRRO, MEIA_BAIRRO, 64.0],
        "pedra": True,
    }
    praca["luzes"] = luzes()
    dados["layouts"][IDENT] = fileiras() + quintais()

    for ident, vila in VILAS.items():
        p = dados["pracas"].setdefault(ident, {})
        p["raio"] = vila["raio"]
        p["so_com_textura"] = True
        p["vias"] = vila["vias"]
        p["luzes"] = luzes_da_vila(vila)
        p["npcs"] = vila["npcs"]
        dados["layouts"][ident] = montar_vila(vila)
        print("%s: %d pecas, %d postes" % (ident, len(dados["layouts"][ident]),
                                           len(p["luzes"])))

    with open(DESTINO, "w") as arquivo:
        json.dump(dados, arquivo, ensure_ascii=False, indent=1)
    print("%s: %d pecas, %d postes" % (
        IDENT, len(dados["layouts"][IDENT]), len(praca["luzes"])))


if __name__ == "__main__":
    main()
