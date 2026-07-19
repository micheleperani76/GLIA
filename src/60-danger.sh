# ---- danger self-explanation (v1.6) ----
explain_danger() {
    # one plain-language sentence about what a dangerous command will do
    local cmd="$1" out
    out=$(aichat --model "$MODEL" \
        "Explain in ONE short sentence, in ${PLAN_LANG}, in plain language for a non-expert, what this bash command will do and what it could delete or change permanently. No markdown, no code, only the sentence. Command: $cmd$(nothink)" \
        < /dev/null 2>/dev/null | strip_think | grep -v '^\s*$' | head -n 2 | paste -sd ' ' -)
    [ -n "$out" ] && printf '%s\n' "$out"
    return 0
}

# ================= D4: reading someone else's error (v2.19.3) =================

mirror_refresh_cmd() {
    # The RIGHT command for THIS machine, not a generic one: CachyOS ships its
    # own rater (and a timer for it), plain Arch has reflector. Same idea as
    # pkg_install_cmd - name the tool that is actually here.
    if command -v cachyos-rate-mirrors >/dev/null 2>&1; then
        printf '%s' "sudo cachyos-rate-mirrors"
    elif command -v reflector >/dev/null 2>&1; then
        printf '%s' "sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist"
    else
        printf '%s' "$(t ke_mirror_manual)"
    fi
}

known_error() {
    # Echoes the id of a known error found in $1, or returns 1. Both patterns
    # of a row must match: an unordered AND is two greps, not one clever regex
    # (and clever regexes are how `rm` matched terrafo(rm) - see v2.19.0).
    local txt="$1" e id pm p1 p2 extra
    [ -n "$txt" ] || return 1
    for e in "${KNOWN_ERRORS[@]}"; do
        IFS='|' read -r id pm p1 p2 extra <<< "$e"
        # A 5th field means someone put a '|' inside a pattern and IFS cut the
        # regex in half: the rule would then match nothing while looking armed.
        # --danger validates its regexes at the door for the same reason; a
        # broken guard is worse than none, so this one is loud, not silent.
        [ -n "$extra" ] && { echo "glia: KNOWN_ERRORS row '$id': a pattern contains '|', the field separator" >&2; continue; }
        [ "$pm" = "*" ] || [ "$pm" = "$PKGMGR" ] || continue
        grep -qiE "$p1" <<< "$txt" 2>/dev/null || continue
        if [ -n "$p2" ]; then grep -qiE "$p2" <<< "$txt" 2>/dev/null || continue; fi
        printf '%s' "$id"; return 0
    done
    return 1
}

known_error_say() {
    # Explain, don't decide: after this the usual fix prompt still runs, so the
    # user can still ask the AI. They just aren't hearing the forum first.
    local id="$1"
    echo -e "${YELLOW}$(t ke_title)${NC}"
    echo -e "  $(t "ke_${id}_what")"
    echo -e "  ${GREEN}$(t ke_fix)${NC} $(t "ke_${id}_fix")"
    echo -e "  ${RED}$(t ke_trap)${NC} $(t "ke_${id}_trap")"
}
# ================= end D4: reading someone else's error =================

# ---- reboot / shutdown detection (v1.8) ----
is_reboot_cmd() {
    # true if the command reboots, powers off or halts the whole machine
    grep -qiE '(^|[[:space:];&|])(reboot|poweroff|halt)([[:space:]]|$)|systemctl[[:space:]].*(reboot|poweroff|halt|suspend|hibernate)|shutdown([[:space:]]|$)|init[[:space:]]+[06]([[:space:]]|$)' <<< "$1"
}

# ---- deterministic privilege fix (v1.8) ----
add_sudo_segment() {
    # adds sudo to ONE simple command if it needs root and lacks it,
    # preserving leading/trailing spaces of the segment
    local seg="$1" lead trail core first
    lead="${seg%%[![:space:]]*}"
    trail="${seg##*[![:space:]]}"
    core="${seg#"$lead"}"; core="${core%"$trail"}"
    [ -z "$core" ] && { printf '%s' "$seg"; return; }
    first="${core%%[[:space:]]*}"
    # already elevated, or read-only queries that do NOT need root -> leave as is
    case "$core" in
        sudo\ *) printf '%s' "$seg"; return ;;
        systemctl\ status*|systemctl\ list*|systemctl\ show*|systemctl\ is-*|systemctl\ cat*|systemctl\ --user*)
            printf '%s' "$seg"; return ;;
        pacman\ -Q*|pacman\ -Ss*|pacman\ -Si*|pacman\ -Sl*|pacman\ -Sg*|pacman\ -Sp*|pacman\ -F*)
            printf '%s' "$seg"; return ;;
        apt\ list*|apt\ search*|apt\ show*|apt\ policy*|apt-cache\ *)
            printf '%s' "$seg"; return ;;
        dnf\ list*|dnf\ search*|dnf\ info*|dnf\ repoquery*|dnf\ provides*)
            printf '%s' "$seg"; return ;;
        zypper\ search*|zypper\ se\ *|zypper\ info*|zypper\ if\ *)
            printf '%s' "$seg"; return ;;
    esac
    if grep -qE "^($ROOT_BINS)$" <<< "$first"; then
        printf '%s%s%s' "$lead" "sudo $core" "$trail"
    else
        printf '%s' "$seg"
    fi
}

