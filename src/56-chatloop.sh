# ---- /web: the net INTO the conversation (v3.1) ----

chat_web_cmd() {
    # /web <question> - grab a piece of the web WITHOUT leaving the chat.
    # The collection is the -ws pipeline (w3m asks the engine): NO AI, so
    # the chat model never moves, no swap, and the dialogue stays exactly
    # where it is - the fear of "freezing the chat to go search" dissolves
    # because nothing needs freezing. The results enter the conversation
    # as a marked block, like a die roll: the tool brings a FACT, the
    # model uses it at your NEXT message. Refused in source mode: there
    # the document is the only truth, both promises cannot hold at once.
    local q="$*" ctx
    [ -z "$q" ] && { echo "$(t cw_usage)"; return 1; }
    if [ -n "${CHAT_SOURCE_FILE:-}" ]; then
        echo -e "${YELLOW}$(t cw_source)${NC}"; return 1
    fi
    web_deps_ok || return 1
    echo -e "${BLUE}$(t cw_searching)${NC}"
    ctx="$(build_web_context "$q" 0)"
    [ -z "$ctx" ] && { echo -e "${YELLOW}$(t cw_nores)${NC}"; return 1; }
    printf '%s\n' "$ctx"   # the \n is HERE: $(...) ate the trailing one (the usual suspect)
    CHAT_MSGS=$(jq -c --arg c "$(t cw_frame) \"$q\":

$ctx
$(t cw_frame2)" '. + [{role:"user",content:$c}]' <<<"$CHAT_MSGS")
    echo -e "${GREEN}$(t cw_added)${NC}"
}

# ---- /compatta: shrink without starting over (v3.2) ----

chat_compact_cmd() {
    # The middle way between the red bar and /nuova. The model SUMMARIZES
    # the dialogue, then the conversation becomes: base (sheet/memory or
    # source, untouched) + the summary MARKED as a summary + the last 2
    # exchanges VERBATIM - the immediate thread stays exact, "e quindi?"
    # keeps working. Compaction is LOSSY by definition and SAYS so; the
    # full text is saved to a .md FIRST (safety net before scissors), the
    # inference is declared, and on any failure nothing is touched.
    local n req summary tail
    n=$(jq length <<<"$CHAT_MSGS")
    # system + 4 kept verbatim: below 7 there is nothing worth squeezing
    if [ "$n" -le 7 ]; then echo "$(t cc_empty)"; return 1; fi
    echo -e "${BLUE}$(t cc_saving)${NC}"
    chat_save
    echo -e "${BLUE}$(t cc_working)${NC}"
    req=$(jq -cn --arg m "${MODEL#ollama:}" --argjson h "$CHAT_MSGS" --argjson n "$CHAT_CTX" \
              --arg p "$(t cc_sumprompt)$(nothink)" \
          '{model:$m, messages:($h + [{role:"user",content:$p}]), stream:false,
            options:{num_ctx:$n}}')
    summary=$(curl -fsS --max-time 300 "$OLLAMA_URL/api/chat" -d "$req" 2>/dev/null \
              | jq -r '.message.content // empty' \
              | sed -z 's/<think>.*<\/think>//g')
    summary="${summary#"${summary%%[![:space:]]*}"}"
    if [ -z "$summary" ]; then
        echo -e "${RED}$(t cc_fail)${NC}"; return 1
    fi
    tail=$(jq -c '.[-4:]' <<<"$CHAT_MSGS")
    CHAT_MSGS=$(jq -c --arg s "$(t cc_sumhead)

$summary" --argjson tail "$tail" '[.[0], {role:"user",content:$s}] + $tail' <<<"$CHAT_MSGS")
    echo -e "${GREEN}$(t cc_done)${NC}"
}

chat_help() {
    case "$UILANG" in
    it) cat <<EOF
Modalità chat - $ASSIST_NAME -c  (forma lunga: --chat)

A cosa serve:
  --ask risponde UNA volta e finisce lì. -c invece tiene TUTTO il dialogo
  e lo rimanda al modello a ogni turno: "e su Debian?" viene capito perché
  la domanda di prima è ancora lì. È la differenza tra chiedere a uno
  sconosciuto e parlare con qualcuno che ti sta davvero ascoltando.

Come si usa:
  $ASSIST_NAME -c                  entra in chat
  $ASSIST_NAME -c <domanda>        entra e fa subito la prima domanda
  poi scrivi al prompt e premi Invio · frecce su/giù = messaggi precedenti

Comandi dentro la chat:
  /esci      esci (anche /exit, /quit o Ctrl+D)
  /nuova     riparti da zero (contesto azzerato)
  /salva     salva tutto in un file .md
  /modello   cambia IA al volo, SOLO per questa chat: il default resta
  /contesto  cosa c'è nella base e quanto costa · /contesto <nome> on|off
  /ricorda   salva un fatto · /memoria elenca · /scorda <n> toglie
  /dadi 2d6  tira i dadi NELLA frase, senza IA: "palla di fuoco da /dadi 8d6"
             arriva al modello col risultato già dentro — tu tiri, l'IA narra
  /web <domanda>  un dato dal web SENZA uscire dalla chat: la raccolta è
             la stessa di -ws (w3m, niente IA, il modello non si muove),
             i risultati entrano nel dialogo con le fonti [n] e il modello
             li usa dal tuo prossimo messaggio. Non in modalità fonte.
  /fonte <file>  SOLO quel documento come base di conoscenza: per studiare o
             per un GdR con le tue regole. Scheda e memoria sospese (meno
             allucinazioni, più spazio), l'IA cita il testo · /fonte off
             All'avvio: $ASSIST_NAME -c --fonte <file> [prima domanda]
  /compatta  la via di mezzo tra la barra rossa e /nuova: prima salva TUTTO
             in un .md (la rete di sicurezza), poi il modello riassume e la
             conversazione diventa base + riassunto (marcato come tale) +
             ultimi 2 scambi testuali. Un riassunto perde qualcosa per
             definizione, e costa un'inferenza: entrambe le cose dichiarate.
  /aiuto     promemoria dei comandi

La barra sotto ogni risposta:
  [████░░░░░░░░░░░░░░░░] 21% · 1.7k/8.2k tok · turno 3 · qwen2.5-coder:7b
  È la finestra che si riempie: token VERI contati da Ollama, non stime.
  Verde = tranquillo · giallo = oltre metà · rosso = il modello sta per
  scordare l'inizio: /salva e poi /nuova.

Perché non parte da 0%:
  Perché la base occupa spazio, e la barra non mente per farsi bella. La
  base è fatta di blocchi che puoi vedere e spegnere:
    help     la scheda comandi: è ciò che stampa "$ASSIST_NAME -h", passato
             all'IA. Senza, il modello NON sa cosa sia $ASSIST_NAME e ti
             inventa i flag. Non è una copia scritta a mano: è la stessa
             funzione, quindi non può andare fuori sincrono.
    memory   i fatti di --remember
  /contesto li misura (token veri, chiesti al motore) e li spegne:
    /contesto help off      la scheda non entra più, in questa e nelle
                            prossime chat. Su una macchina piccola si fa
                            una volta e non ci si pensa più.

La finestra si regola da sola:
  CHAT_NUM_CTX="auto" (default) chiede al MODELLO quanto regge e la tara
  sulla RAM libera: due limiti, vince il più piccolo. La riga all'ingresso
  dice sempre quale ha vinto. Vuoi decidere tu? Metti un numero al posto di
  "auto" in testa allo script e comanda quello.
  Perché non un numero fisso: la v2.20 aveva 8192 scritto a mano e la
  macchina su cui è nata ne regge 32768 - quattro volte tanto. Lo stesso
  script gira su un server da 4 GB: un numero fisso è sbagliato per
  qualcuno per forza.

La memoria:
  /ricorda scrive nella STESSA memoria di --remember: un fatto salvato qui
  domani c'è in tutte le modalità. Per questo non salva niente da solo -
  ogni fatto si paga in ogni prompt futuro, e deve deciderlo chi paga.

Differenze dalle altre modalità:
  $ASSIST_NAME <frase>   propone ed esegue COMANDI (con conferma)
  $ASSIST_NAME --ask     una risposta secca, poi esce
  $ASSIST_NAME -c        discussione vera, il contesto resta
EOF
        ;;
    de) cat <<EOF
Chat-Modus - $ASSIST_NAME -c  (lange Form: --chat)

Wozu:
  --ask antwortet EINMAL und ist fertig. -c behält den GANZEN Dialog und
  schickt ihn dem Modell bei jeder Runde mit: "und auf Debian?" wird
  verstanden, weil die Frage davor noch da ist. Der Unterschied zwischen
  einem Fremden und jemandem, der wirklich zuhört.

Verwendung:
  $ASSIST_NAME -c                  Chat öffnen
  $ASSIST_NAME -c <Frage>          öffnen und gleich die erste Frage stellen
  dann am Prompt schreiben und Enter · Pfeile hoch/runter = frühere Eingaben

Befehle im Chat:
  /ende       beenden (auch /exit, /quit oder Strg+D)
  /neu        von vorn beginnen (Kontext geleert)
  /speichern  alles in eine .md-Datei sichern
  /modell     KI wechseln, NUR für diesen Chat: der Standard bleibt
  /kontext    was in der Basis steckt und was es kostet · /kontext <Name> on|off
  /merken     einen Fakt sichern · /gedaechtnis auflisten · /vergiss <n>
  /wuerfel 2d6  würfelt IM Satz, ohne KI: "Feuerball für /wuerfel 8d6" erreicht
              das Modell mit dem Ergebnis schon drin — du würfelst, die KI erzählt
  /suche <Frage>  ein Datum aus dem Web OHNE den Chat zu verlassen: das
              Sammeln ist dasselbe wie -ws (w3m, keine KI, das Modell
              bleibt geladen), die Ergebnisse gehen mit Quellen [n] in den
              Dialog. Nicht im Quellen-Modus.
  /quelle <Datei>  NUR dieses Dokument als Wissensbasis: zum Lernen oder für
              ein Rollenspiel mit eigenen Regeln. Blatt und Gedächtnis
              pausiert, die KI zitiert den Text · /quelle off
              Beim Start: $ASSIST_NAME -c --fonte <Datei> [erste Frage]
  /kompakt    der Mittelweg zwischen rotem Balken und /neu: erst wird ALLES
              in eine .md gesichert (das Sicherheitsnetz), dann fasst das
              Modell zusammen - Basis + Zusammenfassung (als solche markiert)
              + letzte 2 Wechsel im Wortlaut. Eine Zusammenfassung verliert
              per Definition etwas und kostet eine Inferenz: beides gesagt.
  /hilfe      Übersicht der Befehle

Der Balken unter jeder Antwort:
  [████░░░░░░░░░░░░░░░░] 21% · 1.7k/8.2k tok · Runde 3 · qwen2.5-coder:7b
  Das Fenster füllt sich: ECHTE Token von Ollama, keine Schätzung.
  Grün = entspannt · gelb = über der Hälfte · rot = das Modell vergisst
  gleich den Anfang: /speichern, dann /neu.

Warum nicht bei 0%:
  Weil die Basis Platz braucht und der Balken nicht schönfärbt. Die Basis
  besteht aus Blöcken, die du sehen und abschalten kannst:
    help     das Befehlsblatt: genau das, was "$ASSIST_NAME -h" ausgibt, an
             die KI weitergereicht. Ohne das weiß das Modell NICHT, was
             $ASSIST_NAME ist, und erfindet Flags. Keine Handkopie: dieselbe
             Funktion, also kann sie nicht auseinanderlaufen.
    memory   die Fakten aus --remember
  /kontext misst sie (echte Token, bei der Engine erfragt) und schaltet ab:
    /kontext help off       das Blatt bleibt draußen, jetzt und künftig.

Das Fenster regelt sich selbst:
  CHAT_NUM_CTX="auto" (Standard) fragt das MODELL, wie viel es trägt, und
  passt es an den freien RAM an: zwei Grenzen, die kleinere gewinnt. Die
  Zeile beim Start sagt immer, welche. Lieber selbst bestimmen? Statt "auto"
  eine Zahl oben ins Skript, und die gilt.

Unterschied zu den anderen Modi:
  $ASSIST_NAME <Satz>    schlägt BEFEHLE vor und führt sie aus (mit Frage)
  $ASSIST_NAME --ask     eine einzelne Antwort, dann Schluss
  $ASSIST_NAME -c        echtes Gespräch, der Kontext bleibt
EOF
        ;;
    *) cat <<EOF
