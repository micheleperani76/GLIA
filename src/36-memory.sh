# ---- persistent memory (v1.6) ----
memory_context() {
    # prints the stored facts as one prompt line; nothing if memory is empty
    [ -s "$MEMFILE" ] || return 0
    printf 'Known facts about the user (background only, use them ONLY when the request refers to them; otherwise act on the local machine): %s. ' \
        "$(paste -sd ';' "$MEMFILE" | sed 's/;/; /g')"
}

remember_fact() {
    [ -z "$*" ] && { echo "$(t mem_usage)" >&2; exit 1; }
    mkdir -p "$(dirname "$MEMFILE")"
    printf '%s\n' "$*" >> "$MEMFILE"
    if [ "$(wc -l < "$MEMFILE")" -gt "$MEMMAX" ]; then
        tail -n "$MEMMAX" "$MEMFILE" > "$MEMFILE.tmp" && mv "$MEMFILE.tmp" "$MEMFILE"
    fi
    echo -e "${GREEN}$(t mem_saved)${NC}"
    show_equiv "echo '$*' >> ${MEMFILE/#$HOME/\~}"
}

show_memory() {
    if [ -s "$MEMFILE" ]; then
        nl -w2 -s'. ' "$MEMFILE"
        echo -e "${YELLOW}$(t mem_file) ${MEMFILE/#$HOME/\~}${NC}"
    else
        echo "$(t mem_empty)"
    fi
}

forget_fact() {
    local n="$1" total fact
    if ! grep -qE '^[0-9]+$' <<< "$n" || [ ! -s "$MEMFILE" ]; then
        echo "$(t forget_usage)" >&2; exit 1
    fi
    total=$(wc -l < "$MEMFILE")
    if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        echo "$(t forget_usage)" >&2; exit 1
    fi
    fact=$(sed -n "${n}p" "$MEMFILE")
    sed -i "${n}d" "$MEMFILE"
    echo -e "${GREEN}$(t forgotten)${NC} $fact"
    show_equiv "sed -i '${n}d' ${MEMFILE/#$HOME/\~}"
}

# ---- conversation context (v1.6) ----
session_context() {
    # prints the recent exchanges of this terminal, if not expired
    [ -f "$SESSFILE" ] || return 0
    local age
    age=$(( $(date +%s) - $(stat -c %Y "$SESSFILE" 2>/dev/null || echo 0) ))
    if [ "$age" -gt "$SESSTTL" ]; then
        rm -f "$SESSFILE"
        return 0
    fi
    printf 'Recent conversation in this terminal (use it to resolve follow-ups like "it", "that file"): %s. ' \
        "$(paste -sd ';' "$SESSFILE" | sed 's/;/; /g')"
}

session_add() {
    # $1 = user request, $2 = executed command
    printf 'User asked: %s | you ran: %s\n' "$1" "$2" >> "$SESSFILE" 2>/dev/null || return 0
    tail -n "$SESSMAX" "$SESSFILE" > "$SESSFILE.tmp" && mv "$SESSFILE.tmp" "$SESSFILE"
    chmod 600 "$SESSFILE" 2>/dev/null
}

# ---- command cache (v1.7) ----
cache_key() {
    # same request in the same directory = same key (case/space insensitive)
    printf '%s|%s' "$PWD" "$(tr -s ' ' <<< "${*,,}")" | sha256sum | cut -d' ' -f1
}

cache_lookup() {
    [ -f "$CACHEFILE" ] || return 0
    grep "^$(cache_key "$@")|" "$CACHEFILE" 2>/dev/null | tail -n 1 | cut -d'|' -f2-
}

cache_store() {
    # $1 = request, $2 = command that just ran with exit 0
    local key; key=$(cache_key "$1")
    mkdir -p "$(dirname "$CACHEFILE")"
    { grep -v "^$key|" "$CACHEFILE" 2>/dev/null; printf '%s|%s\n' "$key" "$2"; } > "$CACHEFILE.tmp"
    tail -n "$CACHEMAX" "$CACHEFILE.tmp" > "$CACHEFILE"
    rm -f "$CACHEFILE.tmp"
}

# ---- aliases (v2.0): named shortcuts, no AI needed ----
# storage: name<TAB>type<TAB>request<TAB>command   (type = run | ask)
ALIAS_RESERVED=" add list ls rm remove edit help save "   # sub-actions, not valid names

