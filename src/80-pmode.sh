# ============================================================
#  PROJECT MODE v2 (-p): edit files that ALREADY EXIST (v2.18, Part A)
#
#  Pipeline: read the file -> ask the AI for search/replace blocks -> apply them
#  to a TEMP copy -> WE compute the real unified diff -> show the diff and the
#  exact `git apply` command -> touch the file only on an explicit yes.
#
#  Why search/replace and not a diff straight from the model: a 7B model gets
#  line numbers and context lines wrong, so `git apply` would fail constantly.
#  Blocks it gets right most of the time; the diff we compute ourselves is
#  therefore always authentic and always applies cleanly.
#
#  The AI is the SAME dedicated coding model as --new: project_target() +
#  swap_in/swap_out, exactly as project_mode does. No second selection path.
# ============================================================

# pmode_log <event> <detail>: timestamped line in PMODE_LOG. Its own log, so the
# history of code edits stays readable and separate from the command log.
pmode_log() {
    mkdir -p "$(dirname "$PMODE_LOG")" 2>/dev/null || return 0
    printf '%s | %s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$PMODE_LOG"
}

# pmode_check_repo <dir>: -p needs a git work tree (that is the undo story).
# Not a repo -> explain, SHOW `git init`, ask. Dirty tree -> warn + extra
# confirm, never block. Returns 1 to abort the run.
pmode_check_repo() {
    local dir="$1" br
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        br="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"; [ -z "$br" ] && br="?"
        if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
            echo -e "${BLUE}[pmode]${NC} $(t pmv_repook) ($(t pmv_branch) $br)"
            echo -e "${YELLOW}$(t pmv_dirty)${NC}"
            core_show_cmd "git -C ${dir/#$HOME/\~} status --short"
            core_confirm "$(t pmv_dirtyask)" || { echo "$(t cancelled)"; return 1; }
        else
            echo -e "${BLUE}[pmode]${NC} $(t pmv_repook) ($(t pmv_branch) $br, $(t pmv_clean))"
        fi
        return 0
    fi
    echo -e "${YELLOW}$(t pmv_notrepo)${NC}"
    echo -e "$(t pmv_needgit)"
    core_show_cmd "cd ${dir/#$HOME/\~} && git init"
    if core_confirm "$(t pmv_initask)"; then
        git -C "$dir" init -q || return 1
        echo -e "${GREEN}$(t pmv_initdone)${NC}"
        pmode_log "GIT INIT" "$dir"
        core_log "PMODE GIT INIT" "$dir"
        return 0
    fi
    echo "$(t pmv_initno)"
    return 1
}

# pmode_collect_context <absfile...>: read the target(s) and enforce ONE
# combined context budget. We REFUSE rather than truncate: a cut file breaks
# search/replace matching and yields edits that look right and are wrong.
# Token heuristic: bytes/4. Phase 3: with 2+ files the model-facing text gets
# '==== FILE: <rel> ====' separators; with ONE file it stays exactly as in
# Phase 1 (raw content - the tuned prompt is not disturbed).
# Fills: PMODE_ABS[] PMODE_RELS[] PMODE_TEXTS[] PMODE_MULTI PMODE_FILE_TEXT
#        PMODE_FILE_LINES PMODE_FILE_TOKENS
pmode_collect_context() {
    local f rel txt budget total=0 lines=0
    PMODE_ABS=(); PMODE_RELS=(); PMODE_TEXTS=(); PMODE_FILE_TEXT=""
    [ "$#" -gt 1 ] && PMODE_MULTI=1 || PMODE_MULTI=0
    for f in "$@"; do
        rel="${f#"$PMODE_TOP"/}"
        txt="$(cat "$f"; printf x)"; txt="${txt%x}"
        PMODE_ABS+=("$f"); PMODE_RELS+=("$rel"); PMODE_TEXTS+=("$txt")
        lines=$(( lines + $(wc -l < "$f") ))
        total=$(( total + $(wc -c < "$f") ))
        if [ "$PMODE_MULTI" = 1 ]; then
            PMODE_FILE_TEXT+="==== FILE: $rel ===="$'\n'"$txt"$'\n'
        else
            PMODE_FILE_TEXT="$txt"
        fi
    done
    PMODE_FILE_LINES="$lines"
    PMODE_FILE_TOKENS=$(( total / 4 ))
    budget=$(( PMODE_NUM_CTX - PMODE_CTX_RESERVE ))
    if [ "$PMODE_FILE_TOKENS" -gt "$budget" ]; then
        echo -e "${RED}$(t pmv_toobig)${NC}" >&2
        echo -e "  ~$PMODE_FILE_TOKENS $(t pmv_tokens) > $budget $(t pmv_tokens)   (PMODE_NUM_CTX=$PMODE_NUM_CTX - PMODE_CTX_RESERVE=$PMODE_CTX_RESERVE)" >&2
        echo -e "${YELLOW}$(t pmv_toobig_hint)${NC}" >&2
        pmode_log "REFUSED (too large)" "${PMODE_RELS[*]} | ~$PMODE_FILE_TOKENS tokens > $budget"
        return 1
    fi
    return 0
}

