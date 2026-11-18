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

/** `nega` recusa a ferramenta; `bloqueia` pede mais um turno antes de encerrar; vazio é "nada a dizer". */
export type Response = { nega?: string; bloqueia?: string }

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
