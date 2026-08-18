#!/usr/bin/env python3
"""Prepara um personagem GLB para o auto-rigger do Mixamo.

Tres coisas impedem o GLB de subir direto:

1. **O Mixamo nao aceita GLB.** Aceita FBX, OBJ, ou ZIP com OBJ + MTL +
   texturas. Aqui sai o ZIP.
2. **Limite de ~150 mil poligonos.** O modelo gerado veio com 285 mil.
3. **Textura em WebP**, que o par OBJ/MTL nao le. Vira PNG.

A UV **nao** e interpolada ao simplificar: cada vertice novo herda a UV de um
representante. Media de UV atravessa a emenda do mapa e puxa a textura para o
meio da imagem — o personagem sairia com o rosto borrado.
"""
import os, shutil, sys, zipfile
import numpy as np
import fast_simplification
from fast_simplification.replay import replay_simplification
from pygltflib import GLTF2
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from decimar_malha import ler_accessor

ALVO = 120000  # abaixo do limite do Mixamo, com folga


def imagem_do_glb(gltf, blob, indice):
    vista = gltf.bufferViews[gltf.images[indice].bufferView]
    inicio = vista.byteOffset or 0
    dados = blob[inicio:inicio + vista.byteLength]
    caminho = "/tmp/_textura_%d" % indice
    with open(caminho, "wb") as f:
        f.write(dados)
    return Image.open(caminho).convert("RGB")


def main():
    origem = sys.argv[1]
    destino = sys.argv[2] if len(sys.argv) > 2 else "personagem/heroi_mixamo"
    os.makedirs(destino, exist_ok=True)

    gltf = GLTF2().load(origem)
    blob = gltf.binary_blob()
    primitiva = gltf.meshes[0].primitives[0]

    posicoes = ler_accessor(gltf, blob, primitiva.attributes.POSITION).astype(np.float32)
    triangulos = ler_accessor(gltf, blob, primitiva.indices).reshape(-1, 3).astype(np.int64)
    uvs = ler_accessor(gltf, blob, primitiva.attributes.TEXCOORD_0).astype(np.float32)
    normais = None
    if getattr(primitiva.attributes, "NORMAL", None) is not None:
        normais = ler_accessor(gltf, blob, primitiva.attributes.NORMAL).astype(np.float32)

    antes = len(triangulos)
    if antes > ALVO:
        reducao = 1.0 - ALVO / float(antes)
        _, _, colapsos = fast_simplification.simplify(
            posicoes, triangulos.astype(np.int32), reducao, return_collapses=True)
        novas_posicoes, novos_triangulos, mapeamento = replay_simplification(
            posicoes, triangulos.astype(np.int32), colapsos)

        # Representante, nao media: UV medida atravessa a emenda do mapa.
        representante = np.zeros(len(novas_posicoes), dtype=np.int64)
        representante[mapeamento[::-1]] = np.arange(len(mapeamento))[::-1]
        uvs = uvs[representante]
        if normais is not None:
            normais = normais[representante]
        posicoes = np.asarray(novas_posicoes, dtype=np.float32)
        triangulos = np.asarray(novos_triangulos, dtype=np.int64)

    # O Mixamo mede em centimetros e espera o personagem em pe sobre a origem.
    altura = float(posicoes[:, 1].max() - posicoes[:, 1].min())
    posicoes = posicoes.copy()
    posicoes[:, 1] -= posicoes[:, 1].min()

    nome = "heroi"
    with open(os.path.join(destino, nome + ".obj"), "w") as f:
        f.write("# Acordelot — heroi preparado para o Mixamo\n")
        f.write("mtllib %s.mtl\n" % nome)
        for p in posicoes:
            f.write("v %.6f %.6f %.6f\n" % (p[0], p[1], p[2]))
        for uv in uvs:
            # OBJ conta o V de baixo para cima; glTF, de cima para baixo.
            f.write("vt %.6f %.6f\n" % (uv[0], 1.0 - uv[1]))
        if normais is not None:
            for n in normais:
                f.write("vn %.6f %.6f %.6f\n" % (n[0], n[1], n[2]))
        f.write("usemtl heroi\n")
        for t in triangulos + 1:
            if normais is not None:
                f.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" %
                        (t[0], t[0], t[0], t[1], t[1], t[1], t[2], t[2], t[2]))
            else:
                f.write("f %d/%d %d/%d %d/%d\n" % (t[0], t[0], t[1], t[1], t[2], t[2]))

    albedo = imagem_do_glb(gltf, blob, 0)
    albedo.save(os.path.join(destino, nome + "_albedo.png"))

    with open(os.path.join(destino, nome + ".mtl"), "w") as f:
        f.write("newmtl heroi\nKd 1.0 1.0 1.0\nd 1.0\nillum 2\n")
        f.write("map_Kd %s_albedo.png\n" % nome)

    pacote = destino + ".zip"
    with zipfile.ZipFile(pacote, "w", zipfile.ZIP_DEFLATED) as z:
        for arquivo in sorted(os.listdir(destino)):
            z.write(os.path.join(destino, arquivo), arquivo)

    print(f"triangulos: {antes:,} -> {len(triangulos):,}")
    print(f"altura do modelo: {altura:.3f} (pes na origem)")
    print(f"textura: {albedo.size[0]}x{albedo.size[1]}")
    print("pacote:", pacote, f"({os.path.getsize(pacote)//1024} KB)")


if __name__ == "__main__":
    main()
