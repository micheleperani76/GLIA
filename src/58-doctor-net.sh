# ---- doctor (v2.7): one-shot health check ----
# net_update_status (v2.14.1): ONE silent check, shared by -V and --doctor.
# Sets NEWVER. Returns: 0 = online & up to date · 1 = online, newer available
# (NEWVER set) · 2 = offline / unreachable.
# net_online (v2.14.2): fast, reliable connectivity probe (~1s; fails fast
# when offline). Shared by -w (protection), -V and --doctor.
net_online() { curl -fsS --max-time 3 -o /dev/null -I "https://github.com" 2>/dev/null; }

NEWVER=""; NEWTAG=""

# ================= Release channels / update check (Part E, v2.17) =================

# --- CORE cache (reused later by Parts B/C/D and MOTD) ---
core_cache_get() {
    # $1=key  $2=max_age_sec ; prints payload (lines after the 1st) if fresh.
    local f="$GLIA_CACHE_DIR/$1" maxage="$2" ts now
    [ -r "$f" ] || return 1
    ts="$(sed -n 1p "$f" 2>/dev/null)"
    [[ "$ts" =~ ^[0-9]+$ ]] || return 1
    now="$(date +%s)"
    [ $(( now - ts )) -le "$maxage" ] || return 1
    tail -n +2 "$f"
}
core_cache_put() {
    # $1=key ; payload read from stdin. First stored line = epoch timestamp.
    local f="$GLIA_CACHE_DIR/$1"
    mkdir -p "$GLIA_CACHE_DIR" 2>/dev/null || return 1
    { date +%s; cat; } > "$f"
}

# --- channel persistence (stable|beta, default stable) ---
chan_get() {
    local c="stable"
    [ -r "$GLIA_CHANNEL_FILE" ] && c="$(sed -n 1p "$GLIA_CHANNEL_FILE" 2>/dev/null)"
    case "$c" in beta) echo beta ;; *) echo stable ;; esac
}
chan_set() {
    mkdir -p "$(dirname "$GLIA_CHANNEL_FILE")" 2>/dev/null
    printf '%s\n' "$1" > "$GLIA_CHANNEL_FILE"
}

# --- installed TAG record (E6) ---
# VERSION identifies the CODE (rule 3.6: it is the BASE of the tag, so that
# promoting a beta to stable is a pure re-tag of the SAME commit). The tag
# record identifies WHICH TAG of that code is installed. Without it,
# ver_cmp 2.17.0 vs 2.17.0-beta.2 = 1 and beta.2 is never offered: the beta
# channel could not iterate. Plain text on purpose: the user can `cat` it.
tag_set() {
    # $1 = tag (e.g. v2.17.0-beta.2). Called after EVERY successful install:
    # --update and --rollback alike (a record that lies is worse than none).
    # Canonicalised here, at the single write point: a rollback to a legacy
    # backup dir named "2.17.0" still records "v2.17.0".
    local tag="${1:-}"
    [ -n "$tag" ] || return 1
    case "$tag" in v*) ;; *) tag="v$tag" ;; esac
    mkdir -p "$(dirname "$GLIA_INSTALLED_TAG_FILE")" 2>/dev/null || return 1
    printf '%s\n' "$tag" > "$GLIA_INSTALLED_TAG_FILE"
}

glia_effective_tag() {
    # The tag we compare against the remote. Priority:
    #   1) the recorded installed tag, IF its base == $VERSION  (guards against
    #      hand-installs that replaced the script without updating the record:
    #      the record would be lying)
    #   2) fallback "v$VERSION"  (fresh install from the installer/git, script
    #      copied by hand, first run after upgrading from <= 2.16, missing or
    #      corrupt record)
    local rec base
    if [ -r "$GLIA_INSTALLED_TAG_FILE" ]; then
        rec="$(head -n1 "$GLIA_INSTALLED_TAG_FILE" 2>/dev/null)"
        base="${rec#v}"; base="${base%%-*}"
        [ "$base" = "$VERSION" ] && { printf '%s\n' "$rec"; return 0; }
    fi
    printf 'v%s\n' "$VERSION"
}

