---
name: revisar-entrega
description: Revisa a entrega de um hackathon de jogo ou app interativo (spec, calibração, build) contra o enunciado e os critérios do júri em quatro eixos, consolida com decisões numeradas para o dono e, depois das respostas, aplica no vault e escreve o briefing do chat que implementa.
disable-model-invocation: true
argument-hint: "<projeto do vault ou caminho da spec>"
metadata:
  surfaces: "code"
---

# Revisar a entrega contra o desafio

A sessão julga e consolida, os auditores leem, e o disco só muda depois que o dono responde às decisões.

## 0. Entradas

Junte os caminhos e confira que cada um existe:

- a spec da entrega, com o glossário e as decisões dela;
- o enunciado do desafio e o regulamento com os critérios do júri;
- as pesquisas que a spec cita, cada uma no seu `index.md`;
- o que roda: página de calibração ou simulação, build publicado, repo. Artifact se lê com o `Artifact` (`action: read`) e vai salvo em disco antes do despacho, porque o auditor só lê arquivo;
- o que está em construção agora: o repo do projeto (`vault-vinculos repos <projeto>`), a branch, os últimos commits e se outro chat está implementando.

O objeto da revisão é a spec e a calibração. O código em construção é do chat que implementa e vira teste de aceite (`aceite`) quando a fatia fechar. O build publicado entra só para conferir uma afirmação da spec, e se abre pelo endereço que a submissão dá ao júri, com os parâmetros que ele traz.

Pronto quando cada entrada tem caminho, ou o dono disse que ela não existe.

## 1. Um auditor por eixo, em paralelo

Despache os quatro `auditor` numa mensagem só. Os eixos e as perguntas de cada brief estão em [eixos.md](eixos.md).

Cada brief leva:

- as entradas do eixo;
- uma pasta própria no scratchpad (`auditor-<eixo>/`) para os scripts, porque auditores que dividem um arquivo se atropelam;
- o formato da volta:
  - os achados, do mais grave para o menos, cada um com evidência (arquivo:linha e trecho curto);
  - em cada achado, se mexe em restrição ou em proposta da spec, quanto custa mudar antes do congelamento e a correção numa frase;
  - no fim, até 5 linhas do que já é forte.

## 2. Conferir antes de mostrar

Enquanto os relatórios chegam, reproduza a evidência de cada achado grave: rode a simulação, o `git`, leia a linha. O achado reproduzido leva a marca **conferido**; o outro vai como achado do auditor.

O fato científico que o vault não resolve e que muda texto de tela ou mecânica vai para um `coletor-web`, na fonte primária. O relatório dele é bruto da skill `research`.

Pronto quando todo achado grave está conferido ou marcado como não reproduzido.

## 3. Consolidar

Uma lista só, nesta ordem:

1. as notas prováveis por critério do júri, com o que puxa cada uma para baixo e o que a sobe barato;
2. o que mexe no que está sendo construído agora;
3. números e calibração, dizendo de quem é cada número quando a spec diz;
4. texto de tela, numa tabela "a spec diz / a fonte diz / texto sugerido";
5. submissão e apresentação;
6. as decisões do dono, numeradas Q1, Q2…, com o mecanismo explicado e a opção recomendada primeiro.

A consolidação termina nas decisões. Achado que chega depois (o do coletor, em geral) reabre só a seção que ele afeta. Quando o resumo passa de uma tela, ofereça a página.

## 4. Aplicar, com as respostas

Resposta ambígua: aplique a leitura mais próxima da recomendação e diga qual leitura fez.

- **Vault:**
  - antes de escrever, leia `~/ObsidianVault/AGENTS.md` e compare a spec com o último checkpoint (`vaultgit diff HEAD -- <spec>`), porque outra sessão pode estar editando a mesma spec;
  - aplique as trocas por script, exigindo que cada trecho original apareça exatamente uma vez;
  - a decisão entra com "(dono, DD/MM)" e o porquê;
  - o que não foi decidido entra em "Em aberto" como ponteiro para a página da revisão;
  - a pesquisa entra pela skill `research`;
  - no fim, rode `freitask doctor`.
- **Repo:** é do chat que implementa. Leia o que já está no `main` (log, modelo, tabela de textos) para o briefing pedir só o que falta e apontar cada texto errado pela chave.
- **Briefing:** um arquivo no scratchpad, para o dono colar no chat que implementa, nesta ordem:
  1. recopiar a spec, se o repo guarda uma cópia;
  2. o que entra, com o porquê;
  3. os textos errados;
  4. o que fica de fora (recusado ou ainda não decidido);
  5. o contrato do repo, como ponteiro.

Pronto quando cada resposta do dono virou mudança no vault ou linha do briefing, e o relato final diz qual.
