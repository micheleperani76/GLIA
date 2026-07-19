interactive_mode() {
    # neophyte-friendly input: read the whole request at a dedicated prompt
    # with `read -r`, so the interactive shell never parses special chars.
    # Since v2.7 it is a real REPL: request after request in the same
    # session (conversation context carries over); empty line = quit.
    local req
    check_ai
    printf '%s\n' "$(t int_hint)" >&2
    while true; do
        printf '%s> ' "$ASSIST_NAME" >&2
        IFS= read -r req || break
        [ -z "$req" ] && break
        propose_and_run "$req" || true
    done
    exit 0
}

int_help() {
    case "$UILANG" in
    it) cat <<EOF
Modalità interattiva - $ASSIST_NAME (da solo) oppure $ASSIST_NAME -i

A cosa serve:
  La shell (fish, bash, zsh) interpreta alcuni caratteri PRIMA di passarli
  a $ASSIST_NAME:   '   "   \$   |   ;   &   *   ( )   \`
  Se scrivi una frase con questi simboli sulla stessa riga del comando, la
  shell si blocca o ne cambia il senso. In modalità interattiva la richiesta
  viene letta a un prompt dedicato, dove ogni carattere è preso alla lettera.

Come si usa:
  $ASSIST_NAME              (da solo)   entra nel prompt  $ASSIST_NAME>
  $ASSIST_NAME -i           lo stesso, in forma esplicita
  poi scrivi la frase al prompt e premi Invio   ·   Invio a vuoto = esci

Quando serve:
  ogni volta che la richiesta contiene   '   "   \$   |   ;   &   *
  Esempio tipico:  mostrami l'uso del disco   (l'apostrofo rompe la shell)

Esempi (scrivili AL PROMPT $ASSIST_NAME>, non sulla riga della shell):
  mostrami l'uso del disco
  conta i file *.log nella cartella corrente
  cerca "errore 500" nei log e contali
  quanto spazio occupa \$HOME
  comprimi /etc & salvalo in /tmp

Le frasi semplici (senza simboli) puoi ancora scriverle dirette:
  $ASSIST_NAME trova i file più grandi in /home
EOF
        ;;
    de) cat <<EOF
Interaktiver Modus - $ASSIST_NAME (allein) oder $ASSIST_NAME -i

Wozu:
  Die Shell (fish, bash, zsh) interpretiert manche Zeichen, BEVOR sie an
  $ASSIST_NAME gehen:   '   "   \$   |   ;   &   *   ( )   \`
  Schreibst du einen Satz mit diesen Zeichen in dieselbe Befehlszeile,
  blockiert die Shell oder verändert den Sinn. Im interaktiven Modus wird
  die Anfrage an einem eigenen Prompt gelesen, Zeichen für Zeichen wörtlich.

Verwendung:
  $ASSIST_NAME              (allein)   öffnet den Prompt  $ASSIST_NAME>
  $ASSIST_NAME -i           dasselbe, explizit
  dann die Anfrage am Prompt eingeben und Enter   ·   leere Zeile = beenden

Wann:
  immer wenn die Anfrage   '   "   \$   |   ;   &   *   enthält
  Typisches Beispiel:  zeig mir die Plattennutzung   (Apostroph bricht die Shell)

Beispiele (am Prompt $ASSIST_NAME> eingeben, nicht in der Shell-Zeile):
  zeig mir die Plattennutzung
  zähle die *.log-Dateien im aktuellen Ordner
  suche "Fehler 500" in den Logs und zähle sie
  wie viel Platz braucht \$HOME
  komprimiere /etc & lege es in /tmp ab

Einfache Sätze (ohne Sonderzeichen) gehen weiterhin direkt:
  $ASSIST_NAME finde die größten Dateien in /home
EOF
        ;;
    *) cat <<EOF
Interactive mode - $ASSIST_NAME (alone) or $ASSIST_NAME -i

What it is for:
  The shell (fish, bash, zsh) interprets some characters BEFORE they reach
  $ASSIST_NAME:   '   "   \$   |   ;   &   *   ( )   \`
  If you type a request with these symbols on the command line, the shell
  blocks or changes its meaning. In interactive mode the request is read at
  a dedicated prompt, where every character is taken literally.

How to use it:
  $ASSIST_NAME              (alone)   opens the prompt  $ASSIST_NAME>
  $ASSIST_NAME -i           the same, explicit form
  then type the request at the prompt and press Enter   ·   empty line = quit

When you need it:
  whenever the request contains   '   "   \$   |   ;   &   *
  Typical case:  show me the disk usage   (the apostrophe breaks the shell)

Examples (type them AT the prompt $ASSIST_NAME>, not on the shell line):
  show me the disk usage
  count the *.log files in the current folder
  find "error 500" in the logs and count them
  how much space does \$HOME use
  compress /etc & save it to /tmp

Simple requests (no symbols) can still go inline:
  $ASSIST_NAME find the largest files in /home
EOF
        ;;
    esac
}

