-- Highlight groups. Each links to a standard group by default (`default =
-- true`), so any colorscheme looks reasonable and can override them.

local M = {}

M.links = {
    GlasstermNormal = "NormalFloat",
    GlasstermBorder = "FloatBorder",
    GlasstermAccent = "FloatTitle",
    GlasstermTitle = "FloatTitle",
    GlasstermHint = "Comment",
    GlasstermError = "DiagnosticError",
    GlasstermErrorChip = "DiagnosticVirtualTextError",
    GlasstermTab = "Comment",
    GlasstermTabActive = "PmenuSel",
}

function M.setup()
    for group, target in pairs(M.links) do
        vim.api.nvim_set_hl(0, group, { link = target, default = true })
    end
end

return M
