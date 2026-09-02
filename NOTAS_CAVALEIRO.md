# Cavaleiro chefe — onde parei e como continuar

Documento de passagem. O modelo está no jogo, com a espada encaixada e medida.
Falta a animação e a entrada dele no mundo.

---

## 1. O que já existe

| Arquivo | O que é |
|---|---|
| `models/cavaleiro_chefe.glb` | O cavaleiro. 29.998 triângulos, 41 ossos, 3 texturas. |
| `models/espada_cavaleiro.glb` | A espada dele. 44.998 triângulos, sem rig, 3 texturas. |
| `scripts/cavaleiro_chefe.gd` | Monta o chefe: normaliza a altura e encaixa a espada na mão. |
| `.tools/decimar_riggado.py` | Decimador que preserva UV, ossos, pesos e texturas. |

Os dois GLB vieram do Tripo com **1,89 e 1,97 milhão de triângulos** (79 MB e
61 MB). Foram decimados. Os originais estão em `~/Downloads` do dono, não no
repositório.

### O ambiente Python

`.tools/decimar_riggado.py` precisa de um venv que **não está versionado**
(está no `.gitignore`). Para recriar:

```bash
python3 -m venv .tools/venv3d
.tools/venv3d/bin/python -m pip install pygltflib "numpy<2" "fast_simplification==0.1.7"
```

Duas travas que custaram tempo e vão se repetir:

- **`numpy` tem de ser 1.x.** O `fast_simplification` é compilado contra a ABI
  antiga; com numpy 2 ele quebra em `numpy.core.multiarray failed to import`.
- **`fast_simplification` mais novo que 0.1.7 exige Python 3.10+.** Esta máquina
  só tem 3.9, e as versões novas usam `X | None`, que 3.9 não entende.

Uso:

```bash
.tools/venv3d/bin/python .tools/decimar_riggado.py entrada.glb saida.glb 30000
```

**Não use o `.tools/decimar_malha.py` para personagem.** Ele foi escrito para
cenário do TripoSR — malha de posição e cor, sem UV e sem esqueleto — e
descarta os dois. Passar um personagem por ele devolve o modelo cinza e sem rig.

---

## 2. O encaixe da espada — já resolvido, não refazer

Este rig **não tem osso de dedo**, só `R_Hand`. O método que resolveu a lança da
Wins (a linha dos nós, de `RightHandIndex1` a `RightHandPinky1`) não serve aqui.

O eixo saiu da **geometria da mão**: os 241 vértices que `R_Hand` domina,
decompostos em componentes principais no espaço do próprio osso. As três
extensões saem na proporção de uma mão:

```
0,116  ->  comprimento dos dedos
0,079  ->  a linha dos nós  <- É ESTE o eixo de quem segura
0,045  ->  espessura da palma
```

O sinal veio da assimetria do polegar (−0,382): a lâmina sai pelo lado do
polegar, o pomo pelo do mindinho.

O resultado está em `EIXO_DO_PUNHO` no script, e foi conferido por medida:

| Medida | Resultado |
|---|---|
| Comprimento da espada no mundo | 1,200 m |
| Onde a mão fecha na espada | 82,4% (o cabo fino, medido no arquivo) |
| Folga do eixo até o punho | 0,0000 m |
| **Ângulo espada × antebraço** | **91,1°** |
| Altura do cavaleiro | 2,30 m |

Os 91,1° são a prova: a lâmina sai perpendicular ao antebraço, que é mão
fechada de verdade. Se depois de mexer no script esse ângulo sair perto de 0 ou
180, a espada voltou a ficar deitada ao longo do braço — que era o defeito.

---

## 3. O que falta: as animações

O modelo **não veio com animação nenhuma**, só o esqueleto.

### Por que as bibliotecas do projeto não tocam nele

O projeto tem seis bibliotecas assadas (`personagem/*_anims.res`), todas em
ossos **Mixamo** (`mixamorig_Hips`, `mixamorig_RightArm`…). Este rig usa nomes
do **Tripo**:

