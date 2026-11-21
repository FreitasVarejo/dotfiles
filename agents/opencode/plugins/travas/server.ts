// Plugin de servidor `travas`: leva ao OpenCode as travas de `agents/travas/` (ADR 0028).
// Só cola: a tradução do evento do OpenCode para o JSON de hook do Claude Code e o despacho pelo
// `travas.json` estão em `adaptador.py`, que `travas.ts` chama. Aqui ficam os ganchos e o que é
// estado de sessão.
//
// - `execute.before`: a trava que recusa (`tasks-so-pelo-freitask`) faz a chamada falhar com o motivo
//   dela como erro da ferramenta, que é o texto que o modelo lê; as que só anotam (a verificação)
//   rodam junto. A que pergunta (`chave-com-aprovacao`, `permissionDecision: "ask"`) vira um pedido
//   de `ctx.permission.assert`, e a recusa do dono é relançada. Cada uso pede de novo: o pedido não leva
//   `save`, então um "always" não grava regra (no código do OpenCode, o `reply` só grava o `save`, e o TUI
//   só oferece "always" com `save`), e a ação é só da trava (`ASK_ACTION`), então nem uma regra gravada
//   de `shell` libera o uso seguinte. Sem regra que case, o efeito padrão é "ask". Falha do `assert` que
//   não é recusa (erro do OpenCode, sessão sumida) não recusa nada.
// - `execute.after`: os toques (`doctor-no-stop marca`, `verificacao-no-stop pos-bash`).
// - `experimental.idle`: o Stop. Cobra uma vez por prompt do dono (`stop_hook_active` na segunda
//   passada), nunca em sessão-filha (o Stop do Claude Code só roda no agente principal) e nunca
//   enquanto a própria sessão espera shell ou subagente em segundo plano (o gancho roda de novo
//   quando eles terminam).
// - `skill.transform`: `${CLAUDE_SESSION_ID}` vira `$OPENCODE_SESSION_ID`, que o shell do OpenCode
//   expande. A transformação é da skill, não da sessão, então não dá para pôr o id literal; ela se
//   registra no primeiro prompt, para rodar depois das que acrescentam as skills do disco.
//
// O id que as travas recebem é o da sessão raiz: uma sessão-filha (subagente) usa o do pai, como no
// Claude Code, onde o subagente toca com o `session_id` do principal. Assim o Stop do principal cobra
// o que o subagente editou.
//
// A API vem do código do OpenCode (anomalyco/opencode, tag v2.2.7): packages/plugin/src/promise/
// (tool.ts, session.ts, skill.ts, permission.ts), packages/plugin/src/README.md e, para o que o
// `assert` faz com `save` e regras, packages/core/src/permission.ts. `experimental.idle` é experimental:
// se uma versão nova mudar o nome ou o formato, o Stop deixa de cobrar; confira antes de subir a versão.
// `Plugin.define` só devolve o objeto, então o plugin é o objeto direto: o teste de `agents/tests/`
// carrega este arquivo no Node, sem o pacote do OpenCode.
import type { Plugin } from "@opencode/plugin"
import { ask, refusal, withSessionVar, ASK_ACTION, SESSION_TOKEN } from "./travas.ts"
import type { Request, Response } from "./travas.ts"

type Place = { cwd: string; root: string; child: boolean }

const plugin = {
  id: "dotfiles.travas",
  async setup(ctx: Plugin.Context) {
    const places = new Map<string, Place>()
    // Sessões cujo Stop já pediu mais um turno neste prompt.
    const blocked = new Set<string>()

    const whereIs = async (sessionID: string): Promise<Place | undefined> => {
      const known = places.get(sessionID)
      if (known) return known
      try {
        const session = await ctx.session.get({ sessionID: sessionID as never })
        const parent = session.parentID === undefined ? undefined : String(session.parentID)
        const place = {
          cwd: String(session.location.directory),
          root: parent === undefined ? sessionID : ((await whereIs(parent))?.root ?? parent),
          child: parent !== undefined,
        }
        places.set(sessionID, place)
        return place
      } catch {
        return undefined
      }
    }

    const tool = async (kind: "antes" | "depois", event: any): Promise<Response> => {
      const sessionID = String(event.sessionID)
      const place = await whereIs(sessionID)
      if (!place) return {}
      const request: Request = {
        evento: kind,
        sessao: place.root,
        cwd: place.cwd,
        ferramenta: String(event.tool),
        entrada: event.input,
        chamada: String(event.id),
      }
      if (kind === "depois") {
        request.status = event.status
        if (event.status === "completed") request.aplicados = event.result?.output?.applied
      }
      return await ask(request)
    }

    await ctx.tool.hook("execute.before", async (event) => {
      let answer: Response
      try {
        answer = await tool("antes", event)
      } catch {
        return
      }
      // Fora do `try`: é a recusa, e ela tem de chegar à ferramenta.
      if (answer.nega) throw new Error(answer.nega)
      if (!answer.pergunta) return
      const question = answer.pergunta
      try {
        await ctx.permission.assert({
          sessionID: String(event.sessionID),
          agent: event.agent === undefined ? undefined : String(event.agent),
          action: ASK_ACTION,
          resources: [question],
          metadata: { command: event.input?.command },
          source: { type: "tool", messageID: String(event.messageID), id: String(event.id) },
        } as never)
      } catch (error) {
        const refused = refusal(error, question)
        if (refused) throw refused
      }
    })

    await ctx.tool.hook("execute.after", async (event) => {
      try {
        await tool("depois", event)
      } catch {
        // Trava a mais nunca derruba a ferramenta que já rodou.
      }
    })

    // A transformação das skills roda na ordem em que se registram, e as skills de `~/.claude/skills` e
    // `.claude/skills` entram por transformações do próprio OpenCode que se registram depois das dos
    // plugins; registrada em `setup`, esta só veria as embutidas. O primeiro prompt vem depois da
    // ativação de todos, então ela entra por último e vê todas.
    let skillsHooked = false
    const hookSkills = async () => {
      if (skillsHooked) return
      skillsHooked = true
      await ctx.skill.transform((editor) => {
        for (const skill of editor.list()) {
          if (skill.content.includes(SESSION_TOKEN)) {
            editor.update(skill.id, (draft) => {
              draft.content = withSessionVar(draft.content)
            })
          }
        }
      })
    }

    await ctx.session.hook("prompt", async (event) => {
      blocked.delete(String(event.sessionID))
      try {
        await hookSkills()
      } catch {
        skillsHooked = false
      }
    })

    await ctx.session.hook("experimental.idle", async (event) => {
      try {
        const sessionID = String(event.sessionID)
        const place = await whereIs(sessionID)
        if (!place || place.child) return
        const waiting = event.background.some(
          (work) => (work.kind === "shell" || work.kind === "subagent") && String(work.sessionID) === sessionID,
        )
        if (waiting) return
        const active = blocked.has(sessionID)
        blocked.delete(sessionID)
        const answer = await ask({ evento: "parar", sessao: place.root, cwd: place.cwd, parada_ativa: active })
        if (!answer.bloqueia || active) return
        blocked.add(sessionID)
        await ctx.session.synthetic({
          sessionID: event.sessionID,
          text: "Uma trava do workflow impediu o fim do turno:\n\n" + answer.bloqueia,
        })
      } catch {
        // O gancho que falha derruba a execução: aqui o pior caso é o Stop não cobrar.
      }
    })
  },
} satisfies Plugin.Plugin

export default plugin
