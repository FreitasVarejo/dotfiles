// O histórico de prompts do plugin `claude-ui`: um arquivo próprio, com data, no formato do
// `~/.claude/history.jsonl` do Claude Code (uma linha JSON por prompt: texto, hora, diretório do projeto).
// O arquivo nativo do OpenCode (`prompt-history.jsonl`) guarda só os últimos 50 prompts, sem data, e o plugin
// nunca o escreve: só o lê, para importá-lo na primeira vez e para saber o que o TUI acaba de gravar.
// Não importa o pacote do OpenCode (só `node:`), para o teste de `agents/tests/` rodá-lo no Node.
// Escreva só sintaxe que o Node apaga (sem enum nem parameter property) e importe com `.ts`.
import { watch } from "node:fs"
import { appendFile, mkdir, readFile, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import { basename, dirname, join } from "node:path"

/** O formato de `prompt-history.jsonl` do OpenCode 2.x (packages/tui/src/prompt/history.tsx). */
export type Entrada = {
  text: string
  mode?: string
  pasted?: { text: string; source: { start: number; end: number; text: string } }[]
}

/**
 * Uma linha do histórico próprio. `display`, `pastedContents`, `timestamp`, `project` e `sessionId` são os campos
 * do `history.jsonl` do Claude Code. `display` já traz o texto colado por inteiro (o Claude guarda o rótulo e o
 * conteúdo à parte). Sem `timestamp` e com `importado`: veio do arquivo nativo, que não tem data.
 */
export type Registro = {
  display: string
  pastedContents: Record<string, never>
  timestamp?: number
  project?: string
  sessionId?: string
  mode?: "shell"
  importado?: true
}

type Env = Record<string, string | undefined>

function estado(env: Env, home: string): string {
  return join(env.XDG_STATE_HOME || join(home, ".local", "state"), "opencode")
}

/** Onde o TUI grava o histórico dele: o diretório de estado, `$XDG_STATE_HOME/opencode`. */
export function nativoPath(env: Env = process.env, home: string = homedir()): string {
  return join(estado(env, home), "prompt-history.jsonl")
}

/** O histórico do plugin, ao lado do nativo e com outro nome: o TUI reescreve o dele, e o do plugin nunca é tocado por ele. */
export function proprioPath(env: Env = process.env, home: string = homedir()): string {
  return join(estado(env, home), "claude-ui-history.jsonl")
}

function entradaDe(line: string): Entrada | undefined {
  try {
    const item = JSON.parse(line)
    // A mesma regra do OpenCode (`parsePromptInfo`): texto e a lista de colados.
    if (item && typeof item.text === "string" && Array.isArray(item.pasted)) return item as Entrada
  } catch {
    // linha torta: o próprio OpenCode a descarta
  }
  return undefined
}

async function linhasDe(file: string): Promise<string[]> {
  try {
    return (await readFile(file, "utf8")).split("\n").filter(Boolean)
  } catch {
    return []
  }
}

/** As entradas válidas do arquivo nativo, da mais antiga para a mais nova; linha torta ou arquivo ausente não derruba. */
export async function lerNativo(file: string = nativoPath()): Promise<Entrada[]> {
  return (await linhasDe(file)).flatMap((line) => entradaDe(line) ?? [])
}

/** Os registros válidos do histórico próprio, do mais antigo para o mais novo. */
export async function lerRegistros(file: string = proprioPath()): Promise<Registro[]> {
  const registros: Registro[] = []
  for (const line of await linhasDe(file)) {
    try {
      const item = JSON.parse(line)
      if (item && typeof item.display === "string") registros.push(item as Registro)
    } catch {
      // linha torta: pula
    }
  }
  return registros
}

/**
 * O texto que o dono digitou: o texto colado que o OpenCode troca por um rótulo (`[Pasted ~3 lines]`) volta
 * ao conteúdo real. O trecho só é trocado onde o rótulo ainda está, para um deslocamento não cortar texto.
 */
export function expandir(entrada: Entrada): string {
  let text = entrada.text
  const partes = [...(entrada.pasted ?? [])].sort((a, b) => b.source.start - a.source.start)
  for (const parte of partes) {
    const { start, end, text: rotulo } = parte.source
    if (text.slice(start, end) === rotulo) text = text.slice(0, start) + parte.text + text.slice(end)
  }
  return text
}

/** A linha do histórico próprio para uma entrada nativa; nada quando o prompt é vazio. */
export function registroDe(entrada: Entrada, extra: { timestamp?: number; project?: string; sessionId?: string; importado?: boolean } = {}): Registro | undefined {
  const display = expandir(entrada)
  if (display.trim() === "") return undefined
  const registro: Registro = { display, pastedContents: {} }
  if (extra.timestamp !== undefined) registro.timestamp = extra.timestamp
  if (extra.project) registro.project = extra.project
  if (extra.sessionId) registro.sessionId = extra.sessionId
  if (entrada.mode === "shell") registro.mode = "shell"
  if (extra.importado) registro.importado = true
  return registro
}

/**
 * Primeira vez, sem o arquivo próprio: as entradas do nativo viram o ponto de partida, sem data (o nativo não
 * tem) e marcadas `importado`. Com o arquivo próprio já ali, não faz nada; um arquivo vazio fica como marca de
 * que a importação já passou. Devolve se importou.
 */
export async function importarNativo(nativo: string = nativoPath(), proprio: string = proprioPath()): Promise<boolean> {
  const linhas = (await lerNativo(nativo)).flatMap((entrada) => registroDe(entrada, { importado: true }) ?? [])
  await mkdir(dirname(proprio), { recursive: true })
  try {
    await writeFile(proprio, linhas.map((r) => JSON.stringify(r) + "\n").join(""), { flag: "wx" })
    return true
  } catch (erro: any) {
    if (erro?.code === "EEXIST") return false
    throw erro
  }
}

const JANELA_DE_REPETICAO_MS = 10_000

/**
 * Grava um prompt no fim do histórico próprio. Dois TUIs abertos veem o mesmo prompt no arquivo nativo e os dois
 * o gravariam: o mesmo texto de dez segundos antes, ou menos, não entra de novo.
 */
export async function anexar(registro: Registro, proprio: string = proprioPath()): Promise<boolean> {
  if (registro.timestamp !== undefined) {
    const recentes = (await lerRegistros(proprio)).slice(-30)
    const t = registro.timestamp
    if (recentes.some((r) => r.display === registro.display && r.timestamp !== undefined && Math.abs(t - r.timestamp) <= JANELA_DE_REPETICAO_MS)) return false
  }
  await mkdir(dirname(proprio), { recursive: true })
  await appendFile(proprio, JSON.stringify(registro) + "\n")
  return true
}

/**
 * O que o TUI gravou no nativo desde a última leitura. O nativo só cresce pelo fim, e quando passa de 50
 * entradas o TUI o reescreve sem as mais antigas: acha-se o menor deslocamento em que o que sobrou das
 * `antes` é o começo das `depois`, e o resto é novo. Sem nenhuma sobreposição o arquivo foi trocado: tudo é novo.
 */
export function novasLinhas(antes: readonly string[], depois: readonly string[]): string[] {
  for (let corte = 0; corte <= antes.length; corte++) {
    const resto = antes.length - corte
    if (resto > depois.length) continue
    let igual = true
    for (let i = 0; i < resto; i++) {
      if (antes[corte + i] !== depois[i]) {
        igual = false
        break
      }
    }
    if (igual) return depois.slice(resto)
  }
  return [...depois]
}

/** As entradas válidas do nativo, uma linha normalizada cada: a comparação não depende de espaço nem da ordem de escrita. */
async function normalizadas(nativo: string): Promise<string[]> {
  return (await lerNativo(nativo)).map((entrada) => JSON.stringify(entrada))
}

type Contexto = { project?: string; sessionId?: string }

/**
 * Liga o histórico próprio: importa o nativo se for a primeira vez e, a cada entrada nova que o TUI grava no
 * nativo (o que ele grava ao enviar um prompt, comando ou shell), anexa uma linha com a hora e o projeto.
 * Devolve a função que desliga.
 *
 * Por que o arquivo nativo e não o evento `session.inbox.enqueued`: o evento traz o que foi para o servidor, e um
 * comando de barra (`/implementar x`) chega lá já expandido no modelo do comando; o nativo tem o que o dono
 * digitou, também no modo shell. O custo: o TUI também grava ali o rascunho que o dono limpa com um prompt de
 * 20 caracteres ou mais.
 */
export async function vigiar(opcoes: {
  nativo?: string
  proprio?: string
  contexto?: () => Contexto
  agora?: () => number
  esperaMs?: number
}): Promise<() => void> {
  const nativo = opcoes.nativo ?? nativoPath()
  const proprio = opcoes.proprio ?? proprioPath()
  const agora = opcoes.agora ?? Date.now
  try {
    await importarNativo(nativo, proprio)
  } catch {
    // sem importação a busca ainda funciona com o que for gravado daqui em diante
  }
  let vistas = await normalizadas(nativo)
  let timer: ReturnType<typeof setTimeout> | undefined
  let lendo = false
  let denovo = false
  let parado = false

  const ler = async () => {
    if (lendo) {
      denovo = true
      return
    }
    lendo = true
    try {
      const atuais = await normalizadas(nativo)
      const novas = novasLinhas(vistas, atuais)
      vistas = atuais
      for (const linha of novas) {
        const registro = registroDe(JSON.parse(linha), { timestamp: agora(), ...opcoes.contexto?.() })
        if (registro) await anexar(registro, proprio)
      }
    } catch {
      // o histórico é uma conveniência: falhar não pode atrapalhar o TUI
    } finally {
      lendo = false
      if (denovo && !parado) {
        denovo = false
        agendar()
      }
    }
  }
  const agendar = () => {
    clearTimeout(timer)
    timer = setTimeout(() => void ler(), opcoes.esperaMs ?? 150)
  }

  let vigia: ReturnType<typeof watch> | undefined
  try {
    const alvo = basename(nativo)
    vigia = watch(dirname(nativo), (_tipo, nome) => {
      if (!nome || nome === alvo) agendar()
    })
    vigia.on("error", () => {})
  } catch {
    // sem vigia (diretório ausente): o histórico próprio fica só com o que já tem
  }
  return () => {
    parado = true
    clearTimeout(timer)
    vigia?.close()
  }
}

const dois = (n: number) => String(n).padStart(2, "0")

/** `18/11/2026 14:32`, na hora local. */
export function dataHora(ms: number): string {
  const d = new Date(ms)
  return `${dois(d.getDate())}/${dois(d.getMonth() + 1)}/${d.getFullYear()} ${dois(d.getHours())}:${dois(d.getMinutes())}`
}
