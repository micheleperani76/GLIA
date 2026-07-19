# ---- AI model selection (v2.3): pick which downloaded Ollama model to use ----
model_names() {
    # downloaded Ollama model names, one per line, sorted for STABLE numbering
    ollama list 2>/dev/null | awk 'NR>1 && $1!="" {print $1}' | sort
}

model_resolve() {
    # $1 = a number (from the -m list) OR a model name -> prints the model name
    local q="$1" list n
    list=$(model_names)
    [ -z "$list" ] && return 1
    if [[ "$q" =~ ^[0-9]+$ ]]; then
        n=$(printf '%s\n' "$list" | sed -n "${q}p")
        [ -n "$n" ] && { printf '%s\n' "$n"; return 0; }
        return 1
    fi
    printf '%s\n' "$list" | grep -Fxq "$q" && { printf '%s\n' "$q"; return 0; }
    return 1
}

# ---- RAM primitives (v2.15.2): the ONE place that unloads / warms a model.
# Every function that touches the RAM (set_model, model_stop, swap_in,
# swap_out) goes through these, so the exact ollama/curl incantations live
# in a single spot instead of being copy-pasted around.
mem_unload() {
    # $1 = model -> stop it and free its RAM now. Belt and braces: `ollama
    # stop` for the CLI, plus the keep_alive:0 API that works on every version.
    ollama stop "$1" >/dev/null 2>&1
    curl -fsS --max-time 5 "$OLLAMA_URL/api/generate" -d "{\"model\":\"$1\",\"keep_alive\":0}" >/dev/null 2>&1
}
mem_warm() {
    # $1 = model -> preload it and keep it warm in RAM for the keep_alive window.
    curl -fsS --max-time 120 "$OLLAMA_URL/api/generate" -d "{\"model\":\"$1\",\"keep_alive\":\"30m\",\"prompt\":\"ok\",\"options\":{\"num_predict\":1}}" >/dev/null 2>&1
}

# spin_run <message> <cmd...> (v2.16): run cmd while showing a rotating spinner
# on stderr, so a silent model load looks like it is working. Falls back to a
# plain run (no spinner) when stderr is not a terminal — logs and pipes stay
# clean. The worker runs in the same process group, so Ctrl-C stops both.
spin_run() {
    local msg="$1"; shift
    if [ ! -t 2 ]; then "$@"; return $?; fi
    "$@" &
    local work=$! i=0 rc
    local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    while kill -0 "$work" 2>/dev/null; do
        printf '\r%s %s ' "${frames[i++%10]}" "$msg" >&2
        sleep 0.1
    done
    wait "$work"; rc=$?
    printf '\r\033[K' >&2      # erase the spinner line
    return $rc
}

set_model() {
    # $1 = model name -> becomes the permanent default (per-user)
    local old="${MODEL#ollama:}"
    mkdir -p "$HOME/.config/glia"
    printf '%s\n' "$1" > "$HOME/.config/glia/model"
    echo -e "${GREEN}$(t model_set) $1${NC}"
    show_equiv "echo '$1' > ~/.config/glia/model"
    # v2.11: unload the OLD model from RAM right away - otherwise it sits
    # there for ~5 more minutes (keep_alive) and the RAM looks saturated
    if [ "$old" != "$1" ] && model_loaded "$old"; then
        echo -e "$(t ms_unload) ${GREEN}ollama stop $old${NC}"
        mem_unload "$old"
    fi
    MODEL="ollama:$1"
}

