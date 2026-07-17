# GLIA — GNU/Linux + AI

**A Linux distribution with a built-in AI terminal assistant.**

> ⚠️ **Development status — Debian & Fedora are work in progress.**
> The assistant is built to run on **Arch, Debian and Fedora**, but so far it
> has been **fully tested only on Arch/CachyOS**. **Debian and Fedora support
> is under active development and not yet tested.** Testers and contributors are
> very welcome — please open an issue or a pull request with your results.

**The name**: **G**NU + **LI**nux + **A**I → **GLIA**. It reads the same
in Italian, where AI is "IA". And it's no accident that it sounds
biological: in the brain, *glia* are the cells that support, feed and
protect the neurons — they don't think in their place. That's exactly
what GLIA wants to be for you at the terminal: support, not substitution.

## Philosophy

**GLIA is not a chatbot that uses your PC for you — it's a bridge that brings you to the terminal.**

Most AI assistants turn the computer into a black box: you ask, something happens, you learn nothing. GLIA does the opposite. The goal is to get more people to open the terminal and actually use it, with AI sitting next to them as a guide.

Every request in natural language becomes a real shell command, shown to you *before* it runs. You read it, you approve it, you run it — and little by little you learn it. The AI doesn't replace the terminal: it teaches you to master it.

- **Transparency**: you always see the command, never just the result.
- **Learning by doing**: each interaction is a small terminal lesson.
- **Safety**: dangerous commands (rm -rf, dd, mkfs, ...) require reinforced confirmation.
- **You stay in control**: the AI proposes, you decide.
- **No lock-in — you build your own system**: GLIA ships a minimal base that boots straight to the terminal with the assistant onboard; you add a desktop environment, a browser or a dev stack yourself, by asking `glia`. You are never bound to a distribution’s defaults from day one — and since the assistant runs on Arch, Debian and Fedora, you are just as free to bring it to the distro you already prefer.
- **Standard conventions**: GLIA's own commands mirror normal terminal usage —
  `--help`/`-h`, `--version`/`-V`, matching short/long flags, `-a`/`--alias` for
  saved shortcuts. What you learn in GLIA transfers to every other tool, and what
  you already know from other tools works here. **This is a foundational rule of
  the project: we never invent bespoke syntax when a standard one exists.**

The assistant (`glia`, name configurable at install time) turns natural-language
requests into shell commands, with configurable approval levels.

**See it in action:** [a worked example](docs/example-guided-fix.md) — asking in
plain words, guiding the AI with hints to fix a failed command, and turning the
result into a saved shortcut.

## Why now

AI models keep getting smaller and sharper, and personal computers keep getting
more powerful. Running a genuinely capable assistant — one that understands what
you ask and can act on it — entirely on your own machine is about to go from
exotic to ordinary.

That's a fork in the road. All that local power can turn the computer into a
black box you talk *at* and stop understanding — or it can become the best
teacher the command line has ever had. GLIA takes the second road: not an
assistant that uses the machine for you, but one that hands you the machine —
from zero if you're just starting, or with far more reach if you already know
your way around. The shell newcomers of that near future, with capable PCs and a
local AI beside them, shouldn't be handed a black box. They should be helped in.
That's who GLIA is for.

**In good company.** The idea that a computer should *amplify* a person rather
than replace them — and that you master a machine by driving it yourself — is old
and well argued:

