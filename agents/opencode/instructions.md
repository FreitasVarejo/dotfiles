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
