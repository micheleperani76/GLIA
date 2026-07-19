# ============================================================

# ----------------- CONFIGURATION -----------------
VERSION="3.0.0"
DEFAULT_MODEL="qwen2.5-coder:7b"
# -m bench (D6b): CPU vs iGPU on THIS machine, config up top on purpose.
BENCH_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
BENCH_OVERRIDE_FILE="$BENCH_OVERRIDE_DIR/99-glia-bench.conf"   # our own file only - never touches anyone else's override
BENCH_PROMPT='Write a bash one-liner that finds the 5 largest files in /home. Answer with the command only.'
BENCH_RUNS=2            # generations per configuration (CPU / iGPU)
BENCH_TIMEOUT=600       # seconds, per API call
BENCH_RESTART_WAIT=20   # seconds to wait for ollama to answer again after a restart
BENCH_VERDICT_MARGIN=15 # % - the iGPU must beat CPU by more than this to be called "worth it"
if [ -r "$HOME/.config/glia/model" ]; then
    MODEL="ollama:$(head -n1 "$HOME/.config/glia/model")"
elif [ -r /etc/glia/model ]; then
    MODEL="ollama:$(head -n1 /etc/glia/model)"
else
    MODEL="ollama:$DEFAULT_MODEL"
fi

if [ -r "$HOME/.config/glia/lang" ]; then
    UILANG="$(head -n1 "$HOME/.config/glia/lang")"
elif [ -r /etc/glia/lang ]; then
    UILANG="$(head -n1 /etc/glia/lang)"
else
    case "${LANG:-en}" in
        it*) UILANG="it" ;;
        de*) UILANG="de" ;;
        *)   UILANG="en" ;;
    esac
fi
case "$UILANG" in it|de|en) : ;; *) UILANG="en" ;; esac

PROG="$(basename "$0")"                 # how the command was invoked (glia, myai, ...)
# 'glia' is the permanent anchor: config, logs and the safety command live under it.
# Names --rename must never accept: taking one of these would shadow a command
# you need (or GLIA itself), and a shadowed command fails in the worst way -
# silently, doing something else entirely. There is no confirmation for these:
# a machine you can't type 'ls' or 'sudo' on is not yours any more.
# Any OTHER name already in PATH is refused too (see rename_assistant), but
# that one is a plain "pick another": this list is the part that never bends.
RENAME_FORBIDDEN=" ls cd cp mv rm cat echo test pwd mkdir rmdir ln chmod chown \
find grep sed awk sort head tail less more kill ps top df du tar gzip gunzip \
touch which whereis file link unlink sync date time env export alias unalias \
sh bash zsh fish dash csh ksh python python2 python3 perl ruby node deno \
sudo su doas systemctl service mount umount dd mkfs fdisk parted passwd \
useradd userdel usermod shutdown reboot halt poweroff init exec eval source \
apt apt-get aptitude dnf yum pacman zypper emerge snap flatpak brew pip pip3 \
git ssh scp rsync curl wget make gcc cc vi vim nano emacs man info help \
glia glia-hardware glia-firstboot glia-install ollama aichat "

# The preferred/friendly name (shown in -h) is stored here by --rename.
NAMEFILE="$HOME/.config/glia/name"
# The assistant answers to the name it was CALLED with: a rename symlink
# (e.g. arx -> glia) makes $PROG the user's name, so help and examples mutate
# with it ('arx -h' talks about arx). Fallbacks: the name recorded by
# --rename, then the anchor 'glia' itself.
if [ -n "$PROG" ] && [ "$PROG" != "glia" ] && command -v "$PROG" >/dev/null 2>&1; then
    ASSIST_NAME="$PROG"
elif [ -r "$NAMEFILE" ]; then
    ASSIST_NAME="$(head -n1 "$NAMEFILE")"
else
    ASSIST_NAME="glia"
fi
[ -z "$ASSIST_NAME" ] && ASSIST_NAME="glia"
LOGDIR="$HOME/.local/share/glia"
LOGFILE="$LOGDIR/glia.log"
OLLAMA_URL="http://localhost:11434"

# Persistent memory (v1.6): one fact per line, newest kept
MEMFILE="$HOME/.config/glia/memory"
MEMMAX=20

# Command cache (v1.7): request+directory -> last command that worked
CACHEFILE="$LOGDIR/cache"
CACHEMAX=200

