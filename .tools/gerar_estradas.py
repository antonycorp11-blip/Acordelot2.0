#!/usr/bin/env python3
"""Desenha as estradas e pracas do mundo num mapa que o shader do chao le.

Dois canais:
- Vermelho = terra batida / trilhas florestais
- Verde = calcamento de pedra / avenidas / pracas urbanas
"""
import json, math, random
from PIL import Image, ImageDraw, ImageFilter

REGIOES = "data/regions.json"
LAYOUTS = "data/city_layouts.json"
SAIDA = "textures/road_mask.png"

METROS_POR_PIXEL = 2.0
LARGURA_ESTRADA = 5.5       # metros (estrada principal)
LARGURA_TRILHA = 4.0        # metros (trilha secundária)
LARGURA_AVENIDA = 7.0       # metros (avenida urbana de pedra)

BIOMAS_DE_PEDRA = {"cidade", "ruina", "sagrado"}


def main():
    dados = json.load(open(REGIOES))
    tamanho_regiao = dados["region_size"]
    regioes = dados["regions"]

    nomeadas = [r for r in regioes if not r["id"].startswith("mata_")]
    por_celula = {(r["col"], r["row"]): r for r in nomeadas}

    colunas = [r["col"] for r in regioes]
    linhas = [r["row"] for r in regioes]
    meia = tamanho_regiao * 0.5
    mundo_min = (min(colunas) * tamanho_regiao - meia, min(linhas) * tamanho_regiao - meia)
    mundo_max = (max(colunas) * tamanho_regiao + meia, max(linhas) * tamanho_regiao + meia)
    largura_m = mundo_max[0] - mundo_min[0]
    altura_m = mundo_max[1] - mundo_min[1]

    largura_px = int(largura_m / METROS_POR_PIXEL)
    altura_px = int(altura_m / METROS_POR_PIXEL)

    terra = Image.new("L", (largura_px, altura_px), 0)
    pedra = Image.new("L", (largura_px, altura_px), 0)
    pincel_terra = ImageDraw.Draw(terra)
    pincel_pedra = ImageDraw.Draw(pedra)

    def para_pixel(x, z):
        return ((x - mundo_min[0]) / METROS_POR_PIXEL,
                (z - mundo_min[1]) / METROS_POR_PIXEL)

    def centro(regiao):
        return (regiao["col"] * tamanho_regiao, regiao["row"] * tamanho_regiao)

    rng = random.Random(4242)

    def traco_curvo(pincel, a, b, largura_m, curvatura=0.10):
        largura_px_traco = max(2, int(largura_m / METROS_POR_PIXEL))
        meio = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        perpendicular = (-(b[1] - a[1]), b[0] - a[0])
        comprimento = math.hypot(*perpendicular) or 1.0
        desvio = rng.uniform(-curvatura, curvatura) * math.hypot(b[0] - a[0], b[1] - a[1])
        controle = (meio[0] + perpendicular[0] / comprimento * desvio,
                    meio[1] + perpendicular[1] / comprimento * desvio)
        pontos = []
        for passo in range(16):
            t = passo / 15.0
            um = (1 - t)
            pontos.append((um * um * a[0] + 2 * um * t * controle[0] + t * t * b[0],
                           um * um * a[1] + 2 * um * t * controle[1] + t * t * b[1]))
        pincel.line(pontos, fill=255, width=largura_px_traco, joint="curve")

    # 1. Traçado de vias conectando pares de cenários vizinhos
    conexoes = set()
    for regiao in nomeadas:
        aqui = (regiao["col"], regiao["row"])
        for vizinho_celula in [
            (aqui[0] + 1, aqui[1]), (aqui[0], aqui[1] + 1),
            (aqui[0] + 1, aqui[1] + 1), (aqui[0] + 1, aqui[1] - 1)
        ]:
            vizinho = por_celula.get(vizinho_celula)
            if vizinho is None:
                continue
            par = tuple(sorted([regiao["id"], vizinho["id"]]))
            if par in conexoes:
                continue
            conexoes.add(par)

            de_pedra = (regiao["biome"] in BIOMAS_DE_PEDRA and vizinho["biome"] in BIOMAS_DE_PEDRA)
            pincel = pincel_pedra if de_pedra else pincel_terra
            larg = LARGURA_AVENIDA if de_pedra else LARGURA_ESTRADA
            traco_curvo(pincel, para_pixel(*centro(regiao)), para_pixel(*centro(vizinho)), larg)

    # 2. Conexões expressas adicionais para caminhos de longa distância
    rotas_especiais = [
        ("custom_1785869541494_557", "notas_sagradas", True),       # Estrada Real Norte
        ("custom_1785869541494_557", "custom_1786572451743_753", False), # Estrada Leste para o Lago
        ("custom_1786572451743_753", "custom_1786572518911_723", True),  # Acesso à Vila Ribeirinha
        ("notas_sagradas", "custom_1786572340509_998", True),      # Trilha para a Cidadela da Serra
        ("custom_1786572340509_998", "custom_1786499037621_343", True), # Estrada entre fortes da serra
    ]
    for id_a, id_b, calcada in rotas_especiais:
        reg_a = next((r for r in nomeadas if r["id"] == id_a), None)
        reg_b = next((r for r in nomeadas if r["id"] == id_b), None)
        if reg_a and reg_b:
            pincel = pincel_pedra if calcada else pincel_terra
            larg = LARGURA_AVENIDA if calcada else LARGURA_ESTRADA
            traco_curvo(pincel, para_pixel(*centro(reg_a)), para_pixel(*centro(reg_b)), larg, curvatura=0.15)

    # 3. Desenho de praças, anéis viários e centros urbanos
    for regiao in nomeadas:
        px, pz = para_pixel(*centro(regiao))
        rid = regiao.get("id", "")

        if rid == "custom_1785869541494_557":
            # 🏰 Capital Imperial: Grande Praça Central, anel externo e 8 avenidas radiais
            r_nucleo = 13.5 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - r_nucleo, pz - r_nucleo, px + r_nucleo, pz + r_nucleo], fill=255)
            
            # Anel viário intermediário
            r_anel = 26.0 / METROS_POR_PIXEL
            larg_anel = max(3, int(5.5 / METROS_POR_PIXEL))
            pincel_pedra.arc([px - r_anel, pz - r_anel, px + r_anel, pz + r_anel], 0, 360, fill=255, width=larg_anel)
            
            # 8 Avenidas radiais pavimentadas
            larg_av = int(6.5 / METROS_POR_PIXEL)
            raio_total = 49.0 / METROS_POR_PIXEL
            for ang_deg in [0, 45, 90, 135, 180, 225, 270, 315]:
                ang_rad = math.radians(ang_deg)
                pincel_pedra.line([
                    (px, pz),
                    (px + math.cos(ang_rad) * raio_total, pz + math.sin(ang_rad) * raio_total)
                ], fill=255, width=larg_av)

        elif rid == "custom_1785880661560_858":
            # 🛡️ Portões Reais: Praça de armas e 4 avenidas
            r_patio = 16.0 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - r_patio, pz - r_patio, px + r_patio, pz + r_patio], fill=255)
            larg_av = int(6.5 / METROS_POR_PIXEL)
            r_av = 41.0 / METROS_POR_PIXEL
            for ang_deg in [0, 90, 180, 270]:
                rad = math.radians(ang_deg)
                pincel_pedra.line([(px, pz), (px + math.cos(rad) * r_av, pz + math.sin(rad) * r_av)], fill=255, width=larg_av)

        elif rid == "custom_1785884200706_430":
            # 🏘️ Vila do Caminho: Praça de terra batida e feira com ramificações
            r_vila = 16.0 / METROS_POR_PIXEL
            pincel_terra.ellipse([px - r_vila, pz - r_vila, px + r_vila, pz + r_vila], fill=255)
            larg_trilha = int(5.0 / METROS_POR_PIXEL)
            for ang_deg in [0, 90, 180, 270, 45, 225]:
                rad = math.radians(ang_deg)
                pincel_terra.line([(px, pz), (px + math.cos(rad) * 28.0 / METROS_POR_PIXEL, pz + math.sin(rad) * 28.0 / METROS_POR_PIXEL)], fill=255, width=larg_trilha)

        elif rid == "custom_1786501580114_289":
            # 🎼 Salão do Forjador: Pátio de calçamento e acesso às forjas
            r_forja = 14.0 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - r_forja, pz - r_forja, px + r_forja, pz + r_forja], fill=255)

        elif rid == "custom_1786572518911_723":
            # ⛵ Vila Ribeirinha: Pátio de pedra do cais e pontes
            r_cais = 14.0 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - r_cais, pz - r_cais, px + r_cais, pz + r_cais], fill=255)

        elif rid == "custom_1786572340509_998":
            # ⛰️ Cidadela da Serra: Bastião de pedra no alto da montanha
            r_forte = 15.0 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - r_forte, pz - r_forte, px + r_forte, pz + r_forte], fill=255)

        elif rid == "notas_sagradas":
            # ✦ Santuário Sagrado: Círculo místico de pedra com 8 raios
            r_sagrado = 12.0 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - r_sagrado, pz - r_sagrado, px + r_sagrado, pz + r_sagrado], fill=255)
            larg_raio = int(3.5 / METROS_POR_PIXEL)
            for ang_deg in range(0, 360, 45):
                rad = math.radians(ang_deg)
                pincel_pedra.line([(px, pz), (px + math.cos(rad) * 26.0 / METROS_POR_PIXEL, pz + math.sin(rad) * 26.0 / METROS_POR_PIXEL)], fill=255, width=larg_raio)

        else:
            # Demais cenários (florestas, ruínas, clareiras)
            r_praca = 8.0 / METROS_POR_PIXEL
            pincel = pincel_pedra if regiao["biome"] in BIOMAS_DE_PEDRA else pincel_terra
            pincel.ellipse([px - r_praca, pz - r_praca, px + r_praca, pz + r_praca], fill=255)

    # Suavização para transição natural no terreno
    terra = terra.filter(ImageFilter.GaussianBlur(1.2))
    pedra = pedra.filter(ImageFilter.GaussianBlur(1.0))
    # Onde há pedra, a calçada tem prioridade sobre a terra batida
    terra = Image.composite(Image.new("L", terra.size, 0), terra,
                            pedra.point(lambda v: 255 if v > 90 else 0))

    mapa = Image.merge("RGB", (terra, pedra, Image.new("L", terra.size, 0)))
    mapa.save(SAIDA)
    print(f"Sucesso: Mascara de estradas gravada em {SAIDA}")
    print(f"Dimensoes: {largura_px}x{altura_px} px cobrindo {largura_m:.0f}x{altura_m:.0f} m")


if __name__ == "__main__":
    main()
