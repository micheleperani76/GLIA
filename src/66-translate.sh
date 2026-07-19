# ============================================================
#  -T: translate a file (v2.18). The original is NEVER touched:
#  the translation lands in a NEW file next to it (README.md ->
#  README.it.md). Same preview/hint/save procedure as --new and
#  the same objective checks: a translated .md must still be
#  Markdown, a translated .sh must still pass bash -n (comments
#  and messages get translated, never the code).
# ============================================================
# chat_stream: like chat(), but the reply is PRINTED WHILE IT ARRIVES and
# also returned on stdout (v2.18). The text appearing IS the progress: a
# local model can think for a minute, and a silent terminal looks hung. No
# percentage is shown anywhere - we cannot know how much is left, and an
# invented gauge is worse than none.
# Reuses -w's streaming filter (WEB_STREAM_PY, drops <think> blocks); tee
# writes to the tty so the caller still captures the text via $(...).
chat_stream() {
    local body out tty_out="/dev/null"
    [ -t 2 ] && tty_out="/dev/tty"
    body="$(jq -n --arg m "${MODEL#ollama:}" --argjson msgs "$MSGS" \
        '{model:$m,stream:true,think:false,messages:$msgs}')"
    out="$(curl -sS --no-buffer --max-time 600 "$OLLAMA_URL/api/chat" -d "$body" 2>/dev/null \
        | python3 -c "$WEB_STREAM_PY" | tee "$tty_out")"
    [ -z "${out//[$'\n\t ']/}" ] && return 1
    printf '%s' "$out"
}

translate_help() {
    case "$UILANG" in
    it) cat <<EOF
$ASSIST_NAME -T — traduci un file

  $ASSIST_NAME -T <file>              traduce nella lingua dell'interfaccia ($UILANG)
  $ASSIST_NAME -T <file> <lingua>     traduce in quella lingua (it, en, de, ... o il nome esteso)
  $ASSIST_NAME -T help                questo aiuto

L'originale non si tocca MAI:
  la traduzione va in un file NUOVO accanto — README.md -> README.$UILANG.md — e il nome
  viene mostrato prima di scrivere. Se esiste già, ne sceglie uno libero (.$UILANG-2, ...).

Mentre traduce:
  il testo appare man mano che l'IA lo scrive (nessuna percentuale finta: si vede il lavoro).
  Alla fine: Invio = salva · r = rifai · scrivi un indizio = rifà seguendolo · s = scarta.

Controlli automatici (gli stessi di --new):
  un .md tradotto deve restare Markdown, un .sh deve passare bash -n. Se il controllo
  fallisce riprova spiegando l'errore ($PMODE_MAX_RETRIES volte), poi salva AVVISANDOTI.
  Nei file di codice traduce solo commenti e messaggi: mai codice, comandi, variabili, URL.
  File binari e file troppo grandi per il contesto vengono rifiutati, non troncati.

IA per le traduzioni:
  $ASSIST_NAME --translate-model            mostra quella attuale e apre il menu guidato
  $ASSIST_NAME --translate-model <nome>     fissa un'IA dedicata alle traduzioni
  $ASSIST_NAME --translate-model -d         torna a seguire l'IA di default
  $ASSIST_NAME -m <nome> -T <file>          usa quel modello SOLO per questa traduzione
  Senza nulla di fissato usa l'IA di default: nessun cambio di modello, nessuna attesa.

Esempi:
  $ASSIST_NAME -T README.md            (README.$UILANG.md nella lingua dell'interfaccia)
  $ASSIST_NAME -T README.md en         (README.en.md in inglese)
  $ASSIST_NAME -T backup.sh de         (commenti e messaggi in tedesco, codice intatto)
EOF
        ;;
    de) cat <<EOF
$ASSIST_NAME -T — eine Datei übersetzen

  $ASSIST_NAME -T <Datei>             übersetzt in die Sprache der Oberfläche ($UILANG)
  $ASSIST_NAME -T <Datei> <Sprache>   übersetzt in diese Sprache (it, en, de, ... oder der volle Name)
  $ASSIST_NAME -T help                diese Hilfe

Das Original wird NIE angefasst:
  die Übersetzung landet in einer NEUEN Datei daneben — README.md -> README.$UILANG.md — der
  Name wird vor dem Schreiben gezeigt. Existiert sie schon, wird ein freier Name genommen.

Während der Übersetzung:
  der Text erscheint, während die KI ihn schreibt (keine erfundene Prozentanzeige).
  Am Ende: Enter = speichern · r = neu · Hinweis schreiben = neu damit · s = verwerfen.

