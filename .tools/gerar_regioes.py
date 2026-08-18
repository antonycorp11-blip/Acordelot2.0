#!/usr/bin/env python3
"""Gera data/regions.json a partir da grade do jogo 2D.

A grade antiga (gridPos) vira a PLANTA de um terreno unico: a celula (col,row)
ocupa o quadrado de REGION_SIZE metros naquela posicao. Nao ha teleporte — as
celulas vazias do retangulo viram mata fechada para o mundo nao ter buraco.
"""
import json, re

CFG = "data/world_config.json"
OUT = "data/regions.json"

# Bioma a partir do nome do cenario: o emoji do jogo 2D ja classificava tudo.
BIOMAS = [
    ("caverna",  r"Caverna|Passagem Inferior|⛏|🕳"),
    ("sombria",  r"Floresta Sombria|🌑"),
    ("floresta", r"Floresta|Trilha|🌲|🌾"),
    ("clareira", r"Clareira|Enseada|🌿|🏞"),
    ("cidade",   r"Praça|Portões|Vila|🏰|🛡|🏘"),
    ("ruina",    r"Ruínas|Salão|Altar|🏚|🎼"),
    ("sagrado",  r"Notas Sagradas|✦"),
]

# Cada bioma diz o que nasce nele. As escalas saem das arvores ja postas a mao
# em forest_map.tscn (5.0–5.6), que e o tamanho que ficou certo na camera.
PALETAS = {
    "floresta": [{"tag": "tree", "count": 26}, {"tag": "bush", "count": 10}],
    "sombria":  [{"tag": "tree", "count": 34}, {"tag": "crystal", "count": 4}],
    "clareira": [{"tag": "tree", "count": 10}, {"tag": "bush", "count": 16},
                 {"tag": "crystal", "count": 3}],
    "cidade":   [{"tag": "wall", "count": 18}, {"tag": "tree", "count": 6}],
    "ruina":    [{"tag": "wall", "count": 22}, {"tag": "bush", "count": 6}],
    "caverna":  [{"tag": "wall", "count": 26}, {"tag": "crystal", "count": 8}],
    "sagrado":  [{"tag": "crystal", "count": 12}, {"tag": "tree", "count": 6}],
    "mata":     [{"tag": "tree", "count": 44}, {"tag": "bush", "count": 12}],
}


def bioma_de(nome):
    for chave, padrao in BIOMAS:
        if re.search(padrao, nome):
            return chave
    return "floresta"


def main():
    cfg = json.load(open(CFG))
    grid, nomes = cfg["gridPos"], cfg["sceneNames"]

    cols = [p["col"] for p in grid.values()]
    rows = [p["row"] for p in grid.values()]
    # Uma faixa de mata em volta para a borda do mundo nao ser uma parede seca.
    c0, c1 = min(cols) - 1, max(cols) + 1
    r0, r1 = min(rows) - 1, max(rows) + 1

    por_celula = {(p["col"], p["row"]): k for k, p in grid.items()}
    regioes = []
    for row in range(r0, r1 + 1):
        for col in range(c0, c1 + 1):
            ident = por_celula.get((col, row))
            if ident:
                nome = nomes.get(ident, ident)
                bioma = bioma_de(nome)
            else:
                ident = f"mata_{col}_{row}"
                nome = "Mata Fechada"
                bioma = "mata"
            regioes.append({
                "id": ident,
                "name": nome,
                "col": col,
                "row": row,
                "biome": bioma,
                "props": PALETAS[bioma],
                # Semente fixa por celula: o mesmo mundo em toda partida, sem
                # precisar guardar milhares de posicoes num arquivo.
                "seed": abs(hash((col, row, bioma))) % 2147483647,
            })

    saida = {
        "_origem": "gerado por .tools/gerar_regioes.py a partir de data/world_config.json",
        "region_size": 120.0,
        "start_map": cfg["startMap"],
        "regions": regioes,
    }
    json.dump(saida, open(OUT, "w"), ensure_ascii=False, indent=2)

    nomeadas = sum(1 for r in regioes if not r["id"].startswith("mata_"))
    print(f"{len(regioes)} regioes ({nomeadas} do jogo antigo, "
          f"{len(regioes) - nomeadas} de mata) — {c1-c0+1}x{r1-r0+1} celulas")
    print(f"mundo: {(c1-c0+1)*120}m x {(r1-r0+1)*120}m")


if __name__ == "__main__":
    main()