# model_list_tagged: numbered downloaded AIs, each with its role tags (default
# + pinned roles from ROLES). Shared by `-m` (sheet) and `-m role` (D2), so the
# two always number and tag the AIs the same way.
model_list_tagged() {
    local active name i=1 tags r rn rpf pin
    active="${MODEL#ollama:}"
    while IFS= read -r name; do
        tags=""
        [ "$name" = "$active" ] && tags="default"
        for r in "${ROLES[@]}"; do
            IFS='|' read -r rn rpf _ <<< "$r"
            pin="$(head -n1 "$rpf" 2>/dev/null)"
            [ -n "$pin" ] && [ "$name" = "$pin" ] && tags="${tags:+$tags · }$rn"
        done
        if [ -n "$tags" ]; then
            printf '  %d) %s   ← %s\n' "$i" "$name" "$tags"
        else
            printf '  %d) %s\n' "$i" "$name"
        fi
        i=$((i+1))
    done <<< "$(model_names)"
}

model_menu() {
    # list the downloaded AIs numbered, mark the active one, and (with a real
    # terminal) let you pick one as the permanent default.
    local choice sel
    [ -z "$(model_names)" ] && { echo "$(t model_none)"; return; }
    echo "$(t model_avail)"
    model_list_tagged
    (exec 3</dev/tty) 2>/dev/null || return 0
    read -r -p "$(t model_pick)" choice < /dev/tty || return 0
    [ -z "$choice" ] && { echo "$(t model_kept)"; return 0; }
    sel=$(model_resolve "$choice") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; return 1; }
    set_model "$sel"
}

# ---- model management (v2.10): pull / update / rm + engine update ----
pull_running() {
    # $1 = model name -> echo "PID STATE" of an `ollama pull <name>` that is
    # ALREADY alive, and return 0; return 1 when there is none.
    # STATE is the first ps field: T = stopped (Ctrl+Z), R/S = running.
    # Why this exists: ollama serializes pulls of the SAME model. A client
    # suspended with Ctrl+Z stops reading its stream, the server keeps the
    # slot, and every later `ollama pull <same model>` hangs at "pulling
    # manifest" forever. We must see it BEFORE proposing a second download.
    local name="$1" pid st
    command -v pgrep >/dev/null 2>&1 || return 1
    for pid in $(pgrep -x -f "ollama pull $name" 2>/dev/null); do
        [ "$pid" = "$$" ] && continue
        st=$(ps -o stat= -p "$pid" 2>/dev/null | cut -c1)
        [ -n "$st" ] && { printf '%s %s\n' "$pid" "$st"; return 0; }
    done
    return 1
}

model_pull() {
    # $1 = model name -> download it with ollama (checks free RAM first);
    # on success, offers to make it the default (only with a real terminal)
    local name="$1" need_mb free_mb answer busy bpid bstate
    [ -z "$name" ] && { echo "$(t mp_usage)"; return 1; }
    # v2.18: a pull of this very model may already be in flight - most often
    # sitting suspended after a Ctrl+Z. Starting a second one would just hang
    # at "pulling manifest". Say so, and offer to clear it.
    if busy=$(pull_running "$name"); then
        bpid=${busy%% *}; bstate=${busy##* }
        echo -e "${YELLOW}$(t mp_busy)${NC} $name  (PID $bpid$( [ "$bstate" = T ] && echo ", $(t mp_busy_sus)" ))"
        echo "$(t mp_busy_why)"
        [ "$bstate" = T ] && echo "$(t mp_busy_fg)"
        if core_confirm "$(t mp_busy_kill)"; then
            # A STOPPED process cannot act on TERM until it runs again, so we
            # always follow with CONT - otherwise the signal just sits pending
            # and the download stays exactly where it was.
            show_equiv "kill $bpid && kill -CONT $bpid"
            kill "$bpid" 2>/dev/null
            kill -CONT "$bpid" 2>/dev/null
            sleep 1
            if kill -0 "$bpid" 2>/dev/null; then
                echo -e "${RED}$(t mp_busy_alive) $bpid${NC}" >&2
                return 1
            fi
            write_log "model pull: cleared stale pull" "$name (pid $bpid)"
            echo "$(t mp_resume)"
        else
            echo "$(t mp_busy_left)"
            return 1
        fi
    fi
    need_mb=$(ram_needed_mb "$name")
    free_mb=$(ram_free_mb)
    if [ -n "$free_mb" ] && [ "$free_mb" -lt "$need_mb" ]; then
        echo -e "${YELLOW}$(t low_ram)${NC} (~$((need_mb/1000)) GB)"
    fi
    echo -e "${BLUE}$(t proposed)${NC}${GREEN}ollama pull $name${NC}"
    # A GB-sized download is the one place where the user WILL reach for the
    # keyboard. Say what the two keys do before, not after (teaching pillar).
    [ -t 1 ] && echo -e "${YELLOW}$(t mp_keys)${NC}"
    if ollama pull "$name"; then
        echo -e "${GREEN}$(t mp_done) $name${NC}"
        write_log "model pull" "$name"
        (exec 3</dev/tty) 2>/dev/null || return 0
        read -r -p "$(t mp_default_q)" answer < /dev/tty || return 0
        case "${answer,,}" in "$YES_KEY") set_model "$name" ;; esac
    else
        echo -e "${RED}$(t mp_fail) $name${NC}" >&2
        return 1
    fi
}

