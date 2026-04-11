# OpenCode Configuration

Arquivos de configuração do [OpenCode](https://opencode.ai) para usar globalmente em todos os projetos.

## Arquivos

- **`opencode.json`** - Configuração principal (modelo, providers, formatters, etc.)
- **`tui.json`** - Configuração da interface TUI (tema, scroll, keybinds, etc.)
- **`agents/`** - Agentes customizados
- **`commands/`** - Comandos customizados
- **`plugins/`** - Plugins customizados
- **`themes/`** - Temas customizados

## Setup

Execute o `setup.sh` na raiz do dotfiles para criar symlinks:

```bash
./setup.sh
```

Isso criará symlinks em `~/.config/opencode/` apontando para os arquivos aqui.

## Variáveis de Ambiente

Para manter credenciais seguras, use variáveis de ambiente nos arquivos JSON:

```json
{
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{env:ANTHROPIC_API_KEY}"
      }
    }
  }
}
```

Configure as variáveis em seu `~/.bashrc` ou `~/.zshrc`:

```bash
export ANTHROPIC_API_KEY="sk-..."
```

## Mais Informações

- [OpenCode Config Docs](https://opencode.ai/docs/config/)
- [OpenCode Themes](https://opencode.ai/docs/themes/)
- [OpenCode Keybinds](https://opencode.ai/docs/keybinds/)
