# ============================================================
#  Roles (D2): which AI can be PINNED to a job. One row per role:
#      role | pinfile | help-page | flags-it-serves
#  Adding a role = adding a ROW here + its name in the three languages
#  (role_noun_<role>); plus, for the standard long flag, a three-line alias
#  wrapper. No new menu, no new cmd, no new sheet code, no new message set.
#  v2.19.1 dropped a 5th field, the message prefix (wm/pm/tm): it existed only
#  to index three copies of the same messages, and the copies are gone.
# ============================================================
ROLES=(
    "web|$WEBMODELFILE|web_help|-w"
    "project|$CODEMODELFILE|project_help|-p · --new"
    "translate|$TRANSMODELFILE|translate_help|-T"
)

# role_field <role> <2|3|4> -> pinfile | help | flags   (1/default = role name)
role_field() {
    local r rn pf hp fl
    for r in "${ROLES[@]}"; do
        IFS='|' read -r rn pf hp fl <<< "$r"
        [ "$rn" = "$1" ] || continue
        case "$2" in 2) printf '%s' "$pf" ;; 3) printf '%s' "$hp" ;;
                     4) printf '%s' "$fl" ;;
                     *) printf '%s' "$rn" ;; esac
        return 0
    done
    return 1
}

# role_norm <token> -> canonical role name, accepting the full name OR its
# first letter (web|w, project|p, translate|t). Returns 1 on an unknown token.
# The abbreviation is the initial, derived from the table - no separate list.
role_norm() {
    local r rn
    for r in "${ROLES[@]}"; do
        rn="${r%%|*}"
        [ "$1" = "$rn" ] || [ "$1" = "${rn:0:1}" ] && { printf '%s' "$rn"; return 0; }
    done
    return 1
}

# role_model_menu <role>: numbered pick, 0 = follow the default. Same body the
# old web/project/translate menus shared, driven by the role's fields.
role_model_menu() {
    local role="$1" pf list n i=0 choice sel
    pf="$(role_field "$role" 2)"
    list="$(model_names)"; [ -z "$list" ] && return 0
    echo "$(t ro_pick "$role")"
    while IFS= read -r n; do i=$((i+1)); printf "  %d) %s\n" "$i" "$n"; done <<< "$list"
    printf "  0) %s\n" "$(t ro_followopt)"
    read -r -p "$(t ro_choose) " choice < /dev/tty || return 0
    [ -z "$choice" ] && return 0
    if [ "$choice" = "0" ]; then rm -f "$pf"; echo -e "${GREEN}$(t ro_default "$role")${NC}"; return 0; fi
    sel=$(model_resolve "$choice") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; return 1; }
    mkdir -p "$(dirname "$pf")"; printf '%s\n' "$sel" > "$pf"
    echo -e "${GREEN}$(t ro_set "$role") $sel${NC}"; show_equiv "echo '$sel' > ${pf/#$HOME/\~}"
}

# role_model_cmd <role> [arg]: the generic body behind --web-model,
# --project-model and --translate-model (and, later, `-m role <role> ...`).
role_model_cmd() {
    local role="$1"; shift
    local pf hp cur sel
    pf="$(role_field "$role" 2)"; hp="$(role_field "$role" 3)"
    case "${1:-}" in
        help|-h|--help) page "$hp" ;;
        ""|show|list)
            cur="$(head -n1 "$pf" 2>/dev/null)"
            if [ -n "$cur" ]; then echo -e "$(t ro_current "$role") ${GREEN}$cur${NC}"; else echo -e "$(t ro_follow "$role")"; fi
            role_model_menu "$role" ;;
        default|-d|none|off|clear|reset)
            rm -f "$pf"; echo -e "${GREEN}$(t ro_default "$role")${NC}"; show_equiv "rm ${pf/#$HOME/\~}" ;;
        *)
            sel=$(model_resolve "$1") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; exit 1; }
            mkdir -p "$(dirname "$pf")"; printf '%s\n' "$sel" > "$pf"
            echo -e "${GREEN}$(t ro_set "$role") $sel${NC}"; show_equiv "echo '$sel' > ${pf/#$HOME/\~}" ;;
    esac
}
# role_list: the console (D2). Lists the DOWNLOADED AIs, numbered and tagged
# with the role each holds now (same numbering as `-m`), then a legend of the
# jobs and how to assign one BY NUMBER. Read-only, scriptable.
role_list() {
    local r rn rpf hp fl legend=""
    [ -z "$(model_names)" ] && { echo "$(t model_none)"; return; }
    echo "$(t role_hdr)"
    model_list_tagged
    for r in "${ROLES[@]}"; do
        IFS='|' read -r rn rpf hp fl <<< "$r"
        legend="${legend:+$legend    }$rn ($fl)"
    done
    echo "$(t role_jobs) $legend"
    echo "$(t role_ex)"
}

