# ---- save-last & repeat proposal (v2.2) ----
alias_has_command() {
    # 0 if some alias already stores this exact command (field 4)
    [ -f "$ALIASFILE" ] || return 1
    awk -F'\t' -v c="$1" '$4==c {f=1} END{exit !f}' "$ALIASFILE"
}

save_last() {
    # remember the last successful  request<TAB>command  (only the last one)
    mkdir -p "$LOGDIR"
    printf '%s\t%s\n' "$1" "$2" > "$LASTFILE"
}

repeat_update() {
    # upsert  key<TAB>epoch<TAB>declined  (keep the last 200 entries)
    local key="$1" ts="$2" dec="$3"
    mkdir -p "$LOGDIR"; touch "$REPEATFILE"
    { grep -vE "^$key"$'\t' "$REPEATFILE" 2>/dev/null
      printf '%s\t%s\t%s\n' "$key" "$ts" "$dec"; } > "$REPEATFILE.tmp"
    tail -n 200 "$REPEATFILE.tmp" > "$REPEATFILE"
    rm -f "$REPEATFILE.tmp"
}

maybe_propose_alias() {
    # $1 request, $2 command (already succeeded). Offer to save it as a shortcut
    # ONLY on a quick repeat (same request within REPEAT_WINDOW), once, never
    # nagging: a decline is remembered, an existing alias is never re-proposed.
    local req="$1" cmd="$2" key now prev declined line name
    [ -z "$cmd" ] && return 0
    (exec 3</dev/tty) 2>/dev/null || return 0        # need a real terminal to ask
    alias_has_command "$cmd" && return 0             # already a shortcut
    key=$(cache_key "$req")
    now=$(date +%s)
    prev=""; declined=0
    if [ -f "$REPEATFILE" ]; then
        line=$(awk -F'\t' -v k="$key" '$1==k{print; exit}' "$REPEATFILE")
        [ -n "$line" ] && { prev=$(cut -f2 <<< "$line"); declined=$(cut -f3 <<< "$line"); }
    fi
    if [ -n "$prev" ] && [ "$declined" != "1" ] && [ $((now - prev)) -le "$REPEAT_WINDOW" ]; then
        echo -e "${BLUE}$(t al_propose)${NC} ${GREEN}$cmd${NC}"
        read -r -p "$(t al_propose_q)" name < /dev/tty || name=""
        if [ -n "$name" ] && alias_valid_name "$name"; then
            alias_store "$name" "run" "" "$cmd"
        else
            [ -n "$name" ] && echo "$(t al_invalid)" >&2
            declined=1                               # said no (or invalid) -> stop asking
        fi
    fi
    repeat_update "$key" "$now" "$declined"
}

alias_save_last() {
    # turn the last successful command into a shortcut (you decide, on demand).
    # $1 = optional name; if missing, ask for it (needs a terminal).
    local name="$1" req cmd
    [ -s "$LASTFILE" ] || { echo "$(t al_save_none)"; return; }
    req=$(cut -f1 "$LASTFILE"); cmd=$(cut -f2 "$LASTFILE")
    [ -z "$cmd" ] && { echo "$(t al_save_none)"; return; }
    if alias_has_command "$cmd"; then
        echo -e "${YELLOW}$(t al_exists)${NC} $cmd"; return
    fi
    echo -e "$(t al_save_show) ${GREEN}$cmd${NC}"
    if [ -z "$name" ]; then
        (exec 3</dev/tty) 2>/dev/null || { echo "$(t al_usage)"; return 1; }
        read -r -p "$(t al_name_q)" name < /dev/tty || return 1
    fi
    [ -z "$name" ] && { echo "$(t cancelled)"; return; }
    alias_valid_name "$name" || { echo "$(t al_invalid)" >&2; return 1; }
    alias_store "$name" "run" "" "$cmd"
}

alias_help() {
    case "$UILANG" in
    it) cat <<EOF
Scorciatoie (alias) - $ASSIST_NAME -a

Cosa sono:
  una scorciatoia salva un comando che usi spesso, così lo richiami per
  nome senza interpellare l'IA (es. l'ora di Bangkok).

Comandi:
  $ASSIST_NAME -a                    elenca le scorciatoie (numerate)
  $ASSIST_NAME -a <nome|n>           esegue la scorciatoia (per nome o numero)
  $ASSIST_NAME -a add                crea guidato (chiede nome, comando, tipo)
  $ASSIST_NAME -a add <nome> <cmd>   crea al volo una scorciatoia diretta
  $ASSIST_NAME -a rm                 rimuove guidato (mostra la lista, chiedi il numero)
  $ASSIST_NAME -a rm <n|nome>        rimuove per numero o nome (con conferma)
  $ASSIST_NAME -a save               salva l'ultimo comando riuscito come scorciatoia
  $ASSIST_NAME -a edit               apre il file delle scorciatoie nell'editor
  $ASSIST_NAME -a help               questo aiuto

