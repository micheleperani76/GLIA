# GLIA — GNU/Linux + IA

**A Linux distribution with a built-in AI terminal assistant.**

*GLIA stands for GNU Linux IA (Intelligenza Artificiale — Italian for AI).*

The philosophy: live your system from the terminal, with AI as your guide.
The assistant (`mypc`, name configurable at install time) turns natural-language
requests into shell commands, with configurable approval levels: dangerous
commands require reinforced confirmation.

## Project status

| Phase | Status |
|---|---|
| 1. `mypc` assistant with safety levels | ✅ working |
| 2. Hardware detection → model recommendation | ✅ `glia-hardware` v1.0 |
| 3. Live ISO (archiso) with AI preinstalled | 🔜 next step |
| 4. Calamares installer with AI setup step | ⏳ |
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

## Quick install (Arch/CachyOS)

```bash
sudo pacman -S ollama aichat
sudo systemctl enable --now ollama
./bin/glia-hardware              # recommends the model for your hardware
ollama pull qwen2.5-coder:7b     # or the recommended one
install -m 755 bin/mypc bin/glia-hardware ~/.local/bin/
mkdir -p ~/.config/aichat && cp config/aichat-config.yaml ~/.config/aichat/config.yaml
```

## Usage

```bash
mypc find the largest files in /home   # proposes the command → Enter runs it
mypc -d what does rsync do             # plain-text explanation only
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
