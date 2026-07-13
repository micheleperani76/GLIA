#!/usr/bin/env bash
# ============================================================
#  glia-build.sh - Build the GLIA live ISO
#  Version: 1.1 - 2026-07-13 (sync bin/ into airootfs: the ISO always ships the current assistant)
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  What it does:
#   1. syncs bin/* into the ISO tree (so the ISO never ships stale copies)
#   2. embeds the AI model into the ISO tree (if not already there)
#   3. builds the ISO with mkarchiso
#   4. cleans up the work directory
#
#  Usage:
#    sudo bash scripts/glia-build.sh
# ============================================================

# ----------------- CONFIGURATION -----------------
MODEL_NAME="qwen2.5-coder"          # model to embed
MODEL_TAG="7b"
WORKDIR="/var/tmp/glia-build"       # on disk, NOT in /tmp (which lives in RAM)
# ---------------------------------------------------

set -euo pipefail
GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
step() { echo -e "\n${YELLOW}==> $*${NC}"; }

# ------------------- CHECKS ----------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run me with sudo:  sudo bash scripts/glia-build.sh${NC}" >&2
    exit 1
fi
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$PROJECT/iso" ] || { echo -e "${RED}iso/ profile not found in $PROJECT${NC}" >&2; exit 1; }

# ---------- 1. SYNC THE ASSISTANT INTO THE ISO ----------
# The copies in iso/airootfs/usr/local/bin are what the live system runs:
# refresh them from bin/ so the ISO never ships an outdated assistant.
step "Syncing bin/ into the ISO tree..."
for f in glia glia-hardware glia-firstboot glia-install; do
    install -m 755 "$PROJECT/bin/$f" "$PROJECT/iso/airootfs/usr/local/bin/$f"
done

# --------------- 2. EMBED THE MODEL ---------------
DSTM="$PROJECT/iso/airootfs/var/lib/ollama"
MANIFEST_DST="$DSTM/manifests/registry.ollama.ai/library/$MODEL_NAME/$MODEL_TAG"

if [ -f "$MANIFEST_DST" ]; then
    step "Model $MODEL_NAME:$MODEL_TAG already embedded, skipping copy"
else
    step "Looking for $MODEL_NAME:$MODEL_TAG in the local Ollama store..."
    USER_HOME=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
    MSRC=""
    for c in /var/lib/ollama "$USER_HOME/.ollama/models"; do
        [ -f "$c/manifests/registry.ollama.ai/library/$MODEL_NAME/$MODEL_TAG" ] && MSRC="$c" && break
    done
    if [ -z "$MSRC" ]; then
        echo -e "${RED}Model not found. Download it first:  ollama pull $MODEL_NAME:$MODEL_TAG${NC}" >&2
        exit 1
    fi
    echo "Found in: $MSRC"

    step "Copying manifest and blobs (~4.7 GB, takes a minute)..."
    mkdir -p "$DSTM/manifests/registry.ollama.ai/library/$MODEL_NAME" "$DSTM/blobs"
    cp -v "$MSRC/manifests/registry.ollama.ai/library/$MODEL_NAME/$MODEL_TAG" \
          "$DSTM/manifests/registry.ollama.ai/library/$MODEL_NAME/"
    grep -oE 'sha256:[a-f0-9]{64}' "$MSRC/manifests/registry.ollama.ai/library/$MODEL_NAME/$MODEL_TAG" \
        | sort -u | while read -r d; do
        cp -v "$MSRC/blobs/${d/:/-}" "$DSTM/blobs/"
    done
    chmod -R a+rX "$DSTM"
fi
du -sh "$DSTM"

# ------------------- 3. BUILD ---------------------
step "Building the ISO (10-15 min, compresses the model too)..."
rm -rf "$WORKDIR"
mkarchiso -v -w "$WORKDIR" -o "$PROJECT/out" "$PROJECT/iso"

# ------------------ 4. CLEANUP --------------------
step "Cleaning up the work directory..."
rm -rf "$WORKDIR"

step "Done! Your ISO:"
ls -lh "$PROJECT/out/"*.iso
echo -e "${GREEN}Test it with:  run_archiso -i out/<iso-name> -- -m 12G${NC}"
