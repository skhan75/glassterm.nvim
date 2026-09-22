local H = dofile("tests/helpers.lua")
local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local child = H.new_child()

T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.start_editor()
        end,
        post_once = child.stop,
    },
})

local function setup(extra)
    child.setup(
        vim.tbl_deep_extend("force", { shell = H.FAKE_SHELL, prewarm = false }, extra or {})
    )
end

local function float_count()
    return child.lua_get("#floats()")
end

T["toggle"] = MiniTest.new_set()

T["toggle"]["opens the terminal in a focused float and hides it again"] = function()
    setup()
    child.lua("gt().toggle()")
    eq(float_count(), 1)
    eq(child.lua_get("vim.api.nvim_get_current_win() == floats()[1]"), true)
    eq(child.lua_get("vim.bo.buftype"), "terminal")

    child.lua("gt().toggle()")
    eq(float_count(), 0)
end

T["toggle"]["reuses the same buffer and shell every time"] = function()
    setup()
    child.lua("gt().toggle()")
    local first = child.lua_get("{ buf = term().buf, job = term().job }")
    child.lua("gt().toggle(); gt().toggle()")
    eq(child.lua_get("{ buf = term().buf, job = term().job }"), first)
    -- still running: jobwait with a zero timeout reports -1 for live jobs
    eq(child.lua_get("vim.fn.jobwait({ term().job }, 0)[1]"), -1)
end

T["toggle"]["focuses an open float instead of hiding it when focus is elsewhere"] = function()
    setup({ hide_on_leave = false })
    child.lua("gt().toggle()")
    child.lua("vim.cmd.wincmd('p')")
    eq(child.lua_get("vim.api.nvim_get_current_win() == floats()[1]"), false)

    child.lua("gt().toggle()")
    eq(float_count(), 1)
    eq(child.lua_get("vim.api.nvim_get_current_win() == floats()[1]"), true)
end

T["toggle"]["returns focus to the window it came from"] = function()
    setup()
    local editor = child.api.nvim_get_current_win()
    child.lua("gt().toggle(); gt().toggle()")
    eq(child.api.nvim_get_current_win(), editor)
end

T["prewarm"] = MiniTest.new_set()

T["prewarm"]["starts the shell hidden without leaving normal mode"] = function()
    -- A common user autocommand that would otherwise flip the editor into insert mode.
    child.cmd("autocmd TermOpen * startinsert")
    setup()
    child.lua("gt().prewarm()")
    H.sleep(100)
    eq(child.lua_get("term() ~= nil"), true)
    eq(float_count(), 0)
    eq(child.api.nvim_get_mode().mode, "n")
end

T["prewarm"]["runs the user's TermOpen autocommands when first shown"] = function()
    child.cmd("autocmd TermOpen * let w:opened_by_termopen = 1")
    setup()
    child.lua("gt().prewarm()")
    child.lua("gt().toggle()")
    eq(child.lua_get("vim.w.opened_by_termopen"), 1)
end

T["prewarm"]["is skipped when no UI is attached"] = function()
    setup({ prewarm = { enabled = true, delay_ms = 10 } })
    H.sleep(150)
    eq(child.lua_get("term() == nil"), true)
end

T["toggle"]["opens in the current tab when the float is open in another"] = function()
    setup({ hide_on_leave = false })
    child.lua("gt().toggle()")
    child.cmd("wincmd p | tabnew")
    local tab = child.api.nvim_get_current_tabpage()
    child.lua("gt().toggle()")
    eq(child.api.nvim_get_current_tabpage(), tab)
    eq(child.lua_get("vim.api.nvim_win_get_tabpage(require('glassterm.window').win)"), tab)
    eq(child.lua_get("vim.bo.buftype"), "terminal")
end

T["hide on leave"] = MiniTest.new_set()

T["hide on leave"]["hides the float when focus moves to an editor window"] = function()
    setup()
    child.lua("gt().toggle()")
    child.lua("vim.cmd.wincmd('p')")
    H.wait(child, "#floats() == 0", 1000, "float to hide")
    eq(child.lua_get("term() ~= nil"), true)
end

