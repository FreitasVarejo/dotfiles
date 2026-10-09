---
paths:
  - "nvim/lua/plugins/lang/dotnet.lua"
  - "nvim/hooks/**"
---

# C# / Roslyn

- The client is `seblyng/roslyn.nvim` with the Roslyn LSP from Mason (custom registry
  `github:Crashdummyy/mason-registry`); it needs the .NET SDK on `PATH`.
- Keep `filewatching = "off"` plus the `didChangeWatchedFiles` notification on save:
  watching `bin/`/`obj/` makes the server reanalyse the solution on every build.
- The inotify limit in `nvim/hooks/setup.sh` is there so a big solution loads at all;
  the editor still doesn't watch.
