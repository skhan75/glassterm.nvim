-- Terminal pool: hidden terminal buffers and their shell processes.
-- Knows nothing about windows; window.lua decides what is shown.

local config = require("glassterm.config")
local integration = require("glassterm.integration")

local M = {}

-- A shell that exits sooner than this after starting is treated as a crash
-- and is not pre-started again (avoids a respawn loop on a broken shell).
M.MIN_UPTIME_MS = 1000

---@type table<integer, table>
M.terms = {}
M.last = 1

local listeners = { spawn = {}, exit = {} }

---@param event "spawn"|"exit"
function M.on(event, fn)
    table.insert(listeners[event], fn)
end

local function emit(event, ...)
    for _, fn in ipairs(listeners[event]) do
        fn(...)
    end
end

local function alive(t)
    return t ~= nil
        and vim.api.nvim_buf_is_valid(t.buf)
        and t.job ~= nil
        and vim.fn.jobwait({ t.job }, 0)[1] == -1
end

---@return table|nil terminal with a live shell
function M.get(id)
    local t = M.terms[id]
    if alive(t) then
        return t
    end
end

---@return integer[] ids of live terminals, ascending
function M.ids()
    local ids = {}
    for id, t in pairs(M.terms) do
        if alive(t) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids
end

local function exited(t, code)
    if M.terms[t.id] ~= t then
        return
    end
    M.terms[t.id] = nil
    emit("exit", t, code, (vim.uv.hrtime() - t.started) / 1e6)
end

---Start a shell in a hidden terminal buffer.
---@return table|nil terminal
function M.spawn(id)
    local opts = config.options
    local argv, env, kind = integration.command(opts.shell, id, opts.integration.enabled)
    local buf = vim.api.nvim_create_buf(false, true)
    local t = {
        id = id,
        buf = buf,
        kind = kind,
        name = vim.fs.basename(argv[1] or "shell"),
        started = vim.uv.hrtime(),
        mode = "t",
    }

    -- TermOpen handlers often run :startinsert, which would flip whatever window
    -- is current into insert mode. It fires later, when the float first shows.
    local ei = vim.o.eventignore
    vim.o.eventignore = ei == "" and "TermOpen" or ei .. ",TermOpen"
    local ok, job = pcall(vim.api.nvim_buf_call, buf, function()
        return vim.fn.jobstart(argv, {
            term = true,
            env = env,
            on_exit = function(_, code)
                vim.schedule(function()
                    exited(t, code)
                end)
            end,
        })
    end)
    vim.o.eventignore = ei

    if not ok or type(job) ~= "number" or job <= 0 then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        vim.notify(
            ("glassterm: could not start %s%s"):format(argv[1], ok and "" or (": " .. tostring(job))),
            vim.log.levels.ERROR
        )
        return nil
    end

    t.job = job
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].buflisted = false
    vim.b[buf].glassterm = id
    pcall(vim.api.nvim_buf_set_name, buf, ("glassterm://%d"):format(id))
    vim.bo[buf].filetype = "glassterm"
    M.terms[id] = t
    emit("spawn", t)
    return t
end

---@return table|nil
function M.ensure(id)
    return M.get(id) or M.spawn(id)
end

return M
