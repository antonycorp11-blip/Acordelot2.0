#!/usr/bin/env python3
"""Gera data/regions.json a partir da grade do jogo e configurações de biomas.

A grade (gridPos) vira a PLANTA de um terreno unico: a celula (col,row)
ocupa o quadrado de REGION_SIZE metros naquela posicao. As
celulas circundantes viram mata fechada e bosques densos para formar um mundo completo.
"""
import json, re

CFG = "data/world_config.json"
OUT = "data/regions.json"

# Mapeamento de biomas por palavra-chave no nome
BIOMAS = [
    ("caverna",  r"Caverna|Gruta|Passagem|⛏|🕳"),
    ("sombria",  r"Floresta Sombria|Sustenido|Pauta|🌑"),
    ("floresta", r"Floresta|Trilha|Pomares|Coleta|Águas|🌲|🌾"),
    ("clareira", r"Clareira|Enseada|🌿|🏞|⛵"),
    ("cidade",   r"Praça|Portões|Vila|Cidadela|Bastião|🏰|🛡|🏘|⛰"),
    ("ruina",    r"Ruínas|Altar|Forjador|Salão|🏚|🎼"),
    ("sagrado",  r"Notas Sagradas|Santuário|✦"),
]

# Densidade rica de props por bioma
PALETAS = {
    "floresta": [
        {"tag": "tree", "count": 32},
        {"tag": "bush", "count": 14},
        {"tag": "grama_alta", "count": 28},
        {"tag": "flores", "count": 18},
        {"tag": "cogumelo", "count": 10},
        {"tag": "pedrinha", "count": 8}
    ],
    "sombria": [
        {"tag": "arvore_morta", "count": 18},
        {"tag": "pinheiro", "count": 20},
        {"tag": "pedra", "count": 14},
        {"tag": "raiz", "count": 12},
        {"tag": "crystal", "count": 6}
    ],
    "clareira": [
        {"tag": "tree", "count": 12},
        {"tag": "bush", "count": 18},
        {"tag": "grama_alta", "count": 34},
        {"tag": "flores", "count": 30},
        {"tag": "crystal", "count": 4},
        {"tag": "pedrinha", "count": 12}
    ],
    "cidade": [
        {"tag": "wall", "count": 16},
        {"tag": "tree", "count": 8},
        {"tag": "grama_alta", "count": 14},
        {"tag": "flores", "count": 12}
    ],
    "ruina": [
        {"tag": "wall", "count": 24},
        {"tag": "pedra", "count": 16},
        {"tag": "bush", "count": 10},
        {"tag": "raiz", "count": 8}
    ],
    "caverna": [
        {"tag": "wall", "count": 28},
        {"tag": "pedra", "count": 22},
        {"tag": "crystal", "count": 10}
    ],
    "sagrado": [
        {"tag": "crystal", "count": 16},
        {"tag": "tree", "count": 8},
        {"tag": "flores", "count": 24},
        {"tag": "grama_alta", "count": 20}
    ],
    "mata": [
        {"tag": "tree", "count": 48},
        {"tag": "pinheiro", "count": 16},
        {"tag": "bush", "count": 18},
        {"tag": "grama_alta", "count": 24},
        {"tag": "cogumelo", "count": 12},
        {"tag": "pedrinha", "count": 10}
    ],
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
    
    # Grid de 11x10 cobrindo de -5 a 5 nas colunas e -4 a 5 nas linhas
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
    print(f"{len(regioes)} regioes ({nomeadas} principais, "
          f"{len(regioes) - nomeadas} de mata) — {c1-c0+1}x{r1-r0+1} celulas")
    print(f"Mundo total: {(c1-c0+1)*120}m x {(r1-r0+1)*120}m")


if __name__ == "__main__":
    main()
