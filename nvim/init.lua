-- bread's neovim config
-- keymaps are in lua/config/mappings.lua
-- install a patched font & ensure your terminal supports glyphs
-- enjoy :D

-- auto install vim-plug and plugins, if not found
local data_dir = vim.fn.stdpath('data')
if vim.fn.empty(vim.fn.glob(data_dir .. '/site/autoload/plug.vim')) == 1 then
    vim.cmd('silent !curl -fLo ' .. data_dir .. '/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim')
    vim.o.runtimepath = vim.o.runtimepath
    vim.cmd('autocmd VimEnter * PlugInstall --sync | source $MYVIMRC')
end

local vim = vim
local Plug = vim.fn['plug#']

vim.g.start_time = vim.fn.reltime()
vim.loader.enable() --  SPEEEEEEEEEEED 
vim.call('plug#begin')

-- Basic UI & Utilities
Plug('catppuccin/nvim', { ['as'] = 'catppuccin' }) --colorscheme
Plug('ellisonleao/gruvbox.nvim', { ['as'] = 'gruvbox' }) --colorscheme 2
Plug('uZer/pywal16.nvim', { [ 'as' ] = 'pywal16' }) --or, pywal colorscheme
Plug('nvim-lualine/lualine.nvim') --statusline
Plug('nvim-tree/nvim-web-devicons') --pretty icons
Plug('folke/which-key.nvim') --mappings popup
Plug('romgrk/barbar.nvim') --bufferline
Plug('goolord/alpha-nvim') --pretty startup
Plug('nvim-treesitter/nvim-treesitter') --improved syntax
Plug('mfussenegger/nvim-lint') --async linter
Plug('nvim-tree/nvim-tree.lua') --file explorer
Plug('windwp/nvim-autopairs') --autopairs 
Plug('lewis6991/gitsigns.nvim') --git
Plug('numToStr/Comment.nvim') --easier comments
Plug('norcalli/nvim-colorizer.lua') --color highlight
Plug('ibhagwan/fzf-lua') --fuzzy finder and grep
Plug('numToStr/FTerm.nvim') --floating terminal
Plug('ron-rs/ron.vim') --ron syntax highlighting
Plug('MeanderingProgrammer/render-markdown.nvim') --render md inline
Plug('emmanueltouzery/decisive.nvim') --view csv files
Plug('folke/twilight.nvim') --surrounding dim

-- POWER USER PLUGINS (LSP + Autocomplete + Snippets)
Plug('neovim/nvim-lspconfig')             -- Configurações básicas de LSP
Plug('williamboman/mason.nvim')           -- Gerenciador de LSPs/Linters
Plug('williamboman/mason-lspconfig.nvim') -- Ponte entre Mason e LSPConfig

Plug('hrsh7th/nvim-cmp')      -- Engine de Autocompletar
Plug('hrsh7th/cmp-nvim-lsp')  -- Fonte de LSP para o cmp
Plug('hrsh7th/cmp-buffer')    -- Fonte de buffer para o cmp
Plug('hrsh7th/cmp-path')      -- Fonte de caminhos (paths) para o cmp

Plug('L3MON4D3/LuaSnip')             -- Engine de Snippets
Plug('saadparwaiz1/cmp_luasnip')     -- Ponte entre Snippets e cmp
Plug('rafamadriz/friendly-snippets') -- Coleção de snippets prontos

vim.call('plug#end')

-- move config and plugin config to alternate files
require("config.theme")
require("config.mappings")
require("config.options")
require("config.autocmd")

require("plugins.alpha")
-- require("plugins.autopairs")
require("plugins.barbar")
require("plugins.colorizer")
require("plugins.colorscheme")
require("plugins.comment")
-- require("plugins.fterm")
-- require("plugins.fzf-lua")
require("plugins.gitsigns")
require("plugins.lualine")
require("plugins.nvim-lint")
-- require("plugins.nvim-tree")
require("plugins.render-markdown")
-- require("plugins.treesitter")
-- require("plugins.twilight")
-- require("plugins.which-key")

vim.defer_fn(function() 
        --defer non-essential configs,
        --purely for experimental purposes:
        --this only makes a difference of +-10ms on initial startup
    require("plugins.autopairs")
    require("plugins.fterm")
    require("plugins.fzf-lua")
    require("plugins.nvim-tree")
    require("plugins.treesitter")
    require("plugins.twilight")
    require("plugins.which-key")
end, 100)

load_theme()

-- CONFIGURAÇÃO POWER USER
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "lua_ls", "clangd", "pyright" } -- C++, Python, Lua
})

local lspconfig = require('lspconfig')
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- Ativa LSPs instalados via Mason automaticamente
require("mason-lspconfig").setup_handlers {
    function (server_name)
        lspconfig[server_name].setup {
            capabilities = capabilities
        }
    end,
}

-- Configuração do Autocompletar (CMP)
local cmp = require('cmp')
cmp.setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Enter confirma
    ['<Tab>'] = cmp.mapping.select_next_item(),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  }, {
    { name = 'buffer' },
    { name = 'path' },
  })
})