Chat mode - $ASSIST_NAME -c  (long form: --chat)

What it is for:
  --ask answers ONCE and is done. -c keeps the WHOLE dialogue and sends it
  back to the model at every turn: "and on Debian?" is understood because
  the previous question is still there. The difference between asking a
  stranger and talking to someone who is actually listening.

How to use it:
  $ASSIST_NAME -c                  open the chat
  $ASSIST_NAME -c <question>       open it and ask the first question now
  then type at the prompt and press Enter · up/down arrows = earlier input

Commands inside the chat:
  /exit      quit (also /quit or Ctrl+D)
  /new       start over (context cleared)
  /save      save everything to a .md file
  /model     switch AI on the fly, THIS chat only: the default stays
  /context   what is in the base and what it costs · /context <name> on|off
  /remember  store a fact · /memory lists · /forget <n> drops one
  /roll 2d6  rolls dice IN the sentence, no AI: "fireball for /roll 8d6"
             reaches the model with the result already in — you roll, the AI narrates
  /web <question>  a piece of the web WITHOUT leaving the chat: the
             collection is the same as -ws (w3m, no AI, the model stays
             loaded), the results join the dialogue with [n] sources.
             Not in source mode.
  /source <file>  ONLY that document as the knowledge base: for studying, or
             an RPG with house rules. Sheet and memory suspended, the AI
             cites the text · /source off
             At launch: $ASSIST_NAME -c --fonte <file> [first question]
  /compact   the middle way between the red bar and /new: EVERYTHING is
             saved to a .md first (the safety net), then the model
             summarizes - base + summary (marked as such) + last 2
             exchanges verbatim. A summary loses something by definition
             and costs one inference: both said out loud.
  /help      command reminder

