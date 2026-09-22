-- Titles, footers and winbars: pure functions from terminal state to
-- highlighted text, so every decoration is testable without a window.

local M = {}

local MAC = { M = "⌥", A = "⌥", C = "⌃", S = "⇧", D = "⌘" }
local TEXT = { M = "Alt-", A = "Alt-", C = "Ctrl-", S = "Shift-", D = "Cmd-" }

---Human label for a single-modifier mapping: "<M-t>" -> "⌥t" / "Alt-t".
---@param lhs string
---@param mac boolean|nil defaults to the running OS
function M.key_label(lhs, mac)
    if mac == nil then
        mac = vim.fn.has("mac") == 1
    end
    local mod, key = lhs:match("^<([MACSD])%-(.+)>$")
    if not mod then
        return lhs
    end
    return (mac and MAC or TEXT)[mod] .. key
end

---@param path string
---@param home string|nil defaults to $HOME
function M.pretty_path(path, home)
    home = home or vim.env.HOME
    if home and home ~= "" then
        if path == home then
            return "~"
        end
        if path:sub(1, #home + 1) == home .. "/" then
            return "~" .. path:sub(#home + 1)
        end
    end
    return path
end

local function width(chunks)
    local n = 0
    for _, c in ipairs(chunks) do
        n = n + vim.fn.strdisplaywidth(c[1])
    end
    return n
end

-- Name, folder and exit chip: the left/title side.
local function left_parts(info, with_cwd)
    local parts = { { " " .. info.shell .. " ", "GlasstermTitle" } }
    if with_cwd and info.cwd then
        parts[#parts + 1] = { info.cwd .. " ", "GlasstermHint" }
    end
    if info.status and info.status ~= 0 then
        parts[#parts + 1] = { (" exit %d "):format(info.status), "GlasstermErrorChip" }
    end
    return parts
end

-- Terminal tabs and key hints: the right/footer side.
local function right_parts(info, with_hints)
    local parts = {}
    if #info.terms > 1 then
        for _, id in ipairs(info.terms) do
            local hl = id == info.current and "GlasstermTabActive" or "GlasstermTab"
            parts[#parts + 1] = { (" %d "):format(id), hl }
        end
    end
    if with_hints and #info.hints > 0 then
        parts[#parts + 1] = { " " .. table.concat(info.hints, " · ") .. " ", "GlasstermHint" }
    end
    return parts
end

-- One-line layouts give up the hints first, then the folder.
local function fit_line(info)
    for _, keep in ipairs({ { true, true }, { true, false }, { false, false } }) do
        local left, right = left_parts(info, keep[1]), right_parts(info, keep[2])
        if width(left) + width(right) <= info.width then
            return left, right
        end
    end
    return left_parts(info, false), {}
end

local function escape(s)
    return (s:gsub("%%", "%%%%"))
end

local function statusline(chunks)
    local out = {}
    for _, c in ipairs(chunks) do
        out[#out + 1] = ("%%#%s#%s"):format(c[2], escape(c[1]))
    end
    return table.concat(out)
end

---@param slot "top"|"center"|"bottom"|"winbar"
---@param info table shell, cwd, status, terms, current, hints, width, border_hl
---@return table { title?, title_pos?, footer?, footer_pos?, winbar? }
function M.decorations(slot, info)
    if slot == "bottom" then
        local left, right = fit_line(info)
        local footer = vim.list_extend({}, left)
        local gap = info.width - width(left) - width(right)
        if gap > 0 then
            footer[#footer + 1] = { string.rep("─", gap), info.border_hl }
        end
        vim.list_extend(footer, right)
        return { footer = footer, footer_pos = "left" }
    end

    if slot == "winbar" then
        local left, right = fit_line(info)
        local bar = statusline(left) .. "%*"
        if #right > 0 then
            bar = bar .. "%=" .. statusline(right) .. "%*"
        end
        return { winbar = bar }
    end

    local title = left_parts(info, true)
    if width(title) > info.width then
        title = left_parts(info, false)
    end
    local footer = right_parts(info, true)
    if width(footer) > info.width then
        footer = right_parts(info, false)
    end
    return {
        title = title,
        title_pos = slot == "center" and "center" or "left",
        footer = #footer > 0 and footer or nil,
        footer_pos = #footer > 0 and "right" or nil,
    }
end

return M
