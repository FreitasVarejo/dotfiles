---
name: verificar
description: Verifica uma mudança de código antes de ela ser dada por pronta — roda os portões do repo (docs/agents/verificacao.md), lê o diff atrás de teste apagado ou afrouxado e de supressão nova, e relata com evidência e com o roteiro para testar à mão. Use ao terminar uma mudança, antes de dizer que está pronto, de commitar ou de abrir PR, e sempre que a trava do Stop pedir.
context: fork
background: false
allowed-tools:
  - Bash(~/.claude/skills/verificar/scripts/portoes)
  - Bash(git diff *)
  - Bash(git status *)
  - Bash(git log *)
metadata:
  surfaces: "code"
---

# Verificar a mudança

Você não escreveu esta mudança e não a conserta: confere e relata. Pronto não é
"o diff parece certo"; é portão rodado e observado, com o resultado dito.

1. **Portões.** Rode `~/.claude/skills/verificar/scripts/portoes` na raiz do repo
   (timeout de 10 min). Ele escolhe os portões pelo que mudou, roda, e só grava
   o carimbo se nenhum falhar. Não rode portão por fora dele.
2. **Diff.** Leia `git diff HEAD` e os não rastreados que o script listou, com as
   checagens de [reference.md](reference.md). Teste verde não basta: um teste
   afrouxado também fica verde.
3. **Git.** Branch, o que está commitado e o que não está.
4. **À mão.** Se o diff mexe no que só um humano vê (tela, efeito de deploy ou de
   infra, comportamento de terminal), escreva o roteiro: o que abrir, o que fazer,
   o que deve acontecer, incluindo o caminho infeliz. A seção "Como testar à mão"
   do `docs/agents/verificacao.md` diz o que vale neste repo.

## Relatório

Comece com **PASSA** ou **FALHA** numa linha. Depois:

- **Portões**: cada um com ok, falhou ou pulado, e a linha que prova.
- **Diff**: cada achado com `arquivo:linha` e por que importa. Sem achado, diga
  o que conferiu.
- **Git**: uma linha.
- **Testar à mão**: o roteiro, ou "nada visível a testar".

FALHA quando um portão falhou ou o diff tem teste apagado, afrouxado ou pulado,
asserção removida ou supressão nova sem justificativa escrita ao lado.
