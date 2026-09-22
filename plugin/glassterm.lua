-- :Glassterm command. Everything else loads on first use.
if vim.g.loaded_glassterm then
    return
end
vim.g.loaded_glassterm = true

if vim.fn.has("nvim-0.11") == 0 then
    vim.api.nvim_echo({ { "glassterm.nvim needs Neovim 0.11 or newer", "ErrorMsg" } }, true, {})
    return
end

local function gt()
    return require("glassterm")
end

local subcommands = {
    toggle = function(a)
        gt().toggle(tonumber(a.fargs[2]))
    end,
    open = function(a)
        gt().open(tonumber(a.fargs[2]))
    end,
    close = function()
        gt().close()
    end,
    zoom = function()
        gt().zoom()
    end,
    style = function(a)
        gt().set_style(a.fargs[2])
    end,
    send = function(a)
        if a.range > 0 then
            gt().send(vim.api.nvim_buf_get_lines(0, a.line1 - 1, a.line2, false))
        else
            gt().send(table.concat(vim.list_slice(a.fargs, 2), " "))
        end
    end,
    rerun = function()
        gt().rerun()
    end,
}

local names = vim.tbl_keys(subcommands)
table.sort(names)

local function starting(list, prefix)
    return vim.tbl_filter(function(s)
        return vim.startswith(s, prefix)
    end, list)
end

vim.api.nvim_create_user_command("Glassterm", function(a)
    local name = a.fargs[1] or "toggle"
    local fn = subcommands[name]
    if not fn then
        return vim.notify(("glassterm: unknown subcommand %q"):format(name), vim.log.levels.ERROR)
    end
    local ok, err = pcall(fn, a)
    if not ok then
        vim.notify(tostring(err), vim.log.levels.ERROR)
    end
end, {
    nargs = "*",
    range = true,
    desc = "glassterm: floating terminal",
    complete = function(lead, line)
        local words = vim.split(line, "%s+", { trimempty = true })
        local n = #words + (line:match("%s$") and 1 or 0)
        if n == 2 then
            return starting(names, lead)
        elseif n == 3 and words[2] == "style" then
            return starting(require("glassterm.config").STYLES, lead)
        end
        return {}
    end,
})