tag_is_fallback() {
    # 0 = the record is missing/corrupt/stale and glia_effective_tag() is
    # falling back to v$VERSION. A real diagnostic for --doctor, not an error.
    [ "$(glia_effective_tag)" = "v$VERSION" ] && \
        [ "$(head -n1 "$GLIA_INSTALLED_TAG_FILE" 2>/dev/null)" != "v$VERSION" ]
}

# --- tag discovery: pure git, no API, no jq ---
rc_list_tags() {
    git ls-remote --tags "$GLIA_REPO_URL" 2>/dev/null \
        | sed 's#.*refs/tags/##; s#\^{}##' | sort -u
}
rc_latest_tag() {
    # $1 = channel. stable -> only vX.Y.Z ; beta -> highest tag overall.
    local chan="${1:-stable}" t best=""
    while IFS= read -r t; do
        [ -n "$t" ] || continue
        if [ "$chan" = stable ]; then
            [[ "$t" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        else
            [[ "$t" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] || continue
        fi
        if [ -z "$best" ] || [ "$(ver_cmp "$t" "$best")" = 1 ]; then best="$t"; fi
    done < <(rc_list_tags)
    printf '%s' "$best"
}

# --- online check: sets NEWVER/NEWTAG, caches the result ---
rc_check() {
    # return: 0 up-to-date, 1 newer available, 2 offline/failed.
    NEWVER=""; NEWTAG=""
    net_online || return 2
    local chan tag cmp
    chan="$(chan_get)"
    tag="$(rc_latest_tag "$chan")"
    [ -n "$tag" ] || return 2
    NEWTAG="$tag"
    # Compare TAG against TAG (E6.1). Comparing against bare $VERSION made
    # ver_cmp v2.17.0-beta.2 vs 2.17.0 = -1 ("older"), so a newer beta was
    # never offered: the beta channel could not iterate.
    cmp="$(ver_cmp "$tag" "$(glia_effective_tag)")"
    # Cache FACTS ONLY (E6.2): the channel we asked and the tag we saw. Storing
    # the VERDICT froze it: right after an update -V kept saying "available",
    # because the answer had been computed against the OLD installed tag.
    printf '%s\n%s\n' "$chan" "$tag" | core_cache_put "$RC_CHECK_KEY"
    if [ "$cmp" = 1 ]; then NEWVER="${tag#v}"; return 1; fi
    return 0
}

# --- cached read (offline), for -V / --doctor: "tag|checked_at_epoch" ---
rc_cached() {
    # Facts only (E6.2). No verdict is returned because none is stored: the
    # caller recomputes it against glia_effective_tag(), so it can never go
    # stale after an update, a rollback, or a channel switch.
    # A cache entry from ANOTHER channel is a MISS: otherwise `--channel stable`
    # would keep showing beta's latest tag. This is why --channel needs no
    # explicit cache invalidation.
    local f="$GLIA_CACHE_DIR/$RC_CHECK_KEY" ts chan tag
    [ -r "$f" ] || return 1
    ts="$(sed -n 1p "$f")"; [[ "$ts" =~ ^[0-9]+$ ]] || return 1
    chan="$(sed -n 2p "$f")"; tag="$(sed -n 3p "$f")"
    [ -n "$tag" ] || return 1
    [ "$chan" = "$(chan_get)" ] || return 1
    printf '%s|%s' "$tag" "$ts"
}

rc_age_human() {
    # $1 = epoch. Compact, language-neutral age: 45m / 2h / 3d. "(0d)" for a
    # check made a minute ago was technically true and practically useless.
    local now age; now="$(date +%s)"; age=$(( now - ${1:-0} ))
    [ "$age" -lt 0 ] && age=0
    if   [ "$age" -lt 3600 ];  then printf '%dm' $(( age / 60 ))
    elif [ "$age" -lt 86400 ]; then printf '%dh' $(( age / 3600 ))
    else                            printf '%dd' $(( age / 86400 )); fi
}

# --- version line for -V: a FRESH check when online, honest cache offline ---
version_line() {
    # One honest line: VERSION is the code, the tag is WHICH build of that code.
    # Showing 2.17.0 while v2.17.0-beta.1 is installed was confusing (E6.1).
    echo -e "$ASSIST_NAME $VERSION (GLIA) · $(t rc_channel): $(chan_get) · $(t rc_installed) $(glia_effective_tag)"
    # v2.18.8: -V used to be offline-only, recomputing the verdict from cached
    # facts. The verdict logic was honest but the FACTS could be stale: a -V
    # run 4h after the last check kept saying "up to date" while two newer
    # tags had landed, and --update --check contradicted it a second later.
    # If -V shows a verdict at all, the verdict must be true: so when online
    # it now runs the SAME check as --update --check (rc_check, which also
    # refreshes the cache), and only offline does it fall back to the cache -
    # saying so, in the past tense, instead of asserting the present.
    if rc_check; then
        echo -e "$(t rc_lastcheck): $(date '+%Y-%m-%d %H:%M') — $(t doc_update_no)"
        return 0
    elif [ -n "$NEWVER" ]; then
        echo -e "$(t rc_lastcheck): $(date '+%Y-%m-%d %H:%M') — $(t doc_update_yes) ${GREEN}$NEWVER${NC}   ->   ${GREEN}$ASSIST_NAME --update${NC}"
        return 0
    fi
    # offline (or the probe failed): cached facts, worded as the past they are
    local c tag ts when
    if c="$(rc_cached)"; then
        tag="${c%%|*}"; ts="${c##*|}"
        when="$(date -d "@$ts" '+%Y-%m-%d' 2>/dev/null) ($(rc_age_human "$ts"))"
        if [ "$(ver_cmp "$tag" "$(glia_effective_tag)")" = 1 ]; then
            echo -e "$(t rc_offline_v) $when — ${GREEN}${tag#v}${NC} $(t rc_stale_yes)   ->   ${GREEN}$ASSIST_NAME --update${NC}"
        else
            echo -e "$(t rc_offline_v) $when — $(t rc_stale_ok)"
        fi
    else
        echo -e "$(t rc_lastcheck): $(t rc_never)"
    fi
}

# --- --channel command ---
set_channel() {
    case "${1:-}" in
        ""|show|status)
            echo -e "${BLUE}$(t rc_channel):${NC} $(chan_get)"
            echo "$(t rc_chan_expl)" ;;
        stable)
            chan_set stable
            echo -e "${GREEN}$(t rc_chan_set) stable${NC}"
            show_equiv "echo stable > ${GLIA_CHANNEL_FILE/#$HOME/\~}" ;;
        beta)
            chan_set beta
            echo -e "${YELLOW}$(t rc_chan_beta_warn)${NC}"
            echo -e "${GREEN}$(t rc_chan_set) beta${NC}"
            show_equiv "echo beta > ${GLIA_CHANNEL_FILE/#$HOME/\~}" ;;
        *)
            echo -e "${RED}$(t rc_chan_bad)${NC}" >&2; return 1 ;;
    esac
}