# pmode_build_prompt <request>: fresh conversation + the system prompt that
# forces the S/R format. English on purpose: the model must reproduce these
# markers character-for-character. Phase 3: with 2+ files every block must
# carry a 'file:' header naming the target; empty SEARCH = append to that file.
# The single-file prompt is the Phase-1-tuned one, untouched.
pmode_build_prompt() {
    local req="$1" label
    MSGS='[]'
    if [ "$PMODE_MULTI" = 1 ]; then
        add_msg system "You are a code editor. You receive several files and a change request.
Reply ONLY with one or more edit blocks in exactly this format:
<<<<<<< SEARCH file: relative/path
(lines copied EXACTLY from that file, enough to be unique)
=======
(the replacement lines)
>>>>>>> REPLACE
Rules:
- EVERY block MUST name its file on the SEARCH line, exactly as written in
  the '==== FILE: ... ====' headers below. Never invent other files.
- SEARCH must be a CONTIGUOUS run of lines copied from that file: never join
  lines that are not next to each other, never leave lines out in between.
- Use ONE SEPARATE block for EACH place you change.
- Copy SEARCH lines character-for-character, including every space and tab.
- Keep SEARCH as short as possible while still unique in that file.
- An EMPTY SEARCH means: append the replacement lines at the end of that file.
- No explanations, no markdown fences, nothing outside the blocks."
        label="Files:"
    else
        add_msg system "You are a code editor. You receive a file and a change request.
Reply ONLY with one or more edit blocks in exactly this format:
<<<<<<< SEARCH
(lines copied EXACTLY from the file, enough to be unique)
=======
(the replacement lines)
>>>>>>> REPLACE
Rules:
- SEARCH must be a CONTIGUOUS run of lines copied from the file: never join
  lines that are not next to each other, never leave lines out in between.
- Use ONE SEPARATE block for EACH place you change.
- Copy SEARCH lines character-for-character, including every space and tab.
- Keep SEARCH as short as possible while still unique in the file.
- No explanations, no markdown fences, nothing outside the blocks."
        label="File: ${PMODE_RELS[0]##*/}"
    fi
    [ "$PMODE_MULTI" = 1 ] && label="Files: ${PMODE_RELS[*]}"
    add_msg user "$label
--- file content start ---
$PMODE_FILE_TEXT
--- file content end ---

Change request: $req"
}

# pmode_get_edit: ONE model call through the existing chat() wrapper (no second
# curl). The caller has already swapped the code model in.
pmode_get_edit() {
    local out
    echo -e "${YELLOW}$(t pmv_thinking)${NC}" >&2
    out="$(chat)" || return 1
    [ -z "$out" ] && return 1
    printf '%s' "$out"
}