Automatische Prüfungen (wie bei --new):
  ein übersetztes .md muss Markdown bleiben, ein .sh muss bash -n bestehen. Schlägt die
  Prüfung fehl, wird mit erklärtem Fehler wiederholt ($PMODE_MAX_RETRIES mal), dann MIT WARNUNG
  gespeichert. In Code werden nur Kommentare und Meldungen übersetzt, nie der Code selbst.
  Binärdateien und zu große Dateien werden abgelehnt, nicht gekürzt.

KI für Übersetzungen:
  $ASSIST_NAME --translate-model            zeigt die aktuelle und öffnet das Menü
  $ASSIST_NAME --translate-model <Name>     setzt eine eigene KI für Übersetzungen
  $ASSIST_NAME --translate-model -d         folgt wieder der Standard-KI
  $ASSIST_NAME -m <Name> -T <Datei>         nutzt dieses Modell NUR für diese Übersetzung
  Ohne Festlegung wird die Standard-KI genutzt: kein Modellwechsel, keine Wartezeit.

Beispiele:
  $ASSIST_NAME -T README.md            ·   $ASSIST_NAME -T README.md en
  $ASSIST_NAME -T backup.sh de         (Kommentare und Meldungen, Code bleibt)
EOF
        ;;
    *) cat <<EOF
$ASSIST_NAME -T — translate a file

  $ASSIST_NAME -T <file>              translates into the interface language ($UILANG)
  $ASSIST_NAME -T <file> <lang>       translates into that language (it, en, de, ... or the full name)
  $ASSIST_NAME -T help                this help

The original is NEVER touched:
  the translation goes into a NEW file next to it — README.md -> README.$UILANG.md — and the
  name is shown before anything is written. If it exists, a free one is picked (.$UILANG-2, ...).

While translating:
  the text appears as the AI writes it (no invented percentage: you watch the work).
  At the end: Enter = save · r = redo · type a hint = redo following it · s = discard.

Automatic checks (the same as --new):
  a translated .md must still be Markdown, a .sh must pass bash -n. If a check fails it
  retries with the error explained ($PMODE_MAX_RETRIES times), then saves WITH A WARNING.
  In code, only comments and messages are translated: never code, commands, variables, URLs.
  Binary files and files too big for the context are refused, not truncated.

AI for translations:
  $ASSIST_NAME --translate-model            show the current one and open the guided menu
  $ASSIST_NAME --translate-model <name>     pin a dedicated AI for translations
  $ASSIST_NAME --translate-model -d         follow the default AI again
  $ASSIST_NAME -m <name> -T <file>          use that model ONLY for this translation
  With nothing pinned it uses the default AI: no model swap, no waiting.

Examples:
  $ASSIST_NAME -T README.md            ·   $ASSIST_NAME -T README.md en
  $ASSIST_NAME -T backup.sh de         (comments and messages only, code untouched)
EOF
        ;;
    esac
}

translate_lang_name() {
    case "$1" in
        it) printf 'Italian' ;;
        en) printf 'English' ;;
        de) printf 'German' ;;
        *)  printf '%s' "$1" ;;   # anything else goes to the model as-is
    esac
}

translate_out_path() {
    # $1 = source, $2 = lang code -> NEW path next to the original, never an
    # existing one (name-2, name-3, ... like --new does for folders)
    local dir base ext cand n=2
    dir="$(dirname "$1")"; base="$(basename "$1")"
    if [ "${base%.*}" != "$base" ]; then
        ext="${base##*.}"; base="${base%.*}"
        cand="$dir/$base.$2.$ext"
        while [ -e "$cand" ]; do cand="$dir/$base.$2-$n.$ext"; n=$((n+1)); done
    else
        cand="$dir/$base.$2"
        while [ -e "$cand" ]; do cand="$dir/$base.$2-$n"; n=$((n+1)); done
    fi
    printf '%s' "$cand"
}

