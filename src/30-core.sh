# ------------------- FUNCTIONS ----------------------
write_log() {
    mkdir -p "$LOGDIR"
    printf '%s | %s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$LOGFILE"
}

show_equiv() {
    # teaching pillar (v2.10): whenever glia does something internally, it
    # also SHOWS the equivalent manual command, so you can try it yourself.
    echo -e "  ${YELLOW}($(t equiv) $*)${NC}"
}

# ================= CORE helpers (Part E, v2.17) =================
# Built here in Session ZERO so later Parts (A-F) reuse the same names.

# core_show_cmd / core_log: documented CORE aliases over the existing helpers,
# so future modules have a stable name to call (the old names keep working).
core_show_cmd() { show_equiv "$@"; }
core_log()      { write_log "$@"; }

core_confirm() {
    # y/N confirmation, default NO. Honors $YES_KEY and the localized confirm
    # word (s/j/y, si/ja/yes). Set GLIA_ASSUME_YES=1 for non-interactive "yes"
    # (used by scripted runs and tests). Returns 0 on yes, 1 otherwise.
    local prompt="${1:-$(t rc_confirm_generic)}" ans yeslc
    [ "${GLIA_ASSUME_YES:-}" = 1 ] && return 0
    (exec 3</dev/tty) 2>/dev/null || return 1
    read -r -p "$prompt" ans < /dev/tty || return 1
    yeslc="$(printf '%s' "$CONFIRM_WORD" | tr '[:upper:]' '[:lower:]')"
    case "${ans,,}" in "$YES_KEY"|y|yes|"$yeslc") return 0 ;; *) return 1 ;; esac
}

ver_cmp() {
    # SemVer compare WITH pre-releases. Echoes -1 (A<B), 0 (A==B), 1 (A>B).
    # A leading 'v' is ignored. Rules (SemVer 2.0.0 section 11):
    #   - compare MAJOR.MINOR.PATCH numerically;
    #   - a version WITHOUT a pre-release is GREATER than the same with one
    #     (2.17.0 > 2.17.0-beta.1);
    #   - pre-release identifiers compared left-to-right: numeric<numeric
    #     numerically, numeric always lower than alphanumeric, else by ASCII.
    # Test table (see below): run  glia --selftest-vercmp  is NOT shipped; these
    # are validated in dev with a scratch harness.
    #   2.17.0       vs 2.16.0        -> 1
    #   2.16.0       vs 2.17.0        -> -1
    #   2.17.0       vs 2.17.0        -> 0
    #   2.17.0       vs 2.17.0-beta.1 -> 1
    #   2.17.0-beta.1 vs 2.17.0-beta.2 -> -1
    #   2.17.0-rc.1  vs 2.17.0-beta.9 -> 1
    #   2.17.0-beta.10 vs 2.17.0-beta.2 -> 1
    local A="${1#v}" B="${2#v}"
    local Amain="${A%%-*}" Bmain="${B%%-*}" Apre="" Bpre=""
    [ "$A" != "$Amain" ] && Apre="${A#*-}"
    [ "$B" != "$Bmain" ] && Bpre="${B#*-}"
    local -a Af Bf
    IFS=. read -r -a Af <<< "$Amain"
    IFS=. read -r -a Bf <<< "$Bmain"
    local i a b
    for i in 0 1 2; do
        a="${Af[i]:-0}"; b="${Bf[i]:-0}"
        a="${a//[!0-9]/}"; b="${b//[!0-9]/}"; a="${a:-0}"; b="${b:-0}"
        if [ "$a" -gt "$b" ]; then echo 1; return; fi
        if [ "$a" -lt "$b" ]; then echo -1; return; fi
    done
    # main version equal -> pre-release rules
    if [ -z "$Apre" ] && [ -z "$Bpre" ]; then echo 0; return; fi
    if [ -z "$Apre" ]; then echo 1; return; fi     # no pre > has pre
    if [ -z "$Bpre" ]; then echo -1; return; fi
    local -a Ap Bp
    IFS=. read -r -a Ap <<< "$Apre"
    IFS=. read -r -a Bp <<< "$Bpre"
    local n=${#Ap[@]} x y
    [ ${#Bp[@]} -gt "$n" ] && n=${#Bp[@]}
    for ((i=0; i<n; i++)); do
        x="${Ap[i]-}"; y="${Bp[i]-}"
        # fewer fields (when all previous equal) = lower precedence
        if [ -z "$x" ] && [ -n "$y" ]; then echo -1; return; fi
        if [ -n "$x" ] && [ -z "$y" ]; then echo 1; return; fi
        [ "$x" = "$y" ] && continue
        if [[ "$x" =~ ^[0-9]+$ ]] && [[ "$y" =~ ^[0-9]+$ ]]; then
            if [ "$x" -gt "$y" ]; then echo 1; else echo -1; fi; return
        elif [[ "$x" =~ ^[0-9]+$ ]]; then echo -1; return   # numeric < alnum
        elif [[ "$y" =~ ^[0-9]+$ ]]; then echo 1; return
        else
            if [[ "$x" > "$y" ]]; then echo 1; else echo -1; fi; return
        fi
    done
    echo 0
}
# =============== end CORE helpers (Part E) ===============

ram_needed_mb() {
    # optional $1 = a model name; default = the active MODEL (v2.10)
    case "${1:-$MODEL}" in
        *32b*|*30b*) echo 22000 ;;
        *14b*)       echo 11000 ;;
        *7b*|*8b*)   echo 6000 ;;
        *)           echo 4000 ;;
    esac
}

