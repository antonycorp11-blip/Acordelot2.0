#!/usr/bin/env python3
"""Carimba a build web com a impressao digital do proprio conteudo.

O navegador do celular guardava a build antiga e o jogador testava uma versao
que ja nao existia — mesmo com o vercel.json mandando nao guardar. O jeito que
sempre funciona e o arquivo MUDAR DE NOME: cache de nome que nao existe mais
nao tem como ser servido.

Ate aqui esse numero era escrito a mao (index_v2, index_v3), o que deixava as
versoes antigas para tras — noventa megabytes de build morta dentro do
repositorio — e dependia de alguem lembrar de subir o numero. Aqui o nome sai
do resumo do proprio .pck: build igual mantem o nome, build diferente ganha
outro, e o que sobrou de antes e apagado.

Uso: publicar_web.py   (depois do --export-release do Godot)
"""
import hashlib
import json
import os
import re
import glob

PASTA = "builds/web"
# Tudo que o carregador do Godot procura pelo nome do executavel.
SUFIXOS = (".js", ".pck", ".wasm", ".audio.worklet.js",
           ".audio.position.worklet.js", ".side.wasm")


## O GitHub recusa arquivo acima de 100 MB, e o pacote do jogo ja bate nos 94.
## Cortar conteudo para caber nao e caminho: o jogo so cresce. Entao o pacote
## sobe PARTIDO, e o navegador remonta antes de entregar ao motor — nenhum
## arquivo passa do limite, e o jogador nao percebe diferenca.
LIMITE_DA_PARTE = 45 * 1024 * 1024


def _partir(caminho):
    tamanho = os.path.getsize(caminho)
    if tamanho <= LIMITE_DA_PARTE:
        return []
    partes = []
    with open(caminho, "rb") as f:
        indice = 1
        while True:
            pedaco = f.read(LIMITE_DA_PARTE)
            if not pedaco:
                break
            nome = "%s.p%d" % (caminho, indice)
            with open(nome, "wb") as saida:
                saida.write(pedaco)
            partes.append(os.path.basename(nome))
            indice += 1
    os.remove(caminho)
    return partes


def _digital(caminho):
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for pedaco in iter(lambda: f.read(1 << 20), b""):
            h.update(pedaco)
    return h.hexdigest()[:10]


def main():
    pck = os.path.join(PASTA, "index.pck")
    if not os.path.exists(pck):
        print("nao achei builds/web/index.pck — rode o --export-release antes")
        return

    marca = "index_" + _digital(pck)

    # Fora com qualquer carimbo anterior, menos o que estamos gravando agora.
    for antigo in glob.glob(os.path.join(PASTA, "index_*")):
        base = os.path.basename(antigo)
        if not base.startswith(marca):
            os.remove(antigo)

    tamanhos = {}
    for sufixo in SUFIXOS:
        origem = os.path.join(PASTA, "index" + sufixo)
        if not os.path.exists(origem):
            continue
        destino = os.path.join(PASTA, marca + sufixo)
        os.replace(origem, destino)
        if sufixo in (".pck", ".wasm"):
            tamanhos[marca + sufixo] = os.path.getsize(destino)

    partes = _partir(os.path.join(PASTA, marca + ".pck"))

    caminho_html = os.path.join(PASTA, "index.html")
    html = open(caminho_html, encoding="utf-8").read()

    html = html.replace('src="index.js"', 'src="%s.js"' % marca)

    # A configuracao do carregador guarda o nome base e o tamanho de cada peca;
    # deixar os antigos ali faz o Godot pedir arquivo que nao existe mais.
    def _corrigir(m):
        cfg = json.loads(m.group(1))
        cfg["executable"] = marca
        cfg["fileSizes"] = tamanhos
        return "const GODOT_CONFIG = " + json.dumps(cfg, separators=(",", ":"))

    html, quantas = re.subn(r"const GODOT_CONFIG = (\{.*?\});", _corrigir, html,
                            count=1, flags=re.S)
    if quantas != 1:
        print("AVISO: nao achei o GODOT_CONFIG no index.html")

    # O motor recebe o pacote ja remontado, como endereco de memoria. Ele nunca
    # sabe que o arquivo estava em pedacos.
    if partes:
        remontagem = """
	async function juntarOPacote() {
		const partes = %s;
		const pedacos = [];
		for (const nome of partes) {
			const resposta = await fetch(nome);
			if (!resposta.ok) {
				throw new Error('faltou uma parte do pacote: ' + nome);
			}
			pedacos.push(await resposta.arrayBuffer());
		}
		// Blob costura os pedacos sem copiar tudo para um buffer unico antes:
		// num celular, a copia dobraria a memoria no pior instante da carga.
		return URL.createObjectURL(new Blob(pedacos, {type: 'application/octet-stream'}));
	}
""" % json.dumps(partes)
        html = html.replace("const engine = new Engine(GODOT_CONFIG);",
                            "const engine = new Engine(GODOT_CONFIG);\n" + remontagem, 1)

        abertura = """		engine.startGame({
			'onProgress': function (current, total) {"""
        nova_abertura = """		juntarOPacote().then((pacote) => engine.startGame({
			'mainPack': pacote,
			'onProgress': function (current, total) {"""
        fechamento = """		}).then(() => {
			setStatusMode('hidden');
		}, displayFailureNotice);"""
        novo_fechamento = """		}).then(() => {
			setStatusMode('hidden');
		}, displayFailureNotice)).catch(displayFailureNotice);"""
        if abertura not in html or fechamento not in html:
            print("AVISO: o index.html mudou de forma; o pacote NAO foi religado")
        else:
            html = html.replace(abertura, nova_abertura, 1)
            html = html.replace(fechamento, novo_fechamento, 1)

    open(caminho_html, "w", encoding="utf-8").write(html)

    print("carimbo: %s" % marca)
    for nome, tam in tamanhos.items():
        print("  %-26s %6.1f MB" % (nome, tam / 1048576))
    for nome in partes:
        print("  %-26s %6.1f MB (parte)" % (
            nome, os.path.getsize(os.path.join(PASTA, nome)) / 1048576))


main()
