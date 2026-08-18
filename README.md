# Acordelot 2.0 — o mundo em 3D

RPG de educação musical, agora em Godot 4.7. O jogo 2D (`~/Desktop/wasd_game`)
continua sendo a fonte da história, das missões e da teoria musical; aqui está o
mundo onde isso vai acontecer em 3D.

Alvo: **celular e navegador**, câmera isométrica fixa no estilo Albion Online.

## Rodar

```bash
.tools/Godot.app/Contents/MacOS/Godot --editor --path .   # editor
.tools/Godot.app/Contents/MacOS/Godot --path .            # jogo
.tools/Godot.app/Contents/MacOS/Godot --path . -- --shot  # salva um quadro e sai
```

O `--shot` existe porque captura de tela do sistema não alcança a janela do
jogo: é assim que se confere o mundo sem depender de alguém olhar a tela.

## Publicar

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-release "Web" "builds/web/index.html"
```

O `builds/web/` **está versionado** e é o que a Vercel publica (`vercel.json`
aponta para lá). Não há Node nesta máquina, então não dá para exportar na
Vercel — o build sai daqui pronto.

> O jogo 2D versionou o `dist/` e o `.git` passou de 550 MB. Aqui o build são
> 48 MB por vez: **só comitar `builds/web/` quando for de fato publicar**, não a
> cada experimento.

## Como o mundo é montado

Não há teleporte entre cenários: o mundo é contínuo, de ponta a ponta.

- A grade do jogo 2D (`gridPos`, 20 cenários) virou a **planta** de um terreno
  único — `data/world_config.json`. Cada célula ocupa 120 m naquela posição.
- `.tools/gerar_regioes.py` transforma essa grade em `data/regions.json`, dando
  bioma e paleta de vegetação a cada célula. As células vazias do retângulo
  viram mata fechada, para o mundo não ter buraco.
- `scripts/chunk_builder.gd` monta pedaços de 30 m a partir da paleta, com
  semente fixa: o mesmo mundo em toda partida, sem guardar coordenada nenhuma.
- `scripts/world_streamer.gd` carrega **só o que a câmera enxerga**. O chão é
  plano e a câmera é fixa, então dá para ser exato: lança-se um raio por canto
  da tela até o plano do chão e carrega-se o retângulo que cabe esses pontos.

## Assets

`generate_3d.py` (na pasta `AcordeLot 2.0`) faz imagem → GLB pelo TripoSR. O que
sai de lá **não serve direto**: vem com ~185 mil triângulos por objeto (um
arbusto veio com 492 mil), o que dá 5 fps e um download que ninguém baixa no 4G.

```bash
"../AcordeLot 2.0/venv/bin/python" .tools/decimar_malha.py   # -> models/
```

Isso levou 52 MB e 185 mil triângulos para 750 KB e ~2,4 mil. **Todo modelo novo
passa por aqui** antes de entrar em `data/asset_catalog.json`.

O LOD automático do Godot não substitui isso: o renderizador GL Compatibility
(o que roda em celular e navegador) não aplica LOD de malha, e as malhas do
TripoSR nem têm normais, que é do que o gerador de LOD precisa.

## Armadilhas já pagas

1. **Compressão VRAM de textura derruba o editor** nesta máquina (Intel HD 5000,
   assertion do Metal). `project.godot` já força `compress/mode: 0` como padrão.
2. **O jogador nasce antes do mundo existir.** O mundo se monta um pedaço por
   quadro; sem `ensure_ground_at` antes do primeiro passo de física, ele despenca
   durante a montagem.
3. **Centro de célula na quina de quatro pedaços** fazia o jogador nascer com
   meio corpo fora do chão e escorregar. O pedaço é centrado no índice, não
   apoiado nele.
4. **Cor por vértice precisa de material que a leia** (`Material_TripoSR.tres`):
   sem ele o modelo do TripoSR chega branco e o céu o deixa azulado.
5. **O autoload não roda no editor**, só no jogo — conferir mundo por
   `execute_gdscript` no editor dá `null`. Medir com o jogo rodando.

## Ponte com o Claude

O editor expõe um servidor MCP (addon `godot_mcp`, porta 6400). A ponte é
`.tools/gmcp.py`, que fala JSON-RPC direto no `POST /message` — sem SSE, que
guardava resposta pendente e embaralhava os ids.

```bash
python3 .tools/gmcp.py tools
python3 .tools/gmcp.py call get_scene_tree '{}'
```
