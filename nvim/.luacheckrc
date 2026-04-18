-- Luacheck configuration for Neovim configuration
-- This file configures luacheck for Lua linting in the nvim config

-- Standard warnings and errors
std = "lua54"
max_line_length = 120

-- Ignore specific warnings globally
ignore = {
  "631", -- Line is too long
}

-- Define globals that should not trigger undefined variable warnings
-- Neovim and Lua standard library globals
globals = {
  -- Neovim globals
  "vim",
  
  -- Standard Lua functions (usually builtin)
  "load",
  "loadstring",
  "xpcall",
  "pairs",
  "ipairs",
  "tonumber",
  "tostring",
  "type",
  "unpack",
  "table",
  "string",
  "math",
  "os",
  "io",
  "coroutine",
  "debug",
  "bit",
  "utf8",
}

-- Configuration for specific directories/files
files["**/lua/**"] = {
  globals = {
    -- Additional globals for Neovim configuration
    "vim",
  },
}

-- Relax some checks for plugin configurations
files["**/lua/plugins/**"] = {
  -- Plugins can have unused variables in return tables
}

-- More lenient for config files
files["**/lua/config/**"] = {
  -- Config files might have intentionally unused variables
}
