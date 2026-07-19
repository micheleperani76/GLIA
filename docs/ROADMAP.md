# GLIA Roadmap

Updated: 2026-07-17

Where things are heading: **[Direction — the next moves](#direction-the-next-moves-noted-2026-07-16)**
— written 2026-07-16 as five threads, then D6 and D7 were added to it the same
night. Of the seven: **six landed, one dropped on purpose**:

| | thread | outcome |
|---|---|---|
| D1 | shared Ollama (`--engine`) | **dropped 2026-07-17** — costs the half of GLIA that measures your machine, buys the half that worked anyway; its one residue landed inverted in v2.19.2 (doctor says it's ignoring `OLLAMA_HOST`) |
| D2 | one console for the AIs | landed v2.18.5 · tail (one parametric message set) v2.19.1 |
| D3 | phase 5 + what we claim about it | landed 2026-07-17 — marked honestly **not started**; logo regenerated |
| D4 | does every command teach? | audit half landed v2.18.9 · error-reading landed v2.19.3 (1 case shipped, 3 held back for want of evidence) |
| D5 | configurable safety | landed v2.19.0 (`--danger`) |
| D6 | the GPU nobody uses | landed v2.18.6 (`--doctor`) + v2.18.7 (`-m bench`) |
| D7 | check-docs against drift | landed v2.18.4 |

Still open, and worth writing down before the enthusiasm returns: **three more
known errors** (stale keyring, partial upgrade, disk full) — held back on
purpose until there is real evidence for each, since D4's whole value is being
right where the forums are wrong; and **phase 5 itself** (Btrfs snapshots),
which is now honestly labelled rather than quietly "in progress". Below all
that, the running TODO list.

## Assistant intelligence mechanisms

Inspired by how large AI agents work, scaled down to stay lean on a 7B model.

Implemented in glia v1.6:

1. **Look before acting** — the model receives the current directory and a
   short listing of its contents with every request, so proposed commands
   fit the context instead of being generic.
2. **Learn from errors** — when an executed command fails, its exit code and
   stderr are sent back to the model, which proposes a corrected command
   (max 2 fix rounds, always with the usual confirmation).

3. **Persistent memory** — `--remember "<fact>"` stores short user facts in
   `~/.config/glia/memory` (max 20 lines, oldest dropped); `--memory` lists
   them, `--forget <n>` deletes one. Facts are included in every prompt
   (command mode and `-d`), so the assistant knows your machines, paths,
   habits. Not yet injected in project mode (`-p`).
4. **Conversation context** — per-terminal session file in
   `$XDG_RUNTIME_DIR/glia-session-$USER-$PPID` (mode 600): last 3 executed
   request→command exchanges, 10 minute expiry, so follow-ups like "now
   compress it" work. Only executed commands are recorded.
5. **Danger self-explanation** — before the SI/YES confirmation on a
   destructive command, a second model call explains in one plain-language
   sentence (in the UI language) what the command will do.

## Ideas to evaluate

6. **Memory retrieval (lightweight RAG)** — only if memory outgrows the
   prompt. Two stages:
   - **6a (lean, no new deps):** raise the memory cap (e.g. 200 lines) and,
     instead of injecting everything, `grep`-filter the lines sharing words
     with the request. Lexical retrieval, GLIA-style.
   - **6b (real RAG):** embeddings via Ollama (e.g. nomic-embed-text) +
     local vector store. Only if 6a proves insufficient: it adds a second
     model in RAM and new dependencies, against the lean philosophy.
   Worth it for large notes/docs/logs, not for ~20 one-line facts.

7. **GNOME Shell search provider** — invoke glia straight from the GNOME
   overview search: type a request, get the proposed command without opening
   a terminal first. A small DBus search provider + `.desktop` file that runs
   glia and shows the result. Future implementation.

## Done

1. **glia assistant** (v1.2) — proposes commands, safety levels (YES for
   destructive commands), command log, `--rename`, model from config file
   (`~/.config/glia/model` → `/etc/glia/model` → default).
2. **glia-hardware** (v1.0) — RAM/GPU detection, model tier recommendation,
   `-j` JSON output for the installer.
3. **Live ISO** — archiso (releng-based), Italian keymap, ollama service
   enabled, qwen2.5-coder:7b embedded (~5.8 GB ISO). Build with:
   `sudo bash scripts/glia-build.sh`. Test with:
   `qemu-system-x86_64 -enable-kvm -cpu host -smp 6 -m 12G -cdrom out/glia-*.iso -boot d -vga virtio`
   (run_archiso ignores extra args and defaults to 3 GB RAM: not enough
   for the 7B model).

## Done: Calamares installer (phase 4) — full QEMU install verified 2026-07-12
(UEFI: systemd-boot; BIOS grub untested on real hardware yet)

- Minimal graphical environment on the live ISO
- calamares package from the CachyOS repo
- Custom **glia-ai** module (QML + Python):
  - assistant name (default `glia`, applied via `--rename` logic)
  - model choice proposed from `glia-hardware -j`
  - writes `/etc/glia/model` on the target system
  - model download: during install if online, else first-boot service

## Direction: the next moves (noted 2026-07-16)

Five threads to open, in no particular order. Written down before they are
built, so the reasons survive the enthusiasm. (D6 and D7 were appended to the
list the same night, which makes seven — the count above is the honest one.
Each thread carries its own outcome note at the end of its section.)

### D1. A shared Ollama — use an AI that lives on another machine

The idea: point GLIA at the Ollama on your server (or on the beefy desktop in
the other room) instead of the local one, and let a weak laptop drive a 30B
model. `OLLAMA_URL` is already a single variable (one line, 17 uses), so the
*plumbing* is nearly free. Everything around it is not:

- **The hardware logic becomes a lie.** `ram_free_mb`, `check_ai` and the
  low-RAM warning all read the LOCAL `/proc/meminfo` (4 call sites), and
  `glia-hardware -l` recommends models for the LOCAL machine. Against a remote
  Ollama they measure the wrong computer: `-m pull` would refuse a 30B on a
  laptop that isn't the one running it, and the tier table would advise a 4B
  for a server with 128 GB.
- **`-m` stops being personal and becomes shared surgery.** On a shared
  server, `-m rm` deletes a model for *everyone*, `-m pull` fills someone
  else's disk, and `-m stop` unloads an AI another person is using right now.
  This is the existing TODO below ("An AI in RAM that GLIA did not load")
  turned from a politeness problem into a real one: on a shared engine
  *every* loaded model is probably someone's work.
- **The single-model-in-RAM promise doesn't apply.** `swap_in`/`swap_out`
  exist to keep exactly one AI resident on YOUR machine. On a server with
  RAM to spare that rotation is pointless churn, and on a shared one it is
  actively rude. Remote mode probably means: never swap, never stop.
- **`--update-engine` has no meaning** when the engine is not here.
- **A claim on the home page needs revisiting.** We say "no cloud, nothing
  leaves your machine". With a remote Ollama, prompts leave the machine — to
  a machine you own, over your LAN, but they leave. The honest wording is
  something like "your machine, or one you own", plus plain-language warning
  that `OLLAMA_URL` over a network is HTTP in the clear.

Shape to consider: `glia --engine <url>` (and `--engine local` to come back),
with the whole hardware/RAM/rotation layer switching off and saying so, rather
than pretending to measure a computer it cannot see. Doctor should report
which engine it is talking to, and refuse to give RAM advice about a machine
that isn't there.

---

### **DECIDED 2026-07-17: DROPPED.** A shared Ollama is not a road GLIA takes.

Not "postponed" — decided against, so it stops being re-opened every time the
idea sounds clever again. The reasons, in the order they matter:

**1. The hardware layer isn't a satellite, it's half the product.** The list
above ("the hardware logic becomes a lie") reads like a chore list. It isn't:
`glia-hardware`, the tier table, the guided `-m pull`, the RAM line in
`--doctor`, `-m bench`, the D6a GPU check — that IS what GLIA does that a bare
`ollama run` doesn't. Against a remote engine every one of them either switches
off or lies about the wrong computer. What survives — propose, confirm, explain,
teach, `--danger`, memory, aliases, `-w`/`-p`/`-T` — survives *unchanged*, which
is the tell: D1 costs the half of GLIA that measures your machine and buys the
half that would have worked anyway.

**2. The estimate was stale, and got staler the same day it was written.**
"`OLLAMA_URL` is one variable, 17 uses, the plumbing is nearly free" — it is
**20** uses now, and the three added on 2026-07-17 are the worst kind: `-m bench`
(D6b) writes `/etc/systemd/system/ollama.service.d/` and runs `systemctl restart
ollama`, and the D6a GPU check reads `/usr/lib/ollama` and `lspci`. Against a
remote engine `-m bench` doesn't merely measure the wrong box — it tries to
restart a service that isn't there. The list of local assumptions in this
section was already incomplete hours after being written, which is itself the
argument: the local engine isn't a variable, it's a premise, and premises don't
have call sites you can count.

**3. `--engine <url>` was the wrong shape anyway.** Ollama already has the
standard variable — `OLLAMA_HOST` — and this project's own rule, written in D2
above, is that *we never invent bespoke syntax when a standard one exists*. Any
version of D1 worth shipping would have honoured `OLLAMA_HOST`, not invented a
flag beside it.

**4. Nobody here needs it.** The pitch is "a weak laptop drives a 30B on the
beefy machine in the other room". The machines this is built on are an XPS17
with 31 GB and a Debian server that is *not* bigger. A feature for a user we
don't have, costing the half of the product we do have.

**The claim on the home page stands, unchanged.** "No cloud, nothing leaves your
machine" needed rewording only if we shipped this. We didn't, so it stays true —
and that is a feature, not a technicality: it is the one sentence that says what
GLIA is.

**One residue, and it survives INVERTED.** GLIA ignores `OLLAMA_HOST` silently
(0 occurrences, `OLLAMA_URL` is hardcoded to localhost). For anyone who has that
variable exported — exactly the people who own a server — `ollama list` and
`glia -m` answer differently in the same shell, and neither says why. Deciding
against remote engines makes that silence *worse*, not better: if GLIA is a
local-engine program by design, it should SAY so when it finds a variable
claiming otherwise, not quietly disagree with `ollama list` under the user's
nose. Same class as `-V` announcing "up to date" from four-hour-old facts
(fixed in v2.18.8). Not about supporting remote at all: a `--doctor` line —
*"OLLAMA_HOST points at X: GLIA only works with the local engine and is
ignoring it."*

**Done 2026-07-17 (v2.19.2).** Doctor names the variable, says it is being
ignored, why, and warns that `ollama list` in that same shell is answering from
somewhere else. A diagnostic, not a failure: nothing is broken. It only fires
when the value really points elsewhere — `localhost`, `127.*`, `::1`, a bare
`:11434` and `0.0.0.0` are all still this machine (0.0.0.0 is what you set to
make the *server* listen everywhere; as a client target it is still here).
Thirteen shapes of the variable were run through the check before it shipped,
because a rule that fires on innocents is how people learn to ignore rules —
the lesson `rm`-vs-`terrafo(rm)` taught the same day, applied before rather
than after. **This closes D1 entirely**: the thread is dropped, and the one
thing that survived it is a sentence that says so out loud.

### D2. One console for the AIs — refactor `-m` and its satellites

Today the roles are scattered across four commands: `-m`, `--web-model`,
`--project-model` (plus `--code-model` alias), `--translate-model`. That is
how `--translate-model` was born, and it is the pattern: **every new role adds
a new top-level flag**, its own help page, its own completions, its own line
in README and on the site. Adding `translate` touched five surfaces and the
role still went missing on four of them.

The ask: a single console under `-m` where you SEE every role, WHO holds it,
and can move them — instead of four commands each holding one truth. The
`-m` sheet already shows the role tags; this is the other half, the assigning.

Constraints that must survive:
- The old flags keep working. "We never invent bespoke syntax when a standard
  one exists" cuts both ways: we don't break what people already type.
- It must degrade to non-interactive use (scripts, `--yes`), not become a
  menu-only feature.
- Whatever the shape, adding role #5 must not mean touching five surfaces
  again. If it does, the refactor missed the point.

**Landed 2026-07-17 (v2.18.5, tag pending)** — `-m role` is the console: bare
lists the downloaded AIs NUMBERED (same as `-m`), each tagged with the job it
holds; you assign BY NUMBER — `-m role <n> <role>` (role = full name or its
initial, web/w · project/p · translate/t), `-m role 0 <role>` sends a job back
to the default. `roles` is a silent alias. The old `--web-model` /
`--project-model` / `--translate-model` still
work — they, the console AND the `-m` sheet's role tags now all read ONE table
(`ROLES`). The three near-identical `*_model_cmd` / `*_model_menu` triplets
collapsed into one generic body, output verified **byte-identical** (12 cases,
old vs new). Adding role #5 = one row in `ROLES` (+ a three-line alias for the
long flag); check-docs (D7) guards README/commands.html/completions. The "five
surfaces" is now one. Still open: fold the tripled `wm_`/`pm_`/`tm_` message
strings (×3 languages) into one role-parametric set — a text change, kept out
of this pass so it stayed a byte-identical refactor.

**Landed 2026-07-17 (v2.19.1, tag pending) — and the premise was wrong.** They
were filed as "triplicated": the same message three times, so folding them
would be mechanical. Reading all 57 says otherwise — **they had drifted**:

    tm_default: "Le traduzioni tornano a seguire il default."      ← a RESULT
    wm_default: "Ricerca web: uso sempre il modello di default."   ← a STATE
    pm_default: "Codice (-p, --new): uso sempre il modello di default."

Same line of code prints all three (right after the pin file is removed), and
they say different kinds of thing. D2 unified the *code* and left the *texts* —
which is precisely what made the drift visible: one body, three voices. `pm`
was the worst: it called itself **three different names** across its own five
strings ("i progetti", "il codice (comandi -p e --new)", "Codice (-p, --new)").

Decided: **the result-shaped wording wins** — it is printed after the action, so
it reports what just happened. The role's name moved to `role_noun_*` (the one
thing that genuinely differs), and the five keys became one parametric set:
**45 lines of strings → 15 + 9 nouns**. `wm_choose`/`wm_followopt` turned out
never to have been role-specific at all — the generic menu called `wm_*` for
every role, which is what a leftover prefix looks like — so they are `ro_*` now,
text untouched. And **`ROLES` lost its 3rd field**: the `wm/pm/tm` prefix
existed only to index the duplication, so it died with it. Adding a role is now
one row + its name in three languages.

