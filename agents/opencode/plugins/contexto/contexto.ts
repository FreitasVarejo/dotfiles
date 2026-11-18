// A lógica do plugin `contexto`, sem nenhuma dependência do OpenCode: só `node:` e o disco.
// Fica separada de `server.ts` para o teste de `agents/tests/` carregá-la no Node.
// Escreva só sintaxe que o Node apaga (sem enum nem parameter property) e importe com `.ts`.
//
// O que o Claude Code carrega sozinho e o OpenCode não:
// - regras de `.claude/rules/*.md` com `paths:`, quando um arquivo casa;
// - a memória de `~/.claude/projects/<slug>/memory/`;
// - o `CLAUDE.md` com `@imports`.
import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from "node:fs"
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path"

/** Um `put` de `instructions.entry` do OpenCode: a chave é `[a-z0-9][a-z0-9._-]*`. */
export type Entry = { key: string; value: string }

/** Teto do OpenCode por entrada é 256 KiB; fica abaixo, com folga para o JSON. */
const MAX_BYTES = 200_000
/** Teto do Claude Code para o `MEMORY.md` carregado na partida. */
const MEMORY_MAX_LINES = 200
/** Cadeia de `@imports`: o `CLAUDE.md` é o nível 0, o mesmo limite do Claude Code. */
const MAX_IMPORT_DEPTH = 5

function readText(file: string): string | undefined {
  try {
    return statSync(file).isFile() ? readFileSync(file, "utf8") : undefined
  } catch {
    return undefined
  }
}

function isDir(path: string): boolean {
  try {
    return statSync(path).isDirectory()
  } catch {
    return false
  }
}

function inside(parent: string, child: string): boolean {
  const rel = relative(parent, child)
  return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel))
}

function realOr(path: string): string {
  try {
    return realpathSync(path)
  } catch {
    return resolve(path)
  }
}

export function capBytes(text: string, note: string): string {
  if (Buffer.byteLength(text, "utf8") <= MAX_BYTES) return text
  return Buffer.from(text, "utf8").subarray(0, MAX_BYTES).toString("utf8") + "\n\n[" + note + "]"
}

/** Chave de entrada a partir de um caminho ou nome: minúsculas, só `[a-z0-9._-]`, começando por alfanumérico. */
export function keyOf(prefix: string, name: string): string {
  const body = name.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^[-._]+|[-._]+$/g, "")
  return body ? prefix + "-" + body : prefix
}

// ---------------------------------------------------------------------------------------------
// Projeto e memória

export type Project = {
  /** A raiz da cópia de trabalho: onde estão `.claude/rules/` e o `CLAUDE.md` do projeto. */
  root: string
  /** A raiz do repo principal: um worktree usa a memória do repo de onde saiu. */
  canonical: string
}

/** Sobe de `dir` até achar `.git` (pasta ou arquivo de worktree). Sem git, o projeto é a própria pasta. */
export function findProject(dir: string): Project {
  for (let current = resolve(dir); ; current = dirname(current)) {
    const git = join(current, ".git")
    if (existsSync(git)) return { root: current, canonical: canonicalOf(current, git) }
    if (dirname(current) === current) return { root: resolve(dir), canonical: resolve(dir) }
  }
}

function canonicalOf(root: string, git: string): string {
  const text = isDir(git) ? undefined : readText(git)
  const gitdir = text?.match(/^gitdir:\s*(.+?)\s*$/m)?.[1]
  const linked = gitdir ? resolve(root, gitdir).match(/^(.*)[\\/]\.git[\\/]worktrees[\\/][^\\/]+$/) : null
  return linked ? linked[1] : root
}

/** O nome da pasta de projeto do Claude Code: todo caractere fora de `[A-Za-z0-9]` vira `-`. */
export function projectSlug(path: string): string {
  return path.replace(/[^a-zA-Z0-9]/g, "-")
}

export function memoryDir(home: string, project: Project): string {
  return join(home, ".claude", "projects", projectSlug(project.canonical), "memory")
}

/** A entrada `memoria`: o diretório (para o modelo gravar) e o `MEMORY.md` se houver. Sempre existe. */
export function memoryEntry(dir: string, home: string): Entry {
  const shown = dir.startsWith(home + sep) ? "~" + dir.slice(home.length) : dir
  const index = readText(join(dir, "MEMORY.md"))?.trim()
  const lines = index ? index.split("\n") : []
  const body =
    lines.length === 0
      ? "(ainda não há memória gravada neste projeto)"
      : lines.slice(0, MEMORY_MAX_LINES).join("\n") +
        (lines.length > MEMORY_MAX_LINES ? "\n[MEMORY.md cortado nas primeiras " + MEMORY_MAX_LINES + " linhas]" : "")
  const text = [
    "Memória persistente deste projeto, compartilhada com o Claude Code. Diretório: " + shown,
    "Os arquivos de memória citados no índice se leem sob demanda, com `read`. Como gravar: as instruções de memória.",
    "",
    "MEMORY.md:",
    body,
  ].join("\n")
  return { key: "memoria", value: capBytes(text, "memória cortada") }
}

