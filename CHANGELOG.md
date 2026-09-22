# Changelog

## 0.1.0 (2026-09-21)

First release.

- Floating terminal toggled with one key in normal, insert and terminal mode,
  over a shell that is started hidden in advance (no process starts on toggle).
- Four styles: `glass`, `drop`, `drawer`, `capsule`; switchable in `setup()`,
  with `:Glassterm style`, or per toggle. Zoom to the full editor.
- Shell integration for zsh, bash and fish, injected without editing rc files:
  live folder in the title, a failure border and `exit N` chip, prompt jumps.
- Numbered terminals, send line/selection, re-run with a result notification.
- Hide on focus leave, close and re-prestart on exit, mode and scroll memory,
  resize handling, files opened in the float moved to the previous window.
- `:Glassterm` command, `:checkhealth glassterm`, `:help glassterm`.
