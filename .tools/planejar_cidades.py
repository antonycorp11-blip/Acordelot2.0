#!/usr/bin/env python3
"""Desenha as plantas urbanas do Acordelot e grava data/city_layouts.json.

NAO e sorteio. E um plano radial, o mesmo desenho da referencia: praca redonda no
centro, avenidas saindo dela como raios, aneis concentricos cruzando os raios, e
os quarteiroes ocupando as fatias entre um raio e outro. Cada peca sai de uma
conta — angulo, anel, recuo — e a mesma cidade nasce igual em toda maquina.

Por que gerar por regra em vez de digitar coordenada a coordenada: uma cidade
radial de tres aneis tem umas cem construcoes, e digitar cem posicoes a mao
produz erro de alinhamento que o olho pega na hora. A regra garante que toda casa
de um anel esteja na MESMA distancia do centro e recuada o MESMO tanto da rua —
que e exatamente o que faz um traçado parecer planejado.

O que muda de cidade para cidade: quantos raios, quantos aneis, se ha muralha, e
quais marcos ocupam os pontos nobres. O resto e o mesmo motor.

Rodar: python3 .tools/planejar_cidades.py
"""
import json
import math
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M = "res://models/"

# Largura livre de cada tipo de via, em metros. Nada de construcao pisa nela.
LARGURA_DA_AVENIDA = 7.0
LARGURA_DO_ANEL = 5.0
# Recuo do alinhamento predial ate o meio-fio.
RECUO = 2.2

# As casas que sobreviveram bem a conversao 3D. As demais viraram mancha e estao
# fora ate serem refeitas — vila com casa derretida e pior que vila com menos
# variedade.
CASAS = ["casa_vila", "casa_camponesa", "casa_chale", "casa_mercador",
         "casa_sobrado", "loja_toldo", "celeiro"]
NOBRES = ["casa_sobrado", "casa_nobre", "casa_mercador"]


def peca(ident, tag, modelo, x, z, giro=0.0, escala=1.0):
    return {"id": ident, "tag": tag, "model": M + modelo + ".glb",
            "position": [round(x, 2), round(z, 2)],
            "rotation": round(giro % 360.0, 1), "scale": escala}


def anel_de_casas(pecas, prefixo, raio, por_quarteirao, ruas, paleta, tag="casa"):
    """Preenche os quarteiroes de um anel, um por fatia entre duas avenidas.

    A primeira versao espalhava N casas pelo circulo inteiro e DESCARTAVA as que
    caiam sobre uma avenida. Como a largura angular de uma rua cresce quando o
    raio diminui, o anel de dentro perdia dois tercos das casas e a cidade
    nascia rala justamente onde deveria ser densa.
    """
    lote = 0
    for indice in range(len(ruas)):
        comeco = ruas[indice]
        fim = ruas[(indice + 1) % len(ruas)]
        # A fatia vai de uma avenida a seguinte, descontada a calcada de cada
        # lado. Sobrando menos que um lote, o quarteirao fica vazio de verdade.
        largura = (fim - comeco) % 360.0
        margem = _abertura(raio, LARGURA_DA_AVENIDA)
        util = largura - margem * 2.0
        if util <= 0.0:
            continue

        for k in range(por_quarteirao):
            # Distribui pelos CENTROS dos lotes: assim a primeira e a ultima casa
            # ficam recuadas da esquina, como em quarteirao de verdade.
            passo = util / por_quarteirao
            angulo = comeco + margem + passo * (k + 0.5)
            rad = math.radians(angulo)
            pecas.append(peca(f"{prefixo}_{lote:02d}", tag,
                              paleta[lote % len(paleta)],
                              math.cos(rad) * raio, math.sin(rad) * raio,
                              giro=270.0 - angulo))
            lote += 1


def _diferenca(a, b):
    return (a - b + 180.0) % 360.0 - 180.0


def _abertura(raio, largura):
    """Meia largura de uma via, vista como angulo a partir do centro."""
    return math.degrees(math.atan2(largura * 0.5 + RECUO, max(raio, 1.0)))


