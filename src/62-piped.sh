# ---- piped input as context (v2.7) ----
# cat error.log | glia why does this fail   -> the piped text goes to the AI.
# Read only when stdin is NOT a terminal, and only in the request paths
# (never in interactive mode, which reads its requests from stdin).
PIPED=""
read_piped() {
    [ -t 0 ] && return 0
    PIPED="$(head -c 4000 2>/dev/null | head -n 40)"
}

piped_context() {
    [ -n "$PIPED" ] && printf 'The user piped this input (treat it as the data/context of the request): <<<%s>>>. ' "$PIPED"
}

AI_ERR=""
generate_command() {
    # "look before acting": the model sees where we are and what is here
    local errfile out ctx
    ctx="$CONTEXT $(memory_context)$(session_context)$(piped_context)Current directory: $PWD. It contains: $(ls -1 2>/dev/null | head -n 15 | paste -sd ', ' -)."
    errfile=$(mktemp)
    out=$(aichat --model "$MODEL" "$ctx Request: $*$(nothink)" < /dev/null 2>"$errfile" \
        | strip_think \
        | sed 's/^```[a-z]*//; s/```$//' \
        | grep -v '^\s*$' \
        | head -n 1)
    AI_ERR=$(tail -n 3 "$errfile" 2>/dev/null)
    rm -f "$errfile"
    echo "$out"
}

strip_think() {
    # reasoning models (qwen3, deepseek-r1, ...) may emit their reasoning
    # inside <think>...</think> BEFORE the real answer: drop the whole
    # block, keep only what comes after (v2.11)
    awk '/<think>/{skip=1} /<\/think>/{skip=0; next} !skip'
}

nothink() {
    # qwen3 honors the /no_think switch: skip the reasoning phase entirely.
    # A shell command needs the answer, not the thoughts (faster, no tags).
    case "${MODEL#ollama:}" in qwen3*) printf ' /no_think' ;; esac
}

CMD_ERR=""
run_command() {
    # runs the command; stderr is shown live AND captured for the fix loop.
    # $2 (optional) = the original request, logged next to the command (v2.7)
    local cmd="$1" errf status
    errf=$(mktemp)
    bash -c "set -o pipefail; $cmd" 2> >(tee "$errf" >&2)
    status=$?
    CMD_ERR=$(tail -n 5 "$errf" 2>/dev/null)
    rm -f "$errf"
    write_log "EXECUTED (exit=$status)" "$cmd${2:+   <- $2}"
    return $status
}

edit_command() {
    # let the user edit $1 in place (readline, prefilled); prints the result.
    # empty result = keep the original (caller treats it as "no change").
    local edited
    echo -e "${BLUE}$(t edit_cmd)${NC}" >&2
    # v2.11: redirect from /dev/tty ONLY when stdin is not a terminal -
    # readline + /dev/tty redirect stops the job under fish
    if [ -t 0 ]; then
        IFS= read -r -e -i "$1" edited || edited="$1"
    else
        IFS= read -r -e -i "$1" edited < /dev/tty || edited="$1"
    fi
    printf '%s' "${edited:-$1}"
}