# role_cmd [args]: the `-m role` subconsole (D2). Grammar mirrors `-m <n>`:
#   -m role                  list the numbered AIs + who holds what
#   -m role <n|name> <role>  assign that AI to a job (role: full name or initial)
#   -m role 0 <role>         that job goes back to following the default
# The actual write is delegated to role_model_cmd, so the confirmation line and
# the show_equiv are exactly those of --web-model / --project-model / etc.
role_cmd() {
    case "${1:-}" in
        ""|list|ls)     role_list; return ;;
        help|-h|--help) page model_help; return ;;
    esac
    local who="$1" role sel
    role="$(role_norm "${2:-}")" || {
        if [ -z "${2:-}" ]; then echo -e "${YELLOW}$(t role_usage)${NC}" >&2
        else echo -e "${RED}$(t role_unknown) ${2}${NC}" >&2; echo "$(t role_valid)" >&2; fi
        exit 1
    }
    if [ "$who" = "0" ]; then
        role_model_cmd "$role" default
    else
        sel=$(model_resolve "$who") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; exit 1; }
        role_model_cmd "$role" "$sel"
    fi
}

# Public entry points (kept: the dispatch and the old flags call these).
# Each is a thin alias over the generic body above.
web_model_cmd() { role_model_cmd web "$@"; }

# which AI runs -p (projects/coding):  pinned project model  >  default
project_target() {
    local pin; pin="$(head -n1 "$CODEMODELFILE" 2>/dev/null)"
    [ -n "$pin" ] && { printf '%s' "$pin"; return; }
    printf '%s' "${MODEL#ollama:}"
}

project_model_cmd() { role_model_cmd project "$@"; }

# which AI runs -T (translations):  one-off -m  >  pinned  >  default
translate_target() {
    if [ -n "${TRANS_OVERRIDE:-}" ]; then printf '%s' "$TRANS_OVERRIDE"; return; fi
    local pin; pin="$(head -n1 "$TRANSMODELFILE" 2>/dev/null)"
    [ -n "$pin" ] && { printf '%s' "$pin"; return; }
    printf '%s' "${MODEL#ollama:}"
}

translate_model_cmd() { role_model_cmd translate "$@"; }

# web_take_prefix <query...>: an "engine:" prefix picks the engine for THIS
# search only ("-w bing: query" or "-w bing:query"); --web-engine sets the
# default. Sets WEB_ENGINE_ONEOFF and leaves the cleaned query in WEB_Q
# (globals: a subshell could not hand both back). Shared by -w, -w+ and -ws.
web_take_prefix() {
    WEB_Q="$*"
    case "$WEB_Q" in
        ddg:*|bing:*|searx:*)
            WEB_ENGINE_ONEOFF="${WEB_Q%%:*}"
            WEB_Q="${WEB_Q#*:}"; WEB_Q="${WEB_Q# }"
            ;;
    esac
}

