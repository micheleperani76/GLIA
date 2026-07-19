# ================= end -m bench (D6b) =================

model_help() {
    case "$UILANG" in
    it) cat <<EOF
IA / modelli - $ASSIST_NAME -m

Le IA le scarica e le tiene Ollama; l'assistente ne usa UNA alla volta.

Comandi:
  $ASSIST_NAME -m                  elenca le IA scaricate (numerate) e scegli la predefinita (guidato)
  $ASSIST_NAME -m list|ls          come sopra
  $ASSIST_NAME -m <n|nome>         imposta la predefinita (per numero o nome)
  $ASSIST_NAME -m <n|nome> <task>  usa quella IA solo per quel comando (predefinita invariata)
  $ASSIST_NAME -m role             IA scaricate numerate + chi fa ogni lavoro (default/web/project/translate)
  $ASSIST_NAME -m role <n> <ruolo>   assegna l'IA n. <n> a un lavoro (0 = torna al default; ruolo: web/w, project/p, translate/t)
  $ASSIST_NAME -m pull             (da solo) check hardware + lista di IA fattibili, scegli e scarica
  $ASSIST_NAME -m pull <nome>      scarica una nuova IA (es. qwen3:8b), con controllo RAM
  $ASSIST_NAME -m update [n|nome]  aggiorna le IA scaricate (tutte, o solo quella indicata)
  $ASSIST_NAME -m rm <n|nome>      rimuove una IA (chiede conferma)
  $ASSIST_NAME -m bench            CPU vs iGPU Intel misurate qui (serve sudo, riavvia ollama 2 volte, poi ripristina) - solo iGPU Intel per ora
  $ASSIST_NAME -m bench --dry-run  come sopra ma mostra solo cosa farebbe, senza toccare nulla
  $ASSIST_NAME --update-engine     aggiorna il motore Ollama stesso
  $ASSIST_NAME -m help             questo aiuto

Stessi nomi di Ollama (list, pull, rm): quello che impari qui vale anche là.

RAM (i modelli si caricano al primo uso e si scaricano da soli dopo ~5 min):
  $ASSIST_NAME -m ps               chi è caricato in RAM ora, e per quanto ancora
  $ASSIST_NAME -m stop <n|nome>    scaricane uno SUBITO, senza aspettare
  · sono gli stessi comandi di Ollama:  ollama ps  ·  ollama stop <nome>
  · al cambio di predefinita, $ASSIST_NAME spegne da sola la vecchia IA

Esempi:
  $ASSIST_NAME -m pull qwen3:8b
  $ASSIST_NAME -m 2 riscrivi questo script in modo più chiaro

Note:
  · la predefinita è salvata in ~/.config/glia/model (cancella il file per tornare al default)
  · glia-hardware consiglia il modello adatto alla tua macchina
EOF
        ;;
    de) cat <<EOF
KI / Modelle - $ASSIST_NAME -m

Die KIs lädt und verwaltet Ollama; der Assistent nutzt EINE davon.

Befehle:
  $ASSIST_NAME -m                    geladene KIs auflisten (nummeriert) und Standard wählen (geführt)
  $ASSIST_NAME -m list|ls            wie oben
  $ASSIST_NAME -m <n|Name>           Standard setzen (per Nummer oder Name)
  $ASSIST_NAME -m <n|Name> <Aufgabe> diese KI nur für diesen Befehl nutzen (Standard bleibt)
  $ASSIST_NAME -m role             nummerierte KIs + wer welche Aufgabe macht (default/web/project/translate)
  $ASSIST_NAME -m role <n> <Rolle>   KI Nr. <n> einer Aufgabe zuweisen (0 = zurück zum Standard; Rolle: web/w, project/p, translate/t)
  $ASSIST_NAME -m pull               (allein) Hardware-Check + Liste machbarer KIs, wählen und laden
  $ASSIST_NAME -m pull <Name>        eine neue KI laden (z. B. qwen3:8b), mit RAM-Check
  $ASSIST_NAME -m update [n|Name]    geladene KIs aktualisieren (alle, oder nur die eine)
  $ASSIST_NAME -m rm <n|Name>        eine KI entfernen (fragt nach Bestätigung)
  $ASSIST_NAME -m bench              CPU vs Intel-iGPU, hier gemessen (braucht sudo, startet ollama 2x neu, stellt danach wieder her) - vorerst nur Intel-iGPU
  $ASSIST_NAME -m bench --dry-run    wie oben, zeigt nur was passieren würde, ohne etwas zu ändern
  $ASSIST_NAME --update-engine       die Ollama-Engine selbst aktualisieren
  $ASSIST_NAME -m help               diese Hilfe

Gleiche Namen wie Ollama (list, pull, rm): was du hier lernst, gilt auch dort.

