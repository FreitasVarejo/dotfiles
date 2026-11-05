---
name: improve-codebase-architecture
description: Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.
disable-model-invocation: true
metadata:
  surfaces: "code"
  upstream: "https://github.com/mattpocock/skills"
  upstream-path: "skills/engineering/improve-codebase-architecture"
  upstream-commit: "0ab1b63a410a03d3627979a109c8695de27af954"
  vendored-at: "2026-09-21"
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities**: refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This command is _informed_ by the project's domain model and built on a shared design vocabulary:

- Call the Skill tool with "codebase-design" for the architecture vocabulary (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Use these terms exactly in every suggestion, and don't drift into "component," "service," "API," or "boundary."
- The project's glossary gives names to good seams; its ADRs record decisions this command should not re-litigate. Both live in the vault, where the repo's `docs/agents/domain.md` points.

## Process

### 1. Explore

**Scope before you scan: YAGNI.** Deepening a module pays off by making future changes to it easier, so put extra weight on the parts of the codebase that have recently changed. Decide *where* to look before you look:

- If the user named a direction (a module, a subsystem, a pain point), take it, and skip the inference below.
- Otherwise, walk back a good stretch of the commit history (`git log --oneline`) to find the codebase's hot spots, the files and areas that keep coming up, and let those paths pull your attention first. If the changes are scattered with no clear hot spot, widen the net.

Read the project's glossary and any ADRs in the area you're touching first, at the paths the repo's `docs/agents/domain.md` gives.

Read the project's earlier reviews as well. The project is the one named in the arguments, or else the one `vault-vinculos repo .` links to this repo (ask when it links several). Its earlier reviews are the `tipo: registro` notes at the project's root whose `origem:` names this skill, and the tasks that cite each one, archived ones included, say what became of every candidate. Leave out a candidate whose task was archived `dropped` unless the code has since changed what its reason rests on. An earlier review's files and line numbers describe its `commit:`: measure again before you repeat a finding.

Then spawn a sub-agent to walk the codebase. Don't follow rigid heuristics; explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow**, with an interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the OS temp directory so nothing lands in the repo. Resolve the temp dir from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows), and write to `<tmpdir>/architecture-review-<timestamp>.html` so each run gets a fresh file. Open it for the user (`xdg-open <path>` on Linux, `open <path>` on macOS, `start <path>` on Windows) and tell them the absolute path.

The report uses **Tailwind via CDN** for layout and styling, and **Mermaid via CDN** for diagrams where a graph/flow/sequence reliably communicates the structure. Mix Mermaid with hand-crafted CSS/SVG visuals: use Mermaid when relationships are graph-shaped (call graphs, dependencies, sequences), and hand-built divs/SVG when you want something more editorial (mass diagrams, cross-sections, collapse animations). Each candidate gets a **before/after visualisation**. Be visual.

For each candidate, render a card with:

- **Files**: which files/modules are involved
- **Problem**: why the current architecture is causing friction
- **Solution**: plain English description of what would change
- **Benefits**: explained in terms of locality and leverage, and how tests would improve
- **Before / After diagram**: side-by-side, custom-drawn, illustrating the shallowness and the deepening
- **Recommendation strength**: one of `Strong`, `Worth exploring`, `Speculative`, rendered as a badge

End the report with a **Top recommendation** section: which candidate you'd tackle first and why.

**Use the glossary's vocabulary for the domain, and the `/codebase-design` vocabulary for the architecture.** If the glossary defines "Order," talk about "the Order intake module," not "the FooBarHandler," and not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly in the card (e.g. a warning callout: _"contradicts ADR-0007, but worth reopening because…"_). Don't list every theoretical refactor an ADR forbids.

See [HTML-REPORT.md](HTML-REPORT.md) for the full HTML scaffold, diagram patterns, and styling guidance.

**Record the review in the vault** once the HTML is written, without asking. Where notes and attachments go is the vault's rule (`~/ObsidianVault/AGENTS.md`); this skill adds the name and the content:

- `projects/<project>/revisao-de-arquitetura-<YYYY-MM-DD>.md`, with `tipo: registro`, `data:`, `commit:` (the HEAD you reviewed), `origem:` (this skill and the scope) and `anexo:`. The body carries every candidate in markdown (files with line numbers, problem, solution, strength) and the top recommendation: a later chat reads this note, not the HTML.
- `projects/<project>/anexos/revisao-de-arquitetura-<YYYY-MM-DD>/` holds the HTML, with the date in each file name, since attachments resolve by file name.

The note is a photo of one commit and stays as written; what becomes of each candidate goes in its task (step 3). On a machine whose vault is another one (the guard in `~/dotfiles/AGENTS.md`, under `## Agent skills`), the review stays in the temp dir.

Do NOT propose interfaces yet. After the note is written, ask the user: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, open its task before the grilling starts, one task per candidate picked: call the Skill tool with "freitask" in the review's project, with a body that cites the review note by wikilink, then move the task to Refinando (`freitask set <id> --status abstract`). The task carries the grilling across chats: write each decision into its body as it settles.

Then call the Skill tool with "grilling" to walk the decision tree with them: constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive.

Side effects happen inline as decisions crystallize; call the Skill tool with "domain-modeling" to keep the domain model current as you go:

- **Naming a deepened module after a concept not in the glossary?** Add the term to the glossary.
- **Sharpening a fuzzy term during the conversation?** Update the glossary right there.
- **User rejects the candidate?** Write the reason into its task and archive it with `freitask archive <id> dropped`: that reason is what keeps the next review from re-suggesting it. Offer an ADR only when the reason also passes the three tests in the "domain-modeling" skill.
- **Want to explore alternative interfaces for the deepened module?** Call the Skill tool with "codebase-design" and use its design-it-twice parallel sub-agent pattern.
- **Design settled?** It is already in the task: move it to Refinada (`freitask set <id> --status tip`), and follow the repo's `docs/agents/issue-tracker.md` for whatever else the work needs.
