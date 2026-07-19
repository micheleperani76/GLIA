# ---------------- PROJECT MODE ----------------------
MSGS='[]'
add_msg() {
    MSGS=$(jq -c --arg r "$1" --arg c "$2" '. + [{"role":$r,"content":$c}]' <<< "$MSGS")
}

chat() {
    # $1 = "json" to force JSON output. Prints the reply, appends it to MSGS.
    local body reply
    body="{\"model\":\"${MODEL#ollama:}\",\"messages\":$MSGS,\"stream\":false"
    [ "$1" = "json" ] && body="$body,\"format\":\"json\""
    body="$body}"
    reply=$(curl -fsS --max-time 600 "$OLLAMA_URL/api/chat" -d "$body" 2>/dev/null | jq -r '.message.content // empty' | strip_think)
    [ -z "$reply" ] && return 1
    add_msg assistant "$reply"
    printf '%s' "$reply"
}

safe_relpath() {
    case "$1" in
        ""|/*|*..*|*'~'*|*'$'*) return 1 ;;
        *) return 0 ;;
    esac
}

strip_fences() {
    sed 's/^```[a-zA-Z]*$//; s/^```$//' | sed '/./,$!d'
}

# newmode_check_content <relpath> <content>: objective checks on generated
# content (v2.18). GLIA knows facts the model ignores: a Markdown file must
# not start with a shebang. Only facts get checked, never opinions; any
# extension without a real check passes (better nothing than a fake check).
# Sets NEW_CHECK_ERR (English: it is fed back to the model) on failure.
NEW_CHECK_ERR=""
newmode_check_content() {
    local path="$1" content="$2" first err
    NEW_CHECK_ERR=""
    first=$(head -n1 <<< "$content")
    case "$path" in
        *.md|*.txt|*.rst)
            if [ "${first#\#!}" != "$first" ]; then
                NEW_CHECK_ERR="the file starts with a shebang ('$first') but '$path' must be plain documentation, not a script"
                return 1
            fi
            if [ "${path%.md}" != "$path" ] && ! grep -qE '^#{1,6} ' <<< "$content"; then
                NEW_CHECK_ERR="the file contains no Markdown heading (a line starting with '# '): it does not look like Markdown"
                return 1
            fi
            ;;
        *.sh)
            if ! err=$(bash -n <<< "$content" 2>&1); then
                NEW_CHECK_ERR="bash -n rejects it: $(head -n2 <<< "$err" | tr '\n' ' ')"
                return 1
            fi
            ;;
    esac
    return 0
}

strip_leaked_plan() {
    # safety net: if the model echoed the JSON plan before the real
    # content, drop everything up to (and including) the closing brace
    local content
    content=$(cat)
    if head -n1 <<< "$content" | grep -qE '^[[:space:]]*\{' \
       && head -n 40 <<< "$content" | grep -q '"project_name"'; then
        sed '1,/^[[:space:]]*}[[:space:]]*$/d' <<< "$content" | sed '/./,$!d'
    else
        printf '%s\n' "$content"
    fi
}

project_mode() {
    local REQUEST="$*"
    command -v jq >/dev/null || { echo "$(t need_jq)" >&2; exit 1; }
    check_ai

    # v2.15: run projects on the dedicated coding AI (if pinned), with the
    # SAME shared RAM swap as -w / one-off -m. PROJ_* are GLOBAL on purpose:
    # the EXIT trap must still see them if any 'exit' fires inside this
    # function, AND when the script ends normally after project_mode returns.
    PROJ_DEF="${MODEL#ollama:}"
    PROJ_TARGET="$(project_target)"
    if [ "$PROJ_TARGET" != "$PROJ_DEF" ]; then
        echo -e "${BLUE}$(t pm_using) ${GREEN}$PROJ_TARGET${NC}"
        swap_in "$PROJ_TARGET" "$PROJ_DEF"
        MODEL="ollama:$PROJ_TARGET"           # this run only; default file untouched
        trap 'swap_out "$PROJ_TARGET" "$PROJ_DEF"' EXIT
    fi

    # ---- plan phase: same guided-hint procedure as the fix loop (v2.4).
    # Enter = proceed, n = cancel, any other text = a hint for the AI: the
    # plan is redone with it. Hints accumulate across attempts (v2.8).
    # On a redo the model REVISES the previous plan (it gets it back) instead
    # of starting over: small models otherwise latch onto the hint and drop
    # files the original request asked for.
    local PLAN NAME NFILES A PLAN_HINTS="" PREV_PLAN=""
    while true; do
        echo -e "${YELLOW}$(t planning)${NC}"
        MSGS='[]'
        add_msg system "You are the GLIA project agent. You plan small software or document projects and then write their files. Always reply in the exact format requested. Keep projects small and practical. Target machine: ${OS_NAME:-Linux}${PKGMGR:+, package manager: $PKGMGR (use it in any install command, never one from other distros)}."
        add_msg user "Project request: ${REQUEST}. ${PREV_PLAN:+You already proposed this plan: $PREV_PLAN. }${PLAN_HINTS:+The user refines it with this extra context (follow it closely, but KEEP satisfying the original request IN FULL: never drop files or parts the request asks for): $PLAN_HINTS. }Reply ONLY with JSON in this exact shape: {\"project_name\":\"short-kebab-case-name\",\"files\":[{\"path\":\"relative/path.ext\",\"description\":\"what this file contains\"}]}. Between 1 and 8 files. File paths are relative to the project root: NEVER wrap them in a top-level folder named after the project (write \"backup.sh\", not \"my-project/backup.sh\"). Write the descriptions in ${PLAN_LANG}. No other text."

        PLAN=$(chat json) || { echo -e "${RED}$(t plan_fail)${NC}"; exit 1; }
        NAME=$(jq -r '.project_name // empty' <<< "$PLAN" 2>/dev/null | tr -cd 'a-zA-Z0-9_-' | cut -c1-40)
        NFILES=$(jq -r '.files | length' <<< "$PLAN" 2>/dev/null)
        if [ -z "$NAME" ] || [ -z "$NFILES" ] || [ "$NFILES" = "0" ]; then
            echo -e "${RED}$(t plan_fail)${NC}"; exit 1
        fi

        echo
        echo -e "${BLUE}=== $(t plan): $NAME ===${NC}"
        echo -e "${YELLOW}$(t steps)${NC}"
        # v2.18: steps are derived mechanically from the file list, never asked
        # to the model. What the model does not invent, it cannot get wrong.
        jq -r --arg c "$(t step_create)" '.files[] | "\($c) \(.path) - \(.description)"' <<< "$PLAN" | nl -w2 -s'. '
        echo -e "${YELLOW}$(t files)${NC}"
        jq -r '.files[] | "  \(.path)  -  \(.description)"' <<< "$PLAN"
        echo
        read -r -p "$(t go)" A < /dev/tty || exit 1
        case "$A" in
            "")   break ;;
            n|N)  echo "$(t cancelled)"; exit 0 ;;
            *)    PLAN_HINTS="${PLAN_HINTS:+$PLAN_HINTS; }$A"
                  PREV_PLAN="$PLAN" ;;   # revise the previous plan with the hint
        esac
    done

    # v2.12.3: projects go into the assistant's dedicated folder
    # ~/<name>/projects (PROJBASE). The 'glia' anchor has no dedicated folder
    # (PROJBASE empty), so it keeps the v2.9 behaviour: the project is created
    # WHERE YOU ARE ($PWD), leaving the ~/glia repo untouched.
    # Never write into an existing folder - if the name is taken, pick the
    # first free one (<name>-2, <name>-3, ...).
    local BASE PROJDIR n
    if [ -n "$PROJBASE" ]; then
        BASE="$PROJBASE"                       # dedicated folder ~/<name>/projects
        mkdir -p "$BASE" 2>/dev/null
        [ -w "$BASE" ] || BASE="$PWD"          # fallback if it can't be used
    else
        BASE="$PWD"                            # anchor 'glia': projects where you are
        [ -w "$BASE" ] || BASE="$HOME"
    fi
    PROJDIR="$BASE/$NAME"
    if [ -e "$PROJDIR" ]; then
        n=2
        while [ -e "$BASE/$NAME-$n" ]; do n=$((n+1)); done
        PROJDIR="$BASE/$NAME-$n"
    fi
    echo -e "${BLUE}$(t proj_dir)${NC} ${PROJDIR/#$HOME/\~}"
    show_equiv "mkdir -p ${PROJDIR/#$HOME/\~}"
    mkdir -p "$PROJDIR"
    write_log "PROJECT START" "$NAME | $REQUEST"

    # Fresh conversation for the writing phase: the JSON plan stays out
    # of the context, so the model does not echo it into the files.
    # v2.18: the context is REBUILT from scratch for EVERY generation (same
    # form as pmode_rewrite_fallback). Files already saved go back in as
    # reference material inside the user message, never as assistant turns:
    # a model continues its own pattern, so a file left in the history as
    # the model's own words primes the next file into the same shape (a
    # README asked after a script came out as a second script). Rebuilding
    # also keeps the context from growing on every regeneration.
    local FILELIST WRITTEN=""
    FILELIST=$(jq -r '.files[] | "- \(.path): \(.description)"' <<< "$PLAN")

    # per-file loop: at the save prompt, typed text = a hint for the AI and
    # the file is regenerated following it (same procedure as the fix loop);
    # hints accumulate per file and reset on the next file (v2.8)
    local i=0 FPATH FDESC CONTENT LINES FILE_HINTS CHECK_TRIES CHECK_FB CHECK_WARN
    while [ "$i" -lt "$NFILES" ]; do
        FPATH=$(jq -r ".files[$i].path" <<< "$PLAN")
        FPATH="${FPATH#./}"
        FDESC=$(jq -r ".files[$i].description" <<< "$PLAN")
        FILE_HINTS=""
        CHECK_TRIES=0 CHECK_FB="" CHECK_WARN=""
        i=$((i+1))
        if ! safe_relpath "$FPATH"; then
            echo -e "${RED}$(t badpath) $FPATH${NC}"
            write_log "SKIPPED (unsafe path)" "$NAME/$FPATH"
            continue
        fi
        while true; do
            echo
            echo -e "${YELLOW}$(t writing) [$i/$NFILES]: ${NC}${GREEN}$FPATH${NC}"
            MSGS='[]'
            add_msg system "You are the GLIA project agent. You write complete, working files for a small project. Reply ONLY with raw file content: no explanations, no markdown fences, no JSON. Target machine: ${OS_NAME:-Linux}${PKGMGR:+, package manager: $PKGMGR (use it in any install command, never one from other distros)}."
            add_msg user "Project: $NAME. Request: $REQUEST.${PLAN_HINTS:+ Extra context from the user (follow it closely): $PLAN_HINTS.} Files of the project: $FILELIST.${WRITTEN:+ The following files are ALREADY WRITTEN. They are reference material only: do not write them again.$WRITTEN} Now write the COMPLETE content of the file '$FPATH' ($FDESC).${FILE_HINTS:+ The user adds this guidance (follow it closely): $FILE_HINTS.}${CHECK_FB:+ Your previous attempt was rejected by an automatic check: $CHECK_FB. Write the file again and fix exactly this.} Reply ONLY with the raw content of '$FPATH'. No explanations, no markdown fences."
            CONTENT=$(chat) || { echo -e "${RED}$(t plan_fail)${NC}"; break; }
            CONTENT=$(strip_fences <<< "$CONTENT" | strip_leaked_plan)
            # v2.18: verify instead of hoping. Same retry ladder as -p:
            # retry with the error explained, then be honest about it.
            if ! newmode_check_content "$FPATH" "$CONTENT"; then
                CHECK_TRIES=$((CHECK_TRIES+1))
                if [ "$CHECK_TRIES" -le "$PMODE_MAX_RETRIES" ]; then
                    echo -e "${YELLOW}$(t new_check_retry) $CHECK_TRIES/$PMODE_MAX_RETRIES: $NEW_CHECK_ERR${NC}"
                    write_log "CHECK RETRY $CHECK_TRIES" "$NAME/$FPATH | $NEW_CHECK_ERR"
                    CHECK_FB="$NEW_CHECK_ERR"
                    continue
                fi
                CHECK_WARN="$NEW_CHECK_ERR"
            else
                CHECK_WARN="" CHECK_FB=""
            fi
            echo -e "${BLUE}$(t preview)${NC}"
            head -n 20 <<< "$CONTENT"
            LINES=$(wc -l <<< "$CONTENT")
            echo -e "${BLUE}--- ($LINES lines) ---${NC}"
            [ -n "$CHECK_WARN" ] && echo -e "${RED}$(t new_check_warn) $CHECK_WARN${NC}"
            read -r -p "$(t save)" A < /dev/tty || A="s"
            if [ "$A" = "v" ] || [ "$A" = "V" ]; then
                echo "$CONTENT" | less
                read -r -p "$(t save)" A < /dev/tty || A="s"
            fi
            case "$A" in
                "")
                    mkdir -p "$PROJDIR/$(dirname "$FPATH")"
                    printf '%s\n' "$CONTENT" > "$PROJDIR/$FPATH"
                    echo -e "${GREEN}$(t saved) $PROJDIR/$FPATH${NC}"
                    if [ -n "$CHECK_WARN" ]; then
                        echo -e "${RED}$(t new_check_saved)${NC}"
                        write_log "SAVED WITH WARNING" "$NAME/$FPATH ($LINES lines) | $CHECK_WARN"
                    else
                        write_log "SAVED" "$NAME/$FPATH ($LINES lines)"
                    fi
                    # saved file becomes reference material for the next ones
                    WRITTEN="$WRITTEN
--- $FPATH (already written) ---
$CONTENT
--- end of $FPATH ---"
                    break ;;
                r|R) continue ;;
                s|S) echo "$(t skipped)"; write_log "SKIPPED" "$NAME/$FPATH"; break ;;
                *)   FILE_HINTS="${FILE_HINTS:+$FILE_HINTS; }$A"; continue ;;   # regenerate with the hint
            esac
        done
    done

    echo
    echo -e "${GREEN}$(t proj_done) $PROJDIR${NC}"
    find "$PROJDIR" -type f | sed "s|$PROJDIR/|  |"
    write_log "PROJECT END" "$NAME"
}