RAM (Modelle laden beim ersten Gebrauch, entladen sich nach ~5 Min. selbst):
  $ASSIST_NAME -m ps               wer gerade im RAM ist, und wie lange noch
  $ASSIST_NAME -m stop <n|Name>    eines SOFORT entladen, ohne zu warten
  · dieselben Befehle wie bei Ollama:  ollama ps  ·  ollama stop <Name>
  · beim Wechsel des Standards stoppt $ASSIST_NAME die alte KI selbst

Beispiele:
  $ASSIST_NAME -m pull qwen3:8b
  $ASSIST_NAME -m 2 schreibe dieses Skript klarer

Hinweise:
  · der Standard liegt in ~/.config/glia/model (Datei löschen = zurück zum Default)
  · glia-hardware empfiehlt das passende Modell für deinen Rechner
EOF
        ;;
    *) cat <<EOF
AI / models - $ASSIST_NAME -m

Ollama downloads and stores the AIs; the assistant uses ONE at a time.

Commands:
  $ASSIST_NAME -m                  list downloaded AIs (numbered) and pick the default (guided)
  $ASSIST_NAME -m list|ls          same as above
  $ASSIST_NAME -m <n|name>         set the default (by number or name)
  $ASSIST_NAME -m <n|name> <task>  use that AI for this command only (default unchanged)
  $ASSIST_NAME -m role             numbered downloaded AIs + who does each job (default/web/project/translate)
  $ASSIST_NAME -m role <n> <role>    pin AI #<n> to a job (0 = back to default; role: web/w, project/p, translate/t)
  $ASSIST_NAME -m pull             (alone) hardware check + list of feasible AIs, pick and download
  $ASSIST_NAME -m pull <name>      download a new AI (e.g. qwen3:8b), with a RAM check
  $ASSIST_NAME -m update [n|name]  refresh the downloaded AIs (all, or just that one)
  $ASSIST_NAME -m rm <n|name>      remove an AI (asks for confirmation)
  $ASSIST_NAME -m bench            CPU vs Intel iGPU, measured here (needs sudo, restarts ollama twice, then restores) - Intel iGPU only for now
  $ASSIST_NAME -m bench --dry-run  same, but only shows what it would do, nothing is changed
  $ASSIST_NAME --update-engine     update the Ollama engine itself
  $ASSIST_NAME -m help             this help

Same names as Ollama (list, pull, rm): what you learn here works there too.

RAM (models load on first use and unload by themselves after ~5 min):
  $ASSIST_NAME -m ps               who is loaded in RAM now, and for how much longer
  $ASSIST_NAME -m stop <n|name>    unload one RIGHT NOW, without waiting
  · the very same Ollama commands:  ollama ps  ·  ollama stop <name>
  · when you switch the default, $ASSIST_NAME stops the old AI by itself

Examples:
  $ASSIST_NAME -m pull qwen3:8b
  $ASSIST_NAME -m 2 rewrite this script more clearly

Notes:
  · the default is stored in ~/.config/glia/model (delete the file to return to the built-in default)
  · glia-hardware recommends the model that fits your machine
EOF
        ;;
    esac
}

update_help() {
    case "$UILANG" in
    it) cat <<EOF
Caricamento e aggiornamento IA - $ASSIST_NAME --update / -m pull

Il motore (Ollama) fa girare le IA; i modelli SONO le IA.
Due cose diverse, due aggiornamenti diversi.

Programma (GLIA):
  $ASSIST_NAME --update             aggiorna GLIA stesso: ultimo tag del canale scelto   [-U]
  $ASSIST_NAME --update --check     controlla soltanto, non installa niente
  $ASSIST_NAME --channel            mostra il canale in uso
  $ASSIST_NAME --channel beta       anteprime (-beta/-rc) oltre alle definitive
  $ASSIST_NAME --channel stable     solo versioni definitive (predefinito)
  $ASSIST_NAME --rollback           torna a una versione precedente (backup automatici)

  · prima di ogni aggiornamento la versione in uso viene salvata in
    ~/.local/share/glia/versions (ultime 3), quindi si puo' sempre tornare indietro
  · la nuova versione viene verificata PRIMA di sostituire quella che funziona
  · a mano:  git clone https://github.com/micheleperani76/GLIA && ./GLIA/scripts/install-assistant.sh

Motore (Ollama):
  $ASSIST_NAME --update-engine      aggiorna Ollama (usa il package manager di QUESTA macchina)

