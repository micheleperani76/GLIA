#!/usr/bin/env bash
# ============================================================
#  check-docs.sh - the parser in bin/glia is the source of truth;
#                  fail loudly when a documented surface disagrees.
#  Version: 0.1 - 2026-07-17 (framework + check #1: version coherence)
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA) - see docs/ROADMAP.md, D7
#
#  Perche': cinque copie a mano della stessa verita' (README,
#  commands.html, le due nav, le due completions, l'header) e
#  nessuna sa delle altre -> derivano. Questo comando le confronta
#  con bin/glia e si lamenta quando non tornano.
#
#  Read-only: non tocca nulla. Stampa PASS/FAIL ed esce con
#    0 = tutto allineato   1 = drift trovato   2 = errore d'uso
#
#  Uso:  scripts/check-docs.sh      (da qualsiasi punto dentro il repo)
# ============================================================
set -u

# ----------------- CONFIGURATION -----------------
# Percorsi relativi alla radice del repo (rilevata sotto).
GLIA_BIN="bin/glia"
README="README.md"
CMDS_HTML="docs/commands.html"
INDEX_HTML="docs/index.html"
COMP_BASH="completions/glia.bash"
COMP_FISH="completions/glia.fish"
# Superfici che devono elencare OGNI flag del parser (alias esclusi):
SURFACES_ALL="$README $CMDS_HTML $COMP_BASH $COMP_FISH"
# Flag deliberatamente NON offerti in tab-completion: --kaboom e' la
# disinstallazione distruttiva, tenerla lontana da <TAB> e' una scelta di
# sicurezza (resta documentata e chiede la parola di conferma prima di agire).
COMPLETION_EXEMPT=" --kaboom "
# Pattern (case-insensitive) di conferma hardcoded che NON devono comparire
# nelle pagine: la parola giusta e' localizzata ($CONFIRM_WORD / $YES_KEY).
CONFIRM_HARDCODED='(type|digit[ae]|scrivi|press|premi|tippe) +(YES|SI|JA)'
# -------------------------------------------------

# --- colori (spenti se stdout non e' un TTY) ---
if [ -t 1 ]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    BOLD=$'\033[1m'; NC=$'\033[0m'
else
    RED=; GREEN=; YELLOW=; BOLD=; NC=
fi

# --- contatori globali ---
PASS=0
FAIL=0

# --- helper di reporting ---
ok()      { PASS=$((PASS+1)); printf '  %s[OK]%s   %s\n'   "$GREEN"  "$NC" "$1"; }
bad()     { FAIL=$((FAIL+1)); printf '  %s[FAIL]%s %s\n'   "$RED"    "$NC" "$1"; }
note()    {                   printf '  %s[..]%s   %s\n'   "$YELLOW" "$NC" "$1"; }
section() {                   printf '\n%s%s%s\n'          "$BOLD"   "$1" "$NC"; }

# --- radice del repo: rifiuta con grazia se non siamo in git ---
REPO="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO" ]; then
    printf '%scheck-docs: non sono in un repo git.%s Lancialo da dentro il repo glia.\n' \
        "$RED" "$NC" >&2
    exit 2
fi
cd "$REPO" || exit 2
if [ ! -f "$GLIA_BIN" ]; then
    printf '%scheck-docs: %s non trovato%s (radice repo: %s)\n' \
        "$RED" "$GLIA_BIN" "$NC" "$REPO" >&2
    exit 2
fi

# --- confronto versioni dotted: stampa "lt", "eq" o "gt" per  a<b/a=b/a>b ---
ver_cmp() {
    [ "$1" = "$2" ] && { echo eq; return; }
    local hi
    hi="$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)"
    [ "$hi" = "$1" ] && echo gt || echo lt
}

