-- glassterm.nvim: a floating terminal that is already running when you ask
-- for it. Toggling only shows or hides a window over a live shell.

local config = require("glassterm.config")
local integration = require("glassterm.integration")
local term = require("glassterm.term")
local window = require("glassterm.window")

local M = {}

local group = nil
local mapped = {} -- { mode, lhs } set by the last setup(), removed by the next

local function notify(msg, level)
    vim.notify("glassterm: " .. msg, level or vim.log.levels.INFO, { title = "glassterm" })
end

local function on_exit(t, code, uptime_ms)
    if config.options.close_on_exit then
        if window.is_open() and window.id == t.id then
            window.hide({ restore_focus = true, remember = false })
        end
        pcall(vim.api.nvim_buf_delete, t.buf, { force = true })
    end
    local crashed = uptime_ms < term.MIN_UPTIME_MS
    if code ~= 0 then
        notify(("%s exited with code %d"):format(t.name, code), vim.log.levels.WARN)
    end
    if t.id == 1 and config.options.prewarm.enabled and not crashed then
        vim.defer_fn(function()
            if not term.get(1) then
                term.spawn(1)
            end
        end, 50)
    end
end

local function on_spawn(t)
    local key = config.options.keys.zoom
    if key then
        vim.keymap.set({ "n", "t" }, key, M.zoom, { buffer = t.buf, desc = "glassterm: zoom" })
    end
end

local function on_request(args)
    local id = vim.b[args.buf].glassterm
    local t = id and term.terms[id]
    if not t then
        return
    end
    local ev = integration.apply(t, args.data)
    if not ev then
        return
    end
    if ev.kind == "command_end" then
        local seen = window.is_open() and window.id == t.id
        local secs = ev.duration_ms and (" · %.1fs"):format(ev.duration_ms / 1000) or ""
        if t.rerun_pending then
            t.rerun_pending = false
            if ev.status == 0 then
                notify("✓ exit 0" .. secs)
            else
                notify(("✗ exit %s%s"):format(ev.status or "?", secs), vim.log.levels.ERROR)
            end
        elseif
            not seen
            and config.options.integration.notify_on_failure
            and (ev.status or 0) ~= 0
        then
            notify(("command failed (exit %d)%s"):format(ev.status, secs), vim.log.levels.WARN)
        end
    end
    if window.id == t.id then
        window.refresh()
    end
end

-- Autocommands and highlights, shared by setup() and direct API use.
local function init_runtime()
    if group then
        return
    end
    group = vim.api.nvim_create_augroup("glassterm", { clear = true })
    require("glassterm.highlights").setup()
    term.on("exit", on_exit)
    term.on("spawn", on_spawn)

    local au = function(event, fn)
        vim.api.nvim_create_autocmd(event, { group = group, callback = fn })
    end
    au("ColorScheme", require("glassterm.highlights").setup)
    au("VimResized", window.refresh)
    au("TermRequest", on_request)
    au("WinClosed", function(args)
        if tonumber(args.match) == window.win then
            window.win = nil
        end
    end)
    au("WinLeave", function()
        if not window.is_focused() then
            return
        end
        window.remember_current()
        if not config.options.hide_on_leave then
            return
        end
        vim.schedule(function()
            local cur = vim.api.nvim_get_current_win()
            if
                window.is_open()
                and cur ~= window.win
                and vim.api.nvim_win_get_config(cur).relative == ""
            then
                window.hide({ remember = false })
            end
        end)
    end)
    -- A file opened from inside the float (:edit, a picker, gf) belongs in
    -- the window the float came from, not in the float.
    au("BufWinEnter", function(args)
        if not window.is_focused() or vim.b[args.buf].glassterm then
            return
        end
        local buf = args.buf
        vim.schedule(function()
            window.hide({ restore_focus = true, remember = false })
            vim.api.nvim_win_set_buf(0, buf)
        end)
    end)
end