# --- update-availability probe (kept name; now tag/channel based) ---
net_update_status() {
    # ONLINE. Sets NEWVER; returns 0 up-to-date / 1 newer / 2 offline.
    NEWVER=""
    rc_check
}
# ================= end Release channels (Part E) =================

# ollama_host_is_local <value> - true if OLLAMA_HOST still means "this machine".
# Ollama accepts it in several shapes: "host", "host:port", "http://host:port",
# and a bare ":11434" (port only = local). Strip the scheme, drop the port, and
# judge the host. 0.0.0.0 is in the local list on purpose: it is what you set
# to make the SERVER listen on every interface, and as a client target it still
# means this machine - warning about it would be crying wolf (see D5).
ollama_host_is_local() {
    local h="${1#*://}"      # drop scheme, if any
    h="${h%%/*}"             # drop any path
    case "$h" in
        \[*\]*) h="${h%%]*}"; h="${h#[}" ;;   # [::1]:11434 -> ::1
        *:*)    h="${h%%:*}" ;;               # host:port    -> host
    esac
    case "$h" in
        ""|localhost|127.0.0.1|127.*|::1|0.0.0.0) return 0 ;;
        *) return 1 ;;
    esac
}

# gpu_backend_probe - shared by --doctor (D6a) and `-m bench` (D6b): sets
# BP_GTYPE (nvidia|amd|intel|none), BP_GNAME, BP_HWFOUND (1 if glia-hardware
# ran), BP_VULKAN/BP_CUDA/BP_ROCM (0/1). Backend presence is checked on the
# real .so files under /usr/lib/ollama, walked RECURSIVELY: a flat listing
# misses ollama-vulkan's own library, which sits one folder down
# (vulkan/libggml-vulkan.so) - eval-backend.sh's own flat `ls` has this gap.
gpu_backend_probe() {
    local hwjson
    BP_GTYPE="none"; BP_GNAME=""; BP_HWFOUND=0
    if command -v glia-hardware >/dev/null 2>&1; then
        BP_HWFOUND=1
        hwjson=$(glia-hardware -j 2>/dev/null)
        BP_GTYPE=$(sed -n 's/.*"gpu_type":"\([^"]*\)".*/\1/p' <<< "$hwjson")
        BP_GNAME=$(sed -n 's/.*"gpu_name":"\([^"]*\)".*/\1/p'  <<< "$hwjson")
        [ -z "$BP_GTYPE" ] && BP_GTYPE="none"
    fi
    BP_VULKAN=0; find /usr/lib/ollama -iname 'libggml-vulkan.so' 2>/dev/null | grep -q . && BP_VULKAN=1
    BP_CUDA=0;   find /usr/lib/ollama -iname 'libggml-cuda.so'   2>/dev/null | grep -q . && BP_CUDA=1
    BP_ROCM=0;   find /usr/lib/ollama -iname 'libggml-hip*.so'   2>/dev/null | grep -q . && BP_ROCM=1
}

