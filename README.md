# shiny.nvim

`shiny.nvim` is a Neovim workflow for Shiny for Python applications and
golem-based R Shiny packages. It detects either project type, runs applications
and tests through Overseer, assigns managed ports, and presents their lifecycle
in one panel.

The panel also contains Golex: a scratch-project manager for creating and
opening disposable golem applications across persistent shelf directories.

The GitHub repository retains the `tapyr.nvim` name until a separate remote
rename. The plugin itself uses only the canonical `shiny.nvim` modules,
commands, help tags, filetypes, and data paths.

## Supported projects

- Shiny for Python projects with an `app.py` that imports `shiny`
- golem packages with `DESCRIPTION` and `inst/golem-config.yml`

Ordinary R Shiny projects that are not golem packages are not detected.

## Requirements

Shared:

- Neovim 0.11 or newer
- [overseer.nvim](https://github.com/stevearc/overseer.nvim)

For Shiny for Python:

- `shiny` and `pytest` in an ancestor `.venv/bin` or Neovim's `PATH`
- optionally `uv` and an ancestor `uv.lock` for first-run `uv sync`
- optionally Linux `/proc` and `ss` to discover apps started outside Neovim

For golem and Golex:

- `Rscript`
- the R packages `golem`, `pkgload`, `shiny`, and `testthat`
- optionally [R.nvim](https://github.com/R-nvim/R.nvim) for
  `document_and_reload()` and `run_dev()`

Python users do not need R, R.nvim, or any R package.

## Installation

With lazy.nvim:

```lua
{
  "ilyaZar/tapyr.nvim",
  name = "shiny.nvim",
  dependencies = {
    "stevearc/overseer.nvim",
  },
  opts = {},
}
```

For a local checkout:

```lua
{
  name = "shiny.nvim",
  dir = vim.fn.expand("~/path/to/shiny.nvim"),
  dependencies = {
    "stevearc/overseer.nvim",
  },
}
```

Shiny initializes automatically. Its defaults can be changed through `opts`:

```lua
{
  "ilyaZar/tapyr.nvim",
  name = "shiny.nvim",
  dependencies = {
    "stevearc/overseer.nvim",
  },
  opts = {
    settings_path = vim.fn.stdpath("config") .. "/lua/plugins/shiny.lua",
    template_path_new_app =
      "https://github.com/Appsilon/tapyr-template.git",
    mappings = {
      run = "<C-b>",
      restart = "<C-S-b>",
      test = "<C-t>",
      panel = "<leader>tm",
      document_reload = "<C-g>",
      run_dev = "<C-S-g>",
    },
    golex = {
      dir = "/tmp/golskels",
      shelves_path =
        vim.fs.joinpath(vim.fn.stdpath("data"), "shiny", "golex.json"),
      open_cmd = { "nvim" },
    },
  },
}
```

Set an individual mapping to `false` to disable it. The two Golem mappings are
attached only inside a detected golem package.

`golex.open_cmd` is an argv array. `{ "nvim" }` uses `xdg-terminal-exec`,
Ghostty, or Alacritty on Linux. GUI launchers such as `{ "code" }`,
`{ "positron" }`, and `{ "rstudio" }` receive the selected project path
directly. RStudio prefers an `.Rproj`, then `DESCRIPTION`, then
`dev/01_start.R`.

To preserve another R.nvim companion's hook, chain Shiny through the R.nvim
options table:

```lua
{
  "R-nvim/R.nvim",
  opts = function(_, opts)
    require("shiny").setup_rnvim(opts)
  end,
}
```

The hook is optional because managed Golem lifecycle tasks use `Rscript`.

## Usage

The canonical command is `:Shiny`:

- `:Shiny` opens the Apps tab
- `:Shiny panel VIEW` opens `apps`, `golex`, `settings`, or `help`
- `:Shiny golex` opens the native Golex tab
- `:Shiny golex 7` creates `golex07`
- `:Shiny golex my.app` creates `my.app`
- `:Shiny golex next` creates the next numbered Golex app
- `:Shiny action document-reload` sends `golem::document_and_reload()` through
  R.nvim
- `:Shiny action run-dev` sends `golem::run_dev()` through R.nvim

The `run-dev` action executes the project-owned development script. It is
separate from the managed run and restart lifecycle.

Detected project buffers receive:

- `Ctrl+b` to run
- `Ctrl+Shift+b` to restart
- `Ctrl+t` to test
- `<leader>tm` to open the panel
- `Ctrl+g` to document and reload a Golem package through R.nvim
- `Ctrl+Shift+g` to run a Golem dev script through R.nvim

## Panel

`Tab` and `Shift+Tab` cycle Apps, Golex, Settings, and Help. `j`, `k`, the arrow
keys, `gg`, and `G` move between selectable rows. `q` or `Esc` closes the panel.

Every tab uses the same bracketed footer syntax, but only its visible actions
are active:

- Apps: app details, restart, stop, browser, refresh, Python template, close
- Golex: create/open, delete, shelves, next app, new Golex app, close
- Settings: edit mapping, close
- Help: open link, close

Apps shows backend, state, assigned port, process details when available, launch
command, and project. `Enter` opens backend-aware details.

Settings shows the effective shared and Golem-specific mappings. Selecting a
mapping opens `settings_path` when that readable file is configured. Shiny never
creates or overwrites the settings file.

## Golex

The Golex tab keeps an editable row above the selectable projects. Press `N` or
`i`, type an R package name or number, and press `Enter`. Numeric input is
formatted with at least two digits.

On a project row:

- `Enter` opens the Open/Recreate dialog
- `d` asks before recursively deleting that project

Press `S` for shelves. Its editable row adds a shelf; `Enter` selects a shelf,
and `d` asks before recursively deleting the selected shelf directory and every
project below it. The configured default shelf cannot be deleted.

Golex apps and shelves are intentionally disposable. Deletion removes their
directories, not only their registry entries. Every destructive prompt names the
complete recursive effect, and deletion is bounded to the selected canonical
entry.

Creation calls `golem::create_golem()` asynchronously. The destination is an
`Rscript` argument and is never interpolated into R source.

## Lifecycle

Python runs:

```text
shiny run --reload --port PORT app.py
```

Python tests run `pytest`. If `shiny` is missing and an ancestor `uv.lock`
exists, one shared `uv sync` task prepares that project before retrying.

Golem runs a package loaded with `pkgload::load_all()`, then passes `run_app()`
to `shiny::runApp()` with the assigned `SHINY_PORT`. This bypasses
`dev/run_dev.R`, whose project-owned behavior may select another port or perform
unrelated preparation. Golem tests run `testthat::test_local(".")`.

Managed applications have one Overseer task per backend-qualified app ID.
Overseer metadata is authoritative for their backend, port, and running state.
Ports are assigned from 8000 through 8199 unless the registry reserves one.
Shiny reports collisions and never stops an unrelated listener.

Linux `ss` and `/proc` discovery supplements managed state for external Shiny
for Python commands. It is not required for plugin-started applications.

## Registries and overrides

Shiny reads `stdpath("config")/shiny.json` and the nearest `.shiny.json`.
Workspace entries appear first and replace matching global entries.

```json
{
  "version": 1,
  "apps": [
    {
      "name": "Python dashboard",
      "path": "apps/dashboard",
      "port": 8012
    },
    {
      "name": "Golem dashboard",
      "path": "packages/dashboard",
      "run": ["Rscript", "dev/run_dev.R"],
      "test": ["Rscript", "tests/testthat.R"]
    }
  ]
}
```

Paths may be absolute or relative to the registry. Shiny detects the backend
from the target directory. `run` and `test` overrides must be non-empty argv
arrays. Run overrides receive `SHINY_PORT`; they must honor it for accurate port
tracking and browser URLs.

## Health and development

Run `:checkhealth shiny` for shared, Python, Golem, Golex, and optional R.nvim
capabilities.

Run the headless suite:

```bash
./scripts/test
```

Generate coverage:

```bash
./scripts/coverage
```

This unified implementation incorporates work from Tapyr.nvim and Rgolem.nvim.
Both copyright notices are preserved in [LICENSE](LICENSE).
