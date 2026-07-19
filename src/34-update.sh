# ---- self-update (v2.17, Part E): channel + tag based, with rollback ----
# Fetch a TAGGED copy of the repo via ONE shallow clone, validate it, back up
# the current install, then swap the script atomically and refresh companions
# from the SAME tag. Rename symlinks survive (they point to 'glia' on disk).

core_fetch_tag() {
    # $1 = tag. Shallow-clones that tag into a fresh temp dir and validates
    # bin/glia (syntax + internal VERSION == tag base). On success prints the
    # checkout dir on stdout (return 0); the CALLER must rm -rf it when done.
    local tag="$1" tmpd base intver
    [ -n "$tag" ] || return 1
    tmpd="$(mktemp -d)" || return 1
    if ! git clone --quiet --depth 1 --branch "$tag" "$GLIA_REPO_URL" "$tmpd/repo" 2>/dev/null; then
        rm -rf "$tmpd"; return 2
    fi
    [ -s "$tmpd/repo/bin/glia" ] || { rm -rf "$tmpd"; return 3; }
    bash -n "$tmpd/repo/bin/glia" 2>/dev/null || { rm -rf "$tmpd"; return 4; }
    intver="$(grep -m1 -oE 'VERSION="[0-9.]+"' "$tmpd/repo/bin/glia" | grep -oE '[0-9.]+')"
    base="${tag#v}"; base="${base%%-*}"
    [ "$intver" = "$base" ] || { rm -rf "$tmpd"; return 5; }
    printf '%s' "$tmpd/repo"
}

rc_backup_current() {
    # Copy the CURRENTLY installed script (+ companion) into versions/<tag>/.
    # Keyed by TAG, not by $VERSION (E6.1): beta.1 and beta.2 share the same
    # VERSION 2.17.0, so a version-keyed backup made them overwrite each other
    # and the older beta became unrecoverable.
    local self dir vdir
    self="$(realpath "$0" 2>/dev/null)"; dir="$(dirname "$self")"
    vdir="$GLIA_VERSIONS_DIR/$(glia_effective_tag)"
    mkdir -p "$vdir" 2>/dev/null || return 1
    cp -f "$self" "$vdir/glia" 2>/dev/null || return 1
    # Written while this version is still the running one, so it answers
    # "when was this version in use?" for the --rollback list.
    date +%s > "$vdir/installed-at" 2>/dev/null
    [ -e "$dir/glia-hardware" ] && cp -f "$dir/glia-hardware" "$vdir/glia-hardware" 2>/dev/null
    return 0
}

rc_backup_when() {
    # $1 = backup dir name. Prints a human date, or nothing if unknown
    # (legacy backups predate the installed-at stamp).
    local f="$GLIA_VERSIONS_DIR/$1/installed-at" ts
    [ -r "$f" ] || return 1
    ts="$(head -n1 "$f" 2>/dev/null)"
    [[ "$ts" =~ ^[0-9]+$ ]] || return 1
    date -d "@$ts" '+%Y-%m-%d' 2>/dev/null
}

