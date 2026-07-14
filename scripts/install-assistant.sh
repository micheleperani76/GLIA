#!/usr/bin/env bash
# ============================================================
#  install-assistant.sh - GLIA assistant installer (any distro)
#  Version: 1.3 - 2026-07-14
#
#  What's new in v1.3:
#   - step 7/8 checks Ollama for models ALREADY downloaded: pick one of
#     them as the default (numbered list) or download a new one (the
#     recommended); the chosen default is written to ~/.config/glia/model
#
#  What's new in v1.2:
#   - step 8/8: final health check with glia --doctor
#   - dry-run asks NO questions anymore: it only shows what the real
#     run will do (the model question included)
#
#  What's new in v1.1:
#   - step 6/7: installs shell completions for YOUR shell (bash or fish;
#     zsh gets a hint - it has no native completion here yet)
#   - step 7/7: the offered model is the one RECOMMENDED by glia-hardware
#     for this machine, not a fixed default
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Installs ONLY the GLIA terminal assistant (glia) on the Linux you
#  already use - no ISO needed. Works on Arch, Debian, Fedora and their
#  relatives. Made to be easy for a complete beginner AND transparent
#  for an expert: it shows every step, and with --dry-run it changes
#  nothing at all.
#
#  Usage:
#    bash scripts/install-assistant.sh            guided install
#    bash scripts/install-assistant.sh --dry-run  show steps, change nothing
#    bash scripts/install-assistant.sh --yes      no questions (experts)
#    bash scripts/install-assistant.sh -h         this help
# ============================================================

set -u

# ----------------- CONFIGURATION (edit here) -----------------
ASSIST_NAME="glia"                    # installed command name (rename later: glia --rename jarvis)
INSTALL_DIR="$HOME/.local/bin"        # where the command goes (no root needed)
AICHAT_CONFIG_DIR="$HOME/.config/aichat"
DEFAULT_MODEL="qwen2.5-coder:7b"      # model offered if you accept the download
OLLAMA_INSTALL_URL="https://ollama.com/install.sh"
AICHAT_REPO="sigoden/aichat"          # GitHub repo for the aichat release binary
LOGDIR="$HOME/.local/share/glia"
LOGFILE="$LOGDIR/install-assistant.log"
# -------------------------------------------------------------

DRY_RUN=0
ASSUME_YES=0

# ------------------- ARGUMENTS ---------------------
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        --yes|-y)     ASSUME_YES=1 ;;
        -h|--help)    SHOW_HELP=1 ;;
        *) echo "Unknown option: $arg (use -h for help)" >&2; exit 1 ;;
    esac
done

# ------------------- LANGUAGE ----------------------
case "${LANG:-en}" in it*) UILANG=it ;; de*) UILANG=de ;; *) UILANG=en ;; esac

RED=$'\033[1;31m'; GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'
BLUE=$'\033[1;34m'; DIM=$'\033[2m'; NC=$'\033[0m'

