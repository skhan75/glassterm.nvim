local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function ui()
    return require("glassterm.ui")
end

local HINTS = { "⌥t hide", "⌥z zoom" }

local function info(over)
    return vim.tbl_extend("force", {
        shell = "zsh",
        cwd = "~/workspace/nvim",
        terms = { 1 },
        current = 1,
        hints = HINTS,
        width = 103,
        border_hl = "GlasstermBorder",
    }, over or {})
end

local function width(chunks)
    local n = 0
    for _, c in ipairs(chunks) do
        n = n + vim.fn.strdisplaywidth(c[1])
    end
    return n
end

T["key_label()"] = MiniTest.new_set()

T["key_label()"]["uses macOS modifier symbols on a Mac"] = function()
    eq(ui().key_label("<M-t>", true), "⌥t")
    eq(ui().key_label("<A-z>", true), "⌥z")
    eq(ui().key_label("<C-\\>", true), "⌃\\")
end

T["key_label()"]["spells modifiers out elsewhere"] = function()
    eq(ui().key_label("<M-t>", false), "Alt-t")
    eq(ui().key_label("<C-\\>", false), "Ctrl-\\")
end

T["key_label()"]["leaves other mappings as written"] = function()
    eq(ui().key_label("<leader>tt", true), "<leader>tt")
end

T["pretty_path()"] = MiniTest.new_set()

T["pretty_path()"]["abbreviates the home directory"] = function()
    eq(ui().pretty_path("/Users/sami/workspace/nvim", "/Users/sami"), "~/workspace/nvim")
    eq(ui().pretty_path("/Users/sami", "/Users/sami"), "~")
end

T["pretty_path()"]["does not abbreviate a sibling that shares the prefix"] = function()
    eq(ui().pretty_path("/Users/samix/code", "/Users/sami"), "/Users/samix/code")
end

T["decorations()"] = MiniTest.new_set()

T["decorations()"]["top slot: name and folder on the border, hints bottom right"] = function()
    local d = ui().decorations("top", info())
    eq(d.title, { { " zsh ", "GlasstermTitle" }, { "~/workspace/nvim ", "GlasstermHint" } })
    eq(d.title_pos, "left")
    eq(d.footer, { { " ⌥t hide · ⌥z zoom ", "GlasstermHint" } })
    eq(d.footer_pos, "right")
    eq(d.winbar, nil)
end

T["decorations()"]["center slot centers the title"] = function()
    eq(ui().decorations("center", info()).title_pos, "center")
end

T["decorations()"]["a failed command adds an exit chip to the title"] = function()
    local d = ui().decorations("top", info({ status = 2 }))
    eq(d.title[3], { " exit 2 ", "GlasstermErrorChip" })
end

T["decorations()"]["a successful command adds no chip"] = function()
    eq(#ui().decorations("top", info({ status = 0 })).title, 2)
end

T["decorations()"]["several terminals show numbered tabs before the hints"] = function()
    local d = ui().decorations("top", info({ terms = { 1, 2, 3 }, current = 2 }))
    eq(d.footer, {
        { " 1 ", "GlasstermTab" },
        { " 2 ", "GlasstermTabActive" },
        { " 3 ", "GlasstermTab" },
        { " ⌥t hide · ⌥z zoom ", "GlasstermHint" },
    })
end

T["decorations()"]["no hints and one terminal means no footer"] = function()
    eq(ui().decorations("top", info({ hints = {} })).footer, nil)
end

T["decorations()"]["without a known folder the title is just the shell"] = function()
    eq(ui().decorations("top", info({ cwd = false })).title, { { " zsh ", "GlasstermTitle" } })
end

T["decorations()"]["bottom slot packs everything into one full-width edge"] = function()
    local d = ui().decorations("bottom", info({ width = 60, border_hl = "GlasstermAccent" }))
    eq(d.title, nil)
    eq(d.footer_pos, "left")
    eq(d.footer[1], { " zsh ", "GlasstermTitle" })
    eq(d.footer[3], { string.rep("─", 60 - 5 - 17 - 19), "GlasstermAccent" })
    eq(d.footer[4], { " ⌥t hide · ⌥z zoom ", "GlasstermHint" })
    eq(width(d.footer), 60)
end

T["decorations()"]["winbar slot builds a statusline-style string"] = function()
    local d = ui().decorations("winbar", info({ status = 1, cwd = "/tmp/100%" }))
    eq(d.title, nil)
    eq(d.footer, nil)
    eq(
        d.winbar,
        "%#GlasstermTitle# zsh %#GlasstermHint#/tmp/100%% %#GlasstermErrorChip# exit 1 %*"
            .. "%=%#GlasstermHint# ⌥t hide · ⌥z zoom %*"
    )
end

T["decorations()"]["drops hints, then the folder, when the window is narrow"] = function()
    local d = ui().decorations("bottom", info({ width = 30 }))
    -- " zsh " (5) + "~/workspace/nvim " (17) fits in 30 only without hints
    eq(d.footer[1], { " zsh ", "GlasstermTitle" })
    eq(d.footer[2], { "~/workspace/nvim ", "GlasstermHint" })
    eq(width(d.footer), 30)

    local tiny = ui().decorations("bottom", info({ width = 12 }))
    eq(tiny.footer[1], { " zsh ", "GlasstermTitle" })
    eq(width(tiny.footer), 12)
end

T["decorations()"]["keeps a top-slot title within the window width"] = function()
    local d = ui().decorations("top", info({ width = 14 }))
    eq(d.title, { { " zsh ", "GlasstermTitle" } })
    eq(d.footer, nil)
end

return T
