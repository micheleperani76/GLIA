# ---- source mode (/fonte, v2.25) ----

chat_blk_source() {
    # The session's single source of truth. NOT a CHAT_BLOCKS entry: loading
    # a source SUSPENDS the base (sheet, memory) instead of joining it - a
    # session aimed at one document does not need GLIA to know itself, and
    # every token saved is conversation room. Anti-invention rule same as
    # the sheet's: what is not in the document does not exist, say so.
    [ -n "${CHAT_SOURCE_FILE:-}" ] && [ -r "$CHAT_SOURCE_FILE" ] || return 0
    local doc name; doc="$(cat "$CHAT_SOURCE_FILE")"; name="${CHAT_SOURCE_FILE##*/}"
    case "$UILANG" in
    it) cat <<EOF
Sei in modalità FONTE. La tua UNICA base di conoscenza per questa sessione
è il documento qui sotto ($name). Rispondi usando SOLO ciò che c'è scritto
nel documento: se la risposta non c'è, dì chiaramente "nella fonte non c'è"
invece di inventare o di attingere ad altre conoscenze. Quando rispondi,
indica da quale parte del documento prendi la risposta.
--- inizio fonte ($name) ---
$doc
--- fine fonte ---

EOF
        ;;
    de) cat <<EOF
Du bist im QUELLEN-Modus. Deine EINZIGE Wissensbasis in dieser Sitzung ist
das Dokument unten ($name). Antworte NUR mit dem, was im Dokument steht:
fehlt die Antwort, sag klar "das steht nicht in der Quelle", statt zu
erfinden oder anderes Wissen heranzuziehen. Nenne beim Antworten die
Stelle des Dokuments, aus der du schöpfst.
--- Quelle Anfang ($name) ---
$doc
--- Quelle Ende ---

EOF
        ;;
    *) cat <<EOF
You are in SOURCE mode. Your ONLY knowledge base for this session is the
document below ($name). Answer using ONLY what is written in the document:
if the answer is not there, say clearly "it is not in the source" instead
of inventing or drawing on other knowledge. When you answer, point to the
part of the document you take the answer from.
--- source start ($name) ---
$doc
--- source end ---

EOF
        ;;
    esac
}

chat_source_load() {
    # $1 = path. Validates, ESTIMATES the cost (chars/4 - declared as an
    # estimate: the real count is one /contesto away and needs the engine),
    # refuses what cannot fit, warns when little room is left. Needs the
    # probed window (CHAT_CTX), so at launch it runs AFTER chat_ctx_probe.
    local f="$1" bytes est
    f="${f/#\~\//$HOME/}"
    [ -f "$f" ] && [ -r "$f" ] || { echo -e "${YELLOW}$(t src_nofile) $f${NC}" >&2; return 1; }
    # NUL bytes = not text. NOT grep -q $'\0': bash strings cannot hold a
    # NUL, so that pattern silently becomes "" and matches EVERY file -
    # caught by the test, invisible in review. tr is a stream, NULs are fine.
    if [ "$(head -c 8192 "$f" | LC_ALL=C tr -cd '\0' | wc -c)" -gt 0 ]; then
        echo -e "${YELLOW}$(t src_binary) $f${NC}" >&2; return 1
    fi
    bytes=$(wc -c < "$f"); est=$(( bytes / 4 ))
    if [ "$est" -gt $(( CHAT_CTX * 3 / 4 )) ]; then
        # over 3/4 of the window: even if it fit, no room to talk ABOUT it
        echo -e "${RED}$(t src_toobig) ~$est $(t src_est) $CHAT_CTX${NC}" >&2
        return 1
    fi
    CHAT_SOURCE_FILE="$f"
    echo -e "${GREEN}$(t src_loaded) ${f##*/} (~$est tok) · $(t src_susp)${NC}"
    [ "$est" -gt $(( CHAT_CTX / 2 )) ] && echo -e "${YELLOW}$(t src_warn_half)${NC}"
    return 0
}

chat_source_cmd() {
    # /fonte [file|off] - bare: status · off: back to the normal base
    case "${1:-}" in
        "")  if [ -n "${CHAT_SOURCE_FILE:-}" ]; then
                 echo -e "${BLUE}$(t src_mode) $CHAT_SOURCE_FILE${NC}"
             else
                 echo "$(t src_none)"; echo "$(t src_usage)"
             fi ;;
        off) if [ -n "${CHAT_SOURCE_FILE:-}" ]; then
                 CHAT_SOURCE_FILE=""
                 echo -e "${GREEN}$(t src_off)${NC}"
             else
                 echo "$(t src_none)"
             fi ;;
        *)   chat_source_load "$1" || return 1 ;;
    esac
}