maybe_sudo() {
    # apply add_sudo_segment to every part of a  &&  or  ;  chain.
    # too risky to auto-elevate pipelines, subshells or redirections: leave them.
    local cmd="$1" out="" rest="$1" sep seg
    case "$cmd" in *'|'*|*'('*|*'`'*|*'$'*|*'>'*|*'<'*) printf '%s' "$cmd"; return ;; esac
    while [[ "$rest" =~ (\&\&|\;) ]]; do
        sep="${BASH_REMATCH[1]}"
        seg="${rest%%"$sep"*}"
        out+="$(add_sudo_segment "$seg")$sep"
        rest="${rest#*"$sep"}"
    done
    out+="$(add_sudo_segment "$rest")"
    printf '%s' "$out"
}

# ================= D5: the danger rules (v2.19.0) =================
# The built-ins above are the floor; these are YOURS, added on top. Plain text
# on purpose, like memory and aliases: one ERE per line, '#' starts a comment,
# so you can cat it, edit it, or put it in your dotfiles.

danger_user_patterns() {
    # your patterns, one per line. Blank lines and # comments skipped.
    [ -r "$DANGERFILE" ] || return 0
    sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$DANGERFILE" 2>/dev/null
}

danger_esc() {
    # A regex is full of backslashes and `echo -e` eats them: \bdd\b would
    # print as "dd" (\b = backspace) and a taught command would be a lie.
    # Double them so echo -e renders the pattern exactly as it is on disk.
    printf '%s' "${1//\\/\\\\}"
}

danger_regex_ok() {
    # A user regex reaches grep on EVERY proposed command. A broken one would
    # print an error each time and, worse, match nothing while looking armed -
    # so it is validated here, at the door, and refused if it does not compile.
    printf '%s' "" | grep -qiE "$1" 2>/dev/null || [ $? -eq 1 ]
}

needs_extra_confirm() {
    # SAFETY PATH: built-ins first, then yours. 2>/dev/null on the user loop
    # only - a built-in that stopped compiling is our bug and must be loud.
    local cmd="$1" p
    DANGER_HIT=""; DANGER_HIT_SRC=""
    for p in "${EXTRA_CONFIRM_PATTERNS[@]}"; do
        if grep -qiE "$p" <<< "$cmd"; then
            DANGER_HIT="$p"; DANGER_HIT_SRC="builtin"
            return 0
        fi
    done
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        if grep -qiE "$p" <<< "$cmd" 2>/dev/null; then
            DANGER_HIT="$p"; DANGER_HIT_SRC="user"
            return 0
        fi
    done < <(danger_user_patterns)
    return 1
}

danger_list() {
    # ONE list, numbered straight through: you see every rule that guards this
    # machine and which part of it is yours. The numbering is shared with
    # `--danger rm <n>`, the same way `-m` and `-m role` share theirs.
    local p n=0 nb=0
    echo -e "${BLUE}$(t dg_builtin_title)${NC}"
    for p in "${EXTRA_CONFIRM_PATTERNS[@]}"; do
        n=$((n+1)); nb=$((nb+1))
        printf '  %2d) %s\n' "$n" "$p"
    done
    echo
    echo -e "${BLUE}$(t dg_user_title)${NC} ${YELLOW}${DANGERFILE/#$HOME/\~}${NC}"
    local had=0
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        n=$((n+1)); had=1
        if danger_regex_ok "$p"; then
            printf '  %2d) %s\n' "$n" "$p"
        else
            printf '  %2d) %s   %b\n' "$n" "$p" "${RED}<- $(t dg_broken)${NC}"
        fi
    done < <(danger_user_patterns)
    [ "$had" -eq 0 ] && echo -e "  $(t dg_user_none)"
    echo
    echo -e "$(t dg_hint)"
    DANGER_NBUILTIN="$nb"
}