L() {
    case "${UILANG}:${1}" in
        it:title)     echo "Installazione dell'assistente GLIA (glia)" ;;
        de:title)     echo "GLIA-Assistent installieren (glia)" ;;
        *:title)      echo "GLIA assistant install (glia)" ;;
        it:intro)     echo "glia traduce quello che scrivi a parole in comandi del terminale, te li mostra e li esegue solo col tuo ok. Questo script installa glia e i suoi due motori (ollama e aichat) sulla tua distribuzione." ;;
        de:intro)     echo "glia verwandelt deine Worte in Terminal-Befehle, zeigt sie dir und fuehrt sie nur nach deiner Bestaetigung aus. Dieses Skript installiert glia und seine zwei Engines (ollama und aichat) auf deiner Distribution." ;;
        *:intro)      echo "glia turns what you type in plain words into terminal commands, shows them to you, and runs them only with your OK. This script installs glia and its two engines (ollama and aichat) on your distro." ;;
        it:menu1)     echo "  1) Installa adesso" ;;
        de:menu1)     echo "  1) Jetzt installieren" ;;
        *:menu1)      echo "  1) Install now" ;;
        it:menu2)     echo "  2) Prova senza modificare nulla (dry-run)" ;;
        de:menu2)     echo "  2) Testlauf, nichts aendern (dry-run)" ;;
        *:menu2)      echo "  2) Try without changing anything (dry-run)" ;;
        it:menu3)     echo "  3) Esci" ;;
        de:menu3)     echo "  3) Beenden" ;;
        *:menu3)      echo "  3) Quit" ;;
        it:choose)    echo "Scelta [1/2/3]: " ;;
        de:choose)    echo "Auswahl [1/2/3]: " ;;
        *:choose)     echo "Choice [1/2/3]: " ;;
        it:bye)       echo "Uscita. Niente e' stato modificato." ;;
        de:bye)       echo "Beendet. Nichts wurde geaendert." ;;
        *:bye)        echo "Bye. Nothing was changed." ;;
        it:dry_on)    echo "MODALITA' PROVA: mostro i passi ma NON eseguo nulla." ;;
        de:dry_on)    echo "TESTLAUF: zeige die Schritte, fuehre aber NICHTS aus." ;;
        *:dry_on)     echo "DRY-RUN: showing the steps but running NOTHING." ;;
        it:norepo)    echo "Non trovo bin/glia. Lancia lo script dalla cartella del repo GLIA (git clone ... && cd glia)." ;;
        de:norepo)    echo "bin/glia nicht gefunden. Starte das Skript im GLIA-Repo-Ordner (git clone ... && cd glia)." ;;
        *:norepo)     echo "Can't find bin/glia. Run this from the GLIA repo folder (git clone ... && cd glia)." ;;
        it:no_pm)     echo "Package manager non riconosciuto. Installa a mano: curl, jq, ollama, aichat." ;;
        de:no_pm)     echo "Paketmanager nicht erkannt. Manuell installieren: curl, jq, ollama, aichat." ;;
        *:no_pm)      echo "Unknown package manager. Install by hand: curl, jq, ollama, aichat." ;;
        it:pm_found)  echo "Distribuzione rilevata, package manager:" ;;
        de:pm_found)  echo "Distribution erkannt, Paketmanager:" ;;
        *:pm_found)   echo "Detected distro, package manager:" ;;
        it:s_deps)    echo "1/8  Dipendenze di base (curl, jq)" ;;
        de:s_deps)    echo "1/8  Basis-Abhaengigkeiten (curl, jq)" ;;
        *:s_deps)     echo "1/8  Base dependencies (curl, jq)" ;;
        it:s_ollama)  echo "2/8  Ollama (il motore che fa girare l'IA in locale)" ;;
        de:s_ollama)  echo "2/8  Ollama (die lokale KI-Engine)" ;;
        *:s_ollama)   echo "2/8  Ollama (the engine that runs the AI locally)" ;;
        it:s_aichat)  echo "3/8  aichat (il ponte tra glia e ollama)" ;;
        de:s_aichat)  echo "3/8  aichat (die Bruecke zwischen glia und ollama)" ;;
        *:s_aichat)   echo "3/8  aichat (the bridge between glia and ollama)" ;;
        it:s_files)   echo "4/8  Comando glia e glia-hardware in $INSTALL_DIR" ;;
        de:s_files)   echo "4/8  Befehl glia und glia-hardware nach $INSTALL_DIR" ;;
        *:s_files)    echo "4/8  glia and glia-hardware into $INSTALL_DIR" ;;
        it:s_conf)    echo "5/8  Configurazione di aichat" ;;
        de:s_conf)    echo "5/8  aichat-Konfiguration" ;;
        *:s_conf)     echo "5/8  aichat configuration" ;;
        it:s_comp)    echo "6/8  Completamento TAB per la tua shell" ;;
        de:s_comp)    echo "6/8  TAB-Vervollstaendigung fuer deine Shell" ;;
        *:s_comp)     echo "6/8  TAB completion for your shell" ;;
        it:comp_zsh)  echo "zsh: nessun completamento nativo per ora. Puoi usare quello bash con: autoload bashcompinit && bashcompinit && source completions/glia.bash" ;;
        de:comp_zsh)  echo "zsh: noch keine native Vervollstaendigung. Die bash-Variante geht mit: autoload bashcompinit && bashcompinit && source completions/glia.bash" ;;
        *:comp_zsh)   echo "zsh: no native completion yet. You can use the bash one with: autoload bashcompinit && bashcompinit && source completions/glia.bash" ;;
        it:comp_skip) echo "shell non riconosciuta: completamento saltato (vedi la cartella completions/ del repo)." ;;
        de:comp_skip) echo "Shell nicht erkannt: Vervollstaendigung uebersprungen (siehe completions/ im Repo)." ;;
        *:comp_skip)  echo "shell not recognized: completion skipped (see the repo's completions/ folder)." ;;
        it:s_model)   echo "7/8  Modello IA" ;;
        de:s_model)   echo "7/8  KI-Modell" ;;
        *:s_model)    echo "7/8  AI model" ;;
        it:s_check)   echo "8/8  Controllo finale (glia --doctor)" ;;
        de:s_check)   echo "8/8  Abschlusscheck (glia --doctor)" ;;
        *:s_check)    echo "8/8  Final check (glia --doctor)" ;;
        it:have)      echo "gia' presente, salto." ;;
        de:have)      echo "bereits vorhanden, uebersprungen." ;;
        *:have)       echo "already present, skipping." ;;
        it:ollama_note) echo "Uso lo script ufficiale di Ollama (curl | sh). Se preferisci, puoi leggerlo prima su $OLLAMA_INSTALL_URL." ;;
        de:ollama_note) echo "Nutze das offizielle Ollama-Skript (curl | sh). Du kannst es vorher auf $OLLAMA_INSTALL_URL lesen." ;;
        *:ollama_note)  echo "Using Ollama's official script (curl | sh). You can read it first at $OLLAMA_INSTALL_URL." ;;
        it:aichat_dl) echo "Scarico il binario di aichat dalle release di GitHub." ;;
        de:aichat_dl) echo "Lade das aichat-Binary von den GitHub-Releases." ;;
        *:aichat_dl)  echo "Downloading the aichat binary from GitHub releases." ;;
        it:aichat_fail) echo "Non sono riuscito a scaricare aichat. Prendilo a mano da: https://github.com/$AICHAT_REPO/releases" ;;
        de:aichat_fail) echo "aichat-Download fehlgeschlagen. Hol es manuell: https://github.com/$AICHAT_REPO/releases" ;;
        *:aichat_fail)  echo "Could not download aichat. Get it by hand from: https://github.com/$AICHAT_REPO/releases" ;;
        it:model_found) echo "Ho trovato queste IA già scaricate in Ollama:" ;;
        de:model_found) echo "Diese KIs sind in Ollama schon vorhanden:" ;;
        *:model_found)  echo "Found these AIs already downloaded in Ollama:" ;;
        it:model_new)  echo "scarica una nuova IA — consigliata:" ;;
        de:model_new)  echo "eine neue KI laden — empfohlen:" ;;
        *:model_new)   echo "download a new AI — recommended:" ;;
        it:model_pick_q) echo "Quale predefinita? numero o n (Invio = 1): " ;;
        de:model_pick_q) echo "Welche als Standard? Nummer oder n (Enter = 1): " ;;
        *:model_pick_q)  echo "Which default? number or n (Enter = 1): " ;;
        it:model_set)  echo "Modello predefinito impostato:" ;;
        de:model_set)  echo "Standardmodell gesetzt:" ;;
        *:model_set)   echo "Default model set:" ;;
        it:model_ask) echo "Scarico ora il modello consigliato per questa macchina, $REC_MODEL? [s/N]: " ;;
        de:model_ask) echo "Das fuer diesen Rechner empfohlene Modell $REC_MODEL jetzt laden? [j/N]: " ;;
        *:model_ask)  echo "Download $REC_MODEL, the model recommended for this machine, now? [y/N]: " ;;
        it:model_skip) echo "Salto il download. Piu' tardi:  ollama pull $REC_MODEL   (o: glia -m pull, guidato)" ;;
        de:model_skip) echo "Uebersprungen. Spaeter:  ollama pull $REC_MODEL   (oder: glia -m pull, gefuehrt)" ;;
        *:model_skip)  echo "Skipped. Later:  ollama pull $REC_MODEL   (or: glia -m pull, guided)" ;;
        it:path_warn) echo "Attenzione: $INSTALL_DIR non e' nel PATH: il comando non partirebbe scrivendo solo 'glia'." ;;
        de:path_warn) echo "Achtung: $INSTALL_DIR ist nicht im PATH: 'glia' wuerde so nicht starten." ;;
        *:path_warn)  echo "Note: $INSTALL_DIR is not in your PATH, so typing just 'glia' would not work." ;;
        it:path_fix)  echo "Aggiungo $INSTALL_DIR al PATH nella configurazione della tua shell? [S/n]: " ;;
        de:path_fix)  echo "$INSTALL_DIR zur PATH in deiner Shell-Konfig hinzufuegen? [J/n]: " ;;
        *:path_fix)   echo "Add $INSTALL_DIR to your PATH in your shell config? [Y/n]: " ;;
        it:path_done) echo "Fatto. Apri un nuovo terminale (o riavvia la shell) perche' abbia effetto." ;;
        de:path_done) echo "Fertig. Oeffne ein neues Terminal, damit es wirkt." ;;
        *:path_done)  echo "Done. Open a new terminal (or restart your shell) for it to take effect." ;;
        it:done)      echo "Installazione completata." ;;
        de:done)      echo "Installation abgeschlossen." ;;
        *:done)       echo "Installation complete." ;;
        it:try)       echo "Provalo cosi':" ;;
        de:try)       echo "Probier es so:" ;;
        *:try)        echo "Try it like this:" ;;
        it:try_req)   echo "scrivi cosa vuoi fare, a parole tue" ;;
        de:try_req)   echo "schreibe in deinen Worten, was du tun willst" ;;
        *:try_req)    echo "type what you want to do, in your own words" ;;
        it:try_help)  echo "l'aiuto: ti assiste sempre, per qualsiasi informazione" ;;
        de:try_help)  echo "die Hilfe: sie steht dir immer zur Seite, fuer alles" ;;
        *:try_help)   echo "the help: it always has your back, for everything" ;;
        it:try_rename) echo "dai all'assistente il nome che ti piace ('glia' resta sempre)" ;;
        de:try_rename) echo "gib dem Assistenten den Namen, der dir gefaellt ('glia' bleibt immer)" ;;
        *:try_rename)  echo "give the assistant the name you like ('glia' always stays)" ;;
        it:logat)     echo "Log dell'installazione:" ;;
        de:logat)     echo "Installationsprotokoll:" ;;
        *:logat)      echo "Install log:" ;;
    esac
}

