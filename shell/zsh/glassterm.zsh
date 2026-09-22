# glassterm shell integration for zsh. It only prints terminal escape codes:
#   OSC 7        the current folder, at every prompt
#   OSC 133 ; A  a prompt starts (also powers Neovim's [[ and ]])
#   OSC 133 ; C  a command starts
#   OSC 133 ; D  the command ended, with its exit status
[[ -n "${_GLASSTERM_LOADED-}" ]] && return
typeset -g _GLASSTERM_LOADED=1
typeset -gi _glassterm_running=0

# Percent-encode a path for a file:// URL; result in $REPLY.
_glassterm_urlencode() {
    emulate -L zsh
    local LC_ALL=C s="$1" out="" c hex
    local -i i
    for (( i = 1; i <= ${#s}; i++ )); do
        c="${s[i]}"
        case "$c" in
            [a-zA-Z0-9/._~-]) out+="$c" ;;
            *) builtin printf -v hex '%%%02X' "'$c"; out+="$hex" ;;
        esac
    done
    REPLY="$out"
}

_glassterm_precmd() {
    local ret=$?
    # Only after a command ran: not for the first prompt or an empty line.
    if (( _glassterm_running )); then
        builtin printf '\e]133;D;%d\a' "$ret"
        _glassterm_running=0
    fi
    _glassterm_urlencode "$PWD"
    builtin printf '\e]7;file://%s%s\a' "${HOST}" "$REPLY"
    builtin printf '\e]133;A\a'
}

_glassterm_preexec() {
    _glassterm_running=1
    builtin printf '\e]133;C\a'
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _glassterm_precmd
add-zsh-hook preexec _glassterm_preexec
