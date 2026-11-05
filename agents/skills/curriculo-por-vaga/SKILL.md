---
name: curriculo-por-vaga
description: Deriva o cv.yaml de uma vaga do mestre.yaml sem inventar experiência e lista as lacunas. Use quando o dono pedir o currículo de uma vaga com pasta em curriculo/vagas/.
argument-hint: "<pasta da vaga>"
metadata:
  surfaces: "code"
---

# Currículo por vaga

Do `mestre.yaml` sai o `cv.yaml` de uma vaga. Escolher, ordenar e omitir é com
você; **o texto vem do mestre**. O dono revisa tudo, e o `confere` prova o que
uma revisão cansada deixaria passar.

O argumento é a pasta da vaga, `curriculo/vagas/<x>/`, com o `vaga.md` do dono.
Chame de `<curriculo>` a pasta dois níveis acima: nela moram `mestre.yaml`,
`confere` e `build`. O cabeçalho do mestre diz o formato dos campos. Sem
argumento, liste `~/dev/pessoal/curriculo/vagas/` e pergunte qual.

Um texto do `cv.yaml` é **literal** quando o `confere` o aceita
(`<curriculo>/confere --help` diz o critério).

## 1. Leia

Leia o `vaga.md` e o `mestre.yaml` inteiros. A vaga é o que está no `vaga.md`;
se faltar requisito ali, peça ao dono a descrição. Liste os requisitos da vaga,
cada um com uma marca e o item do mestre que o cobre, citado:

- **coberto**: o mestre tem o item.
- **parcial**: o item cobre uma parte do requisito.
- **sem evidência**: o mestre não tem.

**Pronto quando** todo requisito tem marca e, se coberto ou parcial, a citação.

## 2. Pergunte pelas lacunas

Mostre a lista ao dono e, para cada requisito parcial ou sem evidência,
pergunte se há experiência que o mestre não tem. Abra com uma rodada, uma
pergunta por lacuna, e feche com "o que você fez nos últimos seis meses que o
mestre não tem?". O dono pode pular a rodada; as lacunas seguem para o passo 4.

Cada resposta que traz algo abre uma ramificação, uma pergunta por vez, a
próxima nascida da resposta anterior:

- **fez ou usou**: o quê, em que escala, em produção ou em teste, o problema
  difícil que resolveu.
- **ajudou ou participou**: qual foi o papel dele, o que ele mesmo fez.
- **tecnologia ou atividade vizinha**: o que fez nela. Se cobre o requisito,
  quem decide é ele.
- **projeto pessoal ou curso**: o que construiu ou entregou, e quando.
- **nada**: uma pergunta de categoria mais ampla; depois, a próxima lacuna.

Relacione com o que ele disse antes ("isso é o mesmo que X?"). Duas ou três
tentativas sem nada encerram a lacuna. Papel, escala, número, cargo, tecnologia
e data são do dono: entram como ele disse, e o que ele não disse não entra.

**Pronto quando** cada lacuna virou um item candidato, nas palavras dele, ou
ficou marcada lacuna.

## 3. O mestre muda só por diff

O que a descoberta trouxe entra no `mestre.yaml` antes de entrar no CV. Mostre as
linhas que acrescentaria (em inglês, na entrada a que pertencem, no formato do
cabeçalho do mestre) e grave depois do "ok" do dono. O item confirmado entra sem
marca; `REVISAR` fica para o que diverge entre fontes.

**Pronto quando** o diff foi gravado com "ok", ou nada novo apareceu.

## 4. Plano: aprovação antes de gerar

Mostre, só com seleção e ordem: as entradas de cada seção do `cv.yaml`, o que
fica de fora do mestre e as lacunas que restam. Marque as entradas e os itens
escolhidos que o mestre traz com `REVISAR`. Se a pasta já tem `cv.yaml`, diga que
o plano o substitui.

**Pronto quando** o dono respondeu "ok" ou ajustou o plano. Sem "ok", não gere.

## 5. Gere

Escreva o `cv.yaml` na pasta da vaga. Cada entrada vem de uma entrada do mestre,
com os campos e os bullets dela; nome, contato, `paper`, `updated`, linhas e
bullets de seção vêm iguais do mestre. Encurtar uma lista, fundir dois itens, trocar uma palavra ou
juntar campos de duas entradas gera um item não literal, que só fica com o "ok,
vem destas linhas" do dono (passo 6). Se nenhum item do mestre cobre um
requisito, ele é lacuna, e o CV não o cobre.

**Pronto quando** o plano aprovado está no arquivo.

## 6. Confira antes de mostrar

Rode `<curriculo>/confere <pasta>/cv.yaml`. A prova é a saída dele, não o seu
julgamento.

- **0**: mostre o `cv.yaml` com a linha de resumo do `confere`.
- **1**: para cada item listado, volte ao texto literal do mestre, ou mostre ao
  dono o item com as linhas do mestre de que vem e mantenha-o só com o "ok, vem
  destas linhas". Itens que o dono não aprovou voltam ao literal.
- **2**: diga o erro. O CV não foi conferido.

**Pronto quando** a lista que o `confere` imprime é exatamente a dos itens que o
dono aprovou (vazia, se ele não aprovou nenhum).

## 7. Lacunas

Escreva o `lacunas.md` na pasta da vaga (você pode sobrescrevê-lo; o `vaga.md` é
só do dono). Ele leva:

- os requisitos do passo 1 com a marca final e o item citado;
- o que entrou no mestre nesta rodada;
- cada item não literal aprovado, com as linhas de origem.

**Pronto quando** os três blocos estão escritos e todo requisito do passo 1
aparece. Diga ao dono que o PDF sai de `<curriculo>/build <pasta>/cv.yaml`;
rodá-lo é com ele.
