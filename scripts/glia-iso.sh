#!/usr/bin/env bash
# ============================================================
#  glia-iso.sh - Guided GLIA ISO builder: it explains, you approve
#                Costruzione guidata della ISO: spiega, tu approvi
#  Version: 1.2 - 2026-07-19 (base-distro menu, assistant-only path, clearer flow)
#  Status:  WORK IN PROGRESS - incomplete, under active revision.
#           Treat it as a working base; contributions welcome.
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Menu:
#   1. build the GLIA ISO   (choose the base -> checks -> build -> QEMU/USB)
#   2. test an ISO in QEMU
#   3. write an ISO to a USB stick (reinforced confirmation)
#   4. install only the assistant on the distro you already run
#
#  Today the ISO builds on an Arch base only (mkarchiso); Debian and
#  Fedora bases are on the roadmap. The assistant (option 4) already
#  runs on Arch, Debian and Fedora.
#
#  GLIA philosophy applies here too: every command is shown before it
#  runs - [Enter] run, [n] skip, [e] explain (via glia), [q] quit.
#
#  Usage:
#    bash scripts/glia-iso.sh                 # guided, interactive
#    bash scripts/glia-iso.sh --dry-run       # show everything, run nothing
#    bash scripts/glia-iso.sh --lang=it|en    # force language (default: $LANG)
#    bash scripts/glia-iso.sh -h | -V
# ============================================================

# ----------------- CONFIGURATION -----------------
MODEL_NAME="qwen2.5-coder"                    # model embedded in the ISO
MODEL_TAG="7b"
QEMU_RAM="12G"                                # RAM for the QEMU test
QEMU_DISK_SIZE="40G"                          # virtual disk for the QEMU test
LOG_FILE="${HOME}/.local/share/glia/glia-iso.log"
BUILD_SPACE_GB=15                             # free space needed to build
# ---------------------------------------------------

set -u
VERSION="1.2"
DRY_RUN=0
UI_LANG=""
PREREQ_DONE=0

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'
CYAN='\033[1;36m'; DIM='\033[2m'; NC='\033[0m'

# =================== LANGUAGE ======================
# Auto-detect from $LANG (it_* -> Italian), override with --lang.

for arg in "$@"; do
    case "$arg" in --lang=it|--lang=en ) UI_LANG="${arg#--lang=}" ;; esac
done
if [ -z "$UI_LANG" ]; then
    case "${LANG:-en}" in it_*|it ) UI_LANG="it" ;; * ) UI_LANG="en" ;; esac
fi

if [ "$UI_LANG" = "it" ]; then
    # ---------------- ITALIANO ----------------
    T_TAGLINE="Spiega, tu approvi. Supporto, non sostituzione."
    T_DRYRUN_ON="Modalità DRY-RUN: ogni comando viene mostrato, nulla viene eseguito."
    T_PROPOSED="→ comando proposto:"
    T_PROMPT="[Invio] esegui · [n] salta · [e] spiega · [q] esci"
    T_NOT_EXEC="[dry-run] non eseguito"
    T_DONE="fatto"
    T_EXITCODE="codice di uscita"
    T_SKIPPED="saltato"
    T_NO_GLIA="glia non è installato su questa macchina - nessuna spiegazione AI disponibile."
    T_BYE="Ciao."
    T_KEYS="Invio, n, e o q."
    T_CONTINUE="[Invio] per continuare · [q] per uscire:"
    T_EXPLAIN_PROMPT="Spiega in breve e con parole semplici cosa fa questo comando shell:"

    T_BASE_TITLE="Scelta della base"
    T_BASE_TEACH="La ISO di GLIA oggi si costruisce solo su base Arch Linux:
lo strumento che la assembla (mkarchiso) esiste solo lì.
Le basi Debian e Fedora sono in roadmap: servono strumenti
diversi (live-build, livemedia-creator) e un contributor che
se ne occupi. Nota: l'ASSISTENTE invece gira già su Arch,
Debian e Fedora - è la voce 4 del menu."
    T_BASE_1="1) Arch Linux   - disponibile"
    T_BASE_2="2) Debian       - in roadmap, non ancora disponibile"
    T_BASE_3="3) Fedora       - in roadmap, non ancora disponibile"
    T_BASE_B="b) torna al menu"
    T_BASE_CHOICE="Base per la ISO:"
    T_BASE_ROADMAP="Questa base non esiste ancora. Se vuoi contribuire: apri una
issue su github.com/micheleperani76/GLIA - il progetto cerca
proprio tester e contributor per il mondo Debian/Fedora."
    T_BASE_KEYS="1, 2, 3 oppure b."

    T_P1_TITLE="Controlli preliminari"
    T_P1_TEACH="Costruire la ISO di GLIA significa assemblare in una cartella