show_help() {
    cat <<EOF
$(L title) - v1.0

$(L intro)

Usage:
  bash scripts/install-assistant.sh            guided install
  bash scripts/install-assistant.sh --dry-run  show steps, change nothing
  bash scripts/install-assistant.sh --yes      no questions (experts)
  bash scripts/install-assistant.sh -h         this help

Configurable variables are at the top of this file (command name,
install directory, default model, ...).
EOF
}

# ------------------- HELPERS -----------------------
log() { mkdir -p "$LOGDIR"; printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"; }

# run a command; in dry-run just print it. Everything is logged.
run() {
    log "CMD: $*"
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '   %s[dry-run]%s %s\n' "$DIM" "$NC" "$*"
    else
        "$@"
    fi
}

# run a shell line (pipes/redirections); same dry-run + log behaviour.
run_sh() {
    log "SH: $1"
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '   %s[dry-run]%s %s\n' "$DIM" "$NC" "$1"
    else
        bash -c "$1"
    fi
}

# true only if /dev/tty can actually be opened (not just stat-ed)
tty_ok() { (exec 3</dev/tty) 2>/dev/null; }

# yes/no question. Returns 0 for yes. $2 = default ("y" or "n").
ask_yn() {
    local prompt="$1" def="${2:-n}" ans
    [ "$ASSUME_YES" -eq 1 ] && return 0
    if tty_ok; then read -r -p "$prompt" ans < /dev/tty || ans=""; else ans=""; fi
    ans="${ans,,}"
    [ -z "$ans" ] && ans="$def"
    case "$ans" in s|y|j) return 0 ;; *) return 1 ;; esac
}

