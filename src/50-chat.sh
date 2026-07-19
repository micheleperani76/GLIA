# ============================================================
#  SECTION: chat mode (-c, v2.20) - a real conversation
# ============================================================
# --ask answers once and exits; -c keeps the WHOLE dialogue and sends it
# back at every turn, so "and on Debian?" means what it should. It talks
# to Ollama's native /api/chat directly (not aichat): that endpoint takes
# the messages array as-is, and its final streamed chunk carries the REAL
# token counts (prompt_eval_count + eval_count) - exactly what the
# saturation bar needs. In-chat commands are slash-words, so no phrase is
# ever eaten by mistake; each has localized aliases (see the case below).

# ---- the window: measured, not guessed (v2.21) ----
# Everything below asks the ENGINE and does arithmetic on the answer. Not one
# number here is remembered: layer counts and context lengths differ per model
# and per quantization, and reciting them from memory is exactly how you become
# the forum you are correcting (see v2.19.3). If the engine says nothing usable
# we fall back and SAY so - a chat that refuses to open teaches nobody anything.

CHAT_SHOW_CACHE=""; CHAT_SHOW_CACHE_MODEL=""
chat_show_info() {
    # $1 = model -> its /api/show payload, fetched once per model per run
    if [ "$CHAT_SHOW_CACHE_MODEL" = "$1" ]; then printf '%s' "$CHAT_SHOW_CACHE"; return 0; fi
    CHAT_SHOW_CACHE=$(curl -fsS --max-time 10 "$OLLAMA_URL/api/show" \
        -d "$(jq -n --arg m "$1" '{model:$m}')" 2>/dev/null)
    CHAT_SHOW_CACHE_MODEL="$1"
    printf '%s' "$CHAT_SHOW_CACHE"
}

chat_mi() {
    # $1 = model, $2 = model_info suffix (context_length, block_count, ...)
    # The keys are architecture-prefixed ("qwen2.context_length"), so we ask
    # the engine for the architecture too rather than assuming one.
    local info arch v
    info=$(chat_show_info "$1"); [ -n "$info" ] || return 1
    arch=$(jq -r '.model_info["general.architecture"] // empty' <<<"$info" 2>/dev/null)
    [ -n "$arch" ] || return 1
    v=$(jq -r --arg k "$arch.$2" '.model_info[$k] // empty' <<<"$info" 2>/dev/null)
    case "$v" in ''|*[!0-9]*) return 1 ;; esac
    [ "$v" -gt 0 ] || return 1
    printf '%s' "$v"
}

chat_kv_bytes() {
    # $1 = model -> bytes of KV cache per token:
    #   2 (K and V) x layers x kv_heads x head_dim x 2 bytes (fp16)
    # every factor straight from /api/show, so this works on the 14b, the 32b
    # and whatever gets pulled in six months - not just on today's qwen.
    local m="$1" layers kv heads emb hd
    layers=$(chat_mi "$m" block_count)             || return 1
    kv=$(chat_mi "$m" attention.head_count_kv)     || return 1
    heads=$(chat_mi "$m" attention.head_count)     || return 1
    emb=$(chat_mi "$m" embedding_length)           || return 1
    hd=$(( emb / heads )); [ "$hd" -gt 0 ] || return 1
    printf '%d' $(( 2 * layers * kv * hd * 2 ))
}

# Set by chat_ctx_probe, read by the bar, /contesto, --doctor and -m bench.
CHAT_CTX=0            # the window we actually ask Ollama for
CHAT_CTX_WHY=""       # config | model | cap | ram | fallback - WHY that number
CHAT_CTX_MODELMAX=0   # what the model says it can take
CHAT_CTX_RAMMAX=0     # what the free RAM could hold (0 = could not tell)

