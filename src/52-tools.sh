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
    # roll, the AI narrates. Since v3.3 each tool declares how many words
    # it eats (argc): /conv takes three (100 mi km), the others one - the
    # regex repeats {argc} times, so the tool never bites into your prose.
    # The result is printed to stderr too, in green - your fact, seen by
    # you before the model sees the sentence. An invalid expression warns
    # and stays as typed: a tool must not eat your words.
    local line="$1" entry aliases fn argc out pre tok rest res
    local -a args
    for entry in "${CHAT_TOOLS[@]}"; do
        IFS='=' read -r aliases fn argc <<< "$entry"; out=""
        while [[ "$line" =~ /($aliases)([[:space:]]+[^[:space:]]+){$argc} ]]; do
            tok="${BASH_REMATCH[0]}"
            pre="${line%%"$tok"*}"; line="${line#*"$tok"}"
            read -r _ rest <<< "$tok"          # drop the /alias, keep the args
            read -ra args <<< "$rest"
            if res="$("$fn" "${args[@]}")"; then
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


# ---- the green toolbox (v3.3): -R -X --conv --days --pw --pick ----
# Tools, not features: each one is a small, deterministic, NO-AI command
# that works alone at the prompt AND inside the integrations (the chat
# expands /caso, /calc, /conv, /giorni in place, like /dadi). The model
# is bad at arithmetic and randomness; these never are. One tool = one
# function here + one dispatch arm + one line in the registries.

rand_roll() {
    # $1 = N (1..N) or A-B. The institutional cousin of the dice: same
    # kernel entropy (shuf), none of the RPG flavour.
    local expr="$1" a b
    if [[ "$expr" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        a="${BASH_REMATCH[1]}"; b="${BASH_REMATCH[2]}"
    elif [[ "$expr" =~ ^([0-9]+)$ ]]; then
        a=1; b="${BASH_REMATCH[1]}"
    else
        echo -e "${YELLOW}$(t rand_bad) $expr${NC}" >&2; return 1
    fi
    if [ "$a" -ge "$b" ] || [ "$b" -gt 1000000000 ]; then
        echo -e "${YELLOW}$(t rand_bad) $expr${NC}" >&2; return 1
    fi
    printf '%s-%s → %s\n' "$a" "$b" "$(shuf -i "$a"-"$b" -n1)"
}

calc_eval() {
    # $1 = arithmetic expression, evaluated by awk - NOT bc: bc is not
    # installed everywhere (this very machine proved it), awk is POSIX
    # and already carries --conv. Letters are refused OUTRIGHT: no names
    # means no functions, no variables, no surprises - a calculator that
    # only knows numbers cannot be talked into anything. Commas become
    # dots (Italian fingers type 1,5), ^ is power, % is modulo.
    local expr="${1//,/.}" out
    if ! [[ "$expr" =~ ^[0-9+*/().^%[:space:]-]+$ ]]; then
        echo -e "${YELLOW}$(t calc_bad) $1${NC}" >&2; return 1
    fi
    out=$(awk "BEGIN{printf \"%.6f\", $expr}" 2>/dev/null)
    case "$out" in ''|*inf*|*nan*) echo -e "${YELLOW}$(t calc_bad) $1${NC}" >&2; return 1 ;; esac
    # trim trailing zeros (2.440000 -> 2.44, 3.000000 -> 3)
    out=$(sed -E 's/(\.[0-9]*[1-9])0+$/\1/; s/\.0+$//' <<<"$out")
    printf '%s = %s\n' "$1" "$out"
}

conv_unit() {
    # <unit> -> "category factor-to-base", or nothing if unknown.
    # One table, symbols only (km not "chilometri"): predictable beats
    # clever. Bases: m, kg, l, m2, m/s, byte, J, Pa, s. Temperatures are
    # formulas, not factors: handled apart in conv_eval.
    case "$1" in
        mm)   echo "len 0.001" ;;      cm)  echo "len 0.01" ;;
        m)    echo "len 1" ;;          km)  echo "len 1000" ;;
        in)   echo "len 0.0254" ;;     ft)  echo "len 0.3048" ;;
        yd)   echo "len 0.9144" ;;     mi)  echo "len 1609.344" ;;
        nmi)  echo "len 1852" ;;
        mg)   echo "mass 0.000001" ;;  g)   echo "mass 0.001" ;;
        kg)   echo "mass 1" ;;         t)   echo "mass 1000" ;;
        oz)   echo "mass 0.0283495" ;; lb)  echo "mass 0.453592" ;;
        st)   echo "mass 6.35029" ;;
        ml)   echo "vol 0.001" ;;      cl)  echo "vol 0.01" ;;
        l)    echo "vol 1" ;;          m3)  echo "vol 1000" ;;
        floz) echo "vol 0.0295735" ;;  cup) echo "vol 0.24" ;;
        pt)   echo "vol 0.473176" ;;   qt)  echo "vol 0.946353" ;;
        gal)  echo "vol 3.78541" ;;
        m2)   echo "area 1" ;;         km2) echo "area 1000000" ;;
        ha)   echo "area 10000" ;;     acre) echo "area 4046.86" ;;
        ft2)  echo "area 0.092903" ;;
        mps)  echo "speed 1" ;;        kmh) echo "speed 0.2777778" ;;
        mph)  echo "speed 0.44704" ;;  kn)  echo "speed 0.5144444" ;;
        b)    echo "data 1" ;;         bit) echo "data 0.125" ;;
        kb)   echo "data 1000" ;;      mb)  echo "data 1000000" ;;
        gb)   echo "data 1000000000" ;; tb) echo "data 1000000000000" ;;
        kib)  echo "data 1024" ;;      mib) echo "data 1048576" ;;
        gib)  echo "data 1073741824" ;; tib) echo "data 1099511627776" ;;
        j)    echo "en 1" ;;           kj)  echo "en 1000" ;;
        cal)  echo "en 4.184" ;;       kcal) echo "en 4184" ;;
        wh)   echo "en 3600" ;;        kwh) echo "en 3600000" ;;
        pa)   echo "press 1" ;;        hpa) echo "press 100" ;;
        kpa)  echo "press 1000" ;;     bar) echo "press 100000" ;;
        mbar) echo "press 100" ;;      atm) echo "press 101325" ;;
        psi)  echo "press 6894.76" ;;  mmhg) echo "press 133.322" ;;
        s)    echo "time 1" ;;         min) echo "time 60" ;;
        h)    echo "time 3600" ;;      d)   echo "time 86400" ;;
        w)    echo "time 604800" ;;
        *)    return 1 ;;
    esac
}

