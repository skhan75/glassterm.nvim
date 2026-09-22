-- Parser for the shell-integration escape sequences a terminal child emits
-- (delivered by Neovim's TermRequest event):
--   OSC 7   ; file://host/path    current directory
--   OSC 133 ; A                   prompt start (also drives nvim's [[ / ]])
--   OSC 133 ; C                   command start
--   OSC 133 ; D [; status]        command finished

local M = {}

local function strip_terminator(seq)
    return (seq:gsub("\7$", ""):gsub("\27\\$", ""))
end

local function unescape(s)
    return (s:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

---@param seq string raw sequence, starting with ESC ]
---@return table|nil event { kind = "cwd", path } | { kind = "prompt" }
---  | { kind = "command_start" } | { kind = "command_end", status? }
function M.parse(seq)
    if type(seq) ~= "string" or seq:sub(1, 2) ~= "\27]" then
        return nil
    end
    local body = strip_terminator(seq:sub(3))

    local url = body:match("^7;(.*)$")
    if url then
        local path = url:match("^file://[^/]*(/.*)$")
        return path and { kind = "cwd", path = unescape(path) } or nil
    end

    local mark, rest = body:match("^133;(%a)(.*)$")
    if mark == "A" then
        return { kind = "prompt" }
    elseif mark == "C" then
        return { kind = "command_start" }
    elseif mark == "D" then
        return { kind = "command_end", status = tonumber(rest:match("^;(%-?%d+)")) }
    end
    return nil
end

return M
