// Plugin de TUI `claude-ui`: três coisas do Claude Code que o OpenCode 2.x não tem.
//
// - Rodapé (statusline): modelo, contexto em uso e, quando a rota responde para o modelo, o que resta da
//   assinatura; e a faixa das travas pendentes, a mesma do mod `agents/mods/travas-pendentes`, perguntando
//   às travas (`pendente <sessão>`). Entra nos slots `prompt.footer.status` e `home.footer.status`.
// - `/permissions`: lista as aprovações "sempre" do projeto e remove a escolhida (rotas `permission.saved.*`).
//   Só cobre o que o dono salvou como "sempre", não as regras da config.
// - `ctrl+r` (e `/historico`): busca no histórico de prompts e cola o escolhido no prompt. O plugin de vim
//   (cli.json) trata `ctrl+r` como refazer no modo NORMAL e, no INSERT, devolve a tecla (`run` devolve false):
//   esta camada tem prioridade menor que a do vim e maior que a do `session.rename` (também `ctrl+r`),
//   então a tecla só chega aqui no INSERT, que é onde se quer buscar.
//
// A lógica está em `rodape.ts` e `dialogos.ts`, que não importam o OpenCode (testadas por
// `~/dotfiles/agents/tests/test_opencode_claude_ui.py`); aqui só a cola. A API vem do código do OpenCode
// (anomalyco/opencode, tag v2.2.7): packages/plugin/src/tui/context.ts (slots, `ui.dialog`, `keymap`, `client`,
// `data`). Se uma versão nova mudar um slot, uma rota ou o nome de um evento, a peça fica sem efeito: confira
// antes de subir a versão.
import { Plugin } from "@opencode/plugin/tui"
import { createEffect, createMemo, createSignal, onCleanup, Show } from "solid-js"
import { buscarNoHistorico, confirmacaoDeRemocao, lerHistorico, opcoesDasSalvas, opcoesDoHistorico } from "./dialogos.ts"
import type { Salva } from "./dialogos.ts"
import { contexto, faixa, pendentes, SEM_PENDENTES, semPendencia, tokensEmUso, usoDaAssinatura } from "./rodape.ts"
import type { Pendentes } from "./rodape.ts"

const PRIORIDADE_DA_BUSCA = 50
const USO_A_CADA_MS = 5 * 60_000
const PENDENCIAS_A_CADA_MS = 30_000
// O que mexe no estado das travas (o toque de uma ferramenta, o fim de um turno): a faixa reconfere.
const EVENTOS = ["session.tool.success", "session.tool.failed", "session.idle", "session.execution.succeeded"] as const

function Rodape(props: { context: Plugin.Context; sessionID?: string; uso: () => { texto: string; esgotado: boolean } | undefined }) {
  const ctx = props.context
  const [pendente, setPendente] = createSignal<Pendentes>(SEM_PENDENTES)
  const raiz = createMemo(() => (props.sessionID ? ctx.data.session.root(props.sessionID) : undefined))
  const sessao = createMemo(() => (props.sessionID ? ctx.data.session.get(props.sessionID) : undefined))
  const local = () => sessao()?.location ?? ctx.location
  const modelo = createMemo(() => {
    const atual = ctx.ui.model.current()
    if (!atual) return undefined
    const info = ctx.data.location.model.list(local())?.find((m) => m.providerID === atual.providerID && m.id === atual.modelID)
    return { atual, info }
  })
  const rodando = () => (props.sessionID ? ctx.data.session.status(props.sessionID) === "running" : false)
  const linha = createMemo(() => {
    const m = modelo()
    const tokens = props.sessionID ? tokensEmUso(ctx.data.session.message.list(props.sessionID)) : undefined
    return [
      m ? (m.info?.name ?? m.atual.modelID) : undefined,
      props.sessionID && (m || tokens !== undefined) ? contexto(tokens, m?.info?.limit.context) : undefined,
      props.uso()?.texto,
    ]
      .filter((parte): parte is string => Boolean(parte))
      .join(" · ")
  })

  // A pergunta às travas sai do tempo do evento: uma rajada de ferramentas vira uma consulta só.
  let timer: ReturnType<typeof setTimeout> | undefined
  let consultando = false
  let denovo = false
  const consultar = async () => {
    if (consultando) {
      denovo = true
      return
    }
    consultando = true
    try {
      const id = raiz()
      setPendente(id ? await pendentes(id) : SEM_PENDENTES)
    } catch {
      // trava ausente é "nada pendente"
    } finally {
      consultando = false
      if (denovo) {
        denovo = false
        agendar()
      }
    }
  }
  const agendar = () => {
    clearTimeout(timer)
    timer = setTimeout(() => void consultar(), 300)
  }
  createEffect(() => {
    raiz()
    agendar()
  })
  const desligar = EVENTOS.map((tipo) => ctx.data.on(tipo, agendar))
  // Commit ou carimbo feito por fora não passa por evento desta sessão: enquanto há algo pendente, reconfere.
  const poll = setInterval(() => {
    if (!semPendencia(pendente())) agendar()
  }, PENDENCIAS_A_CADA_MS)
  onCleanup(() => {
    clearTimeout(timer)
    clearInterval(poll)
    desligar.forEach((fora) => fora())
  })

  const aviso = () => faixa(pendente())
  // A faixa é o que o dono precisa agir: não encolhe, e quem cede lugar é o modelo/contexto.
  return (
    <>
      <Show when={linha()}>
        <text wrapMode="none" truncate flexShrink={1} minWidth={0} fg={ctx.theme.text.muted}>
          {linha()}
        </text>
      </Show>
      <Show when={aviso()}>
        <text wrapMode="none" flexShrink={0} fg={rodando() ? ctx.theme.text.muted : ctx.theme.text.feedback.warning.base}>
          {aviso()}
        </text>
      </Show>
    </>
  )
}