// ---------------------------------------------------------------------------------------------
// Regras de `.claude/rules/*.md` com `paths:`

export type Rule = { file: string; name: string; paths: string[]; body: string }

/** Parte `a, b` em itens, sem partir dentro de `{...}`. */
function splitList(text: string): string[] {
  const items: string[] = []
  let depth = 0
  let current = ""
  for (const ch of text) {
    if (ch === "{") depth++
    if (ch === "}") depth = Math.max(0, depth - 1)
    if (ch === "," && depth === 0) {
      items.push(current)
      current = ""
    } else current += ch
  }
  items.push(current)
  return items
}

function unquote(item: string): string {
  const text = item.trim()
  const quoted = text.match(/^(["'])(.*)\1$/)
  return quoted ? quoted[2] : text
}

/** O frontmatter da regra: só a chave `paths`, em lista, em lista de uma linha ou em texto corrido. */
export function parseRule(file: string, name: string, text: string): Rule | undefined {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/)
  if (!match) return undefined
  const lines = match[1].split(/\r?\n/)
  const at = lines.findIndex((line) => /^paths\s*:/.test(line))
  if (at < 0) return undefined
  const inline = lines[at].replace(/^paths\s*:/, "").trim()
  let paths: string[] = []
  if (inline) {
    const flow = inline.match(/^\[(.*)\]$/)
    paths = splitList(flow ? flow[1] : inline).map(unquote)
  } else {
    for (const line of lines.slice(at + 1)) {
      const item = line.match(/^\s*-\s+(.*)$/)
      if (item) paths.push(unquote(item[1]))
      else if (line.trim() !== "" && !/^\s*#/.test(line)) break
    }
  }
  paths = paths.filter((p) => p !== "")
  if (paths.length === 0) return undefined
  return { file, name, paths, body: match[2].trim() }
}

/** Lê `.claude/rules/**.md` do projeto; só entram as regras com `paths:`. */
export function loadRules(root: string): Rule[] {
  const base = join(root, ".claude", "rules")
  const rules: Rule[] = []
  const walk = (dir: string) => {
    let names: string[]
    try {
      names = readdirSync(dir).sort()
    } catch {
      return
    }
    for (const name of names) {
      const path = join(dir, name)
      if (isDir(path)) walk(path)
      else if (name.endsWith(".md")) {
        const text = readText(path)
        const rule = text === undefined ? undefined : parseRule(path, relative(base, path), text)
        if (rule) rules.push(rule)
      }
    }
  }
  walk(base)
  return rules
}

/** Glob no estilo do `paths:` do Claude Code: `**`, `*`, `?`, `{a,b}` e `[abc]`, relativo à raiz do projeto. */
export function globToRegExp(glob: string): RegExp {
  let g = glob.replace(/^\.\//, "").replace(/^\//, "")
  if (g.endsWith("/")) g += "**"
  let out = ""
  let braces = 0
  for (let i = 0; i < g.length; i++) {
    const ch = g[i]
    if (ch === "*") {
      if (g[i + 1] === "*") {
        if (g[i + 2] === "/") {
          out += "(?:.*/)?"
          i += 2
        } else {
          out += ".*"
          i += 1
        }
      } else out += "[^/]*"
    } else if (ch === "?") out += "[^/]"
    else if (ch === "{") {
      braces++
      out += "(?:"
    } else if (ch === "}" && braces > 0) {
      braces--
      out += ")"
    } else if (ch === "," && braces > 0) out += "|"
    else if (ch === "[") {
      const end = g.indexOf("]", i + 2)
      if (end < 0) out += "\\["
      else {
        const cls = g.slice(i + 1, end)
        out += "[" + (cls.startsWith("!") ? "^" + cls.slice(1) : cls).replace(/\\/g, "\\\\") + "]"
        i = end
      }
    } else out += ch.replace(/[.+^$()|\\/]/g, "\\$&")
  }
  return new RegExp("^" + out + "$")
}

export function ruleMatches(rule: Rule, relPath: string): boolean {
  return rule.paths.some((glob) => globToRegExp(glob).test(relPath))
}

/** A entrada de uma regra que casou com o arquivo: chave `regra-<nome>`, texto sem o frontmatter. */
export function ruleEntry(rule: Rule, root: string): Entry {
  const shown = relative(root, rule.file)
  const text =
    "Regra do projeto (" + shown + "), vale para arquivos que casam com: " + rule.paths.join(", ") + "\n\n" + rule.body
  return { key: keyOf("regra", rule.name.replace(/\.md$/, "")), value: capBytes(text, "regra cortada") }
}

/** As regras do projeto que casam com os caminhos tocados (absolutos ou relativos à `cwd`). */
export function rulesFor(project: Project, cwd: string, touched: string[]): Entry[] {
  const rules = loadRules(project.root)
  if (rules.length === 0) return []
  const rels = touched
    .map((p) => resolve(cwd, p))
    .filter((abs) => inside(project.root, abs) && !isDir(abs))
    .map((abs) => relative(project.root, abs).split(sep).join("/"))
  return rules.filter((rule) => rels.some((rel) => ruleMatches(rule, rel))).map((rule) => ruleEntry(rule, project.root))
}

/** Os caminhos que uma ferramenta de arquivo tocou: `path` em read/edit/write; os cabeçalhos do `patch`. */
export function touchedPaths(tool: string, input: unknown): string[] {
  if (typeof input !== "object" || input === null) return []
  const fields = input as Record<string, unknown>
  if (tool === "read" || tool === "edit" || tool === "write") return typeof fields.path === "string" ? [fields.path] : []
  if (tool === "patch" && typeof fields.patchText === "string") {
    return [...fields.patchText.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to):\s*(.+?)\s*$/gm)].map(
      (m) => m[1],
    )
  }
  return []
}

// ---------------------------------------------------------------------------------------------
// CLAUDE.md com @imports

/** Troca por espaços o que está em bloco ou em trecho de código: `@` ali não é import. */
export function maskCode(text: string): string {
  const out: string[] = []
  let fence: string | undefined
  for (const line of text.split("\n")) {
    const mark = line.match(/^\s*(```+|~~~+)/)
    if (fence) {
      if (mark && mark[1][0] === fence[0] && mark[1].length >= fence.length) fence = undefined
      out.push(" ".repeat(line.length))
    } else if (mark) {
      fence = mark[1]
      out.push(" ".repeat(line.length))
    } else out.push(line.replace(/`[^`\n]*`/g, (span) => " ".repeat(span.length)))
  }
  return out.join("\n")
}

/** Os alvos `@caminho` de um texto, na ordem em que aparecem, sem os de código. */
export function importTargets(text: string): string[] {
  const targets: string[] = []
  for (const match of maskCode(text).matchAll(/(?:^|\s)@(\S+)/g)) {
    const target = match[1].replace(/[.,;:!?)\]}"']+$/, "")
    if (target) targets.push(target)
  }
  return targets
}

function resolveImport(target: string, from: string, home: string): string {
  if (target === "~" || target.startsWith("~/")) return join(home, target.slice(1))
  return resolve(dirname(from), target)
}

/**
 * O `CLAUDE.md` com os `@imports` expandidos: cada arquivo vira um bloco "Contents of <caminho>",
 * o importado logo depois de quem o importou. Import que sai da home é ignorado, com aviso no texto;
 * além de 5 níveis também.
 */
export function expandClaudeMd(file: string, home: string): string {
  const parts: string[] = []
  const seen = new Set<string>()
  const homeReal = realOr(home)
  const visit = (path: string, depth: number, parent?: string) => {
    const text = readText(path)
    if (text === undefined) return
    seen.add(realOr(path))
    parts.push("Contents of " + path + (parent ? " (imported from " + parent + ")" : "") + ":\n\n" + text.trim())
    for (const target of importTargets(text)) {
      const next = resolveImport(target, path, home)
      const exists = readText(next) !== undefined
      if (!inside(homeReal, realOr(next))) {
        // Fora da home nem o arquivo se lê; avisa se o alvo existe ou se tem cara de caminho (`@../x.md`).
        if (exists || target.includes("/")) {
          parts.push("[import ignorado, fora da home: @" + target + " em " + path + "]")
        }
      } else if (!exists || seen.has(realOr(next))) {
        continue
      } else if (depth >= MAX_IMPORT_DEPTH) {
        parts.push("[import ignorado, passa de " + MAX_IMPORT_DEPTH + " níveis: @" + target + " em " + path + "]")
      } else visit(next, depth + 1, path)
    }
  }
  visit(file, 0)
  return capBytes(parts.join("\n\n"), "CLAUDE.md cortado")
}

/**
 * Os `CLAUDE.md` da home até a pasta da sessão (fora da home, só a pasta), o mais geral primeiro.
 * Pasta com `AGENTS.md` ao lado fica de fora: o OpenCode já lê esse arquivo sozinho.
 */
export function claudeMdEntries(cwd: string, home: string): Entry[] {
  const start = resolve(cwd)
  const base = resolve(home)
  const chain: string[] = []
  for (let current = start; ; current = dirname(current)) {
    chain.unshift(current)
    if (current === base || dirname(current) === current) break
  }
  const dirs = inside(base, start) ? chain : [start]
  const entries: Entry[] = []
  for (const dir of dirs) {
    const file = join(dir, "CLAUDE.md")
    if (readText(file) === undefined || existsSync(join(dir, "AGENTS.md"))) continue
    const where = inside(base, dir) ? relative(base, dir) : dir
    entries.push({ key: keyOf("claude-md", where === "" ? "home" : where), value: expandClaudeMd(file, home) })
  }
  return entries
}
