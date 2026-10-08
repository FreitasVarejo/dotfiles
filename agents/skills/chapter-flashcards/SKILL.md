---
name: chapter-flashcards
description: Estuda um capítulo de livro técnico no vault Obsidian do usuário — cria um .md por seção, gera 100 flashcards reais no formato do repeater (shaankhosla/repeater) distribuídos por peso entre as seções, e monta a página do capítulo. Use sempre que o usuário pedir para "fazer/preparar/começar o capítulo N", gerar flashcards, cards, exercícios repeater ou questões de um capítulo, montar a estrutura de um capítulo no vault, ou mencionar o Sybex/LPIC-1 junto com cards ou seções — mesmo que ele não diga "skill" nem cite o repeater.
metadata:
  surfaces: "code,web"
  upstream: "claude.ai (skill do dono, My Uploads)"
  upstream-path: "chapter-flashcards"
  upstream-commit: "skill_01C6nq5nh8pL1thRneTBwEZQ sincronizada em 2026-09-15"
  vendored-at: "2026-09-21"
---

# Chapter Flashcards

Transforma um capítulo do livro em material de estudo dentro do vault Obsidian:

1. uma pasta por capítulo, com um `.md` por seção do livro;
2. um orçamento de **100 cards reais** no capítulo, distribuídos por peso entre as seções, escritos no fim de cada arquivo de seção;
3. uma página do capítulo (`README.md`) ligando tudo.

Pré-requisitos esperados: um MCP do Obsidian (listar, ler, escrever, anexar, editar, buscar), acesso ao livro (PDF) e, se disponível, a documentação do repeater. Se o repositório/doc do repeater estiver no contexto, ele vale mais que `references/repeater-format.md` — o formato pode ter mudado.

## Antes de tudo: leia as referências

- `references/repeater-format.md` — como o repeater conta e parseia cards, e as armadilhas que geram cards fantasmas. **Obrigatório** antes de escrever qualquer card.
- `references/vault-conventions.md` — nomes de arquivos, frontmatter, templates da seção e do README do capítulo, estilo dos cards.

## Parâmetros

Descubra pelo contexto antes de perguntar. Padrões do vault atual:

| Parâmetro | Padrão |
| :--- | :--- |
| Raiz do livro no vault | `study/lpic-sybex-study-guide` |
| Orçamento por capítulo | 100 cards reais |
| Idioma dos cards e resumos | português (termos técnicos e comandos como o exame cobra) |
| Tipos de card | `Q:`/`A:` e `C:` — nunca múltipla escolha |

Na raiz do livro, se existirem, leia `README.md` e `prompts/CARD-BUDGET.md`: eles guardam as distribuições dos capítulos anteriores e a lista de assuntos já cobertos em outro lugar. `prompts/CREATE-EXERCISE-LIST.md` é de uma fase antiga (múltipla escolha) — ignore o formato dele.

## Fluxo

### Fase 0 — Inventário

1. Liste a raiz do livro e a pasta do capítulo, se já existir.
2. Leia os arquivos de seção existentes do capítulo. Anote, para cada um: se tem anotações do usuário, se já tem `## Repeater Exercises` e quantos cards reais tem (use `scripts/count_cards.py` se houver shell; senão conte à mão pela regra de contagem).
3. Diga ao usuário, em 2–4 linhas, o que encontrou antes de seguir.

### Fase 1 — Seções a partir do livro

1. Localize o capítulo no PDF (sumário + páginas). Com shell: `pdftotext -layout -f INI -l FIM livro.pdf -`.
2. Determine as **seções de primeiro nível**. Confirme com os cabeçalhos de página, não só com a indentação do sumário: no capítulo 5 do Sybex, sub-headings do sumário eram seções próprias. Não conte "Summary", "Exam Essentials" nem "Review Questions" como seções.
3. Anote para cada seção: título em inglês, páginas e subtópicos.
4. Crie a pasta e os arquivos de seção que faltam, com o template de `vault-conventions.md` (frontmatter + H1, sem card ainda).

**Nunca reescreva as anotações do usuário.** Elas são dele. Em arquivos existentes você só pode (a) adicionar ou substituir a seção `## Repeater Exercises`, que fica no fim, e (b) corrigir um `id` de frontmatter claramente errado — e avisar que fez isso.