T["hide on leave"]["ignores focus moving to another float"] = function()
    setup()
    child.lua("gt().toggle()")
    child.lua([[
        local b = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_open_win(b, true, { relative = "editor", row = 1, col = 1, width = 10, height = 2 })
    ]])
    H.sleep(50)
    eq(float_count(), 2)
end

T["numbered terminals"] = MiniTest.new_set()

T["numbered terminals"]["opens terminal n and lists live ids"] = function()
    setup()
    child.lua("gt().toggle(2)")
    eq(child.lua_get("vim.b.glassterm"), 2)
    eq(child.lua_get("require('glassterm.term').ids()"), { 2 })
end

T["numbered terminals"]["swaps the buffer inside the open float"] = function()
    setup()
    child.lua("gt().toggle(1)")
    local win = child.lua_get("floats()[1]")
    child.lua("gt().toggle(2)")
    eq(child.lua_get("floats()[1]"), win)
    eq(child.lua_get("vim.b.glassterm"), 2)
    eq(child.lua_get("require('glassterm.term').ids()"), { 1, 2 })
end

T["numbered terminals"]["switching from outside the float keeps each terminal's mode"] = function()
    setup({ hide_on_leave = false })
    child.lua("gt().toggle(1)")
    eq(child.api.nvim_get_mode().mode, "t")
    -- Leave terminal 1 while still typing in it, then go to insert mode in code.
    child.lua("vim.api.nvim_set_current_win(require('glassterm.window').prev)")
    child.type_keys("i")
    eq(child.api.nvim_get_mode().mode, "i")
    child.lua("gt().toggle(2)")
    child.lua("gt().toggle(1)")
    eq(child.lua_get("vim.b.glassterm"), 1)
    eq(child.api.nvim_get_mode().mode, "t")
end

T["numbered terminals"]["uses a count typed before the toggle key"] = function()
    setup()
    child.type_keys("3", "<M-t>")
    eq(child.lua_get("vim.b.glassterm"), 3)
end

T["exit"] = MiniTest.new_set()

T["exit"]["closes the float and forgets the terminal"] = function()
    setup({ shell = { "/bin/sh" } })
    child.lua("require('glassterm.term').MIN_UPTIME_MS = 0")
    child.lua("gt().toggle()")
    child.lua("vim.fn.chansend(term().job, 'exit\\r')")
    H.wait(child, "#floats() == 0 and term() == nil", 3000, "shell exit to close the float")
end

T["exit"]["pre-starts a replacement for terminal 1 when prewarm is on"] = function()
    setup({ shell = { "/bin/sh" }, prewarm = { enabled = true, delay_ms = 100000 } })
    child.lua("require('glassterm.term').MIN_UPTIME_MS = 0")
    child.lua("gt().toggle()")
    local job = child.lua_get("term().job")
    child.lua("vim.fn.chansend(term().job, 'exit\\r')")
    H.wait(child, "term() ~= nil and term().job ~= " .. job, 3000, "replacement shell")
    eq(float_count(), 0)
end

T["exit"]["does not respawn a shell that dies straight away"] = function()
    setup({ shell = { "/bin/sh", "-c", "exit 3" }, prewarm = { enabled = true, delay_ms = 100000 } })
    child.lua("gt().prewarm()")
    H.wait(child, "#_G.notes > 0", 3000, "crash notification")
    H.sleep(300)
    eq(child.lua_get("term() == nil"), true)
    eq(child.lua_get("_G.notes[1].msg:match('exited with code 3') ~= nil"), true)
end

T["mode memory"] = MiniTest.new_set()

T["mode memory"]["reopens ready to type when left in terminal mode"] = function()
    setup()
    child.type_keys("<M-t>")
    eq(child.api.nvim_get_mode().mode, "t")
    child.type_keys("<M-t>", "<M-t>")
    eq(child.api.nvim_get_mode().mode, "t")
end

T["mode memory"]["restores the scroll position when left in normal mode"] = function()
    setup()
    child.lua("gt().toggle()")
    child.type_keys([[<C-\><C-n>]], "gg")
    eq(child.api.nvim_get_mode().mode, "nt")
    child.lua("gt().toggle(); gt().toggle()")
    eq(child.api.nvim_get_mode().mode, "nt")
    eq(child.lua_get("vim.api.nvim_win_get_cursor(0)[1]"), 1)
