---
name: domain-modeling
description: Build and sharpen a project's domain model, whose glossary and decisions (ADRs) live in the Obsidian vault, not in the repo. Use when discussing codebase terminology, resolving what a term means, or recording an ADR or changing one (which means superseding it).
metadata:
  surfaces: "code"
  upstream: "https://github.com/mattpocock/skills"
  upstream-path: "skills/engineering/domain-modeling"
  upstream-commit: "0ab1b63a410a03d3627979a109c8695de27af954"
  vendored-at: "2026-09-21"
  reescrita: "2026-10"
---

# Domain Modeling

Actively build and sharpen the project's domain model as you design. This is the *active* discipline: challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise. (Merely *reading* the glossary for vocabulary is not this skill: that's a one-line habit any skill can do. This skill is for when you're changing the model, not just consuming it.)

## Where the model lives

The glossary and the ADRs live in the vault, in the project's folder, never in the repo:

```
~/ObsidianVault/projects/<project>/
├── glossario.md          ← the glossary
└── decisoes/
    ├── 0001-slug.md      ← the ADRs
    └── 0002-slug.md
```

Find the project before writing anything:

1. If the repo has `docs/agents/domain.md`, read it. It names the glossary, the `decisoes/` folder and anything else a new decision must touch. Follow it.
2. Otherwise, the project is the `projects/<project>/` that the repo's contract (`AGENTS.md`, `CLAUDE.md`) cites.
3. Otherwise, ask which project.

Never create `CONTEXT.md`, `CONTEXT-MAP.md` or `docs/adr/` in the repo: a second home for the model is a second source of truth. Write only to the glossary and to `decisoes/`, plus whatever the repo's `docs/agents/domain.md` explicitly asks for (a line in the project's MOC, for instance). The vault's own rules are in `~/ObsidianVault/AGENTS.md`.

Write in the language the existing notes use.

Create the files lazily, only when you have something to write. A project with no `glossario.md` gets one when its first term is resolved, shaped like another project's glossary in the vault. An empty `decisoes/` takes its format from the most recent ADR of another project.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in the glossary, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account': do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible. Which is right?"

### Update the glossary inline

When a term is resolved, update the glossary right there. Don't batch these up: capture them as they happen.

The glossary states its own format and what earns a place in it; read its opening before adding a term, and copy the shape of the entries already there. It is a glossary and nothing else: not a spec, not a scratch pad, not a log of decisions. A decision goes to `decisoes/`, and the glossary entry links to it.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful.
2. **Surprising without context**: a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons.

If a decision is easy to reverse, skip it: you'll just reverse it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond "we did the obvious thing."

What tends to qualify:

- **Architectural shape.** "We're using a monorepo." "The write model is event-sourced, the read model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider, deployment target. Not every library: just the ones that would take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; other contexts reference it by ID only." The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path.** "We're using manual SQL instead of an ORM because X." Anything where a reasonable reader would assume the opposite. These stop the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of compliance requirements." "Response times must be under 200ms because of the partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** If you considered GraphQL and picked REST for subtle reasons, record it; otherwise someone will suggest GraphQL again in six months.

## Writing an ADR

- **Number**: the highest `NNNN` in `decisoes/` plus one. File name `NNNN-slug-in-kebab-case.md`.
- **Format by example**: open the most recent ADR in the folder and copy its shape: the frontmatter keys (`tipo`, `status`, `decidido-em`, `origem`, and `supersede` when it applies) and the sections it uses. Don't bring a template from elsewhere.
- **An ADR is never edited once written.** To change a decision, write a new ADR that supersedes it. `supersede:` names the old one and how much of it goes: `"[[NNNN-slug]] — parcial: <which clause>"`, and the old one stays `vigente`; or `"[[NNNN-slug]] — inteira"`, and then the old one's frontmatter alone changes, to `status: supersedida` plus `supersedida-por: "[[new-slug]] — inteira"`. Look for an existing supersede in the folder and match it.
- **If the decision contradicts an ADR in force**, say so to the user before writing, and make the new ADR supersede the clause it contradicts.