def muralha_circular(pecas, raio, torres, portoes):
    """Cortina fechada com torre em intervalo regular e portao em cada estrada.

    A torre nao e enfeite: e ela que marca o ritmo da muralha e da a leitura de
    cidade fortificada de longe. Portao so onde HA estrada — portao no meio do
    nada e cenario.
    """
    for i in range(torres):
        angulo = i * (360.0 / torres)
        if any(abs(_diferenca(angulo, p)) < 14.0 for p in portoes):
            continue
        rad = math.radians(angulo)
        pecas.append(peca(f"torre_{i:02d}", "torre", "torre_redonda",
                          math.cos(rad) * raio, math.sin(rad) * raio,
                          giro=270.0 - angulo))
    for i, angulo in enumerate(portoes):
        rad = math.radians(angulo)
        pecas.append(peca(f"portao_{i}", "muralha", "muralha_portao",
                          math.cos(rad) * raio, math.sin(rad) * raio,
                          giro=270.0 - angulo, escala=1.2))


def iluminar(pecas, raio, angulos, marca):
    """Poste so no CRUZAMENTO de um anel com uma avenida.

    Iluminacao publica acompanha esquina, nao perimetro: um anel continuo de
    postes vira cerca luminosa e come a praca inteira — foi o que aconteceu na
    primeira versao, com trinta e dois postes na capital.
    """
    for i, angulo in enumerate(angulos):
        rad = math.radians(angulo)
        pecas.append(peca(f"lamp_{marca}_{i:02d}", "lampiao", "lampiao",
                          math.cos(rad) * raio, math.sin(rad) * raio))


def cidade_radial(avenidas, aneis, raio_da_muralha, portoes, marcos):
    """Monta uma cidade inteira a partir da sua geometria.

    Devolve as pecas E a geometria: o shader do chao precisa dos mesmos numeros
    para desenhar o leito das ruas. Se os dois calculassem por conta propria, a
    casa acabaria no meio da avenida na primeira vez que um numero mudasse.
    """
    pecas = []

    # O monumento no centro exato: e o ponto de fuga de todas as avenidas, e
    # e o que o jogador ve ao chegar por qualquer uma delas.
    pecas.append(peca("monumento", "fonte", "fonte_musical", 0, 0, escala=1.6))

    ruas = [i * (360.0 / avenidas) for i in range(avenidas)]

    # Iluminacao publica: QUATRO postes na praca e mais nada.
    #
    # A primeira versao pos um em cada cruzamento de anel com avenida e a capital
    # ficou com trinta e dois — de cima, um bosque de postes que engolia a
    # cidade. Poste e mobiliario de rua: quando se nota que ha muitos, ja ha
    # muitos. Quatro marcam o centro e somem no resto da leitura.
    iluminar(pecas, 7.5, ruas[:4], "praca")

    for indice, (raio, por_quarteirao, paleta) in enumerate(aneis):
        anel_de_casas(pecas, f"anel{indice}", raio, por_quarteirao, ruas, paleta)

    for ident, tag, modelo, angulo, raio, escala in marcos:
        rad = math.radians(angulo)
        pecas.append(peca(ident, tag, modelo,
                          math.cos(rad) * raio, math.sin(rad) * raio,
                          giro=270.0 - angulo, escala=escala))

    if raio_da_muralha > 0.0:
        muralha_circular(pecas, raio_da_muralha,
                         torres=max(8, avenidas * 2), portoes=portoes)

    # As ruas correm entre os aneis de casas, nao sobre eles.
    raios = [r for r, _, _ in aneis]
    entre = [round((raios[i] + raios[i + 1]) * 0.5, 1) for i in range(len(raios) - 1)]
    entre.append(round(raios[-1] + 5.0, 1))
    return pecas, {"avenidas": avenidas, "aneis": entre[:3]}