Due tipi:
  diretta   esegue subito il comando salvato
  con-IA    mostra il comando e chiede: Invio = usa la scorciatoia,
            a = chiedo all'IA (utile se la richiesta era poco precisa)

Esempio:
  $ASSIST_NAME -a add bangkok "TZ=Asia/Bangkok date"
  $ASSIST_NAME -a bangkok

Note:
  · nel richiamo e nella rimozione i nomi NON distinguono maiuscole/minuscole
  · la rimozione chiede sempre conferma (Invio = no)
  · se rilanci la stessa richiesta entro 10 min, a fine esecuzione ti propongo
    (una volta) di salvarla come scorciatoia; con -a save la salvi quando vuoi
  · file: $ALIASFILE
EOF
        ;;
    de) cat <<EOF
Shortcuts (Aliase) - $ASSIST_NAME -a

Was sie sind:
  ein Alias speichert einen oft genutzten Befehl, den du dann per Name
  aufrufst, ohne die KI zu fragen (z. B. die Uhrzeit von Bangkok).

Befehle:
  $ASSIST_NAME -a                    Aliase auflisten (nummeriert)
  $ASSIST_NAME -a <Name|n>           Alias ausführen (per Name oder Nummer)
  $ASSIST_NAME -a add                geführt anlegen (fragt Name, Befehl, Typ)
  $ASSIST_NAME -a add <Name> <cmd>   direkt einen Alias anlegen
  $ASSIST_NAME -a rm                 geführt entfernen (Liste, dann Nummer)
  $ASSIST_NAME -a rm <n|Name>        per Nummer oder Name entfernen (mit Bestätigung)
  $ASSIST_NAME -a save               letzten erfolgreichen Befehl als Shortcut speichern
  $ASSIST_NAME -a edit               Alias-Datei im Editor öffnen
  $ASSIST_NAME -a help               diese Hilfe

Zwei Typen:
  direkt    führt den gespeicherten Befehl sofort aus
  mit-KI    zeigt den Befehl und fragt: Enter = Alias verwenden,
            a = KI fragen (nützlich bei unklarer Anfrage)

Beispiel:
  $ASSIST_NAME -a add bangkok "TZ=Asia/Bangkok date"
  $ASSIST_NAME -a bangkok

Hinweise:
  · beim Aufruf und Entfernen sind Namen NICHT case-sensitiv
  · das Entfernen fragt immer nach (Enter = nein)
  · wiederholst du dieselbe Anfrage binnen 10 min, schlage ich am Ende (einmal)
    vor, sie als Shortcut zu speichern; mit -a save speicherst du jederzeit
  · Datei: $ALIASFILE
EOF
        ;;
    *) cat <<EOF
Shortcuts (aliases) - $ASSIST_NAME -a

What they are:
  an alias saves a command you use often, so you recall it by name
  without asking the AI (e.g. the time in Bangkok).

Commands:
  $ASSIST_NAME -a                    list aliases (numbered)
  $ASSIST_NAME -a <name|n>           run an alias (by name or number)
  $ASSIST_NAME -a add                create it guided (asks name, command, type)
  $ASSIST_NAME -a add <name> <cmd>   create a direct alias in one go
  $ASSIST_NAME -a rm                 remove it guided (shows the list, asks the number)
  $ASSIST_NAME -a rm <n|name>        remove by number or name (with confirmation)
  $ASSIST_NAME -a save               save the last successful command as a shortcut
  $ASSIST_NAME -a edit               open the aliases file in your editor
  $ASSIST_NAME -a help               this help

Two kinds:
  direct    runs the saved command immediately
  with-AI   shows the command and asks: Enter = use the alias,
            a = ask the AI (handy when the request was fuzzy)

Example:
  $ASSIST_NAME -a add bangkok "TZ=Asia/Bangkok date"
  $ASSIST_NAME -a bangkok

Notes:
  · on recall and removal, names are NOT case-sensitive
  · removal always asks for confirmation (Enter = no)
  · repeat the same request within 10 min and I offer (once) to save it as a
    shortcut when it finishes; use -a save to save it whenever you want
  · file: $ALIASFILE
EOF
        ;;
    esac
}