chat_ctx_probe() {
    # $1 = model -> resolve CHAT_CTX. Two limits, and the smaller one wins:
    # the model's own training (asking for more than that buys nonsense) and
    # the RAM (the KV cache is linear in the window; the swap is not a plan).
    local m="$1" mmax kv avail budget by_ram ctx
    CHAT_CTX_MODELMAX=0; CHAT_CTX_RAMMAX=0
    case "$CHAT_NUM_CTX" in
        auto) : ;;
        ''|*[!0-9]*) CHAT_CTX="$CHAT_CTX_FALLBACK"; CHAT_CTX_WHY="fallback"; return 0 ;;
        *) CHAT_CTX="$CHAT_NUM_CTX"; CHAT_CTX_WHY="config"; return 0 ;;   # you asked: you get it
    esac
    mmax=$(chat_mi "$m" context_length) || {
        CHAT_CTX="$CHAT_CTX_FALLBACK"; CHAT_CTX_WHY="fallback"; return 0
    }
    CHAT_CTX_MODELMAX="$mmax"
    ctx="$mmax"; CHAT_CTX_WHY="model"
    if [ "$ctx" -gt "$CHAT_CTX_CAP" ]; then ctx="$CHAT_CTX_CAP"; CHAT_CTX_WHY="cap"; fi
    if kv=$(chat_kv_bytes "$m"); then
        avail=$(ram_free_mb)
        case "$avail" in ''|*[!0-9]*) avail=0 ;; esac
        if [ "$avail" -gt 0 ]; then
            # a model already in RAM has already paid for its weights
            if model_loaded "$m"; then
                budget=$(( avail - CHAT_RAM_KEEP_MB ))
            else
                budget=$(( avail - $(ram_needed_mb "$m") - CHAT_RAM_KEEP_MB ))
            fi
            if [ "$budget" -gt 0 ]; then
                by_ram=$(( budget * 1024 * 1024 / kv ))
                CHAT_CTX_RAMMAX="$by_ram"
                [ "$by_ram" -lt "$ctx" ] && { ctx="$by_ram"; CHAT_CTX_WHY="ram"; }
            else
                CHAT_CTX_RAMMAX="$CHAT_CTX_MIN"; ctx="$CHAT_CTX_MIN"; CHAT_CTX_WHY="ram"
            fi
        fi
    fi
    ctx=$(( ctx / 1024 * 1024 ))                       # whole 1k steps
    [ "$ctx" -lt "$CHAT_CTX_MIN" ] && ctx="$CHAT_CTX_MIN"
    CHAT_CTX="$ctx"
}

chat_ctx_line() {
    # one honest line: the window and WHY it is that size
    printf '%s %s' "$(t chat_ctx_win)" "$(chat_fmt_tok "$CHAT_CTX")"
    case "$CHAT_CTX_WHY" in
        config)   printf ' (%s)' "$(t chat_why_config)" ;;
        model)    printf ' (%s)' "$(t chat_why_model)" ;;
        cap)      printf ' (%s)' "$(t chat_why_cap)" ;;
        ram)      printf ' (%s · %s %s)' "$(t chat_why_ram)" "$(t chat_why_modelmax)" "$(chat_fmt_tok "$CHAT_CTX_MODELMAX")" ;;
        fallback) printf ' (%s)' "$(t chat_why_fallback)" ;;
    esac
}

chat_fmt_tok() {
    # 12345 -> "12.3k"; below 1000 the plain number
    if [ "$1" -ge 1000 ]; then
        printf '%d.%dk' "$(($1/1000))" "$(($1%1000/100))"
    else
        printf '%d' "$1"
    fi
}

chat_bar() {
    # $1 = tokens of the LAST call (its prompt already contains the whole
    # history, so this IS the saturation), $2 = turn number. Drawn on
    # stderr, so a redirected chat transcript stays clean.
    # It shows the RAW truth, base blocks included: a fresh chat does not start
    # at 0% and that is the point - the cost is visible, and /contesto turns it
    # off. Subtracting it to look pretty would just be the bar lying quietly.
    local used=$1 turn=$2 width=20 pct fill i bar='' color
    pct=$(( used * 100 / CHAT_CTX )); [ "$pct" -gt 100 ] && pct=100
    fill=$(( pct * width / 100 ))
    for ((i=0; i<width; i++)); do
        if [ "$i" -lt "$fill" ]; then bar+='█'; else bar+='░'; fi
    done
    color=$GREEN
    [ "$pct" -ge "$CHAT_WARN_PCT" ] && color=$YELLOW
    [ "$pct" -ge "$CHAT_CRIT_PCT" ] && color=$RED
    printf '%b[%s] %d%%%b · %s/%s tok · %s %d · %s\n' \
        "$color" "$bar" "$pct" "$NC" "$(chat_fmt_tok "$used")" \
        "$(chat_fmt_tok "$CHAT_CTX")" "$(t chat_turn)" "$turn" "${MODEL#ollama:}" >&2
    [ "$pct" -ge "$CHAT_CRIT_PCT" ] && echo -e "${RED}$(t chat_full)${NC}" >&2
    return 0
}