# ─────────────────────────────────────────────────────────── as quatro cidades
#
# Os angulos dos portoes vem da mascara de estradas medida em jogo, nao de
# escolha estetica: a Vila do Caminho e encruzilhada de quatro bracos, Portoes
# Reais recebe estrada a leste e ao sul, a Praca Central so pelo sul, e o Salao
# do Forjador so pelo oeste. Portao fora da estrada nao e portao.
CIDADES = {
    # Praca Central de Acordelot — a capital, tres aneis e muralha completa.
    "custom_1785869541494_557": dict(
        raio=52.0,
        planta=cidade_radial(
            avenidas=8,
            aneis=[(13.0, 2, CASAS), (23.0, 3, CASAS), (34.0, 4, CASAS)],
            raio_da_muralha=50.0,
            portoes=[90.0],
            marcos=[
                ("castelo", "torre", "torre_redonda", 270.0, 34.0, 1.6),
                ("catedral", "sobrado", "casa_sobrado", 225.0, 33.0, 1.3),
                ("mercado_a", "banca", "banca_verde", 40.0, 24.0, 1.0),
                ("mercado_b", "banca", "banca_vermelha", 60.0, 24.0, 1.0),
                ("moinho", "moinho", "moinho", 135.0, 44.0, 1.0),
                ("leao_o", "estatua", "leao_sentado", 100.0, 13.0, 1.0),
                ("leao_l", "estatua", "leao_de_pe", 80.0, 13.0, 1.0),
            ])),
    # Portoes Reais — praca de armas: um anel so, muralha pesada, duas estradas.
    "custom_1785880661560_858": dict(
        raio=44.0,
        planta=cidade_radial(
            avenidas=4,
            aneis=[(14.0, 2, NOBRES), (25.0, 4, CASAS)],
            raio_da_muralha=41.0,
            portoes=[0.0, 90.0],
            marcos=[
                ("torre_mestra", "torre", "torre_redonda", 180.0, 30.0, 1.5),
                ("estandarte_o", "estandarte", "estandarte_agudo", 250.0, 11.0, 1.0),
                ("estandarte_l", "estandarte", "estandarte_grave", 290.0, 11.0, 1.0),
                ("poco", "poco", "poco", 200.0, 15.0, 1.0),
            ])),
    # Vila do Caminho — encruzilhada de quatro bracos, sem muralha.
    "custom_1785884200706_430": dict(
        raio=34.0,
        planta=cidade_radial(
            avenidas=4,
            aneis=[(12.0, 2, CASAS), (21.0, 3, CASAS)],
            raio_da_muralha=0.0,
            portoes=[],
            marcos=[
                ("poco", "poco", "poco", 45.0, 9.0, 1.0),
                ("feira", "banca", "banca_verde", 135.0, 10.0, 1.0),
                ("carroca", "mobilia", "carroca", 315.0, 10.0, 1.0),
                ("celeiro", "celeiro", "celeiro", 225.0, 27.0, 1.0),
            ])),
    # Salao do Forjador — aldeia de estrada sem saida, um anel curto.
    "custom_1786499037621_343": dict(
        raio=26.0,
        planta=cidade_radial(
            avenidas=2,
            aneis=[(11.0, 3, CASAS)],
            raio_da_muralha=0.0,
            portoes=[],
            marcos=[
                ("oficina", "oficina_ferreiro", "oficina_ferreiro", 180.0, 17.0, 1.0),
                ("poco", "poco", "poco", 90.0, 8.0, 1.0),
                ("barris", "mobilia", "barris", 300.0, 9.0, 1.0),
            ])),
}


def main():
    saida = {
        "_nota": ("GERADO por .tools/planejar_cidades.py — nao editar a mao, o "
                  "proximo run sobrescreve. E plano radial, nao sorteio: praca no "
                  "centro, avenidas em raio, aneis concentricos, e o quarteirao "
                  "ocupando a fatia entre duas avenidas. Mexer no desenho e mexer "
                  "no script."),
        "pracas": {}, "layouts": {},
    }
    for ident, cidade in CIDADES.items():
        pecas, geometria = cidade["planta"]
        saida["pracas"][ident] = {"raio": cidade["raio"],
                                  "avenidas": geometria["avenidas"],
                                  "aneis": geometria["aneis"]}
        saida["layouts"][ident] = pecas
        alcance = max(math.hypot(*p["position"]) for p in pecas)
        print(f'{ident}  {len(pecas):3d} pecas  alcance {alcance:.0f} m  '
              f'praca {cidade["raio"]:.0f} m  '
              f'{geometria["avenidas"]} avenidas, aneis {geometria["aneis"]}')

    destino = os.path.join(RAIZ, "data", "city_layouts.json")
    with open(destino, "w") as arquivo:
        json.dump(saida, arquivo, ensure_ascii=False, indent=1)
    print("gravado em data/city_layouts.json")


main()