# pmode_parse_blocks <raw>: fill PMODE_S[] / PMODE_R[] with the SEARCH and
# REPLACE bodies. Everything outside the markers is ignored on purpose: small
# models chatter. Returns 1 when there is no well-formed block at all.
pmode_parse_blocks() {
    local raw="$1" line state="out" cur_s="" cur_r="" cur_f="" hdr
    PMODE_S=(); PMODE_R=(); PMODE_F=()
    while IFS= read -r line; do
        case "$line" in
            '<<<<<<< SEARCH'*)
                # Phase 3: optional ' file: relative/path' on the marker line
                hdr="${line#<<<<<<< SEARCH}"; hdr="${hdr# }"
                case "$hdr" in
                    file:*) cur_f="${hdr#file:}"; cur_f="${cur_f# }"; cur_f="${cur_f%% }" ;;
                    *)      cur_f="" ;;
                esac
                state="search"; cur_s=""; cur_r=""; continue ;;
            '======='*)
                if [ "$state" = "search" ]; then state="replace"; continue; fi ;;
            '>>>>>>> REPLACE'*)
                if [ "$state" = "replace" ]; then
                    PMODE_S+=("$cur_s"); PMODE_R+=("$cur_r"); PMODE_F+=("$cur_f")
                    state="out"; continue
                fi ;;
        esac
        case "$state" in
            search)  cur_s+="$line"$'\n' ;;
            replace) cur_r+="$line"$'\n' ;;
        esac
    done <<< "$raw"
    [ "${#PMODE_S[@]}" -gt 0 ]
}

# pmode_count_occ <haystack> <needle>: literal (non-regex) occurrence count.
pmode_count_occ() {
    local rest="$1" needle="$2" cnt=0
    [ -z "$needle" ] && { printf 0; return; }
    while :; do
        case "$rest" in
            *"$needle"*) cnt=$((cnt+1)); rest="${rest#*"$needle"}" ;;
            *) break ;;
        esac
    done
    printf '%d' "$cnt"
}

# pmode_make_diff <patchfile>: apply the parsed blocks to TEMP copies of the
# context files, validate each SEARCH matches EXACTLY ONCE in ITS file (§1.1),
# then let git compute ONE combined unified diff (§5: git applies multi-file
# patches natively - one confirm, one apply, one commit). Sets PMODE_ERR on
# failure for the retry ladder. Never touches the originals.
# Phase 3 rules: with 2+ files every block needs a valid 'file:' header naming
# a file IN CONTEXT; an empty SEARCH appends to that file. With one file the
# header is optional and empty SEARCH is still rejected (Phase 1 behaviour).
pmode_make_diff() {
    local patch="$1"
    local i j s r n idx tmp rel
    local -a texts=()
    PMODE_ERR=""
    for j in "${!PMODE_TEXTS[@]}"; do texts[j]="${PMODE_TEXTS[j]}"; done
    for i in "${!PMODE_S[@]}"; do
        s="${PMODE_S[i]}"; r="${PMODE_R[i]}"
        # --- which file does this block target? ---
        if [ "$PMODE_MULTI" = 1 ]; then
            [ -z "${PMODE_F[i]}" ] && { PMODE_ERR="block $((i+1)): $(t pmv_nofilehdr)"; return 1; }
            idx=-1
            for j in "${!PMODE_RELS[@]}"; do
                [ "${PMODE_RELS[j]}" = "${PMODE_F[i]}" ] && { idx=$j; break; }
            done
            [ "$idx" -lt 0 ] && { PMODE_ERR="block $((i+1)): $(t pmv_badfile) (${PMODE_F[i]})"; return 1; }
        else
            idx=0
        fi
        # --- empty SEARCH: append (multi-file only, §5) ---
        if [ -z "${s//[$'\n\t ']/}" ]; then
            if [ "$PMODE_MULTI" = 1 ]; then
                [ -n "${texts[idx]}" ] && [ "${texts[idx]%$'\n'}" = "${texts[idx]}" ] \
                    && texts[idx]+=$'\n'
                texts[idx]+="$r"
                continue
            fi
            PMODE_ERR="block $((i+1)): $(t pmv_emptysearch)"; return 1
        fi
        n="$(pmode_count_occ "${texts[idx]}" "$s")"
        if [ "$n" -eq 0 ]; then
            # tolerate a missing final newline (last lines of the file)
            s="${s%$'\n'}"; r="${r%$'\n'}"
            n="$(pmode_count_occ "${texts[idx]}" "$s")"
        fi
        case "$n" in
            0) PMODE_ERR="block $((i+1)): $(t pmv_nomatch)"; return 1 ;;
            1) : ;;
            *) PMODE_ERR="block $((i+1)): $(t pmv_multimatch) ($n)"; return 1 ;;
        esac
        texts[idx]="${texts[idx]//"$s"/"$r"}"
    done
    # --- ONE combined patch: per-file real git diffs, concatenated ---
    : > "$patch"
    for j in "${!PMODE_RELS[@]}"; do
        [ "${texts[j]}" = "${PMODE_TEXTS[j]}" ] && continue
        rel="${PMODE_RELS[j]}"
        tmp="$(mktemp "${TMPDIR:-/tmp}/glia-pmode-new.XXXXXX")" || return 1
        printf '%s' "${texts[j]}" > "$tmp"
        # git diff --no-index exits 1 when files differ: the normal case.
        # Rewrite ONLY the 4 header lines to the real relative path so the
        # patch applies from the repo root; a removed body line could
        # legitimately start with '--- '.
        git diff --no-index --unified=3 -- "${PMODE_ABS[j]}" "$tmp" 2>/dev/null \
            | sed -e "1s|^diff --git .*|diff --git a/$rel b/$rel|" \
                  -e "1,4s|^--- .*|--- a/$rel|" \
                  -e "1,4s|^+++ .*|+++ b/$rel|" >> "$patch"
        rm -f "$tmp"
    done
    if [ ! -s "$patch" ]; then
        PMODE_ERR="$(t pmv_nodiff)"; return 1
    fi
    return 0
}

