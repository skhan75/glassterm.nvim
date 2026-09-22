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

function H.sleep(ms)
    vim.uv.sleep(ms)
end

return H