Modelli:
  $ASSIST_NAME -m pull             (da solo) check hardware + lista di IA fattibili, scegli e scarica
  $ASSIST_NAME -m pull <nome>      scarica una IA per nome (es. qwen3:8b)
  $ASSIST_NAME -m update           ri-scarica tutte le IA: prende solo le versioni nuove
  $ASSIST_NAME -m update <n|nome>  aggiorna solo quella
  $ASSIST_NAME -m rm <n|nome>      rimuove una IA (chiede conferma)

Puoi farlo tu, dal terminale:
  ollama list                                      elenca i modelli
  ollama pull <nome>                               scarica o aggiorna un modello
  ollama rm <nome>                                 rimuove un modello
  ollama ps                                        chi è caricato in RAM ora
  ollama stop <nome>                               scarica subito una IA dalla RAM
  sudo pacman -Syu ollama                          aggiorna il motore (Arch/CachyOS)
  curl -fsSL https://ollama.com/install.sh | sh    aggiorna il motore (altre distro)

Esempi:
  $ASSIST_NAME --update-engine && $ASSIST_NAME -m pull   prima il motore, poi una IA nuova
  $ASSIST_NAME -m pull qwen3:30b-a3b

Note:
  · la lista delle IA fattibili viene da: glia-hardware -l (catalogo + hardware di questa macchina)
  · aggiornare un modello = rifare il pull: ollama scarica solo se esiste una versione nuova
EOF
        ;;
    de) cat <<EOF
KIs laden und aktualisieren - $ASSIST_NAME --update / -m pull

Die Engine (Ollama) laesst die KIs laufen; die Modelle SIND die KIs.
Zwei verschiedene Dinge, zwei verschiedene Updates.

Programm (GLIA):
  $ASSIST_NAME --update             GLIA selbst aktualisieren: neuester Tag im Kanal   [-U]
  $ASSIST_NAME --update --check     nur pruefen, nichts installieren
  $ASSIST_NAME --channel            aktuellen Kanal anzeigen
  $ASSIST_NAME --channel beta       Vorabversionen (-beta/-rc) zusaetzlich zu finalen
  $ASSIST_NAME --channel stable     nur finale Versionen (Standard)
  $ASSIST_NAME --rollback           zu einer frueheren Version zurueck (automatische Backups)

  · vor jedem Update wird die laufende Version in ~/.local/share/glia/versions
    gesichert (die letzten 3), man kann also immer zurueck
  · die neue Version wird geprueft, BEVOR die funktionierende ersetzt wird
  · manuell: git clone https://github.com/micheleperani76/GLIA && ./GLIA/scripts/install-assistant.sh

Engine (Ollama):
  $ASSIST_NAME --update-engine      Ollama aktualisieren (nutzt den Paketmanager DIESES Rechners)

Modelle:
  $ASSIST_NAME -m pull             (allein) Hardware-Check + Liste machbarer KIs, waehlen und laden
  $ASSIST_NAME -m pull <Name>      eine KI per Name laden (z. B. qwen3:8b)
  $ASSIST_NAME -m update           alle KIs neu laden: holt nur neue Versionen
  $ASSIST_NAME -m update <n|Name>  nur diese aktualisieren
  $ASSIST_NAME -m rm <n|Name>      eine KI entfernen (fragt nach Bestaetigung)

Du kannst es selbst tun, im Terminal:
  ollama list                                      Modelle auflisten
  ollama pull <Name>                               ein Modell laden oder aktualisieren
  ollama rm <Name>                                 ein Modell entfernen
  ollama ps                                        wer gerade im RAM ist
  ollama stop <Name>                               eine KI sofort aus dem RAM entladen
  sudo pacman -Syu ollama                          Engine aktualisieren (Arch/CachyOS)
  curl -fsSL https://ollama.com/install.sh | sh    Engine aktualisieren (andere Distros)

Beispiele:
  $ASSIST_NAME --update-engine && $ASSIST_NAME -m pull   erst die Engine, dann eine neue KI
  $ASSIST_NAME -m pull qwen3:30b-a3b

Hinweise:
  · die Liste der machbaren KIs kommt von: glia-hardware -l (Katalog + Hardware dieses Rechners)
  · ein Modell aktualisieren = pull wiederholen: ollama laedt nur, wenn es eine neue Version gibt
EOF
        ;;
    *) cat <<EOF
Downloading and updating AIs - $ASSIST_NAME --update / -m pull

The engine (Ollama) runs the AIs; the models ARE the AIs.
Two different things, two different updates.

Program (GLIA):
  $ASSIST_NAME --update             update GLIA itself: latest tag on the chosen channel   [-U]
  $ASSIST_NAME --update --check     check only, install nothing
  $ASSIST_NAME --channel            show the channel in use
  $ASSIST_NAME --channel beta       previews (-beta/-rc) on top of the final ones
  $ASSIST_NAME --channel stable     final versions only (default)
  $ASSIST_NAME --rollback           go back to a previous version (automatic backups)

  · before every update the running version is saved in
    ~/.local/share/glia/versions (last 3 kept), so you can always go back
  · the new version is validated BEFORE it replaces the one that works
  · by hand: git clone https://github.com/micheleperani76/GLIA && ./GLIA/scripts/install-assistant.sh

