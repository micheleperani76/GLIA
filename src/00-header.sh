#!/usr/bin/env bash
# ============================================================
#  glia - AI terminal assistant (Ollama + aichat)
#  Version: 3.1.0 - 2026-07-19
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Design pillar: commands follow standard terminal conventions, so
#  what you learn here you can reuse in other programs (and vice versa).
#
#  What's new in v3.1.0 ("the net into the conversation"):
#   - `/web <question>` in the chat (aliases /cerca, /suche): grab a piece
#     of the web WITHOUT leaving the dialogue. The collection is the -ws
#     pipeline - w3m asks the engine, NO AI - so the chat model never
#     moves and nothing needs saving or freezing: the user's fear ("do we
#     exit, run -w, come back carrying the saves?") dissolves because the
#     conversation lives in the running process and the collection never
#     touches the model. No swap, no exit, no loss.
#   - The results join the conversation as a marked block ([n] sources,
#     "cite them, and if they are not enough SAY SO") and the model uses
#     them at your NEXT message - the dice pattern again: the tool brings
#     a FACT the model cannot fudge, the model narrates when you speak.
#   - Refused in source mode: there the document is the ONLY truth, and
#     two exclusive promises cannot hold at once. /fonte off first.
#   - The cost is honest as always: the results live in the window like
#     any message, the bar counts them, /nuova clears them.
#
#  What's new in v3.0.0 ("the version where GLIA becomes a project"):
#   - For the USER: nothing changes. Same flags, same behaviour, same
#     --update. That is not an empty release note, it is the PROOF the
#     migration is sound: the first build of the new layout reproduced
#     the old bin/glia byte for byte (cmp, not "looks the same").
#   - For anyone touching the CODE: development moved to src/ - 26 modules,
#     one area each, numeric prefix = load order. bin/glia is now the
#     GENERATED artifact (cat src/[0-9]*.sh), still committed, so --update
#     and --rollback keep installing ONE file: no runtime sourcing, no
#     version skew between modules, and the installer never learns src/
#     exists. Edit src/, run `make build`.
#   - check-docs gained check #6: rebuild and compare, byte for byte. A
#     hand edit of the artifact is drift, and drift gets screamed at -
#     the five-copies lesson applied to the code itself.
#   - CONTRIBUTING.md: the module map, the workflow, and the house rules
#     (one truth, localized strings, honest numbers, changelog that
#     explains WHY). `make lint` runs shellcheck on the modules,
#     informative, not blocking. The major version number is for THIS:
#     the project opens its door, and the door now has a map on it.
#
#  What's new in v2.25 ("one document as the whole truth"):
#   - Source mode: `glia -c --fonte <file>` (or `/fonte <file>` in chat)
#     makes ONE document the chat's ONLY knowledge base - study a text, play
#     an RPG by YOUR house rules. The file goes to the model WHOLE, with the
#     sheet's own anti-invention rule (what is not in the document does not
#     exist: say so) plus the order to CITE the part it draws from. For
#     files that fit the window this beats RAG: the model reads the entire
#     text, not fragments a retriever guessed at (RAG for oversized files
#     is D9 in docs/ROADMAP.md, with its price written down).
#   - The base steps aside: sheet and memory are SUSPENDED while a source
#     is loaded, not turned off - a session aimed at one document does not
#     need GLIA to know itself (the user's own point), and every token saved
#     is conversation room. /fonte off brings them back exactly as they
#     were; the chat-blocks file is never touched.
#   - The size is checked BEFORE loading: over 3/4 of the window = refused
#     (no room left to talk ABOUT the document), over 1/2 = loaded with a
#     warning. The check is chars/4 and SAYS it is an estimate ("~"); the
#     real count is one /contesto away, which in source mode measures the
#     source and skips the block table - listing blocks the model is not
#     seeing would be the bar lying.
#
#  What's new in v2.24 ("you roll, the AI narrates"):
#   - Green tools live INSIDE the chat now. "/dadi 8d6" resolves WHERE it
#     sits in the sentence: "lancio una palla di fuoco che fa /dadi 8d6"
#     reaches the model as "... che fa [8d6 → 3 + 5 + ... = 29]". The roll is
#     local, instant, zero tokens; the model gets a FACT it cannot fudge -
#     the master rolls, the AI narrates. Your dice are echoed in green before
#     the model speaks, and history keeps what you TYPED, not the expansion.
#   - It is a registry (CHAT_TOOLS), not a special case: aliases=function,
#     one entry today (dice - dice_roll itself, not a copy), the next green
#     tool is one line and one function. CHAT_BLOCKS taught us to be born
#     parametric instead of discovering it three copies later.
#   - An unrecognized flag is a TYPO, not a sentence. "arx -ask comando -c"
#     used to reach the model as natural language and came back as an
#     invented echo with a confident voice - the design pillar (standard
#     terminal conventions) violated by the fallback itself. Now: "unknown
#     flag: -ask · long flags take TWO dashes (e.g. --ask)", exit 2, like
#     every program you have ever used. Natural language does not start
#     with a dash; a typo does.
#
#  What's new in v2.23 ("a d20 does not need a 7B model"):
#   - `glia -D 2d6` / `--dice`: dice in role-playing notation, [N]dM[+K|-K]
#     (1d4, 2d6, d20, 1d100+4), several rolls per call. GREEN by construction:
#     no check_ai, no model, no token - it answers in milliseconds with Ollama
#     stopped, on the server, anywhere. The rolls come from shuf (kernel
#     entropy): $RANDOM is 15 bits and modulo-biased, and a die that leans is
#     the one thing a die must not do. Single dice are shown, not just the
#     total (2d6 -> 4 + 5 = 9): in a game you want to SEE the double six.
#   - And because the sheet is show_help itself, the chat and --ask knew this
#     flag existed the moment it was written. Nobody updated anything.
#
#  What's new in v2.22 ("--ask knows itself too"):
#   - v2.21 gave the chat the command sheet and left --ask out, to save 536
#     tokens on a one-shot question. But --ask is where a user asks "how do I
#     translate a file?" most often - and got an invented flag in a confident
#     voice, exactly the failure the sheet exists to stop. Now --ask gets the
#     SAME sheet: chat_blk_help (i.e. show_help - one source of truth, never
#     a copy), honouring the SAME /contesto switch: turn "help" off once and
#     BOTH modes stop paying. One truth, one switch, one file of state.
#   - Only the intro changes: the model is told it answers ONCE, no dialogue,
#     because a sheet that says "you are the chat mode" to a mode that exits
#     after one answer would start its life with a false sentence.
#
#  What's new in v2.21 ("the machine knows better than the author"):
#   - The chat window stops being a number we picked. v2.20 shipped
#     CHAT_NUM_CTX=8192, written by hand; the machine it was written on takes
#     32768 - FOUR TIMES more, and the author never asked. "auto" now asks the
#     MODEL (/api/show) how much it can take and fits it to the RAM actually
#     free: two limits, the smaller wins, and the startup line always says
#     WHICH one won ("the model's maximum" / "free RAM limit"). The KV cost is
#     arithmetic on facts the engine reports - 2 x layers x kv_heads x head_dim
#     x 2 bytes, every factor from /api/show - so it holds on the 14b, the 32b
#     and whatever gets pulled in six months, not just on today's qwen. Put a
#     number back in and it wins: your machine, your call. A fixed default was
#     wrong for someone BY CONSTRUCTION: the same script runs on a 4 GB server.
#   - The chat knows what GLIA is. Until now the model had never heard of the
#     program it lives in: ask "how do I translate a file?" and it invented a
#     flag with a confident voice. The command sheet now goes into the system
#     message - and it is NOT written by hand, it is show_help, the same
#     function `-h` prints. A hand copy would have been the SIXTH copy of the
#     same truth (check-docs.sh exists because the first five drifted) and the
#     only one nobody could ever see drift.
#   - That sheet costs tokens, and the bar does NOT hide them. The honest fix
#     for a base cost is not a prettier zero: it is a switch. The system
#     message is a REGISTRY of blocks now (CHAT_BLOCKS, like ROLES) - /contesto
#     measures each one with real tokens (asked of the engine, not chars/4) and
#     turns it off for good. Small machine: `/contesto help off`, once.
#     The next block is five lines and a function, not a redesign (D2).
#   - /ricorda - the chat can finally write to the memory it could already
#     read, and the system message is rebuilt ON THE SPOT: a fact the model
#     cannot see until the next chat would be the worst kind of failure, the
#     kind that looks like it worked. Manual on purpose: every fact is paid for
#     in EVERY future prompt of EVERY mode, so whoever pays decides. Also
#     /memoria and /scorda, same shared memory as --remember.
#   - The memory line stops doing two jobs. memory_context() ends with
#     "otherwise act on the local machine" - written for the command proposer.
#     In a chat nothing is executed: that tail is either noise or a shove
#     towards commands this mode does not run. Same facts, right job (D2).
#   - `--doctor` and `-m bench` report the window; NEITHER owns it. Putting the
#     probe inside bench was tempting (it is the "measure, don't guess" command)
#     and would have been a bug: bench returns at line one on any machine
#     without an Intel iGPU - no GPU, nvidia, amd - so the Debian server would
#     have been stuck at 8192 forever, and a fresh install would need a command
#     nobody knows exists. The probe is free (two curls, no sudo); bench costs
#     two ollama restarts and sudo. Also: RAM says what FITS, only a real
#     measurement says what is USABLE (prompt eval re-reads the whole
#     conversation every turn) - that is a bench of its own, and it goes to
#     docs/ROADMAP.md rather than being written from memory today.
#
#  What's new in v2.20 ("someone who is actually listening"):
#   - New chat mode: `glia -c` / `--chat`. --ask answers once and exits; -c
#     keeps the WHOLE dialogue and sends it back every turn, so "and on
#     Debian?" means what it should. It talks to Ollama's native /api/chat
#     directly (not aichat): that endpoint takes the messages array as-is,
#     and its final streamed chunk carries the REAL token counts - which is
#     exactly what the saturation bar under every answer shows (green ->
#     yellow -> red; red = the model is about to forget the beginning of the
#     conversation). In-chat commands, localized: /esci /nuova /salva
#     /modello /aiuto. /modello switches the AI for THIS chat only - the
#     default is untouched, and the old model is unloaded first so two LLMs
#     never sit in RAM together. One trap defused: Ollama silently uses a
#     SMALL context unless asked, so CHAT_NUM_CTX is requested explicitly
#     (options.num_ctx) - the bar's denominator is the truth, not a hope.
#
#  What's new in v2.19 ("your machine, your dangers"):
#   - v2.19.3: D4's other half - reading someone ELSE's error. When a command
#     GLIA ran fails, the fix loop asks the AI for a correction. On a handful
#     of errors that is the WRONG move, and this is the point: the model read
#     the same forums the user would, so the answer it is most likely to
#     produce is the popular one - and for these, the popular one is a
#     permanent, system-wide security downgrade. Today GLIA would launder
#     forum folklore through an assistant the user trusts, with our name on
#     it. So: on the ground we KNOW, we don't ask. First case, the one hit for
#     real on 2026-07-17 - pacman, a mirror 404 on a `.sig`: what actually
#     happened (the SIGNATURE is missing, not the package; ONE mirror is
#     broken; pacman refusing is pacman working), the fix (the mirror tool
#     that is really on this machine - cachyos-rate-mirrors here, reflector on
#     plain Arch), and the trap (`SigLevel = Never`, which turns signature
#     checking off for the WHOLE system FOREVER because one mirror broke
#     today). We explain and STILL offer the fix prompt: inform, don't decide.
#     Matching only touches what does NOT translate - pacman speaks the user's
#     language (verified: `LANG=it_IT pacman -Q nope` answers in Italian), so
#     `.sig` and `404` are the anchors, never the prose. Rules lean tight: a
#     miss costs nothing, a false positive lectures you about an error you
#     don't have. Keyring, partial upgrade and disk full are NOT here on
#     purpose - see docs/ROADMAP.md: writing them from memory is how you
#     become the forum you're correcting.
#   - v2.19.2: `--doctor` stops ignoring OLLAMA_HOST in silence. GLIA talks to
#     the LOCAL engine by decision, not by accident (D1 - a shared Ollama -
#     was dropped on purpose: it costs the half of GLIA that measures your
#     machine and buys the half that worked anyway). But whoever exports
#     OLLAMA_HOST is exactly the person who owns a server, and for them
#     `ollama list` and `glia -m` answer from different machines in the SAME
#     shell, with nothing saying why. Deciding against remote makes that
#     silence worse, not better: doctor now names the variable, says it is
#     being ignored and why. A diagnostic, not a failure - nothing is broken.
#     Only fires when the value really points elsewhere: localhost, 127.*,
#     ::1, a bare ":11434" and 0.0.0.0 are all still this machine, and a
#     warning on those would be crying wolf (the lesson from v2.19.0's rm/
#     terraform false positive).
#   - v2.19.1: the D2 tail - wm_/pm_/tm_ folded into ONE parametric set. They
#     were filed as "triplicated strings"; they were not. They had DRIFTED:
#     tm_default announced a RESULT ("translations go back to following the
#     default") while wm_/pm_ described a STATE ("always uses the default
#     model") - printed by the SAME line of code, right after the pin file is
#     removed. D2 unified the code and left the texts, which is what made the
#     drift visible. The result-shaped wording won (it reports what just
#     happened); the role's name now comes from role_noun_* and everything
#     else is one set of five: 45 lines of strings became 15 + 9 nouns.
#     `pm` also called itself three different things ("i progetti", "il
#     codice (comandi -p e --new)", "Codice (-p, --new)") - now one name.
#     wm_choose/wm_followopt were never role-specific: the generic menu called
#     wm_* for every role, which is what a leftover prefix looks like -> ro_*.
#     ROLES loses its 3rd field (the wm/pm/tm prefix): its only job was to
#     index the duplication, so it died with it. Adding a role = one row +
#     its name in three languages. web_using/pm_using/tm_using stay per-role
#     on purpose: "for THIS project" is a different noun form from "the
#     projects", they live outside the generic body, and folding them would
#     need a SECOND noun table to save 9 lines and cost 12.
#   - v2.19.0: `--danger` (D5) - the safety rules stop being only ours. The
#     built-in patterns cover the classics (rm -rf, dd, mkfs, curl|sh), but
#     they are OUR defaults on YOUR machine: a deploy script, `terraform
#     destroy`, a `kubectl delete` against prod are dangers we cannot know.
#     Now you add them: `--danger` lists every rule numbered (built-in first,
#     yours after), `--danger add '<regex>'`, `--danger rm <n>` for your own,
#     and `--danger test '<cmd>'` - the dry-run of safety: it says whether a
#     rule would fire and WHICH, running nothing. Yours are ADDED to the
#     built-ins, never instead: the built-ins don't come off, like
#     RENAME_FORBIDDEN, because the cost is one keypress and the risk is your
#     disk - and refusing says WHY, which is the difference between a locked
#     door and a blank wall. The danger explanation needed no work to cover
#     custom rules: it explains the COMMAND, not the rule. A regex is
#     validated at the door (a broken one would be checked on every command
#     while guarding nothing) and one that fires on `ls` is warned about: a
#     rule that always fires teaches you to confirm without reading.
#     File: ~/.config/glia/danger, plain text, one ERE per line.
#   - v2.19.0: a built-in rule stops crying wolf - `rm .*-[a-zA-Z]*[rf]` was
#     unanchored, so it fired on `terrafo(rm) destroy -auto-approve` and
#     `confi(rm) -xf`. `\brm\b` catches every real case (rm -rf, sudo rm -rf,
#     rm -r, rm -f, rm --recursive) and no innocents. Found by `--danger
#     test` on its first run - the same way check-docs (D7) found six drifts
#     on its first run. A tool that finds a real bug the day it ships is the
#     argument for the tool.
#
#  What's new in v2.18 ("-p edits, --new creates, -T translates"):
#   - v2.18.4: `make check-docs` (D7) - the parser in bin/glia is the source
#     of truth, and a checker now fails loudly when a documented surface
#     drifts from it. Four checks: version coherence (VERSION = header, and
#     compared with the newest tag - VERSION ahead of the tag is the normal
#     pre-release state, not an error); every parser flag present in README,
#     commands.html and BOTH completions (aliases excepted; --kaboom is kept
#     out of tab-completion on purpose, being the destructive uninstall);
#     the two site navs agreeing on entries, order and mobile breakpoint;
#     and no page hardcoding a confirm word that is really $CONFIRM_WORD /
#     $YES_KEY. It caught six real drifts on the first run, fixed here:
#     README never listed --lang, --remember/--memory/--forget or
#     --clear-cache, and the fish completion never offered -w+.
#   - v2.18.5: `-m role` (D2) - one console for the AI roles. `-m role` lists
#     the downloaded AIs NUMBERED (same as `-m`), each tagged with the job it
#     holds (default/web/project/translate); you assign BY NUMBER with
#     `-m role <n> <role>` (role = full name or its initial: web/w, project/p,
#     translate/t), and `-m role 0 <role>` sends a job back to the default.
#     The old --web-model / --project-model / --translate-model still work:
#     they, the console and the sheet's role tags all read ONE table (ROLES),
#     so adding a role is one row instead of five hand-kept surfaces - the
#     very cost D7's check-docs measures. The three near-identical *_model_cmd
#     and *_model_menu triplets collapsed into one generic body, and the
#     numbered listing is shared with `-m` (model_list_tagged).
#   - v2.18.6: `--doctor` gains a GPU/backend check (D6a). Read-only: a
#     dedicated GPU (NVIDIA/AMD) with no matching Ollama backend installed
#     is the safe advice, and pacman gets the exact package (ollama-cuda/
#     -rocm, verified against the repos); other package managers get a
#     "check upstream" nudge instead of an invented name. An Intel iGPU is
#     the opposite case: only ever mentioned, never recommended - measured
#     4.5x slower than CPU on ours (docs/design/bench-gpu-2026-07-17.txt),
#     and if OLLAMA_IGPU_ENABLE=1 is already set, doctor says so and repeats
#     the number. Detection walks /usr/lib/ollama for the real .so files
#     (not the package DB), because ollama-vulkan puts its library in a
#     vulkan/ subfolder a flat `ls` would miss - the same gap eval-backend.sh
#     (the D6 prototype) has today. Flipping the backend itself is `-m bench`
#     (D6b), still to come.
#   - v2.18.7: `-m bench` (D6b) - flips the backend and measures FOR REAL,
#     instead of asking the user to edit a systemd override and read two
#     numbers themselves. Intel iGPU only for now (the CPU-only lever for a
#     dedicated NVIDIA/AMD GPU isn't verified on real hardware); refuses
#     cleanly otherwise. Asks for confirmation, needs sudo, restarts
#     ollama.service twice (CPU baseline, then OLLAMA_IGPU_ENABLE=1), and
#     ALWAYS restores the original state afterwards via a trap, even on
#     Ctrl-C. `--dry-run` shows the exact commands without touching
#     anything. Live-tested end to end on this machine: CPU 6.22 tok/s vs
#     iGPU 1.74 tok/s (-72%), override cleanly removed, service back to its
#     original environment afterwards.
#   - v2.18.8: `-V` checks for real. It used to be offline-only, recomputing
#     its verdict from cached facts - honest logic, stale facts: a -V run
#     hours after the last check kept saying "up to date" while newer tags
#     had landed, and --update --check contradicted it a second later. If -V
#     shows a verdict at all, the verdict must be true: online it now runs
#     the SAME check as --update --check (rc_check, cache refreshed as a
#     side effect); offline it falls back to the cache but says so, in the
#     past tense ("was up to date as of...") instead of asserting the
#     present. Costs ~0.6s online; offline stays instant.
#   - v2.18.9: the teaching audit (D4, first half). Every action that writes a
#     file, makes a link or calls an external tool, checked one by one against
#     show_equiv. Three were doing it silently, and all three are now taught:
#     `-a add`/`-a save` and `-a rm` (they write ~/.config/glia/aliases) and
#     `--channel stable|beta` (it writes ~/.config/glia/channel). The audit
#     also cleared four suspects that teach by another route and needed no
#     change: -m pull/rm/stop/update print the `ollama ...` line themselves,
#     and -p already ends its diff with the `git apply` that would do it by
#     hand. The equivalents shown were RUN by hand and produce a byte-
#     identical aliases file - a teaching line that doesn't work is worse
#     than none. Still open (D4's other half, its own change): explaining
#     someone ELSE's error - mirror 404, stale keyring, partial upgrade -
#     where the popular workaround is worse than the problem.
#   - v2.18.3: `--doctor` closes the shadowing case BACKWARDS. v2.18.2 stops
#     --rename from burying a command, but a nickname made before it is
#     still sitting there, and whoever has one is exactly the person who
#     will never find out. Doctor now walks the whole PATH for every
#     nickname of ours and reports any that covers a real command, with the
#     path it covers and the rm that fixes it. (command -v is no use for
#     this: it finds our own symlink first and reports success.)
#   - v2.18.3: scripts/eval-web.sh - a bench for -w. Web answers can't be
#     unit tested (the right answer changes with the world), but a -w that
#     silently stopped searching CAN be caught: half the questions have
#     answers that move, half don't.
#   - v2.18.2: `--rename` no longer lets a nickname bury a command. The old
#     check only looked inside ~/.local/bin, so a name living anywhere else
#     in PATH was invisible to it: `--rename jar` said "Done" and quietly
#     buried /usr/bin/jar. Now there are two guards. A reserved list
#     (RENAME_FORBIDDEN: coreutils, shells, sudo/systemctl, package
#     managers, glia/ollama itself) is refused outright - no confirmation
#     offered, because a machine you can't type 'ls' on is not yours any
#     more. Any OTHER name already in PATH is refused too, but SHOWING what
#     would have been buried (the real path) and offering free variants to
#     type instead. A name that is already our own symlink is a no-op, not
#     a collision.
#   - v2.18.2: one rename, one name. The previous nickname used to stay
#     behind for ever - nicknames piled up in ~/.local/bin unnoticed. It is
#     removed now, and SAID with the command that did it (scripts calling
#     the old name will stop: you must hear it now, not find out later).
#     'glia' answers no matter what.
#   - v2.18.1: `-T <file> [lang]` translates a file into a NEW file next to
#     it (README.md -> README.en.md); the original is NEVER touched and the
#     target name is shown before anything is written. The text streams as
#     the AI writes it - no invented percentage. The generated content is
#     verified (.md still Markdown, .sh passes bash -n): on failure it
#     retries with the error explained, then saves WITH A WARNING rather
#     than pretending. In code only comments and messages are translated.
#     `--translate-model [name|-d]` pins a dedicated AI (the twin of
#     --web-model / --project-model), `-m <name> -T <file>` is the one-off.
#     `-T help` is a full help page (it/de/en); the -m sheet shows the
#     `translate` role, so no pinned role stays invisible.
#   - CHANGED: `-p` now EDITS an existing file - it shows the diff and asks;
#     the generator (the old `-p <idea>`) moved to `--new` [-n]. They are
#     opposite jobs and must not share a flag: `-p not-a-file` says so
#     instead of silently scaffolding a project from a typo.
#   - `-p` takes SEVERAL files in one change (one diff, one confirm, one
#     commit), offers an optional local commit after applying, and `-p
#     --undo` reverts it (git revert, never reset: history stays intact).
#   - web search is pluggable: ddg | bing | searx via `--web-engine`, or a
#     one-off `engine:` prefix; `-ws <search|URL>` gives direct results with
#     NO AI call (and opens a URL as a page).
#   - `--doctor` groups its output in sections; `--new` verifies what it
#     generated, reusing the -p retry ladder.
#   - the general help fits one screen again: every area points to its own
#     help page, and each of those lists ALL of its subcommands.
#
#  What's new in v2.17 ("release channels: beta, and a way back"):
#   - v2.17.2: the installer no longer reassigns a default model you already
#     chose when it runs with `--yes` (or with no tty). It keeps your choice
#     and only fills an empty one, saying which model it picked and how to
#     change it. `--yes` means "don't ask me questions", not "pick for me".
#   - v2.17.1: the installer now records the installed tag in
#     ~/.config/glia/installed-tag, exactly as `--update` already did. An
#     install done by hand no longer falls back to v$VERSION, so later betas
#     of the same version are offered correctly on the beta channel.
#   - GLIA updates itself from git TAGS now, not from the tip of main. Two
#     channels: stable (only vX.Y.Z) and beta (also previews, -beta/-rc).
#     `--channel [stable|beta]` shows or switches it; the default is stable.
#   - CHANGED: bare `--update` now updates GLIA itself; the Ollama ENGINE
#     moved to `--update-engine`. The explicit old forms keep working as
#     hidden aliases (`--update glia`, `--update ollama`), so ONLY the bare
#     form changed behaviour. `-U` is an alias of `--update`.
#   - `--update --check`: ask only, install nothing.
#   - every update backs the running script up first (~/.local/share/glia/
#     versions, the last 3 are kept), so `--rollback` can put any of them
#     back - and a rollback is itself reversible (it backs up first too).
#   - the new version is fetched with ONE shallow clone of the tag and
#     validated BEFORE it replaces anything (bash -n + the file's VERSION
#     must match the tag); the swap is atomic (install + mv), so a failed
#     update leaves the working version untouched. Companions (glia-hardware,
#     completions) are refreshed from the SAME tag, so a version is coherent.
#   - `-V` no longer touches the network: it prints the version, the channel
#     and the last CACHED check with its age. The online check happens only
#     in `--update [--check]` and `--doctor`.
#   - `--doctor` gained a release section: version, channel, running file,
#     versions available for rollback, repo reachability, cached-check age.
#
#  What's new in v2.16 ("show the load"):
#   - a rotating spinner appears while a model is loaded into RAM (the guest AI
#     for -w/-p/-m, and the default being restored), so a silent ~10-15s cold
#     load no longer looks like a hang. Shared helper spin_run; it steps aside
#     automatically when stderr isn't a terminal (logs/pipes stay clean).
#   - the guest AI is now preloaded during the swap (with that spinner), so the
#     answer starts streaming as soon as it's ready.
#
#  What's new in v2.15 ("a model per job"):
#   - v2.15.5: swap_out brings the default back ONLY if GLIA was the one that
#     unloaded it (SWAP_STOPPED). If you stopped the default yourself
#     (`ollama stop`), a later -w/-p/-m guest call no longer force-reloads it:
#     your choice is respected and the default stays off.
#   - v2.15.4: the swap now announces WHICH AI it is loading for the task
#     ("Loading the AI for this task: ollama run <model>"), so the stop/load
#     step names the incoming model, not just the one being stopped.
#   - v2.15.3: web search now sends "think":false to Ollama. Reasoning models
#     (e.g. gemma, which returns its reasoning in a separate 'thinking' field)
#     were spending ALL num_predict tokens reasoning and leaving 'content'
#     empty -> the -w answer came out blank when a reasoning model was the web
#     model. Harmless on non-reasoning models. (Not a swap/RAM bug.)
#   - v2.15.2: RAM handling centralized in two primitives — mem_unload (stop
#     + free) and mem_warm (preload + keep warm). set_model, model_stop,
#     swap_in and swap_out now all go through them, so the ollama/curl
#     incantations live in ONE place (no behaviour change, just DRY).
#   - v2.15.1: single-model RAM policy. The swap ALWAYS unloads the default
#     before loading a guest AI (web/project/one-off), even when there is
#     room for both: exactly ONE model stays in RAM at any time. The default
#     is reloaded/kept warm afterwards. (The old "enough RAM for both: keep
#     both" behaviour is gone.)
#   - `--project-model <name>`: pin a dedicated AI for `-p` (projects/coding),
#     exactly like `--web-model` does for web search. `--project-model default`
#     (or `-d`) follows the default; `--project-model` alone shows it and a
#     guided menu. Precedence: pin > default.
#   - `-p` (project mode) now runs on that coding AI, with the SAME shared
#     RAM swap + restore as the one-off `-m` and web search (swap_in/swap_out).
#   - `-m` list: the old "in use now" marker becomes a role tag area. Each AI
#     shows the roles pinned onto it: `default`, `web`, `project` (only
#     explicit pins; web/project appear on their own row only when set apart).
#
#  What's new in v2.14 ("swap the AI, safely"):
#   - ONE shared RAM-swap mechanism (swap_in/swap_out), reused by BOTH the
#     one-off `-m <name> <task>` AND web search. "Swap only if needed":
#     the active AI is unloaded ONLY when free RAM can't hold both; then
#     the DEFAULT is always reloaded/kept warm afterwards. Every
#     `ollama stop`/`ollama run` is shown (teaching pillar).
#   - `-m <name> -w <question>` (and `-w+`): run a web search on a chosen
#     AI just for this call, with the same RAM swap + restore.
#   - `--web-model <name>`: pin a dedicated AI for web search;
#     `--web-model default` (or `-d`) follows the default; `--web-model`
#     alone shows it and a guided menu. Precedence: inline -m > pin > default.
#   - `--ask` is the documented long form for a plain answer; the old `-d`
#     short still works as a silent legacy alias.
#   - v2.14.1: `-V` runs a SILENT update check and warns only if a newer
#     version is available online (says nothing when offline or up to date).
#     The check (net_update_status) is shared with --doctor.
#   - v2.14.2: `-w` checks the connection FIRST — if you are offline it says
#     so clearly and skips the whole browser+model procedure. The probe is
#     the shared, fast `net_online` (~1s; caching it would risk stale state).
#
#  What's new in v2.13 ("web"):
#   - `-w <question>`: search the web and answer with sources. Uses the
#     w3m text browser to query DuckDuckGo (lite) - no API key and no
#     token juggling: w3m sends real browser headers so it is not
#     rate-blocked like raw curl, and it renders result pages to clean
#     text. The model summarizes the results and ALWAYS closes with a
#     "Fonti:" list of the sources actually used.
#   - snippet-first (fast): by default only the result snippets are read;
#     `-w+ <question>` (deep) also reads the top pages in full for more
#     detail. Region via WEB_REGION; results/pages tunable at the top.
#   - teaching pillar: prints the equivalent `w3m -dump ...` command.
#     Needs w3m; a guided install hint is shown if it is missing.
#   - v2.13.1: the setup script installs w3m (base deps) and `--doctor`
#     checks it; the website documents -w/-w+ under "Ask & explain".
#
#  What's new in v2.11 ("kaboom"):
#   - `--kaboom`: guided uninstall. Asks what to remove: 1) only the
#     program (glia, config, memory, aliases, completions - Ollama, aichat
#     and the downloaded AIs stay) or 2) everything (also aichat, the
#     Ollama engine and the models). Shows EVERY command it will run
#     before running it (teaching pillar), requires the heavy typed
#     confirmation (SI/JA/YES), and never touches shared dependencies
#     (curl, jq): they belong to other programs too.
#   - reasoning models handled: <think>...</think> blocks are stripped
#     from every AI reply (strip_think), and qwen3 gets the /no_think
#     switch - a shell command needs the answer, not the thoughts
#   - hint at the proposal prompt: any text longer than one letter typed
#     at "Proposed command:" becomes extra context and the command is
#     regenerated with it (same accumulating hints as the fix loop)
#   - RAM housekeeping: switching the default model STOPS the old one
#     right away (ollama stop, shown to the user) instead of leaving it
#     in RAM for the keep_alive window; the low-RAM warning is skipped
#     when the active model is already loaded; ollama ps/stop documented
#     in -m help and --update help
#
#  What's new in v2.10 ("manage your AIs"):
#   - `-m pull <name>`: download a new AI model (checks free RAM first,
#     then offers to make it the default)
#   - `-m pull` alone: guided - hardware check (RAM, GPU, disk) + numbered
#     menu of up to 10 models FEASIBLE on this machine; the catalog and the
#     feasibility logic live in glia-hardware (-l), shared with the installer
#   - `-m update [n|name]`: refresh ALL downloaded models, or just one
#   - `-m rm <n|name>`: remove a model (asks confirmation; clears the
#     saved default if it was the one removed)
#   - `-m list|ls`: aliases of the plain `-m` listing (ollama nomenclature:
#     pull/rm/list are the SAME words ollama uses)
#   - `--update-engine` (it was `--update` until v2.17): update the Ollama
#     ENGINE itself, distro-aware (pacman repo on Arch/CachyOS, official
#     install script elsewhere)
#   - teaching pillar, everywhere: glia can do it FOR you, but its real job
#     is to hand you the command so YOU can try it at the terminal. Every
#     internal action now prints the equivalent manual command via
#     show_equiv() - "(equivale a: ...)" - and guided menus end with
#     "Puoi farlo tu con il comando: ..."
#
#  What's new in v2.9.1 ("never touch an existing folder"):
#   - if a folder with the project's name already exists, a FREE name is
#     picked (<name>-2, <name>-3, ...): the assistant never writes into a
#     folder it did not create; the chosen folder is shown before writing
#   - the assistant's fallback folder moves from <Documents>/<name> to
#     ~/<name>-projects in the HOME: a suffixed name is far less likely to
#     collide with a folder of yours (an existing <Documents>/<name> keeps
#     being used, for compatibility)
#
#  What's new in v2.9 ("projects where you are"):
#   - project mode creates the project in the CURRENT directory
#     ($PWD/<project-name>): this is a textual desktop, you must not lose
#     the context of where you are. The old projects folder
#     (<Documents>/<name>) is only a fallback when $PWD is not writable
#   - the planner is told to keep file paths relative to the project root,
#     so no more double nesting like <project>/<project>_dir/file
#
#  What's new in v2.8 ("guide the plan"):
#   - project mode (-p) now uses the SAME guided-hint procedure as the
#     fix loop (v2.4): at the plan prompt you can TYPE extra context
#     (e.g. "I also want a backup.sh script, source is /home") and the
#     plan is redone with it; hints accumulate across attempts
#   - the same at each file: type a hint at the save prompt and the file
#     is regenerated following it (r still regenerates plain, s skips)
#   - plan hints are also passed to the writing phase, so the files
#     respect what you asked for in the plan refinement
#
#  What's new in v2.7 ("smarter loop, lighter friction"):
#   - interactive mode is now a real REPL: keep asking request after
#     request in the same session (context carries over); empty line = quit
#   - m = edit the proposed command in place (readline, prefilled) before
#     running it - often you only need to change a path
#   - e = explain: ask on demand what ANY proposed command does, not only
#     the dangerous ones
#   - piped input becomes context:  cat error.log | glia why does it fail
#   - -d/--ask now uses the conversation context, so follow-ups work there too
#   - --doctor: one-shot health check (engine, model, RAM, deps, PATH, dirs)
#   - plain sudo no longer triggers the heavy danger confirmation: auto-sudo
#     (v1.8) made every trivial install noisy; truly destructive patterns
#     still get the full warning + AI explanation
#   - new danger patterns: find -delete, rsync --delete, git reset --hard,
#     crontab -r
#   - the log now records the original request next to the executed command
#   - bash completion shipped in completions/glia.bash
#   - fixes: model presence check is anchored (qwen3 no longer matches
#     qwen3:8b), single VERSION variable instead of 5 hardcoded spots
#
#  What's new in v2.6 ("interactive input, special chars safe"):
#   - the assistant with NO arguments (just `myai`) now opens an interactive
#     prompt: type the request there and it is read with `read -r`, so the
#     interactive shell (fish, zsh, bash...) never parses it. You can type
#     ' " $ | ; & * literally, with no quoting. Empty line = quit.
#   - `-i` / `--interactive` is the explicit synonym; `-i help` shows a
#     dedicated guide with examples. `-h` still shows the general help.
#   - everything after (proposal, confirm, guided fix, cache, memory) is
#     unchanged - only WHERE the request comes from is new.
#
#  What's new in v2.5 ("leaner help, deeper sub-helps"):
#   - the general `-h` is now slim: common use, the most common management
#     commands, examples, and an index of per-group detailed helps
#   - detailed help per group: `-a help` (shortcuts), `-m help` (AI/models),
#     `--memory help` (facts), `-p help` (project mode) - all paged
#
#  What's new in v2.4 ("guide the fix"):
#   - when a command fails, at the fix prompt you can now TYPE an extra hint
#     (e.g. "it's an ssh host") and it is fed to the AI to refine the command;
#     hints accumulate across attempts. Enter = plain fix, n = quit. Up to 5 tries.
#
#  What's new in v2.3 ("choose your AI"):
#   - `-m` / `--model`: pick which downloaded Ollama model the assistant uses.
#       * `-m`               guided: numbered list of AIs, pick the default
#       * `-m <n|name>`      set the default permanently (by number or name)
#       * `-m <n|name> ...`  use that AI for THIS request only (default unchanged)
#
#  What's new in v2.2 ("shortcut on the fly"):
#   - `-a save` turns the LAST successful command into a shortcut, when YOU
#     decide (never automatic)
#   - on a quick repeat of the same request (within 10 min) it offers ONCE to
#     save it as a shortcut; a decline is remembered, so it never nags
#
#  What's new in v2.1 ("alias polish"):
#   - `-a list` is numbered; `-a rm <n|name>` removes by number or name,
#     names are case-insensitive, and removal asks for confirmation
#   - `-a rm` with no argument is guided (shows the list, asks the number)
#   - `-a help` gives a detailed help focused only on aliases
#   - long help is paged (less) so it stays readable on a bare server console
#
#  What's new in v2.0 ("aliases + standard flags"):
#   - --alias / -a: save a named shortcut for a command you use often,
#     so you don't ask the AI every time. Two kinds:
#       * direct : runs the saved command instantly (e.g. Bangkok time)
#       * ask    : shows the saved command and asks "use the alias, or
#                  ask the AI?" - for requests that were a bit fuzzy
#     Manage with:  -a add | -a list | -a rm <name> | -a edit
#   - standard conformance: every short flag now has a long twin
#     (-d/--ask, -l/--log), there is a --version / -V like any normal
#     terminal program, and --cache-clear is now --clear-cache
#     (the old spelling still works)
#
#  What's new in v1.9 ("one name: glia, with a safety net"):
#   - the default command is now 'glia', which is also a permanent
#     anchor: it never gets renamed away and always works
#   - --rename NAME no longer MOVES the file: it creates a symlink
#     NAME -> glia and records the chosen name in ~/.config/glia/name,
#     so the 'glia' command keeps working as a passepartout
#   - 'glia -h' (or NAME -h) shows the current assistant name, to
#     recover it if you forgot it or mistyped it
#   - config, logs and the project folder are unified under 'glia'
#  What's new in v1.8 ("friendlier & safer confirmations"):
#   - dangerous commands now use the standard s/n prompt (localized:
#     s/it, y/en, j/de) instead of typing the whole word; Enter = No,
#     so the safe default is always "cancel"
#   - deterministic auto-sudo: before proposing, commands starting with
#     a root-only binary (pacman, systemctl, mount...) get sudo added
#     automatically, on every segment of a && / ; chain - no more
#     re-asking the AI just to add a missing sudo
#   - reboot/shutdown get their own explicit confirmation, and the model
#     is told to prefer 'systemctl restart <service>' over a full reboot
#  What's new in v1.7 ("command cache"):
#   - a request already answered is served instantly from cache; only
#     commands that ran successfully (exit 0) are cached, the command
#     itself is always re-executed (fresh output every time)
#   - at a cache hit, r = bypass the cache and ask the AI again
#   - --cache-clear empties the cache
#  What's new in v1.6 ("persistent memory"):
#   - --remember "<fact>" stores short facts in ~/.config/glia/memory
#     (max 20 lines, oldest dropped); facts are added to every prompt
#   - --memory lists the stored facts, --forget <n> deletes one
#   - conversation context: each terminal keeps its last exchanges
#     (10 min expiry), so follow-ups like "now compress it" work
#   - danger self-explanation: before the $CONFIRM_WORD prompt, the AI
#     explains in one plain sentence what the command will do
#  What's new in v1.5 ("look before acting, learn from errors"):
#   - the model now sees the current directory and its contents,
#     so commands fit the place you are in
#   - if a command fails, the error is sent back to the model and
#     a corrected command is proposed (with the usual confirmation)
#  What's new in v1.4:
#   - project mode built in: `mypc -p <idea>` plans a project in
#     steps and writes its files (with confirmation), inside
#     <Documents>/GLIA-Projects/ only. Replaces glia-project.
#   - the plan is written in the interface language
#  v1.3: multi-language UI (en/it/de), real AI errors, RAM check
#  v1.2: model from config (~/.config/glia/model -> /etc/glia/model)
#  v1.1: AI self-check, --rename, dynamic program name
#
#  Usage:
#    glia (no args)        interactive prompt: type request with special chars
#    glia <request>        propose a command (Enter = run)
#    glia -i|--interactive same as no-args; `-i help` shows a guide
#    glia -p <file> "<request>"  edit an EXISTING file: show the diff, then ask
#    glia --new <idea>     new project: plan steps, write files (was -p up to v2.17)
#    glia -T <file> [lang] translate a file into a NEW file next to it (-T help)
#    glia -D <NdM[+K]> ... dice roll, RPG notation (2d6, 1d100+4) - no AI (-D help)
#    glia -d|--ask <q>     plain-text answer, no command
#    glia -w|-w+ <q>       search the web and answer with sources (-w help)
#    glia -ws <search|URL> direct results, no AI call (a URL opens that page)
#    glia -l|--log         show the command log
#    glia -a <name>        run a saved alias (shortcut)
#    glia -a add [name cmd] create an alias  (list | rm <name> | edit)
#    glia --remember <fact> store a fact in persistent memory
#    glia --memory         list stored facts
#    glia --forget <n>     delete fact number n
#    glia --clear-cache    empty the command cache
#    glia --danger         your extra danger rules (list/add/rm/test)
#    glia --doctor         one-shot health check (engine, model, RAM, config)
#    glia -m pull [name]   download a new AI model (alone: guided menu; update/rm)
#    glia --update         update GLIA itself, from the chosen channel (-U)
#    glia --update --check check for a new version, install nothing
#    glia --update-engine  update the Ollama engine itself (--update help: guide)
#    glia --channel [ch]   show or switch the release channel (stable|beta)
#    glia --rollback       go back to a previously installed version
#    glia --kaboom         guided uninstall (program only, or everything)
#    glia --rename <name>  rename the assistant (glia always stays too)
#    glia --lang <code>    set interface language (en, it, de)
#    glia -V|--version     show the version
#    glia -h               this help