un sistema Arch Linux completo e avviabile, incorporare il
modello AI (~5 GB) e comprimere tutto in un unico file .iso
con mkarchiso. Servono: un host Arch (o podman su altre
distro), ~${BUILD_SPACE_GB} GB liberi su disco e la rete per i pacchetti."
    T_REPO_OK="repo GLIA trovato in:"
    T_REPO_FAIL="Questa non sembra la repo GLIA (mancano iso/ o scripts/glia-build.sh)."
    T_REPO_HINT="Lanciami da dentro la repo clonata: bash scripts/glia-iso.sh"
    T_ARCH_OK="Host Arch rilevato (pacman presente) - build nativa."
    T_ARCHISO_OK="archiso è installato."
    T_ARCHISO_MISS="archiso manca - è lo strumento ufficiale Arch che costruisce le ISO live."
    T_ARCHISO_INSTALL="Installa archiso:"
    T_NONARCH_1="Host non-Arch - mkarchiso gira solo su Arch, quindi costruiamo"
    T_NONARCH_2="dentro un container Arch. Serve podman (o docker)."
    T_PODMAN_OK="podman è installato."
    T_PODMAN_MISS="podman non trovato. Installalo prima (Debian: sudo apt install podman)."
    T_SPACE_OK="Spazio libero in /var/tmp:"
    T_SPACE_NEED="GB necessari"
    T_SPACE_FAIL="Spazio insufficiente in /var/tmp:"
    T_SPACE_TEACH="La build lavora in /var/tmp/glia-build - su disco, NON in /tmp,
perché /tmp di solito vive in RAM e 15 GB non ci starebbero."
    T_NET_OK="La rete funziona."
    T_NET_FAIL="Non raggiungo archlinux.org - la build scarica pacchetti, offline fallirà."
    T_MODEL_OK="trovato nello store Ollama locale."
    T_MODEL_MISS="non trovato - la build lo incorpora nella ISO."
    T_MODEL_TEACH="La ISO esce con il modello AI già dentro, così il sistema live