# ---- the system message, block by block (v2.21) ----

chat_blk_help() {
    # The command sheet. NOT written by hand: show_help is what `-h` prints,
    # so the day a flag is born the chat knows it the same day. A hand copy
    # would be the SIXTH copy of the same truth (scripts/check-docs.sh exists
    # because the first five drifted) and the only one nobody could see drift
    # - the model would recite dead flags in a confident voice.
    # $1 = mode ("chat", default, or "ask"): same sheet for both, only the
    # first sentence changes - the chat holds a dialogue, --ask answers once
    # and exits, and telling the model which one it is costs one line.
    local mode="${1:-chat}" sheet intro
    sheet="$(show_help 2>/dev/null)"
    [ -n "$sheet" ] || return 0
    case "$UILANG:$mode" in
        it:ask) intro="Sei la modalità risposta secca (--ask) di $ASSIST_NAME, un assistente IA da terminale per Linux: rispondi una volta sola, senza dialogo, e sai rispondere anche su te stesso." ;;
        it:*)   intro="Sei la modalità chat di $ASSIST_NAME, un assistente IA da terminale per Linux: sai rispondere anche su te stesso." ;;
        de:ask) intro="Du bist der Einmal-Antwort-Modus (--ask) von $ASSIST_NAME, einem KI-Terminal-Assistenten für Linux: du antwortest genau einmal, ohne Dialog, und kannst auch über dich selbst Auskunft geben." ;;
        de:*)   intro="Du bist der Chat-Modus von $ASSIST_NAME, einem KI-Terminal-Assistenten für Linux: du kannst auch über dich selbst Auskunft geben." ;;
        *:ask)  intro="You are the one-shot answer mode (--ask) of $ASSIST_NAME, an AI terminal assistant for Linux: you answer once, no dialogue, and you can answer about yourself too." ;;
        *:*)    intro="You are the chat mode of $ASSIST_NAME, an AI terminal assistant for Linux: you can answer about yourself too." ;;
    esac
    case "$UILANG" in
    it) cat <<EOF
$intro Questa è la tua guida, cioè esattamente ciò
che stampa "$ASSIST_NAME -h":
--- inizio guida ---
$sheet
--- fine guida ---
Questi sono TUTTI i comandi che esistono. Se una cosa non è nell'elenco NON
esiste: dillo, invece di inventare un flag. Per i dettagli di un'area rimanda
a "$ASSIST_NAME <flag> help". Tu i comandi li spieghi, non li esegui.

EOF
        ;;
    de) cat <<EOF
$intro Das ist deine Anleitung,
genau das, was "$ASSIST_NAME -h" ausgibt:
--- Anleitung Anfang ---
$sheet
--- Anleitung Ende ---
Das sind ALLE Befehle, die es gibt. Steht etwas nicht in der Liste, dann
existiert es NICHT: sag das, statt ein Flag zu erfinden. Für Details eines
Bereichs verweise auf "$ASSIST_NAME <Flag> help". Du erklärst die Befehle,
du führst sie nicht aus.

EOF
        ;;
    *) cat <<EOF
$intro This is your guide - exactly what
"$ASSIST_NAME -h" prints:
--- guide start ---
$sheet
--- guide end ---
These are ALL the commands that exist. If something is not in the list it does
NOT exist: say so instead of inventing a flag. For the details of an area point
to "$ASSIST_NAME <flag> help". You explain the commands, you don't run them.

EOF
        ;;
    esac
}

chat_blk_memory() {
    # The stored facts. NOT memory_context(): that one ends with "otherwise act
    # on the local machine", an instruction written for the command proposer. In
    # a chat nothing gets executed, so that tail is either noise or a push
    # towards commands this mode does not run. Same facts, right job (D2 again:
    # one line doing two jobs is a drift waiting to happen).
    [ -s "$MEMFILE" ] || return 0
    local facts; facts="$(paste -sd ';' "$MEMFILE" | sed 's/;/; /g')"
    case "$UILANG" in
    it) cat <<EOF
Fatti che l'utente ti ha chiesto di ricordare, come sfondo: usali solo quando
la domanda li tocca davvero, non forzarli in ogni risposta: $facts.
EOF
        ;;
    de) cat <<EOF
