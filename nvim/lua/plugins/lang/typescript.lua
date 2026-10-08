-- O extra lang.typescript (e o linting.eslint) sobem o servidor na raiz do
-- monorepo (pnpm-lock.yaml ou .git) e ligam recursos que pesam com dezenas de
-- milhares de arquivos. Aqui a raiz passa a ser o tsconfig.json mais próximo
-- do buffer, e o que é caro fica desligado.

-- Embrulha o root_dir do nvim-lspconfig: ele continua decidindo SE o servidor
-- sobe (exclusão de deno; no eslint, o guarda de config de ESLint na árvore) e
-- a raiz que ele acharia vira o limite de busca do tsconfig.json. `stop` não
-- examina o próprio diretório do lock/.git.
local function tsconfig_root(default)
  return function(bufnr, on_dir)
    default(bufnr, function(project_root)
      local found = vim.fs.find("tsconfig.json", {
        path = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)),
        upward = true,
        type = "file",
        limit = 1,
        stop = project_root,
      })[1]
      local dir = found and vim.fs.dirname(found)
      on_dir(dir and vim.fs.relpath(project_root, dir) and dir or project_root)
    end)
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Lido antes de o LazyVim chamar vim.lsp.config(server, ...), então ainda
      -- é o root_dir de nvim-lspconfig/lsp/<server>.lua.
      for _, server in ipairs({ "vtsls", "eslint" }) do
        local default = vim.lsp.config[server] and vim.lsp.config[server].root_dir
        if type(default) == "function" then
          opts.servers[server] = opts.servers[server] or {}
          opts.servers[server].root_dir = tsconfig_root(default)
        end
      end

      -- Tirar o extra lang.tailwind não basta: o servidor que ele instalou no
      -- Mason é ligado pelo mason-lspconfig, e o root_dir dele cai no .git
      -- quando não há tailwind.config.
      opts.servers.tailwindcss = { enabled = false }

      opts.servers.vtsls = vim.tbl_deep_extend("force", opts.servers.vtsls or {}, {
        settings = {
          complete_function_calls = false,
          typescript = {
            suggest = { completeFunctionCalls = false },
            updateImportsOnFileMove = { enabled = "never" },
            inlayHints = {
              enumMemberValues = { enabled = false },
              functionLikeReturnTypes = { enabled = false },
              parameterNames = { enabled = "none" },
              parameterTypes = { enabled = false },
              propertyDeclarationTypes = { enabled = false },
              variableTypes = { enabled = false },
            },
            preferences = { includePackageJsonAutoImports = "off" },
            tsserver = { maxTsServerMemory = 4096 },
          },
        },
      })
      return opts
    end,
  },
}