rc_sort_versions() {
    # Read version/tag strings on stdin, print them ASCENDING (oldest first).
    # Tag-named ("v2.17.0-beta.1") and legacy version-named ("2.17.0") dirs mix
    # freely: ver_cmp already ignores a leading 'v', so no normalisation pass is
    # needed here and the caller keeps the REAL directory name for its paths.
    local -a a=(); local x i j tmp n
    while IFS= read -r x; do [ -n "$x" ] && a+=("$x"); done
    n=${#a[@]}
    for ((i=0; i<n; i++)); do
        for ((j=0; j<n-1-i; j++)); do
            if [ "$(ver_cmp "${a[j]}" "${a[j+1]}")" = 1 ]; then
                tmp="${a[j]}"; a[j]="${a[j+1]}"; a[j+1]="$tmp"
            fi
        done
    done
    [ "$n" -gt 0 ] && printf '%s\n' "${a[@]}"
}

rc_prune() {
    # keep the newest GLIA_KEEP_VERSIONS backups, delete older ones
    [ -d "$GLIA_VERSIONS_DIR" ] || return 0
    local -a vers=(); local d v sorted total keep_from i=0
    for d in "$GLIA_VERSIONS_DIR"/*/; do [ -d "$d" ] && vers+=("$(basename "$d")"); done
    [ "${#vers[@]}" -le "$GLIA_KEEP_VERSIONS" ] && return 0
    sorted="$(printf '%s\n' "${vers[@]}" | rc_sort_versions)"      # oldest first
    total="$(printf '%s\n' "$sorted" | grep -c .)"
    keep_from=$(( total - GLIA_KEEP_VERSIONS ))
    while IFS= read -r v; do
        [ -n "$v" ] || continue
        i=$((i+1))
        [ "$i" -le "$keep_from" ] && rm -rf "$GLIA_VERSIONS_DIR/$v" 2>/dev/null
    done <<< "$sorted"
}

glia_self_update() {
    # Update the GLIA PROGRAM. $1 = "--check" -> query only, do not install.
    local self dir chan tag cmp cur check_only=0 repodir sudo=""
    [ "${1:-}" = "--check" ] && check_only=1
    self="$(realpath "$0" 2>/dev/null)"; dir="$(dirname "$self")"
    chan="$(chan_get)"; cur="$(glia_effective_tag)"
    echo -e "${BLUE}$(t su_current)${NC} $VERSION   [$cur]   ($(t rc_channel): $chan)"
    # ONE remote query (E6.1): rc_check sets NEWTAG/NEWVER, compares against the
    # effective tag and refreshes the cache. Asking ls-remote twice for the same
    # fact was duplicated logic (DRY) and a second round-trip for nothing.
    rc_check; cmp=$?
    if [ "$cmp" = 2 ]; then                        # tell no-tags apart from offline
        if net_online; then echo -e "${YELLOW}$(t rc_notags)${NC}"
        else echo -e "${YELLOW}$(t doc_offline)${NC}"; fi
        return 2
    fi
    tag="$NEWTAG"
    if [ "$cmp" != 1 ]; then
        echo -e "${GREEN}$(t su_uptodate)${NC}   ($tag)"; return 0
    fi
    echo -e "$(t su_new) ${GREEN}${tag#v}${NC}   [$tag]"
    if [ "$check_only" = 1 ]; then
        echo -e "  ${GREEN}$ASSIST_NAME --update${NC}"; return 1
    fi
    core_confirm "$(t rc_updconfirm)" || { echo "$(t su_denied)"; return 0; }
    repodir="$(core_fetch_tag "$tag")" || { echo -e "${RED}$(t su_dlfail)${NC}" >&2; return 1; }
    rc_backup_current || echo -e "${YELLOW}$(t rc_backupwarn)${NC}"
    rc_prune
    [ -w "$dir" ] || sudo="sudo"
    if ! $sudo install -m755 "$repodir/bin/glia" "$dir/glia.new" \
         || ! $sudo mv -f "$dir/glia.new" "$dir/glia"; then
        rm -rf "$repodir"; echo -e "${RED}$(t su_dlfail)${NC}" >&2; return 1
    fi
    tag_set "$tag"      # the record must follow the script on disk, immediately
    core_log "self update" "$cur -> $tag ($chan)"
    # companions from the SAME tag, best effort, only where they already exist
    _rc_put() { { [ -e "$2" ] && [ -f "$1" ]; } || return 0
        local s=""; [ -w "$(dirname "$2")" ] || s="sudo"; $s install -m"$3" "$1" "$2"; }
    _rc_put "$repodir/bin/glia-hardware" "$dir/glia-hardware" 755
    _rc_put "$repodir/completions/glia.bash" "$HOME/.local/share/bash-completion/completions/glia" 644
    _rc_put "$repodir/completions/glia.fish" "$HOME/.config/fish/completions/glia.fish" 644
    unset -f _rc_put
    rm -rf "$repodir"
    echo -e "${GREEN}$(t su_done)${NC}"
    core_show_cmd "git clone --depth 1 --branch $tag $GLIA_REPO_URL /tmp/glia && install -m755 /tmp/glia/bin/glia ${dir/#$HOME/\~}/glia"
    echo -e "$(t rc_rollhint) ${GREEN}$ASSIST_NAME --rollback${NC}"
    "$dir/glia" -V
}

glia_rollback() {
    # Go back to a previously installed version, from the local backups made by
    # rc_backup_current. The CURRENT script is backed up first, so a rollback is
    # itself reversible. Newest backup first; Enter picks it.
    local self dir; self="$(realpath "$0" 2>/dev/null)"; dir="$(dirname "$self")"
    local -a vers=(); local v d i=1 ans pick src sudo="" when cur
    cur="$(glia_effective_tag)"      # backups are keyed by TAG since E6.1
    if [ -d "$GLIA_VERSIONS_DIR" ]; then
        while IFS= read -r v; do [ -n "$v" ] && vers+=("$v"); done < <(
            for d in "$GLIA_VERSIONS_DIR"/*/; do
                [ -f "$d/glia" ] && basename "$d"
            done | rc_sort_versions | tac )
    fi
    [ "${#vers[@]}" -gt 0 ] || { echo -e "${YELLOW}$(t rc_norollback)${NC}"; return 0; }
    echo -e "${BLUE}$(t rc_rolllist)${NC}"
    for v in "${vers[@]}"; do
        when="$(rc_backup_when "$v")" && when="   ${BLUE}($(t rc_rollwhen) $when)${NC}" || when=""
        if [ "$v" = "$cur" ]; then
            echo -e "  $i) $v   ${YELLOW}($(t rc_rollcurrent))${NC}$when"
        else
            echo -e "  $i) $v$when"
        fi
        i=$((i+1))
    done
    (exec 3</dev/tty) 2>/dev/null || { echo "$(t cancelled)"; return 1; }
    read -r -p "$(t rc_rollpick)" ans < /dev/tty || return 1
    [ -z "$ans" ] && ans=1
    if ! [[ "$ans" =~ ^[0-9]+$ ]] || [ "$ans" -lt 1 ] || [ "$ans" -gt "${#vers[@]}" ]; then
        echo "$(t cancelled)"; return 0
    fi
    pick="${vers[$((ans-1))]}"
    src="$GLIA_VERSIONS_DIR/$pick/glia"
    [ -f "$src" ] || { echo -e "${RED}$(t rc_norollback)${NC}" >&2; return 1; }
    [ "$pick" = "$cur" ] && { echo -e "${YELLOW}$(t rc_rollsame)${NC}"; return 0; }
    echo -e "$(t rc_rollto) ${GREEN}$pick${NC}"
    core_confirm "$(t rc_rollconfirm)" || { echo "$(t su_denied)"; return 0; }
    bash -n "$src" 2>/dev/null || { echo -e "${RED}$(t su_dlfail)${NC}" >&2; return 1; }
    rc_backup_current || echo -e "${YELLOW}$(t rc_backupwarn)${NC}"   # keep it reversible
    [ -w "$dir" ] || sudo="sudo"
    if ! $sudo install -m755 "$src" "$dir/glia.new" \
         || ! $sudo mv -f "$dir/glia.new" "$dir/glia"; then
        echo -e "${RED}$(t su_dlfail)${NC}" >&2; return 1
    fi
    # companion from the SAME backup, only where it already exists
    if [ -f "$GLIA_VERSIONS_DIR/$pick/glia-hardware" ] && [ -e "$dir/glia-hardware" ]; then
        $sudo install -m755 "$GLIA_VERSIONS_DIR/$pick/glia-hardware" "$dir/glia-hardware" 2>/dev/null
    fi
    # Easy to miss, essential (E6.1): without this the record would keep naming
    # the version we just rolled AWAY from, and every later comparison would be
    # made against a tag that is no longer installed.
    tag_set "$pick"
    core_log "rollback" "$cur -> $pick"
    echo -e "${GREEN}$(t su_done)${NC}"
    core_show_cmd "install -m755 ${src/#$HOME/\~} ${dir/#$HOME/\~}/glia"
    "$dir/glia" -V
}

