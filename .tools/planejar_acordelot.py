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


def prop(tag, modelo, x, z, giro=0):
    return {"tag": tag, "model": M + modelo + ".glb",
            "position": [round(x, 2), round(z, 2)], "rotation": giro}


def fileiras():
    """As seis fileiras de fachada, mais as quatro casas da avenida."""
    pecas = []
    semente = 0

    # Giro 0 olha para +z e giro 180 para -z; 90 olha para +x e 270 para -x.
    # `lado` diz qual borda da caixa encosta na linha: -1 e a de maior
    # coordenada (casa antes da rua), +1 a de menor (casa depois da rua).
    fileiras_z = [
        # rua z = 0 (travessa, dentro do largo)
        (-FACHADA_TRAVESSA, 0, -1.0, (-55, -37, -19, 19, 37, 55)),
        (FACHADA_TRAVESSA, 180, 1.0, (-55, -37, -19, 19, 37, 55)),
        # rua z = -44 (bairro norte)
        (-RUA_BAIRRO + FACHADA_BAIRRO, 180, 1.0, (-55, -37, -19, 19, 37, 55)),
        (-RUA_BAIRRO - FACHADA_BAIRRO, 0, -1.0, (-55, -37, 37, 55)),
        # rua z = +44 (bairro sul)
        (RUA_BAIRRO - FACHADA_BAIRRO, 0, -1.0, (-55, -37, -19, 19, 37, 55)),
        (RUA_BAIRRO + FACHADA_BAIRRO, 180, 1.0, (-55, -37, 37, 55)),
    ]
    for linha, giro, lado, xs in fileiras_z:
        for x in xs:
            # A coordenada em z e so o ponto de partida: quem manda e a linha
            # de fachada, e o construtor recalcula esta casa pela caixa dela.
            pecas.append(casa(semente, x, linha + (6.0 * lado), giro,
                              ("z", linha, lado)))
            semente += 3

    # As quatro casas que olham para a avenida, nas pontas norte e sul — os
    # unicos trechos do eixo central onde sobra fundo de quarteirao.
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

    with open(DESTINO, "w") as arquivo:
        json.dump(dados, arquivo, ensure_ascii=False, indent=1)
    print("%s: %d pecas, %d postes" % (
        IDENT, len(dados["layouts"][IDENT]), len(praca["luzes"])))


if __name__ == "__main__":
    main()