end

T["geometry"] = MiniTest.new_set()

local function float_box()
    return child.lua_get([[
        (function()
            local c = vim.api.nvim_win_get_config(floats()[1])
            return { c.row, c.col, c.width, c.height }
        end)()
    ]])
end

T["geometry"]["opens with the configured style"] = function()
    setup()
    child.lua("gt().toggle()")
    eq(float_box(), { 3, 7, 103, 30 })
end

T["geometry"]["reshapes when the editor is resized"] = function()
    setup()
    child.lua("gt().toggle()")
    child.o.columns = 100
    H.wait(child, "vim.api.nvim_win_get_config(floats()[1]).width == 86", 1000, "resize")
end

T["geometry"]["zoom fills the editor and toggles back"] = function()
    setup()
    child.lua("gt().toggle(); gt().zoom()")
    eq(float_box(), { 0, 0, 118, 36 })
    child.lua("gt().zoom()")
    eq(float_box(), { 3, 7, 103, 30 })
end

T["geometry"]["zoom resets when the float hides"] = function()
    setup()
    child.lua("gt().toggle(); gt().zoom(); gt().toggle(); gt().toggle()")
    eq(float_box(), { 3, 7, 103, 30 })
end

T["geometry"]["set_style reshapes an open float in place"] = function()
    setup()
    child.lua("gt().toggle()")
    local win = child.lua_get("floats()[1]")
    child.lua("gt().set_style('drawer')")
    eq(child.lua_get("floats()[1]"), win)
    eq(float_box(), { 0, 67, 52, 38 })
end

T["geometry"]["a style passed to toggle lasts for that open only"] = function()
    setup()
    child.lua("gt().toggle({ style = 'capsule' })")
    eq(float_box(), { 9, 21, 76, 12 })
    child.lua("gt().toggle(); gt().toggle()")
    eq(float_box(), { 3, 7, 103, 30 })
end

T["safety"] = MiniTest.new_set()

T["safety"]["a file opened from inside the float lands in the previous window"] = function()
    setup()
    local editor = child.api.nvim_get_current_win()
    child.lua("gt().toggle()")
    child.cmd("edit tests/helpers.lua")
    H.wait(child, "#floats() == 0", 1000, "float to hand the file over")
    eq(child.api.nvim_get_current_win(), editor)
    eq(child.lua_get("vim.fn.expand('%:t')"), "helpers.lua")
    eq(child.lua_get("term() ~= nil"), true)
end

T["safety"]["quitting Neovim does not stop on the hidden shell"] = function()
    setup()
    child.lua("gt().prewarm()")
    H.sleep(100)
    child.lua_notify("vim.cmd('qa')")
    local deadline = vim.uv.now() + 3000
    while child.is_running() and vim.uv.now() < deadline do
        local ok = pcall(child.lua_get, "1")
        if not ok then
            break
        end
        vim.uv.sleep(20)
    end
    eq(pcall(child.lua_get, "1"), false)
end

T["keys"] = MiniTest.new_set()

T["keys"]["toggle works from normal, insert and terminal mode"] = function()
    setup()
    child.type_keys("<M-t>")
    eq(float_count(), 1)
    child.type_keys("<M-t>")
    eq(float_count(), 0)
    child.type_keys("i", "<M-t>")
    eq(float_count(), 1)
end

T["keys"]["a key set to false is not mapped"] = function()
    setup({ keys = { toggle = false } })
    eq(child.lua_get("vim.fn.maparg('<M-t>', 'n')"), "")
end

T["keys"]["zoom is mapped only inside glassterm terminals"] = function()
    setup()
    eq(child.lua_get("vim.fn.maparg('<M-z>', 'n')"), "")
    child.lua("gt().toggle()")
    eq(child.lua_get("vim.fn.maparg('<M-z>', 't', false, true).buffer"), 1)
    child.type_keys("<M-z>")
    eq(float_box(), { 0, 0, 118, 36 })
end

return T