# gpu_backend_pkg_hint <cuda|rocm|vulkan> - D6a: install hint for --doctor's
# GPU/backend check. pacman splits GPU backends into real packages
# (ollama-vulkan/-cuda/-rocm, verified in the CachyOS/Arch repos); other
# package managers do not split the same way (the official installer at
# ollama.com auto-detects CUDA/ROCm at install time instead), so we do not
# invent a package name for them there - the honest answer is "check upstream".
gpu_backend_pkg_hint() {
    local pkg
    case "$1" in
        cuda)   pkg="ollama-cuda" ;;
        rocm)   pkg="ollama-rocm" ;;
        vulkan) pkg="ollama-vulkan" ;;
    esac
    case "$PKGMGR" in
        pacman) pkg_install_cmd "$pkg" ;;
        *)      t doc_gpu_pkg_unknown ;;
    esac
}

doctor() {
    local fails=0 mname avail need
    doc_line() {   # $1 = 0 ok / 1 fail, $2 = label, $3 = hint on failure
        if [ "$1" -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} $2"
        else
            echo -e "  ${RED}✗${NC} $2${3:+   -> $3}"
            fails=$((fails+1))
        fi
    }
    # v2.18: output grouped in four sections. Checks that pass stay visible
    # (proof they ran); the MODEL check is the one exception: a green line per
    # model was noise, so it only speaks when the model is missing. Skipping
    # the check entirely would make the doctor blind, so it still runs.
    echo -e "${BLUE}=== $(t doc_title) ===${NC}"
    echo -e "${YELLOW}$(t doc_sec_tools)${NC}"
    command -v aichat >/dev/null 2>&1;  doc_line $? "$(t doc_aichat)" "$(pkg_install_cmd aichat)"
    command -v jq >/dev/null 2>&1;      doc_line $? "$(t doc_jq)" "$(pkg_install_cmd jq)"
    command -v w3m >/dev/null 2>&1;     doc_line $? "$(t doc_w3m)" "$(pkg_install_cmd w3m)"
    command -v ollama >/dev/null 2>&1;  doc_line $? "$(t doc_ollama)" "https://ollama.com/download"
    command -v git >/dev/null 2>&1;     doc_line $? "$(t doc_git)" "$(pkg_install_cmd git)"
    echo
    echo -e "${YELLOW}$(t doc_sec_engine)${NC}"
    curl -fsS --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1
    doc_line $? "$(t doc_api)" "systemctl start ollama"
    mname="${MODEL#ollama:}"
    case "$mname" in *:*) : ;; *) mname="$mname:latest" ;; esac
    if ! curl -fsS --max-time 5 "$OLLAMA_URL/api/tags" 2>/dev/null | grep -q "\"$mname\""; then
        doc_line 1 "$(t doc_model)" "ollama pull ${MODEL#ollama:}"
    fi
    avail=$(ram_free_mb)
    need=$(ram_needed_mb)
    [ -n "$avail" ] && [ "$avail" -ge "$need" ]
    doc_line $? "$(t doc_ram) (${avail:-?} MB / ~${need} MB)" "glia-hardware"
    # The chat window, as a diagnostic: nothing is broken, but "why is my chat
    # only 8k?" deserves an answer that is not "read the source". Free: the
    # probe is /api/show plus arithmetic, no model load, no sudo. It lives in
    # its own function precisely so it is NOT stuck behind `-m bench`, which
    # exits early on any machine without an Intel iGPU.
    if command -v jq >/dev/null 2>&1 && \
       curl -fsS --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
        chat_ctx_probe "${MODEL#ollama:}"
        echo -e "  ${YELLOW}i${NC} $(t doc_chat_ctx): ${GREEN}$(chat_ctx_line)${NC}"
    fi
    # D1's residue, inverted (v2.19.2). GLIA is a local-engine program by
    # decision, not by accident (see docs/ROADMAP.md, D1: DROPPED) - so it
    # ignores OLLAMA_HOST. Ignoring it SILENTLY is the bug: in one shell,
    # `ollama list` answers from the server and `glia -m` from localhost, and
    # neither says why. Not a failure - nothing is broken, this is by design -
    # so it is a diagnostic line, like the tag-fallback one.
    if [ -n "${OLLAMA_HOST:-}" ] && ! ollama_host_is_local "$OLLAMA_HOST"; then
        echo -e "  ${YELLOW}i${NC} $(t doc_ohost) ${GREEN}$OLLAMA_HOST${NC}"
        echo -e "    $(t doc_ohost_why)"
    fi
    echo
    echo -e "${YELLOW}$(t doc_sec_gpu)${NC}"
    # D6a (2026-07-17): the --doctor half of D6 - read-only, no backend is
    # ever flipped here (that is `-m bench`, D6b, later). Dedicated GPU with
    # no matching backend is the safe, worth-it advice; an Intel iGPU is the
    # opposite (measured 4.5x slower on ours - see docs/design/bench-gpu-
    # 2026-07-17.txt), so it is only ever mentioned, never recommended.
    gpu_backend_probe
    if [ "$BP_HWFOUND" -eq 0 ]; then
        echo -e "  ${BLUE}i${NC} $(t doc_gpu_nohw)"
    else
        local gtype="$BP_GTYPE" gname="$BP_GNAME" has_vulkan="$BP_VULKAN" has_cuda="$BP_CUDA" has_rocm="$BP_ROCM"
        local igpu_on want backend_label gok
        case "$gtype" in
            nvidia|amd)
                if [ "$gtype" = nvidia ]; then want=cuda; backend_label="CUDA"; gok=$has_cuda
                else                            want=rocm; backend_label="ROCm"; gok=$has_rocm
                fi
                [ "$gok" -eq 1 ]
                doc_line $? "$(t doc_gpu_dedicated) $gname ($backend_label)" "$(gpu_backend_pkg_hint "$want")"
                ;;
            intel)
                if [ "$has_vulkan" -eq 1 ]; then
                    igpu_on=0
                    systemctl show ollama --property=Environment 2>/dev/null \
                        | grep -q 'OLLAMA_IGPU_ENABLE=1' && igpu_on=1
                    echo -e "  ${BLUE}i${NC} $(t doc_gpu_igpu_have) $gname"
                    if [ "$igpu_on" -eq 1 ]; then
                        echo -e "    $(t doc_gpu_igpu_enabled)"
                    else
                        echo -e "    $(t doc_gpu_igpu_dropped)"
                    fi
                else
                    echo -e "  ${BLUE}i${NC} $(t doc_gpu_igpu_none) $gname"
                fi
                ;;
            *)
                echo -e "  ${BLUE}i${NC} $(t doc_gpu_none)"
                ;;
        esac
    fi
    echo
    echo -e "${YELLOW}$(t doc_sec_paths)${NC}"
    command -v "$ASSIST_NAME" >/dev/null 2>&1
    doc_line $? "$(t doc_name)" "cp bin/glia ~/.local/bin/  (+ echo \$PATH)"
    # v2.18.3: a nickname from before v2.18.2 may still be burying a real
    # command. --rename blocks this going forward; doctor is what closes the
    # case backwards, for the installs that already have one.
    local shadows sname spath slink
    shadows="$(rename_shadow_scan)"
    if [ -z "$shadows" ]; then
        doc_line 0 "$(t doc_shadow_ok)"
    else
        while IFS=$'\t' read -r sname spath slink; do
            [ -n "$sname" ] || continue
            doc_line 1 "$(t doc_shadow_bad) '$sname' -> $spath" "rm -f ${slink/#$HOME/\~}"
        done <<< "$shadows"
        echo -e "    ${YELLOW}$(t doc_shadow_exp)${NC}"
    fi
    mkdir -p "$LOGDIR" "$HOME/.config/glia" 2>/dev/null \
        && [ -w "$LOGDIR" ] && [ -w "$HOME/.config/glia" ]
    doc_line $? "$(t doc_dirs)" "ls -ld $LOGDIR ~/.config/glia"
    mkdir -p "$(dirname "$PMODE_LOG")" 2>/dev/null \
        && { [ ! -e "$PMODE_LOG" ] || [ -w "$PMODE_LOG" ]; } && [ -w "$(dirname "$PMODE_LOG")" ]
    doc_line $? "$(t doc_pmode_log)" "ls -ld $(dirname "$PMODE_LOG")"
    # --- release channel / self-update (Part E, v2.17) ---
    # Informational only: never counted as failures. The repo probe below is
    # the ONLY network touch in doctor.
    echo
    echo -e "${YELLOW}$(t doc_sec_release)${NC}"
    local dsrc blist nback=0 cc cts
    dsrc="$(realpath "$0" 2>/dev/null)"
    echo -e "  ${BLUE}i${NC} $(t doc_rc_version) ${GREEN}$VERSION${NC}   [$(glia_effective_tag)]   ($(t rc_channel): $(chan_get))"
    echo -e "  ${BLUE}i${NC} $(t doc_rc_source) ${dsrc/#$HOME/\~}"
    # The tag record missing or stale is a DIAGNOSTIC, not a failure: it is the
    # normal state of a fresh install, and it explains which tag we compare with.
    if tag_is_fallback; then
        echo -e "  ${BLUE}i${NC} $(t rc_tag_fallback) ${GREEN}v$VERSION${NC}"
        echo -e "    $(t rc_tag_fallback_fix) ${GLIA_INSTALLED_TAG_FILE/#$HOME/\~}"
    fi
    if [ -d "$GLIA_VERSIONS_DIR" ]; then
        blist="$(for d in "$GLIA_VERSIONS_DIR"/*/; do [ -f "$d/glia" ] && basename "$d"; done \
                 | rc_sort_versions | tac | paste -sd' ' -)"
        nback="$(printf '%s' "$blist" | wc -w)"
    fi
    if [ "$nback" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} $(t doc_rc_backups) $blist"
    else
        echo -e "  ${BLUE}i${NC} $(t doc_rc_nobackups)"
    fi
    if ! net_online; then
        echo -e "  ${YELLOW}i${NC} $(t doc_offline)"
    else
        echo -e "  ${GREEN}✓${NC} $(t doc_net)"
        net_update_status
        case $? in
            0) echo -e "  ${GREEN}✓${NC} $(t doc_update_no)   (${NEWTAG:-?})" ;;
            1) echo -e "  ${YELLOW}↑${NC} $(t doc_update_yes) ${GREEN}$NEWVER${NC}   ->   ${GREEN}$ASSIST_NAME --update${NC}" ;;
            *) echo -e "  ${YELLOW}i${NC} $(t rc_notags)" ;;
        esac
    fi
    if cc="$(rc_cached)"; then
        cts="${cc##*|}"
        echo -e "  ${BLUE}i${NC} $(t rc_lastcheck): $(date -d "@$cts" '+%Y-%m-%d %H:%M' 2>/dev/null) ($(rc_age_human "$cts"))"
    else
        echo -e "  ${BLUE}i${NC} $(t rc_lastcheck): $(t rc_never)"
    fi
    echo
    if [ "$fails" -eq 0 ]; then
        echo -e "${GREEN}$(t doc_all_ok)${NC}"
    else
        echo -e "${YELLOW}$fails $(t doc_issues)${NC}"
    fi
    return "$fails"
}

