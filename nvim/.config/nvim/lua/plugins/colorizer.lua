return {
  {
    "norcalli/nvim-colorizer.lua",
    event = "VeryLazy",
    opts = {
      filetypes = {
        "*",
        "!vim",
      },
      user_default_options = {
        RGB = true,
        RRGGBB = true,
        names = false,
        RRGGBBAA = true,
        AARRGGBB = false,
        rgb_fn = true,
        hsl_fn = true,
        css = true,
        css_fn = true,
        mode = "background",
        tailwind = false,
        sass = { enable = true },
        always_update = false,
      },
    },
    config = function(_, opts)
      require("colorizer").setup(opts.filetypes, opts.user_default_options)
    end,
  },
}