`web_using`/`pm_using`/`tm_using` stay per-role **on purpose**: "for THIS
project" is a different noun form from "the projects", they are printed outside
the generic body, and folding them would need a SECOND noun table to save 9
lines and cost 12 — generalising past the point where it pays.

Verified old-vs-new with the D2 harness (fake HOME, 3 languages × 3 roles ×
4 actions, artefacts normalised). This one is **not** byte-identical, and that
was the point: every diff line was read and is an intended wording change,
nothing else moved. The `-m role` console, the role tags on the `-m` sheet and
all three `--*-model help` pages still work — the help page's field number
shifted from 4 to 3 when the prefix went, which is exactly the kind of change
that breaks quietly, so it was tested rather than assumed.

### D3. Phase 5 — Btrfs snapshots, branding, polish (and what we claim about it)

The site's Status table says phase 5 is "⏳ in progress". It is not: nothing
has been built. **Decide and align**: either start it, or mark it honestly as
not started. A status table that flatters the project is the same bug as an
`-m` sheet that hides a role — the shop window lying about the shop.

Contents, when it starts: Btrfs snapshots as a safety net before destructive
operations; the Calamares `logo.png` still says "IA" and must be regenerated
(see Branding below); docs polish.

**Landed 2026-07-17 (site + branding asset; no code changed, so no version and
no tag — VERSION identifies the CODE, and a v2.19.1 whose `bin/glia` is
byte-identical to v2.19.0 would offer everyone an update that updates nothing).**
Decided: **marked honestly as not started**, because it isn't. Phase 5 on the site said "⏳ in progress" while
nothing had been built; it now reads "○ not started" and names what it actually
is — *Btrfs snapshots as a safety net before destructive operations* — instead
of the vague "snapshots, branding, polish". The status vocabulary gained the
word it was missing: green ✓ done, amber ⏳ in progress, grey ○ not started. It
had no way to say "not yet", so anything unstarted had to borrow "in progress",
and a table that can only flatter isn't a status table.