# ---- kaboom (v2.11): guided uninstall ----
kaboom() {
    # Two levels: 1 = only the program (engine and AIs stay), 2 = everything.
    # Teaching pillar even on the way out: every command is SHOWN before
    # running, heavy typed confirmation, shared deps (curl, jq) never touched.
    local self dir f choice ans c cmds=()
    echo -e "${RED}$(t kb_title)${NC}"
    echo
    echo "$(t kb_what)"
    echo "$(t kb_opt1)"
    echo "$(t kb_opt2)"
    echo "$(t kb_opt3)"
    (exec 3</dev/tty) 2>/dev/null || { echo "$(t cancelled)"; return 1; }
    read -r -p "$(t kb_choose)" choice < /dev/tty || return 1
    case "$choice" in 1|2) : ;; *) echo "$(t cancelled)"; return 0 ;; esac

    # -- build the command list (only for things that actually exist) --
    self="$(realpath "$0" 2>/dev/null)"; dir="$(dirname "$self")"
    # renamed commands: every symlink next to glia that points to it
    for f in "$dir"/*; do
        [ -L "$f" ] && [ "$(readlink "$f")" = "glia" ] && cmds+=("rm -f $f")
    done
    cmds+=("rm -f $dir/glia $dir/glia-hardware")
    [ -d "$HOME/.config/glia" ]       && cmds+=("rm -rf ~/.config/glia")
    [ -d "$LOGDIR" ]                  && cmds+=("rm -rf ${LOGDIR/#$HOME/\~}")
    [ -f "$HOME/.local/share/bash-completion/completions/glia" ] \
        && cmds+=("rm -f ~/.local/share/bash-completion/completions/glia")
    [ -f "$HOME/.config/fish/completions/glia.fish" ] \
        && cmds+=("rm -f ~/.config/fish/completions/glia.fish")

    if [ "$choice" = 2 ]; then
        [ -f "$HOME/.config/aichat/config.yaml" ] && cmds+=("rm -f ~/.config/aichat/config.yaml")
        if [ "$PKGMGR" = pacman ]; then
            local pkgs=""
            pacman -Qq ollama >/dev/null 2>&1 && pkgs="$pkgs ollama"
            pacman -Qq aichat >/dev/null 2>&1 && pkgs="$pkgs aichat"
            [ -n "$pkgs" ] && cmds+=("sudo pacman -Rns$pkgs")
            [ -d /var/lib/ollama ] && cmds+=("sudo rm -rf /var/lib/ollama")
        else
            # engine installed with Ollama's official script
            command -v systemctl >/dev/null 2>&1 && [ -f /etc/systemd/system/ollama.service ] && {
                cmds+=("sudo systemctl disable --now ollama")
                cmds+=("sudo rm /etc/systemd/system/ollama.service")
            }
            command -v ollama >/dev/null 2>&1 && cmds+=("sudo rm $(command -v ollama)")
            [ -d /usr/share/ollama ] && cmds+=("sudo rm -rf /usr/share/ollama")
            id ollama >/dev/null 2>&1 && cmds+=("sudo userdel ollama")
            [ -f "$dir/aichat" ] && cmds+=("rm -f $dir/aichat")
        fi
        [ -d "$HOME/.ollama" ] && cmds+=("rm -rf ~/.ollama")
    fi

    # -- show everything first, then one heavy confirmation --
    echo
    echo "$(t kb_cmds)"
    for c in "${cmds[@]}"; do
        echo -e "  ${GREEN}$c${NC}"
    done
    echo
    echo -e "${YELLOW}$(t kb_deps)${NC}"
    grep -qsF "# added by GLIA install-assistant" \
        "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish" 2>/dev/null \
        && echo -e "${YELLOW}$(t kb_path_note)${NC}"
    echo
    read -r -p "$(t kb_confirm)" ans < /dev/tty || return 1
    [ "$ans" != "$CONFIRM_WORD" ] && { echo "$(t cancelled)"; return 0; }

    write_log "KABOOM" "level $choice"
    for c in "${cmds[@]}"; do
        echo -e "$(t kb_run) $c"
        eval "$c" || true          # eval re-parses the line, so ~ expands
    done
    echo -e "${GREEN}$(t kb_done)${NC}"
}