# pmode_show_diff <patchfile> <top>: colored diff + the exact git apply command.
# The teaching pillar: the command comes BEFORE the offer to run it.
pmode_show_diff() {
    local patch="$1" top="$2"
    echo
    echo -e "${BLUE}$(t pmv_proposed)${NC}"
    if command -v delta >/dev/null 2>&1; then delta < "$patch"
    else git -c color.diff=always diff --no-index /dev/null /dev/null >/dev/null 2>&1
         sed -e "s/^+.*/$(printf '\033[32m')&$(printf '\033[0m')/" \
             -e "s/^-.*/$(printf '\033[31m')&$(printf '\033[0m')/" \
             -e "s/^@@.*/$(printf '\033[36m')&$(printf '\033[0m')/" "$patch"
    fi
    echo
    echo -e "${YELLOW}$(t pmv_applyself)${NC}"
    echo -e "  ${GREEN}git -C ${top/#$HOME/\~} apply $patch${NC}"
}

# pmode_apply <top> <patchfile> <file>: --check first, then apply. A patch that
# does not pass --check is never applied: the tree stays exactly as it was.
pmode_apply() {
    local top="$1" patch="$2" f="$3"
    if ! git -C "$top" apply --check "$patch" 2>/dev/null; then
        echo -e "${RED}$(t pmv_checkfail)${NC}" >&2
        pmode_log "APPLY REFUSED (git apply --check failed)" "$f | $patch"
        return 1
    fi
    git -C "$top" apply "$patch" 2>/dev/null || {
        echo -e "${RED}$(t pmv_checkfail)${NC}" >&2
        pmode_log "APPLY FAILED" "$f | $patch"
        return 1
    }
    return 0
}

# pmode_commit <top> <request> <relfile...>: Phase 2 — offer an OPTIONAL local
# commit after a successful apply. Message prefixed 'glia-pmode: ' so undo can
# find it. Nothing is ever pushed; only the named files are staged.
pmode_commit() {
    local top="$1" req="$2"; shift 2
    local msg h
    msg="glia-pmode: ${req%%$'\n'*}"
    core_show_cmd "git -C ${top/#$HOME/\~} add $* && git commit -m \"$msg\""
    core_confirm "$(t pmv_commit_ask)" || { pmode_log "COMMIT DECLINED" "$*"; return 0; }
    git -C "$top" add -- "$@" && git -C "$top" commit -q -m "$msg" || return 1
    h="$(git -C "$top" rev-parse --short HEAD)"
    echo -e "${GREEN}$(t pmv_commit_done)${NC} $h  $msg"
    pmode_log "COMMIT" "$h | $msg | $*"
    core_log "PMODE COMMIT" "$h | $msg"
    return 0
}