local function map(modes, lhs, rhs, desc)
    if not lhs then
        return
    end
    vim.keymap.set(modes, lhs, rhs, { desc = "glassterm: " .. desc, silent = true })
    for _, mode in ipairs(modes) do
        mapped[#mapped + 1] = { mode, lhs }
    end
end

local function set_keymaps()
    for _, m in ipairs(mapped) do
        pcall(vim.keymap.del, m[1], m[2])
    end
    mapped = {}
    local keys = config.options.keys
    map({ "n", "i", "t" }, keys.toggle, function()
        M.toggle(vim.v.count > 0 and vim.v.count or nil)
    end, "toggle terminal")
    map({ "n" }, keys.send, function()
        M.send(vim.api.nvim_get_current_line())
    end, "send line to terminal")
    map({ "x" }, keys.send, function()
        local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), {
            type = vim.fn.mode(),
        })
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
        M.send(lines)
    end, "send selection to terminal")
    map({ "n" }, keys.rerun, M.rerun, "re-run last command")
end

local function schedule_prewarm()
    local p = config.options.prewarm
    if not p.enabled then
        return
    end
    local function later()
        vim.defer_fn(function()
            -- Only with a UI: scripts and headless runs never get a stray shell.
            if #vim.api.nvim_list_uis() > 0 then
                M.prewarm()
            end
        end, p.delay_ms)
    end
    if vim.v.vim_did_enter == 1 then
        later()
    else
        vim.api.nvim_create_autocmd("UIEnter", { group = group, once = true, callback = later })
    end
end

---@param opts table|nil see :help glassterm-config
function M.setup(opts)
    config.setup(opts)
    init_runtime()
    set_keymaps()
    schedule_prewarm()
    M._did_setup = true
end

---Start terminal 1's shell in the background if it is not running.
function M.prewarm()
    init_runtime()
    if not term.get(1) then
        term.spawn(1)
    end
end

local function parse(arg)
    local opts = type(arg) == "number" and { id = arg } or vim.deepcopy(arg or {})
    if opts.style and not vim.tbl_contains(config.STYLES, opts.style) then
        error(("glassterm: unknown style %q"):format(opts.style), 0)
    end
    return opts
end

---Show a terminal, or hide it if it is focused, or focus it if it is open.
---@param arg integer|{ id: integer|nil, style: string|nil }|nil
function M.toggle(arg)
    init_runtime()
    local opts = parse(arg)
    if window.in_other_tab() then
        window.hide({ remember = false })
    end
    if window.is_open() then
        if opts.id and opts.id ~= window.id then
            local t = term.ensure(opts.id)
            if t then
                window.show(t)
            end
        elseif window.is_focused() then
            window.hide({ restore_focus = true })
        else
            window.focus()
        end
        return
    end
    local t = term.ensure(opts.id or term.last)
    if t then
        window.open(t, { style = opts.style })
    end
end

---Show and focus a terminal (never hides).
function M.open(arg)
    init_runtime()
    local opts = parse(arg)
    if window.is_open() and (not opts.id or opts.id == window.id) then
        window.focus()
    else
        M.toggle(opts)
    end
end

function M.close()
    window.hide({ restore_focus = true })
end

function M.zoom()
    window.toggle_zoom()
end

---@param name "glass"|"drop"|"drawer"|"capsule"
function M.set_style(name)
    parse({ style = name })
    window.set_style(name)
end

function M.is_open()
    return window.is_open()
end

---Type text into the terminal and run it, then show the terminal.
---@param text string|string[]
function M.send(text)
    init_runtime()
    local lines = type(text) == "table" and text or vim.split(text, "\n", { plain = true })
    local t = term.ensure(term.last)
    if not t then
        return
    end
    vim.fn.chansend(t.job, table.concat(lines, "\r") .. "\r")
    if window.is_open() and window.id == t.id then
        window.focus()
    else
        M.open(t.id)
    end
end

---Re-run the shell's previous command without opening the float.
function M.rerun()
    init_runtime()
    local t = term.get(term.last)
    if not t then
        return notify("no terminal to re-run in yet", vim.log.levels.WARN)
    end
    local cmd = integration.RERUN[t.kind or ""]
    if not cmd then
        return notify("re-run needs zsh, bash or fish", vim.log.levels.WARN)
    end
    if t.busy then
        return notify("terminal busy: a command is still running", vim.log.levels.WARN)
    end
    t.rerun_pending = t.integrated == true
    t.rerun_sent = vim.uv.hrtime()
    -- Ctrl-E Ctrl-U clears anything half-typed at the prompt first.
    vim.fn.chansend(t.job, "\5\21" .. cmd .. "\r")
end

return M
