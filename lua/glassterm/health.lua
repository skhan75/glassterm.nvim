-- :checkhealth glassterm

local M = {}

function M.check()
    local health = vim.health
    local config = require("glassterm.config")
    local integration = require("glassterm.integration")
    local term = require("glassterm.term")

    health.start("glassterm")

    if vim.fn.has("nvim-0.11") == 1 then
        health.ok("Neovim " .. tostring(vim.version()))
    else
        health.error("Neovim 0.11 or newer is required")
    end

    if require("glassterm")._did_setup then
        health.ok("setup() has been called")
    else
        health.warn("setup() has not been called: no keymaps are set", {
            "Call require('glassterm').setup() (lazy.nvim does this for `opts`)",
        })
    end

    local opts = config.options
    local argv = integration.argv(opts.shell)
    local kind = integration.kind(argv)
    if not opts.integration.enabled then
        health.info("Shell integration is off (integration.enabled = false)")
    elseif kind then
        health.ok(("%s: shell integration available"):format(kind))
    else
        health.warn(("%s: no shell integration"):format(argv[1] or "?"), {
            "The folder title, failure border and re-run need zsh, bash or fish",
        })
    end

    local ids = term.ids()
    if #ids == 0 then
        health.info("No terminal running yet")
    end
    for _, id in ipairs(ids) do
        local t = term.get(id)
        if t.integrated then
            health.ok(("terminal %d: shell integration active (%s)"):format(id, t.cwd or "?"))
        elseif t.kind and opts.integration.enabled then
            health.warn(("terminal %d: no signals from %s yet"):format(id, t.name), {
                "If this persists after a prompt, something in your shell startup files may be replacing prompt hooks",
            })
        else
            health.info(("terminal %d: %s"):format(id, t.name))
        end
    end
end

return M