**The logo is regenerated** and now says *GNU/Linux + AI*, closing the branding
half. It also gained a **source**: `logo.svg` lives next to it in the branding
folder, with the one-line `rsvg-convert` that rebuilds the PNG in a comment at
the top — the drift happened because the PNG was a rasterised dead end nobody
could edit, and a fix that leaves the trap open isn't a fix. Colours and
geometry were measured off the old PNG (`#1a1c2c`, `#4fd1c5`, border, baselines)
and reproduced, so only the two letters changed.

Worth writing down, because it cost real time: grepping `IA` matches the "IA"
inside **GL·IA** — `docs/logo.svg` looked guilty and was innocent. Exactly the
same unanchored-match bug as the `rm` inside *terrafo·rm* found on the same day
(D5). Twice in one session, in opposite directions: once the tool cried wolf,
once the reviewer did.

**Still open, needs a decision (not swept):** 12 files carry the header comment
`# Project: GLIA (GNU Linux IA)`, and `bin/glia-hardware` has a third variant,
`GLIA / LinuxIA`. The Branding note below says the texts were updated on
2026-07-12, so these were either deliberate or missed — they are developer-
facing comments, invisible to users, and a 12-file sweep is a decision, not an
obvious fix. Left alone pending that call.

### D4. Audit: does every command actually TEACH?

