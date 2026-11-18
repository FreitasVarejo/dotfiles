// Plugin de servidor `contexto`: leva ao OpenCode o contexto que o Claude Code carrega sozinho.
// A lógica está em `contexto.ts`; aqui só os ganchos. Cada coisa entra na sessão como entrada de
// instruções (`session.instructions.entry.put`), que o OpenCode anuncia ao modelo na próxima fronteira
// de passo, sem gastar turno. Um `put` com o mesmo valor não muda nada, então repetir é seguro.
//
// A API vem do código do OpenCode (anomalyco/opencode, tag v2.2.7): packages/plugin/src/promise/
// (tool.ts, session.ts) e packages/core/src/session/instruction-entry.ts. Se uma versão nova mudar
// o nome de um gancho ou de uma ferramenta, o plugin fica sem efeito: confira antes de subir a versão.
// `Plugin.define` só devolve o objeto, então o plugin é o objeto direto e só o tipo vem do host:
// assim o teste de `agents/tests/` carrega este arquivo no Node, sem o pacote do OpenCode.
import type { Plugin } from "@opencode/plugin"
import { homedir } from "node:os"
import { claudeMdEntries, findProject, memoryDir, memoryEntry, rulesFor, touchedPaths } from "./contexto.ts"
import type { Entry, Project } from "./contexto.ts"

type Where = { cwd: string; project: Project }

const plugin = {
  id: "dotfiles.contexto",
  async setup(ctx: Plugin.Context) {
    const home = homedir()
    // Por sessão: onde ela trabalha, e o que já entrou nela (nesta execução do servidor).
    const places = new Map<string, Where>()
    const started = new Set<string>()
    const given = new Map<string, Set<string>>()

    const whereIs = async (sessionID: string): Promise<Where | undefined> => {
      const known = places.get(sessionID)
      if (known) return known
      try {
        const session = await ctx.session.get({ sessionID: sessionID as never })
        const cwd = String(session.location.directory)
        const place = { cwd, project: findProject(cwd) }
        places.set(sessionID, place)
        return place
      } catch {
        return undefined
      }
    }

    const put = async (sessionID: string, entries: Entry[]) => {
      const seen = given.get(sessionID) ?? new Set<string>()
      given.set(sessionID, seen)
      for (const entry of entries) {
        if (seen.has(entry.key)) continue
        seen.add(entry.key)
        try {
          await ctx.session.instructions.entry.put({
            sessionID: sessionID as never,
            key: entry.key as never,
            value: entry.value,
          })
        } catch {
          // Contexto a mais nunca derruba a ferramenta nem o prompt.
          seen.delete(entry.key)
        }
      }
    }

    // No começo da sessão, antes da primeira chamada ao modelo: a memória e os CLAUDE.md.
    await ctx.session.hook("prompt", async (event) => {
      const sessionID = String(event.sessionID)
      if (started.has(sessionID)) return
      started.add(sessionID)
      const place = await whereIs(sessionID)
      if (!place) return
      await put(sessionID, [memoryEntry(memoryDir(home, place.project), home), ...claudeMdEntries(place.cwd, home)])
    })

    // Depois de uma ferramenta de arquivo, as regras de `.claude/rules/` que casam com o caminho.
    await ctx.tool.hook("execute.after", async (event) => {
      if (event.status !== "completed") return
      const touched = touchedPaths(event.tool, event.input)
      if (touched.length === 0) return
      const sessionID = String(event.sessionID)
      const place = await whereIs(sessionID)
      if (!place) return
      await put(sessionID, rulesFor(place.project, place.cwd, touched))
    })
  },
} satisfies Plugin.Plugin

export default plugin
