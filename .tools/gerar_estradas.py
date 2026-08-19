#!/usr/bin/env python3
"""Desenha as estradas do mundo num mapa que o shader do chão lê.

Estrada de verdade LIGA um cenário ao outro. Mancha de terra sorteada por ruído
não faz isso: some no meio do caminho e nunca chega a lugar nenhum.

Então o traçado sai da própria grade do jogo 2D: cada par de cenários vizinhos
(distância 1 na grade) vira um trecho. Onde as duas pontas são urbanas, o trecho
é calçamento de pedra; no resto, terra batida.

O resultado é UMA imagem cobrindo o mundo inteiro, amostrada pela posição — dois
canais: vermelho = terra, verde = pedra. Custa uma leitura de textura e vale
para qualquer traçado que a gente queira desenhar depois.
"""
import json, math, random
from PIL import Image, ImageDraw, ImageFilter

REGIOES = "data/regions.json"
SAIDA = "textures/road_mask.png"

METROS_POR_PIXEL = 2.0
LARGURA_ESTRADA = 4.5   # metros
LARGURA_PRACA = 7.0     # metros, no centro de cada cenário
# Era 16 m, e o desfoque da máscara ainda alargava: da altura da câmera virava
# um descampado de barro ocupando meia tela em toda região. Praça é ponto de
# encontro, não clareira.
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

    rng = random.Random(31415)

    def traco(pincel, a, b, largura_m):
        """Trecho com uma barriga: estrada reta de régua entrega o mapa como
        grade. A curva é sempre a mesma para o mesmo par, porque a semente é
        fixa — o mundo não muda de desenho entre partidas."""
        largura_px_traco = max(2, int(largura_m / METROS_POR_PIXEL))
        meio = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        perpendicular = (-(b[1] - a[1]), b[0] - a[0])
        comprimento = math.hypot(*perpendicular) or 1.0
        desvio = rng.uniform(-0.12, 0.12) * math.hypot(b[0] - a[0], b[1] - a[1])
        controle = (meio[0] + perpendicular[0] / comprimento * desvio,
                    meio[1] + perpendicular[1] / comprimento * desvio)
        pontos = []
        for passo in range(13):
            t = passo / 12.0
            um = (1 - t)
            pontos.append((um * um * a[0] + 2 * um * t * controle[0] + t * t * b[0],
                           um * um * a[1] + 2 * um * t * controle[1] + t * t * b[1]))
        pincel.line(pontos, fill=255, width=largura_px_traco, joint="curve")

    trechos = 0
    for regiao in nomeadas:
        aqui = (regiao["col"], regiao["row"])
        for vizinho_celula in [(aqui[0] + 1, aqui[1]), (aqui[0], aqui[1] + 1)]:
            vizinho = por_celula.get(vizinho_celula)
            if vizinho is None:
                continue
            de_pedra = (regiao["biome"] in BIOMAS_DE_PEDRA
                        and vizinho["biome"] in BIOMAS_DE_PEDRA)
            pincel = pincel_pedra if de_pedra else pincel_terra
            traco(pincel, para_pixel(*centro(regiao)), para_pixel(*centro(vizinho)),
                  LARGURA_ESTRADA)
            trechos += 1

    # Praça no centro de cada cenário: é onde a estrada chega e onde vão ficar
    # NPC e missão. Urbano ganha calçamento, o resto ganha chão batido.
    for regiao in nomeadas:
        px, pz = para_pixel(*centro(regiao))
        rid = regiao.get("id", "")
        
        if rid == "custom_1785869541494_557":
            # Praça Central Monumental (Ref. 4): Anel concêntrico de pedra e 4 avenidas radiais
            raio_nucleo = 12.0 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - raio_nucleo, pz - raio_nucleo, px + raio_nucleo, pz + raio_nucleo], fill=255)
            
            # Anel externo pavimentado do mercado
            raio_anel_ext = 26.0 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - raio_anel_ext, pz - raio_anel_ext, px + raio_anel_ext, pz + raio_anel_ext], fill=255)
            
            # 4 Avenidas radiais de pedra cruzando o canal
            larg_av = int(7.0 / METROS_POR_PIXEL)
            pincel_pedra.line([(px, pz - raio_anel_ext - 10), (px, pz + raio_anel_ext + 10)], fill=255, width=larg_av)
            pincel_pedra.line([(px - raio_anel_ext - 10, pz), (px + raio_anel_ext + 10, pz)], fill=255, width=larg_av)
            
        elif rid == "custom_1785880661560_858":
            # Portões Reais (Ref. 2): Avenida de pedra cruzando a ponte e o pátio interno
            larg_portao = int(6.5 / METROS_POR_PIXEL)
            pz_ponte = pz + int(14.0 / METROS_POR_PIXEL)
            pz_norte = pz - int(25.0 / METROS_POR_PIXEL)
            pincel_pedra.line([(px, pz_ponte), (px, pz_norte)], fill=255, width=larg_portao)
            
            # Pátio pavimentado dentro da fortaleza
            raio_patio = 16.0 / METROS_POR_PIXEL
            pincel_pedra.ellipse([px - raio_patio, pz - 10 - raio_patio, px + raio_patio, pz - 10 + raio_patio], fill=255)
            
        elif rid == "custom_1785884200706_430":
            # Vila do Caminho (Ref. 3): Chão de terra batida largo em torno do poço e ramificações
            raio_vila = 16.0 / METROS_POR_PIXEL
            pincel_terra.ellipse([px - raio_vila, pz - raio_vila, px + raio_vila, pz + raio_vila], fill=255)
            
            # Trilha para o moinho (leste) e para a estalagem (noroeste)
            larg_trilha = int(4.5 / METROS_POR_PIXEL)
            pincel_terra.line([(px, pz), (px + int(21.0 / METROS_POR_PIXEL), pz - int(1.0 / METROS_POR_PIXEL))], fill=255, width=larg_trilha)
            pincel_terra.line([(px, pz), (px - int(16.0 / METROS_POR_PIXEL), pz - int(12.0 / METROS_POR_PIXEL))], fill=255, width=larg_trilha)
            pincel_terra.line([(px, pz), (px + int(15.0 / METROS_POR_PIXEL), pz + int(12.0 / METROS_POR_PIXEL))], fill=255, width=larg_trilha)
            pincel_terra.line([(px, pz), (px - int(16.0 / METROS_POR_PIXEL), pz + int(13.0 / METROS_POR_PIXEL))], fill=255, width=larg_trilha)
            
        elif rid == "custom_1785881037059_214":
            # Floresta do Despertar (Ref. 1): Bifurcação em Y
            raio_floresta = 8.0 / METROS_POR_PIXEL
            pincel_terra.ellipse([px - raio_floresta, pz - raio_floresta, px + raio_floresta, pz + raio_floresta], fill=255)
            larg_y = int(5.0 / METROS_POR_PIXEL)
            # Ramo nordeste (para o caminho da vila)
            pincel_terra.line([(px, pz), (px + int(18.0 / METROS_POR_PIXEL), pz - int(25.0 / METROS_POR_PIXEL))], fill=255, width=larg_y)
            # Ramo noroeste (para a trilha da serra/enseada)
            pincel_terra.line([(px, pz), (px - int(18.0 / METROS_POR_PIXEL), pz - int(25.0 / METROS_POR_PIXEL))], fill=255, width=larg_y)
            
        else:
            raio = LARGURA_PRACA / METROS_POR_PIXEL * 0.5
            pincel = pincel_pedra if regiao["biome"] in BIOMAS_DE_PEDRA else pincel_terra
            pincel.ellipse([px - raio, pz - raio, px + raio, pz + raio], fill=255)

    # Borda macia: sem isso a estrada tem recorte de papel no terreno.
    terra = terra.filter(ImageFilter.GaussianBlur(1.2))
    pedra = pedra.filter(ImageFilter.GaussianBlur(1.0))
    # Onde há pedra, não há terra: a calçada manda.
    terra = Image.composite(Image.new("L", terra.size, 0), terra,
                            pedra.point(lambda v: 255 if v > 110 else 0))

    mapa = Image.merge("RGB", (terra, pedra, Image.new("L", terra.size, 0)))
    mapa.save(SAIDA)

    print(f"{trechos} trechos ligando {len(nomeadas)} cenarios")
    print(f"mapa: {largura_px}x{altura_px} px cobrindo {largura_m:.0f}x{altura_m:.0f} m")
    print(f"mundo_min = ({mundo_min[0]:.1f}, {mundo_min[1]:.1f})  "
          f"tamanho = ({largura_m:.1f}, {altura_m:.1f})")


if __name__ == "__main__":
    main()
