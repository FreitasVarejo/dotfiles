return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function()
      return {
        sections = {
          lualine_c = {
            {
              "filename",
              path = 1,
            },
          },
          lualine_x = {
            {
              function()
                local icons = require("lazyvim.util").ui.icons
                local day = os.date("%d")
                local month_num = tonumber(os.date("%m"))
                local months = { "Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez" }
                local month = months[month_num]
                return icons.calendar .. " " .. day .. " " .. month
              end,
              color = function()
                return { fg = "#9ece6a" }
              end,
            },
          },
        },
      }
    end,
  },
}
