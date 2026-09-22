# glassterm.nvim

A floating terminal for Neovim that is already running when you ask for it.

Press <kbd>Alt</kbd>+<kbd>t</kbd> and a shell appears over your code in about
4 ms, because nothing starts: glassterm keeps the shell alive in a hidden
buffer and only shows or hides a window. It looks the way your terminal
does. With a transparent colorscheme the float is the same glass as the
rest of your editor, and its border tells you when a command failed.

```
 local function greet(name)
     r╭ zsh ~/code/app ───────────────────────────────────────────────────╮
 end  │~/code/app on  main                                                 │
      │❯ npm test                                                           │
 print│  ✓ 42 passing (1.2s)                                                │
 ~    │                                                                     │
 ~    │~/code/app on  main                                                 │
 ~    │❯ █                                                                  │
 ~    │                                                                     │
 ~    ╰──────────────────────────────────────────────── ⌥t hide · ⌥z zoom ╯
```

## Features

- **Instant.** The shell starts hidden about a second after Neovim's UI appears,
  so even the first toggle is a window, not a process.
- **Four shapes.** `glass` (centered pane), `drop` (Quake-style sheet from the
  top), `drawer` (side sheet), `capsule` (small box for one command). Switch
  in `setup()`, with `:Glassterm style`, or per toggle.
- **Knows your shell.** zsh, bash and fish report their folder and every
  command's exit code. The title shows the live folder, the border turns
  red when a command fails, and `[[` / `]]` jump between prompts. No rc-file
  edits: glassterm loads the hook itself, only into shells it starts.
- **Re-run without looking.** Re-run the last command from your code. A
  notification tells you `✓ exit 0 · 1.2s` or `✗ exit 1` when it's done.
- **Send code.** Send the current line or a selection to the shell.
- **Robust.** Hides when focus goes back to your code, closes when the shell
  exits (and pre-starts a fresh one), remembers whether you were typing or
  scrolled back, follows editor resizes, keeps files opened from inside it
  out of the float, and never makes quitting Neovim ask about the shell.
- **Numbered terminals.** `2⌥t` opens a second shell in the same spot.
- **No dependencies.**

## Requirements

