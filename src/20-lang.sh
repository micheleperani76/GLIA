# ============================================================
#  D4 (v2.19.3): the errors where the popular fix is worse than the problem.
#  The fix loop asks the AI for a corrected command. For a handful of errors
#  that is exactly the wrong move: the model read the same forums the user
#  would, and the top-voted answer to some of these is a permanent,
#  system-wide security downgrade. On the ground we KNOW, we don't ask - we
#  say what happened, what actually fixes it, and what not to do. Same rule as
#  `-m bench` (a number beats a heuristic) and --danger's built-ins.
#
#  MATCH ONLY ON WHAT DOESN'T TRANSLATE. pacman speaks the user's language -
#  verified on this machine: `LANG=it_IT pacman -Q nope` says "errore:
#  impossibile trovare il pacchetto". A regex on its prose breaks on the next
#  locale. File extensions, HTTP codes, exit codes and tool names don't move.
#
#    id | pkgmgr ('*' = any) | pattern | second pattern (both must match)
#
#  Lean TIGHT: a miss costs nothing (you get today's behaviour - the AI is
#  asked), while a false positive lectures someone about an error they don't
#  have, and that is how people learn to skip what we say. Plain `\.sig` also
#  matched "config.sig.bak is 404 lines long"; the trailing class stops it
#  eating into a longer name - the anchoring lesson from rm-vs-terrafo(rm).
#
#  '|' IS THE FIELD SEPARATOR, so a pattern must never contain one: write
#  [abc] instead of (a|b|c). The first draft of the row below used an
#  alternation, IFS split the regex in half, and the rule silently stopped
#  matching anything at all - a guard that quietly guards nothing.
KNOWN_ERRORS=(
    "sig404|pacman|\.sig[^.[:alnum:]]|404"
)

# Binaries that need root to CHANGE the system (v1.8 auto-sudo).
# If a command starts with one of these and has no sudo, we add it ourselves.
ROOT_BINS='pacman|paccache|pacman-key|pacman-mirrors|pacstrap|apt|apt-get|dnf|zypper|apk|systemctl|mount|umount|swapon|swapoff|mkfs|fsck|parted|fdisk|cfdisk|sgdisk|wipefs|modprobe|timedatectl|hwclock|useradd|usermod|userdel|groupadd|chpasswd|visudo|reboot|poweroff|shutdown|halt'

OS_NAME=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}")
# Anchor the model to the local machine: name the package manager explicitly
PKGMGR=""
for p in pacman apt dnf zypper apk; do
    command -v "$p" >/dev/null 2>&1 && { PKGMGR="$p"; break; }
done

# install-command hint for the local package manager (arch/debian/fedora/...)
pkg_install_cmd() {
    case "$PKGMGR" in
        pacman)      echo "sudo pacman -S $*" ;;
        apt|apt-get) echo "sudo apt install $*" ;;
        dnf)         echo "sudo dnf install $*" ;;
        zypper)      echo "sudo zypper install $*" ;;
        apk)         echo "sudo apk add $*" ;;
        *)           echo "install $*" ;;
    esac
}
CONTEXT="System: ${OS_NAME:-Linux}, user: $USER.${PKGMGR:+ The package manager on THIS machine is $PKGMGR.} \
Commands will be executed with bash. When something can be solved by restarting a \
single service, prefer 'systemctl restart <service>' over rebooting the whole \
machine; suggest a full reboot ONLY when strictly necessary (e.g. after a kernel \
update). For commands that would run FOREVER (ping, top, tail -f, watch) prefer a \
bounded variant instead, e.g. 'ping -c 5'. Reply ONLY with a single-line bash command, \
no explanations, no markdown, no backticks."
# ---------------------------------------------------

# ------------------- LANGUAGE ----------------------
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'

case "$UILANG" in
    it) CONFIRM_WORD="SI";  PLAN_LANG="Italian"; YES_KEY="s" ;;
    de) CONFIRM_WORD="JA";  PLAN_LANG="German";  YES_KEY="j" ;;
    *)  CONFIRM_WORD="YES"; PLAN_LANG="English"; YES_KEY="y" ;;
esac