Fakten, die der Nutzer dich merken ließ, als Hintergrund: nutze sie nur, wenn
die Frage sie wirklich berührt, dränge sie nicht in jede Antwort: $facts.
EOF
        ;;
    *) cat <<EOF
Facts the user asked you to remember, as background: use them only when the
question actually touches them, do not force them into every answer: $facts.
EOF
        ;;
    esac
}

chat_blk_state() {
    # $1 = block name -> on|off. The saved choice wins; otherwise the default
    # declared in CHAT_BLOCKS.
    local n="$1" b bn bd v
    v=$(awk -F= -v n="$n" '$1==n {print $2}' "$CHAT_BLOCKS_FILE" 2>/dev/null | tail -n1)
    case "$v" in on|off) printf '%s' "$v"; return 0 ;; esac
    for b in "${CHAT_BLOCKS[@]}"; do
        IFS='|' read -r bn bd _ <<< "$b"
        [ "$bn" = "$n" ] && { printf '%s' "$bd"; return 0; }
    done
    printf 'off'
}

chat_blk_set() {
    # $1 = name, $2 = on|off -> persisted: the choice outlives this chat, so a
    # small machine turns the sheet off once and never thinks about it again.
    mkdir -p "$(dirname "$CHAT_BLOCKS_FILE")"
    { grep -v "^$1=" "$CHAT_BLOCKS_FILE" 2>/dev/null; printf '%s=%s\n' "$1" "$2"; } \
        > "$CHAT_BLOCKS_FILE.tmp" && mv "$CHAT_BLOCKS_FILE.tmp" "$CHAT_BLOCKS_FILE"
}

chat_blk_known() {
    local b bn
    for b in "${CHAT_BLOCKS[@]}"; do
        IFS='|' read -r bn _ <<< "$b"
        [ "$bn" = "$1" ] && return 0
    done
    return 1
}

chat_blk_desc() {
    case "$UILANG:$1" in
        it:help)   echo "la scheda comandi (${ASSIST_NAME} -h)" ;;
        de:help)   echo "das Befehlsblatt (${ASSIST_NAME} -h)" ;;
        *:help)    echo "the command sheet (${ASSIST_NAME} -h)" ;;
        it:memory) echo "i fatti di --remember" ;;
        de:memory) echo "die Fakten aus --remember" ;;
        *:memory)  echo "the facts from --remember" ;;
        *)         echo "" ;;
    esac
}

chat_blocks_on() {
    # the enabled block names, comma separated ("nothing" if none)
    local b bn out=""
    if [ -n "${CHAT_SOURCE_FILE:-}" ]; then
        printf '%s %s' "$(t src_mode)" "${CHAT_SOURCE_FILE##*/}"; return
    fi
    for b in "${CHAT_BLOCKS[@]}"; do
        IFS='|' read -r bn _ <<< "$b"
        [ "$(chat_blk_state "$bn")" = "on" ] && out="${out:+$out, }$bn"
    done
    printf '%s' "${out:-$(t chat_ctx_none)}"
}

chat_sysmsg() {
    # the system message = the enabled blocks, in order, plus the language
    # (not a block: two words, and not optional).
    # The blank line between blocks is added HERE, not inside them: $(...)
    # eats trailing newlines, so a block ending in "\n\n" arrives glued to the
    # next one ("...you don't run them.Facts the user asked..."). Caught by
    # reading the text the model actually receives - which is the only way to
    # catch it, since nothing errors.
    local s="" b bn bf out
    # Source mode (v2.25) takes over: ONE document, nothing else. The base
    # blocks are SUSPENDED, not switched off - /fonte off brings them back
    # exactly as they were, chat-blocks state untouched.
    if [ -n "${CHAT_SOURCE_FILE:-}" ]; then
        out="$(chat_blk_source)"
        [ -n "$out" ] && s="${out}"$'\n\n'
    else
    for b in "${CHAT_BLOCKS[@]}"; do
        IFS='|' read -r bn _ bf <<< "$b"
        [ "$(chat_blk_state "$bn")" = "on" ] || continue
        out="$("$bf")"
        [ -n "$out" ] && s="${s}${out}"$'\n\n'
    done
    fi
    case "$UILANG" in
        it) s="${s}Rispondi in italiano." ;;
        de) s="${s}Antworte auf Deutsch." ;;
        *)  s="${s}Answer in English." ;;
    esac
    printf '%s' "$s"
}