function promptFocado(ctx: Plugin.Context): any {
  const rota = ctx.ui.router.current().type
  if (rota !== "home" && rota !== "session") return undefined
  const editor: any = ctx.renderer.currentFocusedEditor
  return editor && typeof editor.insertText === "function" && editor.focused !== false ? editor : undefined
}

export default Plugin.define({
  id: "dotfiles.claude-ui",
  setup(ctx) {
    // O uso da assinatura é por local e vale para os dois rodapés: uma consulta, repetida de tempos em tempos.
    const [info, setInfo] = createSignal<any>(null)
    const carregarUso = async () => {
      try {
        const resposta = await ctx.client.experimental.usage.limits({ location: ctx.location } as never)
        setInfo(resposta.data ?? null)
      } catch {
        setInfo(null)
      }
    }
    void carregarUso()
    const intervalo = setInterval(() => void carregarUso(), USO_A_CADA_MS)
    const uso = () => {
      const atual = ctx.ui.model.current()
      if (!atual || !info()) return undefined
      const local = ctx.location
      const modelo = ctx.data.location.model.list(local)?.find((m) => m.providerID === atual.providerID && m.id === atual.modelID)
      const provedor = ctx.data.location.provider.list(local)?.find((p) => p.id === atual.providerID)
      return usoDaAssinatura(info(), modelo as never, provedor as never)
    }

    ctx.ui.slot({
      append: "prompt.footer.status",
      render: (entrada) => <Rodape context={ctx} sessionID={entrada.sessionID} uso={uso} />,
    })
    ctx.ui.slot({
      append: "home.footer.status",
      render: () => <Rodape context={ctx} uso={uso} />,
    })

    const sessaoAtual = () => {
      const rota = ctx.ui.router.current()
      return rota.type === "session" ? rota.sessionID : undefined
    }

    const aprovacoes = async () => {
      const projectID = sessaoAtual() ? ctx.data.session.get(sessaoAtual()!)?.projectID : undefined
      for (;;) {
        let salvas: Salva[]
        try {
          salvas = (await ctx.client.permission.saved.list({ projectID })) as unknown as Salva[]
        } catch (erro) {
          ctx.ui.toast.show({ variant: "error", message: "Aprovações salvas: " + (erro instanceof Error ? erro.message : String(erro)) })
          return
        }
        if (salvas.length === 0) {
          ctx.ui.toast.show({ variant: "info", message: "Nenhuma aprovação \"sempre\" salva neste projeto." })
          return
        }
        const id = await ctx.ui.dialog.select({
          title: "Aprovações \"sempre\" do projeto (Enter remove)",
          placeholder: "Filtrar",
          options: opcoesDasSalvas(salvas),
        })
        const alvo = salvas.find((salva) => salva.id === id)
        if (!alvo) return
        const confirmou = await ctx.ui.dialog.confirm({ title: "Remover aprovação", message: confirmacaoDeRemocao(alvo) })
        if (!confirmou) continue
        try {
          await ctx.client.permission.saved.remove({ id: alvo.id })
          ctx.data.project.permission.invalidate(alvo.projectID ?? projectID ?? "")
        } catch (erro) {
          ctx.ui.toast.show({ variant: "error", message: "Não removeu: " + (erro instanceof Error ? erro.message : String(erro)) })
        }
      }
    }

    const historico = async () => {
      const editor = promptFocado(ctx)
      const opcoes = opcoesDoHistorico(await lerHistorico())
      if (opcoes.length === 0) {
        ctx.ui.toast.show({ variant: "info", message: "Histórico de prompts vazio." })
        return
      }
      const texto = await ctx.ui.dialog.select({
        title: "Histórico de prompts",
        placeholder: "Buscar (todas as palavras)",
        options: opcoes,
        search: buscarNoHistorico,
      })
      if (texto === undefined || !editor || editor.isDestroyed) return
      // O diálogo devolve o foco ao prompt um instante depois de fechar; o texto entra já com ele de volta.
      setTimeout(() => {
        if (editor.isDestroyed) return
        editor.focus()
        editor.insertText(texto)
      }, 20)
    }

    ctx.keymap.layer(() => ({
      mode: "base",
      priority: PRIORIDADE_DA_BUSCA,
      commands: [
        {
          id: "claude-ui.historico",
          title: "Buscar no histórico de prompts",
          group: "Prompt",
          palette: true,
          slash: { name: "historico" },
          run: () => void historico(),
        },
        {
          id: "claude-ui.historico.tecla",
          bind: "ctrl+r",
          // Só com o prompt focado: fora dele a tecla segue para o `session.rename`.
          enabled: () => promptFocado(ctx) !== undefined,
          run: () => void historico(),
        },
      ],
    }))
    ctx.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "claude-ui.permissions",
          title: "Aprovações salvas (permissions)",
          group: "Prompt",
          palette: true,
          slash: { name: "permissions" },
          run: () => void aprovacoes(),
        },
      ],
    }))

    return () => {
      clearInterval(intervalo)
    }
  },
})
