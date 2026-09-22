-- Neovim config for recording the README GIFs (`make demo`). You don't
-- need any of this to use glassterm.
--
--   GLASSTERM_DEMO_STYLE=drop  records another style (default: glass)

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. "/demo") -- colors/blazer.lua, lua/theme.lua

vim.g.mapleader = " "
vim.o.termguicolors = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.laststatus = 3
vim.o.showmode = false
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.o.fillchars = "eob: "
-- VHS sends Alt+t as Escape and t with its typing delay between them; a
-- real terminal sends both at once. Give the recorder room to be read as one.
vim.o.ttimeoutlen = 250
vim.cmd.colorscheme("blazer")

vim.api.nvim_create_autocmd("FileType", {
    pattern = "lua",
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})

function _G.demo_mode()
    local names = { n = " N ", i = " I ", t = " T ", c = " C " }
    return names[vim.fn.mode():sub(1, 1)] or " N "
end
vim.o.statusline = "%#GlasstermTabActive#%{v:lua.demo_mode()}%* %#GlasstermHint# main  %f%=%l:%c %*"

require("glassterm").setup({
    style = vim.env.GLASSTERM_DEMO_STYLE or "glass",
    shell = { "zsh" },
    prewarm = { delay_ms = 100 },
})

-- Key caps: show demo keypresses in the corner, like a screencast.
local cap = {}
local function show_key(label)
    if cap.win and vim.api.nvim_win_is_valid(cap.win) then
        vim.api.nvim_win_close(cap.win, true)
    end
    local text = "  " .. label .. "  "
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
    local width = vim.fn.strdisplaywidth(text)
    cap.win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        row = 1,
        col = vim.o.columns - width - 4,
        width = width,
        height = 1,
        border = "rounded",
        style = "minimal",
        focusable = false,
        zindex = 300,
    })
    vim.wo[cap.win].winhighlight = "NormalFloat:GlasstermTitle,FloatBorder:GlasstermAccent"
    local win = cap.win
    vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, 900)
end

local captions = {
    [vim.keycode("<M-t>")] = "⌥ t",
    [vim.keycode("<M-z>")] = "⌥ z",
}
vim.on_key(function(_, typed)
    local label = typed and captions[typed]
    if label then
        vim.schedule(function()
            show_key(label)
        end)
    end
end)
