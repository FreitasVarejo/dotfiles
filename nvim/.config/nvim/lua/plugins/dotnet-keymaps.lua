-- .NET Development Keymaps
-- Provides convenient shortcuts for building, testing, debugging, and running C# projects

return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>d", group = ".NET Development" },
        { "<leader>db", "<cmd>TermExec cmd='dotnet build'<cr>", desc = "Build project" },
        { "<leader>dr", "<cmd>TermExec cmd='dotnet run'<cr>", desc = "Run project" },
        { "<leader>dt", "<cmd>TermExec cmd='dotnet test'<cr>", desc = "Run tests" },
        { "<leader>dw", "<cmd>TermExec cmd='dotnet watch run'<cr>", desc = "Watch & run" },
        { "<leader>dc", "<cmd>TermExec cmd='dotnet clean'<cr>", desc = "Clean project" },
        { "<leader>dd", "<cmd>TermExec cmd='netcoredbg --interpreter=vscode'<cr>", desc = "Start debugger" },
        { "<leader>dx", "<cmd>TermExec cmd='dotnet format'<cr>", desc = "Format solution" },
      },
    },
  },

  {
    "mbbill/undotree",
    optional = true,
  },
}
