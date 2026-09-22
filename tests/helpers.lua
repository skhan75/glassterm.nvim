-- Shared test helpers: a child Neovim with glassterm loaded plus polling.
local H = {}

-- A "shell" that prints one line and idles: stable across platforms.
H.FAKE_SHELL = { "/bin/sh", "-c", "printf 'glassterm test'; exec sleep 100000" }

---@return MiniTest.child
function H.new_child()
    local child = MiniTest.new_child_neovim()

    child.setup = function(opts)
        child.lua("require('glassterm').setup(...)", { opts or {} })
    end

    child.start_editor = function(lines, columns)
        child.restart({ "-u", "tests/minimal_init.lua" })
        child.o.lines, child.o.columns = lines or 40, columns or 120
        child.o.laststatus, child.o.cmdheight, child.o.showtabline = 3, 1, 0
        child.lua([[
            _G.floats = function()
                return vim.tbl_filter(function(w)
                    return vim.api.nvim_win_get_config(w).relative ~= ""
                end, vim.api.nvim_list_wins())
            end
            _G.gt = function() return require("glassterm") end
            _G.term = function(id) return require("glassterm.term").get(id or 1) end
            _G.notes = {}
            vim.notify = function(msg, level) table.insert(_G.notes, { msg = msg, level = level }) end
        ]])
    end

    return child
end

---Poll a Lua expression in the child until it is truthy.
---@param args table|nil values for `...` in `expr`
function H.wait(child, expr, timeout_ms, what, args)
    local deadline = vim.uv.now() + (timeout_ms or 3000)
    while vim.uv.now() < deadline do
        local v = child.lua_get(expr, args)
        -- nil comes back as vim.NIL, which is truthy: treat it as "not yet".
        if v and v ~= vim.NIL then
            return
        end
        vim.uv.sleep(20)
    end
    error(("timed out after %dms waiting for %s"):format(timeout_ms or 3000, what or expr), 2)
end

---A throwaway HOME for real shells. Defaults keep zsh non-interactive at
---startup on any machine: an empty .zshrc (Debian/Ubuntu zsh launches its
---new-user wizard without one) and skip_global_compinit (Ubuntu's global
---zshrc runs compinit, which stops at a prompt on insecure fpath dirs).
---@param files table<string, string[]>|nil extra files, relative to HOME
---@return string home realpath
function H.shell_home(files)
    local home = vim.fn.tempname()
    vim.fn.mkdir(home, "p")
    home = vim.uv.fs_realpath(home)
    local all = vim.tbl_extend("keep", files or {}, {
        [".zshrc"] = {},
        [".zshenv"] = { "skip_global_compinit=1" },
    })
    for name, lines in pairs(all) do
        vim.fn.mkdir(vim.fs.dirname(home .. "/" .. name), "p")
        vim.fn.writefile(lines, home .. "/" .. name)
    end
    return home
end

---Wait for terminal 1's first shell prompt; on timeout, fail with what the
---terminal is showing, so a hung startup explains itself in CI logs.
function H.wait_prompt(child, timeout_ms)
    local ok, err = pcall(
        H.wait,
        child,
        "term() and term().integrated and term().cwd ~= nil",
        timeout_ms or 8000
    )
    if not ok then
        local screen = child.lua_get([[
            (function()
                local t = require("glassterm.term").terms[1]
                if not t then return "(no terminal)" end
                local lines = vim.api.nvim_buf_get_lines(t.buf, 0, -1, false)
                return table.concat(vim.tbl_filter(function(l) return l ~= "" end, lines), "\n")
            end)()
        ]])
        error(("%s\n--- terminal showed ---\n%s"):format(err, screen), 2)
    end
end

function H.sleep(ms)
    vim.uv.sleep(ms)
end

return H
