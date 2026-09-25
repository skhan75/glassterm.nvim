# glassterm.nvim

A Neovim floating terminal plugin whose shell is already running when you ask
for it: an instant toggle, four float styles (centered, Quake-style drop-down,
side drawer, capsule) and shell integration for zsh, bash and fish.

![glassterm: toggle, run, hide, zoom](assets/hero.gif)

- **Instant.** The shell starts hidden in the background, so <kbd>Alt</kbd>+<kbd>t</kbd>
  only shows a window: about 4 ms, no process start.
- **Four styles.** Glass, drop, drawer and capsule. Pick one or switch any time.
- **Knows your shell.** zsh, bash and fish show their folder in the title, turn
  the border red when a command fails, and can re-run the last command from
  your code.
- **No dependencies.** Neovim 0.11+.

## How it compares

- **toggleterm.nvim** is the mature all-rounder: splits, tabs, many terminals,
  a big ecosystem. glassterm keeps one terminal, starts its shell in advance,
  and adds shell integration (folder in the title, red border on failure,
  re-run with a result notification).
- **snacks.nvim's terminal** is great if you already run snacks. glassterm is
  standalone and gives you the four float shapes and the shell hook.
- **vim-floaterm** offers many window positions for Vim and Neovim.
  glassterm is Neovim-only and trades breadth for the instant toggle and the
  shell integration.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "skhan75/glassterm.nvim", lazy = false, opts = {} }
```

## Use

| Key / command | |
|---|---|
| <kbd>Alt</kbd>+<kbd>t</kbd> | Show / hide the terminal (normal, insert and terminal mode) |
| <kbd>Alt</kbd>+<kbd>z</kbd> | Zoom to the full editor and back |
| `2`<kbd>Alt</kbd>+<kbd>t</kbd> | A second terminal |
| `:Glassterm style drop` | Switch style |
| `:Glassterm send make test` | Run a command, or selected lines with `:'<,'>Glassterm send` |
| `:Glassterm rerun` | Re-run the last command without opening the terminal |

On macOS, your terminal must send Option as Alt (Ghostty
`macos-option-as-alt = left`, iTerm2 "Esc+", kitty `macos_option_as_alt left`).

## Styles

| `glass` | `drop` |
|---|---|
| ![glass](assets/style-glass.gif) | ![drop](assets/style-drop.gif) |
| **`drawer`** | **`capsule`** |
| ![drawer](assets/style-drawer.gif) | ![capsule](assets/style-capsule.gif) |

```lua
opts = { style = "drawer" }
```

## Shell integration

The title follows `cd`, a failed command turns the border red, and
`:Glassterm rerun` reports back while you stay in your code. glassterm adds a
small hook only to the zsh, bash and fish shells it starts. Your rc files are
never edited.

![shell integration](assets/shell.gif)

## Configuration

<details>
<summary>Defaults</summary>

```lua
require("glassterm").setup({
    style = "glass", -- "glass" | "drop" | "drawer" | "capsule"
    shell = nil, -- nil uses 'shell'
    prewarm = { enabled = true, delay_ms = 1000 },
    hide_on_leave = true, -- hide when you go back to your code
    close_on_exit = true,
    integration = { enabled = true, notify_on_failure = true },
    ui = { hints = true },
    keys = {
        toggle = "<M-t>",
        zoom = "<M-z>",
        send = false, -- e.g. "<leader>ts"
        rerun = false, -- e.g. "<leader>tr"
    },
    styles = { -- <= 1 is a fraction of the editor, > 1 is cells
        glass = { width = 0.86, height = 0.80 },
        drop = { height = 0.42 },
        drawer = { width = 0.44, side = "right" },
        capsule = { width = 76, height = 12, row = 0.26 },
    },
})
```

</details>

Everything else (the Lua API, highlight groups, how the shell hook works) is
in `:help glassterm`. `:checkhealth glassterm` shows whether your shell is
connected.

## Development

`make test` runs the tests, `make bench` measures toggle latency, and
`make demo` re-records these GIFs with [VHS](https://github.com/charmbracelet/vhs).

## License

MIT