# root helper: empty if already root, otherwise "sudo"
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

detect_pm() {
    local p
    for p in pacman apt-get dnf zypper apk; do
        command -v "$p" >/dev/null 2>&1 && { echo "$p"; return; }
    done
    echo ""
}

# install one or more packages with the detected package manager
pm_install() {
    case "$PM" in
        pacman)  run $SUDO pacman -S --needed --noconfirm "$@" ;;
        apt-get) run $SUDO apt-get update -qq; run $SUDO apt-get install -y "$@" ;;
        dnf)     run $SUDO dnf install -y "$@" ;;
        zypper)  run $SUDO zypper --non-interactive install "$@" ;;
        apk)     run $SUDO apk add "$@" ;;
    esac
}

# ------------------- STEPS -------------------------
step_deps() {
    echo -e "${BLUE}$(L s_deps)${NC}"
    local missing=()
    command -v curl >/dev/null 2>&1 || missing+=(curl)
    command -v jq   >/dev/null 2>&1 || missing+=(jq)
    if [ "${#missing[@]}" -eq 0 ]; then
        echo "   curl, jq: $(L have)"
    else
        pm_install "${missing[@]}"
    fi
}

step_ollama() {
    echo -e "${BLUE}$(L s_ollama)${NC}"
    if command -v ollama >/dev/null 2>&1; then
        echo "   ollama: $(L have)"
    else
        echo -e "   ${DIM}$(L ollama_note)${NC}"
        run_sh "curl -fsSL $OLLAMA_INSTALL_URL | sh"
    fi
    # make sure the service is up (the official script usually does this already)
    if command -v systemctl >/dev/null 2>&1; then
        run $SUDO systemctl enable --now ollama
    fi
}