chat_tok_count() {
    # $1 = text -> the REAL tokens it costs, counted by the engine.
    # Measured, not chars/4: an estimate is the kind of number we took out of
    # the bar on purpose. Note num_predict:0 does NOT stop generation (checked
    # on 2026-07-17: it answered 245 tokens anyway), so we ask for ONE token
    # and throw it away - same trick mem_warm already uses.
    local j
    j=$(curl -fsS --max-time 120 "$OLLAMA_URL/api/chat" \
        -d "$(jq -n --arg m "${MODEL#ollama:}" --arg c "$1" --argjson n "$CHAT_CTX" \
              '{model:$m, messages:[{role:"system",content:$c}], stream:false,
                options:{num_predict:1, num_ctx:$n}}')" 2>/dev/null)
    jq -r '.prompt_eval_count // empty' <<<"$j" 2>/dev/null
}

chat_ctx_cmd() {
    # /contesto [nome on|off] - what the base costs, and the switch to drop it
    local name="${1:-}" val="${2:-}" b bn bf st tok pct total
    if [ -n "$name" ]; then
        chat_blk_known "$name" || { echo -e "${YELLOW}$(t chat_blk_unknown) $name${NC}"; return 1; }
        case "$val" in
            on|off) chat_blk_set "$name" "$val"
                    echo -e "${GREEN}${name} = ${val}${NC}  $(t chat_blk_persist)" ;;
            *)      echo "$(t chat_ctx_usage)"; return 1 ;;
        esac
        return 0
    fi
    echo -e "${BLUE}$(chat_ctx_line)${NC}"
    echo "$(t chat_ctx_measuring)"
    # Source mode: the source is the whole base - measure it, remind that
    # the blocks are suspended, and skip the block table (it would list
    # things the model is NOT seeing right now, which is the bar lying).
    if [ -n "${CHAT_SOURCE_FILE:-}" ]; then
        tok=$(chat_tok_count "$(chat_blk_source)")
        case "$tok" in ''|*[!0-9]*) tok=0 ;; esac
        printf '  %-8s %-4s %6s tok  %2d%%   %s\n' "fonte" "on" "$tok" \
            "$(( tok * 100 / CHAT_CTX ))" "${CHAT_SOURCE_FILE##*/}"
        echo "  ($(t src_susp))"
        total=$(chat_tok_count "$(chat_sysmsg)")
        case "$total" in ''|*[!0-9]*) total=0 ;; esac
        printf '  %s %s tok (%d%%) · %s %s\n' "$(t chat_ctx_total)" "$total" \
            "$(( total * 100 / CHAT_CTX ))" "$(t chat_ctx_left)" "$(chat_fmt_tok $(( CHAT_CTX - total )))"
        echo "$(t src_usage)"
        return 0
    fi
    for b in "${CHAT_BLOCKS[@]}"; do
        IFS='|' read -r bn _ bf <<< "$b"
        st=$(chat_blk_state "$bn")
        if [ "$st" = "on" ]; then
            tok=$(chat_tok_count "$("$bf")")
            case "$tok" in ''|*[!0-9]*) tok=0 ;; esac
            pct=$(( tok * 100 / CHAT_CTX ))
            printf '  %-8s %-4s %6s tok  %2d%%   %s\n' "$bn" "$st" "$tok" "$pct" "$(chat_blk_desc "$bn")"
        else
            printf '  %-8s %-4s %6s      %3s   %s\n' "$bn" "$st" "-" "-" "$(chat_blk_desc "$bn")"
        fi
    done
    total=$(chat_tok_count "$(chat_sysmsg)")
    case "$total" in ''|*[!0-9]*) total=0 ;; esac
    printf '  %s %s tok (%d%%) · %s %s\n' "$(t chat_ctx_total)" "$total" \
        "$(( total * 100 / CHAT_CTX ))" "$(t chat_ctx_left)" "$(chat_fmt_tok $(( CHAT_CTX - total )))"
    echo "$(t chat_ctx_usage)"
}