- Douglas Engelbart, *Augmenting Human Intellect* (1962): tools should increase
  "the capability of a man to approach a complex problem situation, to gain
  comprehension to suit his particular needs." Augment, don't automate away.
  [Doug Engelbart Institute](https://www.dougengelbart.org/pubs/augment-3906.html)
- Neal Stephenson, *In the Beginning Was the Command Line* (1999): "the
  command-line interface opens a much more direct and explicit channel from user
  to machine than the GUI." The terminal isn't a relic — it's the most direct way
  to actually understand your own computer.
  [nealstephenson.com](https://www.nealstephenson.com/in-the-beginning-was-the-command-line.html)
- Seymour Papert, *Mindstorms* (1980): not "the computer programs the child" but
  "the child programs the computer," gaining mastery by doing.
  [MIT News](https://news.mit.edu/2016/seymour-papert-pioneer-of-constructionist-learning-dies-0801)
- Why it's timely: small language models now run locally on ordinary hardware —
  fast, private, capable — through tools like Ollama and llama.cpp.
  [Running LLMs locally](https://daily.dev/blog/running-llms-locally-ollama-llama-cpp-self-hosted-ai-developers/)

## How GLIA is different

Plenty of tools now translate plain language into a shell command — it's a
crowded, useful idea. GLIA's difference isn't the translation itself. A plain
translator runs one way: words in, a command out that runs. **GLIA closes the
loop** — every command it produces is handed back to you, to read and to learn,
so what you send as a request returns to you as knowledge. Three things follow
from that:

- **It teaches instead of replacing.** Every proposal shows the real command
  before it runs, so you *learn* the terminal rather than outsource it. Most
  assistants aim to do the work for you; GLIA aims to make you able to do it
  yourself — then steps aside the moment you know how.
- **Green by design, and offline.** It runs on local Ollama — no cloud, no API
  keys, nothing leaves your machine. And it's built to spend less: turn any
  repeated request into a **shortcut that runs with no AI call at all**, while a
  local cache answers repeated questions — so the model isn't burned twice for
  the same thing. Fewer calls, less energy, a faster terminal.
- **A whole distribution, not just a command.** GLIA ships as a minimal Linux
  distro (live ISO + Calamares installer) that boots straight to the terminal
  with the assistant already onboard — and the same `glia` also installs onto
  the Arch, Debian or Fedora you already run.

The translation is the easy part — and GLIA gets it right. What makes it GLIA is
everything built on a tool that actually works: it teaches while it runs, it's
green by design, and it's a whole system, not a lone command.

## Project status

| Phase | Status |
|---|---|
| 1. `glia` assistant with safety levels | ✅ working |
| 2. Hardware detection → model recommendation | ✅ `glia-hardware` v1.0 |
| 3. Live ISO (archiso) with AI preinstalled | ✅ 5.8 GB ISO, model embedded, tested in QEMU |
| 4. Calamares installer with AI setup step | ✅ working, full install tested in QEMU (UEFI) |
| 5. Btrfs snapshots, branding, polish | ⏳ |

## Components

- **`bin/glia`** — AI terminal assistant (Ollama + aichat).
  Proposes a command → Enter runs it, `n` cancels, `r` retries.
  Destructive commands (rm -rf, dd, mkfs, sudo, curl|sh, ...) ask for a
  short `s`/`y`/`j` confirmation (Enter = no). Commands needing root get
  `sudo` added automatically. Everything is logged to
  `~/.local/share/glia/glia.log`.
  Aliases (`glia -a add <name> <cmd>`) save commands you use often so you
  don't ask the AI every time (e.g. `glia -a bangkok`); manage them with
  `-a list` / `-a rm` / `-a edit`.
  Web search with sources: `glia -w <question>` queries the chosen engine
  (DuckDuckGo by default; `glia --web-engine` switches to Bing or a SearXNG
  instance, an `engine:` prefix like `glia -w bing: <question>` picks one for
  a single search) through the w3m text browser (no API key) and the local
  model summarizes with a **Sources** list. `glia -ws <search | URL>` skips
  the AI entirely: direct results in seconds, or the page itself if you
  already have the address.
  Edit files you already have: `glia -p <file> "<request>"` asks the code AI
  for the change, computes the **real diff itself**, shows it together with the
  exact `git apply` command, and touches the file only if you say yes — decline
  and the patch is left in `/tmp` for you to apply by hand. It needs a git repo
  (that is the undo story) and proposes `git init` when there isn't one. Every
  run is logged to `~/.config/glia/pmode.log`. Creating something from scratch
  is a different job and has its own flag: `glia --new <idea>` (this was `-p`
  up to v2.17).
  Translate a file: `glia -T <file> [lang]` writes the translation into a
  **new file next to it** (`README.md` → `README.en.md`) and never touches the
  original; the target name is shown before anything is written. The text
  streams as the AI writes it, and the result is checked (a translated `.md`
  must still be Markdown, a `.sh` must pass `bash -n`) — if a check keeps
  failing it saves **with a warning** instead of pretending. In code only
  comments and messages are translated, never the code itself.
  Pick the AI per job: `glia -m` sets the default and shows
  role tags (default / web / project / translate) next to each model, while
  `glia --web-model`, `glia --project-model` and `glia --translate-model` pin a
  dedicated AI for web search, for code (`glia -p`, `glia --new`) and for
  translations. Only one model stays resident in
  RAM: GLIA swaps it out and back for a one-off task — showing which AI it
  loads — and if you stop the default yourself it is left off.
  Name it yours: `glia --rename <name>` — and since a nickname is a **command
  in your PATH**, a name that already exists is refused rather than silently
  buried; `glia --doctor` also reports any older nickname that is shadowing
  one. Standard flags
  throughout: `-h/--help`, `-V/--version`, `-d/--ask`, `-l/--log`.
- **`bin/glia-hardware`** — detects RAM/GPU/VRAM and recommends the right
  AI model tier. JSON output (`-j`) designed for the installer.
- **`config/aichat-config.yaml`** — aichat configuration for local Ollama
  (target: `~/.config/aichat/config.yaml`).

## Install GLIA — three ways

1. **Full install on a real PC** — build the ISO (step 1), write it to a
   USB stick and install (way 1).
2. **Try it in a virtual machine** — build the ISO (step 1), boot it in
   QEMU (way 2).
3. **Only the assistant** — add `glia` to the Linux you already use
   (way 3, no ISO needed).

There are no prebuilt ISO downloads: the ISO is always built fresh from
this repo.

**Why there’s no ready-made ISO.** Because the machine should be yours, not ours — and you shouldn’t be locked into one distribution from day one. GLIA gives you a minimal base that boots straight to the terminal with the assistant already onboard, nothing you didn’t choose. From there you build the system you want, at your own pace and skill level: need a desktop environment, a browser, a dev stack? You ask `glia`, and you install it together. And since the assistant runs on Arch, Debian and Fedora, you are just as free to bring it to the distro you already prefer. Either way you start bound to nothing, and you understand your computer because you built it yourself.

### Step 1 — build the ISO (needed for ways 1 and 2)

You need an Arch-based host (Arch, CachyOS, ...),
the `archiso` package, ~15 GB of free disk space and a network connection
(the AI model, ~5 GB, is downloaded once and embedded in the ISO).

```bash
sudo pacman -S archiso qemu-desktop edk2-ovmf   # qemu/ovmf only needed for testing
git clone https://github.com/micheleperani76/GLIA glia
cd glia
sudo bash scripts/glia-build.sh
```

The ISO lands in `out/glia-YYYY.MM.DD-x86_64.iso` (~6 GB). The build works
in `/var/tmp/glia-build` and cleans up after itself.

#### Building from Debian, Fedora or any non-Arch distro

`mkarchiso` only runs on Arch, but you can build inside an Arch container
with podman (or docker). You still need ~15 GB free and a network
connection; the ISO appears in `out/` on your host as usual.

```bash
# Debian/Ubuntu: sudo apt install podman git
# Fedora:        sudo dnf install podman git

git clone https://github.com/micheleperani76/GLIA glia
cd glia
sudo podman run --rm -it --privileged -v "$PWD:/glia" docker.io/archlinux:latest \
  bash -c "pacman -Syu --noconfirm archiso && bash /glia/scripts/glia-build.sh"
```

Notes:

- `--privileged` is required: mkarchiso needs loop devices and mounts.
- With docker, replace `podman` with `docker` (same arguments).
- On Fedora, if the mount is denied by SELinux, use `-v "$PWD:/glia:z"`.
- To test the ISO in QEMU on Debian/Fedora, install `qemu-system-x86` and
  `ovmf` (Debian) or `qemu-kvm` and `edk2-ovmf` (Fedora); the OVMF firmware
  path in the QEMU command of way 2 may differ (e.g.
  `/usr/share/OVMF/OVMF_CODE.fd`).

### Way 1 — install on a real PC

Write the ISO to a USB stick. **Careful: everything on the stick is
erased — double-check the device name with `lsblk` first.**

```bash
lsblk                                                    # find the stick, e.g. /dev/sdb (NOT sdb1)
sudo dd if=out/glia-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Boot the PC from the USB stick (usually F12, F8 or Esc for the boot menu;
both UEFI and legacy BIOS work), pick **Install GLIA (Calamares)** and
follow the installer: language, keyboard, disk, user, AI model. After the
reboot, log in: the one-time setup asks the name of your assistant and,
if needed, downloads the chosen model.

Hardware: 40+ GB disk; 16 GB RAM for the default 7B model, or pick the
4B model in the installer for 8 GB machines.

### Way 2 — try it in QEMU

UEFI, needs ~12 GB of free RAM for the embedded 7B model:

```bash
qemu-img create -f qcow2 out/test-disk.qcow2 40G
qemu-system-x86_64 -enable-kvm -cpu host -smp 6 -m 12G \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive file=out/glia-*.iso,media=cdrom,if=none,id=cd0 \
  -device ide-cd,drive=cd0,bootindex=0 \
  -drive file=out/test-disk.qcow2,format=qcow2,if=virtio \
  -vga virtio
```

Boot the first menu entry for the live environment, or *Install GLIA
(Calamares)* to install to the virtual disk. After installing, relaunch
QEMU without the two cdrom lines to boot the installed system.

### Way 3 — only the assistant, on the Linux you already use

**The easy way — one script for Arch, Debian, Fedora and relatives.** It
installs the two engines (ollama, aichat), the `glia` command and its
config, and offers to download a model. It never changes anything without
asking; run it with `--dry-run` first to preview every single step.

```bash
git clone https://github.com/micheleperani76/GLIA glia && cd glia
bash scripts/install-assistant.sh --dry-run   # preview, changes nothing
bash scripts/install-assistant.sh             # then the real install
```

> **Status — help wanted:** the assistant runs cross-distro, but the automated
> installer has so far been tested on **Arch/CachyOS only**. The **Debian and
> Fedora** paths are work-in-progress and **not yet tested** — if you try them,
> feedback, issues and PRs are very welcome.

**Shell notes.** `glia` itself is a bash script but runs fine from any shell.
The installer adapts to yours: if `~/.local/bin` is missing from your PATH it
offers to fix the right config file (`.bashrc`, `.zshrc`, or `config.fish` via
`fish_add_path`), and it installs TAB completion for **bash** and **fish**
automatically. **zsh** has no native completion yet — you can load the bash
one with `autoload bashcompinit && bashcompinit && source completions/glia.bash`.

<details>
<summary><b>Manual install</b> (for experts, or to see exactly what the script does)</summary>

`glia` is a bash script: it only needs `ollama` and `aichat`.

On Arch/CachyOS:

```bash
sudo pacman -S ollama aichat
sudo systemctl enable --now ollama
./bin/glia-hardware              # recommends the model for your hardware
ollama pull qwen2.5-coder:7b     # or the recommended one
install -m 755 bin/glia bin/glia-hardware ~/.local/bin/
mkdir -p ~/.config/aichat && cp config/aichat-config.yaml ~/.config/aichat/config.yaml
# TAB completion — bash:
mkdir -p ~/.local/share/bash-completion/completions && cp completions/glia.bash ~/.local/share/bash-completion/completions/glia
# TAB completion — fish:
mkdir -p ~/.config/fish/completions && cp completions/glia.fish ~/.config/fish/completions/
```

On Debian, Fedora and other distros:

```bash
curl -fsSL https://ollama.com/install.sh | sh    # official Ollama installer
                                                 # (yes, glia would explain a curl|sh and make you confirm it before running — read scripts before you pipe them to a shell!)
# aichat: grab the binary for your arch from https://github.com/sigoden/aichat/releases
# and put it in ~/.local/bin/

git clone https://github.com/micheleperani76/GLIA glia && cd glia
./bin/glia-hardware              # recommends the model for your hardware
ollama pull qwen2.5-coder:7b     # or the recommended one
install -m 755 bin/glia bin/glia-hardware ~/.local/bin/
mkdir -p ~/.config/aichat && cp config/aichat-config.yaml ~/.config/aichat/config.yaml
```

</details>

## Usage

```bash
glia find the largest files in /home   # proposes the command → Enter runs it
glia                                   # interactive REPL: request after request, any symbol allowed; empty line quits
glia --ask what does rsync do          # plain-text explanation only (-d is the old short form)
glia -c                                # real chat (--chat): the whole dialogue is kept turn after turn; a bar shows how full the context window is (real tokens); /esci /nuova /salva /modello (switch AI, this chat only)
cat error.log | glia why does it fail  # piped input becomes context for the AI
glia -w latest stable linux kernel     # search the web and answer, always with sources (-w+ reads the pages too)
glia -ws linux kernel                  # direct results, no AI call — a URL opens that page
glia -p backup.sh "add a --verbose flag"   # edit an EXISTING file: shows the diff and the git apply command, then asks
glia --new a bash backup script with rsync and a README explaining how to use it   # new project: plans the steps, then writes the files (with confirmation)
glia -T README.md en                   # translate into a NEW file next to it (README.en.md); the original is never touched
glia --remember "the server runs debian"  # store a short fact the AI will recall in later prompts
glia --memory                          # list stored facts (glia --forget <n> deletes fact n)
glia --lang it                         # switch the interface language: it / en / de
glia --clear-cache                     # empty the command cache
glia -l                                # log of executed commands
glia --danger                          # the danger rules, numbered: built-in + yours (add '<regex>' · rm <n> · test '<cmd>')
glia --doctor                          # one-shot health check (engine, model, RAM, config)
glia -m pull                           # guided download: hardware check + the AI models that FIT this machine
glia -m update                         # refresh the downloaded models (only fetches new versions)
glia -m ps                             # which model is loaded in RAM right now (= ollama ps)
glia -m stop <n|name>                  # unload a model from RAM immediately (= ollama stop)
glia -m role                           # numbered AIs + who does what; assign by number: glia -m role <n> <role>  (0 = follow the default)
glia -m bench                          # CPU vs Intel iGPU, measured on this machine (needs sudo, restores everything after; --dry-run to preview)
glia --update                          # update GLIA itself, from your channel (glia --update help: full guide)
glia --update --check                  # is there a new version? ask only, install nothing
glia --rollback                        # go back to a previously installed version
glia --update-engine                   # update the Ollama engine itself
glia --rename mypc                     # name the assistant (a name already taken by a command is refused, not buried)
glia --kaboom                          # guided uninstall (level 1: program only · level 2: everything) — asks for the confirm word in your language (YES/SI/JA)
glia-hardware                           # hardware report and recommended models
```

At every proposed command you can also press `m` to edit it in place before
running, or `e` to have the AI explain what it does. Bash tab-completion is in
`completions/glia.bash` (source it from `~/.bashrc`).

## Updates, the beta channel, and going back

GLIA updates itself from git **tags**, not from the tip of `main`, so an update
always lands on a version that was deliberately released. There are two channels:

| Channel | What you get | Tags |
|---|---|---|
| `stable` (default) | only finished versions | `vX.Y.Z` |
| `beta` | previews too, as soon as they exist | `vX.Y.Z-beta.N`, `vX.Y.Z-rc.N` |

```bash
glia --channel                 # which channel am I on?
glia --channel beta            # opt into previews
glia --channel stable          # back to finished versions only
glia --update --check          # ask, install nothing
glia --update                  # update to the newest tag on your channel
glia --rollback                # put a previous version back
```

Safety, by design:

- the running script is **backed up before every update** (`~/.local/share/glia/versions`,
  the last 3 are kept), so `--rollback` can always put one back — and a rollback
  backs up too, so it is itself reversible;
- the new version is fetched with one shallow clone of the tag and **validated
  before it replaces anything** (syntax check + the file's version must match the
  tag), and the swap is atomic: a failed update leaves the working version alone;
- `glia -V` **checks for real when online** (the same probe as
  `glia --update [--check]`, ~0.5s), so its verdict and the checker's can never
  contradict each other. Offline it falls back to the last cached check — and
  says so, with the age of that answer, instead of asserting the present.

> **Changed in v2.17:** bare `glia --update` now updates **GLIA**; the Ollama
> engine moved to `glia --update-engine`. The explicit old forms (`glia --update glia`,
> `glia --update ollama`) still work, so only the bare form changed.

### Release conventions (for the repo)

- Tags are semver: stable `vX.Y.Z`, pre-releases `vX.Y.Z-beta.N` / `vX.Y.Z-rc.N`.
- `stable` sees only `vX.Y.Z`; `beta` sees the highest tag of either kind.
- Promoting a preview = tagging **the same commit** `vX.Y.Z`. Nothing is rebuilt.
- GitHub Releases carry the changelog for stable tags; betas can be tag-only.
  The client never depends on the Releases API — plain `git ls-remote --tags`.

## Model tiers by hardware

| Tier | Hardware | Models |
|---|---|---|
| 1 | <16 GB RAM, no GPU | qwen3:4b, gemma3:4b, llama3.2:3b |
| 2 | ≥16 GB RAM, no GPU | qwen2.5-coder:7b, qwen3:8b, mistral:7b |
| 2+ | ≥24 GB RAM, no GPU | qwen3:30b-a3b (MoE: fast on CPU), qwen3:14b, qwen2.5-coder:14b |
| 3 | GPU ≥12 GB VRAM | qwen2.5-coder:14b, phi4:14b, deepseek-r1:14b |
| 4 | GPU ≥20 GB VRAM | qwen3-coder:30b, qwen2.5-coder:32b, devstral:24b |

Beyond the tiers, `glia -m pull` (with no name) checks your RAM, GPU and disk
and offers up to 10 models from a curated catalog that actually fit your
machine — pick one by number, or run the `ollama pull` command it shows you.

## Using other models — Hugging Face & GGUF

GLIA runs on **Ollama**, and you are not limited to the models in the tiers
above. Ollama can load models from two places:

- **Ollama's official library** — a curated set of popular models, ready to
  use: `ollama pull gemma3:4b`. This is what the tiers and `glia -m pull`
  draw from.
- **Any GGUF model from Hugging Face** — Ollama pulls community models
  directly, as long as they are in **GGUF** format:

  ```bash
  ollama pull hf.co/<user>/<repo-GGUF>
  # example:
  ollama pull hf.co/bartowski/gemma-2-2b-it-GGUF
  ```

**What is GGUF?** It's the file format used by llama.cpp — the engine under
Ollama — to run models efficiently on CPU and GPU. On Hugging Face the same
model usually exists in two flavours, and only one of them runs here:

- **GGUF** → ready to *run*. Look for repos whose name ends in `-GGUF` (often
  published by users like `bartowski`, `unsloth` or `TheBloke`).
- **safetensors / PyTorch** → the raw weights, meant for *training and
  fine-tuning*, not direct execution. Ollama will **not** load these. (This is
  the job of a tool like Unsloth: it fine-tunes models, it does not serve
  them — so it is not a replacement for Ollama.)

**On a CPU-only machine**, pick a light quantization — **Q4_K_M** is the usual
sweet spot between size, speed and quality. Most GGUF repos offer several quant
levels: the smaller the file, the faster it runs and the lower the quality.

## Roadmap & what's next

GLIA is actively evolving. Planned and in-progress work:

- **Cross-distro testing — help wanted.** The assistant runs on Arch, Debian
  and Fedora, but the automated installer has so far been tested on
  Arch/CachyOS only. **Debian and Fedora need testers** — feedback, issues and
  PRs are very welcome.
- **macOS support — help wanted (contributor-led).** The assistant only, never a
  standalone distro: pure GLIA support for people on a Mac. It needs a Homebrew
  path instead of pacman/apt/dnf, `ollama serve`/launchd instead of systemd, and
  a modern bash. I won't be building this one myself — looking for a contributor
  to own and maintain the macOS port.
- **A shared Ollama.** Point GLIA at the engine on another machine you own —
  the server, or the desktop in the other room — so a thin laptop can drive a
  30B model. The plumbing is one variable; the honesty is the work: every
  RAM check and hardware tier would be measuring the wrong computer, `-m rm`
  on a shared engine deletes a model for everyone, and "nothing leaves your
  machine" would have to become "nothing leaves a machine you own".
- **One console for the AIs.** Roles live in four commands today (`-m`,
  `--web-model`, `--project-model`, `--translate-model`) and each new role
  adds a flag, a help page, completions and two doc entries. One place under
  `-m` to see who holds what and move it — the old flags keep working.
- **Does every command teach?** An audit, not a feature: `show_equiv` shows
  you the command you could have typed yourself, but no one has ever checked
  systematically which actions change your system *without* showing it. A
  project about teaching the terminal can't leave that to chance.
- **Configurable safety.** The dangerous-command list is ours, hardcoded, on
  your machine. Let people add their own — a deploy script, a `terraform
  destroy` — with the same plain-language explanation the built-ins get.
- **The GPU nobody uses.** The plain `ollama` package ships CPU backends only:
  install it with an RTX in the machine and you silently get CPU speed, with a
  10-20x gain sitting idle and nothing ever saying so — `ollama-cuda` /
  `-rocm` / `-vulkan` are add-ons you have to know about. `--doctor` should
  spot it. For weak iGPUs the honest answer is the opposite: measured here,
  Vulkan on an Intel UHD GT1 was **4.5x slower** than the CPU (8.8 → 1.9
  tok/s), so the plan is `glia -m bench` — measure on your machine, don't ship
  a table of guesses.
- **`make check-docs`.** Five hand-kept copies of the same truth (help,
  README, site, completions, the code itself) and none knows about the
  others — so they drift. One command that reads the parser as the source of
  truth and fails when a surface disagrees.
- **Btrfs snapshots** as a safety net, plus branding and polish (phase 5).
- **Lightweight memory retrieval** if the stored facts outgrow the prompt.
- **A terminal-first desktop — the long-term vision.** The most ambitious idea:
  a minimal desktop where the terminal *is* the backdrop, in place of the
  wallpaper every other desktop shows. GUI programs open as windows on top of it
  that you can stash away and bring back at will, driven by a lightweight window
  manager underneath. The shell and the AI together become how you run the
  machine — launch an app, hide it, reopen it, arrange and interact with what's
  on screen, all by talking to GLIA. A graphical desktop grown outward from the
  command line, not bolted on top of it.

Full details and history in [docs/ROADMAP.md](docs/ROADMAP.md).
Contributions are welcome — open an issue or a pull request.

## ☕ Support GLIA

GLIA is free and open source, built in my spare time. If it's useful to you
and you'd like to help, buy me a coffee — you choose the amount. Thank you!

[![Buy me a coffee](https://img.shields.io/badge/%E2%98%95_Buy_me_a_coffee-support_GLIA-2dd4bf?style=for-the-badge)](https://checkout.revolut.com/pay/9b1a8a04-2740-4141-b351-bebb0f3e5b70)

---
*Author: Michele (with Claude) — 2026*
