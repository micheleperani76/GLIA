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
  Web search with sources: `glia -w <question>` queries DuckDuckGo through
  the w3m text browser (no API key) and the local model summarizes with a
  **Sources** list. Pick the AI per job: `glia -m` sets the default and shows
  role tags (default / web / project) next to each model, while
  `glia --web-model` and `glia --project-model` pin a dedicated AI for web
  search and for project mode (`glia -p`). Only one model stays resident in
  RAM: GLIA swaps it out and back for a one-off task — showing which AI it
  loads — and if you stop the default yourself it is left off. Standard flags
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
                                                 # (yes, glia would ask you to type YES for a curl|sh — read scripts before running them!)
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
glia -d what does rsync do             # plain-text explanation only
cat error.log | glia why does it fail  # piped input becomes context for the AI
glia -p a bash backup script with rsync and a README explaining how to use it   # project mode: plans the steps, then writes the files (with confirmation)
glia -l                                # log of executed commands
glia --doctor                          # one-shot health check (engine, model, RAM, config)
glia -m pull                           # guided download: hardware check + the AI models that FIT this machine
glia -m update                         # refresh the downloaded models (only fetches new versions)
glia -m ps                             # which model is loaded in RAM right now (= ollama ps)
glia -m stop <n|name>                  # unload a model from RAM immediately (= ollama stop)
glia --update                          # update the Ollama engine itself (glia --update help: full guide)
glia --update glia                     # update GLIA itself: pulls the latest version from GitHub, asks before replacing
glia --kaboom                          # guided uninstall (level 1: program only · level 2: everything) — asks you to type YES
glia-hardware                           # hardware report and recommended models
```

At every proposed command you can also press `m` to edit it in place before
running, or `e` to have the AI explain what it does. Bash tab-completion is in
`completions/glia.bash` (source it from `~/.bashrc`).

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