translate_file() {
    local f="$1" lang="${2:-$UILANG}" txt tokens out lname CONTENT LINES A
    local HINTS="" tries=0 fb="" warn=""
    command -v jq >/dev/null || { echo "$(t need_jq)" >&2; exit 1; }
    [ -f "$f" ] && [ -r "$f" ] || { echo -e "${RED}$(t tr_notafile) ${f:-}${NC}" >&2; exit 1; }
    # same binary refusal as -p: translating a binary can only destroy it
    if [ -s "$f" ] && { LC_ALL=C grep -qP '\x00' "$f" 2>/dev/null \
         || [ "$(file --mime-encoding -b "$f" 2>/dev/null)" = "binary" ]; }; then
        echo -e "${RED}$(t pmv_binary)${NC}" >&2
        exit 1
    fi
    check_ai
    # dedicated translation AI (--translate-model) or one-off -m, with the
    # same shared RAM swap as -w / -p. TR_* are GLOBAL on purpose: the EXIT
    # trap must still see them on any early exit.
    TR_DEF="${MODEL#ollama:}"
    TR_TARGET="$(translate_target)"
    if [ "$TR_TARGET" != "$TR_DEF" ]; then
        echo -e "${BLUE}$(t tm_using) ${GREEN}$TR_TARGET${NC}"
        swap_in "$TR_TARGET" "$TR_DEF"
        MODEL="ollama:$TR_TARGET"
        trap 'swap_out "$TR_TARGET" "$TR_DEF"' EXIT
    fi
    txt="$(cat "$f"; printf x)"; txt="${txt%x}"
    # the model must read the file AND write it back: half budget, like the
    # -p whole-file fallback. Refused, not truncated (a mutilated input
    # produces a mutilated translation).
    tokens=$(( $(wc -c < "$f") / 4 ))
    if [ "$tokens" -gt $(( PMODE_NUM_CTX / 2 )) ]; then
        echo -e "${RED}$(t pmv_toobig)${NC}" >&2
        echo -e "  ~$tokens $(t pmv_tokens) > $(( PMODE_NUM_CTX / 2 )) $(t pmv_tokens)" >&2
        exit 1
    fi
    lname="$(translate_lang_name "$lang")"
    out="$(translate_out_path "$f" "$lang")"
    echo -e "${BLUE}$(t tr_doing)${NC} ${GREEN}${f/#$HOME/\~}${NC} -> ${GREEN}${out/#$HOME/\~}${NC}   ($lname)"
    write_log "TRANSLATE START" "$f -> $out ($lname)"
    while true; do
        MSGS='[]'
        add_msg system "You are a careful translator of files. Reply ONLY with the complete translated file content: no explanations, no markdown fences, nothing else. Preserve the structure and formatting EXACTLY. In code or scripts, translate ONLY comments and user-visible message strings: never translate code, commands, variable names, file paths or URLs."
        add_msg user "Translate the following file into ${lname}.${HINTS:+ The user adds this guidance (follow it closely): $HINTS.}${fb:+ Your previous attempt was rejected by an automatic check: $fb. Translate again and fix exactly this.}
File: $(basename "$f")
--- file content start ---
$txt
--- file content end ---
Reply ONLY with the COMPLETE translated file content."
        echo -e "${BLUE}$(t tr_working)${NC}"
        echo
        CONTENT=$(chat_stream) || { echo -e "${RED}$(t tr_fail)${NC}" >&2; exit 1; }
        echo
        CONTENT=$(strip_fences <<< "$CONTENT")
        # same objective checks and retry ladder as --new: the OUTPUT file
        # has the same extension, so the same facts must hold
        if ! newmode_check_content "$out" "$CONTENT"; then
            tries=$((tries+1))
            if [ "$tries" -le "$PMODE_MAX_RETRIES" ]; then
                echo -e "${YELLOW}$(t new_check_retry) $tries/$PMODE_MAX_RETRIES: $NEW_CHECK_ERR${NC}"
                write_log "CHECK RETRY $tries" "$out | $NEW_CHECK_ERR"
                fb="$NEW_CHECK_ERR"
                continue
            fi
            warn="$NEW_CHECK_ERR"
        else
            warn="" fb=""
        fi
        # no preview: you just watched the whole text stream by. Straight to
        # the decision.
        LINES=$(wc -l <<< "$CONTENT")
        echo -e "${BLUE}--- ($LINES lines) ---${NC}"
        [ -n "$warn" ] && echo -e "${RED}$(t new_check_warn) $warn${NC}"
        read -r -p "$(t tr_save)" A < /dev/tty || A="s"
        case "$A" in
            "")
                printf '%s\n' "$CONTENT" > "$out"
                echo -e "${GREEN}$(t saved) $out${NC}"
                if [ -n "$warn" ]; then
                    echo -e "${RED}$(t new_check_saved)${NC}"
                    write_log "TRANSLATED WITH WARNING" "$f -> $out | $warn"
                else
                    write_log "TRANSLATED" "$f -> $out ($lname)"
                fi
                return 0 ;;
            r|R) continue ;;
            s|S) echo "$(t skipped)"; write_log "TRANSLATE SKIPPED" "$f"; return 0 ;;
            *)   HINTS="${HINTS:+$HINTS; }$A"; continue ;;
        esac
    done
}

