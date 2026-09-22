local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

-- Required lazily: a module error at file load hangs the headless runner.
local styles = setmetatable({}, {
    __index = function(_, k)
        return require("glassterm.styles")[k]
    end,
})
local defaults = require("glassterm.config").defaults.styles

local ROUNDED = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
local E = { top = 0, width = 120, height = 38 }

local function box(l)
    return { l.row, l.col, l.width, l.height }
end

-- The outer box (content + border) must stay inside the editor area.
local function fits(l, e)
    local b = l.border
    local outer_w = l.width + (b[8] ~= "" and 1 or 0) + (b[4] ~= "" and 1 or 0)
    local outer_h = l.height + (b[2] ~= "" and 1 or 0) + (b[6] ~= "" and 1 or 0)
    return l.row >= e.top
        and l.col >= 0
        and l.row + outer_h <= e.top + e.height
        and l.col + outer_w <= e.width
end

T["glass"] = MiniTest.new_set()

T["glass"]["centers an 86% x 80% pane, border included"] = function()
    local l = styles.layout("glass", defaults.glass, E)
    -- content 103x30, outer 105x32: col (120-105)/2 = 7, row (38-32)/2 = 3
    eq(box(l), { 3, 7, 103, 30 })
    eq(l.border, ROUNDED)
    eq(l.slot, "top")
    eq(l.border_hl, "GlasstermBorder")
end

T["glass"]["clamps a full-size request so the border stays on screen"] = function()
    local l = styles.layout("glass", { width = 1, height = 1 }, E)
    eq(box(l), { 0, 0, 118, 36 })
end

T["glass"]["treats sizes above 1 as cells"] = function()
    local l = styles.layout("glass", { width = 100, height = 20 }, E)
    eq({ l.width, l.height }, { 100, 20 })
end

T["glass"]["starts below a tabline"] = function()
    local l = styles.layout("glass", defaults.glass, { top = 1, width = 120, height = 37 })
    -- content 103x29, outer 105x31: row 1 + floor((37-31)/2) = 4
    eq(box(l), { 4, 7, 103, 29 })
end

T["drop"] = MiniTest.new_set()

T["drop"]["spans the full width from the top with only a bottom edge"] = function()
    local l = styles.layout("drop", defaults.drop, E)
    eq(box(l), { 0, 0, 120, 15 }) -- floor(38 * 0.42) = 15
    eq(l.border, { "", "", "", "", "", "─", "", "" })
    eq(l.slot, "bottom")
    eq(l.border_hl, "GlasstermAccent")
end

T["drawer"] = MiniTest.new_set()

T["drawer"]["sits on the right with only a left edge"] = function()
    local l = styles.layout("drawer", defaults.drawer, E)
    -- content 52 wide + 1 edge = 53: col 120 - 53 = 67
    eq(box(l), { 0, 67, 52, 38 })
    eq(l.border, { "", "", "", "", "", "", "", "│" })
    eq(l.slot, "winbar")
end

T["drawer"]["mirrors to the left with only a right edge"] = function()
    local l = styles.layout("drawer", { width = 0.44, side = "left" }, E)
    eq(box(l), { 0, 0, 52, 38 })
    eq(l.border, { "", "", "", "│", "", "", "", "" })
end

T["capsule"] = MiniTest.new_set()

T["capsule"]["floats a fixed-size box in the upper middle"] = function()
    local l = styles.layout("capsule", defaults.capsule, E)
    -- outer 78x14: col (120-78)/2 = 21, row floor(38 * 0.26) = 9
    eq(box(l), { 9, 21, 76, 12 })
    eq(l.border, ROUNDED)
    eq(l.slot, "center")
    eq(l.border_hl, "GlasstermAccent")
end

T["capsule"]["shrinks and moves up to fit a tiny editor"] = function()
    local e = { top = 0, width = 40, height = 12 }
    local l = styles.layout("capsule", defaults.capsule, e)
    eq(box(l), { 0, 0, 38, 10 })
end

T["zoom"] = MiniTest.new_set()

T["zoom"]["fills the editor with a rounded border whatever the style"] = function()
    for _, name in ipairs({ "glass", "drop", "drawer", "capsule" }) do
        local l = styles.layout(name, defaults[name], E, { zoom = true })
        eq(box(l), { 0, 0, 118, 36 })
        eq(l.border, ROUNDED)
        eq(l.slot, "top")
    end
end

T["every style fits tiny and huge editors"] = function()
    for _, e in ipairs({
        { top = 0, width = 40, height = 12 },
        { top = 0, width = 300, height = 90 },
        { top = 1, width = 20, height = 5 },
    }) do
        for _, name in ipairs(require("glassterm.config").STYLES) do
            local l = styles.layout(name, defaults[name], e)
            eq({ name, e.width, fits(l, e) }, { name, e.width, true })
            eq(l.width >= 1 and l.height >= 1, true)
        end
    end
end

T["editor()"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            _G.child = MiniTest.new_child_neovim()
            child.start({ "-u", "tests/minimal_init.lua" })
            child.o.lines, child.o.columns = 40, 120
        end,
        post_case = function()
            child.stop()
        end,
    },
})

T["editor()"]["leaves room for a global statusline and the command line"] = function()
    child.o.laststatus, child.o.cmdheight, child.o.showtabline = 3, 1, 0
    eq(child.lua_get("require('glassterm.styles').editor()"), { top = 0, width = 120, height = 38 })
end

T["editor()"]["starts below a visible tabline"] = function()
    child.o.laststatus, child.o.cmdheight, child.o.showtabline = 3, 1, 2
    eq(child.lua_get("require('glassterm.styles').editor()"), { top = 1, width = 120, height = 37 })
end

T["editor()"]["uses the statusline row when there is no statusline"] = function()
    child.o.laststatus, child.o.cmdheight, child.o.showtabline = 0, 1, 0
    eq(child.lua_get("require('glassterm.styles').editor()"), { top = 0, width = 120, height = 39 })
end

return T
