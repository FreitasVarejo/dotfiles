/** O que o Stop cobraria agora: cada repo sem `/verificar` e se falta o doctor. */
export type Pendentes = {
  verificar: { root: string; files: number }[]
  doctor: boolean
}

declare module 'claude-code' {
  interface PluginState {
    'travas-pendentes': { pendentes: Pendentes | null }
  }
}
