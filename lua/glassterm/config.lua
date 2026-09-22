-- Options: defaults, shorthand normalization and validation.

local M = {}

M.STYLES = { "glass", "drop", "drawer", "capsule" }

M.defaults = {
    style = "glass",
    -- nil uses 'shell'. A string is split on whitespace; a list is used as argv.
    shell = nil,
    prewarm = { enabled = true, delay_ms = 1000 },
    hide_on_leave = true,
    close_on_exit = true,
    integration = { enabled = true, notify_on_failure = true },
    ui = { hints = true },
    keys = {
        toggle = "<M-t>",
        zoom = "<M-z>",
        send = false,
        rerun = false,
    },
    -- Sizes: <= 1 is a fraction of the editor, > 1 is a count of cells.
    styles = {
        glass = { width = 0.86, height = 0.80 },
        drop = { height = 0.42 },
        drawer = { width = 0.44, side = "right" },
        capsule = { width = 76, height = 12, row = 0.26 },
    },
}

M.options = vim.deepcopy(M.defaults)

-- vim.validate(name, value, fn, optional, expected): `expected` names what a
-- bad value should have been, so errors read "expected one of glass, ...".
local function check(name, value, fn, expected)
    vim.validate(name, value, fn, false, expected)
end

local function one_of(name, value, list)
    check(name, value, function(v)
        return vim.tbl_contains(list, v)
    end, "one of " .. table.concat(list, ", "))
end

-- `false` for a feature table means "off, everything else default".
local function normalize(opts, name)
    if opts[name] == false then
        opts[name] = { enabled = false }
    elseif opts[name] == true then
        opts[name] = { enabled = true }
    end
end

local function validate(o)
    one_of("style", o.style, M.STYLES)
    vim.validate("shell", o.shell, { "string", "table" }, true)
    vim.validate("prewarm.enabled", o.prewarm.enabled, "boolean")
    vim.validate("prewarm.delay_ms", o.prewarm.delay_ms, "number")
    vim.validate("hide_on_leave", o.hide_on_leave, "boolean")
    vim.validate("close_on_exit", o.close_on_exit, "boolean")
    vim.validate("integration.enabled", o.integration.enabled, "boolean")
    vim.validate("integration.notify_on_failure", o.integration.notify_on_failure, "boolean")
    vim.validate("ui.hints", o.ui.hints, "boolean")
    for name, lhs in pairs(o.keys) do
        check("keys." .. name, lhs, function(v)
            return v == false or type(v) == "string"
        end, "a key string or false")
    end
    for style, s in pairs(o.styles) do
        one_of("styles." .. style, style, M.STYLES)
        for _, field in ipairs({ "width", "height" }) do
            if s[field] ~= nil then
                check(("styles.%s.%s"):format(style, field), s[field], function(v)
                    return type(v) == "number" and v > 0
                end, "a positive number")
            end
        end
        if s.row ~= nil then
            check(("styles.%s.row"):format(style), s.row, function(v)
                return type(v) == "number" and v >= 0
            end, "a number >= 0")
        end
    end
    one_of("styles.drawer.side", o.styles.drawer.side, { "left", "right" })
end

---@param opts table|nil
---@return table
function M.setup(opts)
    opts = vim.deepcopy(opts or {})
    normalize(opts, "prewarm")
    normalize(opts, "integration")
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
    -- An argv list replaces the default outright; deep-extend would merge by index.
    if type(opts.shell) == "table" then
        merged.shell = opts.shell
    end
    local ok, err = pcall(validate, merged)
    if not ok then
        -- Drop the "config.lua:NN:" prefix: the option name is what users need.
        error("glassterm: " .. tostring(err):gsub("^[^:]*:%d+: ", ""), 0)
    end
    M.options = merged
    return merged
end

return M
