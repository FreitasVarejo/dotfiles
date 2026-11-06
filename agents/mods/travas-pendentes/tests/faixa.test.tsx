import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const BAND = {
  plugin: 'travas-pendentes',
  component: 'AbovePrompt',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 10,
    bodyColumns: 120,
    scroll: { offset: 0, bodyRows: 10 },
    view: {},
  },
} as const

// As travas respondem o `pendente`; cada chamada fica anotada.
function travas(on: On, verif: string, doctor: string) {
  const asked: string[][] = []
  on('process.run', (_, e) => {
    asked.push([...e.argv])
    const stdout = e.argv[0]?.endsWith('/verificacao-no-stop') ? verif : doctor
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('env.get', () => ({ value: '/home/u' }))
  return asked
}

function postToolUse(tool_name: string, tool_use_id: string) {
  return { tool_name, tool_input: {}, tool_response: {}, tool_use_id, session_id: 'sess-1' }
}

test('depois do Stop, a faixa diz o repo sem /verificar e o doctor', async ($, on) => {
  const clock = mock.clock(on)
  const asked = travas(on, '3\t/home/u/dotfiles\n', 'vault\n')
  on('classic.Stop', () => ({}))

  await $.classic.Stop({ stop_hook_active: false, session_id: 'sess-1' })
  await clock.advance(300)

  expect(asked.map(a => a.slice(1))).toEqual([['pendente', 'sess-1'], ['pendente', 'sess-1']])
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  const band = await ui.find({ type: 'Text', text: /o Stop cobra/ })
  expect(band?.text).toBe('o Stop cobra: /verificar em ~/dotfiles (3 arquivos) · freitask doctor (vault tocado)')
  await ui.unmount()
})

test('uma rajada de Edits vira uma consulta só; Read não consulta', async ($, on) => {
  const clock = mock.clock(on)
  const asked = travas(on, '', '')
  on('classic.PostToolUse', () => ({}))

  await $.classic.PostToolUse(postToolUse('Read', 'r1'))
  await clock.advance(1000)
  expect(asked.length).toBe(0)

  await $.classic.PostToolUse(postToolUse('Edit', 'e1'))
  await $.classic.PostToolUse(postToolUse('Edit', 'e2'))
  await $.classic.PostToolUse(postToolUse('Bash', 'b1'))
  await clock.advance(300)
  expect(asked.length).toBe(2)
})

test('sem nada pendente, a faixa fica com o engine', async ($, on) => {
  const clock = mock.clock(on)
  travas(on, '', '')
  on('classic.Stop', () => ({}))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  await $.classic.Stop({ stop_hook_active: false, session_id: 'sess-1' })
  await clock.advance(300)

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /o Stop cobra/ })).toBeUndefined()
  expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe('engine')
  await ui.unmount()
})