propose_and_run() {
    local original="$*" request="$*" cmd answer status fixes=0 expl use_cache=1 from_cache hints=""
    while true; do
        from_cache=0
        if [ "$use_cache" -eq 1 ] && [ "$fixes" -eq 0 ]; then
            cmd=$(cache_lookup "$original")
            [ -n "$cmd" ] && from_cache=1
        fi
        if [ "$from_cache" -eq 0 ]; then
            echo -e "${YELLOW}$(t thinking)${NC}" >&2
            cmd=$(generate_command "$request")
        fi
        if [ -z "$cmd" ]; then
            echo -e "${RED}$(t no_command)${NC}" >&2
            if [ -n "$AI_ERR" ]; then
                echo -e "${RED}$(t model_error)${NC}" >&2
                echo "$AI_ERR" >&2
            fi
            return 1
        fi
        # deterministic privilege fix: add sudo where root is required (no AI call)
        cmd=$(maybe_sudo "$cmd")
        # ---- inner loop: show + confirm; 'm' edits the command in place and
        #      re-checks it (an edit can add or remove danger), 'e' explains
        #      it on demand; both come back here without a new AI generation.
        while true; do
            echo
            if [ "$from_cache" -eq 1 ]; then
                echo -e "$(t proposed) ${GREEN}$cmd${NC} ${BLUE}$(t cache_hit)${NC}"
            else
                echo -e "$(t proposed) ${GREEN}$cmd${NC}"
            fi
            if is_reboot_cmd "$cmd"; then
                echo -e "${RED}$(t warn)${NC}"
                read -r -p "$(t ask_reboot)" answer < /dev/tty \
                    || { write_log "CANCELLED (no tty)" "$cmd"; echo "$(t cancelled)"; return; }
                case "${answer,,}" in
                    "$YES_KEY") break ;;
                    r) use_cache=0; continue 2 ;;
                    m) cmd=$(edit_command "$cmd"); from_cache=0; continue ;;
                    *)   write_log "CANCELLED" "$cmd"; echo "$(t cancelled)"; return ;;
                esac
            elif needs_extra_confirm "$cmd"; then
                echo -e "${RED}$(t warn)${NC}"
                echo -e "${YELLOW}$(t explaining)${NC}" >&2
                expl=$(explain_danger "$cmd")
                [ -n "$expl" ] && echo -e "${BLUE}➜ $expl${NC}"
                read -r -p "$(t ask_danger)" answer < /dev/tty \
                    || { write_log "CANCELLED (no tty)" "$cmd"; echo "$(t cancelled)"; return; }
                case "${answer,,}" in
                    "$YES_KEY") break ;;
                    r) use_cache=0; continue 2 ;;
                    m) cmd=$(edit_command "$cmd"); from_cache=0; continue ;;
                    *)   write_log "CANCELLED" "$cmd"; echo "$(t cancelled)"; return ;;
                esac
            else
                read -r -p "$(t ask_normal)" answer < /dev/tty \
                    || { write_log "CANCELLED (no tty)" "$cmd"; echo "$(t cancelled)"; return; }
                case "$answer" in
                    "")  break ;;
                    r|R) use_cache=0; continue 2 ;;
                    m|M) cmd=$(edit_command "$cmd"); from_cache=0; continue ;;
                    e|E) echo -e "${YELLOW}$(t explaining)${NC}" >&2
                         expl=$(explain_danger "$cmd")
                         [ -n "$expl" ] && echo -e "${BLUE}➜ $expl${NC}"
                         continue ;;
                    ?)   write_log "CANCELLED" "$cmd"; echo "$(t cancelled)"; return ;;
                    *)   # longer text = a hint (v2.11): refine the proposal with
                         # it, same accumulating mechanism as the fix loop
                         hints="${hints:+$hints; }$answer"
                         request="Original request: $original. You proposed '$cmd' but the user added context: $hints. Using it, propose a better single-line bash command for the original request."
                         use_cache=0
                         continue 2 ;;
                esac
            fi
        done

        # ---- execute; on failure, learn from the error (up to 5 fixes; the
        #      user can type an extra hint that is fed back to the AI) ----
        session_add "$original" "$cmd"
        run_command "$cmd" "$original"
        status=$?
        if [ "$status" -eq 0 ]; then
            cache_store "$original" "$cmd"
            save_last "$original" "$cmd"
            maybe_propose_alias "$original" "$cmd"
            return 0
        fi
        if [ "$fixes" -ge 5 ]; then
            return "$status"
        fi
        echo -e "${RED}$(t cmd_failed) (exit $status).${NC}"
        # D4 (v2.19.3): if this is one of the errors we KNOW, say the truth
        # BEFORE the AI gets asked for a fix. On these, the model is not a
        # neutral helper: it read the same forums, and the popular answer is a
        # permanent security downgrade. We explain and still offer the fix
        # prompt below - inform, don't decide.
        local kid
        if kid="$(known_error "${CMD_ERR:-}")"; then
            known_error_say "$kid"
            write_log "known error" "$kid"
        fi
        read -r -p "$(t ask_fix)" answer < /dev/tty || return "$status"
        case "${answer,,}" in
            n|no) return "$status" ;;
        esac
        # Enter (empty) = plain fix; any other text = an extra hint for the AI.
        # Hints accumulate, so earlier clues are kept while we refine.
        [ -n "$answer" ] && hints="${hints:+$hints; }$answer"
        fixes=$((fixes+1))
        request="Original request: $original. The command '$cmd' failed with exit code $status and this error: ${CMD_ERR:-unknown}.${hints:+ Extra context from the user: $hints.} Use all of the above to propose a corrected single-line bash command."
        continue
    done
}

