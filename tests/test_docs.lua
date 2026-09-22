local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child = H.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.start_editor()
        end,
        post_once = child.stop,
    },
})

-- Build tags from a copy so the repo never gets a generated doc/tags file.
T["help tags build without errors and the main topics resolve"] = function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir .. "/doc", "p")
    vim.fn.writefile(vim.fn.readfile("doc/glassterm.txt"), dir .. "/doc/glassterm.txt")
    child.lua("vim.opt.runtimepath:prepend(...)", { dir })
    local ok, err = pcall(child.cmd, "helptags " .. dir .. "/doc")
    eq({ ok, ok and "" or tostring(err) }, { true, "" })

    for _, topic in ipairs({
        "glassterm",
        "glassterm-config",
        "glassterm-styles",
        ":Glassterm",
        "glassterm.toggle()",
        "glassterm-integration",
        "glassterm-highlights",
    }) do
        local found = pcall(child.cmd, "help " .. topic)
        eq({ topic, found }, { topic, true })
        child.cmd("helpclose")
    end
end

return T
