# GLIA Roadmap

Updated: 2026-07-12

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

## TODO

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
- **glia-hardware**: detect capable AMD/Intel GPUs and consider
  `OLLAMA_VULKAN=1` (experimental; known garbage-output issues on Intel
  iGPUs; weak iGPUs are usually not worth it vs CPU).
- Btrfs snapshots as safety net (phase 5), branding, docs.
- **Branding**: naming is "GLIA — GNU/Linux + AI" (AI in English) everywhere;
  texts updated 2026-07-12, the Calamares logo.png still says "IA" and must
  be regenerated.
