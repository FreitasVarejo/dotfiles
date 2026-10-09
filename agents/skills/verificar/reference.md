# O que procurar no diff

Cada item é um jeito de o portão ficar verde sem a mudança estar certa.

## Teste

- **Apagado**: arquivo de teste removido, caso de teste removido, ou `describe`
  e `it` inteiros que somem sem o código que testavam sumir junto.
- **Afrouxado**: asserção trocada por uma mais fraca (`toEqual` → `toBeTruthy`,
  igualdade → "contém", número exato → faixa maior, `assert x == y` →
  `assert x`), tolerância aumentada, timeout aumentado para passar.
- **Pulado**: `skip`, `xit`, `.only` esquecido, `@pytest.mark.skip`, `[Ignore]`,
  `pending`, teste comentado.
- **Ajustado ao código**: o valor esperado mudou para o que o código agora
  devolve, sem o diff explicar por que o comportamento novo é o certo.
  Snapshot regravado entra aqui.
- **Sem asserção**: teste novo que só executa o código e não confere nada.

## Supressão

- Lint ou tipo silenciado: `# noqa`, `# type: ignore`, `// @ts-ignore`,
  `// @ts-expect-error`, `eslint-disable`, `#pragma warning disable`,
  `[SuppressMessage]`, `# shellcheck disable=`, `--no-verify`.
- Régua relaxada: limite de complexidade, cobertura ou tamanho aumentado no
  arquivo de configuração do linter ou do CI.

Supressão com o porquê escrito na mesma linha ou na de cima é decisão, não
achado. Sem o porquê, é achado.

## Fora do pedido

- Arquivo que a mudança não precisava tocar: config do portão, workflow de CI,
  arquivo de dono (CODEOWNERS).
- Segredo ou caminho de máquina entrando no repo.
