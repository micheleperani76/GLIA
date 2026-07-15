# ============================================================
#  glia.fish - Fish completion for the glia AI assistant
#  Version: 1.2 - 2026-07-15 (adds -w/--web + --web-model + --project-model)
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Completes flags, sub-actions (-a, -m, --memory, -p, -i, --update),
#  saved alias names and downloaded Ollama model names.
#
#  Install (per user):
#    cp completions/glia.fish ~/.config/fish/completions/glia.fish
#  (fish loads it automatically; no config change needed)
#
#  Renamed assistant? Make the new name reuse these completions,
#  e.g.:  complete -c arx --wraps glia
# ============================================================

# ------------------- helpers -----------------------
function __glia_models
    command -sq ollama; and ollama list 2>/dev/null | awk 'NR>1 && $1!="" {print $1}'
end

function __glia_aliases
    test -r ~/.config/glia/aliases; and cut -f1 ~/.config/glia/aliases
end

function __glia_first    # cursor on the first argument?
    test (count (commandline -opc)) -eq 1
end

function __glia_prev     # previous token
    set -l t (commandline -opc)
    echo $t[-1]
end

function __glia_prev2    # token before the previous one ("" if none)
    set -l t (commandline -opc)
    if test (count $t) -ge 2
        echo $t[-2]
    end
end

# requests are free text: never complete file names
complete -c glia -f

# ------------------- flags (first position) --------
complete -c glia -n __glia_first -a '-h'          -d 'help'
complete -c glia -n __glia_first -a '-V'          -d 'version'
complete -c glia -n __glia_first -a '-i'          -d 'interactive mode (REPL)'
complete -c glia -n __glia_first -a '-d'          -d 'answer in words, run nothing'
complete -c glia -n __glia_first -a '-l'          -d 'command log'
complete -c glia -n __glia_first -a '-a'          -d 'aliases (shortcuts)'
complete -c glia -n __glia_first -a '-m'          -d 'models / AI'
complete -c glia -n __glia_first -a '-p'          -d 'project mode'
complete -c glia -n __glia_first -a '-w'          -d 'web search with sources'
complete -c glia -n __glia_first -a '--web-model' -d 'pin the AI used by -w'
complete -c glia -n __glia_first -a '--project-model' -d 'pin the AI used by -p'
complete -c glia -n __glia_first -a '--remember'  -d 'store a fact'
complete -c glia -n __glia_first -a '--memory'    -d 'list stored facts'
complete -c glia -n __glia_first -a '--forget'    -d 'delete fact number n'
complete -c glia -n __glia_first -a '--clear-cache' -d 'empty the command cache'
complete -c glia -n __glia_first -a '--doctor'    -d 'one-shot health check'
complete -c glia -n __glia_first -a '--update'    -d 'update the Ollama engine'
complete -c glia -n __glia_first -a '--rename'    -d 'rename the assistant'
complete -c glia -n __glia_first -a '--lang'      -d 'interface language'

# ------------------- sub-actions -------------------
# after -m / --model
complete -c glia -n 'contains -- (__glia_prev) -m --model' -a 'help list ls ps stop pull update rm'
complete -c glia -n 'contains -- (__glia_prev) -m --model' -a '(__glia_models)'

# -m update <model> · -m rm <model> · -m stop <model>
complete -c glia -n 'contains -- (__glia_prev2) -m --model; and contains -- (__glia_prev) update rm stop' -a '(__glia_models)'
# -m pull <name>: a NEW model name is free text, nothing to complete

# after -a / --alias
complete -c glia -n 'contains -- (__glia_prev) -a --alias' -a 'add list rm edit save help'
complete -c glia -n 'contains -- (__glia_prev) -a --alias' -a '(__glia_aliases)'

# -a rm <alias>
complete -c glia -n 'contains -- (__glia_prev2) -a --alias; and test (__glia_prev) = rm' -a '(__glia_aliases)'

# --lang <code>
complete -c glia -n 'contains -- (__glia_prev) --lang' -a 'it en de'

# --web-model / --project-model <n|name|default>: pin a dedicated AI
complete -c glia -n 'contains -- (__glia_prev) --web-model --project-model' -a 'default show help'
complete -c glia -n 'contains -- (__glia_prev) --web-model --project-model' -a '(__glia_models)'

# groups that take "help"
complete -c glia -n 'contains -- (__glia_prev) --update --memory -p --project -i --interactive' -a 'help'

# --update glia: update the GLIA program itself (self-update)
complete -c glia -n 'contains -- (__glia_prev) --update' -a 'glia' -d 'update GLIA itself'

# renamed assistant? add its name too, e.g.:
# complete -c arx --wraps glia
