// Lógica do rodapé do plugin `claude-ui`: a faixa das travas pendentes e o uso da assinatura.
// Não importa o pacote do OpenCode (só `node:`), para o teste de `agents/tests/` rodá-la no Node.
// Escreva só sintaxe que o Node apaga (sem enum nem parameter property) e importe com `.ts`.
import { execFile } from "node:child_process"
import { realpathSync } from "node:fs"
import { homedir } from "node:os"
import { fileURLToPath } from "node:url"

/** O que as travas ainda cobrariam da sessão: um item por repo a verificar, e o doctor do vault. */
export type Pendentes = { verificar: { root: string; files: number }[]; doctor: boolean }

export const SEM_PENDENTES: Pendentes = { verificar: [], doctor: false }

/** `agents/travas/`, ao lado do plugin no repo: o link em `~/.config/opencode/plugins/` é resolvido antes. */
export function travasDir(here: string = import.meta.url): string {
  const file = realpathSync(fileURLToPath(here))
  return fileURLToPath(new URL("../../../travas/", "file://" + file))
}

function run(script: string, args: string[], timeoutMs: number): Promise<string> {
  return new Promise((resolve) => {
    try {
      execFile(script, args, { timeout: timeoutMs, encoding: "utf8" }, (error, stdout) => resolve(error ? "" : stdout))
    } catch {
      resolve("")
    }
  })
}

/** Lê o `pendente <sessão>` de `verificacao-no-stop` (uma linha `<n>\t<raiz>` por repo): vazio é nada pendente. */
export function parseVerificar(out: string): Pendentes["verificar"] {
  return out
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [files = "0", root = ""] = line.split("\t")
      return { root, files: Number(files) }
    })
    .filter((item) => item.root !== "" && Number.isFinite(item.files))
}

/**
 * Pergunta às travas, o mesmo que o mod `agents/mods/travas-pendentes` do Claude Code. `sessionID` é o da sessão
 * raiz: o toque de uma sessão-filha já vai para o id dela. Falha de uma trava vira "nada pendente".
 */
export async function pendentes(sessionID: string, travas: string = travasDir()): Promise<Pendentes> {
  const [verif, doctor] = await Promise.all([
    run(travas + "verificacao-no-stop", ["pendente", sessionID], 20_000),
    run(travas + "doctor-no-stop", ["pendente", sessionID], 10_000),
  ])
  return { verificar: parseVerificar(verif), doctor: doctor.trim() === "vault" }
}

export function semPendencia(p: Pendentes): boolean {
  return p.verificar.length === 0 && !p.doctor
}

function curto(root: string, home: string): string {
  return home && root.startsWith(home + "/") ? "~" + root.slice(home.length) : root
}

/** A faixa do mod: o que o Stop cobra. Nada quando não há o que cobrar. */
export function faixa(p: Pendentes, home: string = homedir()): string | undefined {
  if (semPendencia(p)) return undefined
  const partes = [
    ...p.verificar.map((v) => `/verificar em ${curto(v.root, home)} (${v.files} ${v.files === 1 ? "arquivo" : "arquivos"})`),
    ...(p.doctor ? ["freitask doctor (vault tocado)"] : []),
  ]
  return "o Stop cobra: " + partes.join(" · ")
}

type Orcamento = {
  coverage: "all" | "models"
  per: "set" | "model"
  limit: number
  spent: number
  models: { providerID: string; modelID: string; spent?: number }[]
}
type Modelo = { id: string; providerID: string; cost: { input: number }[] }
type Provedor = { id: string; integrationID?: string }

/**
 * O que a rota `/api/experimental/usage/limits` deixa para o modelo da sessão, ou nada: a rota é a do
 * OpenCode Console (limites do workspace), então só responde por modelo que ele serve (ou por modelo que um
 * orçamento nomeia). Mesma regra do `modelUsage` do OpenCode (packages/tui/src/util/usage-limits.ts).
 */
export function usoDaAssinatura(info: { budgets: Orcamento[] } | null | undefined, model: Modelo | undefined, provider: Provedor | undefined): { texto: string; esgotado: boolean } | undefined {
  if (!info || !model) return undefined
  if (model.cost.length > 0 && model.cost.every((c) => c.input === 0)) return undefined
  const servido = provider?.integrationID === "opencode" && provider.id !== "opencode-go"
  const sobras = info.budgets
    .flatMap((b) => {
      if (b.coverage === "all") return servido ? [Math.max(0, b.limit - b.spent)] : []
      const entry = b.models.find((m) => m.providerID === model.providerID && m.modelID === model.id)
      if (!entry) return []
      return [Math.max(0, b.limit - (b.per === "model" ? (entry.spent ?? 0) : b.spent))]
    })
    .sort((a, b) => a - b)
  if (sobras.length === 0) return undefined
  const left = sobras[0]!
  const valor = left > 0 && left < 0.01 ? "<$0.01" : "$" + (Number.isInteger(left) ? String(left) : left.toFixed(2))
  return { texto: `${valor} left`, esgotado: left <= 0 }
}