# web_raw <query|url>: direct web access, NO model involved (v2.18).
# A query prints titles, URLs and snippets straight from the engine; a URL
# or bare domain ("www.morrolinux.it") opens that page directly, paged.
web_raw() {
    local eng wurl i=0 url title snip u
    web_take_prefix "$1"; local q="$WEB_Q"
    web_deps_ok || exit 1
    net_online || { echo -e "${RED}$(t web_noweb)${NC}" >&2; exit 1; }
    # already an address? open it, do not search it. One token, no spaces,
    # and either a scheme or a plausible domain (dot + TLD).
    if [[ "$q" != *" "* ]] && { [[ "$q" =~ ^https?:// ]] \
         || [[ "$q" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}(/.*)?$ ]]; }; then
        u="$q"
        [[ "$u" =~ ^https?:// ]] || u="https://$u"
        echo -e "${BLUE}$(t web_open)${NC} ${GREEN}$u${NC}" >&2
        show_equiv "w3m -dump '$u'" >&2
        echo -e "$(t web_open_hint) ${GREEN}w3m $u${NC}" >&2
        page w3m -dump "$u"
        write_log "WEB PAGE" "$u"
        return 0
    fi
    eng="$(web_engine)"
    wurl="$(web_engine_url "$eng" "$(web_urlenc "$q")")" \
        || { echo -e "${RED}$(t web_searx_nourl)${NC}" >&2; exit 1; }
    echo -e "${BLUE}$(t web_searching)${NC} ${GREEN}$q${NC}   ($(t we_engine): ${GREEN}$eng${NC})" >&2
    show_equiv "w3m -dump -cols $WEB_COLS '$wurl'" >&2
    echo
    while IFS=$'\t' read -r url title snip; do
        [ -z "$url" ] && continue
        i=$((i+1))
        echo -e "${GREEN}$i. $title${NC}"
        echo -e "   ${BLUE}$url${NC}"
        [ -n "$snip" ] && echo "   $snip"
        echo
    done < <(web_search "$q")
    [ "$i" -eq 0 ] && { echo -e "${RED}$(t web_noresult)${NC}" >&2; exit 1; }
    write_log "WEB RAW" "$q"
}

# web_answer <query> <deep 0|1>
web_answer() {
    local q deep="${2:-0}" pages ctx sys prompt body target def keep eng wurl
    web_take_prefix "$1"; q="$WEB_Q"
    web_deps_ok || exit 1
    net_online || { echo -e "${RED}$(t web_noweb)${NC}" >&2; exit 1; }   # v2.14.2: no net, no point
    check_ai
    eng="$(web_engine)"
    wurl="$(web_engine_url "$eng" "$(web_urlenc "$q")")" \
        || { echo -e "${RED}$(t web_searx_nourl)${NC}" >&2; exit 1; }
    def="${MODEL#ollama:}"; target="$(web_target)"
    pages="$WEB_PAGES"; [ "$deep" = 1 ] && pages="$WEB_PAGES_DEEP"
    echo -e "${BLUE}$(t web_searching)${NC} ${GREEN}$q${NC}   ($(t we_engine): ${GREEN}$eng${NC})" >&2
    [ "$target" != "$def" ] && echo -e "$(t web_using) ${GREEN}$target${NC}" >&2
    echo -e "$(t web_cmd_expl)" >&2
    show_equiv "w3m -dump -cols $WEB_COLS '$wurl'" >&2
    ctx="$(build_web_context "$q" "$pages")"
    if [ -z "$ctx" ]; then echo -e "${RED}$(t web_noresult)${NC}" >&2; exit 1; fi
    swap_in "$target" "$def"      # v2.14: free RAM only if the web model differs and won't fit
    if [ "$target" = "$def" ]; then keep="$WEB_KEEPALIVE"; else keep="5m"; fi
    sys="$(t web_sys)"
    prompt="$(t web_today) $(date +%F)."$'\n\n'"$(t web_question): $q"$'\n\n'"$(t web_sources_h):"$'\n'"$ctx"$'\n\n'"$(t web_remind)"
    # stream:true -> the answer appears while it is written; keep_alive keeps
    # the model warm so the NEXT -w skips the cold load (biggest time saver)
    # think:false -> reasoning models (e.g. gemma with a 'thinking' field) must
    # put the ANSWER in 'content', not burn all num_predict tokens reasoning and
    # leave content empty. Harmless on non-reasoning models (v2.15.3).
    body="$(jq -n --arg m "$target" --arg s "$sys" --arg p "$prompt" \
        --arg k "$keep" --argjson np "$WEB_NUMPREDICT" \
        '{model:$m,stream:true,think:false,keep_alive:$k,options:{num_predict:$np},messages:[{role:"system",content:$s},{role:"user",content:$p}]}')"
    curl -sS --no-buffer --max-time 300 "$OLLAMA_URL/api/chat" -d "$body" 2>/dev/null \
        | python3 -c "$WEB_STREAM_PY"
    swap_out "$target" "$def"     # v2.14: unload the guest, make sure the default is warm again
    write_log "WEB" "$q"
}

# --web-engine [engine] [searx-url]: show or set the default -w engine.
web_engine_cmd() {
    local e="${1:-}" u="${2:-}"
    if [ -z "$e" ]; then
        echo -e "$(t we_current) ${GREEN}$(web_engine)${NC}   (ddg | bing | searx)"
        [ -s "$SEARXURLFILE" ] && echo -e "  searx: $(head -n1 "$SEARXURLFILE")"
        return 0
    fi
    case "$e" in
        ddg|bing|searx) ;;
        *) echo -e "${RED}$(t we_bad)${NC}" >&2; return 1 ;;
    esac
    if [ "$e" = searx ]; then
        if [ -n "$u" ]; then
            mkdir -p "$(dirname "$SEARXURLFILE")"
            printf '%s\n' "${u%/}" > "$SEARXURLFILE"
            show_equiv "echo '${u%/}' > ${SEARXURLFILE/#$HOME/\~}"
        fi
        # refuse to set a default that cannot work: searx needs an instance
        [ -s "$SEARXURLFILE" ] || { echo -e "${RED}$(t web_searx_nourl)${NC}" >&2; return 1; }
    fi
    mkdir -p "$(dirname "$WEBENGINEFILE")"
    printf '%s\n' "$e" > "$WEBENGINEFILE"
    echo -e "${GREEN}$(t we_set) $e${NC}"
    show_equiv "echo '$e' > ${WEBENGINEFILE/#$HOME/\~}"
}

web_help() {
    case "$UILANG" in
    it) cat <<EOF
$ASSIST_NAME -w — ricerca sul web con fonti

  $ASSIST_NAME -w <domanda>    cerca sul web e risponde citando le fonti
  $ASSIST_NAME -w+ <domanda>   come sopra, ma legge anche le prime pagine (più lento, più dettaglio)
  $ASSIST_NAME -w bing: <domanda>   questa sola ricerca con Bing (prefissi: ddg: bing: searx:)
  $ASSIST_NAME -ws <ricerca|URL>    risultati diretti SENZA IA (veloce); con un URL apre la pagina

Motore di ricerca:
  $ASSIST_NAME --web-engine             mostra il motore attuale
  $ASSIST_NAME --web-engine bing        cambia il motore di default (ddg | bing | searx)
  $ASSIST_NAME --web-engine searx <URL> imposta l'istanza SearXNG (necessaria per searx)

Come funziona:
  - usa il browser testuale w3m per interrogare il motore scelto (nessuna chiave API)
  - il modello riassume i risultati e chiude sempre con l'elenco 'Fonti:'
  - di default legge solo gli estratti (veloce); -w+ apre le pagine intere

Impostazioni (in cima al file glia):
  WEB_REGION=$WEB_REGION   regione   ·   WEB_RESULTS=$WEB_RESULTS risultati   ·   WEB_PAGES_DEEP=$WEB_PAGES_DEEP pagine con -w+

Modello per la ricerca:
  $ASSIST_NAME -m <nome> -w <domanda>   usa quel modello SOLO per questa ricerca
  $ASSIST_NAME --web-model <nome>       IA fissa per il web (--web-model -d = segue il default)
  La RAM viene scambiata solo se serve e il modello di default viene ripristinato dopo.

Serve w3m:  $(pkg_install_cmd w3m)

Navigare il web a mano (w3m è anche un browser testuale):
  w3m example.com   —  Invio segui il link · B indietro · U apri URL · q esci

Esempi:
  $ASSIST_NAME -w quando esce la prossima LTS di Ubuntu
  $ASSIST_NAME -w+ novità del kernel linux 6.16
EOF
        ;;
    de) cat <<EOF