The first pillar is "you always see the command before it runs — you read it,
you approve it, you learn it". `show_equiv` is the mechanism (26 call sites:
`--rename`, `--lang`, `-m`, `--remember`, `--forget`, `--new`, `--web-model`,
w3m install…). But nobody has ever checked it **systematically**: which
commands change your system, and of those, which ones show you the equivalent
you could have typed yourself?

This is not cosmetics. A command that silently edits a config file teaches
nothing, and a project whose whole point is teaching cannot leave that to
chance. Method: list every action that writes a file, creates a link or calls
an external tool; check each one against `show_equiv`; fix the gaps. The same
`--doctor`-style treatment we gave to shadowed nicknames, applied to the
teaching promise itself.

**The other half of teaching: reading someone else's error.** A real one, hit
on 2026-07-17 while installing a package:

    errore: impossibile scaricare il pacchetto '...pkg.tar.zst.sig'
            da mirror.krfoss.org : The requested URL returned error: 404
    attenzione: impossibile scaricare alcuni file

Nothing here tells a newcomer that `.sig` is a signature, that the PACKAGE
downloaded fine, that the guilty party is *one mirror* and not the package —
and that pacman refusing is pacman doing its job. The fix is one line: get the
file from another mirror. But the answer the forums give, and the one a
frustrated person reaches for, is `SigLevel = Never`: "solving" it by turning
off signature checking for the whole system, forever.

This is squarely GLIA's job and we do nothing about it today. An assistant
that teaches the terminal should be able to say: *"the package is there, its
signature is missing on that mirror — the mirror is broken, not the package.
Take it from another one; don't switch the check off."* Worth collecting a
handful of these (mirror 404, keyring out of date, partial upgrade, disk
full): the errors where the popular workaround is worse than the problem.
That is where an assistant earns the word "assistant".

**Landed 2026-07-17 (v2.18.9, tag pending) — the audit half.** Done the way it
was written: list every action that writes a file, makes a link or calls an
external tool, then check each one against `show_equiv` instead of trusting a
memory of it. **Three were silent, and all three now teach**: `-a add` / `-a
save` and `-a rm` (they write `~/.config/glia/aliases`), and `--channel
stable|beta` (it writes `~/.config/glia/channel`). Four suspects were CLEARED,
which is the other half of an audit's value: `-m pull`/`rm`/`stop`/`update`
print their `ollama ...` line themselves, and `-p` already closes its diff with
the `git apply` you could type — teaching by another route is still teaching,
and a second copy would have been noise. The 26 existing call sites all held
up. One rule earned along the way: the equivalents shown were **run by hand**
and produce a byte-identical aliases file — a teaching line that doesn't
actually work is worse than no line, and `echo -e` eating the `\t` in the first
draft would have shipped exactly that. Where the internals differ from the
line shown (`grep -v` + atomic `mv` vs the `sed -i` we teach) the code says so
in a comment: identical result, and the temp-file dance is why an interrupted
write can't leave half an aliases file.