check_ai() {
    if ! curl -fsS --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
        echo -e "${YELLOW}$(t ollama_start)${NC}" >&2
        show_equiv "systemctl start ollama" >&2
        systemctl start ollama 2>/dev/null || sudo systemctl start ollama 2>/dev/null
        local i
        for i in 1 2 3 4 5; do
            sleep 1
            curl -fsS --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1 && break
        done
    fi
    if ! curl -fsS --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
        echo -e "${RED}$(t ollama_fail)${NC}" >&2
        exit 1
    fi
    # anchored check: a bare name means :latest, so "qwen3" does not
    # falsely match an installed "qwen3:8b" (v2.7)
    local mname="${MODEL#ollama:}"
    case "$mname" in *:*) : ;; *) mname="$mname:latest" ;; esac
    if ! curl -fsS --max-time 5 "$OLLAMA_URL/api/tags" 2>/dev/null | grep -q "\"$mname\""; then
        echo -e "${YELLOW}$(t model_missing)${NC}" >&2
        echo -e "$(t download_with)" >&2
        exit 1
    fi
    local avail need
    avail=$(ram_free_mb)
    need=$(ram_needed_mb)
    if [ -n "$avail" ] && [ "$avail" -lt "$need" ]; then
        # v2.11: no warning if the model is ALREADY loaded - the low free
        # RAM is the model itself sitting in memory, not a problem
        if ! curl -fsS --max-time 2 "$OLLAMA_URL/api/ps" 2>/dev/null | grep -q "\"$mname\""; then
            echo -e "${YELLOW}$(t low_ram) (${avail} MB / ~${need} MB)${NC}" >&2
        fi
    fi
}

