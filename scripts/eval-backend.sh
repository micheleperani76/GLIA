#!/usr/bin/env bash
# eval-backend.sh - CPU vs GPU on THIS machine, measured not guessed.
# Prototype for the future "glia -m bench" (see docs/ROADMAP.md, D6).
# 2026-07-17 on a UHD GT1: CPU 8.8 tok/s vs Vulkan iGPU 1.94 tok/s.
# Misura la velocita' MA stampa anche l'output: su iGPU Intel il rischio
# noto non e' la lentezza, e' la spazzatura (issue ollama#13086).
set -u
MODEL="${1:-qwen2.5-coder:7b}"
LABEL="${2:-run}"
RUNS=3
OUT="/tmp/bench-$LABEL.txt"
: > "$OUT"

PROMPT='Write a bash one-liner that finds the 5 largest files in /home. Answer with the command only.'

{
echo "=== $LABEL | modello: $MODEL | $(date '+%T')"
echo "--- pacchetto ollama installato:"
pacman -Q 2>/dev/null | grep -iE '^ollama' | sed 's/^/    /'
echo "--- backend ggml disponibili:"
ls /usr/lib/ollama/ 2>/dev/null | grep -oE 'libggml-(cpu|vulkan|cuda|hip)[^.]*' | sed 's/libggml-//' | cut -d- -f1 | sort -u | tr '\n' ' ' | sed 's/^/    /'; echo
echo "--- device di inferenza visti da ollama:"
journalctl -u ollama --no-pager 2>/dev/null | grep 'inference compute' | tail -2 | grep -oE 'id=[^ ]+ library=[^ ]+.*(total|available)="[^"]*"' | sed 's/^/    /'
} | tee -a "$OUT"

# scalda: il primo caricamento paga il disco, non il backend
curl -s http://127.0.0.1:11434/api/generate -d "{\"model\":\"$MODEL\",\"prompt\":\"hi\",\"stream\":false,\"options\":{\"num_predict\":1}}" >/dev/null 2>&1

echo "--- chi calcola ORA (PROCESSOR):" | tee -a "$OUT"
ollama ps 2>/dev/null | tee -a "$OUT"

for i in $(seq 1 $RUNS); do
    python3 - "$MODEL" "$PROMPT" "$i" <<'PY' | tee -a "$OUT"
import json, sys, urllib.request
model, prompt, i = sys.argv[1], sys.argv[2], sys.argv[3]
body = json.dumps({"model": model, "prompt": prompt, "stream": False,
                   "options": {"seed": 42, "temperature": 0, "num_predict": 60}}).encode()
req = urllib.request.Request("http://127.0.0.1:11434/api/generate", body,
                             {"Content-Type": "application/json"})
d = json.load(urllib.request.urlopen(req, timeout=600))
ec, ed = d.get("eval_count", 0), d.get("eval_duration", 1)
pc, pd = d.get("prompt_eval_count", 0), d.get("prompt_eval_duration", 1)
print(f"  run {i}: generazione {ec/(ed/1e9):6.2f} tok/s   prefill {pc/(pd/1e9):7.2f} tok/s   ({ec} tok in {ed/1e9:.1f}s)")
if i == "1":
    print("  --- output run 1 (deve avere SENSO, non solo essere veloce):")
    for line in d.get("response", "").strip().split("\n")[:5]:
        print("      " + line)
PY
done

echo "--- log: dove sono finiti i pesi:" | tee -a "$OUT"
journalctl -u ollama --no-pager 2>/dev/null | grep -iE 'load_tensors:.*model buffer size|offloaded .* layers' | tail -3 | sed 's/^.*ollama\[[0-9]*\]: //' | sed 's/^/    /' | tee -a "$OUT"
echo | tee -a "$OUT"