**Landed 2026-07-17 (v2.19.3, tag pending) — the other half, started.** The
sharpest thing found building it wasn't in the ask: **today GLIA would hand you
the forum answer itself.** When a command fails, the fix loop sends stderr to
the model and asks for a corrected command. On exactly these errors, the model
is not a neutral helper — it read the same threads, so the correction it is most
likely to produce is the popular one, and the popular one here is
`SigLevel = Never`. GLIA would launder forum folklore through an assistant the
user trusts, with our name on it. That is the argument for a deterministic
table: on ground we KNOW, we don't ask. Same shape as `-m bench` (a number beats
a heuristic) and `--danger`'s built-ins.

Shipped with **one** case — the one hit for real on 2026-07-17, pacman's mirror
404 on a `.sig`: what actually happened (the SIGNATURE is missing, not the
package; ONE mirror is out of sync; pacman refusing is pacman working), the fix
(named with the tool really present — `cachyos-rate-mirrors` here, `reflector`
on plain Arch, hand-editing the mirrorlist otherwise), and the trap spelled out.
It explains and **still** offers the usual fix prompt: inform, don't decide.

Two rules the code earned, both the hard way:

- **Match only what doesn't translate.** pacman speaks the user's language —
  verified, not assumed: `LANG=it_IT pacman -Q nope` answers *"errore:
  impossibile trovare il pacchetto"*. A regex on its prose dies at the next
  locale. `.sig`, `404`, exit codes and tool names don't move. (curl's *"The
  requested URL returned error: 404"* rides along inside the Italian output —
  that is why the 404 is anchorable at all.)
- **`|` is the field separator, so a pattern can never contain one.** The first
  draft used `\.sig([^.[:alnum:]]|$)`; `IFS` cut the regex in half and the rule
  silently stopped matching **anything** — a guard that looked armed and guarded
  nothing. It now refuses a malformed row loudly, the way `--danger` validates
  its regexes at the door.

**Deliberately NOT shipped: keyring, partial upgrade, disk full.** They are in
the ask, and one row each would have been easy. But of the four only the `.sig`
one is grounded in a real error with real text; the rest I would have written
from memory — and on a feature whose entire value is *being right where the
forums are wrong*, writing from memory is how you become the forum you are
correcting. If GLIA says "don't do X, do Y" and Y is wrong, that is worse than
silence. Each is one row + three strings **once there is evidence**: a real
error text hit on a real machine, or the distro's own documentation.

### D5. Safety first, but configurable

`EXTRA_CONFIRM_PATTERNS` is a hardcoded array (`rm -[rf]`, `dd`, `mkfs`,
`shred`, …) and `ROOT_BINS` is a hardcoded pipe-list. They are good defaults,
but they are *our* defaults on *your* machine. People have their own things
worth protecting: a company deploy script, `terraform destroy`, a `kubectl
delete` against production.

The ask: let the user add patterns of their own — and, carefully, consider
whether any can be removed. Open questions: a config file or `--danger add`?
Do user patterns extend the built-ins or replace them (only extend, surely)?
Can a pattern be disabled at all, or is the built-in list, like
`RENAME_FORBIDDEN`, the part that never bends? Whatever is chosen, the danger
self-explanation (mechanism 5 above) should work for user patterns too — a
custom rule that just says "are you sure?" without explaining is a lesser
tool than the ones we ship.

**Landed 2026-07-17 (v2.19.0, tag pending)** — `--danger`, and the three open
questions above are answered:

- **Config file or `--danger add`? Both, and they are the same thing.** The
  file IS the storage (`~/.config/glia/danger`, plain text, one ERE per line,
  `#` comments) and the command is the door — exactly the shape `--remember`,
  `-a add` and `--lang` already have. You can `cat` it, edit it, put it in your
  dotfiles; nothing is hidden in a format only we can read.
- **Extend or replace? Extend, only.** The built-ins are the floor.
- **Can a built-in be disabled? No** — like `RENAME_FORBIDDEN`. `--danger rm
  <n>` on a built-in is refused, and it says WHY: the rule only asks for one
  more keypress, and the risk it covers is your disk. A locked door with a sign
  on it, not a blank wall. The numbering is shared across the whole list
  (built-in first, yours after), the way `-m` and `-m role` share theirs.

The self-explanation needed **no work at all** to cover custom rules — it
explains the COMMAND, not the rule, so it was already right. Two guards the
ask didn't mention but the code needed: a regex is validated **at the door**
(a broken one would be fed to grep on every single command while guarding
nothing), and one that fires on `ls` gets a warning before it's accepted — a
rule that always fires doesn't protect, it teaches you to confirm without
reading, which is the exact habit the confirm word exists to prevent.

**And `--danger test` earned its place on day one**: its first real run showed
`terraform destroy -auto-approve` tripping a BUILT-IN rule. Not a bug in the
new code — `rm .*-[a-zA-Z]*[rf]` was unanchored, so it matched the "rm" inside
*terrafo**rm***, and `confi**rm** -xf` too. It has been doing that in shipped
GLIA for a long time, fails closed (a spurious warning, not a missed one) and
so nobody noticed. Fixed here to `\brm\b`, verified to still catch every real
case (`rm -rf`, `sudo rm -rf`, `rm -r`, `rm -f`, `rm --recursive`). Same story
as check-docs finding six drifts on ITS first run: a tool that catches a real
bug the day it ships is the argument for the tool.

### D6. The GPU nobody uses — backend packages, and telling who should care