# ============================================================
#  Check #1 - coerenza versione
#  VERSION="x.y.z" nel codice  ==  header "# Version: x.y.z"  vs  ultimo tag git
#  Il bug che pesca: header 2.17.2 mentre VERSION=2.18.0, senza changelog.
#  Nota di processo: "il tag viene per ULTIMO", quindi VERSION>tag a meta'
#  sviluppo e' normale (nota, non errore); VERSION<tag invece e' un problema.
# ============================================================
check_version() {
    section "1. Coerenza versione (VERSION = header, VERSION vs tag)"

    local v_code v_head v_tag
    v_code="$(grep -m1 -oE '^VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$GLIA_BIN" \
              | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    v_head="$(grep -m1 -E '^#[[:space:]]+Version:' "$GLIA_BIN" \
              | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    v_tag="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"

    note "codice  VERSION= : ${v_code:-(non trovato)}"
    note "header  Version: : ${v_head:-(non trovato)}"
    note "tag     git      : ${v_tag:-(nessun tag)}"

    if [ -z "$v_code" ]; then
        bad "VERSION= non trovato in $GLIA_BIN"
        return
    fi

    # header contro codice: devono SEMPRE coincidere
    if [ -z "$v_head" ]; then
        bad "riga '# Version:' non trovata nell'header di $GLIA_BIN"
    elif [ "$v_code" = "$v_head" ]; then
        ok "header allineato al codice ($v_code)"
    else
        bad "header ($v_head) != VERSION ($v_code) - aggiorna la riga '# Version:' in $GLIA_BIN"
    fi

    # codice contro tag: dipende dalla fase del rilascio
    if [ -z "$v_tag" ]; then
        note "nessun tag git da confrontare"
    else
        case "$(ver_cmp "$v_code" "$v_tag")" in
            eq) ok   "tag allineato al codice (v$v_code) - stato rilasciato pulito" ;;
            gt) note "VERSION ($v_code) > ultimo tag (v$v_tag): lavoro non ancora taggato (ok, il tag viene per ultimo)" ;;
            lt) bad  "VERSION ($v_code) < ultimo tag (v$v_tag): il codice e' dietro a un tag pubblicato" ;;
        esac
    fi
}

# ============================================================
#  Estrazione: i rami top-level del case di dispatch di bin/glia.
#  Il dispatch e' il case a colonna 0 ("case \"$1\" in ... esac"); i suoi
#  rami sono rientrati di ESATTAMENTE 4 spazi, i sotto-case di piu' - cosi'
#  si prendono solo i flag veri, non gli help|--undo|... annidati.
#  Stampa un ramo per riga (token separati da |, es. -w+|--web-deep).
# ============================================================
dispatch_arms() {
    awk '
        /^case "\$1" in/       { inside=1; next }
        inside && /^esac/      { inside=0 }
        inside && /^    [^ ].*\)[[:space:]]*$/ {
            s=$0; sub(/^    /,"",s); sub(/\)[[:space:]]*$/,"",s); print s
        }
    ' "$GLIA_BIN"
}

# ============================================================
#  Check #2 - ogni flag del parser compare nelle superfici documentate.
#  Un ramo "passa" su una superficie se ALMENO UN suo token vi compare
#  (cosi' gli alias non sono obbligatori: "aliases excepted, deliberately").
#  --kaboom e' esentato dalle sole completions (vedi COMPLETION_EXEMPT).
# ============================================================
check_flags() {
    section "2. Flag del parser presenti in README, commands.html e completions"
    local arm primary tok surface found miss=0
    while IFS= read -r arm; do
        # '""' e '*' sono i default; un ramo con '?' e' un catch-all glob
        # (es. -?*, la guardia sui flag sbagliati della v2.24): acchiappa
        # ERRORI, non e' un flag documentabile - nessuna superficie deve
        # elencarlo.
        case "$arm" in '""'|'*'|*'?'*) continue ;; esac
        # tieni solo i token che sono flag (iniziano con '-')
        local -a toks=() ; IFS='|' read -ra toks <<< "$arm"
        local -a flags=() ; for tok in "${toks[@]}"; do
            [ "${tok#-}" != "$tok" ] && flags+=("$tok")
        done
        [ "${#flags[@]}" -eq 0 ] && continue
        primary="${flags[0]}"
        for surface in $SURFACES_ALL; do
            case "$surface" in
                "$COMP_BASH"|"$COMP_FISH")
                    [[ "$COMPLETION_EXEMPT" == *" $primary "* ]] && continue ;;
            esac
            found=0
            for tok in "${flags[@]}"; do
                grep -qF -- "$tok" "$surface" && { found=1; break; }
            done
            [ "$found" -eq 0 ] && { bad "$primary manca in $surface"; miss=1; }
        done
    done < <(dispatch_arms)
    [ "$miss" -eq 0 ] && ok "ogni flag del parser compare in tutte le superfici (--kaboom escluso dalle completions, per sicurezza)"
}