funziona 100% offline dal primo avvio. La build lo copia dal
tuo store Ollama locale: lo scarichiamo una volta sola, qui."
    T_MODEL_PULL="Scarica il modello (~4.7 GB, una volta sola):"
    T_PREREQ_OK="Tutti i prerequisiti sono soddisfatti."
    T_PREREQ_FAIL="Mancano alcuni prerequisiti (vedi sopra). Puoi uscire, sistemare e rilanciare."

    T_P2_TITLE="Costruzione della ISO (base Arch)"
    T_P2_TEACH="Cosa succede adesso (10-15 minuti):
 1. bin/* viene copiato nell'albero della ISO - bin/ è l'unica
    fonte di verità, la ISO non può mai avere una copia vecchia
 2. il modello AI viene incorporato (manifest + blob, ~4.7 GB)
 3. mkarchiso assembla e comprime tutto in un unico file .iso
    avviabile in out/
 4. la cartella di lavoro viene ripulita
Serve sudo: mkarchiso crea device e mount."
    T_BUILD_NATIVE="Costruisci la ISO (nativa):"
    T_BUILD_PODMAN="Costruisci la ISO (dentro un container Arch):"
    T_ISO_READY="ISO pronta:"
    T_BUILD_FAIL="Build fallita - controlla l'output sopra. Non c'è altro da fare finché non riesce."
    T_CHAIN_QEMU="Vuoi provarla subito in QEMU? [s/N]:"
    T_CHAIN_USB="Vuoi scriverla su una chiavetta USB? [s/N]:"

    T_P3_TITLE="Prova in QEMU"
    T_NO_ISO="Nessuna ISO in"
    T_NO_ISO_2="- costruiscila prima (voce 1 del menu)."
    T_P3_TEACH="QEMU avvia la ISO in una macchina virtuale: provi tutto il
sistema live - e perfino l'installazione completa - senza
toccare i tuoi dischi veri. Firmware UEFI (OVMF) + ~${QEMU_RAM} di
RAM per il modello ${MODEL_TAG} incorporato. Chiudi la finestra QEMU
per fermare."
    T_QEMU_ASK="Provo"
    T_QEMU_ASK2="in QEMU? [s/N]:"
    T_QEMU_INSTALL="Installa QEMU + firmware UEFI:"
    T_QEMU_MISS="qemu-system-x86_64 non trovato (Debian: sudo apt install qemu-system-x86 ovmf)."
    T_OVMF_MISS="Firmware UEFI OVMF non trovato (Arch: edk2-ovmf, Debian: ovmf)."
    T_OVMF_OK="Firmware UEFI:"
    T_QCOW_CREATE="Crea un disco virtuale da ${QEMU_DISK_SIZE} (cresce su richiesta, parte piccolo):"
    T_QEMU_BOOT="Avvia la ISO in QEMU:"

    T_P4_TITLE="Scrittura su chiavetta USB"
    T_P4_TEACH="ZONA PERICOLOSA. dd copia la ISO byte per byte sulla chiavetta:
TUTTO ciò che c'è sul dispositivo scelto viene cancellato,
subito e per sempre. Sbagliare dispositivo può cancellare il
disco di sistema. Per questo: ti mostriamo i dispositivi, il
nome lo digiti tu, e chiediamo un YES scritto - la regola GLIA
per i comandi distruttivi."
    T_USB_ASK="Scrivo"
    T_USB_ASK2="su una chiavetta USB? [s/N]:"
    T_USB_DEVICES="Dispositivi a blocchi in questo momento (RM=1 = rimovibile):"
    T_USB_WHICH="Nome del dispositivo, disco intero, es. sdb - NON sdb1 (vuoto = annulla):"
    T_CANCELLED="annullato"
    T_NOT_BLOCK="non è un dispositivo a blocchi."
    T_IS_PART="sembra una partizione - usa il disco intero (es. sdb, non sdb1)."
    T_IS_ROOT="contiene il tuo filesystem di root. Assolutamente no."
    T_MOUNTED="ha partizioni montate:"
    T_UMOUNT_ASK="Le smonto e continuo? [s/N]:"
    T_ERASE_WARN="Tutto ciò che c'è su"
    T_ERASE_WARN2="verrà CANCELLATO."
    T_TYPE_YES="Digita YES (maiuscolo) per procedere:"
    T_NOTHING_WRITTEN="annullato - non è stato scritto nulla."
    T_DD_RUN="Scrivi la ISO (qualche minuto, aspetta il 100%):"
    T_USB_DONE="Chiavetta pronta. Avvia il PC di destinazione da USB (di solito F12/F8/Esc)."

    T_A_TITLE="Solo l'assistente, sulla distro che già usi"
    T_A_TEACH="Qui non si costruisce nessuna ISO: si aggiunge il comando glia
al Linux che stai già usando. Lo script ufficiale
install-assistant.sh supporta Arch, Debian e Fedora: installa
i due motori (ollama, aichat), il comando glia e la sua
configurazione, e propone il download di un modello. Non
cambia mai nulla senza chiedere. Nota: finora è testato a
fondo solo su Arch/CachyOS - su Debian e Fedora sei un tester
prezioso: se qualcosa non va, apri una issue!"
    T_A_DETECTED="Distro rilevata:"
    T_A_PREVIEW="Anteprima completa, non cambia nulla (dry-run):"
    T_A_REAL="Installazione vera:"

    T_MENU_TITLE="Cosa vuoi fare?"
    T_MENU_1="1) Costruisci la ISO GLIA     (scegli la base → controlli → build)"
    T_MENU_2="2) Prova una ISO in QEMU"
    T_MENU_3="3) Scrivi una ISO su USB"
    T_MENU_4="4) Installa solo l'assistente sulla distro che già usi"
    T_MENU_Q="q) Esci"
    T_CHOICE="La tua scelta:"
    T_ALL_DONE="Finito - log completo in"
    T_BAD_CHOICE="1-4 oppure q."
    YES_KEY="s"
else
    # ---------------- ENGLISH ----------------
    T_TAGLINE="It explains, you approve. Support, not substitution."
    T_DRYRUN_ON="DRY-RUN mode: every command is shown, nothing runs."
    T_PROPOSED="→ proposed command:"
    T_PROMPT="[Enter] run · [n] skip · [e] explain · [q] quit"
    T_NOT_EXEC="[dry-run] not executed"
    T_DONE="done"
    T_EXITCODE="exit code"
    T_SKIPPED="skipped"
    T_NO_GLIA="glia is not installed on this machine - no AI explanation available."
    T_BYE="Bye."
    T_KEYS="Enter, n, e or q."
    T_CONTINUE="[Enter] to continue · [q] to quit:"
    T_EXPLAIN_PROMPT="Explain briefly, in simple terms, what this shell command does:"

    T_BASE_TITLE="Choose the base"
    T_BASE_TEACH="Today the GLIA ISO builds on an Arch Linux base only: the
tool that assembles it (mkarchiso) exists only there.
Debian and Fedora bases are on the roadmap: they need
different tools (live-build, livemedia-creator) and a
contributor to own them. Note: the ASSISTANT already runs
on Arch, Debian and Fedora - that's option 4 in the menu."
    T_BASE_1="1) Arch Linux   - available"
    T_BASE_2="2) Debian       - on the roadmap, not available yet"
    T_BASE_3="3) Fedora       - on the roadmap, not available yet"
    T_BASE_B="b) back to the menu"
    T_BASE_CHOICE="Base for the ISO:"
    T_BASE_ROADMAP="This base doesn't exist yet. Want to help? Open an issue on
github.com/micheleperani76/GLIA - the project is looking for
exactly this: Debian/Fedora testers and contributors."
    T_BASE_KEYS="1, 2, 3 or b."

    T_P1_TITLE="Preliminary checks"
    T_P1_TEACH="Building the GLIA ISO means assembling a complete, bootable
Arch Linux system in a folder, embedding the AI model (~5 GB),
and compressing everything into one .iso file with mkarchiso.
That needs: an Arch host (or podman on any other distro),
~${BUILD_SPACE_GB} GB of free disk, and network for the packages."
    T_REPO_OK="GLIA repo found in:"
    T_REPO_FAIL="This doesn't look like the GLIA repo (iso/ or scripts/glia-build.sh missing)."
    T_REPO_HINT="Run me from inside the cloned repo: bash scripts/glia-iso.sh"
    T_ARCH_OK="Arch-based host detected (pacman present) - native build."
    T_ARCHISO_OK="archiso is installed."
    T_ARCHISO_MISS="archiso is missing - it's the official Arch tool that builds live ISOs."
    T_ARCHISO_INSTALL="Install archiso:"
    T_NONARCH_1="Non-Arch host - mkarchiso only runs on Arch, so we build"
    T_NONARCH_2="inside an Arch container. That needs podman (or docker)."
    T_PODMAN_OK="podman is installed."
    T_PODMAN_MISS="podman not found. Install it first (Debian: sudo apt install podman)."
    T_SPACE_OK="Free space in /var/tmp:"
    T_SPACE_NEED="GB needed"
    T_SPACE_FAIL="Not enough space in /var/tmp:"
    T_SPACE_TEACH="The build works in /var/tmp/glia-build - on disk, NOT /tmp,
because /tmp usually lives in RAM and 15 GB would not fit."
    T_NET_OK="Network is up."
    T_NET_FAIL="Cannot reach archlinux.org - the build downloads packages, it will fail offline."
    T_MODEL_OK="found in the local Ollama store."
    T_MODEL_MISS="not found - the build embeds it into the ISO."
    T_MODEL_TEACH="The ISO ships with the AI model already inside, so the live
system works 100% offline from the first boot. The build copies
it from your local Ollama store: we download it once, here."
    T_MODEL_PULL="Download the model (~4.7 GB, once):"
    T_PREREQ_OK="All prerequisites satisfied."
    T_PREREQ_FAIL="Some prerequisites are missing (see above). You can quit, fix, and rerun."

    T_P2_TITLE="Build the ISO (Arch base)"
    T_P2_TEACH="What happens now (10-15 minutes):
 1. bin/* is copied into the ISO tree - bin/ is the single
    source of truth, the ISO can never ship a stale copy
 2. the AI model is embedded (manifest + blobs, ~4.7 GB)
 3. mkarchiso assembles and compresses everything into one
    bootable .iso in out/
 4. the work directory is cleaned up
sudo is required: mkarchiso creates devices and mounts."
    T_BUILD_NATIVE="Build the ISO (native):"
    T_BUILD_PODMAN="Build the ISO (inside an Arch container):"
    T_ISO_READY="ISO ready:"
    T_BUILD_FAIL="Build failed - check the output above. Nothing else to do until it succeeds."
    T_CHAIN_QEMU="Test it in QEMU right away? [y/N]:"
    T_CHAIN_USB="Write it to a USB stick? [y/N]:"

    T_P3_TITLE="Test in QEMU"
    T_NO_ISO="No ISO in"
    T_NO_ISO_2="- build it first (menu option 1)."
    T_P3_TEACH="QEMU boots the ISO in a virtual machine: you test the whole
live system - and even a full install - without touching your
real disks. UEFI firmware (OVMF) + ~${QEMU_RAM} of RAM for the
embedded ${MODEL_TAG} model. Close the QEMU window to stop."
    T_QEMU_ASK="Test"
    T_QEMU_ASK2="in QEMU? [y/N]:"
    T_QEMU_INSTALL="Install QEMU + UEFI firmware:"
    T_QEMU_MISS="qemu-system-x86_64 not found (Debian: sudo apt install qemu-system-x86 ovmf)."
    T_OVMF_MISS="OVMF UEFI firmware not found (Arch: edk2-ovmf, Debian: ovmf)."
    T_OVMF_OK="UEFI firmware:"
    T_QCOW_CREATE="Create a ${QEMU_DISK_SIZE} virtual disk (grows on demand, starts tiny):"
    T_QEMU_BOOT="Boot the ISO in QEMU:"

    T_P4_TITLE="Write to a USB stick"
    T_P4_TEACH="DANGER ZONE. dd copies the ISO byte-by-byte onto the stick:
EVERYTHING on the target device is erased, instantly and
forever. Picking the wrong device can wipe your system disk.
That's why: we show the devices, you type the name yourself,
and we ask for a typed YES - the GLIA rule for destructive
commands."
    T_USB_ASK="Write"
    T_USB_ASK2="to a USB stick? [y/N]:"
    T_USB_DEVICES="Block devices right now (RM=1 means removable):"
    T_USB_WHICH="Target device name, whole disk, e.g. sdb - NOT sdb1 (empty = cancel):"
    T_CANCELLED="cancelled"
    T_NOT_BLOCK="is not a block device."
    T_IS_PART="looks like a partition - use the whole disk (e.g. sdb, not sdb1)."
    T_IS_ROOT="holds your root filesystem. Absolutely not."
    T_MOUNTED="has mounted partitions:"
    T_UMOUNT_ASK="Unmount them and continue? [y/N]:"
    T_ERASE_WARN="Everything on"
    T_ERASE_WARN2="will be ERASED."
    T_TYPE_YES="Type YES (uppercase) to proceed:"
    T_NOTHING_WRITTEN="cancelled - nothing written."
    T_DD_RUN="Write the ISO (a few minutes, wait for 100%):"
    T_USB_DONE="Stick ready. Boot the target PC from USB (usually F12/F8/Esc)."

    T_A_TITLE="Assistant only, on the distro you already run"
    T_A_TEACH="No ISO is built here: this adds the glia command to the Linux
you are already running. The official install-assistant.sh
script supports Arch, Debian and Fedora: it installs the two
engines (ollama, aichat), the glia command and its config, and
offers to download a model. It never changes anything without
asking. Note: so far it's fully tested on Arch/CachyOS only -
on Debian and Fedora you are a precious tester: if something
breaks, open an issue!"
    T_A_DETECTED="Detected distro:"
    T_A_PREVIEW="Full preview, changes nothing (dry-run):"
    T_A_REAL="Real install:"

    T_MENU_TITLE="What do you want to do?"
    T_MENU_1="1) Build the GLIA ISO         (choose the base → checks → build)"
    T_MENU_2="2) Test an ISO in QEMU"
    T_MENU_3="3) Write an ISO to USB"
    T_MENU_4="4) Install only the assistant on the distro you already run"
    T_MENU_Q="q) Quit"
    T_CHOICE="Your choice:"
    T_ALL_DONE="Done - full log in"
    T_BAD_CHOICE="1-4 or q."
    YES_KEY="y"
fi

# =================== HELPERS =======================

step()  { echo -e "\n${YELLOW}==> $*${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $*${NC}"; }
warn()  { echo -e "${YELLOW}  ! $*${NC}"; }
fail()  { echo -e "${RED}  ✗ $*${NC}"; }

# A short lesson box: WHY we are about to do something.
teach() {
    echo -e "${CYAN}"
    echo "  ┌──────────────────────────────────────────────────────────"
    while IFS= read -r line; do echo "  │ $line"; done <<< "$*"
    echo "  └──────────────────────────────────────────────────────────"
    echo -e "${NC}"
}

log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" >> "$LOG_FILE"
}

# Show a command, let the user approve it - the GLIA loop.
# run_cmd "description" "command"  -> returns the command's exit code
# Returns 200 if the user skipped the step.
run_cmd() {
    local desc="$1" cmd="$2" ans
    echo -e "\n  ${desc}"
    echo -e "  ${DIM}${T_PROPOSED}${NC}"
    echo -e "    ${GREEN}${cmd}${NC}"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${DIM}${T_NOT_EXEC}${NC}"
        log "DRY-RUN | $cmd"
        return 0
    fi
    while true; do
        echo -ne "  ${T_PROMPT}: "
        read -r ans
        case "$ans" in
            "" )
                log "RUN | $cmd"
                bash -c "$cmd"
                local rc=$?
                if [ $rc -eq 0 ]; then ok "$T_DONE"; else fail "$T_EXITCODE $rc"; fi
                log "EXIT $rc | $cmd"
                return $rc ;;
            n|N ) warn "$T_SKIPPED"; log "SKIP | $cmd"; return 200 ;;
            e|E )
                if command -v glia >/dev/null 2>&1; then
                    glia -d "$T_EXPLAIN_PROMPT $cmd"
                else
                    warn "$T_NO_GLIA"
                fi ;;
            q|Q ) echo "$T_BYE"; log "QUIT during: $cmd"; exit 0 ;;
            * ) echo "  $T_KEYS" ;;
        esac
    done
}

pause() { echo -ne "\n  ${DIM}${T_CONTINUE}${NC} "; read -r a; [ "$a" = "q" ] && exit 0; }

yes_ans() { [ "$1" = "$YES_KEY" ] || [ "$1" = "${YES_KEY^^}" ]; }

# =================== CHECKS ========================

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
IS_ARCH=0
command -v pacman >/dev/null 2>&1 && IS_ARCH=1

phase_prereq() {
    [ "$PREREQ_DONE" -eq 1 ] && return 0

    step "$T_P1_TITLE"
    teach "$T_P1_TEACH"

    local all_ok=1

    # 1. repo layout
    if [ -d "$PROJECT/iso" ] && [ -f "$PROJECT/scripts/glia-build.sh" ]; then
        ok "$T_REPO_OK $PROJECT"
    else
        fail "$T_REPO_FAIL"
        fail "$T_REPO_HINT"
        exit 1
    fi

    # 2. host type
    if [ "$IS_ARCH" -eq 1 ]; then
        ok "$T_ARCH_OK"
        if command -v mkarchiso >/dev/null 2>&1; then
            ok "$T_ARCHISO_OK"
        else
            warn "$T_ARCHISO_MISS"
            run_cmd "$T_ARCHISO_INSTALL" "sudo pacman -S --needed archiso" || all_ok=0
        fi
    else
        warn "$T_NONARCH_1"
        warn "$T_NONARCH_2"
        if command -v podman >/dev/null 2>&1; then
            ok "$T_PODMAN_OK"
        else
            fail "$T_PODMAN_MISS"
            all_ok=0
        fi
    fi

    # 3. disk space (build workdir lives in /var/tmp)
    local free_gb
    free_gb=$(df -BG --output=avail /var/tmp 2>/dev/null | tail -1 | tr -dc '0-9')
    if [ -n "$free_gb" ] && [ "$free_gb" -ge "$BUILD_SPACE_GB" ]; then
        ok "$T_SPACE_OK ${free_gb} GB (>= ${BUILD_SPACE_GB} ${T_SPACE_NEED})."
    else
        fail "$T_SPACE_FAIL ${free_gb:-?} GB / ${BUILD_SPACE_GB} GB."
        teach "$T_SPACE_TEACH"
        all_ok=0
    fi

    # 4. network
    if curl -fsI --max-time 5 https://archlinux.org >/dev/null 2>&1; then
        ok "$T_NET_OK"
    else
        warn "$T_NET_FAIL"
        all_ok=0
    fi

    # 5. AI model in the local Ollama store (native build only)
    if [ "$IS_ARCH" -eq 1 ]; then
        if ollama list 2>/dev/null | grep -q "${MODEL_NAME}:${MODEL_TAG}"; then
            ok "${MODEL_NAME}:${MODEL_TAG} $T_MODEL_OK"
        else
            warn "${MODEL_NAME}:${MODEL_TAG} $T_MODEL_MISS"
            teach "$T_MODEL_TEACH"
            run_cmd "$T_MODEL_PULL" "ollama pull ${MODEL_NAME}:${MODEL_TAG}" || all_ok=0
        fi
    fi

    if [ "$all_ok" -eq 1 ]; then
        ok "$T_PREREQ_OK"
        PREREQ_DONE=1
    else
        warn "$T_PREREQ_FAIL"
        pause
    fi
}

# =================== BASE CHOICE ===================
# Today only the Arch base exists (mkarchiso). Debian/Fedora entries
# are shown honestly as roadmap items, so the structure is already
# here for future contributors.

choose_base() {
    step "$T_BASE_TITLE"
    teach "$T_BASE_TEACH"
    local c
    while true; do
        echo "   $T_BASE_1"
        echo "   $T_BASE_2"
        echo "   $T_BASE_3"
        echo "   $T_BASE_B"
        echo -ne "\n  $T_BASE_CHOICE "
        read -r c
        case "$c" in
            1 ) return 0 ;;
            2|3 ) teach "$T_BASE_ROADMAP" ;;
            b|B ) return 1 ;;
            * ) echo "  $T_BASE_KEYS" ;;
        esac
    done
}

# =================== BUILD =========================

phase_build() {
    choose_base || return

    phase_prereq

    step "$T_P2_TITLE"
    teach "$T_P2_TEACH"

    local rc
    if [ "$IS_ARCH" -eq 1 ]; then
        run_cmd "$T_BUILD_NATIVE" "sudo bash '$PROJECT/scripts/glia-build.sh'"
        rc=$?
    else
        run_cmd "$T_BUILD_PODMAN" \
                "sudo podman run --rm -it --privileged -v '$PROJECT:/glia' docker.io/archlinux:latest bash -c 'pacman -Syu --noconfirm archiso && bash /glia/scripts/glia-build.sh'"
        rc=$?
    fi
    if [ $rc -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
        local iso ans
        iso=$(ls -t "$PROJECT"/out/glia-*.iso 2>/dev/null | head -1)
        [ -n "$iso" ] && ok "$T_ISO_READY $iso ($(du -h "$iso" | cut -f1))"
        # natural next steps, offered - never imposed
        echo -ne "\n  $T_CHAIN_QEMU "
        read -r ans
        yes_ans "$ans" && phase_qemu
        echo -ne "\n  $T_CHAIN_USB "
        read -r ans
        yes_ans "$ans" && phase_usb
    elif [ $rc -ne 0 ] && [ $rc -ne 200 ]; then
        fail "$T_BUILD_FAIL"
        exit 1
    fi
}

# =================== QEMU ==========================

find_ovmf() {
    local c
    for c in /usr/share/edk2/x64/OVMF_CODE.4m.fd \
             /usr/share/edk2/x64/OVMF_CODE.fd \
             /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
             /usr/share/OVMF/OVMF_CODE_4M.fd \
             /usr/share/OVMF/OVMF_CODE.fd \
             /usr/share/edk2/ovmf/OVMF_CODE.fd; do
        [ -f "$c" ] && { echo "$c"; return 0; }
    done
    return 1
}

phase_qemu() {
    step "$T_P3_TITLE"
    local iso
    iso=$(ls -t "$PROJECT"/out/glia-*.iso 2>/dev/null | head -1)
    if [ -z "$iso" ]; then
        warn "$T_NO_ISO $PROJECT/out/ $T_NO_ISO_2"
        return
    fi
    teach "$T_P3_TEACH"

    echo -ne "  $T_QEMU_ASK '$(basename "$iso")' $T_QEMU_ASK2 "
    read -r ans
    yes_ans "$ans" || { warn "$T_SKIPPED"; return; }

    if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        if [ "$IS_ARCH" -eq 1 ]; then
            run_cmd "$T_QEMU_INSTALL" "sudo pacman -S --needed qemu-desktop edk2-ovmf" || return
        else
            fail "$T_QEMU_MISS"
            return
        fi
    fi
    local ovmf
    if ! ovmf=$(find_ovmf); then
        fail "$T_OVMF_MISS"
        return
    fi
    ok "$T_OVMF_OK $ovmf"

    [ -f "$PROJECT/out/test-disk.qcow2" ] || \
        run_cmd "$T_QCOW_CREATE" \
                "qemu-img create -f qcow2 '$PROJECT/out/test-disk.qcow2' ${QEMU_DISK_SIZE}"

    run_cmd "$T_QEMU_BOOT" \
            "qemu-system-x86_64 -enable-kvm -cpu host -smp 6 -m ${QEMU_RAM} -drive if=pflash,format=raw,readonly=on,file='$ovmf' -drive file='$iso',media=cdrom,if=none,id=cd0 -device ide-cd,drive=cd0,bootindex=0 -drive file='$PROJECT/out/test-disk.qcow2',format=qcow2,if=virtio -vga virtio"
}

# =================== USB ===========================

phase_usb() {
    step "$T_P4_TITLE"
    local iso
    iso=$(ls -t "$PROJECT"/out/glia-*.iso 2>/dev/null | head -1)
    if [ -z "$iso" ]; then
        warn "$T_NO_ISO $PROJECT/out/ $T_NO_ISO_2"
        return
    fi
    teach "$T_P4_TEACH"

    echo -ne "  $T_USB_ASK '$(basename "$iso")' $T_USB_ASK2 "
    read -r ans
    yes_ans "$ans" || { warn "$T_SKIPPED"; return; }

    echo -e "\n  $T_USB_DEVICES\n"
    lsblk -d -o NAME,SIZE,MODEL,TRAN,RM | sed 's/^/    /'
    echo
    echo -ne "  $T_USB_WHICH "
    read -r dev
    [ -z "$dev" ] && { warn "$T_CANCELLED"; return; }
    dev="${dev#/dev/}"

    # --- safety checks ---
    if [ ! -b "/dev/$dev" ]; then fail "/dev/$dev $T_NOT_BLOCK"; return; fi
    if [[ "$dev" =~ [0-9]$ && ! "$dev" =~ ^nvme ]]; then
        fail "/dev/$dev $T_IS_PART"
        return
    fi
    local sysdisk
    sysdisk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -1)
    if [ -n "$sysdisk" ] && [ "$dev" = "$sysdisk" ]; then
        fail "/dev/$dev $T_IS_ROOT"
        return
    fi
    if lsblk -no MOUNTPOINT "/dev/$dev" | grep -q .; then
        warn "/dev/$dev $T_MOUNTED"
        lsblk "/dev/$dev" | sed 's/^/    /'
        echo -ne "  $T_UMOUNT_ASK "
        read -r ans
        yes_ans "$ans" || { warn "$T_CANCELLED"; return; }
        if [ "$DRY_RUN" -eq 0 ]; then sudo umount "/dev/${dev}"?* 2>/dev/null; fi
    fi

    echo
    lsblk -d -o NAME,SIZE,MODEL "/dev/$dev" | sed 's/^/    /'
    echo -e "\n  ${RED}$T_ERASE_WARN /dev/$dev $T_ERASE_WARN2${NC}"
    echo -ne "  $T_TYPE_YES "
    read -r ans
    [ "$ans" = "YES" ] || { warn "$T_NOTHING_WRITTEN"; return; }
    log "USB CONFIRMED | /dev/$dev"

    run_cmd "$T_DD_RUN" "sudo dd if='$iso' of=/dev/$dev bs=4M status=progress oflag=sync"
    if [ $? -eq 0 ]; then
        ok "$T_USB_DONE"
    fi
}

# =================== ASSISTANT ONLY ================
# The real "choose your distro" path: install-assistant.sh already
# supports Arch, Debian and Fedora on the system you are running.

phase_assistant() {
    step "$T_A_TITLE"
    teach "$T_A_TEACH"

    if [ ! -f "$PROJECT/scripts/install-assistant.sh" ]; then
        fail "$T_REPO_FAIL"
        return
    fi

    local distro="?"
    [ -r /etc/os-release ] && distro=$(. /etc/os-release && echo "${PRETTY_NAME:-$ID}")
    ok "$T_A_DETECTED $distro"

    run_cmd "$T_A_PREVIEW" "bash '$PROJECT/scripts/install-assistant.sh' --dry-run"
    [ $? -eq 200 ] && return
    run_cmd "$T_A_REAL" "bash '$PROJECT/scripts/install-assistant.sh'"
}

# =================== MAIN ==========================

usage() {
    sed -n '2,28p' "$0" | sed 's/^# \{0,2\}//'
}

for arg in "$@"; do
    case "$arg" in
        --dry-run ) DRY_RUN=1 ;;
        --lang=it|--lang=en ) : ;;   # already handled above
        --lang ) echo "Use --lang=it or --lang=en"; exit 1 ;;
        -h|--help ) usage; exit 0 ;;
        -V|--version ) echo "glia-iso $VERSION"; exit 0 ;;
        * ) echo "Unknown option: $arg (see -h)"; exit 1 ;;
    esac
done

clear
echo -e "${GREEN}"
echo "  ══════════════════════════════════════════════════"
echo "   GLIA ISO - guided build · v$VERSION"
echo "   $T_TAGLINE"
echo "  ══════════════════════════════════════════════════"
echo -e "${NC}"
[ "$DRY_RUN" -eq 1 ] && warn "$T_DRYRUN_ON"
log "=== session start (dry-run=$DRY_RUN, lang=$UI_LANG) ==="

while true; do
    echo
    echo "  $T_MENU_TITLE"
    echo
    echo "   $T_MENU_1"
    echo "   $T_MENU_2"
    echo "   $T_MENU_3"
    echo "   $T_MENU_4"
    echo "   $T_MENU_Q"
    echo -ne "\n  $T_CHOICE "
    read -r choice
    case "$choice" in
        1 ) phase_build ;;
        2 ) phase_qemu ;;
        3 ) phase_usb ;;
        4 ) phase_assistant ;;
        q|Q ) echo "  $T_ALL_DONE $LOG_FILE"; echo "  $T_BYE"; log "=== session end ==="; exit 0 ;;
        * ) echo "  $T_BAD_CHOICE" ;;
    esac
done