chat_mem_cmd() {
    # /ricorda <fact> - the chat writes to the SAME memory --remember uses, so
    # a fact learned here is there tomorrow in every mode. It is not a chat log:
    # every fact is paid for in every future prompt, which is why nothing is
    # saved unless you type it.
    local fact="$*"
    [ -z "$fact" ] && { echo "$(t chat_mem_usage)"; return 1; }
    mkdir -p "$(dirname "$MEMFILE")"
    printf '%s\n' "$fact" >> "$MEMFILE"
    if [ "$(wc -l < "$MEMFILE")" -gt "$MEMMAX" ]; then
        tail -n "$MEMMAX" "$MEMFILE" > "$MEMFILE.tmp" && mv "$MEMFILE.tmp" "$MEMFILE"
        echo -e "${YELLOW}$(t chat_mem_capped) $MEMMAX${NC}"
    fi
    echo -e "${GREEN}$(t mem_saved)${NC} $(t chat_mem_where)"
}

chat_forget_cmd() {
    local n="$1" total fact
    if ! grep -qE '^[0-9]+$' <<< "${n:-x}" || [ ! -s "$MEMFILE" ]; then
        echo "$(t forget_usage)"; return 1
    fi
    total=$(wc -l < "$MEMFILE")
    if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then echo "$(t forget_usage)"; return 1; fi
    fact=$(sed -n "${n}p" "$MEMFILE")
    sed -i "${n}d" "$MEMFILE"
    echo -e "${GREEN}$(t forgotten)${NC} $fact"
}

chat_save() {
    # /salva -> one timestamped .md (the system message stays out)
    local n f
    n=$(jq 'map(select(.role!="system")) | length' <<<"$CHAT_MSGS")
    [ "$n" -eq 0 ] && { echo "$(t chat_nosave)"; return 0; }
    mkdir -p "$CHAT_SAVE_DIR"
    f="$CHAT_SAVE_DIR/chat-$(date +%Y%m%d-%H%M%S).md"
    {
        printf '# glia chat · %s · %s\n' "$(date '+%Y-%m-%d %H:%M')" "${MODEL#ollama:}"
        jq -r --arg u "$(t chat_you)" --arg m "${MODEL#ollama:}" \
            '.[] | select(.role!="system")
                 | "\n## " + (if .role=="user" then $u else $m end) + "\n\n" + .content' \
            <<<"$CHAT_MSGS"
    } > "$f"
    echo -e "${GREEN}$(t chat_saved)${NC} ${f/#$HOME/\~}"
}

chat_model_cmd() {
    # /modello [name|number] - switch the AI of THIS chat only. The default
    # (-m) is untouched; the old model is unloaded first, so two LLMs never
    # sit in RAM together on a small machine (the same care set_model takes).
    local q="$1" sel old="${MODEL#ollama:}"
    if [ -z "$q" ]; then
        echo "$(t model_avail)"; model_list_tagged
        read -r -p "$(t model_pick)" q || return 0
        [ -z "$q" ] && { echo "$(t model_kept)"; return 0; }
    fi
    sel=$(model_resolve "$q") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; return 1; }
    if [ "$sel" != "$old" ] && model_loaded "$old"; then mem_unload "$old"; fi
    MODEL="ollama:$sel"
    echo -e "${GREEN}$(t chat_model_now) $sel${NC}  $(t chat_model_only)"
    # a different model means a different window: the old number belonged to
    # the old AI, and the bar must not keep measuring against it
    chat_ctx_probe "$sel"
    echo -e "${BLUE}$(chat_ctx_line)${NC}"
}

chat_cmds_help() {
    # /aiuto: the short in-chat reminder (full page: glia -c help)
    case "$UILANG" in
    it) cat <<EOF
