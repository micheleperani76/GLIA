#!/usr/bin/env bash
# ============================================================
#  build.sh - src/*.sh -> bin/glia, a plain ordered concatenation.
#  Version: 1.0 - 2026-07-19 (v3.0.0, the split)
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Why a build at all: development is modular (src/, one file per
#  area), distribution stays a SINGLE file - --update installs one
#  file, rollback keeps whole versions, no runtime sourcing, no
#  version skew between modules. The artifact bin/glia is COMMITTED:
#  the update flow never learns src/ exists.
#
#  The concatenation is the numeric-prefix glob order of src/, so
#  "what order do modules load in?" has the same answer as `ls`.
#  bin/glia is generated - edit src/, not the artifact:
#  scripts/check-docs.sh (check #6) rebuilds and screams on drift.
# ============================================================
set -eu

cd "$(dirname "$0")/.."

[ -d src ] || { echo "build.sh: src/ non trovata (vai alla radice del repo)" >&2; exit 2; }

modules=(src/[0-9]*.sh)
[ -e "${modules[0]}" ] || { echo "build.sh: nessun modulo in src/" >&2; exit 2; }

tmp="$(mktemp)"
cat "${modules[@]}" > "$tmp"

# sanity before replacing anything: the result must be valid bash
if ! bash -n "$tmp" 2>&1; then
    rm -f "$tmp"
    echo "build.sh: il concatenato NON passa bash -n - bin/glia non toccato" >&2
    exit 1
fi

if cmp -s "$tmp" bin/glia 2>/dev/null; then
    rm -f "$tmp"
    echo "bin/glia già aggiornato (${#modules[@]} moduli, nessun cambiamento)"
else
    mv "$tmp" bin/glia
    chmod 755 bin/glia
    echo "bin/glia ricostruito da ${#modules[@]} moduli ($(wc -l < bin/glia) righe)"
fi