step_aichat() {
    echo -e "${BLUE}$(L s_aichat)${NC}"
    if command -v aichat >/dev/null 2>&1; then
        echo "   aichat: $(L have)"; return
    fi
    if [ "$PM" = pacman ]; then
        pm_install aichat; return
    fi
    echo -e "   ${DIM}$(L aichat_dl)${NC}"
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '   %s[dry-run]%s scarico e installo aichat (musl) da GitHub in %s\n' "$DIM" "$NC" "$INSTALL_DIR"
        return
    fi
    local mach tag asset url tmp
    case "$(uname -m)" in
        x86_64|amd64)  mach=x86_64 ;;
        aarch64|arm64) mach=aarch64 ;;
        *)             mach="$(uname -m)" ;;
    esac
    tag=$(curl -fsSL "https://api.github.com/repos/$AICHAT_REPO/releases/latest" \
          | grep -oE '"tag_name":[[:space:]]*"[^"]+"' | head -1 | grep -oE 'v[0-9][^"]*')
    if [ -n "$tag" ]; then
        asset="aichat-$tag-$mach-unknown-linux-musl.tar.gz"
        url="https://github.com/$AICHAT_REPO/releases/download/$tag/$asset"
        tmp=$(mktemp -d)
        if curl -fsSL "$url" -o "$tmp/aichat.tar.gz" && tar -xzf "$tmp/aichat.tar.gz" -C "$tmp" 2>/dev/null; then
            install -m 755 "$tmp/aichat" "$INSTALL_DIR/aichat" && log "INSTALLED aichat $tag ($mach)"
        else
            echo -e "   ${YELLOW}$(L aichat_fail)${NC}"
        fi
        rm -rf "$tmp"
    else
        echo -e "   ${YELLOW}$(L aichat_fail)${NC}"
    fi
}

