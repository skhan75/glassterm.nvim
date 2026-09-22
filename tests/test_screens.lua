-- Reference screenshots of every shape. A reference is written on the first
-- run and must be reviewed by eye; later runs fail on any visual change.
local H = dofile("tests/helpers.lua")
local expect = MiniTest.expect

local child = H.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.start_editor(24, 80)
            child.api.nvim_buf_set_lines(0, 0, -1, false, {
                "local function greet(name)",
                "    return 'hello ' .. name",
                "end",
                "",
                "print(greet('glassterm'))",
            })
        end,
        post_once = child.stop,
    },
})

-- Prints a folder report, a finished command with exit 2, then idles.
local SIGNALS = {
    "/bin/sh",
    "-c",
    [[printf 'glassterm test\033]7;file://h/tmp/project\007\033]133;C\007\033]133;D;2\007'; exec sleep 100000]],
}

local function open(opts, toggle_arg)
    -- Function keys: modifier labels differ by OS (⌥t on macOS, Alt-t elsewhere).
    local base =
        { shell = H.FAKE_SHELL, prewarm = false, keys = { toggle = "<F7>", zoom = "<F8>" } }
    child.setup(vim.tbl_deep_extend("force", base, opts or {}))
    child.lua("require('glassterm').toggle(...)", { toggle_arg })
    H.wait(
        child,
        "vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find('glassterm test') ~= nil",
        2000,
        "shell output"
    )
end

T["glass"] = function()
    open()
    expect.reference_screenshot(child.get_screenshot())
end

T["drop"] = function()
    open({ style = "drop" })
    expect.reference_screenshot(child.get_screenshot())
end

T["drawer"] = function()
    open({ style = "drawer" })
    expect.reference_screenshot(child.get_screenshot())
end

T["capsule"] = function()
    open({ style = "capsule", styles = { capsule = { width = 50, height = 8 } } })
    expect.reference_screenshot(child.get_screenshot())
end

T["zoom"] = function()
    open()
    child.lua("require('glassterm').zoom()")
    expect.reference_screenshot(child.get_screenshot())
end

T["folder and failed command"] = function()
    open({ shell = SIGNALS })
    H.wait(child, "require('glassterm.term').get(1).status == 2", 2000, "exit status")
    expect.reference_screenshot(child.get_screenshot())
end

T["numbered tabs"] = function()
    open()
    child.lua("require('glassterm').toggle(2)")
    H.wait(
        child,
        "vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find('glassterm test') ~= nil",
        2000
    )
    expect.reference_screenshot(child.get_screenshot())
end

return T