Engine (Ollama):
  $ASSIST_NAME --update-engine      update Ollama (uses THIS machine's package manager)

Models:
  $ASSIST_NAME -m pull             (alone) hardware check + list of feasible AIs, pick and download
  $ASSIST_NAME -m pull <name>      download an AI by name (e.g. qwen3:8b)
  $ASSIST_NAME -m update           re-pull every AI: fetches only new versions
  $ASSIST_NAME -m update <n|name>  update just that one
  $ASSIST_NAME -m rm <n|name>      remove an AI (asks for confirmation)

You can do it yourself, at the terminal:
  ollama list                                      list the models
  ollama pull <name>                               download or update a model
  ollama rm <name>                                 remove a model
  ollama ps                                        who is loaded in RAM right now
  ollama stop <name>                               unload an AI from RAM right away
  sudo pacman -Syu ollama                          update the engine (Arch/CachyOS)
  curl -fsSL https://ollama.com/install.sh | sh    update the engine (other distros)

Examples:
  $ASSIST_NAME --update-engine && $ASSIST_NAME -m pull   engine first, then a new AI
  $ASSIST_NAME -m pull qwen3:30b-a3b

Notes:
  · the feasible-AI list comes from: glia-hardware -l (catalog + this machine's hardware)
  · updating a model = pulling again: ollama only downloads if a newer version exists
EOF
        ;;
    esac
}

danger_help() {
    case "$UILANG" in
    it) cat <<EOF
Regole di pericolo - $ASSIST_NAME --danger

Prima di eseguire un comando distruttivo, $ASSIST_NAME avvisa, fa spiegare
all'IA cosa sta per succedere, e chiede conferma. A decidere QUALI comandi
sono "distruttivi" è una lista di regole (espressioni regolari).

Le regole di serie sono le nostre, e restano: coprono i classici (rm -rf, dd,
mkfs, shred, fork bomb, curl|sh...). Ma i pericoli veri sono anche i tuoi: uno
script di deploy, terraform destroy, un kubectl delete in produzione. Quelli
li aggiungi tu — si sommano alle nostre, non le sostituiscono.

Comandi:
  $ASSIST_NAME --danger                 elenca tutte le regole numerate (di serie + tue)
  $ASSIST_NAME --danger add '<regex>'   aggiungi una tua regola
  $ASSIST_NAME --danger rm <n>          togli una regola TUA (di serie: rifiutato)
  $ASSIST_NAME --danger test '<cmd>'    scatterebbe? quale regola? (non esegue NIENTE)
  $ASSIST_NAME --danger help            questo aiuto

Esempi:
  $ASSIST_NAME --danger add 'terraform .*destroy'
  $ASSIST_NAME --danger add 'kubectl .*delete.*(prod|production)'
  $ASSIST_NAME --danger test 'terraform destroy -auto-approve'

Note:
  · una regola NON blocca: chiede una conferma in più, e prima l'IA spiega cosa fa
  · la spiegazione funziona anche sulle tue regole: spiega il COMANDO, non la regola
  · le regole di serie non si tolgono (come i nomi riservati di --rename):
    il costo è un tasto, il rischio che coprono è il disco
  · una regex non valida viene rifiutata: verrebbe controllata a ogni comando
  · sintassi: espressioni regolari estese (ERE), come grep -E, senza distinzione
    tra maiuscole e minuscole
  · file: $DANGERFILE (testo semplice, una regex per riga, # = commento)
EOF
        ;;
    de) cat <<EOF
Gefahrenregeln - $ASSIST_NAME --danger

Vor einem zerstoererischen Befehl warnt $ASSIST_NAME, laesst die KI erklaeren,
was gleich passiert, und fragt nach. WELCHE Befehle "zerstoererisch" sind,
entscheidet eine Liste von Regeln (regulaere Ausdruecke).

Die eingebauten Regeln sind unsere und bleiben: sie decken die Klassiker ab
(rm -rf, dd, mkfs, shred, Fork-Bomb, curl|sh...). Die echten Gefahren sind
aber auch deine: ein Deploy-Skript, terraform destroy, ein kubectl delete in
der Produktion. Die fuegst du hinzu - sie kommen DAZU, nicht an ihre Stelle.

Befehle:
  $ASSIST_NAME --danger                 alle Regeln nummeriert auflisten (eingebaut + deine)
  $ASSIST_NAME --danger add '<Regex>'   eigene Regel hinzufuegen
  $ASSIST_NAME --danger rm <n>          eine DEINER Regeln entfernen (eingebaute: abgelehnt)
  $ASSIST_NAME --danger test '<cmd>'    wuerde sie greifen? welche? (fuehrt NICHTS aus)
  $ASSIST_NAME --danger help            diese Hilfe

Beispiele:
  $ASSIST_NAME --danger add 'terraform .*destroy'
  $ASSIST_NAME --danger add 'kubectl .*delete.*(prod|production)'
  $ASSIST_NAME --danger test 'terraform destroy -auto-approve'

Hinweise:
  · eine Regel blockiert NICHT: sie verlangt eine Bestaetigung mehr, davor erklaert die KI
  · die Erklaerung gilt auch fuer deine Regeln: sie erklaert den BEFEHL, nicht die Regel
  · eingebaute Regeln werden nicht entfernt (wie die reservierten Namen bei --rename):
    Kosten eine Taste, Risiko die Platte
  · eine ungueltige Regex wird abgelehnt: sie wuerde bei jedem Befehl geprueft
  · Syntax: erweiterte regulaere Ausdruecke (ERE), wie grep -E, ohne Gross-/Kleinschreibung
  · Datei: $DANGERFILE (Klartext, eine Regex pro Zeile, # = Kommentar)
EOF
        ;;
    *) cat <<EOF
Danger rules - $ASSIST_NAME --danger

Before running a destructive command, $ASSIST_NAME warns you, has the AI
explain in one sentence what is about to happen, and asks you to confirm.
WHICH commands count as "destructive" is decided by a list of rules (regular
expressions).

The built-in rules are ours, and they stay: they cover the classics (rm -rf,
dd, mkfs, shred, fork bombs, curl|sh...). But the real dangers are also yours:
a deploy script, terraform destroy, a kubectl delete against production. Those
you add yourself - and they are ADDED to ours, never instead of them.

Commands:
  $ASSIST_NAME --danger                 list every rule, numbered (built-in + yours)
  $ASSIST_NAME --danger add '<regex>'   add a rule of your own
  $ASSIST_NAME --danger rm <n>          remove one of YOUR rules (built-in: refused)
  $ASSIST_NAME --danger test '<cmd>'    would it fire? which rule? (runs NOTHING)
  $ASSIST_NAME --danger help            this help

Examples:
  $ASSIST_NAME --danger add 'terraform .*destroy'
  $ASSIST_NAME --danger add 'kubectl .*delete.*(prod|production)'
  $ASSIST_NAME --danger test 'terraform destroy -auto-approve'

Notes:
  · a rule does NOT block: it asks for one more confirmation, with the AI's
    explanation first
  · the explanation works for your rules too: it explains the COMMAND, not the rule
  · built-in rules do not come off (like --rename's reserved names): the cost
    is a keypress, the risk they cover is your disk
  · an invalid regex is refused: it would be checked on every single command
  · syntax: extended regular expressions (ERE), like grep -E, case-insensitive
  · file: $DANGERFILE (plain text, one regex per line, # = comment)
EOF
        ;;
    esac
}

memory_help() {
    case "$UILANG" in
    it) cat <<EOF
Memoria (fatti ricordati) - $ASSIST_NAME --memory

L'assistente può ricordare fatti brevi (macchine, percorsi, abitudini) e li
aggiunge al contesto di ogni richiesta, così l'IA li tiene a mente.

Comandi:
  $ASSIST_NAME --remember "<fatto>"   ricorda un fatto
  $ASSIST_NAME --memory               elenca i fatti (numerati)
  $ASSIST_NAME --forget <n>           dimentica il fatto n
  $ASSIST_NAME --memory help          questo aiuto

Esempio:
  $ASSIST_NAME --remember "bt3pro si raggiunge come bt3pro.local (mDNS)"

Note:
  · massimo $MEMMAX fatti (i più vecchi vengono scartati)
  · i fatti sono usati SOLO quando la richiesta li riguarda
  · file: $MEMFILE
EOF
        ;;
    de) cat <<EOF
Gedächtnis (gemerkte Fakten) - $ASSIST_NAME --memory

Der Assistent kann kurze Fakten merken (Rechner, Pfade, Gewohnheiten) und fügt
sie dem Kontext jeder Anfrage hinzu, damit die KI sie berücksichtigt.

Befehle:
  $ASSIST_NAME --remember "<Fakt>"   einen Fakt merken
  $ASSIST_NAME --memory              Fakten auflisten (nummeriert)
  $ASSIST_NAME --forget <n>          Fakt n vergessen
  $ASSIST_NAME --memory help         diese Hilfe

Beispiel:
  $ASSIST_NAME --remember "bt3pro erreichbar als bt3pro.local (mDNS)"

Hinweise:
  · höchstens $MEMMAX Fakten (die ältesten fallen weg)
  · Fakten werden NUR genutzt, wenn die Anfrage sie betrifft
  · Datei: $MEMFILE
EOF
        ;;
    *) cat <<EOF