step_files() {
    echo -e "${BLUE}$(L s_files)${NC}"
    run mkdir -p "$INSTALL_DIR"
    run install -m 755 "$REPO/bin/glia" "$INSTALL_DIR/$ASSIST_NAME"
    run install -m 755 "$REPO/bin/glia-hardware" "$INSTALL_DIR/glia-hardware"
}

step_config() {
    echo -e "${BLUE}$(L s_conf)${NC}"
    run mkdir -p "$AICHAT_CONFIG_DIR"
    run cp "$REPO/config/aichat-config.yaml" "$AICHAT_CONFIG_DIR/config.yaml"
}

step_path() {
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) return ;;   # already in PATH, nothing to do
    esac
    echo -e "${YELLOW}$(L path_warn)${NC}"
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '   %s[dry-run]%s add %s to PATH in your shell config\n' "$DIM" "$NC" "$INSTALL_DIR"
        return
    fi
    ask_yn "$(L path_fix)" y || return
    local shname rc line
    shname="$(basename "${SHELL:-bash}")"
    case "$shname" in
        fish) rc="$HOME/.config/fish/config.fish"; line="fish_add_path $INSTALL_DIR" ;;
        zsh)  rc="$HOME/.zshrc";  line="export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
        *)    rc="$HOME/.bashrc"; line="export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
    esac
    mkdir -p "$(dirname "$rc")"
    if ! grep -qF "$INSTALL_DIR" "$rc" 2>/dev/null; then
        printf '\n# added by GLIA install-assistant\n%s\n' "$line" >> "$rc"
        log "PATH: appended '$line' to $rc"
    fi
    echo -e "   ${GREEN}$(L path_done)${NC}"
}

step_completions() {
    # TAB completion for the user's shell; generic, nothing machine-specific
    echo -e "${BLUE}$(L s_comp)${NC}"
    local shname
    shname="$(basename "${SHELL:-bash}")"
    case "$shname" in
        fish)
            run mkdir -p "$HOME/.config/fish/completions"
            run cp "$REPO/completions/glia.fish" "$HOME/.config/fish/completions/glia.fish"
            ;;
        bash)
            run mkdir -p "$HOME/.local/share/bash-completion/completions"
            run cp "$REPO/completions/glia.bash" "$HOME/.local/share/bash-completion/completions/glia"
            ;;
        zsh)
            echo -e "   ${DIM}$(L comp_zsh)${NC}"
            ;;
        *)
            echo -e "   ${DIM}$(L comp_skip)${NC}"
            ;;
    esac
}