# Web search (v2.13): DuckDuckGo via the w3m text browser. No API key, no
# token juggling - w3m looks like a real browser so it is not rate-blocked.
# Everything below is meant to be easy to change (or point at SearXNG).
WEB_URL="https://lite.duckduckgo.com/lite/?q="   # ddg endpoint (?kl= region)
WEB_URL_BING="https://www.bing.com/search?q="    # bing endpoint
WEB_ENGINE_DEFAULT="ddg"  # engine when nothing is configured: ddg | bing | searx
WEBENGINEFILE="$HOME/.config/glia/web_engine"    # persistent engine choice (--web-engine)
SEARXURLFILE="$HOME/.config/glia/searx_url"      # SearXNG instance URL (searx engine only)
WEB_REGION="it-it"        # ddg result region/language bias (it-it, us-en, de-de, wt-wt)
WEB_RESULTS=5             # how many results feed the answer as sources
WEB_PAGES=0              # pages read IN FULL by default (0 = snippet-first, fast)
WEB_PAGES_DEEP=2          # pages read in full in deep mode (-w+)
WEB_MAXCHARS=2000         # max text kept per page read
WEB_COLS=400              # w3m render width: wide so result URLs are never wrapped
WEB_KEEPALIVE="30m"       # keep the model warm in RAM between -w calls (faster)
WEB_NUMPREDICT=600        # max tokens generated for the web answer
WEBMODELFILE="$HOME/.config/glia/web_model"   # optional AI dedicated to -w (empty = follow default)
CODEMODELFILE="$HOME/.config/glia/code_model" # optional AI dedicated to -p / --new coding (empty = follow default)
TRANSMODELFILE="$HOME/.config/glia/translate_model" # optional AI dedicated to -T (empty = follow default)

# --- Project mode (-p): edit existing files (v2.18, Part A) ---
# -p EDITS files that already exist; --new generates a project from scratch
# (that was -p up to v2.17). Both run on the SAME dedicated coding AI, resolved
# at run time by project_target() (see --project-model): one selection path only.
# Limits live here, not in the code: on a bigger machine with a bigger model,
# raise PMODE_NUM_CTX and the same code handles larger files.
PMODE_NUM_CTX=8192                            # context budget in tokens (model-dependent)
PMODE_CTX_RESERVE=1500                        # tokens reserved for prompt scaffolding + answer
PMODE_LOG="$HOME/.config/glia/pmode.log"      # one plain-text block per run
PMODE_DRYRUN=true                             # true = never touch a file without an explicit confirm
PMODE_MAX_RETRIES=2                           # search/replace retries before the whole-file fallback

# --- Chat mode (-c): a real conversation (v2.20, self-tuning in v2.21) ---
# The context is a JSON messages array sent WHOLE to Ollama's native
# /api/chat at every turn - follow-ups are exact, not summarized. The bar
# under each answer uses the real token counts Ollama returns.
#
# The window is NOT a number we picked: "auto" asks the model how much it
# can take (/api/show) and fits it to the RAM actually free. v2.20 shipped
# 8192 hardcoded and the machine it was written on took 32768 - four times
# more. The same script also runs on a 4 GB server, so a fixed number is
# wrong for someone by construction. Put a number here and it wins: your
# machine, your call.
CHAT_NUM_CTX="auto"                           # "auto" = ask the model, fit the RAM · or a fixed number
CHAT_CTX_CAP=32768                            # ceiling: never ask beyond this, whatever the model claims
CHAT_CTX_FALLBACK=8192                        # when /api/show tells us nothing usable
CHAT_CTX_MIN=2048                             # below this a conversation is pointless
CHAT_RAM_KEEP_MB=1500                         # RAM left to the system, never spent on KV cache
CHAT_WARN_PCT=75                              # bar turns yellow from this saturation
CHAT_CRIT_PCT=90                              # bar turns red + suggests /salva and /nuova
CHAT_SAVE_DIR="$HOME/.local/share/glia/chats" # where /salva writes the conversation (.md)

# What goes into the system message, block by block. Each block costs tokens
# you can SEE (/contesto) and turn off - the alternative was hiding the cost
# in a prettier bar, which is the bar lying. name|default(on/off)|builder
# The next block is 5 lines and a function, not a redesign (see D2).
CHAT_BLOCKS=(
    "help|on|chat_blk_help"        # the command sheet, straight out of show_help
    "memory|on|chat_blk_memory"    # the facts you stored with --remember
)
CHAT_BLOCKS_FILE="$HOME/.config/glia/chat-blocks"   # name=on|off, one per line
# Green tools INSIDE the chat (v2.24): no AI, resolved on the spot, the
# result goes into the sentence. "aliases=function": the function gets the
# word after the alias and prints the resolved text - or fails, and the text
# stays as typed. One entry today (the -D dice, same function, not a copy);
# the next green tool is one line here plus its function, not a redesign.
CHAT_TOOLS=(
    "dadi|wuerfel|roll|dice=dice_roll"
)
# Source mode (v2.25): ONE document as the chat's only knowledge base
# (glia -c --fonte <file>, or /fonte in chat). While a source is loaded the
# base blocks (sheet, memory) are SUSPENDED, not turned off: a session aimed
# at one document does not need GLIA to know itself, and every token saved
# is conversation room. Session-only on purpose: a rulebook is a per-game
# choice, not a config.
CHAT_SOURCE_FILE=""     # set at runtime; empty = normal chat

