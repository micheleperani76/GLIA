# ---- dice roller (-D, v2.23) ----

dice_roll() {
    # $1 = [N]dM[+K|-K]  (1d4, 2d6, d20, 1d100+4). GREEN by design: no AI, no
    # network, no token - a d20 does not need a 7B model. The rolls come from
    # shuf, which draws on the kernel's entropy: $RANDOM is 15 bits and
    # modulo-biased, and a die that leans is the one thing a die must not do.
    local expr="$1" n m mod sum=0 r list=""
    if [[ "$expr" =~ ^([0-9]*)[dD]([0-9]+)([+-][0-9]+)?$ ]]; then
        n="${BASH_REMATCH[1]}"; m="${BASH_REMATCH[2]}"; mod="${BASH_REMATCH[3]}"
    else
        echo -e "${YELLOW}$(t dice_bad) $expr${NC}" >&2; return 1
    fi
    n="${n:-1}"
    if [ "$n" -lt 1 ] || [ "$n" -gt 100 ] || [ "$m" -lt 1 ] || [ "$m" -gt 10000 ]; then
        echo -e "${YELLOW}$(t dice_bad) $expr - $(t dice_limit)${NC}" >&2; return 1
    fi
    for r in $(shuf -r -n "$n" -i 1-"$m"); do
        sum=$((sum + r)); list="${list:+$list + }$r"
    done
    [ -n "$mod" ] && sum=$((sum $mod))
    if [ "$n" -eq 1 ] && [ -z "$mod" ]; then
        printf '%s → %s\n' "$expr" "$sum"           # 1d20 → 17: repeating "17 = 17" would be noise
    else
        printf '%s → %s%s = %s\n' "$expr" "$list" "${mod:+ $mod}" "$sum"
    fi
}

dice_cmd() {
    # every argument is a roll, one line each - in a game you rarely need one
    # die alone. One bad expression does not stop the others, but the exit
    # code remembers it.
    local e rc=0
    for e in "$@"; do dice_roll "$e" || rc=1; done
    return $rc
}

dice_help() {
    case "$UILANG" in
    it) cat <<EOF
Tiro di dadi - $ASSIST_NAME -D  (forma lunga: --dice)

A cosa serve:
  numeri casuali con la notazione dei giochi di ruolo, SENZA IA: niente
  modello da caricare, niente attesa, niente token. Verde per costruzione.
  I tiri escono da shuf, cioè dall'entropia del kernel: un dado che pende
  è l'unica cosa che un dado non deve fare.

Come si usa:
  $ASSIST_NAME -D 1d4          un dado da 4                →  1d4 → 3
  $ASSIST_NAME -D 2d6          due dadi da 6, tiri visibili →  2d6 → 4 + 5 = 9
  $ASSIST_NAME -D d20          l'1 davanti è opzionale
  $ASSIST_NAME -D 1d100+4      col modificatore            →  1d100+4 → 87 +4 = 91
  $ASSIST_NAME -D 2d6 1d8+2    più tiri in un colpo, una riga ciascuno

Dentro la chat (-c): /dadi 2d6 in mezzo alla frase si risolve sul posto,
e il modello riceve la frase col risultato già dentro — tu tiri, l'IA narra.

Limiti: da 1 a 100 dadi per tiro, facce da 1 a 10000, modificatore +K o -K.
EOF
        ;;
    de) cat <<EOF
Würfelwurf - $ASSIST_NAME -D  (Langform: --dice)

Wozu:
  Zufallszahlen in Rollenspiel-Notation, OHNE KI: kein Modell zu laden,
  kein Warten, kein Token. Grün per Konstruktion. Die Würfe kommen aus
  shuf, also aus der Entropie des Kernels: ein Würfel, der sich neigt,
  ist das Einzige, was ein Würfel nicht darf.

Nutzung:
  $ASSIST_NAME -D 1d4          ein W4                       →  1d4 → 3
  $ASSIST_NAME -D 2d6          zwei W6, Würfe sichtbar      →  2d6 → 4 + 5 = 9
  $ASSIST_NAME -D d20          die 1 davor ist optional
  $ASSIST_NAME -D 1d100+4      mit Modifikator              →  1d100+4 → 87 +4 = 91
  $ASSIST_NAME -D 2d6 1d8+2    mehrere Würfe auf einmal, je eine Zeile

Im Chat (-c): /wuerfel 2d6 mitten im Satz wird an Ort und Stelle gewürfelt,
und das Modell erhält den Satz mit dem Ergebnis schon drin — du würfelst,
die KI erzählt.

Grenzen: 1 bis 100 Würfel pro Wurf, 1 bis 10000 Seiten, Modifikator +K oder -K.
EOF
        ;;
    *) cat <<EOF
Dice roll - $ASSIST_NAME -D  (long form: --dice)

What it is for:
  random numbers in role-playing notation, with NO AI: no model to load,
  no waiting, no token. Green by construction. The rolls come from shuf,
  i.e. the kernel's entropy: a die that leans is the one thing a die
  must not do.

Usage:
  $ASSIST_NAME -D 1d4          one d4                      →  1d4 → 3
  $ASSIST_NAME -D 2d6          two d6, rolls visible       →  2d6 → 4 + 5 = 9
  $ASSIST_NAME -D d20          the leading 1 is optional
  $ASSIST_NAME -D 1d100+4      with a modifier             →  1d100+4 → 87 +4 = 91
  $ASSIST_NAME -D 2d6 1d8+2    several rolls at once, one line each

Inside the chat (-c): /roll 2d6 in the middle of a sentence resolves on the
spot, and the model receives the sentence with the result already in —
you roll, the AI narrates.

Limits: 1 to 100 dice per roll, 1 to 10000 sides, modifier +K or -K.
EOF
        ;;
    esac
}

chat_tools_expand() {
    # $1 = the line as typed. Echoes it with every green-tool call resolved
    # IN PLACE: "palla di fuoco da /dadi 8d6" becomes "palla di fuoco da
    # [8d6 → 3 + 5 + ... = 29]", and THAT is what the model receives: you
    # roll, the AI narrates. The roll is printed to stderr too, in green -
    # your dice, seen by you before the model sees the sentence. An invalid
    # expression warns and stays as typed: a tool must not eat your words.
    local line="$1" entry aliases fn out pre tok arg res
    for entry in "${CHAT_TOOLS[@]}"; do
        aliases="${entry%%=*}"; fn="${entry#*=}"; out=""
        while [[ "$line" =~ /($aliases)[[:space:]]+([^[:space:]]+) ]]; do
            tok="${BASH_REMATCH[0]}"; arg="${BASH_REMATCH[2]}"
            pre="${line%%"$tok"*}"; line="${line#*"$tok"}"
            if res="$("$fn" "$arg")"; then
                echo -e "${GREEN}${res}${NC}" >&2
                out+="${pre}[${res}]"
            else
                out+="${pre}${tok}"
            fi
        done
        line="${out}${line}"
    done
    printf '%s' "$line"
}

