local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function parse(seq)
    return require("glassterm.osc").parse(seq)
end

T["cwd (OSC 7)"] = MiniTest.new_set()

T["cwd (OSC 7)"]["reads the path and ignores the host"] = function()
    eq(parse("\27]7;file://mac.local/Users/sami/workspace/nvim"), {
        kind = "cwd",
        path = "/Users/sami/workspace/nvim",
    })
end

T["cwd (OSC 7)"]["decodes percent-escapes"] = function()
    eq(parse("\27]7;file://h/Users/sami/my%20dir/caf%C3%A9").path, "/Users/sami/my dir/café")
end

T["cwd (OSC 7)"]["accepts an empty host"] = function()
    eq(parse("\27]7;file:///tmp").path, "/tmp")
end

T["cwd (OSC 7)"]["strips a BEL or ST terminator"] = function()
    eq(parse("\27]7;file://h/tmp\7").path, "/tmp")
    eq(parse("\27]7;file://h/tmp\27\\").path, "/tmp")
end

T["shell marks (OSC 133)"] = MiniTest.new_set()

T["shell marks (OSC 133)"]["recognises a prompt start, with or without parameters"] = function()
    eq(parse("\27]133;A"), { kind = "prompt" })
    eq(parse("\27]133;A;cl=m;aid=42\7"), { kind = "prompt" })
end

T["shell marks (OSC 133)"]["recognises a command start"] = function()
    eq(parse("\27]133;C\7"), { kind = "command_start" })
end

T["shell marks (OSC 133)"]["reads the exit status of a finished command"] = function()
    eq(parse("\27]133;D;0"), { kind = "command_end", status = 0 })
    eq(parse("\27]133;D;127\7"), { kind = "command_end", status = 127 })
end

T["shell marks (OSC 133)"]["reports an unknown status when none is given"] = function()
    eq(parse("\27]133;D"), { kind = "command_end" })
end

T["ignores sequences it does not use"] = function()
    eq(parse("\27]133;B"), nil)
    eq(parse("\27]52;c;aGVsbG8="), nil)
    eq(parse("\27P+q544e\27\\"), nil)
    eq(parse(""), nil)
end

return T