Comandi della chat (tutto il resto è conversazione):
  /esci       chiudi la chat (anche /exit, /quit o Ctrl+D)
  /nuova      riparti da zero: contesto azzerato
  /salva      salva la conversazione in un file .md (${CHAT_SAVE_DIR/#$HOME/\~})
  /modello    cambia IA al volo, solo per questa chat (/modello <nome|numero>)
  /contesto   cosa c'è nella base, quanto costa davvero, e come spegnerlo
  /ricorda    salva un fatto nella memoria condivisa (/ricorda <fatto>)
  /memoria    elenca i fatti   ·   /scorda <n>   toglie il fatto n
  /dadi 2d6   tira i dadi DOVE sta la frase, senza IA: "palla di fuoco da
              /dadi 8d6" arriva al modello col risultato già dentro (come -D)
  /caso /calc /conv /giorni   gli altri tool green, sempre NELLA frase:
              /caso 100 · /calc 340*1.22 · /conv 100 mi km · /giorni
              2026-12-25 · /scegli a b c (sorteggio, comando) · --tools
  /web <domanda>  cerca sul web SENZA uscire dalla chat (niente IA nella
              raccolta): i risultati entrano nel dialogo, con le fonti
  /fonte <file>  SOLO quel documento come base (studio, GdR con regole tue):
              scheda e memoria sospese, l'IA cita il testo · /fonte off
  /compatta   comprime la chat piena: salva TUTTO su file, poi riassume e
              tiene testuali gli ultimi 2 scambi (un riassunto perde
              qualcosa: per questo prima salva)
  /aiuto      questo promemoria
La barra sotto ogni risposta dice quanto è piena la finestra: token veri
contati da Ollama. Non parte da 0% perché la base (scheda comandi, fatti)
occupa spazio: /contesto te lo mostra misurato e te lo fa spegnere.
EOF
        ;;
    de) cat <<EOF
Chat-Befehle (alles andere ist Unterhaltung):
  /ende       Chat beenden (auch /exit, /quit oder Strg+D)
  /neu        von vorn beginnen: Kontext geleert
  /speichern  Unterhaltung in eine .md-Datei (${CHAT_SAVE_DIR/#$HOME/\~})
  /modell     KI wechseln, nur für diesen Chat (/modell <Name|Nummer>)
  /kontext    was in der Basis steckt, was es kostet, wie man es abschaltet
  /merken     einen Fakt ins gemeinsame Gedächtnis (/merken <Fakt>)
  /gedaechtnis  Fakten auflisten   ·   /vergiss <n>   entfernt Fakt n
  /wuerfel 2d6  würfelt IM Satz, ohne KI: "Feuerball für /wuerfel 8d6" erreicht
              das Modell mit dem Ergebnis schon drin (wie -D)
  /zufall /rechne /umrechnen /tage   die anderen grünen Tools, immer IM
              Satz: /zufall 100 · /rechne 340*1.22 · /umrechnen 100 mi km ·
              /tage 2026-12-25 · /waehle a b c (Los, Befehl) · --tools
  /suche <Frage>  sucht im Web OHNE den Chat zu verlassen (keine KI beim
              Sammeln): die Ergebnisse gehen in den Dialog, mit Quellen
  /quelle <Datei>  NUR dieses Dokument als Basis (Lernen, Rollenspiel mit
              eigenen Regeln): Blatt und Gedächtnis pausiert · /quelle off
  /kompakt    komprimiert den vollen Chat: sichert ALLES in eine Datei,
              fasst zusammen, behält die letzten 2 Wechsel im Wortlaut
  /hilfe      diese Übersicht
Der Balken unter jeder Antwort zeigt, wie voll das Fenster ist: echte Token
von Ollama. Er startet nicht bei 0%, weil die Basis (Befehlsblatt, Fakten)
Platz braucht: /kontext zeigt sie gemessen und schaltet sie ab.
EOF
        ;;
    *) cat <<EOF
Chat commands (everything else is conversation):
  /exit      close the chat (also /quit or Ctrl+D)
  /new       start over: context cleared
  /save      save the conversation to a .md file (${CHAT_SAVE_DIR/#$HOME/\~})
  /model     switch AI on the fly, this chat only (/model <name|number>)
  /context   what is in the base, what it really costs, how to turn it off
  /remember  store a fact in the shared memory (/remember <fact>)
  /memory    list the facts   ·   /forget <n>   drops fact n
  /roll 2d6  rolls dice WHERE the sentence is, no AI: "fireball for
             /roll 8d6" reaches the model with the result already in (as -D)
  /random /calc /conv /days   the other green tools, always IN the
             sentence: /random 100 · /calc 340*1.22 · /conv 100 mi km ·
             /days 2026-12-25 · /pick a b c (draw, command) · --tools
  /web <question>  searches the web WITHOUT leaving the chat (no AI in the
             collection): the results join the dialogue, with sources
  /source <file>  ONLY that document as the base (study, RPG with house
             rules): sheet and memory suspended, the AI cites it · /source off
  /compact   compacts a full chat: saves EVERYTHING to a file, then
             summarizes and keeps the last 2 exchanges verbatim
  /help      this reminder
The bar under every answer shows how full the window is: real tokens counted
by Ollama. It does not start at 0% because the base (command sheet, facts)
takes room: /context shows it measured and lets you switch it off.
EOF
        ;;
    esac
}