t() {
    case "${UILANG}:${1}" in
        it:thinking)        echo "Sto pensando..." ;;
        de:thinking)        echo "Denke nach..." ;;
        *:thinking)         echo "Thinking..." ;;
        it:proposed)        echo "Comando proposto: " ;;
        de:proposed)        echo "Vorgeschlagener Befehl: " ;;
        *:proposed)         echo "Proposed command: " ;;
        it:warn)            echo "⚠ ATTENZIONE: comando potenzialmente distruttivo." ;;
        de:warn)            echo "⚠ ACHTUNG: potenziell zerstörerischer Befehl." ;;
        *:warn)             echo "⚠ WARNING: potentially destructive command." ;;
        it:ask_danger)      echo "$YES_KEY = esegui | Invio o n = annulla | r = riprova | m = modifica: " ;;
        de:ask_danger)      echo "$YES_KEY = ausführen | Enter oder n = abbrechen | r = wiederholen | m = bearbeiten: " ;;
        *:ask_danger)       echo "$YES_KEY = run | Enter or n = cancel | r = retry | m = edit: " ;;
        it:ask_reboot)      echo "Questo RIAVVIA/SPEGNE la macchina. $YES_KEY = procedi | Invio o n = annulla | r = riprova | m = modifica: " ;;
        de:ask_reboot)      echo "Dies STARTET/SCHALTET die Maschine. $YES_KEY = fortfahren | Enter oder n = abbrechen | r = wiederholen | m = bearbeiten: " ;;
        *:ask_reboot)       echo "This will REBOOT/SHUT DOWN the machine. $YES_KEY = proceed | Enter or n = cancel | r = retry | m = edit: " ;;
        it:ask_normal)      echo "Invio = esegui | n = annulla | r = riprova | m = modifica | e = spiega | testo = indizio per l'IA: " ;;
        de:ask_normal)      echo "Enter = ausführen | n = abbrechen | r = wiederholen | m = bearbeiten | e = erklären | Text = Hinweis für die KI: " ;;
        *:ask_normal)       echo "Enter = run | n = cancel | r = retry | m = edit | e = explain | text = hint for the AI: " ;;
        it:edit_cmd)        echo "Modifica il comando e premi Invio (vuoto = annulla):" ;;
        de:edit_cmd)        echo "Befehl bearbeiten und Enter drücken (leer = abbrechen):" ;;
        *:edit_cmd)         echo "Edit the command and press Enter (empty = cancel):" ;;
        it:cancelled)       echo "Annullato." ;;
        de:cancelled)       echo "Abgebrochen." ;;
        *:cancelled)        echo "Cancelled." ;;
        it:rc_confirm_generic) echo "Invio o n = annulla | $YES_KEY = conferma: " ;;
        de:rc_confirm_generic) echo "Enter oder n = abbrechen | $YES_KEY = bestaetigen: " ;;
        *:rc_confirm_generic)  echo "Enter or n = cancel | $YES_KEY = confirm: " ;;
        it:rc_channel)      echo "canale" ;;
        de:rc_channel)      echo "Kanal" ;;
        *:rc_channel)       echo "channel" ;;
        it:rc_chan_expl)    echo "stable = solo versioni definitive (vX.Y.Z); beta = anche le anteprime (-beta/-rc). Cambia con: --channel beta|stable" ;;
        de:rc_chan_expl)    echo "stable = nur finale Versionen (vX.Y.Z); beta = auch Vorabversionen (-beta/-rc). Wechseln: --channel beta|stable" ;;
        *:rc_chan_expl)     echo "stable = final versions only (vX.Y.Z); beta = also previews (-beta/-rc). Switch with: --channel beta|stable" ;;
        it:rc_chan_set)     echo "canale impostato su:" ;;
        de:rc_chan_set)     echo "Kanal gesetzt auf:" ;;
        *:rc_chan_set)      echo "channel set to:" ;;
        it:rc_chan_beta_warn) echo "Sei sul canale beta: riceverai anteprime (-beta/-rc), meno testate." ;;
        de:rc_chan_beta_warn) echo "Du bist im Beta-Kanal: du erhaeltst Vorabversionen (-beta/-rc), weniger getestet." ;;
        *:rc_chan_beta_warn)  echo "You are on the beta channel: you will get previews (-beta/-rc), less tested." ;;
        it:rc_chan_bad)     echo "Canale non valido. Usa: stable | beta" ;;
        de:rc_chan_bad)     echo "Ungueltiger Kanal. Nutze: stable | beta" ;;
        *:rc_chan_bad)      echo "Invalid channel. Use: stable | beta" ;;
        it:rc_installed)    echo "installato:" ;;
        de:rc_installed)    echo "installiert:" ;;
        *:rc_installed)     echo "installed:" ;;
        it:rc_tag_fallback) echo "tag non registrato: per gli aggiornamenti assumo" ;;
        de:rc_tag_fallback) echo "Tag nicht vermerkt: für Updates nehme ich an" ;;
        *:rc_tag_fallback)  echo "no tag recorded: updates assume" ;;
        it:rc_tag_fallback_fix) echo "se hai installato a mano, scrivi il tag reale in:" ;;
        de:rc_tag_fallback_fix) echo "bei Handinstallation den echten Tag eintragen in:" ;;
        *:rc_tag_fallback_fix)  echo "if you installed by hand, write the real tag into:" ;;
        it:rc_lastcheck)    echo "ultimo controllo" ;;
        de:rc_lastcheck)    echo "letzte Pruefung" ;;
        *:rc_lastcheck)     echo "last check" ;;
        it:rc_never)        echo "mai (esegui: --update --check)" ;;
        de:rc_never)        echo "nie (fuehre aus: --update --check)" ;;
        *:rc_never)         echo "never (run: --update --check)" ;;
        it:rc_stale_ok)     echo "risultava aggiornato (riprova online per esserne certo)" ;;
        de:rc_stale_ok)     echo "war auf dem neuesten Stand (online erneut pruefen)" ;;
        *:rc_stale_ok)      echo "was up to date (check again online to be sure)" ;;
        it:rc_stale_yes)    echo "risultava disponibile" ;;
        de:rc_stale_yes)    echo "war verfuegbar" ;;
        *:rc_stale_yes)     echo "was available" ;;
        it:rc_offline_v)    echo "offline: dato dall'ultimo controllo" ;;
        de:rc_offline_v)    echo "offline: Stand der letzten Pruefung" ;;
        *:rc_offline_v)     echo "offline: as of the last check" ;;
        it:rc_notags)       echo "nessun tag di release ancora presente sul remoto" ;;
        de:rc_notags)       echo "noch keine Release-Tags im Remote vorhanden" ;;
        *:rc_notags)        echo "no release tags on the remote yet" ;;
        it:rc_backupwarn)   echo "avviso: backup della versione corrente non riuscito (procedo comunque)" ;;
        de:rc_backupwarn)   echo "Warnung: Backup der aktuellen Version fehlgeschlagen (fahre trotzdem fort)" ;;
        *:rc_backupwarn)    echo "warning: backup of the current version failed (continuing anyway)" ;;
        it:rc_rollhint)     echo "Per tornare indietro:" ;;
        de:rc_rollhint)     echo "Zum Zuruecksetzen:" ;;
        *:rc_rollhint)      echo "To roll back:" ;;
        it:rc_updconfirm)   echo "$YES_KEY = aggiorna | Invio o n = annulla: " ;;
        de:rc_updconfirm)   echo "$YES_KEY = aktualisieren | Enter oder n = abbrechen: " ;;
        *:rc_updconfirm)    echo "$YES_KEY = update | Enter or n = cancel: " ;;
        it:rc_rolllist)     echo "Versioni disponibili per tornare indietro (backup locali):" ;;
        de:rc_rolllist)     echo "Verfuegbare Versionen zum Zuruecksetzen (lokale Backups):" ;;
        *:rc_rolllist)      echo "Versions available to roll back to (local backups):" ;;
        it:rc_rollcurrent)  echo "in uso ora" ;;
        de:rc_rollcurrent)  echo "derzeit aktiv" ;;
        *:rc_rollcurrent)   echo "running now" ;;
        it:rc_rollwhen)     echo "in uso il" ;;
        de:rc_rollwhen)     echo "aktiv am" ;;
        *:rc_rollwhen)      echo "in use on" ;;
        it:rc_rollpick)     echo "Numero (Invio = 1, altro = annulla): " ;;
        de:rc_rollpick)     echo "Nummer (Enter = 1, sonst = abbrechen): " ;;
        *:rc_rollpick)      echo "Number (Enter = 1, anything else = cancel): " ;;
        it:rc_rollto)       echo "Torno alla versione:" ;;
        de:rc_rollto)       echo "Zuruecksetzen auf Version:" ;;
        *:rc_rollto)        echo "Rolling back to version:" ;;
        it:rc_rollconfirm)  echo "$YES_KEY = torna a questa versione | Invio o n = annulla: " ;;
        de:rc_rollconfirm)  echo "$YES_KEY = auf diese Version zurueck | Enter oder n = abbrechen: " ;;
        *:rc_rollconfirm)   echo "$YES_KEY = roll back to this version | Enter or n = cancel: " ;;
        it:rc_rollsame)     echo "E' gia' la versione in uso." ;;
        de:rc_rollsame)     echo "Das ist bereits die laufende Version." ;;
        *:rc_rollsame)      echo "That is already the running version." ;;
        it:rc_norollback)   echo "Nessun backup disponibile: il rollback e' possibile dopo il primo aggiornamento." ;;
        de:rc_norollback)   echo "Keine Backups vorhanden: Rollback ist nach dem ersten Update moeglich." ;;
        *:rc_norollback)    echo "No backups available: rollback becomes possible after the first update." ;;
        it:doc_rc_version)  echo "versione installata:" ;;
        de:doc_rc_version)  echo "installierte Version:" ;;
        *:doc_rc_version)   echo "installed version:" ;;
        it:doc_rc_source)   echo "eseguibile in uso:" ;;
        de:doc_rc_source)   echo "laufende Datei:" ;;
        *:doc_rc_source)    echo "running file:" ;;
        it:doc_rc_backups)  echo "versioni per il rollback:" ;;
        de:doc_rc_backups)  echo "Versionen fuer Rollback:" ;;
        *:doc_rc_backups)   echo "versions available for rollback:" ;;
        it:doc_rc_nobackups) echo "nessun backup ancora (arrivano col primo aggiornamento)" ;;
        de:doc_rc_nobackups) echo "noch keine Backups (kommen mit dem ersten Update)" ;;
        *:doc_rc_nobackups)  echo "no backups yet (they appear with the first update)" ;;
        it:no_command)      echo "Nessun comando generato." ;;
        de:no_command)      echo "Kein Befehl erzeugt." ;;
        *:no_command)       echo "No command generated." ;;
        it:model_error)     echo "Errore dal motore IA:" ;;
        de:model_error)     echo "Fehler von der KI-Engine:" ;;
        *:model_error)      echo "Error from the AI engine:" ;;
        it:ollama_start)    echo "Ollama non è in esecuzione, lo avvio..." ;;
        de:ollama_start)    echo "Ollama läuft nicht, starte es..." ;;
        *:ollama_start)     echo "Ollama is not running, starting it..." ;;
        it:ollama_fail)     echo "Ollama non parte. Controlla con: systemctl status ollama" ;;
        de:ollama_fail)     echo "Ollama startet nicht. Prüfe mit: systemctl status ollama" ;;
        *:ollama_fail)      echo "Ollama could not be started. Check with: systemctl status ollama" ;;
        it:model_missing)   echo "Il modello ${MODEL#ollama:} non è ancora scaricato." ;;
        de:model_missing)   echo "Das Modell ${MODEL#ollama:} ist noch nicht heruntergeladen." ;;
        *:model_missing)    echo "The model ${MODEL#ollama:} is not downloaded yet." ;;
        it:download_with)   echo "Scaricalo con:  ollama pull ${MODEL#ollama:}   (o esegui glia-hardware per un consiglio)" ;;
        de:download_with)   echo "Herunterladen mit:  ollama pull ${MODEL#ollama:}   (oder glia-hardware für eine Empfehlung)" ;;
        *:download_with)    echo "Download it with:  ollama pull ${MODEL#ollama:}   (or run glia-hardware for advice)" ;;
        it:low_ram)         echo "Poca RAM libera per questo modello: potrebbe fallire o essere lentissimo." ;;
        de:low_ram)         echo "Wenig freier RAM für dieses Modell: kann fehlschlagen oder sehr langsam sein." ;;
        *:low_ram)          echo "Low free RAM for this model: it may fail or be very slow." ;;
        it:no_log)          echo "Ancora nessun log ($LOGFILE)." ;;
        de:no_log)          echo "Noch kein Protokoll ($LOGFILE)." ;;
        *:no_log)           echo "No log yet ($LOGFILE)." ;;
        it:mem_saved)       echo "Memorizzato." ;;
        de:mem_saved)       echo "Gespeichert." ;;
        *:mem_saved)        echo "Stored." ;;
        it:mem_empty)       echo "Nessun fatto memorizzato ($MEMFILE)." ;;
        de:mem_empty)       echo "Keine Fakten gespeichert ($MEMFILE)." ;;
        *:mem_empty)        echo "No facts stored ($MEMFILE)." ;;
        it:mem_file)        echo "il file lo puoi modificare in:" ;;
        de:mem_file)        echo "die Datei kannst du bearbeiten in:" ;;
        *:mem_file)         echo "you can edit the file at:" ;;
        it:mem_usage)       echo "Uso: $PROG --remember \"<fatto>\"" ;;
        de:mem_usage)       echo "Verwendung: $PROG --remember \"<Fakt>\"" ;;
        *:mem_usage)        echo "Usage: $PROG --remember \"<fact>\"" ;;
        it:forget_usage)    echo "Uso: $PROG --forget <numero>   (vedi: $PROG --memory)" ;;
        de:forget_usage)    echo "Verwendung: $PROG --forget <Nummer>   (siehe: $PROG --memory)" ;;
        *:forget_usage)     echo "Usage: $PROG --forget <number>   (see: $PROG --memory)" ;;
        it:forgotten)       echo "Dimenticato:" ;;
        de:forgotten)       echo "Vergessen:" ;;
        *:forgotten)        echo "Forgotten:" ;;
        it:renamed)         echo "Fatto. Il tuo assistente ora si chiama:" ;;
        de:renamed)         echo "Fertig. Dein Assistent heißt jetzt:" ;;
        *:renamed)          echo "Done. Your assistant is now called:" ;;
        it:rename_invalid)  echo "Nome non valido (lettere, numeri, - o _; deve iniziare con una lettera)." ;;
        de:rename_invalid)  echo "Ungültiger Name (Buchstaben, Zahlen, - oder _; muss mit Buchstabe beginnen)." ;;
        *:rename_invalid)   echo "Invalid name (letters, digits, - or _; must start with a letter)." ;;
        it:rename_exists)   echo "Esiste già un comando con questo nome." ;;
        de:rename_exists)   echo "Ein Befehl mit diesem Namen existiert bereits." ;;
        *:rename_exists)    echo "A command with that name already exists." ;;
        it:rename_denied)   echo "Permesso negato. Prova con: sudo $PROG --rename" ;;
        de:rename_denied)   echo "Zugriff verweigert. Versuche: sudo $PROG --rename" ;;
        *:rename_denied)    echo "Permission denied. Try: sudo $PROG --rename" ;;
        it:rename_isglia)   echo "'glia' e' il nome di sicurezza e non puo' essere usato come soprannome." ;;
        de:rename_isglia)   echo "'glia' ist der Sicherheitsname und kann kein Spitzname sein." ;;
        *:rename_isglia)    echo "'glia' is the safety name and can't be used as a nickname." ;;
        it:rename_anchor)   echo "'glia' resta sempre disponibile" ;;
        de:rename_anchor)   echo "'glia' bleibt immer verfuegbar" ;;
        *:rename_anchor)    echo "'glia' stays available too" ;;
        it:rename_forbid)   echo "Nome riservato: e' un comando essenziale del sistema (o di GLIA stesso). Chiamare cosi' l'assistente te lo coprirebbe, e non e' un rischio che ti lascio correre." ;;
        de:rename_forbid)   echo "Reservierter Name: ein essenzieller Systembefehl (oder GLIA selbst). Ihn zu ueberdecken ist kein Risiko, das ich dich eingehen lasse." ;;
        *:rename_forbid)    echo "Reserved name: it is an essential system command (or GLIA itself). Naming the assistant that would shadow it, and that is not a risk I will let you take." ;;
        it:rename_shadow)   echo "Questo nome e' gia' un comando sulla tua macchina:" ;;
        de:rename_shadow)   echo "Dieser Name ist auf deinem Rechner bereits ein Befehl:" ;;
        *:rename_shadow)    echo "That name is already a command on your machine:" ;;
        it:rename_shadow_w) echo "Chiamare cosi' l'assistente lo coprirebbe: scrivendo il comando partirebbe GLIA al suo posto." ;;
        de:rename_shadow_w) echo "Den Assistenten so zu nennen wuerde ihn ueberdecken: der Befehl wuerde GLIA starten." ;;
        *:rename_shadow_w)  echo "Naming the assistant that would shadow it: typing the command would start GLIA instead." ;;
        it:rename_try)      echo "Liberi, se ti piacciono:" ;;
        de:rename_try)      echo "Frei, falls sie dir gefallen:" ;;
        *:rename_try)       echo "Free, if you like them:" ;;
        it:rename_try2)     echo "oppure scegline un altro:" ;;
        de:rename_try2)     echo "oder waehle einen anderen:" ;;
        *:rename_try2)      echo "or pick another one:" ;;
        it:rename_oldgone)  echo "Il nome precedente non risponde piu':" ;;
        de:rename_oldgone)  echo "Der vorherige Name antwortet nicht mehr:" ;;
        *:rename_oldgone)   echo "The previous name does not answer any more:" ;;
        it:proj_ask)        echo "Esiste già la cartella progetti col vecchio nome. La rinomino al nuovo nome?" ;;
        de:proj_ask)        echo "Es gibt bereits den Projektordner mit dem alten Namen. Auf den neuen Namen umbenennen?" ;;
        *:proj_ask)         echo "A projects folder with the old name exists. Rename it to the new name?" ;;
        it:proj_migrated)   echo "Cartella progetti rinominata:" ;;
        de:proj_migrated)   echo "Projektordner umbenannt:" ;;
        *:proj_migrated)    echo "Projects folder renamed:" ;;
        it:proj_kept)       echo "Cartella progetti lasciata com'era:" ;;
        de:proj_kept)       echo "Projektordner unverändert gelassen:" ;;
        *:proj_kept)        echo "Projects folder left as it was:" ;;
        it:proj_target_exists) echo "Esiste già una cartella col nuovo nome, non tocco niente:" ;;
        de:proj_target_exists) echo "Ein Ordner mit dem neuen Namen existiert bereits, nichts geändert:" ;;
        *:proj_target_exists)  echo "A folder with the new name already exists, leaving everything:" ;;
        it:glia_inhibited)  echo "L'assistente ora si chiama '$ASSIST_NAME'. Il comando 'glia' serve solo da recupero: usa '$ASSIST_NAME ...' oppure 'glia -h'." ;;
        de:glia_inhibited)  echo "Der Assistent heißt jetzt '$ASSIST_NAME'. Der Befehl 'glia' dient nur zur Wiederherstellung: nutze '$ASSIST_NAME ...' oder 'glia -h'." ;;
        *:glia_inhibited)   echo "The assistant is now called '$ASSIST_NAME'. The 'glia' command is only for recovery: use '$ASSIST_NAME ...' or 'glia -h'." ;;
        it:lang_set)        echo "Lingua impostata: " ;;
        de:lang_set)        echo "Sprache eingestellt: " ;;
        *:lang_set)         echo "Language set: " ;;
        it:lang_usage)      echo "Uso: $PROG --lang it|en|de" ;;
        de:lang_usage)      echo "Verwendung: $PROG --lang it|en|de" ;;
        *:lang_usage)       echo "Usage: $PROG --lang it|en|de" ;;
        # ---- project mode ----
        it:planning)        echo "Preparo il piano del progetto..." ;;
        de:planning)        echo "Erstelle den Projektplan..." ;;
        *:planning)         echo "Preparing the project plan..." ;;
        it:plan)            echo "PIANO DEL PROGETTO" ;;
        de:plan)            echo "PROJEKTPLAN" ;;
        *:plan)             echo "PROJECT PLAN" ;;
        it:steps)           echo "Passi:" ;;
        de:steps)           echo "Schritte:" ;;
        *:steps)            echo "Steps:" ;;
        it:files)           echo "File da creare:" ;;
        de:files)           echo "Zu erstellende Dateien:" ;;
        *:files)            echo "Files to create:" ;;
        it:step_create)     echo "Creo" ;;
        de:step_create)     echo "Ich erstelle" ;;
        *:step_create)      echo "I create" ;;
        it:go)              echo "Invio = procedi | scrivi un indizio per rifare il piano | n = annulla: " ;;
        de:go)              echo "Enter = weiter | schreibe einen Hinweis für einen neuen Plan | n = abbrechen: " ;;
        *:go)               echo "Enter = proceed | type a hint to redo the plan | n = cancel: " ;;
        it:writing)         echo "Genero il file" ;;
        de:writing)         echo "Erzeuge Datei" ;;
        *:writing)          echo "Generating file" ;;
        it:preview)         echo "Anteprima (prime 20 righe):" ;;
        de:preview)         echo "Vorschau (erste 20 Zeilen):" ;;
        *:preview)          echo "Preview (first 20 lines):" ;;
        it:save)            echo "Invio = salva | v = vedi tutto | r = rigenera | scrivi un indizio | s = salta: " ;;
        de:save)            echo "Enter = speichern | v = alles zeigen | r = neu | schreibe einen Hinweis | s = überspringen: " ;;
        *:save)             echo "Enter = save | v = view all | r = regenerate | type a hint | s = skip: " ;;
        it:saved)           echo "Salvato:" ;;
        de:saved)           echo "Gespeichert:" ;;
        *:saved)            echo "Saved:" ;;
        it:skipped)         echo "Saltato." ;;
        de:skipped)         echo "Übersprungen." ;;
        *:skipped)          echo "Skipped." ;;
        it:new_check_retry) echo "Controllo automatico fallito, rigenero. Tentativo" ;;
        de:new_check_retry) echo "Automatische Prüfung fehlgeschlagen, erzeuge neu. Versuch" ;;
        *:new_check_retry)  echo "Automatic check failed, regenerating. Attempt" ;;
        it:new_check_warn)  echo "ATTENZIONE: il controllo automatico fallisce anche dopo i tentativi:" ;;
        de:new_check_warn)  echo "ACHTUNG: die automatische Prüfung schlägt auch nach den Versuchen fehl:" ;;
        *:new_check_warn)   echo "WARNING: the automatic check still fails after the retries:" ;;
        it:new_check_saved) echo "Salvato CON AVVISO: controlla il file prima di usarlo (vedi log)." ;;
        de:new_check_saved) echo "MIT WARNUNG gespeichert: Datei vor Gebrauch prüfen (siehe Log)." ;;
        *:new_check_saved)  echo "Saved WITH WARNING: check the file before using it (see log)." ;;
        it:proj_dir)        echo "Cartella del progetto:" ;;
        de:proj_dir)        echo "Projektordner:" ;;
        *:proj_dir)         echo "Project folder:" ;;
        it:proj_done)       echo "Progetto creato in:" ;;
        de:proj_done)       echo "Projekt erstellt in:" ;;
        *:proj_done)        echo "Project created in:" ;;
        it:proj_created)    echo "Cartella creata:" ;;
        de:proj_created)    echo "Ordner erstellt:" ;;
        *:proj_created)     echo "Folder created:" ;;
        it:plan_fail)       echo "Il modello non ha prodotto un piano valido. Riprova (elenca esplicitamente i file che vuoi)." ;;
        de:plan_fail)       echo "Das Modell hat keinen gültigen Plan erzeugt. Versuche es erneut (liste die Dateien explizit auf)." ;;
        *:plan_fail)        echo "The model did not produce a valid plan. Try again (list the files you want explicitly)." ;;
        it:badpath)         echo "Percorso file non sicuro, saltato:" ;;
        de:badpath)         echo "Unsicherer Dateipfad, übersprungen:" ;;
        *:badpath)          echo "Unsafe file path, skipped:" ;;
        it:need_jq)         echo "La modalità progetto richiede jq:  $(pkg_install_cmd jq)" ;;
        de:need_jq)         echo "Der Projektmodus benötigt jq:  $(pkg_install_cmd jq)" ;;
        *:need_jq)          echo "Project mode requires jq:  $(pkg_install_cmd jq)" ;;
        it:chat_hint)       echo "Chat con ${MODEL#ollama:} · /aiuto = comandi · /esci o Ctrl+D = esci" ;;
        de:chat_hint)       echo "Chat mit ${MODEL#ollama:} · /hilfe = Befehle · /ende oder Strg+D = beenden" ;;
        *:chat_hint)        echo "Chat with ${MODEL#ollama:} · /help = commands · /exit or Ctrl+D = quit" ;;
        it:chat_prompt)     echo "tu" ;;
        de:chat_prompt)     echo "du" ;;
        *:chat_prompt)      echo "you" ;;
        it:chat_turn)       echo "turno" ;;
        de:chat_turn)       echo "Runde" ;;
        *:chat_turn)        echo "turn" ;;
        it:chat_full)       echo "Contesto quasi pieno: il modello sta per scordare l'inizio. /salva per conservare, /nuova per ripartire." ;;
        de:chat_full)       echo "Kontext fast voll: das Modell vergisst gleich den Anfang. /speichern zum Sichern, /neu für den Neustart." ;;
        *:chat_full)        echo "Context almost full: the model is about to forget the beginning. /save to keep it, /new to start over." ;;
        it:chat_cleared)    echo "Contesto azzerato: la chat riparte da zero." ;;
        de:chat_cleared)    echo "Kontext geleert: der Chat beginnt von vorn." ;;
        *:chat_cleared)     echo "Context cleared: the chat starts fresh." ;;
        it:chat_saved)      echo "Conversazione salvata in:" ;;
        de:chat_saved)      echo "Unterhaltung gespeichert in:" ;;
        *:chat_saved)       echo "Conversation saved to:" ;;
        it:chat_nosave)     echo "Niente da salvare: ancora nessuno scambio." ;;
        de:chat_nosave)     echo "Nichts zu speichern: noch kein Austausch." ;;
        *:chat_nosave)      echo "Nothing to save: no exchange yet." ;;
        it:chat_bye)        echo "Chat chiusa." ;;
        de:chat_bye)        echo "Chat beendet." ;;
        *:chat_bye)         echo "Chat closed." ;;
        it:chat_err)        echo "Errore dal modello:" ;;
        de:chat_err)        echo "Fehler vom Modell:" ;;
        *:chat_err)         echo "Error from the model:" ;;
        it:chat_model_now)  echo "Modello di questa chat:" ;;
        de:chat_model_now)  echo "Modell dieses Chats:" ;;
        *:chat_model_now)   echo "This chat's model:" ;;
        it:chat_model_only) echo "(solo per questa chat: il default non cambia)" ;;
        de:chat_model_only) echo "(nur für diesen Chat: der Standard bleibt)" ;;
        *:chat_model_only)  echo "(this chat only: the default is untouched)" ;;
        it:chat_badcmd)     echo "Comando sconosciuto: /aiuto per l'elenco." ;;
        de:chat_badcmd)     echo "Unbekannter Befehl: /hilfe für die Liste." ;;
        *:chat_badcmd)      echo "Unknown command: /help for the list." ;;
        it:chat_need_jq)    echo "La chat richiede jq:  $(pkg_install_cmd jq)" ;;
        de:chat_need_jq)    echo "Der Chat benötigt jq:  $(pkg_install_cmd jq)" ;;
        *:chat_need_jq)     echo "Chat mode requires jq:  $(pkg_install_cmd jq)" ;;
        it:chat_tty)        echo "La chat è un dialogo: serve un terminale interattivo." ;;
        de:chat_tty)        echo "Der Chat ist ein Dialog: er braucht ein interaktives Terminal." ;;
        *:chat_tty)         echo "Chat is a dialogue: it needs an interactive terminal." ;;
        it:chat_you)        echo "Tu" ;;
        de:chat_you)        echo "Du" ;;
        *:chat_you)         echo "You" ;;
        it:chat_ctx_win)    echo "finestra" ;;
        de:chat_ctx_win)    echo "Fenster" ;;
        *:chat_ctx_win)     echo "window" ;;
        it:chat_why_config) echo "da CHAT_NUM_CTX" ;;
        de:chat_why_config) echo "aus CHAT_NUM_CTX" ;;
        *:chat_why_config)  echo "from CHAT_NUM_CTX" ;;
        it:chat_why_model)  echo "il massimo del modello" ;;
        de:chat_why_model)  echo "das Maximum des Modells" ;;
        *:chat_why_model)   echo "the model's maximum" ;;
        it:chat_why_cap)    echo "tetto CHAT_CTX_CAP" ;;
        de:chat_why_cap)    echo "Obergrenze CHAT_CTX_CAP" ;;
        *:chat_why_cap)     echo "CHAT_CTX_CAP ceiling" ;;
        it:chat_why_ram)    echo "limite della RAM libera" ;;
        de:chat_why_ram)    echo "Grenze des freien RAM" ;;
        *:chat_why_ram)     echo "free RAM limit" ;;
        it:chat_why_modelmax) echo "il modello reggerebbe" ;;
        de:chat_why_modelmax) echo "das Modell könnte" ;;
        *:chat_why_modelmax)  echo "the model could take" ;;
        it:chat_why_fallback) echo "il motore non l'ha detto: ripiego" ;;
        de:chat_why_fallback) echo "die Engine sagt es nicht: Rückfall" ;;
        *:chat_why_fallback)  echo "the engine didn't say: fallback" ;;
        it:chat_ctx_base)   echo "in contesto:" ;;
        de:chat_ctx_base)   echo "im Kontext:" ;;
        *:chat_ctx_base)    echo "in context:" ;;
        it:chat_ctx_none)   echo "niente" ;;
        de:chat_ctx_none)   echo "nichts" ;;
        *:chat_ctx_none)    echo "nothing" ;;
        it:chat_ctx_measuring) echo "costo misurato dal motore (token veri, non stime):" ;;
        de:chat_ctx_measuring) echo "Kosten von der Engine gemessen (echte Token, keine Schätzung):" ;;
        *:chat_ctx_measuring)  echo "cost measured by the engine (real tokens, not estimates):" ;;
        it:chat_ctx_total)  echo "totale base:" ;;
        de:chat_ctx_total)  echo "Basis gesamt:" ;;
        *:chat_ctx_total)   echo "base total:" ;;
        it:chat_ctx_left)   echo "restano per parlare:" ;;
        de:chat_ctx_left)   echo "zum Reden bleiben:" ;;
        *:chat_ctx_left)    echo "left to talk:" ;;
        it:chat_ctx_usage)  echo "/contesto <nome> on|off   (spegnere un blocco libera la sua parte di finestra)" ;;
        de:chat_ctx_usage)  echo "/kontext <Name> on|off   (ein Block aus = sein Fensteranteil frei)" ;;
        *:chat_ctx_usage)   echo "/context <name> on|off   (turning a block off frees its share of the window)" ;;
        it:chat_blk_unknown) echo "blocco sconosciuto:" ;;
        de:chat_blk_unknown) echo "unbekannter Block:" ;;
        *:chat_blk_unknown)  echo "unknown block:" ;;
        it:chat_blk_persist) echo "(vale anche per le chat future)" ;;
        de:chat_blk_persist) echo "(gilt auch für künftige Chats)" ;;
        *:chat_blk_persist)  echo "(future chats too)" ;;
        it:chat_mem_usage)  echo "/ricorda <fatto>   ·   il fatto entra nella memoria di --remember: lo vedranno TUTTE le modalità, per sempre" ;;
        de:chat_mem_usage)  echo "/merken <Fakt>   ·   der Fakt landet im --remember-Gedächtnis: ALLE Modi sehen ihn, für immer" ;;
        *:chat_mem_usage)   echo "/remember <fact>   ·   the fact goes into --remember's memory: EVERY mode will see it, forever" ;;
        it:chat_mem_where)  echo "(memoria condivisa: --memory per vederla, /scorda <n> per toglierla)" ;;
        de:chat_mem_where)  echo "(gemeinsames Gedächtnis: --memory zeigt es, /vergiss <n> entfernt)" ;;
        *:chat_mem_where)   echo "(shared memory: --memory shows it, /forget <n> drops it)" ;;
        it:chat_mem_capped) echo "memoria piena: tolto il fatto più vecchio, il tetto è" ;;
        de:chat_mem_capped) echo "Gedächtnis voll: ältester Fakt entfernt, Obergrenze ist" ;;
        *:chat_mem_capped)  echo "memory full: oldest fact dropped, the cap is" ;;
        it:doc_chat_ctx)    echo "finestra della chat (-c)" ;;
        de:doc_chat_ctx)    echo "Chat-Fenster (-c)" ;;
        *:doc_chat_ctx)     echo "chat window (-c)" ;;
        it:bench_ctx)       echo "finestra chat che regge questa macchina:" ;;
        de:bench_ctx)       echo "Chat-Fenster, das diese Maschine trägt:" ;;
        *:bench_ctx)        echo "chat window this machine can hold:" ;;
        it:cache_hit)       echo "[dalla cache, r = richiedi all'IA]" ;;
        de:cache_hit)       echo "[aus dem Cache, r = KI erneut fragen]" ;;
        *:cache_hit)        echo "[from cache, r = ask the AI again]" ;;
        it:cache_cleared)   echo "Cache dei comandi svuotata." ;;
        de:cache_cleared)   echo "Befehls-Cache geleert." ;;
        *:cache_cleared)    echo "Command cache cleared." ;;
        it:explaining)      echo "Chiedo all'IA cosa farà questo comando..." ;;
        de:explaining)      echo "Frage die KI, was dieser Befehl tun wird..." ;;
        *:explaining)       echo "Asking the AI what this command will do..." ;;
        it:cmd_failed)      echo "Il comando è fallito" ;;
        de:cmd_failed)      echo "Der Befehl ist fehlgeschlagen" ;;
        *:cmd_failed)       echo "The command failed" ;;
        it:ask_fix)         echo "Invio = correzione | scrivi un indizio per l'IA | n = esci: " ;;
        de:ask_fix)         echo "Enter = Korrektur | schreibe einen Hinweis für die KI | n = beenden: " ;;
        *:ask_fix)          echo "Enter = fix | type a hint for the AI | n = quit: " ;;
        # ---- aliases (v2.0) ----
        it:al_empty)        echo "Nessun alias salvato ($ALIASFILE)." ;;
        de:al_empty)        echo "Keine Aliase gespeichert ($ALIASFILE)." ;;
        *:al_empty)         echo "No aliases saved ($ALIASFILE)." ;;
        it:al_saved)        echo "Alias salvato:" ;;
        de:al_saved)        echo "Alias gespeichert:" ;;
        *:al_saved)         echo "Alias saved:" ;;
        it:al_updated)      echo "Alias aggiornato:" ;;
        de:al_updated)      echo "Alias aktualisiert:" ;;
        *:al_updated)       echo "Alias updated:" ;;
        it:al_removed)      echo "Alias rimosso:" ;;
        de:al_removed)      echo "Alias entfernt:" ;;
        *:al_removed)       echo "Alias removed:" ;;
        it:al_notfound)     echo "Alias non trovato:" ;;
        de:al_notfound)     echo "Alias nicht gefunden:" ;;
        *:al_notfound)      echo "Alias not found:" ;;
        it:al_name_q)       echo "Parola per l'alias: " ;;
        de:al_name_q)       echo "Wort fuer den Alias: " ;;
        *:al_name_q)        echo "Word for the alias: " ;;
        it:al_cmd_q)        echo "Comando da salvare: " ;;
        de:al_cmd_q)        echo "Zu speichernder Befehl: " ;;
        *:al_cmd_q)         echo "Command to save: " ;;
        it:al_ai_q)         echo "Chiedere conferma all'IA a ogni uso? [$YES_KEY/N]: " ;;
        de:al_ai_q)         echo "Bei jeder Nutzung die KI fragen? [$YES_KEY/N]: " ;;
        *:al_ai_q)          echo "Ask the AI on every use? [$YES_KEY/N]: " ;;
        it:al_req_q)        echo "Richiesta da girare all'IA (Invio = usa il comando): " ;;
        de:al_req_q)        echo "Anfrage fuer die KI (Enter = Befehl verwenden): " ;;
        *:al_req_q)         echo "Request to send to the AI (Enter = use the command): " ;;
        it:al_invalid)      echo "Nome non valido: usa una sola parola, senza spazi (lettere, numeri, - o _; inizia con una lettera). Riservati: add list rm edit." ;;
        de:al_invalid)      echo "Ungueltiger Name: nur ein Wort, keine Leerzeichen (Buchstaben, Zahlen, - oder _; beginnt mit einem Buchstaben). Reserviert: add list rm edit." ;;
        *:al_invalid)       echo "Invalid name: use a single word, no spaces (letters, digits, - or _; start with a letter). Reserved: add list rm edit." ;;
        it:al_run_ask)      echo "Invio = usa l'alias | a = chiedo all'IA: " ;;
        de:al_run_ask)      echo "Enter = Alias verwenden | a = KI fragen: " ;;
        *:al_run_ask)       echo "Enter = use the alias | a = ask the AI: " ;;
        it:al_usage)        echo "Uso: $PROG -a add|list|rm|edit   ·   $PROG -a <nome>" ;;
        de:al_usage)        echo "Verwendung: $PROG -a add|list|rm|edit   ·   $PROG -a <Name>" ;;
        *:al_usage)         echo "Usage: $PROG -a add|list|rm|edit   ·   $PROG -a <name>" ;;
        it:al_c_name)       echo "NOME" ;;
        de:al_c_name)       echo "NAME" ;;
        *:al_c_name)        echo "NAME" ;;
        it:al_c_type)       echo "TIPO" ;;
        de:al_c_type)       echo "TYP" ;;
        *:al_c_type)        echo "TYPE" ;;
        it:al_c_cmd)        echo "COMANDO" ;;
        de:al_c_cmd)        echo "BEFEHL" ;;
        *:al_c_cmd)         echo "COMMAND" ;;
        it:al_rm_which)     echo "Quale numero o nome rimuovere? (Invio = annulla): " ;;
        de:al_rm_which)     echo "Welche Nummer oder welchen Namen entfernen? (Enter = abbrechen): " ;;
        *:al_rm_which)      echo "Which number or name to remove? (Enter = cancel): " ;;
        it:al_rm_confirm)   echo "Confermi la rimozione? [$YES_KEY/N]: " ;;
        de:al_rm_confirm)   echo "Entfernung bestaetigen? [$YES_KEY/N]: " ;;
        *:al_rm_confirm)    echo "Confirm removal? [$YES_KEY/N]: " ;;
        it:al_save_none)    echo "Nessun comando recente da salvare (lanciane uno prima)." ;;
        de:al_save_none)    echo "Kein aktueller Befehl zum Speichern (fuehre zuerst einen aus)." ;;
        *:al_save_none)     echo "No recent command to save (run one first)." ;;
        it:al_save_show)    echo "Ultimo comando riuscito:" ;;
        de:al_save_show)    echo "Letzter erfolgreicher Befehl:" ;;
        *:al_save_show)     echo "Last successful command:" ;;
        it:al_exists)       echo "Questo comando è già una scorciatoia:" ;;
        de:al_exists)       echo "Dieser Befehl ist bereits ein Shortcut:" ;;
        *:al_exists)        echo "This command is already a shortcut:" ;;
        it:al_propose)      echo "Comando già usato di recente:" ;;
        de:al_propose)      echo "Kuerzlich schon benutzter Befehl:" ;;
        *:al_propose)       echo "Command already used recently:" ;;
        it:al_propose_q)    echo "Ne faccio una scorciatoia? scrivi un nome (Invio = no): " ;;
        de:al_propose_q)    echo "Daraus einen Shortcut machen? Name eingeben (Enter = nein): " ;;
        *:al_propose_q)     echo "Make it a shortcut? type a name (Enter = no): " ;;
        # ---- AI model selection (v2.3) ----
        it:model_avail)     echo "IA disponibili (già scaricate):" ;;
        de:model_avail)     echo "Verfügbare KIs (bereits geladen):" ;;
        *:model_avail)      echo "Available AIs (already downloaded):" ;;
        it:model_inuse)     echo "← in uso ora" ;;
        de:model_inuse)     echo "← aktiv" ;;
        *:model_inuse)      echo "← in use" ;;
        it:model_pick)      echo "Quale vuoi usare sempre? scrivi il numero (Invio = lascia com'è): " ;;
        de:model_pick)      echo "Welche willst du immer nutzen? Nummer eingeben (Enter = so lassen): " ;;
        *:model_pick)       echo "Which one to always use? type the number (Enter = keep current): " ;;
        it:model_kept)      echo "Lasciato invariato." ;;
        de:model_kept)      echo "Unverändert gelassen." ;;
        *:model_kept)       echo "Left unchanged." ;;
        it:model_set)       echo "Modello predefinito impostato:" ;;
        de:model_set)       echo "Standardmodell gesetzt:" ;;
        *:model_set)        echo "Default model set:" ;;
        it:model_none)      echo "Nessuna IA scaricata (ollama pull <nome>) oppure Ollama non è in esecuzione." ;;
        de:model_none)      echo "Keine KI geladen (ollama pull <Name>) oder Ollama läuft nicht." ;;
        *:model_none)       echo "No AI downloaded (ollama pull <name>) or Ollama is not running." ;;
        it:model_badsel)    echo "Selezione non valida. Vedi le IA con: $PROG -m" ;;
        de:model_badsel)    echo "Ungültige Auswahl. KIs anzeigen mit: $PROG -m" ;;
        *:model_badsel)     echo "Invalid selection. See the AIs with: $PROG -m" ;;
        it:model_oneoff)    echo "Solo per questo comando uso:" ;;
        de:model_oneoff)    echo "Nur für diesen Befehl nutze ich:" ;;
        *:model_oneoff)     echo "For this command only I use:" ;;
        it:ms_unload)       echo "Spengo la vecchia IA per liberare subito la RAM:" ;;
        de:ms_unload)       echo "Ich stoppe die alte KI, um den RAM sofort freizugeben:" ;;
        *:ms_unload)        echo "Stopping the old AI to free the RAM right away:" ;;
        # ---- model management (v2.10) ----
        it:mp_usage)        echo "Uso: $PROG -m pull <nome>   (es. $PROG -m pull qwen3:8b)" ;;
        de:mp_usage)        echo "Verwendung: $PROG -m pull <Name>   (z. B. $PROG -m pull qwen3:8b)" ;;
        *:mp_usage)         echo "Usage: $PROG -m pull <name>   (e.g. $PROG -m pull qwen3:8b)" ;;
        it:mp_done)         echo "Modello scaricato:" ;;
        de:mp_done)         echo "Modell geladen:" ;;
        *:mp_done)          echo "Model downloaded:" ;;
        it:mp_fail)         echo "Download fallito:" ;;
        de:mp_fail)         echo "Download fehlgeschlagen:" ;;
        *:mp_fail)          echo "Download failed:" ;;
        it:mp_default_q)    echo "La imposto come IA predefinita? [$YES_KEY/N]: " ;;
        de:mp_default_q)    echo "Als Standard-KI setzen? [$YES_KEY/N]: " ;;
        *:mp_default_q)     echo "Set it as the default AI? [$YES_KEY/N]: " ;;
        # ---- pull already in flight (v2.18) ----
        it:mp_busy)         echo "C'è già un download di questo modello:" ;;
        de:mp_busy)         echo "Ein Download dieses Modells läuft bereits:" ;;
        *:mp_busy)          echo "A download of this model is already going on:" ;;
        it:mp_busy_sus)     echo "sospeso con Ctrl+Z" ;;
        de:mp_busy_sus)     echo "mit Ctrl+Z angehalten" ;;
        *:mp_busy_sus)      echo "suspended with Ctrl+Z" ;;
        it:mp_busy_why)     echo "Ollama serve un modello alla volta: finché quello resta lì, un secondo download si pianta su 'pulling manifest'." ;;
        de:mp_busy_why)     echo "Ollama bedient ein Modell nach dem anderen: solange der dort haengt, bleibt ein zweiter Download bei 'pulling manifest' stehen." ;;
        *:mp_busy_why)      echo "Ollama serves one model at a time: while that one sits there, a second download hangs at 'pulling manifest'." ;;
        it:mp_busy_fg)      echo "Un download sospeso riparte solo dal terminale che l'ha lanciato, con:  fg" ;;
        de:mp_busy_fg)      echo "Ein angehaltener Download laeuft nur im Terminal weiter, das ihn gestartet hat, mit:  fg" ;;
        *:mp_busy_fg)       echo "A suspended download only resumes in the terminal that started it, with:  fg" ;;
        it:mp_busy_kill)    echo "Lo termino e riparto da qui? [$YES_KEY/N]: " ;;
        de:mp_busy_kill)    echo "Soll ich ihn beenden und hier neu starten? [$YES_KEY/N]: " ;;
        *:mp_busy_kill)     echo "Shall I end it and start over from here? [$YES_KEY/N]: " ;;
        it:mp_busy_left)    echo "Lascio in pace il download esistente." ;;
        de:mp_busy_left)    echo "Ich lasse den laufenden Download in Ruhe." ;;
        *:mp_busy_left)     echo "Leaving the existing download alone." ;;
        it:mp_busy_alive)   echo "Non è morto: provaci a mano con  kill -9" ;;
        de:mp_busy_alive)   echo "Er ist nicht beendet: versuch es von Hand mit  kill -9" ;;
        *:mp_busy_alive)    echo "It did not die: try by hand with  kill -9" ;;
        it:mp_resume)       echo "Ollama tiene i pezzi già scaricati: il download riprende da dov'era, non riparte da zero." ;;
        de:mp_resume)       echo "Ollama behaelt die geladenen Teile: der Download macht dort weiter, wo er war." ;;
        *:mp_resume)        echo "Ollama keeps the parts already fetched: the download picks up where it left off." ;;
        it:mp_keys)         echo "Ctrl+C annulla · Ctrl+Z sospende (poi riprendi con: fg)" ;;
        de:mp_keys)         echo "Ctrl+C bricht ab · Ctrl+Z haelt an (weiter mit: fg)" ;;
        *:mp_keys)          echo "Ctrl+C cancels · Ctrl+Z suspends (resume with: fg)" ;;
        it:mu_doing)        echo "Aggiorno" ;;
        de:mu_doing)        echo "Aktualisiere" ;;
        *:mu_doing)         echo "Updating" ;;
        it:mu_done)         echo "Aggiornamento modelli completato." ;;
        de:mu_done)         echo "Modell-Update abgeschlossen." ;;
        *:mu_done)          echo "Model update finished." ;;
        it:mstop_doing)     echo "Scarico dalla RAM:" ;;
        de:mstop_doing)     echo "Entlade aus dem RAM:" ;;
        *:mstop_doing)      echo "Unloading from RAM:" ;;
        it:mstop_usage)     echo "Uso: $PROG -m stop <n|nome>   (vedi chi è in RAM con: $PROG -m ps)" ;;
        de:mstop_usage)     echo "Verwendung: $PROG -m stop <n|Name>   (wer im RAM ist: $PROG -m ps)" ;;
        *:mstop_usage)      echo "Usage: $PROG -m stop <n|name>   (see who is in RAM with: $PROG -m ps)" ;;
        it:mr_usage)        echo "Uso: $PROG -m rm <n|nome>   (vedi: $PROG -m list)" ;;
        de:mr_usage)        echo "Verwendung: $PROG -m rm <n|Name>   (siehe: $PROG -m list)" ;;
        *:mr_usage)         echo "Usage: $PROG -m rm <n|name>   (see: $PROG -m list)" ;;
        it:mr_confirm)      echo "Sto per rimuovere:" ;;
        de:mr_confirm)      echo "Ich entferne gleich:" ;;
        *:mr_confirm)       echo "About to remove:" ;;
        it:mr_removed)      echo "Rimosso:" ;;
        de:mr_removed)      echo "Entfernt:" ;;
        *:mr_removed)       echo "Removed:" ;;
        it:mr_wasdefault)   echo "Era la predefinita: scegline un'altra con: $PROG -m" ;;
        de:mr_wasdefault)   echo "Das war der Standard: neuen waehlen mit: $PROG -m" ;;
        *:mr_wasdefault)    echo "That was the default: pick a new one with: $PROG -m" ;;
        it:eng_current)     echo "Ollama attuale:" ;;
        de:eng_current)     echo "Aktuelles Ollama:" ;;
        *:eng_current)      echo "Current Ollama:" ;;
        it:eng_cmd)         echo "Comando di aggiornamento:" ;;
        de:eng_cmd)         echo "Update-Befehl:" ;;
        *:eng_cmd)          echo "Update command:" ;;
        it:eng_confirm)     echo "Invio = procedi | n = annulla: " ;;
        de:eng_confirm)     echo "Enter = fortfahren | n = abbrechen: " ;;
        *:eng_confirm)      echo "Enter = proceed | n = cancel: " ;;
        it:eng_restart)     echo "Riavvio il servizio per attivare la nuova versione:" ;;
        de:eng_restart)     echo "Ich starte den Dienst neu, um die neue Version zu aktivieren:" ;;
        *:eng_restart)      echo "Restarting the service to activate the new version:" ;;
        it:su_current)      echo "Versione locale:" ;;
        de:su_current)      echo "Lokale Version:" ;;
        *:su_current)       echo "Local version:" ;;
        it:su_dlfail)       echo "Download del programma fallito." ;;
        de:su_dlfail)       echo "Download des Programms fehlgeschlagen." ;;
        *:su_dlfail)        echo "Program download failed." ;;
        it:su_badfile)      echo "File scaricato non valido (controllo sintassi fallito)." ;;
        de:su_badfile)      echo "Heruntergeladene Datei ungueltig (Syntaxpruefung fehlgeschlagen)." ;;
        *:su_badfile)       echo "Downloaded file is invalid (syntax check failed)." ;;
        it:su_uptodate)     echo "Sei gia' alla versione piu' recente." ;;
        de:su_uptodate)     echo "Du hast bereits die neueste Version." ;;
        *:su_uptodate)      echo "You are already on the latest version." ;;
        it:su_new)          echo "Nuova versione disponibile:" ;;
        de:su_new)          echo "Neue Version verfuegbar:" ;;
        *:su_new)           echo "New version available:" ;;
        it:su_confirm)      echo "Invio = aggiorna | n = annulla: " ;;
        de:su_confirm)      echo "Enter = aktualisieren | n = abbrechen: " ;;
        *:su_confirm)       echo "Enter = update | n = cancel: " ;;
        it:su_denied)       echo "Aggiornamento annullato." ;;
        de:su_denied)       echo "Update abgebrochen." ;;
        *:su_denied)        echo "Update cancelled." ;;
        it:su_done)         echo "Programma aggiornato." ;;
        de:su_done)         echo "Programm aktualisiert." ;;
        *:su_done)          echo "Program updated." ;;
        it:mp_machine)      echo "Macchina:" ;;
        de:mp_machine)      echo "Rechner:" ;;
        *:mp_machine)       echo "Machine:" ;;
        it:mp_disk)         echo "disco libero:" ;;
        de:mp_disk)         echo "freier Speicher:" ;;
        *:mp_disk)          echo "free disk:" ;;
        it:mp_menu_title)   echo "IA fattibili su questa macchina (✓ = già scaricata, ★ = consigliata):" ;;
        de:mp_menu_title)   echo "Auf diesem Rechner machbare KIs (✓ = schon geladen, ★ = empfohlen):" ;;
        *:mp_menu_title)    echo "AIs feasible on this machine (✓ = already downloaded, ★ = recommended):" ;;
        it:mp_which)        echo "Quale scarico? numero o nome (Invio = annulla): " ;;
        de:mp_which)        echo "Welche laden? Nummer oder Name (Enter = abbrechen): " ;;
        *:mp_which)         echo "Which one to download? number or name (Enter = cancel): " ;;
        # ---- D4: errors where the popular fix is worse than the problem ----
        it:ke_title)        echo "Questo errore lo conosco — e la risposta più diffusa è peggio del problema:" ;;
        de:ke_title)        echo "Diesen Fehler kenne ich - und die verbreitetste Antwort ist schlimmer als das Problem:" ;;
        *:ke_title)         echo "I know this error - and the most popular answer to it is worse than the problem:" ;;
        it:ke_fix)          echo "Rimedio:" ;;
        de:ke_fix)          echo "Loesung:" ;;
        *:ke_fix)           echo "Fix:" ;;
        it:ke_trap)         echo "NON farlo:" ;;
        de:ke_trap)         echo "NICHT tun:" ;;
        *:ke_trap)          echo "Do NOT:" ;;
        it:ke_mirror_manual) echo "apri /etc/pacman.d/mirrorlist e commenta con # il mirror che dà errore" ;;
        de:ke_mirror_manual) echo "oeffne /etc/pacman.d/mirrorlist und kommentiere den fehlerhaften Mirror mit # aus" ;;
        *:ke_mirror_manual)  echo "open /etc/pacman.d/mirrorlist and comment out the failing mirror with #" ;;
        it:ke_sig404_what)  echo "Il file che manca è la FIRMA (.sig), non il pacchetto: quel mirror è disallineato o rotto. pacman si ferma perché non può verificare quello che sta per installare — sta facendo il suo lavoro, non ti sta ostacolando. Il colpevole è UN mirror, non il pacchetto e non il tuo sistema." ;;
        de:ke_sig404_what)  echo "Es fehlt die SIGNATUR (.sig), nicht das Paket: dieser Mirror ist nicht synchron oder defekt. pacman haelt an, weil es nicht pruefen kann, was es installieren wuerde - es macht seine Arbeit, es steht dir nicht im Weg. Schuld ist EIN Mirror, nicht das Paket und nicht dein System." ;;
        *:ke_sig404_what)   echo "What is missing is the SIGNATURE (.sig), not the package: that mirror is out of sync or broken. pacman stops because it cannot verify what it is about to install - it is doing its job, not obstructing you. The guilty party is ONE mirror, not the package and not your system." ;;
        it:ke_sig404_fix)   echo "$(mirror_refresh_cmd)   ·   poi ripeti l'installazione: il pacchetto arriva da un altro mirror, firma inclusa." ;;
        de:ke_sig404_fix)   echo "$(mirror_refresh_cmd)   ·   dann die Installation wiederholen: das Paket kommt von einem anderen Mirror, samt Signatur." ;;
        *:ke_sig404_fix)    echo "$(mirror_refresh_cmd)   ·   then run the install again: the package comes from another mirror, signature included." ;;
        it:ke_sig404_trap)  echo "'SigLevel = Never' in /etc/pacman.conf. È la risposta che troverai sui forum, e spegne il controllo delle FIRME su TUTTO il sistema, PER SEMPRE, per colpa di un mirror rotto oggi. È togliere la serratura di casa perché una chiave non gira." ;;
        de:ke_sig404_trap)  echo "'SigLevel = Never' in /etc/pacman.conf. Das ist die Antwort aus den Foren, und sie schaltet die SIGNATURPRUEFUNG fuer das GANZE System AUF DAUER ab - wegen eines Mirrors, der heute kaputt ist. Das ist, als baue man das Tuerschloss aus, weil ein Schluessel klemmt." ;;
        *:ke_sig404_trap)   echo "'SigLevel = Never' in /etc/pacman.conf. That is the answer the forums give, and it turns SIGNATURE checking off for your WHOLE system, FOREVER, because one mirror is broken today. It is removing your front door lock because one key sticks." ;;
        it:equiv)           echo "equivale a:" ;;
        de:equiv)           echo "entspricht:" ;;
        *:equiv)            echo "same as:" ;;
        it:dg_builtin_title) echo "Regole di serie (non si tolgono):" ;;
        de:dg_builtin_title) echo "Eingebaute Regeln (nicht entfernbar):" ;;
        *:dg_builtin_title)  echo "Built-in rules (cannot be removed):" ;;
        it:dg_user_title)   echo "Le tue regole -" ;;
        de:dg_user_title)   echo "Deine Regeln -" ;;
        *:dg_user_title)    echo "Your rules -" ;;
        it:dg_user_none)    echo "(nessuna: aggiungine con --danger add '<regex>')" ;;
        de:dg_user_none)    echo "(keine: mit --danger add '<regex>' hinzufuegen)" ;;
        *:dg_user_none)     echo "(none yet: add one with --danger add '<regex>')" ;;
        it:dg_broken)       echo "regex non valida: non protegge nulla, correggila o rimuovila" ;;
        de:dg_broken)       echo "ungueltige Regex: schuetzt nichts, korrigieren oder entfernen" ;;
        *:dg_broken)        echo "invalid regex: guards nothing, fix it or remove it" ;;
        it:dg_hint)         echo "Prova una regola senza rischiare niente:  --danger test '<comando>'" ;;
        de:dg_hint)         echo "Eine Regel gefahrlos testen:  --danger test '<Befehl>'" ;;
        *:dg_hint)          echo "Try a rule without risking anything:  --danger test '<command>'" ;;
        it:dg_usage)        echo "Uso: --danger [list] | add '<regex>' | rm <n> | test '<comando>' | help" ;;
        de:dg_usage)        echo "Verwendung: --danger [list] | add '<Regex>' | rm <n> | test '<Befehl>' | help" ;;
        *:dg_usage)         echo "Usage: --danger [list] | add '<regex>' | rm <n> | test '<command>' | help" ;;
        it:dg_add_usage)    echo "Uso: --danger add '<regex>'   (es: --danger add 'terraform .*destroy')" ;;
        de:dg_add_usage)    echo "Verwendung: --danger add '<Regex>'   (z. B.: --danger add 'terraform .*destroy')" ;;
        *:dg_add_usage)     echo "Usage: --danger add '<regex>'   (e.g.: --danger add 'terraform .*destroy')" ;;
        it:dg_bad_regex)    echo "regex non valida, non l'ho aggiunta (verrebbe controllata a ogni comando):" ;;
        de:dg_bad_regex)    echo "ungueltige Regex, nicht hinzugefuegt (sie wuerde bei jedem Befehl geprueft):" ;;
        *:dg_bad_regex)     echo "invalid regex, not added (it would be checked on every command):" ;;
        it:dg_too_broad)    echo "Attenzione: questa regola scatta anche su comandi innocui come 'ls'. Una regola che scatta sempre non protegge: insegna a confermare senza leggere." ;;
        de:dg_too_broad)    echo "Achtung: diese Regel greift auch bei harmlosen Befehlen wie 'ls'. Eine Regel, die immer greift, schuetzt nicht: sie lehrt, ungelesen zu bestaetigen." ;;
        *:dg_too_broad)     echo "Careful: this rule fires even on harmless commands like 'ls'. A rule that always fires doesn't protect: it teaches you to confirm without reading." ;;
        it:dg_too_broad_ask) echo "Aggiungerla lo stesso? $YES_KEY = sì | Invio o n = annulla: " ;;
        de:dg_too_broad_ask) echo "Trotzdem hinzufuegen? $YES_KEY = ja | Enter oder n = abbrechen: " ;;
        *:dg_too_broad_ask)  echo "Add it anyway? $YES_KEY = yes | Enter or n = cancel: " ;;
        it:dg_dup)          echo "regola già presente:" ;;
        de:dg_dup)          echo "Regel bereits vorhanden:" ;;
        *:dg_dup)           echo "rule already there:" ;;
        it:dg_added)        echo "Regola aggiunta:" ;;
        de:dg_added)        echo "Regel hinzugefuegt:" ;;
        *:dg_added)         echo "Rule added:" ;;
        it:dg_removed)      echo "Regola rimossa:" ;;
        de:dg_removed)      echo "Regel entfernt:" ;;
        *:dg_removed)       echo "Rule removed:" ;;
        it:dg_rm_usage)     echo "Uso: --danger rm <n>   (il numero lo vedi con --danger)" ;;
        de:dg_rm_usage)     echo "Verwendung: --danger rm <n>   (Nummer siehe --danger)" ;;
        *:dg_rm_usage)      echo "Usage: --danger rm <n>   (--danger shows the numbers)" ;;
        it:dg_rm_range)     echo "numero fuori intervallo:" ;;
        de:dg_rm_range)     echo "Nummer ausserhalb des Bereichs:" ;;
        *:dg_rm_range)      echo "number out of range:" ;;
        it:dg_rm_builtin)   echo "questa è una regola di serie e non si toglie:" ;;
        de:dg_rm_builtin)   echo "das ist eine eingebaute Regel und wird nicht entfernt:" ;;
        *:dg_rm_builtin)    echo "that is a built-in rule and does not come off:" ;;
        it:dg_rm_builtin_why) echo "chiede solo una conferma in più, non blocca niente: il costo è un tasto, il rischio che copre è il disco. Puoi aggiungere le tue regole, non togliere queste." ;;
        de:dg_rm_builtin_why) echo "sie verlangt nur eine zusaetzliche Bestaetigung, blockiert nichts: Kosten eine Taste, Risiko die Platte. Du kannst eigene Regeln hinzufuegen, diese nicht entfernen." ;;
        *:dg_rm_builtin_why)  echo "it only asks for one more confirmation, it blocks nothing: the cost is a keypress, the risk it covers is your disk. You can add your own rules, not remove these." ;;
        it:dg_rm_confirm)   echo "Rimuovo questa tua regola? $YES_KEY = sì | Invio o n = annulla: " ;;
        de:dg_rm_confirm)   echo "Diese deiner Regeln entfernen? $YES_KEY = ja | Enter oder n = abbrechen: " ;;
        *:dg_rm_confirm)    echo "Remove this rule of yours? $YES_KEY = yes | Enter or n = cancel: " ;;
        it:dg_test_usage)   echo "Uso: --danger test '<comando>'   (non esegue niente: dice solo se scatterebbe una regola)" ;;
        de:dg_test_usage)   echo "Verwendung: --danger test '<Befehl>'   (fuehrt nichts aus: sagt nur, ob eine Regel greifen wuerde)" ;;
        *:dg_test_usage)    echo "Usage: --danger test '<command>'   (runs nothing: only says whether a rule would fire)" ;;
        it:dg_test_reboot)  echo "-> riavvia o spegne la macchina: conferma richiesta (regola fissa, prima delle altre)" ;;
        de:dg_test_reboot)  echo "-> startet neu oder faehrt herunter: Bestaetigung noetig (feste Regel, vor allen anderen)" ;;
        *:dg_test_reboot)   echo "-> reboots or shuts down the machine: confirmation required (fixed rule, ahead of the others)" ;;
        it:dg_test_hit_builtin) echo "-> scatta una regola DI SERIE:" ;;
        de:dg_test_hit_builtin) echo "-> greift eine EINGEBAUTE Regel:" ;;
        *:dg_test_hit_builtin)  echo "-> a BUILT-IN rule fires:" ;;
        it:dg_test_hit_user)    echo "-> scatta una regola TUA:" ;;
        de:dg_test_hit_user)    echo "-> greift eine DEINER Regeln:" ;;
        *:dg_test_hit_user)     echo "-> a rule of YOURS fires:" ;;
        it:dg_test_hit_means)   echo "prima di eseguirlo vedresti l'avviso, la spiegazione dell'IA e la richiesta di conferma." ;;
        de:dg_test_hit_means)   echo "vor der Ausfuehrung saehest du die Warnung, die Erklaerung der KI und die Bestaetigungsabfrage." ;;
        *:dg_test_hit_means)    echo "before running it you'd see the warning, the AI's explanation, and the confirmation prompt." ;;
        it:dg_test_miss)    echo "-> nessuna regola scatta: conferma normale (Invio)" ;;
        de:dg_test_miss)    echo "-> keine Regel greift: normale Bestaetigung (Enter)" ;;
        *:dg_test_miss)     echo "-> no rule fires: normal confirmation (Enter)" ;;
        it:mp_manual)       echo "Puoi farlo tu con il comando:  ollama pull <nome>" ;;
        de:mp_manual)       echo "Du kannst es selbst tun, mit dem Befehl:  ollama pull <Name>" ;;
        *:mp_manual)        echo "You can do it yourself with the command:  ollama pull <name>" ;;
        it:mp_nohw)         echo "glia-hardware non trovato nel PATH: la lista guidata non è disponibile." ;;
        de:mp_nohw)         echo "glia-hardware nicht im PATH: die geführte Liste ist nicht verfügbar." ;;
        *:mp_nohw)          echo "glia-hardware not found in PATH: the guided list is not available." ;;
        it:cat_general)     echo "generale" ;;
        de:cat_general)     echo "allgemein" ;;
        *:cat_general)      echo "general" ;;
        it:cat_coding)      echo "coding" ;;
        de:cat_coding)      echo "Coding" ;;
        *:cat_coding)       echo "coding" ;;
        it:cat_light)       echo "leggero" ;;
        de:cat_light)       echo "leicht" ;;
        *:cat_light)        echo "light" ;;
        it:cat_moe)         echo "MoE: veloce su CPU" ;;
        de:cat_moe)         echo "MoE: schnell auf CPU" ;;
        *:cat_moe)          echo "MoE: fast on CPU" ;;
        it:cat_reasoning)   echo "ragionamento" ;;
        de:cat_reasoning)   echo "Reasoning" ;;
        *:cat_reasoning)    echo "reasoning" ;;
        # ---- kaboom (v2.11) ----
        it:kb_title)        echo "KABOOM — disinstallazione di $ASSIST_NAME (GLIA)" ;;
        de:kb_title)        echo "KABOOM — Deinstallation von $ASSIST_NAME (GLIA)" ;;
        *:kb_title)         echo "KABOOM — uninstalling $ASSIST_NAME (GLIA)" ;;
        it:kb_what)         echo "Cosa rimuovo?" ;;
        de:kb_what)         echo "Was soll ich entfernen?" ;;
        *:kb_what)          echo "What should I remove?" ;;
        it:kb_opt1)         echo "  1) Solo il programma — $ASSIST_NAME, config, memoria, alias, completamenti TAB. Ollama, aichat e le IA scaricate restano." ;;
        de:kb_opt1)         echo "  1) Nur das Programm — $ASSIST_NAME, Config, Gedaechtnis, Aliase, TAB-Vervollstaendigung. Ollama, aichat und die KIs bleiben." ;;
        *:kb_opt1)          echo "  1) Only the program — $ASSIST_NAME, config, memory, aliases, TAB completions. Ollama, aichat and the downloaded AIs stay." ;;
        it:kb_opt2)         echo "  2) Tutto — anche aichat, il motore Ollama e le IA scaricate." ;;
        de:kb_opt2)         echo "  2) Alles — auch aichat, die Ollama-Engine und die geladenen KIs." ;;
        *:kb_opt2)          echo "  2) Everything — also aichat, the Ollama engine and the downloaded AIs." ;;
        it:kb_opt3)         echo "  3) Annulla" ;;
        de:kb_opt3)         echo "  3) Abbrechen" ;;
        *:kb_opt3)          echo "  3) Cancel" ;;
        it:kb_choose)       echo "Scelta [1/2/3]: " ;;
        de:kb_choose)       echo "Auswahl [1/2/3]: " ;;
        *:kb_choose)        echo "Choice [1/2/3]: " ;;
        it:kb_cmds)         echo "Questi sono i comandi che eseguirò:" ;;
        de:kb_cmds)         echo "Diese Befehle werde ich ausfuehren:" ;;
        *:kb_cmds)          echo "These are the commands I will run:" ;;
        it:kb_deps)         echo "Le dipendenze condivise (curl, jq) NON vengono toccate: servono anche ad altri programmi." ;;
        de:kb_deps)         echo "Geteilte Abhaengigkeiten (curl, jq) werden NICHT angeruehrt: andere Programme brauchen sie auch." ;;
        *:kb_deps)          echo "Shared dependencies (curl, jq) are NOT touched: other programs need them too." ;;
        it:kb_confirm)      echo "Per confermare scrivi $CONFIRM_WORD (Invio = annulla): " ;;
        de:kb_confirm)      echo "Zum Bestaetigen $CONFIRM_WORD eingeben (Enter = abbrechen): " ;;
        *:kb_confirm)       echo "To confirm, type $CONFIRM_WORD (Enter = cancel): " ;;
        it:kb_run)          echo "Eseguo:" ;;
        de:kb_run)          echo "Fuehre aus:" ;;
        *:kb_run)           echo "Running:" ;;
        it:kb_path_note)    echo "Nella config della shell resta la riga PATH aggiunta dall'installer; se vuoi toglierla, aprila e cancella il blocco '# added by GLIA install-assistant'." ;;
        de:kb_path_note)    echo "In der Shell-Config bleibt die vom Installer ergaenzte PATH-Zeile; zum Entfernen den Block '# added by GLIA install-assistant' loeschen." ;;
        *:kb_path_note)     echo "Your shell config still has the PATH line the installer added; to remove it, delete the '# added by GLIA install-assistant' block." ;;
        it:kb_done)         echo "Fatto. GLIA è stato rimosso. Grazie di averlo provato — il terminale ora è tutto tuo." ;;
        de:kb_done)         echo "Fertig. GLIA wurde entfernt. Danke fuers Ausprobieren — das Terminal gehoert jetzt ganz dir." ;;
        *:kb_done)          echo "Done. GLIA has been removed. Thanks for trying it — the terminal is all yours now." ;;
        it:eng_noollama)    echo "ollama non è installato:  $(pkg_install_cmd ollama)" ;;
        de:eng_noollama)    echo "ollama ist nicht installiert:  $(pkg_install_cmd ollama)" ;;
        *:eng_noollama)     echo "ollama is not installed:  $(pkg_install_cmd ollama)" ;;
        # ---- interactive mode (v2.6, REPL since v2.7) ----
        it:int_hint)        echo "Modalità interattiva: scrivi una richiesta dopo l'altra, con qualunque simbolo. Invio vuoto = esci." ;;
        de:int_hint)        echo "Interaktiver Modus: eine Anfrage nach der anderen, mit beliebigen Zeichen. Leere Eingabe = beenden." ;;
        *:int_hint)         echo "Interactive mode: type request after request, with any characters. Empty line = quit." ;;
        # ---- doctor (v2.7) ----
        it:doc_title)       echo "Diagnostica $ASSIST_NAME (GLIA v$VERSION)" ;;
        de:doc_title)       echo "Diagnose $ASSIST_NAME (GLIA v$VERSION)" ;;
        *:doc_title)        echo "$ASSIST_NAME diagnostics (GLIA v$VERSION)" ;;
        it:doc_aichat)      echo "aichat installato" ;;
        de:doc_aichat)      echo "aichat installiert" ;;
        *:doc_aichat)       echo "aichat installed" ;;
        it:doc_jq)          echo "jq installato (serve alla modalità progetto)" ;;
        de:doc_jq)          echo "jq installiert (für den Projektmodus)" ;;
        *:doc_jq)           echo "jq installed (needed by project mode)" ;;
        it:doc_w3m)         echo "w3m installato (serve alla ricerca web -w)" ;;
        de:doc_w3m)         echo "w3m installiert (für die Websuche -w)" ;;
        *:doc_w3m)          echo "w3m installed (needed by web search -w)" ;;
        it:doc_ollama)      echo "ollama installato" ;;
        de:doc_ollama)      echo "ollama installiert" ;;
        *:doc_ollama)       echo "ollama installed" ;;
        it:doc_api)         echo "motore Ollama raggiungibile ($OLLAMA_URL)" ;;
        de:doc_api)         echo "Ollama-Engine erreichbar ($OLLAMA_URL)" ;;
        *:doc_api)          echo "Ollama engine reachable ($OLLAMA_URL)" ;;
        it:doc_model)       echo "modello non scaricato: ${MODEL#ollama:}" ;;
        de:doc_model)       echo "Modell nicht geladen: ${MODEL#ollama:}" ;;
        *:doc_model)        echo "model not downloaded: ${MODEL#ollama:}" ;;
        it:doc_sec_tools)   echo "Strumenti:" ;;
        de:doc_sec_tools)   echo "Werkzeuge:" ;;
        *:doc_sec_tools)    echo "Tools:" ;;
        it:doc_sec_engine)  echo "Motore e modello:" ;;
        de:doc_sec_engine)  echo "Engine und Modell:" ;;
        *:doc_sec_engine)   echo "Engine and model:" ;;
        it:doc_ohost)       echo "OLLAMA_HOST punta altrove:" ;;
        de:doc_ohost)       echo "OLLAMA_HOST zeigt woanders hin:" ;;
        *:doc_ohost)        echo "OLLAMA_HOST points elsewhere:" ;;
        it:doc_ohost_why)   echo "la sto ignorando: $ASSIST_NAME lavora solo col motore locale ($OLLAMA_URL), per scelta. Attenzione: in questa shell 'ollama list' ti risponde da lì, io da qui." ;;
        de:doc_ohost_why)   echo "ich ignoriere sie: $ASSIST_NAME arbeitet nur mit der lokalen Engine ($OLLAMA_URL), so gewollt. Achtung: in dieser Shell antwortet 'ollama list' von dort, ich von hier." ;;
        *:doc_ohost_why)    echo "I am ignoring it: $ASSIST_NAME only works with the local engine ($OLLAMA_URL), by design. Careful: in this shell 'ollama list' answers from there, I answer from here." ;;
        it:doc_sec_gpu)     echo "GPU e backend:" ;;
        de:doc_sec_gpu)     echo "GPU und Backend:" ;;
        *:doc_sec_gpu)      echo "GPU and backend:" ;;
        it:doc_sec_paths)   echo "Comando e cartelle:" ;;
        de:doc_sec_paths)   echo "Befehl und Ordner:" ;;
        *:doc_sec_paths)    echo "Command and folders:" ;;
        it:doc_sec_release) echo "Versione e aggiornamenti:" ;;
        de:doc_sec_release) echo "Version und Updates:" ;;
        *:doc_sec_release)  echo "Version and updates:" ;;
        it:doc_ram)         echo "RAM libera sufficiente per il modello" ;;
        de:doc_ram)         echo "genug freier RAM für das Modell" ;;
        *:doc_ram)          echo "enough free RAM for the model" ;;
        it:doc_gpu_dedicated)   echo "backend GPU corretto installato" ;;
        de:doc_gpu_dedicated)   echo "richtiges GPU-Backend installiert" ;;
        *:doc_gpu_dedicated)    echo "correct GPU backend installed" ;;
        it:doc_gpu_igpu_have)   echo "iGPU Intel rilevata, backend Vulkan presente:" ;;
        de:doc_gpu_igpu_have)   echo "Intel-iGPU erkannt, Vulkan-Backend vorhanden:" ;;
        *:doc_gpu_igpu_have)    echo "Intel iGPU detected, Vulkan backend present:" ;;
        it:doc_gpu_igpu_dropped) echo "Ollama la scarta di default (OLLAMA_IGPU_ENABLE=1 per provarla) - su un iGPU simile abbiamo misurato ~4.5x più lenta della CPU: valutala, non darla per scontata." ;;
        de:doc_gpu_igpu_dropped) echo "Ollama verwirft sie standardmäßig (OLLAMA_IGPU_ENABLE=1 zum Testen) - auf einer ähnlichen iGPU haben wir ~4,5x langsamer als CPU gemessen: abwägen, nicht voraussetzen." ;;
        *:doc_gpu_igpu_dropped)  echo "Ollama drops it by default (OLLAMA_IGPU_ENABLE=1 to try it) - on a similar iGPU we measured ~4.5x slower than CPU: worth weighing, not assuming." ;;
        it:doc_gpu_igpu_enabled) echo "OLLAMA_IGPU_ENABLE=1 è già impostata: la iGPU è in uso - ricorda, su hardware simile misurato ~4.5x più lento della CPU." ;;
        de:doc_gpu_igpu_enabled) echo "OLLAMA_IGPU_ENABLE=1 ist bereits gesetzt: die iGPU wird genutzt - zur Erinnerung, auf ähnlicher Hardware ~4,5x langsamer als CPU gemessen." ;;
        *:doc_gpu_igpu_enabled)  echo "OLLAMA_IGPU_ENABLE=1 is already set: the iGPU is in use - reminder, measured ~4.5x slower than CPU on similar hardware." ;;
        it:doc_gpu_igpu_none)   echo "iGPU Intel rilevata, nessun backend installato (non consigliato: su hardware simile più lenta della CPU, banda RAM condivisa):" ;;
        de:doc_gpu_igpu_none)   echo "Intel-iGPU erkannt, kein Backend installiert (nicht empfohlen: auf ähnlicher Hardware langsamer als CPU, geteilte RAM-Bandbreite):" ;;
        *:doc_gpu_igpu_none)    echo "Intel iGPU detected, no backend installed (not recommended: slower than CPU on similar hardware, shared RAM bandwidth):" ;;
        it:doc_gpu_none)        echo "nessuna GPU rilevata: inferenza solo CPU (normale)" ;;
        de:doc_gpu_none)        echo "keine GPU erkannt: reine CPU-Inferenz (normal)" ;;
        *:doc_gpu_none)         echo "no GPU detected: CPU-only inference (normal)" ;;
        it:doc_gpu_nohw)        echo "glia-hardware non trovato: controllo GPU saltato" ;;
        de:doc_gpu_nohw)        echo "glia-hardware nicht gefunden: GPU-Check übersprungen" ;;
        *:doc_gpu_nohw)         echo "glia-hardware not found: GPU check skipped" ;;
        it:doc_gpu_pkg_unknown) echo "verifica come il tuo pacchetto ollama gestisce CUDA/ROCm (ollama.com/download)" ;;
        de:doc_gpu_pkg_unknown) echo "prüfe, wie dein ollama-Paket CUDA/ROCm behandelt (ollama.com/download)" ;;
        *:doc_gpu_pkg_unknown)  echo "check how your distro's ollama package handles CUDA/ROCm (ollama.com/download)" ;;
        it:bench_nogpu)        echo "nessuna GPU rilevata: niente da confrontare" ;;
        de:bench_nogpu)        echo "keine GPU erkannt: nichts zu vergleichen" ;;
        *:bench_nogpu)         echo "no GPU detected: nothing to compare" ;;
        it:bench_unsupported)  echo "GPU dedicata rilevata, ma -m bench per ora copre solo iGPU Intel" ;;
        de:bench_unsupported)  echo "dedizierte GPU erkannt, aber -m bench deckt vorerst nur Intel-iGPUs ab" ;;
        *:bench_unsupported)   echo "dedicated GPU detected, but -m bench only covers Intel iGPUs for now" ;;
        it:bench_novulkan)     echo "iGPU Intel rilevata ma nessun backend Vulkan installato:" ;;
        de:bench_novulkan)     echo "Intel-iGPU erkannt, aber kein Vulkan-Backend installiert:" ;;
        *:bench_novulkan)      echo "Intel iGPU detected but no Vulkan backend installed:" ;;
        it:bench_needjq)       echo "-m bench richiede jq:" ;;
        de:bench_needjq)       echo "-m bench benötigt jq:" ;;
        *:bench_needjq)        echo "-m bench requires jq:" ;;
        it:bench_other_override) echo "in $BENCH_OVERRIDE_DIR c'è già un altro override con OLLAMA_IGPU_ENABLE: controllalo a mano, non ci scrivo sopra" ;;
        de:bench_other_override) echo "in $BENCH_OVERRIDE_DIR gibt es bereits ein anderes Override mit OLLAMA_IGPU_ENABLE: bitte manuell prüfen, ich schreibe nicht darüber" ;;
        *:bench_other_override)  echo "$BENCH_OVERRIDE_DIR already has another override setting OLLAMA_IGPU_ENABLE: check it by hand, not overwriting it" ;;
        it:bench_intro)        echo "sto per confrontare CPU e iGPU su questa macchina:" ;;
        de:bench_intro)        echo "ich vergleiche gleich CPU und iGPU auf dieser Maschine:" ;;
        *:bench_intro)         echo "about to compare CPU and iGPU on this machine:" ;;
        it:bench_equiv_measure) echo "misuro $BENCH_RUNS generazioni con lo stesso prompt su entrambe le configurazioni (API /api/generate di Ollama)" ;;
        de:bench_equiv_measure) echo "ich messe $BENCH_RUNS Generationen mit demselben Prompt in beiden Konfigurationen (Ollama-API /api/generate)" ;;
        *:bench_equiv_measure)  echo "measuring $BENCH_RUNS generations of the same prompt on both configurations (Ollama's /api/generate)" ;;
        it:bench_dryrun_note)  echo "modalità di prova (--dry-run): nessuna modifica eseguita" ;;
        de:bench_dryrun_note)  echo "Testmodus (--dry-run): keine Änderung ausgeführt" ;;
        *:bench_dryrun_note)   echo "dry-run mode: nothing was changed" ;;
        it:bench_confirm)      echo "Riavvio ollama.service due volte (serve sudo), poi ripristino tutto. $YES_KEY = procedi | Invio o n = annulla: " ;;
        de:bench_confirm)      echo "Ich starte ollama.service zweimal neu (sudo nötig), danach stelle ich alles wieder her. $YES_KEY = weiter | Enter oder n = abbrechen: " ;;
        *:bench_confirm)       echo "This restarts ollama.service twice (needs sudo), then restores everything. $YES_KEY = proceed | Enter or n = cancel: " ;;
        it:bench_nosudo)       echo "sudo non disponibile o annullato: nessuna modifica eseguita" ;;
        de:bench_nosudo)       echo "sudo nicht verfügbar oder abgebrochen: keine Änderung ausgeführt" ;;
        *:bench_nosudo)        echo "sudo unavailable or cancelled: nothing was changed" ;;
        it:bench_running_cpu)  echo "misuro la CPU (baseline, iGPU disattivata)..." ;;
        de:bench_running_cpu)  echo "messe die CPU (Baseline, iGPU deaktiviert)..." ;;
        *:bench_running_cpu)   echo "measuring CPU (baseline, iGPU off)..." ;;
        it:bench_running_gpu)  echo "misuro la iGPU (OLLAMA_IGPU_ENABLE=1)..." ;;
        de:bench_running_gpu)  echo "messe die iGPU (OLLAMA_IGPU_ENABLE=1)..." ;;
        *:bench_running_gpu)   echo "measuring the iGPU (OLLAMA_IGPU_ENABLE=1)..." ;;
        it:bench_notready)     echo "ollama non ha risposto dopo il riavvio: interrompo e ripristino" ;;
        de:bench_notready)     echo "ollama hat nach dem Neustart nicht geantwortet: breche ab und stelle wieder her" ;;
        *:bench_notready)      echo "ollama did not answer after the restart: stopping and restoring" ;;
        it:bench_measure_fail) echo "misura fallita: interrompo e ripristino" ;;
        de:bench_measure_fail) echo "Messung fehlgeschlagen: breche ab und stelle wieder her" ;;
        *:bench_measure_fail)  echo "measurement failed: stopping and restoring" ;;
        it:bench_result_cpu)   echo "CPU:  " ;;
        de:bench_result_cpu)   echo "CPU:  " ;;
        *:bench_result_cpu)    echo "CPU:  " ;;
        it:bench_result_gpu)   echo "iGPU: " ;;
        de:bench_result_gpu)   echo "iGPU: " ;;
        *:bench_result_gpu)    echo "iGPU: " ;;
        it:bench_verdict_gpu)  echo "conviene la iGPU su questa macchina" ;;
        de:bench_verdict_gpu)  echo "die iGPU lohnt sich auf dieser Maschine" ;;
        *:bench_verdict_gpu)   echo "the iGPU is worth it on this machine" ;;
        it:bench_verdict_gpu_how) echo "per tenerla attiva in modo permanente: sudo systemctl edit ollama, e sotto [Service] aggiungi Environment=OLLAMA_IGPU_ENABLE=1" ;;
        de:bench_verdict_gpu_how) echo "um sie dauerhaft zu aktivieren: sudo systemctl edit ollama, und unter [Service] Environment=OLLAMA_IGPU_ENABLE=1 hinzufügen" ;;
        *:bench_verdict_gpu_how)  echo "to keep it on permanently: sudo systemctl edit ollama, and under [Service] add Environment=OLLAMA_IGPU_ENABLE=1" ;;
        it:bench_verdict_cpu)  echo "resta su CPU: qui la iGPU non conviene" ;;
        de:bench_verdict_cpu)  echo "bleib bei CPU: die iGPU lohnt sich hier nicht" ;;
        *:bench_verdict_cpu)   echo "stay on CPU: the iGPU isn't worth it here" ;;
        it:doc_name)        echo "comando '$ASSIST_NAME' presente nel PATH" ;;
        de:doc_name)        echo "Befehl '$ASSIST_NAME' im PATH vorhanden" ;;
        *:doc_name)         echo "command '$ASSIST_NAME' found in PATH" ;;
        it:doc_shadow_ok)   echo "nessun nome dell'assistente copre un altro comando" ;;
        de:doc_shadow_ok)   echo "kein Assistentenname ueberdeckt einen anderen Befehl" ;;
        *:doc_shadow_ok)    echo "no assistant name is shadowing another command" ;;
        it:doc_shadow_bad)  echo "un nome dell'assistente COPRE un comando vero:" ;;
        de:doc_shadow_bad)  echo "ein Assistentenname UEBERDECKT einen echten Befehl:" ;;
        *:doc_shadow_bad)   echo "an assistant name is SHADOWING a real command:" ;;
        it:doc_shadow_exp)  echo "scrivendo quel comando parte GLIA al posto suo. Da v2.18.2 --rename non lo permette piu', ma questo nome e' anteriore." ;;
        de:doc_shadow_exp)  echo "dieser Befehl startet GLIA statt des echten. Seit v2.18.2 laesst --rename das nicht mehr zu, dieser Name ist aelter." ;;
        *:doc_shadow_exp)   echo "typing that command starts GLIA instead of the real one. Since v2.18.2 --rename refuses this, but this name predates it." ;;
        it:doc_dirs)        echo "cartelle di config e log scrivibili" ;;
        de:doc_dirs)        echo "Config- und Log-Ordner beschreibbar" ;;
        *:doc_dirs)         echo "config and log folders writable" ;;
        it:doc_net)         echo "connessione internet attiva" ;;
        de:doc_net)         echo "Internetverbindung aktiv" ;;
        *:doc_net)          echo "internet connection active" ;;
        it:doc_offline)     echo "offline: ricerca web (-w) e aggiornamenti non disponibili" ;;
        de:doc_offline)     echo "offline: Websuche (-w) und Updates nicht verfügbar" ;;
        *:doc_offline)      echo "offline: web search (-w) and updates are unavailable" ;;
        it:doc_update_yes)  echo "nuova versione di GLIA disponibile:" ;;
        de:doc_update_yes)  echo "neue GLIA-Version verfügbar:" ;;
        *:doc_update_yes)   echo "a new GLIA version is available:" ;;
        it:doc_update_no)   echo "GLIA è aggiornato all'ultima versione" ;;
        de:doc_update_no)   echo "GLIA ist auf dem neuesten Stand" ;;
        *:doc_update_no)    echo "GLIA is up to date" ;;
        it:doc_all_ok)      echo "Tutto a posto." ;;
        de:doc_all_ok)      echo "Alles in Ordnung." ;;
        *:doc_all_ok)       echo "All good." ;;
        it:doc_issues)      echo "problema/i: sistemali con i suggerimenti qui sopra." ;;
        de:doc_issues)      echo "Problem(e): mit den Hinweisen oben beheben." ;;
        *:doc_issues)       echo "issue(s): fix them with the hints above." ;;
        # ---- web search (v2.13) ----
        it:web_searching)   echo "Cerco sul web:" ;;
        de:web_searching)   echo "Suche im Web:" ;;
        *:web_searching)    echo "Searching the web:" ;;
        it:web_noresult)    echo "Nessun risultato dal web (controlla la rete)." ;;
        de:web_noresult)    echo "Keine Web-Ergebnisse (Netzwerk prüfen)." ;;
        *:web_noresult)     echo "No web results (check your network)." ;;
        it:web_noweb)       echo "Nessuna connessione a internet: la ricerca web (-w) ha bisogno della rete per funzionare. Controlla la connessione e riprova." ;;
        de:web_noweb)       echo "Keine Internetverbindung: Die Websuche (-w) braucht das Netz. Prüfe die Verbindung und versuche es erneut." ;;
        *:web_noweb)        echo "No internet connection: web search (-w) needs the network to work. Check your connection and try again." ;;
        it:web_nomodel)     echo "Il modello non ha risposto." ;;
        de:web_nomodel)     echo "Das Modell hat nicht geantwortet." ;;
        *:web_nomodel)      echo "The model did not answer." ;;
        it:web_now3m)       echo "serve w3m (browser testuale) per la ricerca web:" ;;
        de:web_now3m)       echo "w3m (Textbrowser) wird für die Websuche benötigt:" ;;
        *:web_now3m)        echo "w3m (text browser) is required for web search:" ;;
        it:web_extract)     echo "Estratto" ;;
        de:web_extract)     echo "Auszug" ;;
        *:web_extract)      echo "Snippet" ;;
        it:web_page)        echo "Contenuto pagina" ;;
        de:web_page)        echo "Seiteninhalt" ;;
        *:web_page)         echo "Page content" ;;
        it:web_question)    echo "DOMANDA" ;;
        de:web_question)    echo "FRAGE" ;;
        *:web_question)     echo "QUESTION" ;;
        it:web_sources_h)   echo "FONTI" ;;
        de:web_sources_h)   echo "QUELLEN" ;;
        *:web_sources_h)    echo "SOURCES" ;;
        it:web_usage)       echo "Uso: $ASSIST_NAME -w <domanda>   (-w+ legge anche le pagine)" ;;
        de:web_usage)       echo "Nutzung: $ASSIST_NAME -w <Frage>   (-w+ liest auch die Seiten)" ;;
        *:web_usage)        echo "Usage: $ASSIST_NAME -w <question>   (-w+ also reads the pages)" ;;
        it:dice_usage)      echo "Uso: $ASSIST_NAME -D <NdM[+K]> ...   (es. 1d4, 2d6, 1d100+4 · -D help)" ;;
        de:dice_usage)      echo "Nutzung: $ASSIST_NAME -D <NdM[+K]> ...   (z.B. 1d4, 2d6, 1d100+4 · -D help)" ;;
        *:dice_usage)       echo "Usage: $ASSIST_NAME -D <NdM[+K]> ...   (e.g. 1d4, 2d6, 1d100+4 · -D help)" ;;
        it:dice_bad)        echo "tiro non valido:" ;;
        de:dice_bad)        echo "ungültiger Wurf:" ;;
        *:dice_bad)         echo "invalid roll:" ;;
        it:dice_limit)      echo "limiti: da 1 a 100 dadi, facce da 1 a 10000" ;;
        de:dice_limit)      echo "Grenzen: 1 bis 100 Würfel, 1 bis 10000 Seiten" ;;
        *:dice_limit)       echo "limits: 1 to 100 dice, 1 to 10000 sides" ;;
        it:src_usage)       echo "Uso: /fonte <file> carica · /fonte off toglie · all'avvio: $ASSIST_NAME -c --fonte <file>" ;;
        de:src_usage)       echo "Nutzung: /quelle <Datei> lädt · /quelle off entfernt · beim Start: $ASSIST_NAME -c --fonte <Datei>" ;;
        *:src_usage)        echo "Usage: /source <file> loads · /source off removes · at launch: $ASSIST_NAME -c --fonte <file>" ;;
        it:src_nofile)      echo "fonte non trovata o non leggibile:" ;;
        de:src_nofile)      echo "Quelle nicht gefunden oder nicht lesbar:" ;;
        *:src_nofile)       echo "source not found or not readable:" ;;
        it:src_binary)      echo "la fonte non è testo semplice:" ;;
        de:src_binary)      echo "die Quelle ist kein einfacher Text:" ;;
        *:src_binary)       echo "the source is not plain text:" ;;
        it:src_toobig)      echo "la fonte non entra nella finestra:" ;;
        de:src_toobig)      echo "die Quelle passt nicht ins Fenster:" ;;
        *:src_toobig)       echo "the source does not fit the window:" ;;
        it:src_est)         echo "tok stimati, finestra da" ;;
        de:src_est)         echo "Tok geschätzt, Fenster von" ;;
        *:src_est)          echo "tok estimated, window of" ;;
        it:src_loaded)      echo "fonte caricata:" ;;
        de:src_loaded)      echo "Quelle geladen:" ;;
        *:src_loaded)       echo "source loaded:" ;;
        it:src_susp)        echo "scheda e memoria sospese: questa sessione risponde SOLO dal documento" ;;
        de:src_susp)        echo "Blatt und Gedächtnis pausiert: diese Sitzung antwortet NUR aus dem Dokument" ;;
        *:src_susp)         echo "sheet and memory suspended: this session answers ONLY from the document" ;;
        it:src_warn_half)   echo "attenzione: la fonte occupa oltre metà finestra, resterà poco spazio per la conversazione" ;;
        de:src_warn_half)   echo "Achtung: die Quelle belegt über die Hälfte des Fensters, wenig Platz für das Gespräch" ;;
        *:src_warn_half)    echo "warning: the source takes over half the window, little room left for conversation" ;;
        it:src_off)         echo "fonte rimossa: tornano scheda e memoria" ;;
        de:src_off)         echo "Quelle entfernt: Blatt und Gedächtnis sind zurück" ;;
        *:src_off)          echo "source removed: sheet and memory are back" ;;
        it:src_none)        echo "nessuna fonte caricata" ;;
        de:src_none)        echo "keine Quelle geladen" ;;
        *:src_none)         echo "no source loaded" ;;
        it:src_mode)        echo "fonte:" ;;
        de:src_mode)        echo "Quelle:" ;;
        *:src_mode)         echo "source:" ;;
        it:cw_usage)        echo "Uso: /web <domanda> — cerca sul web e porta i risultati nella chat (senza IA)" ;;
        de:cw_usage)        echo "Nutzung: /suche <Frage> — sucht im Web und bringt die Ergebnisse in den Chat (ohne KI)" ;;
        *:cw_usage)         echo "Usage: /web <question> — searches the web and brings the results into the chat (no AI)" ;;
        it:cw_source)       echo "sei in modalità fonte: il documento è l'unica verità. Prima /fonte off, poi /web" ;;
        de:cw_source)       echo "Quellen-Modus aktiv: das Dokument ist die einzige Wahrheit. Erst /quelle off, dann /suche" ;;
        *:cw_source)        echo "source mode is on: the document is the only truth. /source off first, then /web" ;;
        it:cw_searching)    echo "cerco sul web (senza IA: il modello non si muove, la chat resta dov'è)..." ;;
        de:cw_searching)    echo "suche im Web (ohne KI: das Modell bleibt geladen, der Chat bleibt, wo er ist)..." ;;
        *:cw_searching)     echo "searching the web (no AI: the model stays put, the chat stays where it is)..." ;;
        it:cw_nores)        echo "nessun risultato (rete? motore?) — riprova con altre parole" ;;
        de:cw_nores)        echo "keine Ergebnisse (Netz? Suchmaschine?) — anders formulieren" ;;
        *:cw_nores)         echo "no results (network? engine?) — try different words" ;;
        it:cw_added)        echo "risultati nella conversazione: il modello li userà dal tuo prossimo messaggio" ;;
        de:cw_added)        echo "Ergebnisse im Gespräch: das Modell nutzt sie ab deiner nächsten Nachricht" ;;
        *:cw_added)         echo "results are in the conversation: the model will use them from your next message" ;;
        it:cw_frame)        echo "Risultati web appena raccolti per" ;;
        de:cw_frame)        echo "Soeben gesammelte Web-Ergebnisse zu" ;;
        *:cw_frame)         echo "Web results just collected for" ;;
        it:cw_frame2)       echo "Usali quando la conversazione li tocca: cita la fonte come [n], e se non bastano dillo invece di inventare." ;;
        de:cw_frame2)       echo "Nutze sie, wenn das Gespräch sie berührt: zitiere die Quelle als [n]; reichen sie nicht, sag es, statt zu erfinden." ;;
        *:cw_frame2)        echo "Use them when the conversation touches them: cite the source as [n], and if they are not enough say so instead of inventing." ;;
        it:flag_unknown)    echo "flag sconosciuto:" ;;
        de:flag_unknown)    echo "unbekanntes Flag:" ;;
        *:flag_unknown)     echo "unknown flag:" ;;
        it:flag_dashes)     echo "i flag lunghi vogliono DUE trattini (es." ;;
        de:flag_dashes)     echo "lange Flags brauchen ZWEI Striche (z.B." ;;
        *:flag_dashes)      echo "long flags take TWO dashes (e.g." ;;
        it:flag_list)       echo "· $ASSIST_NAME -h per l'elenco" ;;
        de:flag_list)       echo "· $ASSIST_NAME -h für die Liste" ;;
        *:flag_list)        echo "· $ASSIST_NAME -h for the list" ;;
        it:web_sys)         echo "Sei un assistente esperto. Rispondi alla DOMANDA in italiano usando SOLO le FONTI qui sotto. Sii conciso, accurato e concreto. Se le fonti non bastano o si contraddicono, dillo. Chiudi SEMPRE con una riga vuota e poi 'Fonti:' elencando solo le fonti che hai citato, come [n] titolo - url." ;;
        de:web_sys)         echo "Du bist ein erfahrener Assistent. Beantworte die FRAGE auf Deutsch und nutze NUR die QUELLEN unten. Sei knapp, genau und konkret. Wenn die Quellen nicht reichen oder sich widersprechen, sage es. Schließe IMMER mit einer Leerzeile und dann 'Quellen:' und liste nur die zitierten Quellen als [n] Titel - url." ;;
        *:web_sys)          echo "You are an expert assistant. Answer the QUESTION using ONLY the SOURCES below. Be concise, accurate and concrete. If the sources are insufficient or conflicting, say so. ALWAYS end with a blank line then 'Sources:' listing only the sources you cited, as [n] title - url." ;;
        it:web_remind)      echo "Regole finali: (1) preferisci le fonti PIÙ RECENTI e autorevoli (siti ufficiali); se una fonte sembra datata o in conflitto con altre, scartala. (2) Per prezzi o dati molto volatili, precisa che sono indicativi. (3) Rispondi conciso e chiudi SEMPRE, come ultima cosa, con una riga 'Fonti:' che elenca [n] titolo - url delle fonti citate." ;;
        de:web_remind)      echo "Schlussregeln: (1) bevorzuge die AKTUELLSTEN und verlässlichsten Quellen (offizielle Seiten); veraltete oder widersprüchliche Quellen verwerfen. (2) Bei Preisen oder sehr volatilen Daten darauf hinweisen, dass sie ungefähr sind. (3) Knapp antworten und IMMER zuletzt mit einer Zeile 'Quellen:' [n] Titel - url abschließen." ;;
        *:web_remind)       echo "Final rules: (1) prefer the MOST RECENT and authoritative sources (official sites); discard outdated or conflicting ones. (2) For prices or highly volatile data, note they are approximate. (3) Answer concisely and ALWAYS finish with a 'Sources:' line listing [n] title - url of the cited sources." ;;
        it:web_today)       echo "Oggi è:" ;;
        de:web_today)       echo "Heute ist:" ;;
        *:web_today)        echo "Today is:" ;;
        it:web_cmd_expl)    echo "Interrogo il motore di ricerca con il browser testuale w3m (senza chiavi), leggo i risultati e li faccio riassumere al modello:" ;;
        de:web_cmd_expl)    echo "Ich frage die Suchmaschine mit dem Textbrowser w3m ab (ohne Schlüssel), lese die Ergebnisse und lasse sie vom Modell zusammenfassen:" ;;
        *:web_cmd_expl)     echo "I query the search engine with the w3m text browser (no keys), read the results and have the model summarize them:" ;;
        it:we_engine)       echo "motore" ;;
        de:we_engine)       echo "Suchmaschine" ;;
        *:we_engine)        echo "engine" ;;
        it:we_current)      echo "Motore di ricerca per -w:" ;;
        de:we_current)      echo "Suchmaschine für -w:" ;;
        *:we_current)       echo "Search engine for -w:" ;;
        it:we_set)          echo "Motore impostato:" ;;
        de:we_set)          echo "Suchmaschine gesetzt:" ;;
        *:we_set)           echo "Engine set:" ;;
        it:we_bad)          echo "Motore non valido. Usa: ddg | bing | searx" ;;
        de:we_bad)          echo "Ungültige Suchmaschine. Nutze: ddg | bing | searx" ;;
        *:we_bad)           echo "Invalid engine. Use: ddg | bing | searx" ;;
        it:web_searx_nourl) echo "manca l'istanza SearXNG:  $ASSIST_NAME --web-engine searx <URL>" ;;
        de:web_searx_nourl) echo "SearXNG-Instanz fehlt:  $ASSIST_NAME --web-engine searx <URL>" ;;
        *:web_searx_nourl)  echo "SearXNG instance missing:  $ASSIST_NAME --web-engine searx <URL>" ;;
        it:ws_usage)        echo "Uso: $ASSIST_NAME -ws <ricerca | URL>   (risultati diretti, senza IA)" ;;
        de:ws_usage)        echo "Verwendung: $ASSIST_NAME -ws <Suche | URL>   (direkte Treffer, ohne KI)" ;;
        *:ws_usage)         echo "Usage: $ASSIST_NAME -ws <search | URL>   (direct results, no AI)" ;;
        it:web_open)        echo "Apro la pagina:" ;;
        de:web_open)        echo "Öffne die Seite:" ;;
        *:web_open)         echo "Opening the page:" ;;
        it:web_open_hint)   echo "Per navigarla in modo interattivo:" ;;
        de:web_open_hint)   echo "Zum interaktiven Navigieren:" ;;
        *:web_open_hint)    echo "To browse it interactively:" ;;
        # ---- -T translate (v2.18) ----
        it:tr_usage)        echo "Uso: $ASSIST_NAME -T <file> [it|en|de|...]   traduce in un file NUOVO accanto (l'originale resta intatto); lingua di default: quella dell'interfaccia · IA dedicata: $ASSIST_NAME --translate-model · una tantum: $ASSIST_NAME -m <nome> -T <file>" ;;
        de:tr_usage)        echo "Verwendung: $ASSIST_NAME -T <Datei> [it|en|de|...]   übersetzt in eine NEUE Datei daneben (Original bleibt unberührt); Standardsprache: die der Oberfläche · eigene KI: $ASSIST_NAME --translate-model · einmalig: $ASSIST_NAME -m <Name> -T <Datei>" ;;
        *:tr_usage)         echo "Usage: $ASSIST_NAME -T <file> [it|en|de|...]   translates into a NEW file next to it (the original is untouched); default language: the interface one · dedicated AI: $ASSIST_NAME --translate-model · one-off: $ASSIST_NAME -m <name> -T <file>" ;;
        it:tr_doing)        echo "Traduco:" ;;
        de:tr_doing)        echo "Übersetze:" ;;
        *:tr_doing)         echo "Translating:" ;;
        it:tr_working)      echo "L'IA sta traducendo (il testo appare mentre viene scritto):" ;;
        de:tr_working)      echo "Die KI übersetzt (der Text erscheint, während er geschrieben wird):" ;;
        *:tr_working)       echo "The AI is translating (the text appears as it is written):" ;;
        it:tr_save)         echo "Invio = salva | r = rifai | scrivi un indizio | s = scarta: " ;;
        de:tr_save)         echo "Enter = speichern | r = neu | schreibe einen Hinweis | s = verwerfen: " ;;
        *:tr_save)          echo "Enter = save | r = redo | type a hint | s = discard: " ;;
        it:tr_fail)         echo "Il modello non ha risposto." ;;
        de:tr_fail)         echo "Das Modell hat nicht geantwortet." ;;
        *:tr_fail)          echo "The model did not reply." ;;
        it:tr_notafile)     echo "Non è un file leggibile:" ;;
        de:tr_notafile)     echo "Keine lesbare Datei:" ;;
        *:tr_notafile)      echo "Not a readable file:" ;;
        it:tm_using)        echo "Per questa traduzione uso:" ;;
        de:tm_using)        echo "Für diese Übersetzung nutze ich:" ;;
        *:tm_using)         echo "For this translation I use:" ;;
        # tm_current/follow/set/default/pick folded into the ro_* set (D2 tail).
        # ---- model swap (v2.14) ----
        it:ms_reload)       echo "Ricarico la tua IA di default:" ;;
        de:ms_reload)       echo "Lade deine Standard-KI wieder:" ;;
        *:ms_reload)        echo "Reloading your default AI:" ;;
        it:ms_load)         echo "Carico l'IA per questo compito:" ;;
        de:ms_load)         echo "Ich lade die KI für diese Aufgabe:" ;;
        *:ms_load)          echo "Loading the AI for this task:" ;;
        it:ms_loading)      echo "Carico in memoria" ;;
        de:ms_loading)      echo "Lade in den RAM" ;;
        *:ms_loading)       echo "Loading into RAM" ;;
        it:ms_keep)         echo "C'è RAM per entrambe: non scarico nulla." ;;
        de:ms_keep)         echo "Genug RAM für beide: nichts wird entladen." ;;
        *:ms_keep)          echo "Enough RAM for both: nothing is unloaded." ;;
        it:web_using)       echo "Per questa ricerca uso:" ;;
        de:web_using)       echo "Für diese Suche nutze ich:" ;;
        *:web_using)        echo "For this search I use:" ;;
        # ---- roles: ONE parametric set (D2 tail, v2.19.1) ----
        # These five lines used to be fifteen: wm_/pm_/tm_ said the same thing
        # three times, and had drifted apart while nobody was comparing them -
        # tm_default announced the RESULT ("translations go back to following
        # the default") while wm_/pm_ described a STATE ("always uses the
        # default model"), from the very same line of code. $2 is the role, and
        # the only thing that really differed - its name - now comes from
        # role_noun_*. The result-shaped wording won: it is printed right after
        # the pin file is removed, so it reports what just happened.
        it:role_noun_web)       echo "la ricerca web" ;;
        de:role_noun_web)       echo "die Websuche" ;;
        *:role_noun_web)        echo "web search" ;;
        it:role_noun_project)   echo "i progetti (-p, --new)" ;;
        de:role_noun_project)   echo "Projekte (-p, --new)" ;;
        *:role_noun_project)    echo "projects (-p, --new)" ;;
        it:role_noun_translate) echo "le traduzioni" ;;
        de:role_noun_translate) echo "Übersetzungen" ;;
        *:role_noun_translate)  echo "translations" ;;
        it:ro_pick)         echo "Scegli l'IA per $(t "role_noun_$2"):" ;;
        de:ro_pick)         echo "Wähle die KI für $(t "role_noun_$2"):" ;;
        *:ro_pick)          echo "Pick the AI for $(t "role_noun_$2"):" ;;
        it:ro_set)          echo "IA per $(t "role_noun_$2") impostata:" ;;
        de:ro_set)          echo "KI für $(t "role_noun_$2") gesetzt:" ;;
        *:ro_set)           echo "AI for $(t "role_noun_$2") set to:" ;;
        it:ro_current)      echo "IA fissa per $(t "role_noun_$2"):" ;;
        de:ro_current)      echo "Feste KI für $(t "role_noun_$2"):" ;;
        *:ro_current)       echo "Pinned AI for $(t "role_noun_$2"):" ;;
        it:ro_follow)       echo "L'IA per $(t "role_noun_$2") segue il default." ;;
        de:ro_follow)       echo "Die KI für $(t "role_noun_$2") folgt dem Standard." ;;
        *:ro_follow)        echo "The AI for $(t "role_noun_$2") follows the default." ;;
        it:ro_default)      echo "L'IA per $(t "role_noun_$2") torna a seguire il default." ;;
        de:ro_default)      echo "Die KI für $(t "role_noun_$2") folgt wieder dem Standard." ;;
        *:ro_default)       echo "The AI for $(t "role_noun_$2") follows the default again." ;;
        # These two never had a role in them: the generic menu called wm_* for
        # every role, which is what a leftover prefix looks like.
        it:ro_followopt)    echo "segui sempre il default" ;;
        de:ro_followopt)    echo "immer dem Standard folgen" ;;
        *:ro_followopt)     echo "always follow the default" ;;
        it:ro_choose)       echo "Scelta [numero, 0=default, Invio=lascia]: " ;;
        de:ro_choose)       echo "Auswahl [Nummer, 0=Standard, Enter=lassen]: " ;;
        *:ro_choose)        echo "Choice [number, 0=default, Enter=keep]: " ;;
        # ---- roles console (D2): -m role ----
        it:role_hdr)        echo "IA scaricate - assegna un ruolo con:  $ASSIST_NAME -m role <n> <ruolo>" ;;
        de:role_hdr)        echo "Geladene KIs - Rolle zuweisen mit:  $ASSIST_NAME -m role <n> <Rolle>" ;;
        *:role_hdr)         echo "Downloaded AIs - assign a role with:  $ASSIST_NAME -m role <n> <role>" ;;
        it:role_jobs)       echo "Lavori:" ;;
        de:role_jobs)       echo "Aufgaben:" ;;
        *:role_jobs)        echo "Jobs:" ;;
        it:role_ex)         echo "Es.:  $ASSIST_NAME -m role 2 web    ·    $ASSIST_NAME -m role 0 web = torna al default" ;;
        de:role_ex)         echo "Bsp.: $ASSIST_NAME -m role 2 web    ·    $ASSIST_NAME -m role 0 web = zurück zum Standard" ;;
        *:role_ex)          echo "e.g.: $ASSIST_NAME -m role 2 web    ·    $ASSIST_NAME -m role 0 web = back to default" ;;
        it:role_usage)      echo "Uso: $ASSIST_NAME -m role <n> <ruolo>   (0 = torna al default). Ruoli: web/w · project/p · translate/t" ;;
        de:role_usage)      echo "Verwendung: $ASSIST_NAME -m role <n> <Rolle>   (0 = Standard). Rollen: web/w · project/p · translate/t" ;;
        *:role_usage)       echo "Usage: $ASSIST_NAME -m role <n> <role>   (0 = default). Roles: web/w · project/p · translate/t" ;;
        it:role_unknown)    echo "Ruolo sconosciuto:" ;;
        de:role_unknown)    echo "Unbekannte Rolle:" ;;
        *:role_unknown)     echo "Unknown role:" ;;
        it:role_valid)      echo "Ruoli assegnabili: web/w · project/p · translate/t" ;;
        de:role_valid)      echo "Zuweisbare Rollen: web/w · project/p · translate/t" ;;
        *:role_valid)       echo "Assignable roles: web/w · project/p · translate/t" ;;
        # ---- project/coding model (v2.15; serves -p and --new since v2.18) ----
        # pm_pick/default/set/current/follow folded into the ro_* set (D2 tail).
        # pm_using stays: "for THIS project" is a different noun form from "the
        # projects", and it lives outside the generic body (like web_using and
        # tm_using). Folding it would need a SECOND noun table to save 9 lines
        # and cost 12 - generalising past the point where it pays.
        it:pm_using)        echo "Per questo progetto uso:" ;;
        de:pm_using)        echo "Für dieses Projekt nutze ich:" ;;
        *:pm_using)         echo "For this project I use:" ;;
        # ---- project mode v2: edit existing files (v2.18, Part A) ----
        it:pmv_notafile)    echo "-p modifica file che esistono già. Per creare un progetto nuovo:" ;;
        de:pmv_notafile)    echo "-p bearbeitet vorhandene Dateien. Für ein neues Projekt:" ;;
        *:pmv_notafile)     echo "-p edits files that already exist. To create a new project:" ;;
        it:pmv_notafile_hint) echo "Non esiste nessun file chiamato:" ;;
        de:pmv_notafile_hint) echo "Es gibt keine Datei mit diesem Namen:" ;;
        *:pmv_notafile_hint)  echo "There is no file named:" ;;
        it:pmv_idea)        echo "idea" ;;
        de:pmv_idea)        echo "Idee" ;;
        *:pmv_idea)         echo "idea" ;;
        it:pmv_request)     echo "cosa cambiare" ;;
        de:pmv_request)     echo "was zu ändern ist" ;;
        *:pmv_request)      echo "what to change" ;;
        it:pmv_norequest)   echo "Manca la richiesta. Uso:" ;;
        de:pmv_norequest)   echo "Anfrage fehlt. Verwendung:" ;;
        *:pmv_norequest)    echo "Missing the request. Usage:" ;;
        it:pmv_notreadable) echo "File non leggibile:" ;;
        de:pmv_notreadable) echo "Datei nicht lesbar:" ;;
        *:pmv_notreadable)  echo "File is not readable:" ;;
        it:pmv_notregular)  echo "Non è un file normale:" ;;
        de:pmv_notregular)  echo "Keine reguläre Datei:" ;;
        *:pmv_notregular)   echo "Not a regular file:" ;;
        it:pmv_binary)      echo "Sembra un file binario: -p lavora solo su file di testo." ;;
        de:pmv_binary)      echo "Sieht wie eine Binärdatei aus: -p arbeitet nur mit Textdateien." ;;
        *:pmv_binary)       echo "Looks like a binary file: -p only works on text files." ;;
        it:pmv_needgit)     echo "-p ha bisogno di git: è la tua rete di sicurezza (puoi annullare ogni modifica)." ;;
        de:pmv_needgit)     echo "-p braucht git: das ist dein Sicherheitsnetz (du kannst jede Änderung rückgängig machen)." ;;
        *:pmv_needgit)      echo "-p needs git: it is your safety net (you can undo any change)." ;;
        it:pmv_notrepo)     echo "Questa cartella non è un repository git." ;;
        de:pmv_notrepo)     echo "Dieser Ordner ist kein git-Repository." ;;
        *:pmv_notrepo)      echo "This folder is not a git repository." ;;
        it:pmv_initask)     echo "Inizializzo git qui? Invio o n = annulla | $YES_KEY = sì: " ;;
        de:pmv_initask)     echo "git hier initialisieren? Enter oder n = abbrechen | $YES_KEY = ja: " ;;
        *:pmv_initask)      echo "Initialize git here? Enter or n = cancel | $YES_KEY = yes: " ;;
        it:pmv_initdone)    echo "Repository git creato." ;;
        de:pmv_initdone)    echo "git-Repository erstellt." ;;
        *:pmv_initdone)     echo "git repository created." ;;
        it:pmv_initno)      echo "Nessun problema. Quando vuoi: git init nella cartella, poi riprova con -p." ;;
        de:pmv_initno)      echo "Kein Problem. Wann du willst: git init im Ordner, dann -p erneut." ;;
        *:pmv_initno)       echo "No problem. Whenever you want: git init in the folder, then try -p again." ;;
        it:pmv_repook)      echo "Repo OK" ;;
        de:pmv_repook)      echo "Repo OK" ;;
        *:pmv_repook)       echo "Repo OK" ;;
        it:pmv_branch)      echo "ramo" ;;
        de:pmv_branch)      echo "Zweig" ;;
        *:pmv_branch)       echo "branch" ;;
        it:pmv_clean)       echo "pulito" ;;
        de:pmv_clean)       echo "sauber" ;;
        *:pmv_clean)        echo "clean" ;;
        it:pmv_dirty)       echo "Ci sono modifiche non committate: se qualcosa va storto è più difficile tornare indietro." ;;
        de:pmv_dirty)       echo "Es gibt nicht committete Änderungen: ein Rückgängigmachen ist dann schwieriger." ;;
        *:pmv_dirty)        echo "There are uncommitted changes: undoing is harder if something goes wrong." ;;
        it:pmv_dirtyask)    echo "Continuo comunque? Invio o n = annulla | $YES_KEY = sì: " ;;
        de:pmv_dirtyask)    echo "Trotzdem fortfahren? Enter oder n = abbrechen | $YES_KEY = ja: " ;;
        *:pmv_dirtyask)     echo "Continue anyway? Enter or n = cancel | $YES_KEY = yes: " ;;
        it:pmv_toobig)      echo "File troppo grande per il contesto del modello attuale." ;;
        de:pmv_toobig)      echo "Datei zu groß für den Kontext des aktuellen Modells." ;;
        *:pmv_toobig)       echo "File too large for the current model context." ;;
        it:pmv_toobig_hint) echo "Scegli un'IA con più contesto (--project-model) oppure alza PMODE_NUM_CTX. Non taglio il file: mutilarlo produrrebbe modifiche sbagliate." ;;
        de:pmv_toobig_hint) echo "Wähle eine KI mit mehr Kontext (--project-model) oder erhöhe PMODE_NUM_CTX. Ich kürze die Datei nicht: das würde falsche Änderungen erzeugen." ;;
        *:pmv_toobig_hint)  echo "Pick an AI with more context (--project-model) or raise PMODE_NUM_CTX. I will not truncate the file: mutilating it would produce wrong edits." ;;
        it:pmv_sending)     echo "Invio" ;;
        de:pmv_sending)     echo "Sende" ;;
        *:pmv_sending)      echo "Sending" ;;
        it:pmv_lines)       echo "righe" ;;
        de:pmv_lines)       echo "Zeilen" ;;
        *:pmv_lines)        echo "lines" ;;
        it:pmv_tokens)      echo "token" ;;
        de:pmv_tokens)      echo "Token" ;;
        *:pmv_tokens)       echo "tokens" ;;
        it:pmv_thinking)    echo "L'IA sta scrivendo la modifica..." ;;
        de:pmv_thinking)    echo "Die KI schreibt die Änderung..." ;;
        *:pmv_thinking)     echo "The AI is writing the edit..." ;;
        it:pmv_noreply)     echo "L'IA non ha risposto." ;;
        de:pmv_noreply)     echo "Die KI hat nicht geantwortet." ;;
        *:pmv_noreply)      echo "The AI did not reply." ;;
        it:pmv_noblocks)    echo "Nessun blocco di modifica valido nella risposta." ;;
        de:pmv_noblocks)    echo "Keine gültigen Änderungsblöcke in der Antwort." ;;
        *:pmv_noblocks)     echo "No valid edit blocks in the reply." ;;
        it:pmv_nomatch)     echo "testo SEARCH non trovato nel file" ;;
        de:pmv_nomatch)     echo "SEARCH-Text nicht in der Datei gefunden" ;;
        *:pmv_nomatch)      echo "SEARCH text not found in the file" ;;
        it:pmv_multimatch)  echo "testo SEARCH trovato più di una volta (deve essere unico)" ;;
        de:pmv_multimatch)  echo "SEARCH-Text mehr als einmal gefunden (muss eindeutig sein)" ;;
        *:pmv_multimatch)   echo "SEARCH text found more than once (it must be unique)" ;;
        it:pmv_emptysearch) echo "SEARCH vuoto: non ammesso in questa fase" ;;
        de:pmv_emptysearch) echo "Leeres SEARCH: in dieser Phase nicht erlaubt" ;;
        *:pmv_emptysearch)  echo "Empty SEARCH: not allowed in this phase" ;;
        it:pmv_retry)       echo "Riprovo con la spiegazione dell'errore (tentativo" ;;
        de:pmv_retry)       echo "Neuer Versuch mit der Fehlererklärung (Versuch" ;;
        *:pmv_retry)        echo "Retrying with the error explained (attempt" ;;
        it:pmv_rewrite)     echo "I blocchi continuano a fallire: chiedo il file intero riscritto." ;;
        de:pmv_rewrite)     echo "Die Blöcke scheitern weiter: ich fordere die ganze Datei neu an." ;;
        *:pmv_rewrite)      echo "The blocks keep failing: asking for the whole file rewritten." ;;
        it:pmv_giveup)      echo "Non ce l'ho fatta. Il file NON è stato toccato." ;;
        de:pmv_giveup)      echo "Ich habe es nicht geschafft. Die Datei wurde NICHT verändert." ;;
        *:pmv_giveup)       echo "I could not do it. The file was NOT touched." ;;
        it:pmv_rawout)      echo "Risposta grezza dell'IA (valutala tu):" ;;
        de:pmv_rawout)      echo "Rohantwort der KI (beurteile sie selbst):" ;;
        *:pmv_rawout)       echo "Raw AI reply (judge it yourself):" ;;
        it:pmv_nodiff)      echo "I blocchi non cambiano nulla: il file è già così." ;;
        de:pmv_nodiff)      echo "Die Blöcke ändern nichts: die Datei ist bereits so." ;;
        *:pmv_nodiff)       echo "The blocks change nothing: the file is already like that." ;;
        it:pmv_proposed)    echo "Modifica proposta:" ;;
        de:pmv_proposed)    echo "Vorgeschlagene Änderung:" ;;
        *:pmv_proposed)     echo "Proposed change:" ;;
        it:pmv_applyself)   echo "Puoi applicarla tu con:" ;;
        de:pmv_applyself)   echo "Du kannst sie selbst anwenden mit:" ;;
        *:pmv_applyself)    echo "You can apply it yourself with:" ;;
        it:pmv_ask)         echo "Invio o n = annulla | $YES_KEY = applica | e = rifai la richiesta | q = esci: " ;;
        de:pmv_ask)         echo "Enter oder n = abbrechen | $YES_KEY = anwenden | e = Anfrage ändern | q = beenden: " ;;
        *:pmv_ask)          echo "Enter or n = cancel | $YES_KEY = apply | e = edit the request | q = quit: " ;;
        it:pmv_newreq)      echo "Scrivi la richiesta rifinita (vuoto = annulla):" ;;
        de:pmv_newreq)      echo "Schreibe die verfeinerte Anfrage (leer = abbrechen):" ;;
        *:pmv_newreq)       echo "Type the refined request (empty = cancel):" ;;
        it:pmv_checkfail)   echo "git apply --check ha rifiutato la patch: non applico nulla." ;;
        de:pmv_checkfail)   echo "git apply --check hat den Patch abgelehnt: ich wende nichts an." ;;
        *:pmv_checkfail)    echo "git apply --check rejected the patch: applying nothing." ;;
        it:pmv_applied)     echo "Modifica applicata a" ;;
        de:pmv_applied)     echo "Änderung angewendet auf" ;;
        *:pmv_applied)      echo "Change applied to" ;;
        it:pmv_kept)        echo "Non ho toccato nulla. La patch resta qui:" ;;
        de:pmv_kept)        echo "Ich habe nichts verändert. Der Patch bleibt hier:" ;;
        *:pmv_kept)         echo "I touched nothing. The patch stays here:" ;;
        it:pmv_logged)      echo "Registrato in" ;;
        de:pmv_logged)      echo "Protokolliert in" ;;
        *:pmv_logged)       echo "Logged in" ;;
        it:doc_pmode_log)   echo "log di -p scrivibile" ;;
        de:doc_pmode_log)   echo "-p-Log beschreibbar" ;;
        *:doc_pmode_log)    echo "-p log writable" ;;
        it:doc_git)         echo "git installato (serve a -p)" ;;
        de:doc_git)         echo "git installiert (für -p nötig)" ;;
        *:doc_git)          echo "git installed (needed by -p)" ;;
        # ---- pmode Phase 2: local commit + undo (v2.18) ----
        it:pmv_commit_ask)  echo "Salvo la modifica come commit locale? (non viene mai pushato) " ;;
        de:pmv_commit_ask)  echo "Änderung als lokalen Commit speichern? (wird nie gepusht) " ;;
        *:pmv_commit_ask)   echo "Save the change as a local commit? (never pushed) " ;;
        it:pmv_commit_done) echo "Commit locale creato:" ;;
        de:pmv_commit_done) echo "Lokaler Commit erstellt:" ;;
        *:pmv_commit_done)  echo "Local commit created:" ;;
        it:pmv_undo_none)   echo "Nessun commit di -p da annullare in questo repo." ;;
        de:pmv_undo_none)   echo "Kein -p-Commit zum Rückgängigmachen in diesem Repo." ;;
        *:pmv_undo_none)    echo "No -p commit to undo in this repo." ;;
        it:pmv_undo_found)  echo "Ultimo commit di -p:" ;;
        de:pmv_undo_found)  echo "Letzter -p-Commit:" ;;
        *:pmv_undo_found)   echo "Most recent -p commit:" ;;
        it:pmv_undo_alt)    echo "Alternativa manuale (cancella DAVVERO l'ultimo commit dalla storia locale):" ;;
        de:pmv_undo_alt)    echo "Manuelle Alternative (löscht den letzten Commit WIRKLICH aus der lokalen Historie):" ;;
        *:pmv_undo_alt)     echo "Manual alternative (REALLY deletes the last commit from local history):" ;;
        it:pmv_undo_ask)    echo "Annullo con git revert? " ;;
        de:pmv_undo_ask)    echo "Mit git revert rückgängig machen? " ;;
        *:pmv_undo_ask)     echo "Undo with git revert? " ;;
        it:pmv_undo_done)   echo "Annullato (commit di revert creato)." ;;
        de:pmv_undo_done)   echo "Rückgängig gemacht (Revert-Commit erstellt)." ;;
        *:pmv_undo_done)    echo "Undone (revert commit created)." ;;
        it:pmv_undo_nothead) echo "Non è l'ultimo commit: annullo SOLO con revert (mai reset)." ;;
        de:pmv_undo_nothead) echo "Nicht der letzte Commit: Rückgängig NUR per revert (nie reset)." ;;
        *:pmv_undo_nothead)  echo "Not the last commit: undoing ONLY via revert (never reset)." ;;
        # ---- pmode Phase 3: multi-file (v2.18) ----
        it:pmv_badfile)     echo "il blocco indica un file fuori dal contesto" ;;
        de:pmv_badfile)     echo "der Block nennt eine Datei außerhalb des Kontexts" ;;
        *:pmv_badfile)      echo "the block names a file outside the context" ;;
        it:pmv_nofilehdr)   echo "con più file ogni blocco deve avere l'intestazione 'file:'" ;;
        de:pmv_nofilehdr)   echo "bei mehreren Dateien braucht jeder Block die 'file:'-Kopfzeile" ;;
        *:pmv_nofilehdr)    echo "with multiple files every block needs the 'file:' header" ;;
        it:pmv_sametree)    echo "tutti i file devono stare nello STESSO repository git" ;;
        de:pmv_sametree)    echo "alle Dateien müssen im SELBEN Git-Repository liegen" ;;
        *:pmv_sametree)     echo "all files must live in the SAME git repository" ;;
    esac
}

