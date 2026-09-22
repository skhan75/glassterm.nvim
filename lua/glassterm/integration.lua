-- Shell integration: how each shell is started so it reports its folder
-- and exit codes (see shell/), and how those reports update a terminal.

local osc = require("glassterm.osc")

local M = {}

-- lua/glassterm/integration.lua -> plugin root
M.ROOT = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

-- Re-run the previous command with each shell's own history mechanism rather
-- than a simulated Up + Enter, which history tools such as atuin rebind.
-- The leading space keeps the re-run itself out of history where supported.
M.RERUN = {
    zsh = " fc -e - -1",
    bash = " fc -s",
    fish = " eval $history[1]",
}

---@param shell string|string[]|nil config value; nil uses 'shell'
---@return string[]
function M.argv(shell)
    shell = shell or vim.o.shell
    if type(shell) == "table" then
        return vim.deepcopy(shell)
    end
    return vim.split(shell, "%s+", { trimempty = true })
end

---Shell family for an argv, or nil when it is not a plain interactive
---zsh/bash/fish (e.g. `sh`, `nu`, or anything run with -c).
---@param argv string[]
---@return "zsh"|"bash"|"fish"|nil
function M.kind(argv)
    local name = vim.fs.basename(argv[1] or ""):gsub("%-[%d.]+$", "")
    if name ~= "zsh" and name ~= "bash" and name ~= "fish" then
        return nil
    end
    for i = 2, #argv do
        local a = argv[i]
        if a == "-c" or (name == "bash" and (a == "-l" or a == "--login")) then
            -- A command, or a bash login shell (which ignores --rcfile).
            return nil
        end
    end
    return name
end

---@param shell string|string[]|nil
---@param id integer terminal number
---@param enabled boolean inject the integration hooks
---@return string[] argv, table env, string|nil kind
function M.command(shell, id, enabled)
    local argv = M.argv(shell)
    local kind = M.kind(argv)
    local env = { GLASSTERM = "1", GLASSTERM_ID = tostring(id) }
    if not (enabled and kind) then
        return argv, env, kind
    end

    if kind == "zsh" then
        -- Our .zshenv restores ZDOTDIR before zsh reads the user's files.
        env.GLASSTERM_ZDOTDIR = vim.env.ZDOTDIR or ""
        env.GLASSTERM_ZDOTDIR_SET = vim.env.ZDOTDIR and "1" or ""
        env.ZDOTDIR = M.ROOT .. "/shell/zsh"
    elseif kind == "bash" then
        local rc = M.ROOT .. "/shell/bash/glassterm.bash"
        argv = vim.list_extend({ argv[1], "--rcfile", rc }, vim.list_slice(argv, 2))
    elseif kind == "fish" then
        local script = M.ROOT .. "/shell/fish/glassterm.fish"
        vim.list_extend(argv, { "--init-command", "source " .. vim.fn.shellescape(script) })
    end
    return argv, env, kind
end

---Apply one TermRequest to its terminal.
---@param t table terminal (see term.lua)
---@param seq string|table TermRequest data (0.11: { sequence = ... })
---@return table|nil event the parsed event, when it was one of ours
function M.apply(t, seq)
    if type(seq) == "table" then
        seq = seq.sequence
    end
    local ev = osc.parse(seq)
    if not ev then
        return nil
    end
    t.integrated = true
    if ev.kind == "cwd" then
        t.cwd = ev.path
    elseif ev.kind == "command_start" then
        t.busy = true
        t.status = nil
        t.cmd_started = vim.uv.hrtime()
    elseif ev.kind == "command_end" then
        local started = t.cmd_started or t.rerun_sent
        ev.duration_ms = started and (vim.uv.hrtime() - started) / 1e6 or nil
        t.busy = false
        t.status = ev.status
        t.cmd_started = nil
    end
    return ev
end

return M
