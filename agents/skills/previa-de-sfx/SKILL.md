---
name: previa-de-sfx
description: Busca efeitos sonoros CC0 e monta prévias para o dono escolher de ouvido, até os arquivos finais com crédito. Use quando o dono pedir som, SFX ou efeito sonoro para um jogo ou app, ou quiser trocar um som que não agradou.
---

# Prévia de SFX

O dono escolhe som **de ouvido**, nunca pela descrição. O trabalho é chegar a
uma pasta curta de **prévias** que ele ouve no player dele, e depois entregar
exatamente o que ele ouviu. O gosto dele: **grave**; agudo ele descarta.

Os scripts estão em `~/.claude/skills/previa-de-sfx/scripts/` (`medir`,
`previa.sh`); o cabeçalho de cada um diz o uso.

## 1. Consulte as fontes

Leia `~/ObsidianVault/research/efeitos-sonoros-cc0/index.md`: onde já se achou
CC0 que serve, quais sites recusam download por script e o que o dono já
escolheu ou recusou. Parta dali; a pesquisa nova segue o ritual da skill
`research`.

Pronto quando você sabe quais fontes vai varrer.

## 2. Colete candidatos

- Só entra som com licença **CC0** lida na página de onde o arquivo sai.
  Anote página, autor e licença de cada arquivo baixado.
- Cada download vai numa pasta própria, vazia, no scratchpad.
- Peça mais que o necessário: por som pedido, uns 10 a 20 candidatos.

Pronto quando cada som pedido tem candidatos com licença conferida.

## 3. Meça e corte os agudos

Rode `medir` em todos os candidatos e ordene pelo centroide. Os de centroide
alto saem antes de qualquer prévia. Corte também o que é longo demais para o
gesto do jogo (um clique passa de 0,4 s; uma animação de 0,4 s pede som de
até ~0,8 s), ou apare com `prep` e um `atrim`.

Pronto quando sobram de 3 a 8 candidatos por som pedido.

## 4. Monte as prévias

Pasta: `~/Music/<projeto>/sfx-<assunto>/`, uma subpasta numerada por som
pedido, e `soltos/` com os originais, os `LICENSE` e um `FONTES.txt` (página,
autor, licença, data).

- Cada prévia toca **na ordem em que o jogo vai tocar**: o trio de pesos
  (navegar → confirmar → forte), o par sobe → pausa → desce, o ciclo fecha →
  abre. Monte com `monta`.
- Junto de cada candidato, a versão `_mais-grave` (`prep` com fator 0,75).
- Som que vai tocar junto de outro que já está no jogo ganha uma prévia com os
  dois misturados, na defasagem real.
- Nome do arquivo = o que ele é (`2_mais-grave_maximize-minimize_008.ogg`): é
  pelo nome que o dono responde.

Pronto quando cada subpasta tem prévias numeradas e `soltos/` tem a licença de
todo original usado.

## 5. Pergunte e itere

Liste as subpastas, uma linha por prévia, e pergunte qual ele quer em cada
uma. Se ele recusar todas de uma pasta, pergunte a direção (mecânico demais,
eletrônico de menos, longo demais) e monte a rodada nova em `<pasta>-v2/`,
**sem apagar a anterior**: o dono já voltou à primeira rodada depois de ouvir
a segunda.

Pronto quando cada som pedido tem uma prévia escolhida pelo nome.

## 6. Entregue os escolhidos

- `escolhidos/`, na pasta da rodada: um arquivo por som, com o nome que o jogo
  vai usar, feito com o mesmo `prep` (fator e pico) da prévia escolhida. O
  briefing da implementação diz para copiar sem reprocessar.
- Uma linha de crédito por pacote, no formato que o repo já usa (no
  five-sols-on-mars, o `README.md`), dizendo se o som foi alterado
  ("pitched down").
- Proponha a rodada nova da nota `efeitos-sonoros-cc0`, com o que o dono
  escolheu e recusou (skill `research`).

Pronto quando todo som escolhido está em `escolhidos/` com a linha de crédito
pronta.