The bar under every answer:
  [████░░░░░░░░░░░░░░░░] 21% · 1.7k/8.2k tok · turn 3 · qwen2.5-coder:7b
  The window filling up: REAL tokens counted by Ollama, not estimates.
  Green = relaxed · yellow = past half · red = the model is about to
  forget the beginning: /save, then /new.

Why it does not start at 0%:
  Because the base takes room, and the bar does not lie to look pretty. The
  base is made of blocks you can see and switch off:
    help     the command sheet: exactly what "$ASSIST_NAME -h" prints, handed
             to the AI. Without it the model does NOT know what $ASSIST_NAME
             is and will invent flags. Not a hand-written copy: the same
             function, so it cannot fall out of sync.
    memory   the facts from --remember
  /context measures them (real tokens, asked of the engine) and drops them:
    /context help off       the sheet stays out, now and in future chats.
                            On a small machine you do it once and forget it.

The window tunes itself:
  CHAT_NUM_CTX="auto" (default) asks the MODEL how much it can take and fits
  it to the free RAM: two limits, the smaller one wins. The line at startup
  always says which one did. Want to decide yourself? Put a number instead of
  "auto" at the top of the script and that number rules.
  Why not a fixed number: v2.20 shipped 8192 by hand and the machine it was
  written on takes 32768 - four times more. The same script runs on a 4 GB
  server: a fixed number is wrong for somebody by construction.

