# glassterm shell integration for bash, loaded with `bash --rcfile`. It only
# prints terminal escape codes:
#   OSC 7        the current folder, at every prompt
#   OSC 133 ; A  a prompt starts (also powers Neovim's [[ and ]])
#   OSC 133 ; C  a command starts (bash 4.4+, through PS0)
#   OSC 133 ; D  the previous command ended, with its exit status

# --rcfile replaces the files an interactive bash normally reads: load them.
if [[ -r /etc/bash.bashrc ]]; then
    builtin source /etc/bash.bashrc
fi
if [[ -r ~/.bashrc ]]; then
    builtin source ~/.bashrc
fi

if [[ -z "${_GLASSTERM_LOADED-}" ]]; then
    _GLASSTERM_LOADED=1
    _glassterm_first=1

    # Percent-encode a path for a file:// URL; result in $REPLY.
    _glassterm_urlencode() {
        local LC_ALL=C s="$1" out="" c i
        for ((i = 0; i < ${#s}; i++)); do
            c="${s:i:1}"
            case "$c" in
                [a-zA-Z0-9/._~-]) out+="$c" ;;
                *) builtin printf -v c '%%%02X' "'$c"; out+="$c" ;;
            esac
        done
        REPLY="$out"
    }

    _glassterm_prompt() {
        local ret=$?
        # The first prompt follows the rc files, not a command the user ran.
        if [[ -n "$_glassterm_first" ]]; then
            _glassterm_first=
        else
            builtin printf '\e]133;D;%d\a' "$ret"
        fi
        _glassterm_urlencode "$PWD"
        builtin printf '\e]7;file://%s%s\a' "${HOSTNAME}" "$REPLY"
        builtin printf '\e]133;A\a'
        return "$ret" # keep $? for the rest of PROMPT_COMMAND
    }

    if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        PROMPT_COMMAND=(_glassterm_prompt "${PROMPT_COMMAND[@]}")
    else
        PROMPT_COMMAND="_glassterm_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
    fi

    if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))); then
        PS0="${PS0-}"$'\e]133;C\a'
    fi
fi
