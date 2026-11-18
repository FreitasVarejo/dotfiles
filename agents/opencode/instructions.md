# Instruções só do OpenCode

Valem para as ferramentas e os agentes do OpenCode; nenhum outro agente lê este arquivo.

## Página HTML (artifact)

- Resposta que rende mais como página (protótipo, relatório, painel, gráfico) vira artifact: `artifact_create`, e `artifact_update` para mudar. Um `index.html` único, com CSS e JS embutidos.
- Gráfico: biblioteca de gráfico carregada por CDN, versão fixa. O artifact abre por `file://`, então ele não lê outro arquivo local por `fetch`; os dados vão dentro do HTML.
- Depois de `artifact_create` ou `artifact_update`, abra o `index.html` no navegador. O arquivo fica em `art_<id>/index.html` dentro de `artifacts/` no diretório `data` de `opencode debug paths`. Abra pelo caminho em disco, nunca pela URL do serviço (ela pede senha).
  - WSL (`/proc/version` cita Microsoft): `wslview <arquivo>`; sem `wslview`, `explorer.exe "$(wslpath -w <arquivo>)"`.
  - Linux: `xdg-open <arquivo>`.
- Diga ao dono o caminho do arquivo, para ele reabrir.

## Esperar uma condição

- Esperar build, deploy ou arquivo: `schedule_create` com o portão `{ run }` (comando de shell), e não laço de `sleep`. A descrição da ferramenta diz os campos.

## Subagente com isolamento

- Subagente que precisa de um diretório só dele: `worktree_create`, e depois `session_move` da sessão filha, pelo id, para o diretório que a ferramenta devolveu.

## Agente `plan`

- Termine o plano com a ferramenta `question`, pedindo a aprovação dele. Aprovado, diga ao dono para trocar de agente com Shift+Tab; o `plan` não edita fora do arquivo de plano.

## Memória do projeto

A memória é a mesma do Claude Code: os dois leem e gravam em `~/.claude/projects/<slug>/memory/`. O bloco `<context key="memoria">` da sessão diz o diretório do projeto e traz o índice `MEMORY.md`; grave nesse diretório e em nenhum outro. Os arquivos de memória citados no índice se leem com `read`, só quando o assunto pede.

- Grave o que vale em outra conversa deste projeto: uma preferência ou correção do dono (`feedback`), quem ele é e como trabalha (`user`), um fato do projeto que o código e o git não mostram (`project`), ou onde achar algo fora do repo (`reference`). Não grave o que se lê no código, o histórico do git, o estado da tarefa em curso nem segredo.
- Dono pedindo para lembrar: grave. Pedindo para esquecer: apague o arquivo e a linha do índice. Memória que você percebeu errada ou velha: corrija ou apague.
- Um fato por arquivo, `<nome-em-kebab>.md`. Antes de criar, veja no índice se já há um sobre o assunto e atualize esse.
- O arquivo começa pelo frontmatter, e o corpo diz o fato. Em `feedback` e `project`, acrescente uma linha `**Why:**` (o motivo) e uma `**How to apply:**` (quando vale):

  ```markdown
  ---
  name: nome-em-kebab
  description: "uma linha: quando esta memória serve"
  metadata:
    type: feedback
  ---

  O fato.

  **Why:** o motivo.

  **How to apply:** quando vale.
  ```

- `MEMORY.md` é só o índice, sem frontmatter: uma linha por arquivo, `- [Título](arquivo.md) — gancho de uma linha`, com até 150 caracteres. Só as primeiras 200 linhas entram na sessão: enxugue antes de passar disso. Ao criar, apagar ou renomear um arquivo de memória, atualize a linha no mesmo passo.
- Gravar é `write` ou `edit` nesses arquivos, e o `edit` pede aprovação do dono.
