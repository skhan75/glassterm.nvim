-- Window shapes. Each style maps the editor area to a float layout and
-- nothing here touches a window, so every shape is a pure function.
--
-- A layout is { row, col, width, height, border, border_hl, slot }:
--   row/col    top-left of the outer box, border included (nvim_open_win)
--   width/...  content size, border excluded
--   slot       where the title goes: "top", "center", "bottom" or "winbar"

local M = {}

local ROUNDED = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }

-- Sizes <= 1 are a fraction of the available space, > 1 a count of cells.
local function cells(v, total)
    if v <= 1 then
        return math.floor(total * v)
    end
    return math.floor(v)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(v, hi))
end

---Area a float may cover: below any tabline, above the statusline and cmdline.
---@return { top: integer, width: integer, height: integer }
function M.editor()
    local top = 0
    local stal = vim.o.showtabline
    if stal == 2 or (stal == 1 and #vim.api.nvim_list_tabpages() > 1) then
        top = 1
    end

    local status = 0
    local ls = vim.o.laststatus
    if ls == 2 or ls == 3 then
        status = 1
    elseif ls == 1 then
        local normal = 0
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_config(win).relative == "" then
                normal = normal + 1
            end
        end
        status = normal > 1 and 1 or 0
    end

    local height = vim.o.lines - top - status - vim.o.cmdheight
    return { top = top, width = vim.o.columns, height = math.max(height, 1) }
end

M.styles = {}

function M.styles.glass(o, e)
    local w = clamp(cells(o.width, e.width), 1, e.width - 2)
    local h = clamp(cells(o.height, e.height), 1, e.height - 2)
    return {
        row = e.top + math.floor((e.height - h - 2) / 2),
        col = math.floor((e.width - w - 2) / 2),
        width = w,
        height = h,
        border = ROUNDED,
        border_hl = "GlasstermBorder",
        slot = "top",
    }
end

function M.styles.drop(o, e)
    return {
        row = e.top,
        col = 0,
        width = e.width,
        height = clamp(cells(o.height, e.height), 1, e.height - 1),
        border = { "", "", "", "", "", "─", "", "" },
        border_hl = "GlasstermAccent",
        slot = "bottom",
    }
end

function M.styles.drawer(o, e)
    local w = clamp(cells(o.width, e.width), 1, e.width - 1)
    local right = o.side ~= "left"
    return {
        row = e.top,
        col = right and e.width - w - 1 or 0,
        width = w,
        height = e.height,
        border = right and { "", "", "", "", "", "", "", "│" } or { "", "", "", "│", "", "", "", "" },
        border_hl = "GlasstermBorder",
        slot = "winbar",
    }
end

function M.styles.capsule(o, e)
    local w = clamp(cells(o.width, e.width), 1, e.width - 2)
    local h = clamp(cells(o.height, e.height), 1, e.height - 2)
    local row = clamp(cells(o.row, e.height), 0, e.height - h - 2)
    return {
        row = e.top + row,
        col = math.floor((e.width - w - 2) / 2),
        width = w,
        height = h,
        border = ROUNDED,
        border_hl = "GlasstermAccent",
        slot = "center",
    }
end

local function zoom(e)
    return {
        row = e.top,
        col = 0,
        width = math.max(e.width - 2, 1),
        height = math.max(e.height - 2, 1),
        border = ROUNDED,
        border_hl = "GlasstermBorder",
        slot = "top",
    }
end

---@param name string style name
---@param opts table style options (width, height, row, side)
---@param editor { top: integer, width: integer, height: integer }
---@param state { zoom: boolean }|nil
function M.layout(name, opts, editor, state)
    if state and state.zoom then
        return zoom(editor)
    end
    local style = M.styles[name]
    if not style then
        error(("glassterm: unknown style %q"):format(tostring(name)))
    end
    return style(opts or {}, editor)
end

return M