alias_valid_name() {
    # correct shape AND not one of the -a sub-actions
    grep -qE '^[a-zA-Z][a-zA-Z0-9_-]*$' <<< "$1" || return 1
    case "$ALIAS_RESERVED" in *" $1 "*) return 1 ;; esac
    return 0
}

alias_get() {
    # print the line whose name == $1, exit 1 if none
    [ -f "$ALIASFILE" ] || return 1
    awk -F'\t' -v n="$1" '$1==n {print; f=1} END{exit !f}' "$ALIASFILE"
}

alias_resolve() {
    # $1 = a line number (as shown by -a list) OR a name (case-insensitive).
    # Prints the real stored name, exit 1 if nothing matches.
    [ -s "$ALIASFILE" ] || return 1
    local q="$1" total
    if [[ "$q" =~ ^[0-9]+$ ]]; then
        total=$(wc -l < "$ALIASFILE")
        [ "$q" -ge 1 ] && [ "$q" -le "$total" ] || return 1
        sed -n "${q}p" "$ALIASFILE" | cut -f1
        return 0
    fi
    awk -F'\t' -v n="$q" 'tolower($1)==tolower(n){print $1; f=1; exit} END{exit !f}' "$ALIASFILE"
}

alias_store() {
    # $1 name  $2 type  $3 request  $4 command  (replaces an existing name)
    # D4 (v2.18.9): saving a shortcut writes a file, so it must teach the file.
    # show_equiv shows the HAND-TYPABLE equivalent (sed -i / printf >>), which
    # gives the identical result; the internals below use grep -v + mv because
    # a temp file and one atomic rename can't leave a half-written aliases file.
    local existed=0
    mkdir -p "$(dirname "$ALIASFILE")"; touch "$ALIASFILE"
    grep -qE "^$1"$'\t' "$ALIASFILE" && existed=1
    { grep -vE "^$1"$'\t' "$ALIASFILE" 2>/dev/null
      printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; } > "$ALIASFILE.tmp"
    mv "$ALIASFILE.tmp" "$ALIASFILE"
    if [ "$existed" -eq 1 ]; then
        echo -e "${GREEN}$(t al_updated) $1${NC}"
        show_equiv "sed -i '/^$1\\\\t/d' ${ALIASFILE/#$HOME/\~}  ·  printf '%s\\\\t%s\\\\t%s\\\\t%s\\\\n' '$1' '$2' '$3' '$4' >> ${ALIASFILE/#$HOME/\~}"
    else
        echo -e "${GREEN}$(t al_saved) $1${NC}"
        show_equiv "printf '%s\\\\t%s\\\\t%s\\\\t%s\\\\n' '$1' '$2' '$3' '$4' >> ${ALIASFILE/#$HOME/\~}"
    fi
}

alias_list() {
    if [ ! -s "$ALIASFILE" ]; then echo "$(t al_empty)"; return; fi
    printf '%-3s %-16s %-5s %s\n' "#" "$(t al_c_name)" "$(t al_c_type)" "$(t al_c_cmd)"
    # awk keeps empty fields (unlike read+IFS=tab, which collapses them); NR = row number
    awk -F'\t' 'NF {printf "%-3s %-16s %-5s %s\n", NR, $1, $2, $4}' "$ALIASFILE"
}

alias_add() {
    local name="$1" cmd req ans
    # quick form: -a add <name> <command...>  -> direct alias
    if [ -n "$name" ] && [ "$#" -ge 2 ]; then
        shift; cmd="$*"
        alias_valid_name "$name" || { echo "$(t al_invalid)" >&2; return 1; }
        alias_store "$name" "run" "" "$cmd"; return
    fi
    # interactive form: ask for the word (name), then the command
    if [ -z "$name" ]; then
        read -r -p "$(t al_name_q)" name < /dev/tty || return 1
    fi
    alias_valid_name "$name" || { echo "$(t al_invalid)" >&2; return 1; }
    read -r -p "$(t al_cmd_q)" cmd < /dev/tty || return 1
    [ -z "$cmd" ] && { echo "$(t cancelled)"; return 1; }
    read -r -p "$(t al_ai_q)" ans < /dev/tty || ans=""
    case "${ans,,}" in
        "$YES_KEY"|s|y|j)
            read -r -p "$(t al_req_q)" req < /dev/tty || req=""
            [ -z "$req" ] && req="$cmd"
            alias_store "$name" "ask" "$req" "$cmd" ;;
        *)  alias_store "$name" "run" "" "$cmd" ;;
    esac
}

