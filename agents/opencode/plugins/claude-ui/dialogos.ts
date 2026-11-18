// Lógica dos dois diálogos do plugin `claude-ui`: a busca no histórico de prompts e as aprovações salvas.
// Não importa o pacote do OpenCode (só `node:`), para o teste de `agents/tests/` rodá-la no Node.
// Escreva só sintaxe que o Node apaga (sem enum nem parameter property) e importe com `.ts`.
import { dataHora } from "./historico.ts"
import type { Registro } from "./historico.ts"

export type Opcao<V> = { title: string; value: V; description?: string; footer?: string; category?: string }

function umaLinha(text: string, largura: number): string {
  const linha = text.split("\n").find((l) => l.trim() !== "") ?? ""
  const limpa = linha.trim().replace(/\s+/g, " ")
  return limpa.length > largura ? limpa.slice(0, largura - 1) + "…" : limpa
}

/**
 * As opções do diálogo: a mais nova primeiro, sem repetir texto (vale a data da mais nova); o valor é o texto
 * inteiro, que a busca lê. O rodapé de cada uma traz a data e a hora, ou "importado" para as que vieram do
 * arquivo nativo do OpenCode, que não tem data.
 */
export function opcoesDoHistorico(registros: readonly Registro[]): Opcao<string>[] {
  const vistos = new Set<string>()
  const opcoes: Opcao<string>[] = []
  // `sort` é estável: sem data (importado) ficam no fim, na ordem em que o arquivo as tem, da mais nova para a mais antiga.
  const quandoFoi = (r: Registro) => r.timestamp ?? -Infinity
  const recentes = [...registros].reverse().sort((a, b) => (quandoFoi(a) === quandoFoi(b) ? 0 : quandoFoi(b) > quandoFoi(a) ? 1 : -1))
  for (const registro of recentes) {
    const text = registro.display
    if (text.trim() === "" || vistos.has(text)) continue
    vistos.add(text)
    const linhas = text.split("\n").length
    const quando = registro.timestamp !== undefined ? dataHora(registro.timestamp) : "importado"
    opcoes.push({
      title: (registro.mode === "shell" ? "! " : "") + umaLinha(text, 100),
      value: text,
      footer: linhas > 1 ? `${quando} · ${linhas} linhas` : quando,
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
