return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        lua = { "luacheck" },
      },
    },
    config = function(_, opts)
      local lint = require("lint")
      
      -- Configure luacheck
      local luacheck = lint.linters.luacheck
      luacheck.args = {
        "--codes",
        "--ranges",
      }
      
      -- Set linters
      lint.linters_by_ft = opts.linters_by_ft
      
      -- Auto-lint on save
      local lint_group = vim.api.nvim_create_augroup("lua_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        group = lint_group,
        ft = "lua",
        callback = function()
          lint.try_lint()
        end,
      })
      
      -- Lint on text change with debounce
      vim.api.nvim_create_autocmd({ "BufReadPost", "InsertLeave" }, {
        group = lint_group,
        ft = "lua",
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
}
