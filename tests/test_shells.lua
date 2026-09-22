-- Shell integration against real shells in a throwaway HOME. Shells that are
-- not installed are skipped, not failed.
local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T["command()"] = MiniTest.new_set()

local function command(shell, enabled)
    return require("glassterm.integration").command(shell, 1, enabled ~= false)
end

T["command()"]["points zsh at glassterm's ZDOTDIR and remembers the user's"] = function()
    local saved = vim.env.ZDOTDIR
    vim.env.ZDOTDIR = "/home/me/.config/zsh"
    local argv, env, kind = command({ "/bin/zsh" })
    vim.env.ZDOTDIR = saved
    eq(argv, { "/bin/zsh" })
    eq(kind, "zsh")
    eq(env.ZDOTDIR:match("/shell/zsh$") ~= nil, true)
    eq(env.GLASSTERM_ZDOTDIR, "/home/me/.config/zsh")
    eq(env.GLASSTERM_ZDOTDIR_SET, "1")
end

T["command()"]["loads bash through --rcfile, keeping other arguments"] = function()
    local argv, _, kind = command({ "/opt/homebrew/bin/bash", "--noprofile" })
    eq(kind, "bash")
    eq(argv[1], "/opt/homebrew/bin/bash")
    eq(argv[2], "--rcfile")
    eq(argv[3]:match("/shell/bash/glassterm.bash$") ~= nil, true)
    eq(argv[4], "--noprofile")
end

T["command()"]["adds an init command for fish"] = function()
    local argv = command({ "fish" })
    eq(argv[2], "--init-command")
    eq(argv[3]:match("^source .*/shell/fish/glassterm.fish'?$") ~= nil, true)
end

T["command()"]["leaves other shells, commands and bash login shells alone"] = function()
    for _, shell in ipairs({ { "/bin/sh" }, { "nu" }, { "zsh", "-c", "ls" }, { "bash", "-l" } }) do
        local argv, env = command(shell)
        eq(argv, shell)
        eq(env.ZDOTDIR, nil)
    end
end

T["command()"]["starts the shell untouched when integration is off"] = function()
    local argv, env, kind = command({ "/bin/zsh" }, false)
    eq(argv, { "/bin/zsh" })
    eq(env.ZDOTDIR, nil)
    eq(kind, "zsh")
end

T["command()"]["marks every glassterm shell with GLASSTERM=1"] = function()
    eq(select(2, command({ "/bin/sh" })).GLASSTERM, "1")
end

-- Real shells ---------------------------------------------------------------

local child = H.new_child()
local home

local function start(shell, files)
    home = vim.fn.tempname()
    vim.fn.mkdir(home, "p")
    home = vim.uv.fs_realpath(home)
    for name, lines in pairs(files or {}) do
        vim.fn.mkdir(vim.fs.dirname(home .. "/" .. name), "p")
        vim.fn.writefile(lines, home .. "/" .. name)
    end
    child.start_editor()
    child.lua("vim.env.HOME = ...; vim.env.ZDOTDIR = nil; vim.fn.chdir(...)", { home })
    child.setup({ shell = shell, prewarm = false })
    child.lua("require('glassterm').prewarm()")
    H.wait(child, "term() and term().integrated and term().cwd ~= nil", 8000, "first prompt from " .. shell[1])
end

local function send(text)
    child.lua("vim.fn.chansend(term().job, ...)", { text .. "\r" })
end

local function read(name)
    local path = home .. "/" .. name
    return vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or nil
end

local function wait_file_lines(name, n)
    local deadline = vim.uv.now() + 5000
    while vim.uv.now() < deadline do
        local lines = read(name)
        if lines and #lines >= n then
            return lines
        end
        vim.uv.sleep(30)
    end
    error(("timed out waiting for %d lines in %s"):format(n, name), 2)
end

