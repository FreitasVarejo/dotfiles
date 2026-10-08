-- TypeScript pelo tsgo (extra lang.typescript.tsgo, servidor nativo do TS 7).
-- O tsgo atende o monorepo inteiro numa instância só, com raiz no lockfile, e
-- usa o node_modules/.bin/tsgo de lá quando o projeto tem um: a raiz dele fica
-- a do nvim-lspconfig. O eslint, que sobe na raiz do monorepo e pesa com
-- dezenas de milhares de arquivos, passa a subir no tsconfig.json mais próximo
-- do buffer e só lint no save.

-- Embrulha o root_dir do nvim-lspconfig: ele continua decidindo SE o servidor
-- sobe (o guarda de config de ESLint na árvore) e a raiz que ele acharia vira
-- o limite de busca do tsconfig.json. `stop` não examina o próprio diretório
-- do lock/.git.
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
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "scss" } },
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Lido antes de o LazyVim chamar vim.lsp.config(server, ...), então ainda
      -- é o root_dir de nvim-lspconfig/lsp/eslint.lua.
      local default = vim.lsp.config.eslint and vim.lsp.config.eslint.root_dir
      opts.servers.eslint = opts.servers.eslint or {}
      if type(default) == "function" then
        opts.servers.eslint.root_dir = tsconfig_root(default)
      end
      opts.servers.eslint.settings = vim.tbl_deep_extend("force", opts.servers.eslint.settings or {}, {
        run = "onSave",
      })

      -- Tirar o extra lang.tailwind não basta: o servidor que ele instalou no
      -- Mason é ligado pelo mason-lspconfig, e o root_dir dele cai no .git
      -- quando não há tailwind.config.
      opts.servers.tailwindcss = { enabled = false }

      -- A extra tsgo liga quase todos os inlay hints; aqui ficam desligados
      -- (<leader>uh liga no buffer).
      opts.servers.tsgo = vim.tbl_deep_extend("force", opts.servers.tsgo or {}, {
        settings = {
          typescript = {
            inlayHints = {
              enumMemberValues = { enabled = false },
              functionLikeReturnTypes = { enabled = false },
              parameterNames = { enabled = "none" },
              parameterTypes = { enabled = false },
              propertyDeclarationTypes = { enabled = false },
              variableTypes = { enabled = false },
            },
          },
        },
      })
      return opts
    end,
  },
}
