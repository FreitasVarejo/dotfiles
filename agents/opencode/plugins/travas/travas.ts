// A parte do plugin `travas` que não depende do OpenCode: só `node:` e o `adaptador.py` ao lado.
// Fica separada de `server.ts` para o teste de `agents/tests/` carregá-la no Node.
// Escreva só sintaxe que o Node apaga (sem enum nem parameter property) e importe com `.ts`.
import { spawn } from "node:child_process"
import { fileURLToPath } from "node:url"

/** O pedido ao `adaptador.py`; o que cada campo quer dizer está no docstring dele. */
export type Request = {
  evento: "antes" | "depois" | "parar"
  sessao: string
  cwd: string
  ferramenta?: string
  entrada?: unknown
  chamada?: string
  status?: string
  aplicados?: unknown
  parada_ativa?: boolean
}

/**
 * `nega` recusa a ferramenta; `pergunta` pede a aprovação do dono antes dela; `bloqueia` pede mais um
 * turno antes de encerrar; vazio é "nada a dizer".
 */
export type Response = { nega?: string; pergunta?: string; bloqueia?: string }

/**
 * A ação do pedido de permissão que a pergunta de uma trava abre (`ctx.permission.assert`). É só da
 * trava: nenhuma regra do OpenCode, configurada ou gravada, tem esta ação, e o nome é o que o TUI mostra
 * ("Call tool chave-de-api"). Mude-a junto com a trava que pergunta.
 */
export const ASK_ACTION = "chave-de-api"

/**
 * A recusa do dono (ou de uma regra) a um pedido de `ctx.permission.assert`, como erro a relançar; `undefined`
 * quando o erro é outro, e então a trava não recusa nada (ADR 0027). Os dois jeitos de recusar chegam pela
 * `_tag`: `Tool.Error` (regra que nega, ou recusa com texto do dono) e `Permission.DeclinedError` (recusa
 * simples, sem texto, que o `execute.before` da ferramenta mostraria vazia).
 */
export function refusal(error: unknown, question: string): Error | undefined {
  const tag = (error as { _tag?: unknown } | null | undefined)?._tag
  if (tag === "Tool.Error") return error as Error
  if (tag === "Permission.DeclinedError") return new Error("O dono recusou este uso.\n\n" + question)
  return undefined
}

const ADAPTER = fileURLToPath(new URL("./adaptador.py", import.meta.url))
/** Teto da chamada inteira: o Stop roda o doctor (60s) e a verificação (30s) dentro do adaptador. */
const TIMEOUT_MS = 150_000

/**
 * Pergunta às travas, pelo adaptador. Falha dele (sem python3, estouro de tempo, saída torta) vira
 * resposta vazia: um hook que falha derruba a execução do OpenCode, e a trava ausente não recusa nada.
 */
export function ask(request: Request): Promise<Response> {
  return new Promise((resolve) => {
    let settled = false
    const finish = (response: Response) => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      resolve(response)
    }
    let out = ""
    let child: ReturnType<typeof spawn>
    try {
      child = spawn("python3", ["-I", ADAPTER], { stdio: ["pipe", "pipe", "ignore"] })
    } catch {
      resolve({})
      return
    }
    const timer = setTimeout(() => {
      child.kill("SIGKILL")
      finish({})
    }, TIMEOUT_MS)
    child.on("error", () => finish({}))
    child.stdin?.on("error", () => {})
    child.stdout?.setEncoding("utf8")
    child.stdout?.on("data", (chunk: string) => (out += chunk))
    child.on("close", () => {
      try {
        const parsed = JSON.parse(out)
        finish(typeof parsed === "object" && parsed !== null ? (parsed as Response) : {})
      } catch {
        finish({})
      }
    })
    child.stdin?.end(JSON.stringify(request))
  })
}

/** O texto de uma skill escrita para o Claude Code, com `${CLAUDE_SESSION_ID}` virado no que o shell do OpenCode sabe. */
export const SESSION_TOKEN = "${CLAUDE_SESSION_ID}"
export const SESSION_VAR = "$OPENCODE_SESSION_ID"

export function withSessionVar(content: string): string {
  return content.split(SESSION_TOKEN).join(SESSION_VAR)
}