local function shell_set(bin, rc, extra)
    local set = MiniTest.new_set({
        hooks = {
            pre_case = function()
                if vim.fn.executable(bin) == 0 then
                    MiniTest.skip(bin .. " is not installed")
                end
            end,
            post_case = function()
                child.stop()
            end,
        },
    })

    set["loads the user's own rc file"] = function()
        start({ bin }, { [rc] = { 'touch "$HOME/rc-ran"' } })
        wait_file_lines("rc-ran", 0)
        eq(read("rc-ran") ~= nil, true)
    end

    set["reports the folder at each prompt"] = function()
        start({ bin })
        eq(child.lua_get("term().cwd"), home)
        vim.fn.mkdir(home .. "/sub dir", "p")
        send('cd "' .. home .. '/sub dir"')
        H.wait(child, "term().cwd == ...", 3000, "cwd update", { home .. "/sub dir" })
    end

    set["reports each command's exit status"] = function()
        start({ bin })
        send("false")
        H.wait(child, "term().status == 1", 3000, "status 1")
        send("true")
        H.wait(child, "term().status == 0", 3000, "status 0")
    end

    set["does not report a failure for the rc file's last command"] = function()
        start({ bin }, { [rc] = { "false" } })
        vim.uv.sleep(300)
        eq(child.lua_get("term().status == nil or term().status == 0"), true)
        eq(child.lua_get("#_G.notes"), 0)
    end

    set["re-runs the previous command and reports the result"] = function()
        start({ bin })
        send('echo run >> "$HOME/log"')
        wait_file_lines("log", 1)
        H.wait(child, "term().status == 0 and not term().busy", 3000)
        child.lua("require('glassterm').rerun()")
        wait_file_lines("log", 2)
        H.wait(child, "#_G.notes > 0", 3000, "re-run notification")
        eq(child.lua_get("_G.notes[1].msg:match('✓ exit 0') ~= nil"), true)
        -- A second re-run repeats the same command, not the re-run itself.
        child.lua("require('glassterm').rerun()")
        eq(#wait_file_lines("log", 3), 3)
    end

    set["re-run clears a half-typed command first"] = function()
        start({ bin })
        send('echo run >> "$HOME/log"')
        wait_file_lines("log", 1)
        H.wait(child, "term().status == 0", 3000)
        child.lua("vim.fn.chansend(term().job, ...)", { 'touch "$HOME/half"' })
        child.lua("require('glassterm').rerun()")
        wait_file_lines("log", 2)
        eq(read("half"), nil)
    end

    for name, fn in pairs(extra or {}) do
        set[name] = fn
    end
    return set
end

T["zsh"] = shell_set("zsh", ".zshrc", {
    ["restores the user's ZDOTDIR for their files and child shells"] = function()
        start({ "zsh" })
        send('print -r -- "${ZDOTDIR-unset}" > "$HOME/zdotdir.txt"')
        eq(wait_file_lines("zdotdir.txt", 1), { "unset" })
    end,
    ["honours a ZDOTDIR the user already had"] = function()
        home = nil
        local dir = vim.uv.fs_realpath(vim.fn.tempname():match("^(.*)/")) .. "/gt-zdot-" .. vim.uv.hrtime()
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({ 'touch "$ZDOTDIR/zshrc-ran"' }, dir .. "/.zshrc")
        child.start_editor()
        child.lua("vim.env.ZDOTDIR = ...", { dir })
        child.setup({ shell = { "zsh" }, prewarm = false })
        child.lua("require('glassterm').prewarm()")
        H.wait(child, "term() and term().integrated", 8000, "prompt")
        eq(vim.fn.filereadable(dir .. "/zshrc-ran"), 1)
    end,
    ["marks a running command busy until it ends"] = function()
        start({ "zsh" })
        send("sleep 0.6")
        H.wait(child, "term().busy == true", 2000, "busy")
        child.lua("require('glassterm').rerun()")
        eq(child.lua_get("_G.notes[#_G.notes].msg:match('busy') ~= nil"), true)
        H.wait(child, "term().busy == false and term().status == 0", 3000, "command end")
    end,
})

T["bash"] = shell_set("bash", ".bashrc")
T["fish"] = shell_set("fish", ".config/fish/config.fish")

return T