Memory (remembered facts) - $ASSIST_NAME --memory

The assistant can remember short facts (machines, paths, habits) and adds them
to the context of every request, so the AI keeps them in mind.

Commands:
  $ASSIST_NAME --remember "<fact>"   remember a fact
  $ASSIST_NAME --memory              list facts (numbered)
  $ASSIST_NAME --forget <n>          forget fact n
  $ASSIST_NAME --memory help         this help

Example:
  $ASSIST_NAME --remember "bt3pro is reachable as bt3pro.local (mDNS)"

Notes:
  · at most $MEMMAX facts (the oldest are dropped)
  · facts are used ONLY when the request refers to them
  · file: $MEMFILE
EOF
        ;;
    esac
}

project_help() {
    case "$UILANG" in
    it) cat <<EOF
Progetto nuovo - $ASSIST_NAME --new   (fino alla v2.17 si chiamava -p)

Pianifica un piccolo progetto e ne scrive i file, con la tua conferma a ogni passo.
Crea sempre una cartella NUOVA. Per modificare file che esistono già: $ASSIST_NAME -p help

Comandi:
  $ASSIST_NAME --new <idea>   pianifica i passi e scrivi i file (conferma per ognuno)  [-n]
  $ASSIST_NAME --project-model [nome]   fissa l'IA usata da --new e da -p (da solo: menù
                            guidato; "default"/-d = torna a seguire il modello di default)
  $ASSIST_NAME --new help  questo aiuto