$ASSIST_NAME -w — Websuche mit Quellen

  $ASSIST_NAME -w <Frage>     sucht im Web und antwortet mit Quellenangabe
  $ASSIST_NAME -w+ <Frage>    wie oben, liest zusätzlich die ersten Seiten (langsamer, mehr Detail)
  $ASSIST_NAME -w bing: <Frage>    nur diese Suche mit Bing (Präfixe: ddg: bing: searx:)
  $ASSIST_NAME -ws <Suche|URL>     direkte Treffer OHNE KI (schnell); mit URL wird die Seite geöffnet

Suchmaschine:
  $ASSIST_NAME --web-engine             zeigt die aktuelle Suchmaschine
  $ASSIST_NAME --web-engine bing        wechselt den Standard (ddg | bing | searx)
  $ASSIST_NAME --web-engine searx <URL> setzt die SearXNG-Instanz (für searx nötig)

So funktioniert es:
  - nutzt den Textbrowser w3m für die gewählte Suchmaschine (kein API-Schlüssel)
  - das Modell fasst die Ergebnisse zusammen und endet immer mit 'Quellen:'
  - standardmäßig nur Auszüge (schnell); -w+ öffnet die ganzen Seiten

Einstellungen (oben in der Datei glia):
  WEB_REGION=$WEB_REGION   Region   ·   WEB_RESULTS=$WEB_RESULTS Treffer   ·   WEB_PAGES_DEEP=$WEB_PAGES_DEEP Seiten mit -w+