danger_add() {
    local p="$1"
    [ -n "$p" ] || { echo "$(t dg_add_usage)" >&2; return 1; }
    if ! danger_regex_ok "$p"; then
        echo -e "${RED}$(t dg_bad_regex)${NC} $(danger_esc "$p")" >&2
        return 1
    fi
    # A rule that fires on everything is not protection, it is noise you learn
    # to click through - and a habit of confirming without reading is the very
    # thing the confirm word exists to prevent.
    if grep -qiE "$p" <<< "ls" 2>/dev/null && grep -qiE "$p" <<< "echo hello" 2>/dev/null; then
        echo -e "${YELLOW}$(t dg_too_broad)${NC}"
        core_confirm "$(t dg_too_broad_ask)" || { echo "$(t cancelled)"; return 0; }
    fi
    if danger_user_patterns | grep -qxF "$p"; then
        echo -e "${YELLOW}$(t dg_dup)${NC} $(danger_esc "$p")"; return 0
    fi
    mkdir -p "$(dirname "$DANGERFILE")"
    printf '%s\n' "$p" >> "$DANGERFILE"
    echo -e "${GREEN}$(t dg_added)${NC} $(danger_esc "$p")"
    # printf, not echo: `echo '\bfoo\b' >> file` writes a different thing in
    # sh than in bash. printf '%s\n' is the form that always writes the regex.
    show_equiv "printf '%s\\\\n' '$(danger_esc "$p")' >> ${DANGERFILE/#$HOME/\~}"
    write_log "danger add" "$p"
}

danger_rm() {
    local n="$1" nb total p
    nb="${#EXTRA_CONFIRM_PATTERNS[@]}"
    case "$n" in ''|*[!0-9]*) echo "$(t dg_rm_usage)" >&2; return 1 ;; esac
    total=$(( nb + $(danger_user_patterns | grep -c . 2>/dev/null || echo 0) ))
    if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        echo -e "${RED}$(t dg_rm_range) 1-$total${NC}" >&2; return 1
    fi
    # The built-ins do not bend. Saying WHY, and pointing at what you CAN do,
    # is the difference between a locked door and a wall with no sign on it.
    if [ "$n" -le "$nb" ]; then
        echo -e "${RED}$(t dg_rm_builtin)${NC} $(danger_esc "${EXTRA_CONFIRM_PATTERNS[$((n-1))]}")"
        echo -e "  $(t dg_rm_builtin_why)"
        return 1
    fi
    p="$(danger_user_patterns | sed -n "$((n-nb))p")"
    [ -n "$p" ] || { echo -e "${RED}$(t dg_rm_range) 1-$total${NC}" >&2; return 1; }
    echo -e "  ${GREEN}$(danger_esc "$p")${NC}"
    core_confirm "$(t dg_rm_confirm)" || { echo "$(t cancelled)"; return 0; }
    # grep -vxF, not sed: a regex is exactly the thing you must not feed to sed
    # as a pattern. Fixed-string, whole-line, on a temp file + atomic mv.
    grep -vxF "$p" "$DANGERFILE" > "$DANGERFILE.tmp" 2>/dev/null
    mv "$DANGERFILE.tmp" "$DANGERFILE"
    echo -e "${GREEN}$(t dg_removed)${NC} $(danger_esc "$p")"
    show_equiv "grep -vxF '$(danger_esc "$p")' ${DANGERFILE/#$HOME/\~} > tmp && mv tmp ${DANGERFILE/#$HOME/\~}"
    write_log "danger rm" "$p"
}

danger_test() {
    # The dry-run of safety: ask whether a command WOULD trip a rule, without
    # running anything. The one way to check a new pattern that does not
    # involve typing something destructive and hoping.
    local cmd="$*"
    [ -n "$cmd" ] || { echo "$(t dg_test_usage)" >&2; return 1; }
    echo -e "$(t proposed) ${GREEN}$cmd${NC}"
    if is_reboot_cmd "$cmd"; then
        echo -e "${RED}$(t dg_test_reboot)${NC}"
        return 0
    fi
    if needs_extra_confirm "$cmd"; then
        case "$DANGER_HIT_SRC" in
            user) echo -e "${RED}$(t dg_test_hit_user)${NC} ${YELLOW}$(danger_esc "$DANGER_HIT")${NC}" ;;
            *)    echo -e "${RED}$(t dg_test_hit_builtin)${NC} ${YELLOW}$(danger_esc "$DANGER_HIT")${NC}" ;;
        esac
        echo -e "  $(t dg_test_hit_means)"
    else
        echo -e "${GREEN}$(t dg_test_miss)${NC}"
    fi
    return 0
}

danger_cmd() {
    case "${1:-}" in
        ""|list|ls)     danger_list ;;
        help|-h|--help) page danger_help ;;
        add)            shift; danger_add "$*" ;;
        rm|remove)      shift; danger_rm "${1:-}" ;;
        test)           shift; danger_test "$@" ;;
        *)              echo "$(t dg_usage)" >&2; return 1 ;;
    esac
}
# ================= end D5: the danger rules =================

