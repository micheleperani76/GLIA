#!/usr/bin/env bash
# ============================================================
#  glia.bash - Bash completion for the glia AI assistant
#  Version: 1.3 - 2026-07-15 (adds -w/--web + --web-model + --project-model)
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Completes flags, sub-actions (-a, -m, --memory, -p, -i),
#  saved alias names and downloaded Ollama model names.
#
#  Install (per user):
#    source this file from ~/.bashrc, or copy it to
#    /usr/share/bash-completion/completions/glia
#
#  Renamed assistant? Register the extra name at the bottom,
#  e.g.:  complete -F _glia myai
# ============================================================

# ----------------- CONFIGURATION -----------------
_GLIA_ALIASFILE="$HOME/.config/glia/aliases"
# ---------------------------------------------------

_glia_alias_names() {
    [ -r "$_GLIA_ALIASFILE" ] && cut -f1 "$_GLIA_ALIASFILE"
}

_glia_model_names() {
    command -v ollama >/dev/null 2>&1 && ollama list 2>/dev/null | awk 'NR>1 && $1!="" {print $1}'
}

_glia() {
    local cur prev flags
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    flags="-h --help -V --version -i --interactive -d --ask -l --log
           -a --alias -m --model -p --project --remember --memory --forget
           -w --web -w+ --web-deep --web-model --project-model
           --clear-cache --doctor --update --rename --lang"

    case "$prev" in
        -a|--alias)
            COMPREPLY=( $(compgen -W "add list rm edit save help $(_glia_alias_names)" -- "$cur") )
            return ;;
        --web-model|--project-model)
            # pin a dedicated AI: a downloaded model, or "default" to follow the default
            COMPREPLY=( $(compgen -W "default show help $(_glia_model_names)" -- "$cur") )
            return ;;
        -m|--model)
            COMPREPLY=( $(compgen -W "help list ls ps stop pull update rm $(_glia_model_names)" -- "$cur") )
            return ;;
        --update)
            COMPREPLY=( $(compgen -W "help glia" -- "$cur") )
            return ;;
        pull)
            # -m pull <name>: a NEW model name is free text, nothing to complete
            return ;;
        update|stop)
            # -m update/stop <n|name>: complete with the downloaded models
            [ "${COMP_WORDS[COMP_CWORD-2]}" = "-m" ] || [ "${COMP_WORDS[COMP_CWORD-2]}" = "--model" ] \
                && COMPREPLY=( $(compgen -W "$(_glia_model_names)" -- "$cur") )
            return ;;
        --lang)
            COMPREPLY=( $(compgen -W "it en de" -- "$cur") )
            return ;;
        --memory)
            COMPREPLY=( $(compgen -W "help" -- "$cur") )
            return ;;
        -p|--project|-i|--interactive)
            COMPREPLY=( $(compgen -W "help" -- "$cur") )
            return ;;
        rm|remove)
            # -a rm <alias>  ·  -m rm <model>
            case "${COMP_WORDS[COMP_CWORD-2]}" in
                -a|--alias) COMPREPLY=( $(compgen -W "$(_glia_alias_names)" -- "$cur") ) ;;
                -m|--model) COMPREPLY=( $(compgen -W "$(_glia_model_names)" -- "$cur") ) ;;
            esac
            return ;;
    esac

    # flags only at the start; free text (the request) is never completed
    if [ "$COMP_CWORD" -eq 1 ] && [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "$flags" -- "$cur") )
    fi
}

complete -F _glia glia
# renamed assistant? add its name too, e.g.:
# complete -F _glia myai