alias_rm() {
    local arg="$1" name cmd answer
    # guided mode: no argument -> show the numbered list and ask which one
    if [ -z "$arg" ]; then
        [ -s "$ALIASFILE" ] || { echo "$(t al_empty)"; return; }
        alias_list
        read -r -p "$(t al_rm_which)" arg < /dev/tty || return 1
        [ -z "$arg" ] && { echo "$(t cancelled)"; return; }
    fi
    # accept a number (from the list) or a name (case-insensitive)
    name=$(alias_resolve "$arg") || { echo -e "${RED}$(t al_notfound) $arg${NC}" >&2; return 1; }
    cmd=$(awk -F'\t' -v n="$name" '$1==n{print $4; exit}' "$ALIASFILE")
    # confirm before deleting, so a wrong number/name can't wipe the wrong one.
    # only when a real terminal is available; non-interactive (scripts) proceed.
    if (exec 3</dev/tty) 2>/dev/null; then
        echo -e "  ${GREEN}$name${NC}  ->  $cmd"
        read -r -p "$(t al_rm_confirm)" answer < /dev/tty || answer=""
        case "${answer,,}" in "$YES_KEY"|s|y|j) : ;; *) echo "$(t cancelled)"; return ;; esac
    fi
    # no '&&': removing the last line makes grep -v empty and exit 1,
    # which would otherwise skip the mv and leave the alias in place
    grep -vE "^$name"$'\t' "$ALIASFILE" > "$ALIASFILE.tmp"
    mv "$ALIASFILE.tmp" "$ALIASFILE"
    echo -e "${GREEN}$(t al_removed) $name${NC}"
    show_equiv "sed -i '/^$name\\\\t/d' ${ALIASFILE/#$HOME/\~}"
}

alias_edit() {
    local ed="${EDITOR:-${VISUAL:-}}"
    [ -z "$ed" ] && { command -v nano >/dev/null 2>&1 && ed=nano || ed=vi; }
    mkdir -p "$(dirname "$ALIASFILE")"; touch "$ALIASFILE"
    "$ed" "$ALIASFILE" < /dev/tty > /dev/tty 2>&1
}

alias_execute() {
    # run a saved command, keeping the usual safety confirmations
    local cmd="$1" answer
    if is_reboot_cmd "$cmd"; then
        echo -e "$(t proposed) ${GREEN}$cmd${NC}"
        echo -e "${RED}$(t warn)${NC}"
        read -r -p "$(t ask_reboot)" answer < /dev/tty || { echo "$(t cancelled)"; return; }
        case "${answer,,}" in "$YES_KEY") : ;; *) echo "$(t cancelled)"; return ;; esac
    elif needs_extra_confirm "$cmd"; then
        echo -e "$(t proposed) ${GREEN}$cmd${NC}"
        echo -e "${RED}$(t warn)${NC}"
        read -r -p "$(t ask_danger)" answer < /dev/tty || { echo "$(t cancelled)"; return; }
        case "${answer,,}" in "$YES_KEY") : ;; *) echo "$(t cancelled)"; return ;; esac
    fi
    run_command "$cmd"
}

alias_run() {
    # $1 = alias name (case-insensitive) or list number to execute
    local name line type req cmd answer
    name=$(alias_resolve "$1") || { echo -e "${RED}$(t al_notfound) $1${NC}" >&2; return 1; }
    line=$(alias_get "$name") || { echo -e "${RED}$(t al_notfound) $1${NC}" >&2; return 1; }
    # cut keeps empty fields (unlike read+IFS=tab); fields: name type req command
    type=$(cut -f2 <<< "$line"); req=$(cut -f3 <<< "$line"); cmd=$(cut -f4 <<< "$line")
    if [ "$type" = "ask" ]; then
        echo -e "$(t proposed) ${GREEN}$cmd${NC}"
        read -r -p "$(t al_run_ask)" answer < /dev/tty || answer=""
        case "${answer,,}" in
            a)  check_ai; propose_and_run "$req"; return ;;
            *)  alias_execute "$cmd" ;;
        esac
    else
        alias_execute "$cmd"
    fi
}