conv_eval() {
    # $1=value $2=from $3=to. Same category or refusal - converting kg
    # into km is a question the tool must not pretend to answer.
    local v="${1//,/.}" from to c1 f1 c2 f2
    from="$(tr 'A-Z' 'a-z' <<<"$2")" to="$(tr 'A-Z' 'a-z' <<<"$3")"
    [[ "$v" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || { echo -e "${YELLOW}$(t conv_bad) $1${NC}" >&2; return 1; }
    # temperatures first: formulas, not factors
    case "$from:$to" in
        c:f) awk -v v="$v" 'BEGIN{printf "%.6g °C = %.6g °F\n", v, v*9/5+32}'; return 0 ;;
        f:c) awk -v v="$v" 'BEGIN{printf "%.6g °F = %.6g °C\n", v, (v-32)*5/9}'; return 0 ;;
        c:k) awk -v v="$v" 'BEGIN{printf "%.6g °C = %.6g K\n", v, v+273.15}'; return 0 ;;
        k:c) awk -v v="$v" 'BEGIN{printf "%.6g K = %.6g °C\n", v, v-273.15}'; return 0 ;;
        f:k) awk -v v="$v" 'BEGIN{printf "%.6g °F = %.6g K\n", v, (v-32)*5/9+273.15}'; return 0 ;;
        k:f) awk -v v="$v" 'BEGIN{printf "%.6g K = %.6g °F\n", v, (v-273.15)*9/5+32}'; return 0 ;;
        c:c|f:f|k:k) printf '%s %s = %s %s\n' "$v" "$from" "$v" "$to"; return 0 ;;
    esac
    read -r c1 f1 <<<"$(conv_unit "$from")" || true
    read -r c2 f2 <<<"$(conv_unit "$to")"   || true
    [ -z "$c1" ] && { echo -e "${YELLOW}$(t conv_unk) $from${NC} $(t conv_list)" >&2; return 1; }
    [ -z "$c2" ] && { echo -e "${YELLOW}$(t conv_unk) $to${NC} $(t conv_list)" >&2; return 1; }
    if [ "$c1" != "$c2" ]; then
        echo -e "${YELLOW}$(t conv_mix) ($from ≠ $to)${NC}" >&2; return 1
    fi
    awk -v v="$v" -v f1="$f1" -v f2="$f2" -v a="$from" -v b="$to" \
        'BEGIN{printf "%.6g %s = %.6g %s\n", v, a, v*f1/f2, b}'
}

