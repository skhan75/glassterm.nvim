local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child = H.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.start_editor()
            child.cmd("runtime plugin/glassterm.lua")
        end,
        post_once = child.stop,
    },
})

local function setup(extra)
    child.setup(
        vim.tbl_deep_extend("force", { shell = H.FAKE_SHELL, prewarm = false }, extra or {})
    )
end

T[":Glassterm"] = MiniTest.new_set()

T[":Glassterm"]["with no arguments toggles the terminal"] = function()
    setup()
    child.cmd("Glassterm")
    eq(child.lua_get("#floats()"), 1)
    child.cmd("Glassterm toggle")
    eq(child.lua_get("#floats()"), 0)
end

T[":Glassterm"]["toggle n opens that terminal"] = function()
    setup()
    child.cmd("Glassterm toggle 2")
    eq(child.lua_get("vim.b.glassterm"), 2)
end

T[":Glassterm"]["style switches the style"] = function()
    setup()
    child.cmd("Glassterm style drawer")
    eq(child.lua_get("require('glassterm.config').options.style"), "drawer")
end

T[":Glassterm"]["reports a bad style instead of throwing"] = function()
    setup()
    child.cmd("Glassterm style bubble")
    eq(child.lua_get("_G.notes[1].msg:match('unknown style') ~= nil"), true)
    eq(child.lua_get("_G.notes[1].level"), vim.log.levels.ERROR)
end

T[":Glassterm"]["reports an unknown subcommand"] = function()
    setup()
    child.cmd("Glassterm frobnicate")
    eq(child.lua_get("_G.notes[1].msg:match('frobnicate') ~= nil"), true)
end

T[":Glassterm"]["send runs its arguments in the shell"] = function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    setup({ shell = { "/bin/sh" } })
    child.cmd("Glassterm send echo hi > " .. dir .. "/out")
    H.wait(child, "vim.fn.filereadable(...) == 1", 3000, "command output", { dir .. "/out" })
    vim.uv.sleep(50)
    eq(vim.fn.readfile(dir .. "/out"), { "hi" })
end

T[":Glassterm"]["send with a range runs those buffer lines"] = function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    setup({ shell = { "/bin/sh" } })
    child.api.nvim_buf_set_lines(0, 0, -1, false, {
        "echo a >> " .. dir .. "/f",
        "echo b >> " .. dir .. "/f",
        "echo not-sent >> " .. dir .. "/f",
    })
    child.cmd("1,2Glassterm send")
    H.wait(
        child,
        "vim.fn.filereadable(...) == 1 and #vim.fn.readfile(...) >= 2",
        3000,
        "two lines",
        {
            dir .. "/f",
        }
    )
    vim.uv.sleep(100)
    eq(vim.fn.readfile(dir .. "/f"), { "a", "b" })
end

T["completion"] = MiniTest.new_set()

T["completion"]["offers the subcommands"] = function()
    eq(
        child.lua_get("vim.fn.getcompletion('Glassterm ', 'cmdline')"),
        { "close", "open", "rerun", "send", "style", "toggle", "zoom" }
    )
end

T["completion"]["offers style names after style"] = function()
    eq(child.lua_get("vim.fn.getcompletion('Glassterm style d', 'cmdline')"), { "drop", "drawer" })
end

T["checkhealth"] = MiniTest.new_set()

local function health()
    child.cmd("checkhealth glassterm")
    return table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

T["checkhealth"]["warns when setup() was never called"] = function()
    eq(health():match("WARNING setup%(%) has not been called") ~= nil, true)
end

T["checkhealth"]["reports shell integration as available for zsh"] = function()
    setup({ shell = { "zsh" } })
    eq(health():match("OK zsh: shell integration available") ~= nil, true)
end

T["checkhealth"]["warns that other shells get no integration"] = function()
    setup({ shell = { "/bin/sh" } })
    eq(health():match("WARNING /bin/sh: no shell integration") ~= nil, true)
end

T["checkhealth"]["confirms a live terminal is sending signals"] = function()
    if vim.fn.executable("zsh") == 0 then
        MiniTest.skip("zsh is not installed")
    end
    local home = vim.fn.tempname()
    vim.fn.mkdir(home, "p")
    vim.fn.writefile({}, home .. "/.zshrc")
    child.lua("vim.env.HOME = ...; vim.env.ZDOTDIR = nil", { home })
    setup({ shell = { "zsh" } })
    child.lua("require('glassterm').prewarm()")
    H.wait(child, "term() and term().integrated", 8000, "first prompt")
    eq(health():match("OK terminal 1: shell integration active") ~= nil, true)
end

return T
