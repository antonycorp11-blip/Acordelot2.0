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


def agrupar(posicoes, cores, triangulos, celulas):
    """Uma passada de agrupamento com 'celulas' divisoes no maior eixo."""
    minimo = posicoes.min(axis=0)
    tamanho = (posicoes.max(axis=0) - minimo).max()
    if tamanho <= 0:
        return posicoes, cores, triangulos
    lado = tamanho / celulas

    grade = np.floor((posicoes - minimo) / lado).astype(np.int64)
    _, destino, inverso = np.unique(grade, axis=0, return_index=True, return_inverse=True)

    novo_total = destino.size
    # Posicao e cor do vertice fundido: a media do que caiu na celula. Media, e
    # nao o primeiro: pegar um representante faz a silhueta tremer.
    soma = np.zeros((novo_total, 3), dtype=np.float64)
    np.add.at(soma, inverso, posicoes)
    contagem = np.bincount(inverso, minlength=novo_total).reshape(-1, 1)
    novas_posicoes = (soma / contagem).astype(np.float32)

    novas_cores = None
    if cores is not None:
        soma_cor = np.zeros((novo_total, cores.shape[1]), dtype=np.float64)
        np.add.at(soma_cor, inverso, cores)
        novas_cores = (soma_cor / contagem).astype(np.float32)

    novos = inverso[triangulos]
    # Triangulo que perdeu dois cantos na mesma celula virou linha: fora.
    vivos = ((novos[:, 0] != novos[:, 1]) & (novos[:, 1] != novos[:, 2]) &
             (novos[:, 0] != novos[:, 2]))
    novos = novos[vivos]
    # Duas faces coincidentes viram uma so.
    novos = np.unique(np.sort(novos, axis=1), axis=0) if novos.size else novos
    return novas_posicoes, novas_cores, novos


def escrever_glb(caminho, posicoes, cores, triangulos):
    indices = triangulos.astype(np.uint32).ravel()
    pos_bytes = posicoes.astype(np.float32).tobytes()
    idx_bytes = indices.tobytes()
    cor_bytes = cores.astype(np.float32).tobytes() if cores is not None else b""

    def alinhar(dados):
        resto = len(dados) % 4
        return dados + b"\x00" * (4 - resto) if resto else dados

    blocos, vistas, acessores, deslocamento = [], [], [], 0
    for dados, alvo in ((pos_bytes, "pos"), (cor_bytes, "cor"), (idx_bytes, "idx")):
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
    # Busca binaria na resolucao da grade: e o numero de celulas que decide o
    # tamanho final, e ele nao tem formula fechada para malha irregular.
    baixo, alto, melhor = 4, 256, None
    for _ in range(9):
        meio = (baixo + alto) // 2
        p, c, t = agrupar(posicoes, cores, triangulos, meio)
        if len(t) <= alvo:
            melhor = (p, c, t)
            baixo = meio + 1
        else:
            alto = meio - 1
        if baixo > alto:
            break
    if melhor is None:
        melhor = agrupar(posicoes, cores, triangulos, 4)

    p, c, t = melhor
    destino = os.path.join(SAIDA, os.path.basename(caminho))
    escrever_glb(destino, p, c, t)
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