days_eval() {
    # $1 = date (YYYY-MM-DD, or DD/MM/YYYY - Italian fingers again).
    # "How far is that day?" answered by date(1), which never guesses.
    local d="$1" ts today diff wd
    [[ "$d" =~ ^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$ ]] && \
        d="${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}"
    ts=$(date -d "$d" +%s 2>/dev/null) || { echo -e "${YELLOW}$(t days_bad) $1${NC}" >&2; return 1; }
    today=$(date -d "$(date +%F)" +%s)
    diff=$(( (ts - today) / 86400 ))
    wd=$(date -d "$d" +%A)
    if   [ "$diff" -gt 0 ]; then printf '%s (%s) → %s %s %s\n' "$1" "$wd" "$(t days_in)" "$diff" "$(t days_days)"
    elif [ "$diff" -lt 0 ]; then printf '%s (%s) → %s %s\n' "$1" "$wd" "$(( -diff ))" "$(t days_ago)"
    else printf '%s (%s) → %s\n' "$1" "$wd" "$(t days_today)"
    fi
}

days_cmd() {
    # --days <date> [date2]: one date = distance from today; two dates =
    # the span between them, sign included.
    local a="$1" b="${2:-}" t1 t2
    if [ -n "$b" ]; then
        [[ "$a" =~ ^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$ ]] && a="${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}"
        [[ "$b" =~ ^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$ ]] && b="${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}"
        t1=$(date -d "$a" +%s 2>/dev/null) || { echo -e "${YELLOW}$(t days_bad) $1${NC}" >&2; return 1; }
        t2=$(date -d "$b" +%s 2>/dev/null) || { echo -e "${YELLOW}$(t days_bad) $2${NC}" >&2; return 1; }
        printf '%s → %s: %s %s\n' "$1" "$2" "$(( (t2 - t1) / 86400 ))" "$(t days_days)"
    else
        days_eval "$a"
    fi
}

pw_cmd() {
    # --pw [len|uuid]. Passwords are born HERE, from /dev/urandom, and
    # nowhere near a model: a secret that transits an AI context is not
    # a secret. This tool is deliberately NOT available in the chat.
    local n="${1:-20}"
    if [ "$n" = "uuid" ]; then cat /proc/sys/kernel/random/uuid; return 0; fi
    [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 8 ] && [ "$n" -le 128 ] \
        || { echo -e "${YELLOW}$(t pw_bad)${NC}" >&2; return 1; }
    LC_ALL=C tr -dc 'A-Za-z0-9!@#%+=_.-' < /dev/urandom | head -c "$n"; echo
}

pick_cmd() {
    # --pick [-n K] item item ... : draw K (default 1). The institutional
    # "who does the dishes": same shuf, zero drama.
    local k=1
    if [ "${1:-}" = "-n" ]; then k="${2:-1}"; shift 2; fi
    [ "$#" -ge 2 ] || { echo -e "${YELLOW}$(t pick_usage)${NC}" >&2; return 1; }
    [[ "$k" =~ ^[0-9]+$ ]] && [ "$k" -ge 1 ] && [ "$k" -le "$#" ] \
        || { echo -e "${YELLOW}$(t pick_usage)${NC}" >&2; return 1; }
    printf '→ %s\n' "$(shuf -n "$k" -e "$@" | paste -sd, | sed 's/,/, /g')"
}

tools_help() {
    case "$UILANG" in
    it) cat <<EOF
Tool green - $ASSIST_NAME --tools  (comandi SENZA IA: istantanei, deterministici)

Perché esistono: il modello coi numeri e col caso sbaglia, questi mai.
Ognuno funziona da solo al prompt E dentro la chat (-c), dove si scrive
nella frase e si risolve sul posto — il tool porta il fatto, l'IA ragiona.

  $ASSIST_NAME -D 2d6           dadi GdR: 1d4, 2d6, d20, 1d100+4 (-D help)
  $ASSIST_NAME -R 100           numero casuale 1-100 · -R 5-50 nel range
  $ASSIST_NAME -X "340*1.22"    calcolatrice (awk): = 414.8 · virgola ok
  $ASSIST_NAME --conv 100 mi km conversioni: lunghezze, masse, °C/°F/K,
                                volumi, aree, velocità, GB/GiB, energia,
                                pressioni, tempo (elenco: --conv help)
  $ASSIST_NAME --days 2026-12-25  quanti giorni mancano (o sono passati),
                                e che giorno era · due date = differenza
  $ASSIST_NAME --pw 16          password da /dev/urandom · --pw uuid
  $ASSIST_NAME --pick a b c     sorteggio · --pick -n 2 ne estrae due

