#!/bin/bash
# Builds the throwaway HOME the README recordings run in: a plain zsh
# prompt and a tiny Lua project, so no personal shell setup is recorded.
set -euo pipefail

D=/tmp/glassterm-demo
rm -rf "$D"
mkdir -p "$D/app/src"

cat >"$D/.zshrc" <<'EOF'
autoload -Uz vcs_info add-zsh-hook
add-zsh-hook precmd vcs_info
zstyle ':vcs_info:git:*' formats ' %F{magenta} %b%f'
setopt prompt_subst
PROMPT=$'\n%F{cyan}%~%f${vcs_info_msg_0_}\n%(?.%F{green}.%F{red})❯%f '
EOF

cat >"$D/app/server.lua" <<'EOF'
-- A tiny router: match a method and a path to a handler.
local M = {}

local routes = {}

function M.get(path, handler)
    routes["GET " .. path] = handler
end

function M.post(path, handler)
    routes["POST " .. path] = handler
end

function M.handle(req)
    local handler = routes[req.method .. " " .. req.path]
    if not handler then
        return { status = 404, body = "not found" }
    end
    if req.method == "POST" and (req.body == nil or req.body == "") then
        return { status = 400, body = "empty body" }
    end
    local ok, res = pcall(handler, req)
    if not ok then
        return { status = 500, body = tostring(res) }
    end
    return res
end

M.get("/health", function()
    return { status = 200, body = "ok" }
end)

return M
EOF

cat >"$D/app/src/routes.lua" <<'EOF'
return { "/health", "/users", "/users/:id" }
EOF

cat >"$D/app/test.sh" <<'EOF'
#!/bin/sh
printf '\033[2mrunning 12 tests…\033[0m\n'
sleep 0.4
if [ "${1:-}" = "--fail" ]; then
    printf '  \033[32m✓\033[0m routes resolve\n'
    printf '  \033[31m✗ rejects an empty body\033[0m\n'
    printf '    \033[2mexpected 400, got 500\033[0m\n\n'
    printf '\033[31m1 failing\033[0m, 11 passing\n'
    exit 1
fi
printf '  \033[32m✓ 12 passing\033[0m \033[2m(0.4s)\033[0m\n'
EOF
chmod +x "$D/app/test.sh"

git -C "$D/app" init -q -b main
git -C "$D/app" add -A
git -C "$D/app" -c user.name=demo -c user.email=demo@example.com commit -q -m "init"
