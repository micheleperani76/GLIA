# GLIA Roadmap

Updated: 2026-07-12

## Assistant intelligence mechanisms

Inspired by how large AI agents work, scaled down to stay lean on a 7B model.

Implemented in mypc v1.5:

1. **Look before acting** — the model receives the current directory and a
   short listing of its contents with every request, so proposed commands
   fit the context instead of being generic.
2. **Learn from errors** — when an executed command fails, its exit code and
   stderr are sent back to the model, which proposes a corrected command
   (max 2 fix rounds, always with the usual confirmation).

Planned, in order of value:

3. **Persistent memory** — `--remember "<fact>"` stores short user facts in
   `~/.config/glia/memory` (capped at ~20 lines to stay lean); facts are
   included in the prompt so the assistant knows your machines, paths, habits.
4. **Conversation context** — a per-terminal session file (last 2-3
   exchanges, ~10 minute expiry) so follow-ups like "now compress it" work.
5. **Danger self-explanation** — before asking to confirm a destructive
   command, a second model call explains in one plain-language sentence what
   the command will do, so the user confirms with understanding.

## Done

1. **mypc assistant** (v1.2) — proposes commands, safety levels (YES for
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

## Next: Calamares installer (phase 4)

- Minimal graphical environment on the live ISO
- calamares package from the CachyOS repo
- Custom **glia-ai** module (QML + Python):
  - assistant name (default `mypc`, applied via `--rename` logic)
  - model choice proposed from `glia-hardware -j`
  - writes `/etc/glia/model` on the target system
  - model download: during install if online, else first-boot service

## TODO

- **mypc v1.3**: show the real aichat/ollama error instead of "empty answer"
  (drop `2>/dev/null`, log stderr); check available RAM in `check_ai`
  before loading the model (7B needs ~6 GB free).
- **glia-hardware**: detect capable AMD/Intel GPUs and consider
  `OLLAMA_VULKAN=1` (experimental; known garbage-output issues on Intel
  iGPUs; weak iGPUs are usually not worth it vs CPU).
- Btrfs snapshots as safety net (phase 5), branding, docs.
