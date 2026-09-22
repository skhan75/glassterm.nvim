-- The single float: show, hide, focus, zoom and decorate. Knows nothing
-- about processes; term.lua owns those.

local config = require("glassterm.config")
local styles = require("glassterm.styles")
local term = require("glassterm.term")
local ui = require("glassterm.ui")

local M = {
    win = nil, -- float window id
    id = nil, -- terminal shown in it
    prev = nil, -- window focus returns to
    zoomed = false,
    style = nil, -- one-open style override
}

function M.is_open()
    return M.win ~= nil and vim.api.nvim_win_is_valid(M.win)
end

function M.is_focused()
    return M.is_open() and vim.api.nvim_get_current_win() == M.win
end

local function style_name()
    return M.style or config.options.style
end

local function info(t, layout)
    local opts = config.options
    local hints = {}
    if opts.ui.hints then
        if opts.keys.toggle then
            hints[#hints + 1] = ui.key_label(opts.keys.toggle) .. " hide"
        end
        if opts.keys.zoom then
            hints[#hints + 1] = ui.key_label(opts.keys.zoom) .. (M.zoomed and " shrink" or " zoom")
        end
    end
    return {
        shell = t.name,
        cwd = t.cwd and ui.pretty_path(t.cwd) or false,
        status = not t.busy and t.status or nil,
        terms = term.ids(),
        current = t.id,
        hints = hints,
        -- nvim starts a footer one cell in even with no corner, so an edge-only
        -- bottom border has one cell less for it.
        width = layout.slot == "bottom" and layout.width - 1 or layout.width,
        border_hl = layout.border_hl,
    }
end

-- Window config, window-local options and border group for terminal `t`.
local function build(t)
    local name = style_name()
    local layout = styles.layout(name, config.options.styles[name], styles.editor(), {
        zoom = M.zoomed,
    })
    local deco = ui.decorations(layout.slot, info(t, layout))
    local failed = t.status ~= nil and t.status ~= 0 and not t.busy
    local cfg = {
        relative = "editor",
        row = layout.row,
        col = layout.col,
        width = layout.width,
        height = layout.height,
        border = layout.border,
        zindex = 45, -- below pickers, menus and notifications
        title = deco.title or "",
        footer = deco.footer or "",
    }
    if deco.title then
        cfg.title_pos = deco.title_pos
    end
    if deco.footer then
        cfg.footer_pos = deco.footer_pos
    end
    return cfg, deco, failed and "GlasstermError" or layout.border_hl
end

local function set_wo(name, value)
    vim.api.nvim_set_option_value(name, value, { win = M.win, scope = "local" })
end

local function decorate(deco, border_hl)
    set_wo(
        "winhighlight",
        ("NormalFloat:GlasstermNormal,FloatBorder:%s,FloatTitle:GlasstermTitle,FloatFooter:GlasstermHint"):format(
            border_hl
        )
    )
    set_wo("winbar", deco.winbar or "")
end

-- Record how the user left the terminal so reopening can put them back.
local function remember(t)
    if not t or not M.is_open() then
        return
    end
    t.mode = vim.api.nvim_get_mode().mode == "t" and "t" or "nt"
    t.cursor = vim.api.nvim_win_get_cursor(M.win)
end

function M.remember_current()
    if M.is_focused() then
        remember(term.terms[M.id])
    end
end

local function enter(t)
    if not t.opened then
        -- Deferred from spawn (see term.lua): runs users' terminal setup now,
        -- in the window that shows the terminal.
        t.opened = true
        vim.api.nvim_exec_autocmds("TermOpen", { buffer = t.buf, modeline = false })
    end
    if t.mode == "nt" and t.cursor then
        local last = vim.api.nvim_buf_line_count(t.buf)
        pcall(vim.api.nvim_win_set_cursor, M.win, { math.min(t.cursor[1], last), t.cursor[2] })
        vim.cmd.stopinsert()
    else
        vim.cmd.startinsert()
    end
end

---@param t table terminal
---@param opts { style: string|nil }|nil
function M.open(t, opts)
    opts = opts or {}
    M.style = opts.style
    M.zoomed = false
    M.prev = vim.api.nvim_get_current_win()
    local cfg, deco, border_hl = build(t)
    cfg.style = "minimal"
    M.win = vim.api.nvim_open_win(t.buf, true, cfg)
    M.id = t.id
    term.last = t.id
    decorate(deco, border_hl)
    set_wo("scrolloff", 0)
    set_wo("sidescrolloff", 0)
    enter(t)
end

---Show another terminal in the already-open float.
function M.show(t)
    remember(term.terms[M.id])
    vim.api.nvim_win_set_buf(M.win, t.buf)
    M.id = t.id
    term.last = t.id
    vim.api.nvim_set_current_win(M.win)
    M.refresh()
    enter(t)
end

function M.focus()
    if not M.is_open() then
        return
    end
    local cur = vim.api.nvim_get_current_win()
    if cur ~= M.win then
        M.prev = cur
    end
    vim.api.nvim_set_current_win(M.win)
    enter(term.terms[M.id])
end

---@param opts { restore_focus: boolean|nil, remember: boolean|nil }|nil
function M.hide(opts)
    opts = opts or {}
    if not M.is_open() then
        M.win = nil
        return
    end
    if opts.remember ~= false then
        M.remember_current()
    end
    local win = M.win
    M.win, M.zoomed, M.style = nil, false, nil
    if opts.restore_focus and M.prev and vim.api.nvim_win_is_valid(M.prev) and M.prev ~= win then
        vim.api.nvim_set_current_win(M.prev)
    end
    if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_hide(win)
    end
end

---Recompute geometry and decorations (resize, zoom, style or state change).
function M.refresh()
    if not M.is_open() then
        return
    end
    local t = term.terms[M.id]
    if not t then
        return
    end
    local cfg, deco, border_hl = build(t)
    vim.api.nvim_win_set_config(M.win, cfg)
    decorate(deco, border_hl)
end

function M.toggle_zoom()
    if M.is_open() then
        M.zoomed = not M.zoomed
        M.refresh()
    end
end

---@param name string
function M.set_style(name)
    config.options.style = name
    M.style = nil
    M.refresh()
end

return M