step_model() {
    echo -e "${BLUE}$(L s_model)${NC}"
    # the model offered is the one glia-hardware recommends for THIS machine
    REC_MODEL=$("$REPO/bin/glia-hardware" -m 2>/dev/null)
    [ -z "$REC_MODEL" ] && REC_MODEL="$DEFAULT_MODEL"
    # models ALREADY downloaded in ollama (v1.3): offer them first
    local models
    models=$(ollama list 2>/dev/null | awk 'NR>1 && $1!="" {print $1}' | sort)

    if [ "$DRY_RUN" -eq 1 ]; then
        # a dry run never asks questions: it only SHOWS what the real run will do
        if [ -n "$models" ]; then
            printf '   %s[dry-run]%s %s\n' "$DIM" "$NC" "$(L model_found)"
            printf '%s\n' "$models" | sed 's/^/              /'
            printf '   %s[dry-run]%s %s\n' "$DIM" "$NC" "$(L model_pick_q)"
        else
            printf '   %s[dry-run]%s %s\n' "$DIM" "$NC" "$(L model_ask)"
            printf '   %s[dry-run]%s ollama pull %s\n' "$DIM" "$NC" "$REC_MODEL"
        fi
        return
    fi

    if [ -n "$models" ]; then
        # something is already there: pick a default, or pull a new one
        local i=1 name choice sel
        echo "   $(L model_found)"
        while IFS= read -r name; do
            printf '     %d) %s\n' "$i" "$name"
            i=$((i+1))
        done <<< "$models"
        printf '     n) %s %s\n' "$(L model_new)" "$REC_MODEL"
        if tty_ok && [ "$ASSUME_YES" -eq 0 ]; then
            read -r -p "   $(L model_pick_q)" choice < /dev/tty || choice=""
        else
            choice=""
        fi
        sel=""
        case "$choice" in
            n|N) run_sh "ollama pull $REC_MODEL"; sel="$REC_MODEL" ;;
            *)   [ -z "$choice" ] && choice=1
                 sel=$(printf '%s\n' "$models" | sed -n "${choice}p")
                 [ -z "$sel" ] && sel=$(printf '%s\n' "$models" | head -n1) ;;
        esac
        mkdir -p "$HOME/.config/glia"
        printf '%s\n' "$sel" > "$HOME/.config/glia/model"
        echo -e "   ${GREEN}$(L model_set) $sel${NC}   ${DIM}(echo '$sel' > ~/.config/glia/model)${NC}"
        log "MODEL default: $sel"
        return
    fi

    # nothing downloaded yet: offer the recommended model
    "$REPO/bin/glia-hardware" 2>/dev/null || true
    if ask_yn "$(L model_ask)" n; then
        run_sh "ollama pull $REC_MODEL"
        mkdir -p "$HOME/.config/glia"
        printf '%s\n' "$REC_MODEL" > "$HOME/.config/glia/model"
        log "MODEL default: $REC_MODEL"
    else
        echo -e "   ${DIM}$(L model_skip)${NC}"
    fi
}

step_check() {
    # final health check with glia's own doctor: the new user sees at once
    # whether everything is green (engine, model, RAM, PATH, folders)
    echo -e "${BLUE}$(L s_check)${NC}"
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '   %s[dry-run]%s %s --doctor\n' "$DIM" "$NC" "$ASSIST_NAME"
        return
    fi
    "$INSTALL_DIR/$ASSIST_NAME" --doctor || true
}

# --------------------- MAIN ------------------------
REPO="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${SHOW_HELP:-0}" = 1 ]; then show_help; exit 0; fi

command -v clear >/dev/null 2>&1 && clear
echo -e "${GREEN}=== $(L title) ===${NC}"
echo
echo "$(L intro)" | fold -s -w 72
echo

# choice menu (skipped when --dry-run or --yes were passed)
if [ "$DRY_RUN" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    echo "$(L menu1)"; echo "$(L menu2)"; echo "$(L menu3)"; echo
    if tty_ok; then read -r -p "$(L choose)" ch < /dev/tty || ch=3; else ch=3; fi
    case "$ch" in
        1) : ;;
        2) DRY_RUN=1 ;;
        *) echo "$(L bye)"; exit 0 ;;
    esac
fi
[ "$DRY_RUN" -eq 1 ] && echo -e "${YELLOW}$(L dry_on)${NC}"

# must run from inside the repo (needs bin/glia, bin/glia-hardware, config/)
if [ ! -f "$REPO/bin/glia" ]; then
    echo -e "${RED}$(L norepo)${NC}" >&2; exit 1
fi

PM="$(detect_pm)"
if [ -n "$PM" ]; then
    echo -e "${DIM}$(L pm_found) $PM${NC}"
else
    echo -e "${YELLOW}$(L no_pm)${NC}"
fi
echo
log "START (dry_run=$DRY_RUN, pm=${PM:-none}, name=$ASSIST_NAME)"

step_deps
step_ollama
step_aichat
step_files
step_config
step_completions
step_path
step_model
step_check

echo
echo -e "${GREEN}$(L done)${NC}"
echo -e "$(L try)"
echo "   ${ASSIST_NAME} \"...\"                # $(L try_req)"
echo "   ${ASSIST_NAME} -h                   # $(L try_help)"
echo "   ${ASSIST_NAME} --rename <nome>      # $(L try_rename)"
echo -e "${DIM}$(L logat) $LOGFILE${NC}"
log "END"
