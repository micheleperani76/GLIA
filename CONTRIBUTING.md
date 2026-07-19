# Contributing to GLIA

Welcome. GLIA is a bash program with one design pillar: **commands follow
standard terminal conventions**, so what a user learns here they can reuse
elsewhere. The code follows a pillar of its own: **one source of truth for
every fact**, and a script that screams when copies drift.

## The shape of the code (since v3.0.0)

Development is modular, distribution is a single file:

- **`src/`** — the source, one module per area, numeric prefix = load order.
- **`bin/glia`** — the GENERATED artifact: `cat src/[0-9]*.sh`, committed
  to the repo so `--update` and `--rollback` keep installing one file.
- **You edit `src/`, never `bin/glia`.** `scripts/check-docs.sh` (check #6)
  rebuilds and compares byte-for-byte: a hand edit of the artifact fails CI
  of the mind — and the check.

### The module map

| module | what lives there |
|---|---|
| `00-header` | the header comment: version history, one honest block per release |
| `10-config` | configuration: paths, defaults, the registries (CHAT_BLOCKS, CHAT_TOOLS, ROLES) — and `VERSION` |
| `20-lang` | every user-facing string, three languages (`t()`), `show_help` |
| `30-core` | base helpers: paging, AI check, small plumbing |
| `32-models` | `-m`: choose, pull, update, remove models; RAM primitives |
| `34-update` | self-update from git tags, `--kaboom` |
| `36-memory` | persistent memory, session context, command cache, aliases |
| `37-savelast` | save-last & repeat proposal |
| `38-bench` | `-m bench`: measure, don't guess |
| `40-helppages` | the per-area help pages |
| `42-interactive` | `-i` |
| `50-chat` | the chat: measured window, system-message blocks, `/contesto`, `/ricorda` |
| `52-tools` | green tools: `-D` dice + the in-chat `/dadi` expansion |
| `54-source` | source mode: `/fonte`, one document as the whole truth |
| `56-chatloop` | `chat_help` + the chat loop itself |
| `58-doctor-net` | `--doctor`, release channels, update checks |
| `60-danger` | danger rules (D5), reading other people's errors (D4) |
| `62-piped` | piped input as context |
| `64-project-new` | `--new`: a project from scratch |
| `66-translate` | `-T` |
| `70-nameguard` | the rename guard (glia stays the recovery name) |
| `72-web` | `-w` / `-ws`: web search via w3m, no keys |
| `74-ramswap` | one model in RAM: swap out, swap back |
| `76-roles` | roles (D2): pin an AI to a job |
| `80-pmode` | `-p`: edit existing files with a real diff |
| `90-main` | the dispatch `case "$1"` — and nothing else |

## The workflow

```bash
# edit a module, then:
make build        # src/*.sh -> bin/glia (refuses if bash -n fails)
make check        # build + check-docs: versions, flags in docs, build match
make lint         # shellcheck on the modules (informative, not blocking)
```

Test what you touched. There is no test framework and that is deliberate:
extract the functions you changed into a temp file, drive them with stubs,
check the output (see the git history for many worked examples). `bash -n`
is the floor, not the ceiling.

## The rules that keep this codebase honest

1. **One truth.** The command sheet the chat sees is `show_help` itself.
   The window size is asked of the model, not hardcoded. Before you write
   a constant or copy a line, ask who else owns that fact.
2. **Every flag is documented everywhere or nowhere.** check-docs makes
   README, commands.html and both completions agree with the parser.
   Add a flag = add it to all surfaces (check #2 will remind you).
3. **Strings are localized.** User-facing text goes through `t()` in
   `20-lang`, in Italian, German and English. No hardcoded sentences.
4. **Numbers do not lie.** Estimates are declared as estimates ("~").
   Measured values say who measured them. A bar that hides a cost is a bug.
5. **The changelog explains WHY.** Each release gets a block in `00-header`
   that a stranger can learn from - what changed, what almost went wrong,
   what was decided against and why. Read a few before writing yours.
6. **Aggressive actions ask first** and offer a way back (backups,
   rollback, dry-run). GLIA never breaks someone's work silently.

## Sending a change

Small, focused commits; the message states the user-visible effect first.
Run `make check` before pushing - it is the same script that gates a
release. If your change adds a decision worth remembering, it probably
belongs in `docs/ROADMAP.md` too.
