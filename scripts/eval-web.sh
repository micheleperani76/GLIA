#!/usr/bin/env bash
# ============================================================
#  eval-web.sh - a bench for `glia -w`
#  Version: 1.0 - 2026-07-16
#  Project: GLIA (GNU Linux IA)
#
#  What it is for: -w answers from the live web, so it cannot be unit
#  tested - the right answer changes with the world. What CAN be checked is
#  whether the answer is current, and whether it cites its sources. This
#  runs a fixed set of questions and writes question + answer to one file,
#  ready to be read (by you, or by a model acting as judge).
#
#  Half of the questions have answers that MOVE (kernel version, who runs
#  a company, a price): if -w quietly stopped searching and started
#  answering from the model's training data, those are the ones that rot
#  first. The other half are stable, and catch the opposite failure: a
#  search that drags in noise where plain knowledge was enough.
#
#  Usage:
#    bash scripts/eval-web.sh                 # the assistant found in PATH
#    bash scripts/eval-web.sh -c ./bin/glia   # a specific build
#    bash scripts/eval-web.sh -e bing         # force one engine
#    bash scripts/eval-web.sh -d              # deep mode (-w+)
# ============================================================
set -u

# ---- configuration (top of the file, easy to change) ----
CMD=""                                   # assistant to test (default: auto)
ENGINE=""                                # ddg | bing | searx (default: current)
DEEP=0                                   # 1 = use -w+ instead of -w
OUT="${TMPDIR:-/tmp}/glia-eval-$(date +%Y%m%d-%H%M%S).txt"
TIMEOUT=180                              # seconds per question
PAUSE=4                                  # seconds between questions

QUESTIONS=(
  # --- answers that MOVE: these expose a -w that stopped searching ---
  "qual e l'ultima versione stabile del kernel linux"
  "quando e stato rilasciato debian 13 trixie"
  "quando esce ubuntu 26.04 LTS e come si chiama"
  "qual e l'ultima versione stabile di python"
  "chi e l'attuale CEO di OpenAI"
  "qual e l'ultima versione di fedora linux"
  "qual e il prezzo attuale del bitcoin"
  "qual e l'ultima versione LTS di nodejs"
  # --- stable answers: these expose a -w that adds noise for nothing ---
  "cos e cachyos e su quale distro si basa"
  "che cos e ollama in informatica"
  "qual e la capitale dell'australia"
  "cos e wayland e sta sostituendo x11"
)

usage() {
    sed -n '2,26p' "$0" | sed 's/^#  \{0,1\}//'
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -c|--cmd)    CMD="${2:-}"; shift 2 ;;
        -e|--engine) ENGINE="${2:-}"; shift 2 ;;
        -d|--deep)   DEEP=1; shift ;;
        -o|--out)    OUT="${2:-}"; shift 2 ;;
        -h|--help)   usage ;;
        *) echo "unknown option: $1 (try -h)" >&2; exit 1 ;;
    esac
done

# The assistant answers to whatever name it was given, so look for the
# renamed one first and fall back to the anchor, which always exists.
if [ -z "$CMD" ]; then
    if [ -r "$HOME/.config/glia/name" ] \
       && command -v "$(head -n1 "$HOME/.config/glia/name")" >/dev/null 2>&1; then
        CMD="$(head -n1 "$HOME/.config/glia/name")"
    elif command -v glia >/dev/null 2>&1; then
        CMD="glia"
    else
        echo "no assistant found: pass one with -c ./bin/glia" >&2; exit 1
    fi
fi
command -v "$CMD" >/dev/null 2>&1 || [ -x "$CMD" ] || {
    echo "not executable: $CMD" >&2; exit 1; }

FLAG="-w"; [ "$DEEP" -eq 1 ] && FLAG="-w+"
PREFIX=""; [ -n "$ENGINE" ] && PREFIX="$ENGINE: "

{
    echo "# glia -w bench"
    echo "# date:    $(date '+%F %T')"
    echo "# command: $CMD  ($("$CMD" -V 2>/dev/null | head -1))"
    echo "# mode:    $FLAG${ENGINE:+   engine: $ENGINE}"
    echo
} > "$OUT"

i=0
for q in "${QUESTIONS[@]}"; do
    i=$((i+1))
    printf '  [%2d/%2d] %s\n' "$i" "${#QUESTIONS[@]}" "$q"
    {
        echo "### Q$i: $q"
        echo "--- ANSWER ---"
    } >> "$OUT"
    timeout "$TIMEOUT" "$CMD" $FLAG "${PREFIX}${q}" >> "$OUT" 2>/dev/null \
        || echo "[no answer: timeout or error]" >> "$OUT"
    {
        echo
        echo "====================================="
    } >> "$OUT"
    sleep "$PAUSE"
done

echo
echo "done -> $OUT"
echo "what to look for:"
echo "  · every answer ends with a Sources list (that is -w actually searching)"
echo "  · the moving answers are current, not the model's training data"
echo "  · nothing was invented where it said it had sources"