# pmode_undo: `glia -p --undo`. Finds the most recent 'glia-pmode: ' commit.
# HEAD + clean tree -> git revert --no-edit HEAD (safe default), with
# reset --hard shown ONLY as the manual alternative. Not HEAD -> revert only,
# never reset (§4). Dirty tree -> warn + extra confirm, same as apply.
pmode_undo() {
    local dir top h subj head
    dir="$(pwd)"
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || { echo -e "${RED}$(t pmv_notrepo)${NC}" >&2; return 1; }
    top="$(git -C "$dir" rev-parse --show-toplevel)"
    h="$(git -C "$top" log --grep='^glia-pmode: ' -n1 --format=%H 2>/dev/null)"
    if [ -z "$h" ]; then
        echo -e "${YELLOW}$(t pmv_undo_none)${NC}"; return 0
    fi
    subj="$(git -C "$top" log -n1 --format=%s "$h")"
    head="$(git -C "$top" rev-parse HEAD)"
    echo -e "${BLUE}$(t pmv_undo_found)${NC} $(git -C "$top" rev-parse --short "$h")  $subj"
    if [ -n "$(git -C "$top" status --porcelain 2>/dev/null)" ]; then
        echo -e "${YELLOW}$(t pmv_dirty)${NC}"
        core_confirm "$(t pmv_dirtyask)" || { echo "$(t cancelled)"; return 1; }
    fi
    if [ "$h" = "$head" ]; then
        core_show_cmd "git -C ${top/#$HOME/\~} revert --no-edit HEAD"
        echo -e "${YELLOW}$(t pmv_undo_alt)${NC}  ${GREEN}git reset --hard HEAD~1${NC}"
    else
        echo -e "${YELLOW}$(t pmv_undo_nothead)${NC}"
        core_show_cmd "git -C ${top/#$HOME/\~} revert --no-edit $(git -C "$top" rev-parse --short "$h")"
    fi
    core_confirm "$(t pmv_undo_ask)" || { echo "$(t cancelled)"; return 0; }
    git -C "$top" revert --no-edit "$h" || {
        git -C "$top" revert --abort 2>/dev/null
        echo -e "${RED}$(t pmv_checkfail)${NC}" >&2
        pmode_log "UNDO FAILED" "$h"; return 1
    }
    echo -e "${GREEN}$(t pmv_undo_done)${NC}"
    pmode_log "UNDO" "reverted $h | $subj"
    core_log "PMODE UNDO" "reverted $h"
    return 0
}

# pmode_rewrite_fallback <file> <request>: §1.2 step 2. Blocks kept failing ->
# ask for the COMPLETE corrected file, but only when it fits in half the budget
# (the model must both read it and write it back). We still compute the diff.
pmode_rewrite_fallback() {
    local f="$1" req="$2" out tmp
    [ "$PMODE_FILE_TOKENS" -gt $(( PMODE_NUM_CTX / 2 )) ] && return 1
    echo -e "${YELLOW}$(t pmv_rewrite)${NC}" >&2
    MSGS='[]'
    add_msg system "You are a code editor. You receive a file and a change request. Reply ONLY with the complete corrected file content: no explanations, no markdown fences, nothing else."
    add_msg user "File: $(basename "$f")
--- file content start ---
$PMODE_FILE_TEXT
--- file content end ---

Change request: $req
Reply with the COMPLETE file after the change."
    out="$(pmode_get_edit)" || return 1
    out="$(strip_fences <<< "$out")"
    [ -z "${out//[$'\n\t ']/}" ] && return 1
    # one synthetic block: whole file -> whole file. Reuses the same diff path.
    PMODE_S=("$PMODE_FILE_TEXT"); PMODE_R=("$out"$'\n')
    return 0
}