- Neovim **0.11** or newer
- For shell integration: zsh, bash or fish (other shells work without it)
- On macOS, <kbd>Alt</kbd> keys need your terminal to send Option as Alt
  (Ghostty `macos-option-as-alt = left`, kitty `macos_option_as_alt left`,
  iTerm2 "Esc+")

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "skhan75/glassterm.nvim",
    lazy = false, -- tiny setup; loading at startup makes the first toggle instant
    opts = {},
}
```

Any other plugin manager: add the repository and call `require("glassterm").setup()`.

## Usage

| Key / command | What it does |
|---|---|
| <kbd>Alt</kbd>+<kbd>t</kbd> | Show the terminal; hide it if it's focused; focus it if it's open. Works in normal, insert and terminal mode. |
| `2`<kbd>Alt</kbd>+<kbd>t</kbd> | Terminal 2 (any count, from normal mode) |
| <kbd>Alt</kbd>+<kbd>z</kbd> | Inside the terminal: zoom to the full editor and back |
| `:Glassterm` | Same as `:Glassterm toggle` |
| `:Glassterm toggle [n]` / `open [n]` / `close` | Show/hide, show, hide |
| `:Glassterm zoom` | Zoom the open float |
| `:Glassterm style {name}` | Switch to `glass`, `drop`, `drawer` or `capsule` |
| `:Glassterm send {text}` / `:{range}Glassterm send` | Run text or buffer lines in the shell |
| `:Glassterm rerun` | Re-run the shell's last command without opening the float |

Leave terminal mode with Neovim's usual <kbd>Ctrl</kbd>+<kbd>\\</kbd> <kbd>Ctrl</kbd>+<kbd>n</kbd>.

## Configuration

These are the defaults; pass only what you want to change.

```lua
require("glassterm").setup({
    style = "glass", -- "glass" | "drop" | "drawer" | "capsule"
    -- nil uses 'shell'. A string is split on spaces; a list is used as argv.
    shell = nil,
    prewarm = { enabled = true, delay_ms = 1000 }, -- or false
    hide_on_leave = true, -- hide when focus moves to an editor window
    close_on_exit = true, -- close the float when the shell exits
    integration = { enabled = true, notify_on_failure = true }, -- or false
    ui = { hints = true }, -- key hints in the border
    keys = {
        toggle = "<M-t>", -- normal, insert and terminal mode
        zoom = "<M-z>", -- inside glassterm terminals only
        send = false, -- e.g. "<leader>ts": line (normal) or selection (visual)
        rerun = false, -- e.g. "<leader>tr"
    },
    -- Sizes: <= 1 is a fraction of the editor, > 1 is a number of cells.
    styles = {
        glass = { width = 0.86, height = 0.80 },
        drop = { height = 0.42 },
        drawer = { width = 0.44, side = "right" }, -- or "left"
        capsule = { width = 76, height = 12, row = 0.26 },
    },
})
```

Any key can be `false`. A second key for a quick capsule on top of the
default glass:

```lua
vim.keymap.set("n", "<leader>tc", function()
    require("glassterm").toggle({ style = "capsule" })
end)
```

### Styles

| Style | Shape | Border | Title |
|---|---|---|---|
| `glass` | 86% × 80%, centered | rounded | top border |
| `drop` | full width × 42%, from the top | bottom edge only, accent color | bottom edge |
| `drawer` | 44% × full height, right or left | inner edge only | winbar row |
| `capsule` | 76 × 12, upper middle | rounded, accent color | centered |

Zoom turns any of them into a full-editor window.

### Lua API

```lua
local gt = require("glassterm")
gt.toggle()                    -- or gt.toggle(2), gt.toggle({ id = 2, style = "drop" })
gt.open(n) ; gt.close() ; gt.zoom()
gt.set_style("drawer")
gt.send("make test")           -- string or list of lines
gt.rerun()
gt.prewarm()                   -- start terminal 1's shell now
gt.is_open()
```

## Shell integration

glassterm starts zsh, bash and fish with a small hook that prints standard
terminal escape codes. That's all it does: no files are written, nothing
leaves your machine.

- **OSC 7**: the current folder, at each prompt
- **OSC 133 A**: a prompt starts (Neovim uses this for `[[` / `]]`)
- **OSC 133 C / D**: a command starts / ends with its exit status

How the hook gets in, without touching your rc files:

- **zsh:** `ZDOTDIR` points at glassterm's `.zshenv`, which immediately restores
  your own `ZDOTDIR` and loads your `.zshenv`. zsh then reads your
  `.zprofile`/`.zshrc` as usual. This is the same approach Ghostty and kitty use.
- **bash:** `bash --rcfile <glassterm>/shell/bash/glassterm.bash`, which loads
  `/etc/bash.bashrc` and `~/.bashrc` first.
- **fish:** `fish --init-command 'source <glassterm>/shell/fish/glassterm.fish'`
  after your config.

Limits:
- Other shells (sh, nu, pwsh, …) run without the hook.
- bash login shells (`-l`) ignore `--rcfile`, so they also run without it.
- macOS's bash 3.2 can't report when a command *starts*, so re-run can't
  tell whether that shell is busy.

Every glassterm shell has `GLASSTERM=1` in its environment, so your rc files
can branch on it. Turn the hook off with `integration = false`.

## Highlights

Each group links to a standard one, so every colorscheme looks reasonable.
Override any of them in your colorscheme:

| Group | Default link | Used for |
|---|---|---|
| `GlasstermNormal` | `NormalFloat` | terminal background (transparent themes: glass) |
| `GlasstermBorder` | `FloatBorder` | border of glass, drawer, zoom |
| `GlasstermAccent` | `FloatTitle` | drop's edge, capsule's border |
| `GlasstermTitle` | `FloatTitle` | shell name |
| `GlasstermHint` | `Comment` | folder and key hints |
| `GlasstermError` | `DiagnosticError` | border after a failed command |
| `GlasstermErrorChip` | `DiagnosticVirtualTextError` | `exit N` chip |
| `GlasstermTab` / `GlasstermTabActive` | `Comment` / `PmenuSel` | numbered terminals |

## Performance

`make bench` drives the real plugin through a pseudo-terminal, presses
Alt-t 40 times and times keypress to finished redraw, not counting the
terminal emulator's own paint. On an M3 Pro:

| Screen | Median | p95 |
|---|---|---|
| 230 × 62 | 4.2 ms | 7.0 ms |
| 120 × 40 | 2.7 ms | 4.7 ms |

glassterm's own Lua work is about 0.07 ms of that; the rest is Neovim
redrawing the screen. Starting a new interactive zsh with a typical
oh-my-zsh setup took about 1.9 s on the same machine, which is the wait
that pre-starting removes.

## Health

`:checkhealth glassterm` reports the Neovim version, whether `setup()` ran,
whether your shell gets integration, and whether each running terminal is
sending signals.

## FAQ

**Alt+t types a † or nothing happens (macOS).** Your terminal sends Option
as a character. See [Requirements](#requirements).

**My `TermOpen` autocommand runs `startinsert`. Does pre-starting switch my
editor into insert mode?** No. glassterm defers `TermOpen` for its shells
until the float is first shown, and then runs it in the float.

**Alt+t inside another terminal buffer toggles glassterm.** That's by
design: one key, everywhere. Set `keys.toggle` to something else if you
need Alt+t inside terminals.

## Development

```sh
make test                                 # all tests (headless Neovim + mini.test)
make test-file FILE=tests/test_styles.lua # one file
make lint                                 # stylua --check
make bench                                # toggle latency
```

Screenshot tests compare against `tests/screenshots/`. Delete a reference
to regenerate it, then review the new file by eye before committing.

## License

MIT