rename_shadow_scan() {
    # v2.18.3 - look BACKWARDS: --rename now refuses to bury a command, but a
    # nickname created before v2.18.2 is still sitting there, and the person who
    # has it is exactly the one who will never find out. For every symlink of
    # ours, walk the WHOLE PATH looking for a real command with the same name
    # (command -v is no use here: it would just find our own symlink first).
    # Prints one "name<TAB>shadowed-path<TAB>our-symlink" per problem found.
    local dir f name d cand ours
    ours="$(dirname "$(realpath "$0" 2>/dev/null)" 2>/dev/null)"
    [ -d "$ours" ] || return 0
    for f in "$ours"/*; do
        [ -L "$f" ] || continue
        [ "$(readlink "$f")" = "glia" ] || continue
        name="$(basename "$f")"
        while IFS=: read -r -d: d || [ -n "$d" ]; do
            [ -n "$d" ] || continue
            cand="$d/$name"
            [ "$cand" = "$f" ] && continue                 # ourselves
            [ -f "$cand" ] && [ -x "$cand" ] || continue
            [ -L "$cand" ] && [ "$(readlink "$cand")" = "glia" ] && continue
            printf '%s\t%s\t%s\n' "$name" "$cand" "$f"
            break
        done <<< "$PATH:"
    done
}

rename_suggest() {
    # Free variants of a name the user clearly liked, so a refusal still ends
    # with something to type. Only names that are free EVERYWHERE are offered.
    local base="$1" c out=""
    for c in "${base}-ai" "my${base}" "${base}y" "${base}2"; do
        case "$RENAME_FORBIDDEN" in *" $c "*) continue ;; esac
        command -v "$c" >/dev/null 2>&1 && continue
        out="${out:+$out · }$c"
    done
    printf '%s' "$out"
}

rename_assistant() {
    local newname="$1" self dir canon dest old="$ASSIST_NAME" hit sug
    if [ -z "$newname" ]; then
        echo "Usage: $PROG --rename <newname>" >&2; exit 1
    fi
    if ! grep -qE '^[a-zA-Z][a-zA-Z0-9_-]*$' <<< "$newname"; then
        echo "$(t rename_invalid)" >&2; exit 1
    fi
    if [ "$newname" = "glia" ]; then
        echo "$(t rename_isglia)" >&2; exit 1
    fi
    # v2.18.2 - a name is not just a label: it is a command in your PATH. Two
    # guards, because until now BOTH of these went through silently (the old
    # check only looked inside ~/.local/bin, so /usr/bin/jar was invisible to it
    # and 'glia --rename jar' happily buried the Java tool).
    # 1) the reserved list: never, no confirmation offered.
    case "$RENAME_FORBIDDEN" in
        *" $newname "*)
            echo -e "${RED}'$newname': $(t rename_forbid)${NC}" >&2
            sug="$(rename_suggest "$newname")"
            [ -n "$sug" ] && echo -e "${GREEN}$(t rename_try) $sug${NC}" >&2
            exit 1 ;;
    esac
    # 2) any other existing command: refuse, but SHOW what would be buried.
    #    A name already ours is fine - renaming to the current name is a no-op,
    #    not a collision.
    hit="$(command -v "$newname" 2>/dev/null)"
    if [ -n "$hit" ] && ! { [ -L "$hit" ] && [ "$(readlink "$hit")" = "glia" ]; }; then
        echo -e "${RED}'$newname': $(t rename_shadow) ${YELLOW}$hit${NC}" >&2
        echo -e "${RED}$(t rename_shadow_w)${NC}" >&2
        sug="$(rename_suggest "$newname")"
        if [ -n "$sug" ]; then
            echo -e "${GREEN}$(t rename_try) $sug${NC}" >&2
        else
            echo -e "${GREEN}$(t rename_try2) $PROG --rename <nome>${NC}" >&2
        fi
        exit 1
    fi
    self="$(realpath "$0")"
    dir="$(dirname "$self")"
    canon="$dir/glia"
    # ensure the anchor 'glia' exists: if this file is not it yet, become it once
    if [ ! -e "$canon" ]; then
        mv "$self" "$canon" 2>/dev/null || { echo -e "${RED}$(t rename_denied) glia${NC}" >&2; exit 1; }
    fi
    # the chosen name is only a symlink to glia; glia itself is never moved away
    dest="$dir/$newname"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "$(t rename_exists)" >&2; exit 1
    fi
    ln -sf glia "$dest" 2>/dev/null || { echo -e "${RED}$(t rename_denied) $newname${NC}" >&2; exit 1; }
    # remember the preferred name (shown in -h); 'glia' keeps working as a safety net
    mkdir -p "$(dirname "$NAMEFILE")"; printf '%s\n' "$newname" > "$NAMEFILE"
    echo -e "${GREEN}$(t renamed) $newname${NC}"
    echo "  $newname -h        ($(t rename_anchor))"
    show_equiv "ln -sf glia ${dest/#$HOME/\~}  ·  echo $newname > ~/.config/glia/name"
    # v2.18.2 - one rename, one name. The old symlink used to stay behind
    # forever, so nicknames piled up in ~/.local/bin without anyone noticing.
    # It is removed, but SAID out loud with the command that did it: scripts
    # calling the old name will stop working, and you must hear that now
    # rather than discover it later. 'glia' always answers, whatever happens.
    if [ -n "$old" ] && [ "$old" != "glia" ] && [ "$old" != "$newname" ]; then
        local oldlink="$dir/$old"
        if [ -L "$oldlink" ] && [ "$(readlink "$oldlink")" = "glia" ]; then
            rm -f "$oldlink" 2>/dev/null && {
                echo -e "${YELLOW}$(t rename_oldgone) $old${NC}"
                show_equiv "rm -f ${oldlink/#$HOME/\~}"
            }
        fi
    fi
    # v2.12.3: the assistant has a dedicated home folder ~/<name>. 'glia' is the
    # permanent anchor: ~/glia (the repo) is NEVER touched. On the FIRST rename
    # (old = glia) we simply CREATE the new folder ~/<newname>. On later renames
    # we move ~/<old> -> ~/<newname>, asking first (no = keep the old one AND
    # create the new one). Projects live in ~/<name>/projects.
    local oldfolder="$HOME/$old" newfolder="$HOME/$newname" a
    if [ "$old" = "glia" ]; then
        # anchor: leave ~/glia alone, just create the new dedicated folder
        mkdir -p "$newfolder" && echo -e "${GREEN}$(t proj_created) ${newfolder/#$HOME/\~}${NC}"
    elif [ -d "$oldfolder" ] && [ "$oldfolder" != "$newfolder" ]; then
        if [ -e "$newfolder" ]; then
            echo -e "${YELLOW}$(t proj_target_exists) ${newfolder/#$HOME/\~}${NC}"
        else
            echo -e "${BLUE}$(t proj_ask)${NC}"
            echo "  ${oldfolder/#$HOME/\~}  ->  ${newfolder/#$HOME/\~}"
            if (exec 3</dev/tty) 2>/dev/null; then read -r -p "  [$YES_KEY/N]: " a < /dev/tty || a=""; else a=""; fi
            case "${a,,}" in
                "$YES_KEY") mv "$oldfolder" "$newfolder" && echo -e "${GREEN}$(t proj_migrated) ${newfolder/#$HOME/\~}${NC}" ;;
                *)          mkdir -p "$newfolder"; echo "$(t proj_kept) ${oldfolder/#$HOME/\~}" ;;
            esac
        fi
    else
        # no old folder to move (or same name): just ensure the new one exists
        mkdir -p "$newfolder"
    fi
}

set_language() {
    case "$1" in
        it|en|de)
            mkdir -p "$HOME/.config/glia"
            echo "$1" > "$HOME/.config/glia/lang"
            UILANG="$1"
            case "$UILANG" in it) CONFIRM_WORD="SI"; YES_KEY="s" ;; de) CONFIRM_WORD="JA"; YES_KEY="j" ;; *) CONFIRM_WORD="YES"; YES_KEY="y" ;; esac
            echo -e "${GREEN}$(t lang_set)$1${NC}"
            show_equiv "echo $1 > ~/.config/glia/lang"
            ;;
        *)
            echo "$(t lang_usage)" >&2
            exit 1
            ;;
    esac
}

