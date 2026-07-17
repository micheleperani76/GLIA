# GLIA Roadmap

Updated: 2026-07-16

Where things are heading: **[Direction — the next moves](#direction-the-next-moves-noted-2026-07-16)**
(shared Ollama · one console for the AIs · phase 5 · the teaching audit ·
configurable safety · the GPU nobody uses, with real numbers · check-docs
against drift). Below that, the running TODO list.

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
built, so the reasons survive the enthusiasm.

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

**Landed 2026-07-17 (v2.18.4, tag pending)** — `-m role` is the console: bare
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

### D3. Phase 5 — Btrfs snapshots, branding, polish (and what we claim about it)

The site's Status table says phase 5 is "⏳ in progress". It is not: nothing
has been built. **Decide and align**: either start it, or mark it honestly as
not started. A status table that flatters the project is the same bug as an
`-m` sheet that hides a role — the shop window lying about the shop.

Contents, when it starts: Btrfs snapshots as a safety net before destructive
operations; the Calamares `logo.png` still says "IA" and must be regenerated
(see Branding below); docs polish.

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
fish completion never offered `-w+`. One deliberate carve-out to revisit:
`--kaboom` is exempted from the completion check on purpose (a destructive
uninstall shouldn't be one `<TAB>` away) — flip `COMPLETION_EXEMPT` if that
call is wrong. Still open for later: wire it into a pre-commit/CI step so the
check runs itself instead of relying on memory.

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
  texts updated 2026-07-12, the Calamares logo.png still says "IA" and must
  be regenerated.
