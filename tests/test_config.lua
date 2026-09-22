local T = MiniTest.new_set()
local eq, expect = MiniTest.expect.equality, MiniTest.expect

local function fresh()
    package.loaded["glassterm.config"] = nil
    return require("glassterm.config")
end

T["setup()"] = MiniTest.new_set()

T["setup()"]["deep-merges style overrides without dropping sibling fields"] = function()
    local opts = fresh().setup({ styles = { glass = { width = 0.5 } } })
    eq(opts.styles.glass.width, 0.5)
    eq(opts.styles.glass.height, 0.80)
    eq(opts.styles.capsule.width, 76)
end

T["setup()"]["accepts false as shorthand for disabling prewarm"] = function()
    local opts = fresh().setup({ prewarm = false })
    eq(opts.prewarm.enabled, false)
    eq(type(opts.prewarm.delay_ms), "number")
end

T["setup()"]["accepts false as shorthand for disabling integration"] = function()
    local opts = fresh().setup({ integration = false })
    eq(opts.integration.enabled, false)
    eq(opts.integration.notify_on_failure, true)
end

T["setup()"]["lets a key be disabled with false"] = function()
    local opts = fresh().setup({ keys = { zoom = false } })
    eq(opts.keys.zoom, false)
    eq(opts.keys.toggle, "<M-t>")
end

T["setup()"]["rejects an unknown style and lists the valid ones"] = function()
    expect.error(function()
        fresh().setup({ style = "bubble" })
    end, "style.*glass.*drop.*drawer.*capsule")
end

T["setup()"]["rejects a key that is not a string or false"] = function()
    expect.error(function()
        fresh().setup({ keys = { toggle = 42 } })
    end, "keys.toggle")
end

T["setup()"]["rejects a non-positive size"] = function()
    expect.error(function()
        fresh().setup({ styles = { glass = { width = 0 } } })
    end, "styles.glass.width")
end

T["setup()"]["allows the capsule at the very top with row 0"] = function()
    local opts = fresh().setup({ styles = { capsule = { row = 0 } } })
    eq(opts.styles.capsule.row, 0)
end

T["setup()"]["rejects a drawer side other than left or right"] = function()
    expect.error(function()
        fresh().setup({ styles = { drawer = { side = "top" } } })
    end, "styles.drawer.side")
end

T["setup()"]["accepts the shell as an argv list"] = function()
    local opts = fresh().setup({ shell = { "/bin/zsh", "-l" } })
    eq(opts.shell, { "/bin/zsh", "-l" })
end

T["setup()"]["does not leak one call's options into the next"] = function()
    local config = fresh()
    config.setup({ styles = { glass = { width = 0.5 } } })
    local opts = config.setup({})
    eq(opts.styles.glass.width, 0.86)
end

return T