show_help() {
    case "$UILANG" in
    it) cat <<EOF
$ASSIST_NAME v$VERSION - assistente IA da terminale (IA in uso: ${MODEL#ollama:})
Parola di sicurezza sempre attiva: glia (funziona con qualsiasi nome tu gli dia)

L'essenziale:
  $ASSIST_NAME --rename <nome>     dai IL TUO nome all'assistente (glia resta sempre)
  $ASSIST_NAME <richiesta>         propone un comando: Invio = esegui, n = annulla
  $ASSIST_NAME                     da solo: prompt libero (qualsiasi simbolo)
  $ASSIST_NAME --ask <domanda>     risponde a parole, senza eseguire nulla
  $ASSIST_NAME -c                  chat vera: sa di sé, il contesto resta, barra (--chat)
  $ASSIST_NAME -w <domanda>        cerca sul web e risponde con le fonti
  $ASSIST_NAME -p <file> "<cosa>"  modifica un file esistente (diff, poi chiede)
  $ASSIST_NAME -m                  scegli quale IA usare (guidato)
  $ASSIST_NAME --danger            le tue regole di pericolo: elenca, add, rm, test (--danger help)
  $ASSIST_NAME --doctor            controllo rapido: motore, modello, RAM

Aiuto per area — ogni help elenca TUTTI i suoi sotto-comandi:
  -a help        scorciatoie: -a <nome> esegue · add · save · rm · edit
  -m help        le IA: list · pull · update · rm · ps · stop · role · <n> default
  -p help        modifica file: più file insieme · -p --undo · --project-model
  --new help     progetto nuovo da zero: pianifica e scrive i file
  -w help        ricerca web: -w veloce · -w+ approfondita · -ws senza IA · --web-engine · --web-model
  -T help        traduci un file: file nuovo accanto · lingua · --translate-model
  -i help        modalità interattiva (frasi con simboli speciali)
  -c help        chat: /contesto · /ricorda · /dadi · /web (dati dalla rete) · /fonte (solo un documento)
  --memory help  memoria: --remember salva · --forget scorda · --memory elenca
  --update help  aggiorna: -U · --check · --channel · --rollback · engine

Comandi secchi (una cosa sola, nessun sotto-menù):
  --rename <nome> · --lang <it|en|de> · -T <file> [lingua] (traduci) · -D 2d6 (dadi, senza IA · -D help) · -l (log) · --clear-cache · -V
  --kaboom  disinstallazione GUIDATA: chiede cosa togliere e mostra ogni comando

Esempio:   $ASSIST_NAME trova i file più grandi in /home
Se l'IA non risponde:   systemctl start ollama   ·   glia-hardware
EOF
        ;;
    de) cat <<EOF
$ASSIST_NAME v$VERSION - KI-Terminal-Assistent (aktive KI: ${MODEL#ollama:})
Sicherheitswort, immer aktiv: glia (funktioniert bei jedem Namen, den du ihm gibst)

Das Wesentliche:
  $ASSIST_NAME --rename <Name>    gib dem Assistenten DEINEN Namen (glia bleibt immer)
  $ASSIST_NAME <Anfrage>          schlägt einen Befehl vor: Enter = ausführen, n = nein
  $ASSIST_NAME                    allein: freier Prompt (beliebige Zeichen)
  $ASSIST_NAME --ask <Frage>      antwortet in Worten, führt nichts aus
  $ASSIST_NAME -c                 echter Chat: kennt sich selbst, Kontext bleibt (--chat)
  $ASSIST_NAME -w <Frage>         sucht im Web und antwortet mit Quellen
  $ASSIST_NAME -p <Datei> "<was>" ändert eine vorhandene Datei (Diff, dann Frage)
  $ASSIST_NAME -m                 KI wählen (geführt)
  $ASSIST_NAME --danger           deine Gefahrenregeln: auflisten, add, rm, test (--danger help)
  $ASSIST_NAME --doctor           Schnellcheck: Engine, Modell, RAM

Hilfe pro Bereich — jede Hilfe listet ALLE ihre Unterbefehle:
  -a help        Shortcuts: -a <Name> ausführen · add · save · rm · edit
  -m help        die KIs: list · pull · update · rm · ps · stop · role · <n> Standard
  -p help        Dateien ändern: mehrere Dateien · -p --undo · --project-model
  --new help     neues Projekt von Null: plant und schreibt die Dateien
  -w help        Websuche: -w schnell · -w+ gründlich · -ws ohne KI · --web-engine · --web-model
  -T help        Datei übersetzen: neue Datei daneben · Sprache · --translate-model
  -i help        interaktiver Modus (Sätze mit Sonderzeichen)
  -c help        Chat: /kontext · /merken · /wuerfel · /suche (Daten aus dem Netz) · /quelle (nur ein Dokument)
  --memory help  Gedächtnis: --remember merken · --forget vergessen · --memory
  --update help  aktualisieren: -U · --check · --channel · --rollback · Engine

Einfache Befehle (eine Sache, kein Untermenü):
  --rename <Name> · --lang <it|en|de> · -T <Datei> [Sprache] (übersetzen) · -D 2d6 (Würfel, ohne KI · -D help) · -l (Log) · --clear-cache · -V
  --kaboom  GEFÜHRTE Deinstallation: fragt, was entfernt wird, zeigt jeden Befehl

Beispiel:   $ASSIST_NAME finde die größten Dateien in /home
Wenn die KI nicht antwortet:   systemctl start ollama   ·   glia-hardware
EOF
        ;;
    *) cat <<EOF
$ASSIST_NAME v$VERSION - AI terminal assistant (AI in use: ${MODEL#ollama:})
Safety word, always on: glia (works whatever name you give it)

The essentials:
  $ASSIST_NAME --rename <name>    give the assistant YOUR name (glia always stays)
  $ASSIST_NAME <request>          proposes a command: Enter = run, n = cancel
  $ASSIST_NAME                    alone: free prompt (any symbol)
  $ASSIST_NAME --ask <question>   answers in words, runs nothing
  $ASSIST_NAME -c                 real chat: knows itself, the context stays (--chat)
  $ASSIST_NAME -w <question>      searches the web, answers with sources
  $ASSIST_NAME -p <file> "<what>" edits an existing file (diff, then asks)
  $ASSIST_NAME -m                 choose which AI to use (guided)
  $ASSIST_NAME --danger           your danger rules: list, add, rm, test (--danger help)
  $ASSIST_NAME --doctor           quick check: engine, model, RAM

Help per area — each help lists ALL of its subcommands:
  -a help        shortcuts: -a <name> runs · add · save · rm · edit
  -m help        the AIs: list · pull · update · rm · ps · stop · role · <n> default
  -p help        edit files: several files at once · -p --undo · --project-model
  --new help     new project from scratch: plans and writes the files
  -w help        web search: -w fast · -w+ deep · -ws no AI · --web-engine · --web-model
  -T help        translate a file: new file next to it · language · --translate-model
  -i help        interactive mode (requests with special characters)
  -c help        chat: /context · /remember · /roll · /web (data from the net) · /source (one document only)
  --memory help  memory: --remember saves · --forget drops · --memory lists
  --update help  updating: -U · --check · --channel · --rollback · engine

Plain commands (one job, no submenu):
  --rename <name> · --lang <it|en|de> · -T <file> [lang] (translate) · -D 2d6 (dice, no AI · -D help) · -l (log) · --clear-cache · -V
  --kaboom  GUIDED uninstall: asks what to remove and shows every command

Example:   $ASSIST_NAME find the largest files in /home
If the AI does not answer:   systemctl start ollama   ·   glia-hardware
EOF
        ;;
    esac
}

# Show the help through a pager when writing to a terminal, so long help
# stays readable on a bare server console (the first lines don't scroll
# off the top). Piped/redirected output stays plain, for scripts.
page() {
    # run "$@" and page its output when writing to a terminal, so long text
    # stays readable on a bare server console; plain when piped, for scripts.
    if [ -t 1 ]; then
        if [ -n "${PAGER:-}" ] && command -v "${PAGER%% *}" >/dev/null 2>&1; then
            "$@" | $PAGER; return
        elif command -v less >/dev/null 2>&1; then
            "$@" | less -FRX; return
        fi
    fi
    "$@"
}
show_help_paged() { page show_help; }

