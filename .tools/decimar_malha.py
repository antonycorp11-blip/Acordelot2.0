#!/usr/bin/env python3
"""Decima os GLB do TripoSR para malhas que rodam em celular e navegador.

O TripoSR entrega ~185 mil triangulos por objeto (um arbusto veio com 492 mil).
Setenta e cinco desses na tela sao 14 milhoes de triangulos: 5 fps no desktop, e
nada no celular. Os 52 MB de modelo tambem decidiriam sozinhos se o jogo abre
no 4G.

O gerador de LOD do proprio Godot nao serve aqui: ele agrupa por angulo de
normal, e a malha do TripoSR **nao tem normais** — so posicao e cor por vertice.

Entao a decimacao e por agrupamento em grade: o espaco vira celulas, todo
vertice que cai na mesma celula vira um so (posicao e cor medias) e o triangulo
que perdeu dois cantos na mesma celula deixa de existir. E o metodo certo para
malha organica escaneada, onde nao ha aresta viva a preservar — e o unico que
sobrevive sem normais.

Uso: decimar_malha.py [alvo_de_triangulos] [arquivo.glb ...]
"""
import glob, json, os, struct, sys
import numpy as np
import fast_simplification
from fast_simplification.replay import replay_simplification
from pygltflib import GLTF2

SAIDA = "models"
ALVO_PADRAO = 2500

TIPOS = {5120: "i1", 5121: "u1", 5122: "i2", 5123: "u2", 5125: "u4", 5126: "f4"}
LARGURAS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def ler_accessor(gltf, blob, indice):
    acessor = gltf.accessors[indice]
    vista = gltf.bufferViews[acessor.bufferView]
    largura = LARGURAS[acessor.type]
    dtype = np.dtype("<" + TIPOS[acessor.componentType])
    inicio = (vista.byteOffset or 0) + (acessor.byteOffset or 0)
    passo = vista.byteStride or (dtype.itemsize * largura)

    if passo == dtype.itemsize * largura:
        bruto = np.frombuffer(blob, dtype=dtype, count=acessor.count * largura, offset=inicio)
        return bruto.reshape(acessor.count, largura)
    # Buffer intercalado: le linha a linha respeitando o passo.
    linhas = [np.frombuffer(blob, dtype=dtype, count=largura, offset=inicio + i * passo)
              for i in range(acessor.count)]
    return np.array(linhas)


def normalizar_cor(cor, tipo):
    if tipo == 5121:
        return cor.astype(np.float32) / 255.0
    if tipo == 5123:
        return cor.astype(np.float32) / 65535.0
    return cor.astype(np.float32)


def simplificar(posicoes, cores, triangulos, alvo):
    """Reduz a malha por colapso de aresta com erro quadratico.

    A primeira versao agrupava vertices por celula de grade. Era rapida e
    **furava a malha**: onde a folha e fina, os tres cantos do triangulo caem na
    mesma celula, o triangulo vira degenerado e some — a copa ficava crivada de
    buracos, que na tela apareciam como chuvisco branco (era o fundo passando).

    O colapso de aresta preserva a topologia: junta vertice a vertice pela
    aresta, entao a superficie continua fechada.

    A cor vem junto pelo mapeamento de indices: cada vertice novo recebe a media
    dos originais que desaguaram nele.
    """
    reducao = 1.0 - min(1.0, alvo / float(len(triangulos)))
    saida = fast_simplification.simplify(
        posicoes.astype(np.float32), triangulos.astype(np.int32),
        reducao, return_collapses=True)
    novas_posicoes, novos_triangulos, colapsos = saida
    novas_posicoes, novos_triangulos, mapeamento = replay_simplification(
        posicoes.astype(np.float32), triangulos.astype(np.int32), colapsos)

    novas_cores = None
    if cores is not None:
        total = len(novas_posicoes)
        soma = np.zeros((total, cores.shape[1]), dtype=np.float64)
        valido = mapeamento >= 0
        np.add.at(soma, mapeamento[valido], cores[valido])
        contagem = np.bincount(mapeamento[valido], minlength=total).reshape(-1, 1)
        contagem[contagem == 0] = 1
        novas_cores = (soma / contagem).astype(np.float32)

    return (novas_posicoes.astype(np.float32), novas_cores,
            np.asarray(novos_triangulos, dtype=np.int64))


def normais_suaves(posicoes, triangulos):
    """Normal por vertice, media das faces vizinhas ponderada pela area.

    O TripoSR **nao exporta normais**. Sem elas a Godot gera uma normal plana
    por face, e depois da decimacao as faces sao grandes e irregulares: cada
    uma pega a luz de um jeito e a arvore fica salpicada de claro e escuro,
    como se estivesse comida de traca. Com normal por vertice a superficie
    volta a ser lida como curva, que e o que ela e.

    O produto vetorial ja vem proporcional a area do triangulo, entao somar sem
    normalizar antes JA e a ponderacao por area — face grande pesa mais, que e
    o que se quer.
    """
    normais = np.zeros_like(posicoes, dtype=np.float64)
    a = posicoes[triangulos[:, 0]]
    b = posicoes[triangulos[:, 1]]
    c = posicoes[triangulos[:, 2]]
    face = np.cross(b - a, c - a)
    for canto in range(3):
        np.add.at(normais, triangulos[:, canto], face)
    tamanho = np.linalg.norm(normais, axis=1, keepdims=True)
    tamanho[tamanho == 0] = 1.0
    return (normais / tamanho).astype(np.float32)