# pmode_main <file...> <request...>: the -p entry point. Phase 3: leading args
# that are existing files become the context (1..N); everything after the last
# file is the request. Quoting the request stays the documented form; the
# fallthrough keeps Phase 1's unquoted usage working for a single file.
pmode_main() {
    local -a FILES=()
    local f req dir top t2 patch raw tries=0 rels

    while [ "$#" -gt 0 ] && [ -f "$1" ]; do FILES+=("$1"); shift; done
    req="$*"

    # -p edits EXISTING files. No auto-detect on purpose: a typo in a filename
    # would silently scaffold a whole project - a silent surprise, which is
    # exactly what GLIA must never do. Teach the right command instead.
    if [ "${#FILES[@]}" -eq 0 ]; then
        echo -e "${RED}$(t pmv_notafile)${NC}" >&2
        echo -e "  ${GREEN}$ASSIST_NAME --new <$(t pmv_idea)>${NC}" >&2
        echo -e "${YELLOW}$(t pmv_notafile_hint) ${1:-}${NC}" >&2
        return 1
    fi
    if [ -z "$req" ]; then
        echo -e "${RED}$(t pmv_norequest)${NC}" >&2
        echo -e "  ${GREEN}$ASSIST_NAME -p ${FILES[*]} \"<$(t pmv_request)>\"${NC}" >&2
        return 1
    fi
    for f in "${FILES[@]}"; do
        [ -r "$f" ] || { echo -e "${RED}$(t pmv_notreadable) $f${NC}" >&2; return 1; }
        # Binary check: a NUL byte, or file(1) calling the ENCODING binary. Do
        # NOT match the word "executable" from `file -b`: every script with a
        # shebang is "ASCII text executable" - that would refuse the main use case.
        if [ -s "$f" ] && { LC_ALL=C grep -qP '\x00' "$f" 2>/dev/null \
             || [ "$(file --mime-encoding -b "$f" 2>/dev/null)" = "binary" ]; }; then
            echo -e "${RED}$(t pmv_binary)${NC}" >&2
            pmode_log "REFUSED (binary)" "$f"
            return 1
        fi
    done
    command -v git >/dev/null || { echo -e "${RED}$(pkg_install_cmd git)${NC}" >&2; return 1; }
    command -v jq  >/dev/null || { echo "$(t need_jq)" >&2; return 1; }
    check_ai

    local i
    for i in "${!FILES[@]}"; do FILES[i]="$(realpath "${FILES[i]}")"; done
    dir="$(dirname "${FILES[0]}")"
    pmode_check_repo "$dir" || return 1
    top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
    for f in "${FILES[@]}"; do
        t2="$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null)"
        if [ "$t2" != "$top" ]; then
            echo -e "${RED}$(t pmv_sametree)${NC}" >&2
            echo -e "  $top  <->  ${t2:-?}  ($f)" >&2
            return 1
        fi
    done
    PMODE_TOP="$top"

    pmode_collect_context "${FILES[@]}" || return 1
    rels="${PMODE_RELS[*]}"

    # Same dedicated coding AI as --new, same shared RAM swap (v2.15 machinery).
    # PROJ_* are GLOBAL on purpose: the EXIT trap must still see them.
    PROJ_DEF="${MODEL#ollama:}"
    PROJ_TARGET="$(project_target)"
    if [ "$PROJ_TARGET" != "$PROJ_DEF" ]; then
        echo -e "${BLUE}$(t pm_using) ${GREEN}$PROJ_TARGET${NC}"
        swap_in "$PROJ_TARGET" "$PROJ_DEF"
        MODEL="ollama:$PROJ_TARGET"
        trap 'swap_out "$PROJ_TARGET" "$PROJ_DEF"' EXIT
    fi

    echo -e "${BLUE}[pmode]${NC} $(t pmv_sending) $rels ($PMODE_FILE_LINES $(t pmv_lines), ~$PMODE_FILE_TOKENS $(t pmv_tokens)) -> ${GREEN}$PROJ_TARGET${NC}"
    pmode_log "START" "$rels | $req | model=$PROJ_TARGET | ~$PMODE_FILE_TOKENS tokens"

    patch="$(mktemp "${TMPDIR:-/tmp}/glia-pmode-XXXXXX.patch")" || return 1
    pmode_build_prompt "$req"

    while :; do
        raw="$(pmode_get_edit)" || raw=""
        if [ -z "$raw" ]; then
            echo -e "${RED}$(t pmv_noreply)${NC}" >&2
            pmode_log "GIVE UP (no reply)" "$rels"
            rm -f "$patch"; return 1
        fi
        if pmode_parse_blocks "$raw" && pmode_make_diff "$patch"; then
            break
        fi
        [ -z "$PMODE_ERR" ] && PMODE_ERR="$(t pmv_noblocks)"
        tries=$((tries+1))
        if [ "$tries" -le "$PMODE_MAX_RETRIES" ]; then
            echo -e "${YELLOW}$(t pmv_retry) $tries/$PMODE_MAX_RETRIES): $PMODE_ERR${NC}" >&2
            pmode_log "RETRY $tries" "$rels | $PMODE_ERR"
            add_msg assistant "$raw"
            add_msg user "That did not work: $PMODE_ERR. The SEARCH text must appear EXACTLY ONCE in the file, copied character-for-character from the file content above, including every space and tab. Try again and reply ONLY with edit blocks."
            continue
        fi
        # retries exhausted -> whole-file rewrite (single file only) -> give up
        if [ "$PMODE_MULTI" = 0 ] \
           && pmode_rewrite_fallback "${FILES[0]}" "$req" && pmode_make_diff "$patch"; then
            pmode_log "FALLBACK rewrite" "$rels"
            break
        fi
        echo -e "${RED}$(t pmv_giveup)${NC}" >&2
        echo -e "${YELLOW}$(t pmv_rawout)${NC}" >&2
        printf '%s\n' "$raw" >&2
        pmode_log "GIVE UP" "$rels | retries=$tries | $PMODE_ERR"
        rm -f "$patch"
        return 1
    done

    pmode_show_diff "$patch" "$top"

    local A
    while :; do
        read -r -p "$(t pmv_ask)" A < /dev/tty || A="n"
        case "$A" in
            "$YES_KEY"|y|Y)
                if pmode_apply "$top" "$patch" "$rels"; then
                    echo -e "${GREEN}$(t pmv_applied) $rels${NC}"
                    pmode_log "APPLIED" "$rels | $patch"
                    core_log "PMODE APPLIED" "$rels | $req"
                    pmode_commit "$top" "$req" "${PMODE_RELS[@]}"   # Phase 2: optional local commit
                else
                    rm -f "$patch"; return 1
                fi
                break ;;
            e|E)
                echo -e "${YELLOW}$(t pmv_newreq)${NC}"
                local NEWREQ
                read -r NEWREQ < /dev/tty || NEWREQ=""
                [ -z "$NEWREQ" ] && { echo "$(t cancelled)"; break; }
                req="$NEWREQ"
                pmode_build_prompt "$req"
                raw="$(pmode_get_edit)" || raw=""
                if [ -n "$raw" ] && pmode_parse_blocks "$raw" && pmode_make_diff "$patch"; then
                    pmode_show_diff "$patch" "$top"
                else
                    echo -e "${RED}${PMODE_ERR:-$(t pmv_noblocks)}${NC}" >&2
                    pmode_log "GIVE UP (after edit)" "$rels | ${PMODE_ERR:-no blocks}"
                    break
                fi
                continue ;;
            q|Q|n|N|"")
                echo -e "${YELLOW}$(t pmv_kept)${NC} $patch"
                pmode_log "DECLINED" "$rels | patch kept at $patch"
                echo -e "${BLUE}$(t pmv_logged)${NC} ${PMODE_LOG/#$HOME/\~}"
                return 0 ;;
            *) continue ;;
        esac
    done
    echo -e "${BLUE}$(t pmv_logged)${NC} ${PMODE_LOG/#$HOME/\~}"
    return 0
}