The memory:
  /remember writes to the SAME memory --remember uses: a fact stored here is
  there tomorrow in every mode. That is why nothing is saved on its own -
  every fact is paid for in every future prompt, and whoever pays decides.

How it differs from the other modes:
  $ASSIST_NAME <phrase>  proposes and runs COMMANDS (with confirmation)
  $ASSIST_NAME --ask     one plain answer, then it exits
  $ASSIST_NAME -c        a real discussion, the context stays
EOF
        ;;
    esac
}

chat_mode() {
    # $1 = optional first question (glia -c why is my disk full)
    local line first="${1:-}" reply piece chunk used=0 turn=0 sys req err waiting
    command -v jq >/dev/null 2>&1 || { echo -e "${RED}$(t chat_need_jq)${NC}" >&2; exit 1; }
    [ -t 0 ] || { echo -e "${YELLOW}$(t chat_tty)${NC}" >&2; exit 1; }
    check_ai
    # the window belongs to the model and the machine, not to a constant
    chat_ctx_probe "${MODEL#ollama:}"
    # a source given at launch (glia -c --fonte <file>) loads HERE, after
    # the probe: the size check needs to know the real window first. If it
    # does not fit, better to stop now than to open a chat that lies.
    if [ -n "${CHAT_SOURCE_PENDING:-}" ]; then
        chat_source_load "$CHAT_SOURCE_PENDING" || exit 1
        CHAT_SOURCE_PENDING=""
    fi
    sys="$(chat_sysmsg)"
    CHAT_MSGS=$(jq -cn --arg s "$sys" '[{role:"system",content:$s}]')
    echo -e "${BLUE}$(t chat_hint)${NC}"
    # what is in the base, by name. NOT its token cost: that needs a call to
    # the engine, and paying a model load just to open the chat is a bad trade
    # - /contesto measures it for real the moment you ask.
    echo -e "${BLUE}$(chat_ctx_line) · $(t chat_ctx_base) $(chat_blocks_on)${NC}"
    while true; do
        if [ -n "$first" ]; then
            line="$first"; first=""
            printf '%s> %s\n' "$(t chat_prompt)" "$line"
        else
            IFS= read -r -e -p "$(t chat_prompt)> " line || { echo; break; }
            history -s -- "$line" 2>/dev/null
        fi
        # Green tools resolve FIRST (v2.24): /dadi 2d6 anywhere in the line
        # becomes its result before anything else looks at it. A line that is
        # ONLY a roll goes to the model like any sentence - the master rolled,
        # the AI narrates. History keeps what you typed, not the expansion.
        line="$(chat_tools_expand "$line")"
        case "$line" in
            "")                          continue ;;
            /esci|/exit|/quit|/ende)     break ;;
            /nuova|/new|/neu)
                CHAT_MSGS=$(jq -cn --arg s "$sys" '[{role:"system",content:$s}]')
                used=0; turn=0
                echo -e "${GREEN}$(t chat_cleared)${NC}"; continue ;;
            /salva|/save|/speichern)     chat_save; continue ;;
            /modello|/model|/modell)     chat_model_cmd ""; sys="$(chat_sysmsg)"
                                         CHAT_MSGS=$(jq -c --arg s "$sys" '.[0].content=$s' <<<"$CHAT_MSGS")
                                         continue ;;
            '/modello '*|'/model '*|'/modell '*)
                                         chat_model_cmd "${line#* }"; sys="$(chat_sysmsg)"
                                         CHAT_MSGS=$(jq -c --arg s "$sys" '.[0].content=$s' <<<"$CHAT_MSGS")
                                         continue ;;
            # every command that changes the base rebuilds the system message
            # RIGHT HERE. Saving a fact the model cannot see until the next
            # chat would be the worst way to fail: it looks like it worked.
            /contesto|/context|/kontext) chat_ctx_cmd ""; continue ;;
            '/contesto '*|'/context '*|'/kontext '*)
                                         set -- ${line#* }
                                         chat_ctx_cmd "${1:-}" "${2:-}" || true
                                         sys="$(chat_sysmsg)"
                                         CHAT_MSGS=$(jq -c --arg s "$sys" '.[0].content=$s' <<<"$CHAT_MSGS")
                                         continue ;;
            '/ricorda '*|'/remember '*|'/merken '*)
                                         chat_mem_cmd "${line#* }" || true
                                         sys="$(chat_sysmsg)"
                                         CHAT_MSGS=$(jq -c --arg s "$sys" '.[0].content=$s' <<<"$CHAT_MSGS")
                                         continue ;;
            /ricorda|/remember|/merken)  echo "$(t chat_mem_usage)"; continue ;;
            /memoria|/memory|/gedaechtnis)
                                         show_memory; continue ;;
            '/scorda '*|'/forget '*|'/vergiss '*)
                                         chat_forget_cmd "${line#* }" || true
                                         sys="$(chat_sysmsg)"
                                         CHAT_MSGS=$(jq -c --arg s "$sys" '.[0].content=$s' <<<"$CHAT_MSGS")
                                         continue ;;
            /scorda|/forget|/vergiss)    echo "$(t forget_usage)"; continue ;;
            /compatta|/compact|/kompakt) chat_compact_cmd || true; continue ;;
            '/scegli '*|'/pick '*|'/waehle '*)
                # a draw with a variable list cannot live inline (where
                # would it end?), so it is a command: result shown AND
                # dropped into the dialogue - the tool brings the fact.
                if res_pick="$(pick_cmd ${line#* })"; then
                    echo -e "${GREEN}${res_pick}${NC}"
                    CHAT_MSGS=$(jq -c --arg c "$(t pick_frame) ${line#* } ${res_pick}" \
                        '. + [{role:"user",content:$c}]' <<<"$CHAT_MSGS")
                fi
                continue ;;
            /scegli|/pick|/waehle)       echo "$(t pick_usage)"; continue ;;
            '/web '*|'/cerca '*|'/suche '*)
                                         chat_web_cmd "${line#* }" || true; continue ;;
            /web|/cerca|/suche)          echo "$(t cw_usage)"; continue ;;
            /fonte|/source|/quelle)      chat_source_cmd ""; continue ;;
            '/fonte '*|'/source '*|'/quelle '*)
                                         chat_source_cmd "${line#* }" || true
                                         sys="$(chat_sysmsg)"
                                         CHAT_MSGS=$(jq -c --arg s "$sys" '.[0].content=$s' <<<"$CHAT_MSGS")
                                         continue ;;
            /aiuto|/help|/hilfe|/\?)     chat_cmds_help; continue ;;
            /*)                          echo "$(t chat_badcmd)"; continue ;;
        esac
        turn=$((turn+1))
        CHAT_MSGS=$(jq -c --arg c "$line$(nothink)" '. + [{role:"user",content:$c}]' <<<"$CHAT_MSGS")
        req=$(jq -cn --arg m "${MODEL#ollama:}" --argjson h "$CHAT_MSGS" --argjson n "$CHAT_CTX" \
              '{model:$m, messages:$h, stream:true, options:{num_ctx:$n}}')
        reply=""; err=""; waiting=1
        printf '%s' "$(t thinking)" >&2        # erased at the first token
        # NDJSON stream: one JSON object per line. jq runs once per chunk
        # (the hot path); the full parse happens only on error/final lines,
        # recognized by a cheap string match first.
        while IFS= read -r chunk; do
            [ -z "$chunk" ] && continue
            case "$chunk" in '{"error'*)
                err=$(jq -r '.error // empty' <<<"$chunk"); break ;;
            esac
            piece=$(jq -rj '.message.content // empty' <<<"$chunk")
            if [ -n "$piece" ]; then
                [ "$waiting" = 1 ] && { printf '\r\033[K' >&2; waiting=0; }
                reply+="$piece"; printf '%s' "$piece"
            fi
            case "$chunk" in *'"done":true'*)
                used=$(jq -r '(.prompt_eval_count // 0) + (.eval_count // 0)' <<<"$chunk") ;;
            esac
        done < <(curl -sN --max-time 600 "$OLLAMA_URL/api/chat" -d "$req" 2>/dev/null)
        [ "$waiting" = 1 ] && printf '\r\033[K' >&2
        printf '\n'
        if [ -n "$err" ] || [ -z "$reply" ]; then
            echo -e "${RED}$(t chat_err)${NC} ${err:-Ollama}" >&2
            # drop the unanswered question, so history and reality agree
            CHAT_MSGS=$(jq -c 'del(.[-1])' <<<"$CHAT_MSGS")
            turn=$((turn-1))
            continue
        fi
        CHAT_MSGS=$(jq -c --arg c "$reply" '. + [{role:"assistant",content:$c}]' <<<"$CHAT_MSGS")
        session_add "$line" "(discussed in chat -c)"
        chat_bar "$used" "$turn"
    done
    echo "$(t chat_bye)"
    exit 0
}