model_pull_menu() {
    # `-m pull` with NO name: hardware check + numbered menu of models that
    # FIT this machine. Detection and catalog live in glia-hardware (-j / -l),
    # so the same list adapts by itself on every machine (v2.10).
    local hwjson ram gpu vram disk list n=0 name dl cat rec mark choice sel downloaded
    command -v glia-hardware >/dev/null 2>&1 || { echo "$(t mp_nohw)" >&2; echo "$(t mp_usage)"; return 1; }
    hwjson=$(glia-hardware -j 2>/dev/null)
    ram=$(sed -n 's/.*"ram_gb":\([0-9]*\).*/\1/p'       <<< "$hwjson")
    gpu=$(sed -n 's/.*"gpu_name":"\([^"]*\)".*/\1/p'    <<< "$hwjson")
    vram=$(sed -n 's/.*"gpu_vram_gb":\([0-9]*\).*/\1/p' <<< "$hwjson")
    disk=$(df -h --output=avail "$HOME" 2>/dev/null | tail -n1 | tr -d ' ')
    echo -e "${BLUE}$(t mp_machine)${NC} ${ram:-?} GB RAM · GPU: ${gpu:-?}$( [ "${vram:-0}" -gt 0 ] && echo " (${vram} GB VRAM)" ) · $(t mp_disk) ${disk:-?}"
    list=$(glia-hardware -l 2>/dev/null)
    [ -z "$list" ] && { echo "$(t model_none)"; return 1; }
    downloaded=$(model_names)
    echo "$(t mp_menu_title)"
    while IFS='|' read -r name dl cat rec; do
        n=$((n+1)); mark=""
        [ -n "$downloaded" ] && grep -Fxq "$name" <<< "$downloaded" && mark="✓"
        [ "$rec" = "1" ] && mark="${mark:+$mark }★"
        printf '  %2d) %-22s %5s GB  %-18s %s\n' "$n" "$name" "$dl" "$(t "cat_$cat")" "$mark"
    done <<< "$list"
    echo -e "  ${YELLOW}$(t mp_manual)${NC}"
    (exec 3</dev/tty) 2>/dev/null || return 0
    read -r -p "$(t mp_which)" choice < /dev/tty || return 0
    [ -z "$choice" ] && { echo "$(t cancelled)"; return 0; }
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        sel=$(printf '%s\n' "$list" | sed -n "${choice}p" | cut -d'|' -f1)
        [ -z "$sel" ] && { echo -e "${RED}$(t model_badsel)${NC}" >&2; return 1; }
    else
        sel="$choice"
    fi
    model_pull "$sel"
}

model_stop() {
    # $1 = number or name -> unload that model from RAM right now (v2.11)
    local name
    [ -z "${1:-}" ] && { echo "$(t mstop_usage)"; return 1; }
    name=$(model_resolve "$1") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; return 1; }
    echo -e "$(t mstop_doing) ${GREEN}ollama stop $name${NC}"
    mem_unload "$name"
    ollama ps
}

