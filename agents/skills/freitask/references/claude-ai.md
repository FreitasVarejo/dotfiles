# A skill no claude.ai

Lá o vault não está no disco e o `freitask` não roda: o bloco "Contexto desta
sessão" chega como texto, e nenhum comando da skill funciona. Tudo passa pelo
conector do vault (`obsidian-web-mcp`), com os caminhos relativos a
`~/ObsidianVault/`. Cada passo da skill troca assim:

| na skill | no claude.ai |
|---|---|
| "projetos do vault e o escopo de cada um" | os projetos são as pastas `projects/<p>/` que têm `tasks/`; o escopo é o primeiro parágrafo depois do H1 do MOC, `projects/<p>/<p>.md` |
| as pistas (pasta, repo, branch) | não existem: o projeto sai só do escopo e da conversa |
| `contexto.sh tasks <projeto>` | liste `projects/<p>/tasks/` e leia de cada arquivo a linha `> [!fase] Título`, que vem depois do frontmatter quando a task tem um |
| `freitask kebab` | monte o id: minúsculas, acento dobrado (`ação` → `acao`), palavras ligadas por hífen, sem outra pontuação. Procure o `<id>.md` no vault inteiro, inclusive em `tasks/archived/`: ele precisa estar livre |
| `freitask new` e o §4 | escreva `projects/<p>/tasks/<id>.md` de uma vez: o bloco no "Formato do bloco" do `AGENTS.md` do vault (leia-o pelo conector), com callout `todo`, e o corpo do §4 logo abaixo |
| "De onde veio", no §4 | "Aberta em DD/MM numa conversa do claude.ai." |
| `freitask doctor`, no §5 | termine a resposta pedindo ao dono para rodar `freitask rebuild` e depois `freitask doctor` |

O `rebuild` é o que põe a task no `CURRENT.md`; sem ele, ela existe no disco e
some do painel. O `doctor` acusa o que a escrita à mão deixou passar.
