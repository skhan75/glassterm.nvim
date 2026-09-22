# glassterm shell integration for fish, loaded with --init-command after the
# user's config. It only prints terminal escape codes:
#   OSC 7        the current folder, at every prompt
#   OSC 133 ; A  a prompt starts (also powers Neovim's [[ and ]])
#   OSC 133 ; C  a command starts
#   OSC 133 ; D  the command ended, with its exit status
if not set -q __glassterm_loaded
    set -g __glassterm_loaded 1

    function __glassterm_preexec --on-event fish_preexec
        printf '\e]133;C\a'
    end

    function __glassterm_postexec --on-event fish_postexec
        printf '\e]133;D;%d\a' $status
    end

    function __glassterm_prompt --on-event fish_prompt
        # Escape each path component, keeping the slashes between them.
        set -l path (string join / (string escape --style=url -- (string split / -- $PWD)))
        printf '\e]7;file://%s%s\a' $hostname $path
        printf '\e]133;A\a'
    end
end