In chat: /dadi 2d6 · /caso 100 · /calc 340*1.22 · /conv 100 mi km ·
/giorni 2026-12-25 dentro la frase; /scegli a b c come comando.
/pw NON esiste in chat, di proposito: una password che passa dal
contesto di un modello non è più un segreto.

Unità di --conv:
  lunghezze  mm cm m km in ft yd mi nmi     masse  mg g kg t oz lb st
  temperature c f k                          volumi ml cl l m3 floz cup pt qt gal
  aree       m2 km2 ha acre ft2              velocità mps kmh mph kn
  dati       b bit kb mb gb tb kib mib gib tib
  energia    j kj cal kcal wh kwh            pressioni pa hpa kpa bar mbar atm psi mmhg
  tempo      s min h d w
EOF
        ;;
    de) cat <<EOF
Grüne Tools - $ASSIST_NAME --tools  (Befehle OHNE KI: sofort, deterministisch)

Warum es sie gibt: das Modell irrt bei Zahlen und Zufall, diese nie.
Jedes funktioniert allein am Prompt UND im Chat (-c), mitten im Satz,
an Ort und Stelle gelöst — das Tool bringt den Fakt, die KI denkt.

  $ASSIST_NAME -D 2d6           Rollenspiel-Würfel: 1d4, 2d6, d20 (-D help)
  $ASSIST_NAME -R 100           Zufallszahl 1-100 · -R 5-50 im Bereich
  $ASSIST_NAME -X "340*1.22"    Taschenrechner (awk): = 414.8 · Komma ok
  $ASSIST_NAME --conv 100 mi km Umrechnungen: Längen, Massen, °C/°F/K,
                                Volumen, Flächen, Tempo, GB/GiB, Energie,
                                Druck, Zeit (Liste: --conv help)
  $ASSIST_NAME --days 2026-12-25  wie viele Tage hin (oder her), und
                                welcher Wochentag · zwei Daten = Abstand
  $ASSIST_NAME --pw 16          Passwort aus /dev/urandom · --pw uuid
  $ASSIST_NAME --pick a b c     Losentscheid · --pick -n 2 zieht zwei

Im Chat: /wuerfel 2d6 · /zufall 100 · /rechne 340*1.22 · /umrechnen
100 mi km · /tage 2026-12-25 im Satz; /waehle a b c als Befehl.
/pw gibt es im Chat ABSICHTLICH nicht: ein Passwort, das durch den
Kontext eines Modells läuft, ist kein Geheimnis mehr.
EOF
        ;;
    *) cat <<EOF
Green tools - $ASSIST_NAME --tools  (commands with NO AI: instant, deterministic)

Why they exist: the model gets numbers and randomness wrong, these never do.
Each works alone at the prompt AND inside the chat (-c), written into the
sentence and resolved on the spot — the tool brings the fact, the AI thinks.

  $ASSIST_NAME -D 2d6           RPG dice: 1d4, 2d6, d20, 1d100+4 (-D help)
  $ASSIST_NAME -R 100           random number 1-100 · -R 5-50 in a range
  $ASSIST_NAME -X "340*1.22"    calculator (awk): = 414.8 · comma ok
  $ASSIST_NAME --conv 100 mi km conversions: lengths, masses, °C/°F/K,
                                volumes, areas, speeds, GB/GiB, energy,
                                pressure, time (list: --conv help)
  $ASSIST_NAME --days 2026-12-25  days until (or since), and the weekday ·
                                two dates = the span between them
  $ASSIST_NAME --pw 16          password from /dev/urandom · --pw uuid
  $ASSIST_NAME --pick a b c     draw one · --pick -n 2 draws two

In chat: /roll 2d6 · /random 100 · /calc 340*1.22 · /conv 100 mi km ·
/days 2026-12-25 inside the sentence; /pick a b c as a command.
/pw does NOT exist in chat, on purpose: a password that transits a
model's context is no longer a secret.

Units of --conv:
  length  mm cm m km in ft yd mi nmi        mass  mg g kg t oz lb st
  temp    c f k                             volume ml cl l m3 floz cup pt qt gal
  area    m2 km2 ha acre ft2                speed mps kmh mph kn
  data    b bit kb mb gb tb kib mib gib tib
  energy  j kj cal kcal wh kwh              pressure pa hpa kpa bar mbar atm psi mmhg
  time    s min h d w
EOF
        ;;
    esac
}