# ---- helper nav: voci-sezione (no ghbtn/brand), href normalizzato ----
nav_entries() {
    awk '
        /class="nav-links"/ { blk=1 }
        blk && /<\/div>/    { blk=0 }
        blk && /<a / {
            if ($0 ~ /ghbtn/ || $0 ~ /brand/) next
            h=$0; sub(/.*href="/,"",h); sub(/".*/,"",h); sub(/^index\.html/,"",h)
            l=$0; sub(/.*">/,"",l); sub(/<\/a>.*/,"",l)
            print h "\t" l
        }
    ' "$1"
}
# ---- helper nav: il breakpoint che nasconde le voci su mobile ----
nav_bp() { grep -oE '@media\(max-width:[0-9]+px\)\{\.nav-links a' "$1" \
           | grep -oE '[0-9]+' | head -1; }

# ============================================================
#  Check #3 - le due nav HTML devono avere voci-sezione, ordine e
#  breakpoint identici (il bug: voci che spariscono passando tra le pagine).
#  I bottoni-azione (Coffee/GitHub) sono fuori scopo: restano nel footer.
# ============================================================
check_navs() {
    section "3. Le due nav HTML: voci-sezione, ordine e breakpoint"
    local ea eb bpa bpb
    ea="$(nav_entries "$INDEX_HTML")"
    eb="$(nav_entries "$CMDS_HTML")"
    if [ "$ea" = "$eb" ]; then
        ok "voci-sezione identiche e nello stesso ordine ($(printf '%s\n' "$ea" | grep -c . ) voci)"
    else
        bad "le nav divergono (index vs commands):"
        diff <(printf '%s\n' "$ea") <(printf '%s\n' "$eb") | sed 's/^/      /'
    fi
    bpa="$(nav_bp "$INDEX_HTML")"; bpb="$(nav_bp "$CMDS_HTML")"
    if [ -n "$bpa" ] && [ "$bpa" = "$bpb" ]; then
        ok "stesso breakpoint mobile (${bpa}px)"
    else
        bad "breakpoint diverso: index=${bpa:-?}px  commands=${bpb:-?}px"
    fi
}

# ============================================================
#  Check #4 - nessuna parola di conferma hardcoded nelle pagine.
#  La risposta giusta e' localizzata ($CONFIRM_WORD / $YES_KEY); una pagina
#  che dice "type YES" mente a chi ha l'interfaccia in italiano o tedesco.
# ============================================================
check_confirm() {
    section "4. Nessuna conferma hardcoded nelle pagine (usa \$CONFIRM_WORD/\$YES_KEY)"
    local hits
    hits="$(grep -rniE "$CONFIRM_HARDCODED" "$README" $CMDS_HTML "$INDEX_HTML" 2>/dev/null || true)"
    if [ -z "$hits" ]; then
        ok "nessuna conferma hardcoded trovata"
    else
        bad "conferma hardcoded (deve essere localizzata):"
        printf '%s\n' "$hits" | sed 's/^/      /'
    fi
}

# ============================================================
#  Main
# ============================================================
printf '%s== check-docs ==%s  fonte di verita'\'': %s  (repo: %s)\n' \
    "$BOLD" "$NC" "$GLIA_BIN" "$REPO"

check_version
check_flags
check_navs
check_confirm

section "Riepilogo"
if [ "$FAIL" -eq 0 ]; then
    printf '  %s%d OK, 0 FAIL%s - tutto allineato.\n' "$GREEN" "$PASS" "$NC"
    exit 0
else
    printf '  %s%d FAIL%s, %d OK - drift trovato.\n' "$RED" "$FAIL" "$NC" "$PASS"
    exit 1
fi