```
Root, Hip, Pelvis, Waist, Spine01, Spine02, NeckTwist01, NeckTwist02, Head,
L_Clavicle, L_Upperarm, L_UpperarmTwist01, L_UpperarmTwist02, L_Forearm,
L_ForearmTwist01, L_ForearmTwist02, L_Hand,   (e o espelho em R_)
L_Thigh, L_ThighTwist01, L_ThighTwist02, L_Calf, L_CalfTwist01, L_CalfTwist02,
L_Foot, L_ToeBase                              (e o espelho em R_)
```

São 41. Nomes legíveis, sem dedos.

### Os dois caminhos

**A) `BoneMap` + `SkeletonProfileHumanoid`.** Mapear os 41 para o perfil
humanoide da Godot e reaproveitar `heroi_anims.res`. Mais rápido. Herda
movimento pensado para o Akles, que tem outra silhueta e outra arma.

**B) Escrever as animações neste rig.** Foi o que o dono pediu ("se tiver como
fazer animações novas seria uma boa"), e num chefe rende mais: dá para controlar
o tempo de aviso antes do golpe, o peso do impacto e a recuperação — que é o que
faz um chefe ser **lido** pelo jogador em vez de só bater.

Eu ia pelo B. Recomendo o mesmo.

O repertório mínimo para o que o `bicho.gd` já chama:
`parado`, `andar`, `correr`, `ataque` (um ou dois), `morrer`.

Ficou uma pergunta em aberto com o dono: **se o chefe é só corpo a corpo ou se
tem golpe à distância** (uma onda de corte combinaria com o tema harmônico).
Vale perguntar antes de desenhar os golpes.

---

## 4. Como ele entra no jogo

O sistema de monstros é `scripts/bicho.gd`, e a chave é a lista
`MONSTROS_CONFIG` (linha ~15). Cada entrada é um tipo de monstro:

```gdscript
{"nome": ..., "cena": ..., "biblioteca": ..., "pele": ..., "prefixo": ...,
 "altura": ..., "hp": ..., "dano": ..., "aura": ..., "velocidade": ...}
```

Hoje vai de 0 a 5 — três Shikers e três Golens. **O cavaleiro entra como o tipo
6**, apontando `cena` para `cavaleiro_chefe.glb` e `biblioteca` para a
biblioteca de animação nova.

### O drop de ascensão já existe

Não precisa inventar: `bicho.gd::_largar_premio_de_chefe()` (linha ~981) já dá o
item, e `tornar_super_shiker()` (linha ~885) é o que marca um bicho como chefe.

A regra atual é `monster_type >= 3` ganha `nucleo_maestro`, senão
`selo_regente`. Com o cavaleiro no tipo 6 ele cairia no Núcleo — **confirmar com
o dono qual dos dois ele deve guardar**, porque hoje o Colosso já guarda o
Núcleo e ter dois guardando o mesmo item tira o sentido de um deles.

O item cai **uma vez por conta** (`if progresso.quantidade(chave) <= 0`), então
não há o que farmar. Isso é de propósito.

### Onde ele nasce

A caverna é `scripts/dungeon_caverna.gd`. Os bichos nascem por
`_shiker(onde, tipo)` e `_ninho(centro, tipo, quantos, raio)`. O plantel é
anotado em `_plantel` para o "tentar de novo" da tela de fim poder repovoar —
**um chefe novo tem de entrar por essas funções**, senão ele não volta quando o
jogador tenta de novo.

---

## 5. Como conferir sem chutar

Duas coisas que economizam muito tempo neste projeto.

**Medir vale mais que olhar.** Escreva um script temporário
`extends SceneTree`, rode com `--headless --script`, imprima o número, apague o
script. Foi assim que os 91,1° do punho apareceram. Chutar posição de osso e
conferir por captura é lento e o dono pediu explicitamente para economizar
captura.

**Se for renderizar mesmo assim**, duas armadilhas:

- Modelo novo não carrega antes de
  `Godot --headless --path . --import`.
- `get_viewport().get_texture().get_image()` devolve o quadro **anterior**.
  Sem `await RenderingServer.frame_post_draw` antes, a imagem sai velha — eu
  perdi uma rodada inteira por causa disso.

E o teste de fumaça do projeto continua valendo: autoload temporário `ZFumaca`
no `project.godot`, rodar, restaurar o `project.godot`, apagar o script. Com
**controle negativo**: quebre de propósito e confirme que o teste reprova. Já
aconteceu de eu escrever um teste que passava com a arma no lugar errado.
