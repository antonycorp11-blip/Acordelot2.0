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
        raio=44.0,
        planta=cidade_radial(
            avenidas=4,
            aneis=[
                (14.0, 2, NOBRES_E_MANSOES),
                (25.0, 3, CASAS_MEDIEVAIS)
            ],
            raio_da_muralha=41.0,
            portoes=[0.0, 90.0, 180.0, 270.0],
            marcos=[
                ("torre_comando", "torre", "torre_redonda", 180.0, 30.0, 1.5),
                ("quartel_mestre", "casa_enxaimel_2", "medieval_house_3", 0.0, 28.0, 1.2),
                ("estandarte_norte_1", "estandarte", "estandarte_agudo", 45.0, 11.0, 1.1),
                ("estandarte_norte_2", "estandarte", "estandarte_grave", 135.0, 11.0, 1.1),
                ("estandarte_sul_1", "estandarte", "estandarte_agudo", 225.0, 11.0, 1.1),
                ("estandarte_sul_2", "estandarte", "estandarte_grave", 315.0, 11.0, 1.1),
                ("poco_guarnicao", "poco", "poco", 200.0, 15.0, 1.0),
                ("barris_quartel", "mobilia", "barris", 215.0, 15.0, 1.0),
            ],
            monumento=("monumento_armas", "fonte", "fonte_praca", 1.4)
        )
    ),

    # 3. 🏘️ Vila do Caminho & Mercado do Vale (col 0, row 2)
    "custom_1785884200706_430": dict(
        raio=36.0,
        planta=cidade_radial(
            avenidas=4,
            aneis=[
                (13.0, 2, CASAS_MEDIEVAIS),
                (23.0, 3, CHALES_E_CAMPO)
            ],
            raio_da_muralha=0.0,
            portoes=[],
            marcos=[
                ("moinho_vento", "moinho", "moinho", 135.0, 29.0, 1.15),
                ("celeiro_vila", "celeiro", "celeiro", 225.0, 28.0, 1.1),
                ("banca_feira_1", "banca", "banca_verde", 40.0, 8.5, 1.0),
                ("banca_feira_2", "banca", "banca_vermelha", 60.0, 8.5, 1.0),
                ("banca_feira_3", "banca", "banca_feira", 300.0, 8.5, 1.0),
                ("carroca_vila", "mobilia", "carroca", 320.0, 9.0, 1.0),
                ("barris_taberna", "mobilia", "barris", 160.0, 9.0, 1.0),
                ("lampiao_praca", "lampiao", "lampiao", 90.0, 6.0, 1.0),
                ("lampiao_praca_2", "lampiao", "lampiao", 270.0, 6.0, 1.0),
            ],
            monumento=("poco_central", "poco", "poco", 1.2)
        )
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
        saida["pracas"][ident] = {
            "raio": cidade["raio"],
            "avenidas": geometria["avenidas"],
            "aneis": geometria["aneis"]
        }
        saida["layouts"][ident] = pecas
        alcance = max(math.hypot(*p["position"]) for p in pecas)
        print(f'{ident:26s}  {len(pecas):3d} pecas  alcance {alcance:4.1f}m  '
              f'praca {cidade["raio"]:4.1f}m  '
              f'{geometria["avenidas"]} avenidas, aneis {geometria["aneis"]}')

    destino = os.path.join(RAIZ, "data", "city_layouts.json")
    with open(destino, "w") as arquivo:
        json.dump(saida, arquivo, ensure_ascii=False, indent=1)
    print(f"Sucesso: {len(CIDADES)} cidades e marcos gravados em data/city_layouts.json")


if __name__ == "__main__":
    main()