**Measured on 2026-07-17**, not guessed. Dell XPS17, i7 TigerLake-H, Intel UHD
GT1 (32 EU), 31 GiB DDR, `qwen2.5-coder:7b` q4, same prompt, seed 42, temp 0,
3 runs each, same Ollama 0.32.0:

| backend | generation | prefill | output |
|---|---|---|---|
| CPU (AVX512 + VNNI + REPACK) | **8.8 tok/s** | ~460 tok/s | correct |
| Vulkan on the iGPU (`offloaded 29/29 layers`) | **1.94 tok/s** | ~98 tok/s | correct |

The iGPU is **4.5x SLOWER**, and it worked perfectly while being slower — this
is not a misconfiguration, it is the hardware. No gibberish either (upstream
issue #13086 did not reproduce): the failure mode here is speed, not
correctness. Reason: an iGPU reads from the SAME DDR as the CPU, so it brings
no memory-bandwidth advantage — and bandwidth is the bottleneck in inference —
while a GT1's 32 EUs lose badly to AVX512_VNNI, which exists precisely for
int8 inference.

**What the machine had to say for itself** (worth copying, it is our own
philosophy done by someone else):

    msg="dropping integrated GPU; to enable, set OLLAMA_IGPU_ENABLE=1"
        library=Vulkan description="Intel(R) UHD Graphics (TGL GT1)"

Ollama found the GPU, refused it, said why, and handed over the lever. That is
`'jar': that name is already a command` in another program's voice.

**The three facts that make this diagnosable** (all cheap, all local):

1. `pacman -Q ollama` → the plain `ollama` package is **CPU-only**.
2. `ls /usr/lib/ollama/` → 20 × `libggml-cpu-*.so` and nothing else: no
   `libggml-vulkan.so`, no cuda, no hip. The backend is not merely disabled,
   it **is not there**.
3. The backends are ADD-ONS, not alternatives — no conflicts, install
   alongside: `ollama-vulkan` (6.5 MiB), `ollama-cuda` (773 MiB),
   `ollama-rocm` (974 MiB).

A trap to avoid: `OLLAMA_VULKAN:true` appears in the server config even with
no Vulkan backend installed. It is a *preference*, not a capability — reading
it as "Vulkan is on" is exactly the kind of output that lies. The truthful
line is `inference compute id=... library=...`: that one lists what really
exists.

**Who this is actually for.** Not this laptop. The case that matters is the
person with an RTX who installed `ollama` instead of `ollama-cuda`, is getting
CPU speed, and has no idea: their GPU is a 10-20x gain sitting idle, and
nothing in the system ever mentions it. That is a `--doctor` check:

- **dedicated GPU + matching backend missing** → say so, name the package.
  This is the big win and the safe advice.
- **iGPU + backend missing** → do NOT recommend it. We have the number: 4.5x
  slower. Mention it exists, say it measured worse here, let them choose.
- **backend present but the iGPU is being dropped** → explain
  `OLLAMA_IGPU_ENABLE=1` and the trade-off, do not just print the lever.

**Do not ship a table of EU counts.** The honest version of this feature is
`glia -m bench` (name TBD): run the real thing both ways on THIS machine and
print tok/s, the way we did tonight. A number beats a heuristic, it survives
new hardware without maintenance, and it is the pillar applied to ourselves —
the AI proposes, the measurement decides.

**It already exists as a prototype**: `scripts/eval-backend.sh` is exactly the
script that produced the table above (raw run kept in
`docs/design/bench-gpu-2026-07-17.txt`). What it still needs to become a real
command: flip the backend itself instead of asking the user to edit a systemd
override, refuse to run when there is no GPU to compare against, and print a
verdict rather than two numbers to interpret.

One more thing seen while measuring: with the iGPU enabled Ollama reported
`type=iGPU total="23.3 GiB" available="21.0 GiB"` — it believes system RAM is
VRAM, and sized the context at 32768 instead of 4096 because of it. That is
upstream issue #14953 (OOM risk under memory pressure). If we ever do
recommend an iGPU to someone, we own that warning.

Supersedes the old TODO line "glia-hardware: detect capable AMD/Intel GPUs and
consider OLLAMA_VULKAN=1" — which guessed right ("weak iGPUs are usually not
worth it vs CPU") and now has the receipt.

**Landed 2026-07-17 (v2.18.6, tag pending)** — the `--doctor` half shipped.
A dedicated GPU (NVIDIA/AMD) with no matching Ollama backend installed is a
real failing check with the exact fix — `pacman -S ollama-cuda`/`ollama-rocm`,
verified against the CachyOS/Arch repos; other package managers get an honest
"check upstream" instead of an invented name, since they don't split GPU
backends into packages the same way. An Intel iGPU is never a failing check
and never a recommendation — only ever mentioned, with the measured 4.5x
number, and doctor also reads whether `OLLAMA_IGPU_ENABLE=1` is already set
and repeats the number either way. Detection walks the real `.so` files under
`/usr/lib/ollama` recursively, not a flat listing: `ollama-vulkan` hides its
library one folder down (`vulkan/libggml-vulkan.so`), a gap `eval-backend.sh`'s
own flat `ls` still has today. Still open: the ROCm filename pattern
(`libggml-hip*.so`) is the known ggml/llama.cpp convention but unverified on
disk here (`ollama-rocm` isn't installed on this machine) — worth a quick
check the first time this runs on AMD.

**Landed 2026-07-17 (v2.18.7, tag pending)** — D6b, `-m bench`. It flips the
backend and measures FOR REAL instead of asking the user to edit a systemd
override and read two numbers themselves: asks for confirmation, needs sudo,
restarts `ollama.service` twice (CPU baseline with the override removed, then
`OLLAMA_IGPU_ENABLE=1`), measures the same fixed prompt both times via
Ollama's own `/api/generate`, and prints a verdict — not just the numbers.
The override file is ours alone (`99-glia-bench.conf`), never touches any
other file already in `ollama.service.d/`, and a `trap` restores the original
state unconditionally, even on Ctrl-C. `--dry-run` shows the exact commands
without changing anything. Intel iGPU only for v1 — NVIDIA/AMD refuse
cleanly, since the equivalent CPU-only lever for a dedicated GPU isn't
verified on real hardware (none of these machines have one). Live-tested
end to end on this machine: CPU 6.22 tok/s vs iGPU 1.74 tok/s (-72%),
override cleanly removed and the service back to its original environment
afterwards — confirmed on disk, not just trusted from the command's own
output.

### D7. `make check-docs` — the duplicated surfaces keep drifting

Evidence from one evening (2026-07-16/17), all of it the same bug wearing
different clothes:

- the `translate` role went missing on FOUR surfaces (the `-m` sheet, the
  README, the home page, commands.html), found at four different moments;
- commands.html still described the pre-2.18 `-p` and a project path that the
  code had changed months earlier;
- the two site navs disagreed on both entries AND mobile breakpoint, so menu
  items vanished walking between pages;
- the header of `bin/glia` claimed "Version: 2.17.2" while `VERSION=2.18.0`,
  with no v2.18 changelog at all;
- README promised `--kaboom` "type YES" when it asks for CONFIRM_WORD.

None of this is carelessness: **there are five hand-kept copies of the same
truth and none of them knows about the others**. The completions were the only
surface already right — because someone once wired them to the code by habit.

The ask: one command that reads the parser in `bin/glia` as the source of
truth and fails loudly when a surface disagrees. Cheap checks that would have
caught every item above:

- every flag handled in the case statement appears in README, commands.html
  and both completions (aliases excepted, deliberately);
- `VERSION=` matches the header's `Version:` line and the newest tag;
- the two navs in `docs/*.html` have identical entries, order and breakpoint;
- no page hardcodes a localized string (`YES`, `s/y/j`) that is really
  `CONFIRM_WORD` / `$YES_KEY`.

It is the `--doctor` idea turned on the project instead of the user's machine
— and it is the only one of these threads that makes the OTHER threads cheaper:
D2 says adding role #5 must not cost five surfaces. This is how you find out
whether it did.

**Landed 2026-07-17 (v2.18.4, tag pending)** — `scripts/check-docs.sh` +
`make check-docs`, read-only, exits 0/1. All four checks from the list above
are implemented: version coherence (VERSION = header, and VERSION-ahead-of-tag
treated as the normal pre-release state, not a failure), flag→surfaces,
the two navs (section entries + breakpoint), and hardcoded confirm words.
First run caught **six real drifts**, fixed in the same change: README never
listed `--lang`, `--remember`/`--memory`/`--forget` or `--clear-cache`, and the
fish completion never offered `-w+`.

**What it CANNOT catch, learned 2026-07-17 the embarrassing way.** check-docs
verifies that every *flag* appears in README, commands.html and both
completions. It says nothing about the **prose on the home page** — and it
shouldn't: `index.html` is a shop window, not a flag list, and demanding every
flag appear there would be wrong. But that leaves a real class of drift the
tool cannot see. After a day of shipping `--danger`, `-m bench`, the GPU check
and the error teaching, check-docs was **green all day** while the home page had
not heard of any of them: its "Safety first" card still described only our
built-in rules, and the single word "danger" on the whole page was the adjective
*"Dangerous"*. Nobody noticed until Michele asked "did you update the site?".
The lesson isn't about check-docs, it's about tools in general: **it covered
what it covered, and attention went where it pointed.** A green check is not a
finished job — it is a finished *check*. This one stays a human review item,
because "does the shop window still describe the shop" is not mechanisable.

One deliberate carve-out to revisit:
`--kaboom` is exempted from the completion check on purpose (a destructive
uninstall shouldn't be one `<TAB>` away) — flip `COMPLETION_EXEMPT` if that
call is wrong. Still open for later: wire it into a pre-commit/CI step so the
check runs itself instead of relying on memory.

### D8. A bench for the context — what FITS vs what is USABLE

Opened 2026-07-17, while building the self-tuning chat window (v2.21).

`chat_ctx_probe()` answers one question honestly: how much context **fits**.
It asks the model its limit (`/api/show`) and the RAM its budget (the KV cache
is linear in the window: `2 x layers x kv_heads x head_dim x 2 bytes`, every
factor read from the engine). On the dev machine that gives 32768 — the model's
own ceiling, with RAM to spare.

**But fitting is not the same as being usable**, and today we only measure the
first one. Every turn re-sends the whole conversation, so the prompt eval grows
with the window: a 32k chat can sit comfortably in RAM and still be miserable
to talk to, because turn 12 takes half a minute before the first token. Nothing
in the current probe would ever notice — RAM says yes, and the user waits.

That number needs measuring, not reasoning, and `-m bench` is the command whose
whole job is measuring instead of guessing: `tok/s` on a short prompt vs `tok/s`
with a full ~28k context, on this machine, with this model.

What must NOT happen (the mistake almost made on 2026-07-17): moving the probe
*into* bench. `bench_cmd` returns at its first case on any machine without an
Intel iGPU — no GPU, nvidia, amd — so the Debian server and every nvidia laptop
would have been stuck at the fallback forever, and a fresh install would need a
command nobody knows exists. The probe is free (two curls, no sudo, no restart);
bench costs sudo, two ollama restarts and minutes. Bench **reports** the window;
it does not own it. Whatever D8 becomes, keep that shape.

Open questions, none of them answerable from memory:
- what does the verdict SAY? "your machine holds 32k but is pleasant up to 12k"
  is useful; a table of tok/s is not.
- would it *lower* CHAT_NUM_CTX by itself, or only advise? (glia's line has been
  inform-don't-decide since D4 — probably advise, and let the config obey.)
- it needs data from more than one machine before it has any right to a verdict.
  One measurement is an anecdote; this repo already has
  `docs/design/bench-gpu-2026-07-17.txt` as the shape to follow.

### D9. RAG — a source that does not fit the window (noted 2026-07-19)

v2.25's `/fonte` loads ONE document whole into the system message: for
anything that fits the window it is simpler and MORE reliable than RAG,
because the model sees the entire text, not fragments a retriever guessed
at. That is the right default and it stays.

But a 300-page manual does not fit 32k tokens, and no window setting will
change that. The NotebookLM answer is RAG: chunk the document, embed the
chunks (Ollama has embedding models - `nomic-embed-text` and friends), and
at every question retrieve only the few chunks that look relevant. The
price is real and must be said out loud: the model never sees the whole
document, retrieval can miss the right chunk, and then the answer is wrong
with a confident voice - the exact failure `/fonte` exists to prevent.

So the bar for building it: `/fonte` already refuses oversized files and
POINTS HERE. RAG becomes worth building the day that refusal actually
bothers someone (a real manual, a real session), not before. When it does:
- embeddings computed ONCE per file, cached (hash-keyed), not per question;
- the retrieved chunks go into the same anti-invention frame `/fonte` uses,
  each with its position in the document, so the citation habit survives;
- and the honest line at load time: "fonte grande: risponderò per estratti,
  non ho il documento intero davanti" - the limitation declared, not hidden.

## TODO

- **An AI in RAM that GLIA did not load** (decided 2026-07-16, not yet built).
  Today `swap_in` only unloads `$def`, GLIA's own default. If the user has
  started a model by hand (say `phi4:14b`, downloaded outside GLIA) and then
  runs GLIA, GLIA loads its own model *next to it*: two AIs in RAM, and the
  single-model policy of v2.15.1 is a promise we break in practice.
  Decision: `swap_in` must unload ANY model it finds loaded, not just its
  own — **but ask first**, because that AI is the user's work, not ours, and
  we do not kill someone's work silently. `swap_out` does not bring it back:
  the v2.15.5 rule stands — GLIA only restores what GLIA stopped. After that,
  the normal rotation of the AIs configured in GLIA resumes.
  Open: what to do when there is no tty to ask on (scripted runs) — refuse,
  or fall back to leaving it alone and warning?

- **glia-firstboot robustness** (found in VM test 2026-07-12): the one-time
  setup runs on every login until finished, so two concurrent logins (console
  + SSH) run it twice and inputs desync (the assistant name ended up as
  "Installation_guide" from a stray answer). Write the done-flag early or use
  a lock file; re-prompt only if setup was interrupted.
- **Localize GLIA texts**: motd, firstboot and glia messages are hardcoded
  English; pick it/en from $LANG (Calamares already sets the locale).

- **glia v1.3**: show the real aichat/ollama error instead of "empty answer"
  (drop `2>/dev/null`, log stderr); check available RAM in `check_ai`
  before loading the model (7B needs ~6 GB free).
- ~~**glia-hardware**: detect capable AMD/Intel GPUs and consider
  `OLLAMA_VULKAN=1` (experimental; known garbage-output issues on Intel
  iGPUs; weak iGPUs are usually not worth it vs CPU).~~
  → **superseded by D6**, and measured on 2026-07-17. The hunch was right
  about the conclusion (4.5x slower on a UHD GT1) and wrong about the
  reason: no garbage output at all, and `OLLAMA_VULKAN=1` is not the lever
  — the `ollama` package simply has no Vulkan backend in it, and iGPUs are
  dropped on purpose unless `OLLAMA_IGPU_ENABLE=1`.
- Btrfs snapshots as safety net (phase 5), branding, docs.
- **Branding**: naming is "GLIA — GNU/Linux + AI" (AI in English) everywhere;
  texts updated 2026-07-12. ~~the Calamares logo.png still says "IA" and must
  be regenerated~~ → **done 2026-07-17** (site/asset change, no tag): regenerated from a new
  `logo.svg` source kept beside it, so it can be rebuilt instead of redrawn.
  Open: 12 files still carry `# Project: GLIA (GNU Linux IA)` in their header
  comment (and `bin/glia-hardware` says `GLIA / LinuxIA`) — developer-facing,
  never shown to a user; sweep or keep, needs a call. See D3.
