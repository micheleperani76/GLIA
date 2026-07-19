# ============================================================
#  Model RAM swap (v2.14): ONE mechanism reused by the -m one-off
#  AND by -w. "Swap only if needed": unload the active AI only when the
#  free RAM is not enough for both; always restore the default afterwards.
# ============================================================
# ram_free_mb: the ONE place that reads the free RAM (v2.21). It was born here
# in v2.14 and stayed a local habit: four other spots had already written the
# same awk by hand and never learned about it. Same truth in five copies is how
# D2 started, so now they all call this - and a test can finally fake the RAM
# by redefining one function instead of mocking /proc.
ram_free_mb() { awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null; }
model_loaded() { curl -fsS --max-time 2 "$OLLAMA_URL/api/ps" 2>/dev/null | grep -q "\"$1\""; }

# model_size_mb <name> -> approx RAM need in MB, read from `ollama list` SIZE
# (weights on disk ~= RAM), with a small overhead; falls back to the heuristic.
model_size_mb() {
    local n="$1" row val unit
    row=$(ollama list 2>/dev/null | awk -v m="$n" '$1==m {print $3" "$4; exit}')
    if [ -n "$row" ]; then
        val=${row% *}; unit=${row#* }
        case "$unit" in
            GB|gb) awk -v s="$val" 'BEGIN{printf "%d", s*1024 + 1200}' ;;
            MB|mb) awk -v s="$val" 'BEGIN{printf "%d", s + 1200}' ;;
            *)     ram_needed_mb "$n" ;;
        esac
    else
        ram_needed_mb "$n"
    fi
}

SWAP_STOPPED=""
# swap_in <target> <default>: always unload the default so only ONE AI is in RAM.
swap_in() {
    local target="$1" def="$2"
    SWAP_STOPPED=""
    [ "$target" = "$def" ] && return 0
    # single-model policy (v2.15.1): only ONE AI is ever kept in RAM. When a
    # guest AI is needed, the default is ALWAYS unloaded first — even if there
    # would be room for both — so memory holds exactly one model at a time.
    # The default is reloaded/kept warm afterwards by swap_out.
    if model_loaded "$def"; then
        echo -e "$(t ms_unload) ${GREEN}ollama stop $def${NC}" >&2
        mem_unload "$def"
        SWAP_STOPPED="$def"
    fi
    # v2.15.4: say WHICH AI we are loading for this task; v2.16: preload it now
    # with a visible spinner, so the silent cold load doesn't look like a hang.
    echo -e "$(t ms_load) ${GREEN}ollama run $target${NC}" >&2
    spin_run "$(t ms_loading) $target" mem_warm "$target"
}
# swap_out <target> <default>: free the guest; bring the default back ONLY if
# WE were the ones who unloaded it (SWAP_STOPPED). If you had stopped the
# default yourself, we respect that and leave it off (v2.15.5).
swap_out() {
    local target="$1" def="$2"
    [ "$target" = "$def" ] && return 0
    mem_unload "$target"                 # free the guest either way
    if [ "$SWAP_STOPPED" = "$def" ]; then
        echo -e "$(t ms_reload) ${GREEN}ollama run $def${NC}" >&2
        spin_run "$(t ms_loading) $def" mem_warm "$def"
    fi
    SWAP_STOPPED=""
}

# which AI answers -w:  inline -m override  >  pinned web model  >  default
web_target() {
    if [ -n "${WEB_OVERRIDE:-}" ]; then printf '%s' "$WEB_OVERRIDE"; return; fi
    local pin; pin="$(head -n1 "$WEBMODELFILE" 2>/dev/null)"
    [ -n "$pin" ] && { printf '%s' "$pin"; return; }
    printf '%s' "${MODEL#ollama:}"
}