Consigli:
  · elenca ESPLICITAMENTE i file che vuoi, così l'IA non li dimentica
  · piano sbagliato? scrivi un indizio al prompt (es. "voglio anche backup.sh,
    l'origine è /home") e il piano viene rifatto; gli indizi si accumulano
  · lo stesso vale per ogni file: scrivi un indizio e viene rigenerato
  · il progetto nasce in ~/<nome>/projects (la cartella dedicata dell'assistente);
    finché il nome è "glia" nasce invece DOVE SEI, per non toccare il repo ~/glia
  · non tocca MAI una cartella esistente: se il nome è occupato ne
    sceglie uno libero (nome-2, nome-3, ...) e te lo mostra prima
  · richiede jq

Esempio:
  $ASSIST_NAME --new uno script di backup con rsync e un README che lo spiega
EOF
        ;;
    de) cat <<EOF
Neues Projekt - $ASSIST_NAME --new   (bis v2.17 hieß es -p)

Plant ein kleines Projekt und schreibt seine Dateien, mit deiner Bestätigung bei jedem Schritt.
Legt immer einen NEUEN Ordner an. Vorhandene Dateien ändern: $ASSIST_NAME -p help

Befehle:
  $ASSIST_NAME --new <Idee> Schritte planen und Dateien schreiben (Bestätigung je Datei)  [-n]
  $ASSIST_NAME --project-model [Name]   KI für --new und -p festlegen (allein: geführtes
                            Menü; "default"/-d = wieder dem Standardmodell folgen)
  $ASSIST_NAME --new help  diese Hilfe

Tipps:
  · liste die gewünschten Dateien EXPLIZIT auf, sonst vergisst sie die KI
  · Plan falsch? schreibe am Prompt einen Hinweis (z. B. "ich will auch
    backup.sh, Quelle ist /home") und der Plan wird neu erstellt; Hinweise
    sammeln sich an
  · dasselbe gilt für jede Datei: Hinweis eingeben und sie wird neu erzeugt
  · das Projekt entsteht in ~/<name>/projects (der eigene Ordner des Assistenten);
    solange der Name "glia" ist, entsteht es WO DU BIST (das Repo ~/glia bleibt unberührt)
  · es rührt NIE einen bestehenden Ordner an: ist der Name belegt, wird
    ein freier gewählt (Name-2, Name-3, ...) und vorher angezeigt
  · benötigt jq

Beispiel:
  $ASSIST_NAME --new ein Backup-Skript mit rsync und eine README, die es erklärt
EOF
        ;;
    *) cat <<EOF
New project - $ASSIST_NAME --new   (up to v2.17 this was -p)

Plans a small project and writes its files, with your confirmation at each step.
It always creates a NEW folder. To change files that already exist: $ASSIST_NAME -p help

Commands:
  $ASSIST_NAME --new <idea>  plan the steps and write the files (confirm each one)  [-n]
  $ASSIST_NAME --project-model [name]   pin the AI used by --new and -p (alone: guided
                            menu; "default"/-d = go back to following the default model)
  $ASSIST_NAME --new help  this help

Tips:
  · list the files you want EXPLICITLY, so the AI doesn't forget them
  · wrong plan? type a hint at the prompt (e.g. "I also want backup.sh,
    the source is /home") and the plan is redone; hints accumulate
  · the same works for each file: type a hint and it is regenerated
  · the project is created in ~/<name>/projects (the assistant's own folder);
    while the name is still "glia" it is created WHERE YOU ARE, leaving ~/glia alone
  · it NEVER touches an existing folder: if the name is taken, a free one
    is picked (name-2, name-3, ...) and shown before writing
  · requires jq

Example:
  $ASSIST_NAME --new a backup script with rsync and a README explaining it
EOF
        ;;
    esac
}

pmode_help() {
    case "$UILANG" in
    it) cat <<EOF
Modifica file - $ASSIST_NAME -p   (nuovo nella v2.18)

Cambia un file che ESISTE GIÀ. Ti mostra il diff prima di toccare qualsiasi cosa:
decidi tu se applicarlo. Per creare un progetto nuovo da zero: $ASSIST_NAME --new help

Comandi:
  $ASSIST_NAME -p <file> "<cosa cambiare>"   proponi la modifica, mostra il diff, chiedi
  $ASSIST_NAME -p <f1> <f2> "<cosa>"         stessa cosa su PIÙ file: UN solo diff,
                                             una conferma, un commit (v2.18)
  $ASSIST_NAME -p --undo   annulla l'ultimo commit di -p (git revert, mai reset)
  $ASSIST_NAME -p help     questo aiuto

Dopo l'applicazione ti propone un commit locale (mai pushato): è quello che
rende possibile -p --undo.

Come funziona:
  1. legge il file e lo manda all'IA del codice
  2. l'IA risponde con blocchi cerca/sostituisci (non con un diff: i modelli
     piccoli sbagliano i numeri di riga, e la patch non si applicherebbe mai)
  3. GLIA applica i blocchi a una COPIA temporanea e calcola lui il diff vero
  4. ti mostra il diff colorato e il comando git apply esatto
  5. tocca il file solo se rispondi $YES_KEY

Al prompt:  $YES_KEY = applica · Invio o n = annulla · e = rifai la richiesta · q = esci
Se annulli, la patch resta in /tmp: puoi applicarla a mano quando vuoi.

Serve git:
  è la tua rete di sicurezza (git diff, git checkout per annullare). Se la cartella
  non è un repo, GLIA ti propone git init e ti mostra il comando. Non è un repo e
  non vuoi? Nessun problema: -p esce senza toccare niente.

Se l'IA sbaglia i blocchi:
  riprova fino a $PMODE_MAX_RETRIES volte spiegandole l'errore; poi chiede il file
  intero riscritto; se fallisce anche quello si arrende e ti mostra la sua risposta
  grezza. Il file NON viene mai lasciato a metà.

Impostazioni (in cima al file glia):
  PMODE_NUM_CTX=$PMODE_NUM_CTX   contesto in token · PMODE_CTX_RESERVE=$PMODE_CTX_RESERVE riservati
  PMODE_MAX_RETRIES=$PMODE_MAX_RETRIES tentativi · log: ${PMODE_LOG/#$HOME/\~}
  File troppo grande? GLIA rifiuta invece di tagliarlo (un file mutilato produce
  modifiche sbagliate): scegli un'IA con più contesto o alza PMODE_NUM_CTX.

IA usata: quella del codice ($ASSIST_NAME --project-model), la stessa di --new.
Richiede git e jq.

Esempio:
  $ASSIST_NAME -p backup.sh "aggiungi un'opzione --verbose"
EOF
        ;;
    de) cat <<EOF
Dateien ändern - $ASSIST_NAME -p   (neu in v2.18)

Ändert eine Datei, die BEREITS EXISTIERT. Zeigt dir den Diff, bevor irgendetwas
angefasst wird: du entscheidest. Neues Projekt von Null: $ASSIST_NAME --new help

Befehle:
  $ASSIST_NAME -p <Datei> "<was ändern>"   Änderung vorschlagen, Diff zeigen, fragen
  $ASSIST_NAME -p <D1> <D2> "<was>"        dasselbe für MEHRERE Dateien: EIN Diff,
                                           eine Bestätigung, ein Commit (v2.18)
  $ASSIST_NAME -p --undo   letzten -p-Commit rückgängig machen (git revert, nie reset)
  $ASSIST_NAME -p help     diese Hilfe

Nach dem Anwenden wird ein lokaler Commit angeboten (nie gepusht): er macht
-p --undo möglich.

So funktioniert es:
  1. liest die Datei und schickt sie an die Code-KI
  2. die KI antwortet mit Suchen/Ersetzen-Blöcken (nicht mit einem Diff: kleine
     Modelle verwechseln Zeilennummern, der Patch würde nie passen)
  3. GLIA wendet die Blöcke auf eine temporäre KOPIE an und berechnet den echten Diff
  4. zeigt dir den farbigen Diff und den exakten git-apply-Befehl
  5. die Datei wird nur bei $YES_KEY angefasst

Am Prompt:  $YES_KEY = anwenden · Enter oder n = abbrechen · e = Anfrage ändern · q = beenden
Bei Abbruch bleibt der Patch in /tmp: du kannst ihn jederzeit selbst anwenden.

git wird gebraucht:
  es ist dein Sicherheitsnetz (git diff, git checkout zum Rückgängigmachen). Ist der
  Ordner kein Repo, schlägt GLIA git init vor und zeigt den Befehl. Kein Repo und
  du willst keins? Kein Problem: -p beendet sich, ohne etwas anzufassen.

Wenn die KI die Blöcke verfehlt:
  bis zu $PMODE_MAX_RETRIES Versuche mit erklärtem Fehler; dann wird die ganze Datei
  neu angefordert; scheitert auch das, gibt GLIA ehrlich auf und zeigt die Rohantwort.
  Die Datei bleibt NIE halbfertig zurück.

Einstellungen (oben in der glia-Datei):
  PMODE_NUM_CTX=$PMODE_NUM_CTX   Kontext in Token · PMODE_CTX_RESERVE=$PMODE_CTX_RESERVE reserviert
  PMODE_MAX_RETRIES=$PMODE_MAX_RETRIES Versuche · Log: ${PMODE_LOG/#$HOME/\~}
  Datei zu groß? GLIA lehnt ab statt zu kürzen (eine gekürzte Datei erzeugt falsche
  Änderungen): nimm eine KI mit mehr Kontext oder erhöhe PMODE_NUM_CTX.

Genutzte KI: die Code-KI ($ASSIST_NAME --project-model), dieselbe wie --new.
Benötigt git und jq.

Beispiel:
  $ASSIST_NAME -p backup.sh "füge eine --verbose-Option hinzu"
EOF
        ;;
    *) cat <<EOF
Edit files - $ASSIST_NAME -p   (new in v2.18)

Changes a file that ALREADY EXISTS. It shows you the diff before touching
anything: you decide. To create a new project from scratch: $ASSIST_NAME --new help

Commands:
  $ASSIST_NAME -p <file> "<what to change>"   propose the change, show the diff, ask
  $ASSIST_NAME -p <f1> <f2> "<what>"          same, on SEVERAL files: ONE diff,
                                              one confirm, one commit (v2.18)
  $ASSIST_NAME -p --undo   undo the last -p commit (git revert, never reset)
  $ASSIST_NAME -p help     this help

After applying, an optional local commit is offered (never pushed): it is what
makes -p --undo possible.

How it works:
  1. reads the file and sends it to the code AI
  2. the AI replies with search/replace blocks (not with a diff: small models
     get line numbers wrong, so the patch would never apply)
  3. GLIA applies the blocks to a temporary COPY and computes the real diff itself
  4. shows you the colored diff and the exact git apply command
  5. the file is touched only if you answer $YES_KEY

At the prompt:  $YES_KEY = apply · Enter or n = cancel · e = edit the request · q = quit
If you cancel, the patch stays in /tmp: you can apply it by hand whenever you want.

git is needed:
  it is your safety net (git diff, git checkout to undo). If the folder is not a
  repo, GLIA proposes git init and shows you the command. Not a repo and you don't
  want one? No problem: -p exits without touching anything.

If the AI fumbles the blocks:
  it retries up to $PMODE_MAX_RETRIES times with the error explained; then it asks for
  the whole file rewritten; if that fails too it gives up honestly and shows you its
  raw reply. The file is NEVER left half-done.

Settings (top of the glia file):
  PMODE_NUM_CTX=$PMODE_NUM_CTX   context in tokens · PMODE_CTX_RESERVE=$PMODE_CTX_RESERVE reserved
  PMODE_MAX_RETRIES=$PMODE_MAX_RETRIES retries · log: ${PMODE_LOG/#$HOME/\~}
  File too large? GLIA refuses instead of truncating it (a mutilated file produces
  wrong edits): pick an AI with more context, or raise PMODE_NUM_CTX.

AI used: the code AI ($ASSIST_NAME --project-model), the same one as --new.
Requires git and jq.

Example:
  $ASSIST_NAME -p backup.sh "add a --verbose flag"
EOF
        ;;
    esac
}