Modell für die Suche:
  $ASSIST_NAME -m <Name> -w <Frage>    nutzt dieses Modell NUR für diese Suche
  $ASSIST_NAME --web-model <Name>      feste KI fürs Web (--web-model -d = folgt dem Standard)
  Der RAM wird nur bei Bedarf getauscht, das Standardmodell danach wiederhergestellt.

Benötigt w3m:  $(pkg_install_cmd w3m)

Manuell surfen (w3m ist auch ein Textbrowser):
  w3m example.com   —  Enter Link folgen · B zurück · U URL öffnen · q beenden

Beispiele:
  $ASSIST_NAME -w wann erscheint die nächste Ubuntu LTS
  $ASSIST_NAME -w+ Neuerungen im Linux-Kernel 6.16
EOF
        ;;
    *) cat <<EOF
$ASSIST_NAME -w — web search with sources

  $ASSIST_NAME -w <question>    search the web and answer, citing the sources
  $ASSIST_NAME -w+ <question>   same, but also reads the top pages (slower, more detail)
  $ASSIST_NAME -w bing: <question>   this one search with Bing (prefixes: ddg: bing: searx:)
  $ASSIST_NAME -ws <search|URL>      direct results with NO AI (fast); a URL opens that page

Search engine:
  $ASSIST_NAME --web-engine             show the current engine
  $ASSIST_NAME --web-engine bing        change the default engine (ddg | bing | searx)
  $ASSIST_NAME --web-engine searx <URL> set the SearXNG instance (required for searx)

How it works:
  - uses the w3m text browser to query the chosen engine (no API key)
  - the model summarizes the results and always ends with a 'Sources:' list
  - snippets only by default (fast); -w+ opens the full pages

Settings (top of the glia file):
  WEB_REGION=$WEB_REGION   region   ·   WEB_RESULTS=$WEB_RESULTS results   ·   WEB_PAGES_DEEP=$WEB_PAGES_DEEP pages with -w+

Model for the search:
  $ASSIST_NAME -m <name> -w <question>   use that AI ONLY for this search
  $ASSIST_NAME --web-model <name>        pin an AI for the web (--web-model -d = follow default)
  RAM is swapped only if needed and the default model is restored afterwards.

Needs w3m:  $(pkg_install_cmd w3m)

Browse the web by hand (w3m is also a text browser):
  w3m example.com   —  Enter follow link · B back · U open URL · q quit

Examples:
  $ASSIST_NAME -w when is the next Ubuntu LTS due
  $ASSIST_NAME -w+ what is new in linux kernel 6.16
EOF
        ;;
    esac
}

