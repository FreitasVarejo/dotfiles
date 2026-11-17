// Apelidos do Claude Code para os comandos nativos do OpenCode 2.x: cada um é um
// comando de barra que só despacha o comando nativo pelo id. Nada aqui reimplementa
// o que o nativo faz, e nenhum apelido tem tecla nem entra na paleta.
//
// Os ids saem do código do OpenCode (anomalyco/opencode, tag v2.2.7): packages/tui/src/app.tsx,
// routes/session/index.tsx e feature-plugins/system/. Se uma versão nova mudar um id,
// o apelido fica sem efeito: confira os ids antes de subir a versão.
//
// Fora daqui, por já existirem no OpenCode: /resume, /continue, /effort, /quit, /clear.
import { Plugin } from "@opencode/plugin/tui"

type Apelido = { slash: string; id: string; title: string; sessao?: boolean }

const APELIDOS: readonly Apelido[] = [
  { slash: "rewind", id: "session.timeline", title: "Rewind (alias of /timeline)", sessao: true },
  { slash: "model", id: "model.list", title: "Switch model (alias of /models)" },
  { slash: "config", id: "opencode.settings", title: "Open settings (alias of /settings)" },
  { slash: "mcp", id: "mcp.list", title: "MCP servers (alias of /mcps)" },
  { slash: "plugin", id: "plugins.list", title: "Plugins (alias of /plugins)" },
  { slash: "cost", id: "stats.open", title: "Usage statistics (alias of /stats)" },
  { slash: "theme", id: "theme.switch", title: "Switch theme (alias of /themes)" },
  { slash: "login", id: "provider.connect", title: "Connect an integration (alias of /connect)" },
]

export default Plugin.define({
  id: "dotfiles.apelidos",
  setup(context) {
    context.keymap.layer(() => ({
      mode: "global",
      commands: APELIDOS.map((apelido) => ({
        id: "dotfiles.apelido." + apelido.slash,
        title: apelido.title,
        slash: { name: apelido.slash },
        // O /timeline só existe dentro de uma sessão; fora dela o apelido some, como o nativo.
        enabled: () => !apelido.sessao || context.ui.router.current().type === "session",
        run: () => context.keymap.dispatch(apelido.id),
      })),
    }))
  },
})
