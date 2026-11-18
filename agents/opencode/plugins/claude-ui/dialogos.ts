// Lógica dos dois diálogos do plugin `claude-ui`: a busca no histórico de prompts e as aprovações salvas.
// Não importa o pacote do OpenCode (só `node:`), para o teste de `agents/tests/` rodá-la no Node.
// Escreva só sintaxe que o Node apaga (sem enum nem parameter property) e importe com `.ts`.
import { readFile } from "node:fs/promises"
import { homedir } from "node:os"
import { join } from "node:path"

/** O formato de `prompt-history.jsonl` do OpenCode 2.x (packages/tui/src/prompt/history.tsx). */
export type Entrada = {
  text: string
  mode?: string
  pasted?: { text: string; source: { start: number; end: number; text: string } }[]
}

export type Opcao<V> = { title: string; value: V; description?: string; footer?: string; category?: string }

/** Onde o TUI grava o histórico: o diretório de estado dele, `$XDG_STATE_HOME/opencode`. */
export function historicoPath(env: Record<string, string | undefined> = process.env, home: string = homedir()): string {
  const state = env.XDG_STATE_HOME || join(home, ".local", "state")
  return join(state, "opencode", "prompt-history.jsonl")
}

/** As entradas válidas do arquivo, da mais antiga para a mais nova; linha torta ou arquivo ausente não derruba. */
export async function lerHistorico(file: string = historicoPath()): Promise<Entrada[]> {
  let raw: string
  try {
    raw = await readFile(file, "utf8")
  } catch {
    return []
  }
  const entradas: Entrada[] = []
  for (const line of raw.split("\n")) {
    if (!line) continue
    try {
      const item = JSON.parse(line)
      if (item && typeof item.text === "string") entradas.push(item as Entrada)
    } catch {
      // linha torta: o próprio OpenCode a descarta
    }
  }
  return entradas
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

function umaLinha(text: string, largura: number): string {
  const linha = text.split("\n").find((l) => l.trim() !== "") ?? ""
  const limpa = linha.trim().replace(/\s+/g, " ")
  return limpa.length > largura ? limpa.slice(0, largura - 1) + "…" : limpa
}

/** As opções do diálogo: a mais nova primeiro, sem repetir texto; o valor é o texto inteiro, que a busca lê. */
export function opcoesDoHistorico(entradas: readonly Entrada[]): Opcao<string>[] {
  const vistos = new Set<string>()
  const opcoes: Opcao<string>[] = []
  for (const entrada of [...entradas].reverse()) {
    const text = expandir(entrada)
    if (text.trim() === "" || vistos.has(text)) continue
    vistos.add(text)
    const linhas = text.split("\n").length
    opcoes.push({
      title: (entrada.mode === "shell" ? "! " : "") + umaLinha(text, 100),
      value: text,
      footer: linhas > 1 ? `${linhas} linhas` : undefined,
    })
  }
  return opcoes
}

/** Busca por palavras (todas, em qualquer ordem, sem distinguir caixa) no texto inteiro; a ordem é a da lista. */
export function buscarNoHistorico<V extends string>(query: string, opcoes: readonly Opcao<V>[]): Opcao<V>[] {
  const palavras = query.toLowerCase().split(/\s+/).filter(Boolean)
  if (palavras.length === 0) return [...opcoes]
  return opcoes.filter((opcao) => {
    const texto = opcao.value.toLowerCase()
    return palavras.every((palavra) => texto.includes(palavra))
  })
}

/** Uma aprovação "sempre" do projeto (`PermissionSavedInfo` do OpenCode). */
export type Salva = { id: string; projectID?: string; action: string; resource: string; time: { created: number; updated: number } }

function dia(ms: number): string {
  const d = new Date(ms)
  const dois = (n: number) => String(n).padStart(2, "0")
  return `${d.getFullYear()}-${dois(d.getMonth() + 1)}-${dois(d.getDate())}`
}

/** As opções do diálogo: por ação e depois por recurso; o valor é o id que a rota de remoção pede. */
export function opcoesDasSalvas(salvas: readonly Salva[]): Opcao<string>[] {
  return [...salvas]
    .sort((a, b) => a.action.localeCompare(b.action) || a.resource.localeCompare(b.resource))
    .map((salva) => ({
      title: `${salva.action}  ${salva.resource}`,
      value: salva.id,
      description: "salva em " + dia(salva.time.created),
    }))
}

/** O texto da confirmação antes de remover. */
export function confirmacaoDeRemocao(salva: Salva): string {
  return `Remover "${salva.action} ${salva.resource}"? O OpenCode volta a perguntar antes de ${salva.action} nisso.`
}