model_update() {
    # $1 empty = re-pull EVERY downloaded model (ollama has no 'update':
    # a pull on an existing model fetches the new version); $1 = n|name = only that one
    local list name i=0 total fails=0
    if [ -n "${1:-}" ]; then
        list=$(model_resolve "$1") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; return 1; }
    else
        list=$(model_names)
        [ -z "$list" ] && { echo "$(t model_none)"; return 1; }
    fi
    total=$(printf '%s\n' "$list" | wc -l)
    while IFS= read -r name; do
        i=$((i+1))
        echo -e "${BLUE}$(t mu_doing) ($i/$total):${NC} ${GREEN}ollama pull $name${NC}"
        ollama pull "$name" || { echo -e "${RED}$(t mp_fail) $name${NC}" >&2; fails=$((fails+1)); }
    done <<< "$list"
    write_log "model update" "$(printf '%s' "$list" | tr '\n' ' ')"
    [ "$fails" -eq 0 ] && echo -e "${GREEN}$(t mu_done)${NC}"
    return "$fails"
}

model_rm() {
    # $1 = number or name -> remove that model, after confirmation.
    # If it was the saved default, the config is cleared (falls back to default).
    local name answer active
    [ -z "${1:-}" ] && { echo "$(t mr_usage)"; return 1; }
    name=$(model_resolve "$1") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; return 1; }
    echo -e "${YELLOW}$(t mr_confirm)${NC} ${GREEN}ollama rm $name${NC}"
    (exec 3</dev/tty) 2>/dev/null || { echo "$(t cancelled)"; return 1; }
    read -r -p "[$YES_KEY/N]: " answer < /dev/tty || return 1
    case "${answer,,}" in "$YES_KEY") : ;; *) echo "$(t cancelled)"; return 0 ;; esac
    ollama rm "$name" || return 1
    echo -e "${GREEN}$(t mr_removed) $name${NC}"
    write_log "model rm" "$name"
    active="${MODEL#ollama:}"
    if [ "$name" = "$active" ]; then
        rm -f "$HOME/.config/glia/model"
        echo -e "${YELLOW}$(t mr_wasdefault)${NC}"
    fi
}

engine_update() {
    # update the Ollama ENGINE itself, distro-aware: pacman repo on
    # Arch/CachyOS, the official install script elsewhere (Debian/Fedora
    # have no ollama in their official repos). Always asks before running.
    local ver cmd answer
    if ! command -v ollama >/dev/null 2>&1; then
        echo -e "${RED}$(t eng_noollama)${NC}" >&2
        return 1
    fi
    ver=$(ollama --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)
    echo -e "${BLUE}$(t eng_current)${NC} ${ver:-?}   (${OS_NAME:-Linux}, ${PKGMGR:-?})"
    if [ "$PKGMGR" = "pacman" ]; then
        cmd="sudo pacman -Syu ollama"      # full sync: no partial upgrades on Arch
    else
        cmd="curl -fsSL https://ollama.com/install.sh | sh"   # official installer/updater
    fi
    echo -e "$(t eng_cmd) ${GREEN}$cmd${NC}"
    (exec 3</dev/tty) 2>/dev/null || { echo "$(t cancelled)"; return 1; }
    read -r -p "$(t eng_confirm)" answer < /dev/tty || return 1
    case "${answer,,}" in ""|"$YES_KEY") : ;; *) echo "$(t cancelled)"; return 0 ;; esac
    if eval "$cmd"; then
        write_log "engine update" "$cmd"
        # the running SERVICE keeps the old version until restarted (v2.11)
        if command -v systemctl >/dev/null 2>&1; then
            echo -e "$(t eng_restart) ${GREEN}sudo systemctl restart ollama${NC}"
            sudo systemctl restart ollama 2>/dev/null || true
        fi
        ollama --version
    else
        return 1
    fi
}