def escrever_glb(caminho, posicoes, cores, triangulos, normais=None):
    indices = triangulos.astype(np.uint32).ravel()
    pos_bytes = posicoes.astype(np.float32).tobytes()
    idx_bytes = indices.tobytes()
    cor_bytes = cores.astype(np.float32).tobytes() if cores is not None else b""
    nor_bytes = normais.astype(np.float32).tobytes() if normais is not None else b""

    def alinhar(dados):
        resto = len(dados) % 4
        return dados + b"\x00" * (4 - resto) if resto else dados

    blocos, vistas, acessores, deslocamento = [], [], [], 0
    for dados, alvo in ((pos_bytes, "pos"), (nor_bytes, "nor"), (cor_bytes, "cor"),
                        (idx_bytes, "idx")):
        if not dados:
            continue
        preenchido = alinhar(dados)
        vistas.append({"buffer": 0, "byteOffset": deslocamento, "byteLength": len(dados),
                       "target": 34963 if alvo == "idx" else 34962})
        blocos.append(preenchido)
        deslocamento += len(preenchido)

    indice_vista = 0
    acessores.append({"bufferView": indice_vista, "componentType": 5126, "count": len(posicoes),
                      "type": "VEC3", "min": posicoes.min(axis=0).tolist(),
                      "max": posicoes.max(axis=0).tolist()})
    atributos = {"POSITION": 0}
    indice_vista += 1
    if normais is not None:
        acessores.append({"bufferView": indice_vista, "componentType": 5126,
                          "count": len(normais), "type": "VEC3"})
        atributos["NORMAL"] = len(acessores) - 1
        indice_vista += 1
    if cores is not None:
        acessores.append({"bufferView": indice_vista, "componentType": 5126,
                          "count": len(cores),
                          "type": "VEC4" if cores.shape[1] == 4 else "VEC3"})
        atributos["COLOR_0"] = len(acessores) - 1
        indice_vista += 1
    acessores.append({"bufferView": indice_vista, "componentType": 5125,
                      "count": len(indices), "type": "SCALAR"})

    documento = {
        "asset": {"version": "2.0", "generator": "acordelot decimar_malha.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0}],
        "meshes": [{"primitives": [{"attributes": atributos,
                                    "indices": len(acessores) - 1,
                                    "material": 0}]}],
        "materials": [{"name": "Material_TripoSR",
                       "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1],
                                                "metallicFactor": 0.0,
                                                "roughnessFactor": 1.0}}],
        "accessors": acessores,
        "bufferViews": vistas,
        "buffers": [{"byteLength": deslocamento}],
    }

    corpo = b"".join(blocos)
    json_bytes = json.dumps(documento, separators=(",", ":")).encode()
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(corpo)
    with open(caminho, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes)
        f.write(struct.pack("<II", len(corpo), 0x004E4942) + corpo)


def decimar(caminho, alvo):
    gltf = GLTF2().load(caminho)
    blob = gltf.binary_blob()
    primitiva = gltf.meshes[0].primitives[0]

    posicoes = ler_accessor(gltf, blob, primitiva.attributes.POSITION).astype(np.float32)
    triangulos = ler_accessor(gltf, blob, primitiva.indices).reshape(-1, 3).astype(np.int64)
    cores = None
    if getattr(primitiva.attributes, "COLOR_0", None) is not None:
        indice = primitiva.attributes.COLOR_0
        cores = normalizar_cor(ler_accessor(gltf, blob, indice), gltf.accessors[indice].componentType)

    antes = len(triangulos)
    p, c, t = simplificar(posicoes, cores, triangulos, alvo)
    melhor = (p, c, t)
    p, c, t = melhor
    n = normais_suaves(p, t)
    destino = os.path.join(SAIDA, os.path.basename(caminho))
    escrever_glb(destino, p, c, t, n)
    return f"{os.path.basename(caminho):<44} {antes:>8,} -> {len(t):>6,} tri   " \
           f"{os.path.getsize(caminho)//1024:>6} KB -> {os.path.getsize(destino)//1024:>5} KB"


def main():
    args = sys.argv[1:]
    alvo = ALVO_PADRAO
    if args and args[0].isdigit():
        alvo = int(args.pop(0))
    os.makedirs(SAIDA, exist_ok=True)
    for caminho in (args or sorted(glob.glob("*.glb"))):
        print(decimar(caminho, alvo), flush=True)


if __name__ == "__main__":
    main()
