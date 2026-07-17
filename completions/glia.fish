# ============================================================
#  glia.fish - Fish completion for the glia AI assistant
#  Version: 1.5 - 2026-07-17 (adds `-m role` roles console: roles + assignees)
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
#  e.g.:  complete -c myai --wraps glia
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
complete -c glia -n __glia_first -a '-p'          -d 'edit an existing file (shows the diff first)'
complete -c glia -n __glia_first -a '--new'       -d 'new project from scratch (was -p up to v2.17)'
complete -c glia -n __glia_first -a '-n'          -d 'new project from scratch (short for --new)'
complete -c glia -n __glia_first -a '-w'          -d 'web search with sources'
complete -c glia -n __glia_first -a '-w+'         -d 'web search that also reads the pages (deep)'
complete -c glia -n __glia_first -a '-ws'         -d 'direct web results, no AI (also opens a URL)'
complete -c glia -n __glia_first -a '-T'          -d 'translate a file into a new file next to it'
complete -c glia -n __glia_first -a '--web-model' -d 'pin the AI used by -w'
complete -c glia -n __glia_first -a '--translate-model' -d 'pin the AI used by -T'
complete -c glia -n __glia_first -a '--web-engine' -d 'show/switch the -w search engine (ddg|bing|searx)'
complete -c glia -n __glia_first -a '--project-model' -d 'pin the AI used by -p and --new'
complete -c glia -n __glia_first -a '--remember'  -d 'store a fact'
complete -c glia -n __glia_first -a '--memory'    -d 'list stored facts'
complete -c glia -n __glia_first -a '--forget'    -d 'delete fact number n'
complete -c glia -n __glia_first -a '--clear-cache' -d 'empty the command cache'
complete -c glia -n __glia_first -a '--doctor'    -d 'one-shot health check'
complete -c glia -n __glia_first -a '--update'    -d 'update GLIA itself (chosen channel)'
complete -c glia -n __glia_first -a '--update-engine' -d 'update the Ollama engine'
complete -c glia -n __glia_first -a '--channel'   -d 'show/switch release channel (stable|beta)'
complete -c glia -n __glia_first -a '--rollback'  -d 'go back to a previous version'
complete -c glia -n __glia_first -a '--rename'    -d 'rename the assistant'
complete -c glia -n __glia_first -a '--lang'      -d 'interface language'

# ------------------- sub-actions -------------------
# after -m / --model
complete -c glia -n 'contains -- (__glia_prev) -m --model' -a 'help list ls ps stop pull update rm role bench'
complete -c glia -n 'contains -- (__glia_prev) -m --model' -a '(__glia_models)'

# -m role <n|name|0> <role> (D2): first the AI (number/name, 0=default), then the job
complete -c glia -n 'contains -- (__glia_prev) role roles; and contains -- (__glia_prev2) -m --model' -a '0 (__glia_models)'
complete -c glia -n 'contains -- (__glia_prev2) role roles' -a 'web project translate w p t'

# -m bench [--dry-run] (D6b): no model/name argument, just the one flag
complete -c glia -n 'contains -- (__glia_prev) bench; and contains -- (__glia_prev2) -m --model' -a '--dry-run'

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

# --web-engine <preset>: -w search engine (searx also takes an instance URL)
complete -c glia -n 'contains -- (__glia_prev) --web-engine' -a 'ddg bing searx'

# --web-model / --project-model <n|name|default>: pin a dedicated AI
complete -c glia -n 'contains -- (__glia_prev) --web-model --project-model --translate-model' -a 'default show help'
complete -c glia -n 'contains -- (__glia_prev) --web-model --project-model --translate-model' -a '(__glia_models)'

# groups that take "help"
complete -c glia -n 'contains -- (__glia_prev) --update --memory -p --project -n --new -i --interactive' -a 'help'

# -p <file>: v2.18 edits an EXISTING file, so complete real paths
complete -c glia -n 'contains -- (__glia_prev) -p --project' -F

# -T <file> [lang]: translate an existing file
complete -c glia -n 'contains -- (__glia_prev) -T --translate' -F
complete -c glia -n 'contains -- (__glia_prev2) -T --translate' -a 'it en de'

# --update --check: ask only, install nothing. Bare --update already updates
# GLIA itself; 'glia'/'ollama' remain hidden aliases and are not offered here.
complete -c glia -n 'contains -- (__glia_prev) --update' -a '--check' -d 'check only, install nothing'

# --channel stable|beta
complete -c glia -n 'contains -- (__glia_prev) --channel' -a 'stable' -d 'final versions only (default)'
complete -c glia -n 'contains -- (__glia_prev) --channel' -a 'beta' -d 'also previews (-beta/-rc)'

# renamed assistant? add its name too, e.g.:
# complete -c myai --wraps glia
