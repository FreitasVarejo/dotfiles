// Faixa acima do prompt com o que as travas do Stop ainda cobram desta sessão.
//
// Quem sabe o que está pendente são as próprias travas (`pendente <sessão>` em
// `agents/travas/verificacao-no-stop` e `doctor-no-stop`); este mod só pergunta e
// desenha. Pergunta depois dos hooks clássicos que mexem no estado delas: na cadeia,
// os hooks do settings.json estão abaixo dos módulos, então `await next(e)` volta
// com a trava já rodada. Fica apagada com o agente trabalhando (pendente no meio do
// turno é o normal) e amarela com ele parado: o Stop bloqueia uma vez só, e a faixa
// é o que sobra à vista quando a segunda passada deixa encerrar.

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import type { Pendentes } from '../types'

const pendentes = atom({ plugin: 'travas-pendentes', key: 'pendentes' } as const, null)

const TOUCHES = new Set(['Edit', 'Write', 'NotebookEdit', 'MultiEdit', 'Bash'])
const DEBOUNCE_MS = 300
const RECHECK_MS = 60_000

// Da sessão que os hooks clássicos anunciam; recomeça quando o módulo recarrega.
let sessionId: string | undefined
let scheduled = false
let rechecking: Timer | undefined

async function ask($: EngineInterface, script: string, id: string, timeoutMs: number) {
  const travas = `${$.plugin.root}/../../travas`
  try {
    const r = await $.process.run([`${travas}/${script}`, 'pendente', id], { timeoutMs })
    return r.exitCode === 0 ? r.stdout : ''
  } catch {
    return ''
  }
}

async function refresh($: EngineInterface) {
  const id = sessionId
  if (id === undefined) return
  const home = (await $.env.get('HOME')) ?? ''
  const [verif, doctor] = await Promise.all([
    ask($, 'verificacao-no-stop', id, 20_000),
    ask($, 'doctor-no-stop', id, 10_000),
  ])
  const verificar = verif
    .split('\n')
    .filter(Boolean)
    .map(line => {
      const [files = '0', root = ''] = line.split('\t')
      const short = home && root.startsWith(home + '/') ? '~' + root.slice(home.length) : root
      return { root: short, files: Number(files) }
    })
  const now: Pendentes = { verificar, doctor: doctor.trim() === 'vault' }
  await update($, pendentes, () => now)
}

// Várias chamadas de ferramenta em rajada viram uma consulta só, fora do tempo do hook.
function schedule($: EngineInterface, id: string) {
  sessionId = id
  if (scheduled) return
  scheduled = true
  $.clock.after(DEBOUNCE_MS, () => {
    scheduled = false
    void refresh($)
  })
}

async function recheck($: EngineInterface) {
  const p = await read($, pendentes)
  if (p && (p.verificar.length > 0 || p.doctor)) await refresh($)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const r = await next(e)
    schedule($, await $.session.id())
    // Commit ou carimbo feito por fora não passa por hook desta sessão: enquanto há
    // algo pendente, reconfere de tempos em tempos para a faixa poder sumir.
    // Um `session.start` a mais no mesmo processo (/clear, resume) troca o timer.
    rechecking?.cancel()
    rechecking = $.clock.every(RECHECK_MS, () => {
      void recheck($)
    })
    return r
  })

  on('classic.PostToolUse', async ($, e, next) => {
    const r = await next(e)
    if (TOUCHES.has(e.tool_name)) schedule($, e.session_id)
    return r
  })

  on('classic.PostToolUseFailure', async ($, e, next) => {
    const r = await next(e)
    if (TOUCHES.has(e.tool_name)) schedule($, e.session_id)
    return r
  })

  on('classic.Stop', async ($, e, next) => {
    const r = await next(e)
    schedule($, e.session_id)
    return r
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const p = await read($, pendentes)
    if (e.props.hasSurvey || p === null || (p.verificar.length === 0 && !p.doctor)) {
      return next(e)
    }
    const parts = [
      ...p.verificar.map(v => `/verificar em ${v.root} (${v.files} ${v.files === 1 ? 'arquivo' : 'arquivos'})`),
      ...(p.doctor ? ['freitask doctor (vault tocado)'] : []),
    ]
    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box>
        <Text color="warning" dimColor={e.props.isWorking}>
          o Stop cobra: {parts.join(' · ')}
        </Text>
      </Box>
    )
  })
}
