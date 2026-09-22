# glassterm: zsh reads this file because glassterm pointed ZDOTDIR here.
# Put the user's ZDOTDIR back first, so zsh goes on to read their .zprofile,
# .zshrc and .zlogin exactly as usual, and child shells never see this file.
if [[ -n "${GLASSTERM_ZDOTDIR_SET-}" ]]; then
    export ZDOTDIR="$GLASSTERM_ZDOTDIR"
else
    unset ZDOTDIR
fi
unset GLASSTERM_ZDOTDIR GLASSTERM_ZDOTDIR_SET

# The user's own .zshenv, as zsh would have loaded it.
if [[ -r "${ZDOTDIR:-$HOME}/.zshenv" ]]; then
    builtin source "${ZDOTDIR:-$HOME}/.zshenv"
fi

if [[ -o interactive ]]; then
    builtin source "${${(%):-%x}:A:h}/glassterm.zsh"
fi