# --- Release channel / self-update (v2.17, Part E) ---
# Everything here is meant to be easy to change. Discovery uses the HTTPS repo
# URL (public, no auth, no SSH key) for `git ls-remote`; the raw base fetches a
# tagged copy of the script. Backups live under GLIA_VERSIONS_DIR for rollback.
GLIA_CHANNEL_FILE="$HOME/.config/glia/channel"                          # persisted: stable|beta (default stable)
GLIA_INSTALLED_TAG_FILE="$HOME/.config/glia/installed-tag"              # exact tag installed, e.g. v2.17.0-beta.1
GLIA_REPO_URL="https://github.com/micheleperani76/GLIA.git"             # HTTPS for ls-remote (no auth)
GLIA_RAW_BASE="https://raw.githubusercontent.com/micheleperani76/GLIA"  # + /<ref>/bin/glia
GLIA_VERSIONS_DIR="$HOME/.local/share/glia/versions"                    # backups of installed scripts
GLIA_KEEP_VERSIONS=3                                                    # how many backups to keep
GLIA_CACHE_DIR="$HOME/.cache/glia"                                      # small check-result cache
GLIA_UPDATE_CACHE_MAX_AGE=86400                                         # seconds a check result stays fresh
RC_CHECK_KEY="update-check"                                             # cache file name for the update check

# Aliases (v2.0): user shortcuts, one per line
#   name<TAB>type<TAB>request<TAB>command   (type = run | ask)
ALIASFILE="$HOME/.config/glia/aliases"
DANGERFILE="$HOME/.config/glia/danger"           # D5: YOUR extra danger patterns, one ERE per line (# = comment)

# Save-last / repeat proposal (v2.2)
LASTFILE="$LOGDIR/last"        # last successful command   request<TAB>command
REPEATFILE="$LOGDIR/repeat"    # repeat tracker            key<TAB>epoch<TAB>declined
REPEAT_WINDOW=600              # seconds: propose a shortcut when a request repeats within this

# Conversation context (v1.6): per-terminal session file
# $PPID = the shell of this terminal window, so each window has its own
SESSDIR="${XDG_RUNTIME_DIR:-/tmp}"
SESSFILE="$SESSDIR/glia-session-$USER-$PPID"
SESSMAX=6        # lines kept = 3 exchanges (2 lines each)
SESSTTL=600      # seconds: session forgotten after 10 minutes

# Project mode (v2.12.3): the assistant has a DEDICATED home folder ~/<name>
# and projects are created inside it, in ~/<name>/projects/<project-name>.
# 'glia' is the permanent anchor: ~/glia is the repo and is NEVER used, created
# or moved - so while the name is still 'glia' projects are created WHERE YOU
# ARE ($PWD), exactly as before. After the first rename the assistant gets its
# own ~/<name>/projects folder.
if [ "$ASSIST_NAME" = "glia" ]; then
    PROJBASE=""                                  # anchor: no dedicated folder
else
    PROJBASE="$HOME/$ASSIST_NAME/projects"
fi
PROJBASE_SHOW="${PROJBASE/#$HOME/\~}"   # short form for help/messages

# Patterns that require extra confirmation (they don't block: they ask to type the confirm word).
# NOTE (v2.7): plain 'sudo' is NOT in this list anymore - auto-sudo (v1.8)
# made every routine install/systemctl trip the heavy warning. Destructive
# actions are matched by what they DO, with or without sudo in front.
# D5 (v2.19.0): this list is the FLOOR, not the whole story. It is ours, on
# your machine; your own dangers (a deploy script, terraform destroy, kubectl
# delete against prod) live in $DANGERFILE and are ADDED to these, never
# instead of them - see `--danger`. These built-ins do not bend, for the same
# reason RENAME_FORBIDDEN doesn't: a seatbelt you can unbolt is decoration.
EXTRA_CONFIRM_PATTERNS=(
    # \brm\b, not plain 'rm': unanchored, this fired on terrafo(rm) destroy
    # -auto-approve and confi(rm) -xf. Found by `--danger test` on its first
    # run, v2.19.0. The anchored form still catches every real case (rm -rf,
    # sudo rm -rf, rm -r, rm -f, rm --recursive) and stops crying wolf - a
    # warning that fires on innocent commands is how people learn to ignore it.
    '\brm\b .*-[a-zA-Z]*[rf]'
    '\bdd\b'
    '\bmkfs'
    '\bshred\b'
    '\bwipefs\b'
    '>\s*/dev/(sd|nvme|mmcblk)'
    'chmod .*(777|-R)'
    'chown .*-R'
    '\bparted\b|\bfdisk\b|\bcfdisk\b|\bsgdisk\b'
    '\btruncate\b'
    '\bmv\b.*/dev/null'
    ':\(\)\s*\{'
    '\b(curl|wget)\b.*\|\s*(ba|z|da)?sh'
    '\bfind\b.*-delete'
    '\brsync\b.*--delete'
    '\bgit\b.*\breset\b.*--hard'
    '\bcrontab\b.*-r'
    '\buserdel\b'
)