### Fase 2 — Orçamento (checkpoint)

Distribua os 100 cards pelo **peso do conteúdo**, não em partes iguais — uma seção pode receber 34 e outra 4. O peso combina:

- tamanho da seção no livro (páginas);
- quanto ela aparece nas Review Questions e nas Exam Essentials do capítulo;
- densidade de coisa "decorável" que a prova cobra (comandos, opções, arquivos, valores, contrastes);
- desconto para o que já é coberto em outro capítulo.

Para achar duplicação, busque no vault os comandos/arquivos principais da seção (ex.: `lsmod`, `/etc/fstab`) em outros capítulos e consulte a seção "Evitar duplicação" do `CARD-BUDGET.md`. Assunto já coberto a fundo em outro lugar vira no máximo 1 card de ligação com `[[link]]` dentro de um `A:`.

Dentro de cada seção, orce por subtópico (esses subtópicos viram os `### ` dos cards).

Apresente ao usuário uma tabela `Seção | Páginas | Cards` somando ≤ 100, a lista de subtópicos com seus orçamentos e as duplicações encontradas. **Pare e espere aprovação**, a menos que ele tenha pedido explicitamente para ir direto. Ajustar a divisão é barato; refazer 100 cards não é.

### Fase 3 — Gerar e escrever os cards

Para cada seção, na ordem do livro:

1. Releia o trecho do livro e as anotações do usuário daquela seção. As anotações mostram o que ele achou importante e o vocabulário que usa.
2. Escreva os cards seguindo `vault-conventions.md` e `repeater-format.md`. Priorize, nesta ordem: o que os objetivos do exame e as Exam Essentials cobram; o que as Review Questions cobram (e os erros registrados em `REVIEW_QUESTIONS.md`, se houver); contrastes que caem como pegadinha; valores arbitrários (caminhos, opções, números). Escreva com suas palavras — cards não são trechos copiados do livro.
3. Conte os cards reais da seção. Se passou do orçamento, primeiro converta clozes longos em `Q:`, depois funda cards redundantes; só então corte assunto.
4. Escreva no vault:
   - seção sem `## Repeater Exercises` → anexe ao fim do arquivo;
   - seção com cards existentes → veja "Capítulo que já tem cards" abaixo.
5. Rode a checagem de armadilhas no arquivo resultante (script ou revisão manual contra `repeater-format.md`).

Na primeira seção do capítulo, mostre os cards gerados antes de seguir para as demais, se o usuário não tiver dispensado a validação.

### Fase 4 — Página do capítulo

Crie ou atualize `README.md` da pasta do capítulo com o template de `vault-conventions.md`: objetivos do exame cobertos, tabela de seções com links, orçamento de cards e um resumo das Exam Essentials **escrito por você em português** (um parágrafo curto por tópico) — não transcreva o texto do livro.

Depois, na raiz do livro:
- no `README.md`, mova o capítulo de "ainda não iniciados" para a lista de capítulos, com a tabela de seções;
- no `prompts/CARD-BUDGET.md`, adicione a tabela de distribuição do capítulo e novas entradas em "Evitar duplicação", se houver.

### Fase 5 — Relatório final

Curto: tabela final `Seção | Cards`, total real, arquivos criados/alterados e avisos (armadilhas encontradas nas anotações do usuário, seções sem anotações, divergências entre sumário e páginas). Sugira conferir com `repeater check --plain <pasta-do-capítulo>` — se o número diferir da contagem, alguma armadilha passou.

## Capítulo que já tem cards

O repeater guarda o histórico de revisão pelo hash do texto do card: reescrever um card zera o progresso dele. Então, por padrão, **complete em vez de refazer**:

- conte o que existe por seção e compare com o orçamento;
- mantenha os cards bons como estão (não reformule por estética);
- adicione o que falta para cobrir os subtópicos; corte ou funda só se o capítulo passar de 100;
- substitua a seção inteira apenas se o usuário pedir para refazer.

Para substituir `## Repeater Exercises`, use a edição por texto exato do MCP com o bloco antigo completo como alvo; nunca regrave o arquivo inteiro a partir de uma cópia que possa estar desatualizada.
