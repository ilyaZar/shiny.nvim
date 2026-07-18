# tapyr.nvim

`tapyr.nvim` provides a small Neovim workflow for local Shiny for Python apps.
It discovers projects from an `app.py` import, runs app and test commands
through Overseer, and lists local Shiny listeners in a floating manager.

## Requirements

- Neovim 0.10 or newer
- Linux with `/proc` and `ss`
- [`overseer.nvim`](https://github.com/stevearc/overseer.nvim)
- `uv` and Shiny for Python in each app project

## Installation

With lazy.nvim:

```lua
{
  "ilyaZar/tapyr.nvim",
  dependencies = {
    "stevearc/overseer.nvim",
  },
}
```

For a local development checkout:

```lua
{
  name = "tapyr.nvim",
  dir = vim.fn.expand("~/path/to/tapyr.nvim"),
  dependencies = {
    "stevearc/overseer.nvim",
  },
}
```

Tapyr initializes automatically and requires no configuration call.

## Usage

Open a file below a Shiny `app.py`. Tapyr adds these buffer-local mappings:

- `Ctrl+b` runs the app
- `Ctrl+Shift+b` restarts the app task
- `Ctrl+t` runs the test suite
- `<leader>tm` opens the manager

`:Tapyr` opens the manager directly.

Inside the manager:

- `Tab` and `Shift+Tab` cycle views
- `R` restarts the selected app
- `K` terminates the selected process
- `S` opens the selected app
- `Enter` opens paths from the Build view
- `q`, `Esc`, or `C` closes the manager

Run `:checkhealth tapyr` to verify external dependencies.

## Current Scope

Tapyr currently uses fixed `uv run shiny run app.py` and `uv run pytest`
commands. Project detection expects an `app.py` that imports `shiny`.

The listener view reports raw Shiny-related sockets. Shiny reload helper
listeners may therefore appear beside the public app port.

## Development

Run the isolated headless smoke test:

```bash
./scripts/test
```

## License

MIT
