# GLIA — GNU/Linux + IA

**A Linux distribution with a built-in AI terminal assistant.**

*GLIA stands for GNU Linux IA (Intelligenza Artificiale — Italian for AI).*

## Philosophy

**GLIA is not a chatbot that uses your PC for you — it's a bridge that brings you to the terminal.**

Most AI assistants turn the computer into a black box: you ask, something happens, you learn nothing. GLIA does the opposite. The goal is to get more people to open the terminal and actually use it, with AI sitting next to them as a guide.

Every request in natural language becomes a real shell command, shown to you *before* it runs. You read it, you approve it, you run it — and little by little you learn it. The AI doesn't replace the terminal: it teaches you to master it.

- **Transparency**: you always see the command, never just the result.
- **Learning by doing**: each interaction is a small terminal lesson.
- **Safety**: dangerous commands (rm -rf, dd, mkfs, ...) require reinforced confirmation.
- **You stay in control**: the AI proposes, you decide.

The assistant (`mypc`, name configurable at install time) turns natural-language
requests into shell commands, with configurable approval levels.

## Project status

| Phase | Status |
|---|---|
| 1. `mypc` assistant with safety levels | ✅ working |
| 2. Hardware detection → model recommendation | ✅ `glia-hardware` v1.0 |
| 3. Live ISO (archiso) with AI preinstalled | ✅ 5.8 GB ISO, model embedded, tested in QEMU |
| 4. Calamares installer with AI setup step | 🧪 working, final test in progress |
| 5. Btrfs snapshots, branding, polish | ⏳ |

## Components

- **`bin/mypc`** — AI terminal assistant (Ollama + aichat).
  Proposes a command → Enter runs it, `n` cancels, `r` retries.
  Destructive commands (rm -rf, dd, mkfs, sudo, curl|sh, ...) require
  typing `YES`. Everything is logged to `~/.local/share/mypc/mypc.log`.
- **`bin/glia-hardware`** — detects RAM/GPU/VRAM and recommends the right
  AI model tier. JSON output (`-j`) designed for the installer.
- **`config/aichat-config.yaml`** — aichat configuration for local Ollama
  (target: `~/.config/aichat/config.yaml`).

## Install GLIA — three ways

1. **Full install on a real PC** — build the ISO (step 1), write it to a
   USB stick and install (way 1).
2. **Try it in a virtual machine** — build the ISO (step 1), boot it in
   QEMU (way 2).
3. **Only the assistant** — add `mypc` to the Linux you already use
   (way 3, no ISO needed).

There are no prebuilt ISO downloads: the ISO is always built fresh from
this repo.

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

`mypc` is a bash script: it only needs `ollama` and `aichat`.

On Arch/CachyOS:

```bash
sudo pacman -S ollama aichat
sudo systemctl enable --now ollama
./bin/glia-hardware              # recommends the model for your hardware
ollama pull qwen2.5-coder:7b     # or the recommended one
install -m 755 bin/mypc bin/glia-hardware ~/.local/bin/
mkdir -p ~/.config/aichat && cp config/aichat-config.yaml ~/.config/aichat/config.yaml
```

On Debian, Fedora and other distros:

```bash
curl -fsSL https://ollama.com/install.sh | sh    # official Ollama installer
                                                 # (yes, mypc would ask you to type YES for a curl|sh — read scripts before running them!)
# aichat: grab the binary for your arch from https://github.com/sigoden/aichat/releases
# and put it in ~/.local/bin/

git clone https://github.com/micheleperani76/GLIA glia && cd glia
./bin/glia-hardware              # recommends the model for your hardware
ollama pull qwen2.5-coder:7b     # or the recommended one
install -m 755 bin/mypc bin/glia-hardware ~/.local/bin/
mkdir -p ~/.config/aichat && cp config/aichat-config.yaml ~/.config/aichat/config.yaml
```

## Usage

```bash
mypc find the largest files in /home   # proposes the command → Enter runs it
mypc -d what does rsync do             # plain-text explanation only
mypc -p a bash backup script with rsync and a README explaining how to use it   # project mode: plans the steps, then writes the files (with confirmation)
mypc -l                                # log of executed commands
glia-hardware                           # hardware report and recommended models
```

## Model tiers by hardware

| Tier | Hardware | Models |
|---|---|---|
| 1 | <16 GB RAM, no GPU | qwen3:4b, gemma3:4b, llama3.2:3b |
| 2 | ≥16 GB RAM, no GPU | qwen2.5-coder:7b, qwen3:8b, mistral:7b |
| 3 | GPU ≥12 GB VRAM | qwen2.5-coder:14b, phi4:14b, deepseek-r1:14b |
| 4 | GPU ≥20 GB VRAM | qwen3-coder:30b, qwen2.5-coder:32b, devstral:24b |

---
*Author: Michele (with Claude) — 2026*
