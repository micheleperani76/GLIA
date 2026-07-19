# ================= -m bench (D6b, 2026-07-17) =================
# The doctor half (D6a, v2.18.6) only ever mentions the iGPU. This is the
# other half: measure CPU vs iGPU FOR REAL on this machine and print a
# verdict, instead of asking the user to edit a systemd override by hand
# and read two numbers themselves. v1 covers only the case we have a
# verified lever for: Intel iGPU + OLLAMA_IGPU_ENABLE=1. NVIDIA/AMD refuse
# with a clear message - the equivalent CPU-only lever for a dedicated GPU
# is not verified on real hardware yet (see docs/ROADMAP.md, D6).

bench_wait_ready() {
    local i=0
    while [ "$i" -lt "$BENCH_RESTART_WAIT" ]; do
        curl -fsS --max-time 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1 && return 0
        sleep 1; i=$((i+1))
    done
    return 1
}

bench_measure() {
    # BENCH_RUNS generations of the same fixed prompt, average tok/s.
    local i total=0 count=0 tps ec ed json mname
    mname="${MODEL#ollama:}"
    for i in $(seq 1 "$BENCH_RUNS"); do
        json=$(curl -fsS --max-time "$BENCH_TIMEOUT" "$OLLAMA_URL/api/generate" \
            -d "$(jq -n --arg m "$mname" --arg p "$BENCH_PROMPT" \
                  '{model:$m, prompt:$p, stream:false, options:{seed:42, temperature:0, num_predict:60}}')" \
            2>/dev/null)
        [ -n "$json" ] || continue
        ec=$(jq -r '.eval_count // 0'    <<< "$json" 2>/dev/null)
        ed=$(jq -r '.eval_duration // 0' <<< "$json" 2>/dev/null)
        case "$ec" in ''|*[!0-9]*) continue ;; esac
        case "$ed" in ''|*[!0-9]*) continue ;; esac
        [ "$ec" -gt 0 ] && [ "$ed" -gt 0 ] || continue
        tps=$(awk -v e="$ec" -v d="$ed" 'BEGIN{printf "%.2f", e/(d/1e9)}')
        total=$(awk -v t="$total" -v x="$tps" 'BEGIN{printf "%.4f", t+x}')
        count=$((count+1))
    done
    [ "$count" -eq 0 ] && return 1
    awk -v t="$total" -v c="$count" 'BEGIN{printf "%.2f", t/c}'
}

bench_verdict() {
    local cpu="$1" gpu="$2" pct
    echo
    echo -e "${BLUE}$(t bench_result_cpu)${NC} ${cpu} tok/s"
    echo -e "${BLUE}$(t bench_result_gpu)${NC} ${gpu} tok/s"
    pct=$(awk -v c="$cpu" -v g="$gpu" 'BEGIN{ if (c<=0) print 0; else printf "%.0f", (g-c)/c*100 }')
    if awk -v g="$gpu" -v c="$cpu" -v m="$BENCH_VERDICT_MARGIN" 'BEGIN{ exit !(c>0 && (g-c)/c*100 > m) }'; then
        echo -e "${GREEN}$(t bench_verdict_gpu) (+${pct}%)${NC}"
        echo -e "  $(t bench_verdict_gpu_how)"
    else
        echo -e "${YELLOW}$(t bench_verdict_cpu) (${pct}%)${NC}"
    fi
}

bench_cmd() {
    local dry=0
    case "${1:-}" in --dry-run|-n) dry=1; shift ;; esac

    gpu_backend_probe
    case "$BP_GTYPE" in
        none)
            echo -e "${YELLOW}$(t bench_nogpu)${NC}"
            return 1 ;;
        nvidia|amd)
            echo -e "${YELLOW}$(t bench_unsupported) ($BP_GNAME)${NC}"
            return 1 ;;
        intel)
            if [ "$BP_VULKAN" -ne 1 ]; then
                echo -e "${YELLOW}$(t bench_novulkan) $BP_GNAME${NC}"
                echo -e "  $(gpu_backend_pkg_hint vulkan)"
                return 1
            fi
            ;;
    esac

    command -v jq >/dev/null 2>&1 || { echo -e "${RED}$(t bench_needjq) $(pkg_install_cmd jq)${NC}" >&2; return 1; }

    local other
    other=$(find "$BENCH_OVERRIDE_DIR" -maxdepth 1 -name '*.conf' ! -name "$(basename "$BENCH_OVERRIDE_FILE")" 2>/dev/null)
    if [ -n "$other" ] && grep -ql 'OLLAMA_IGPU_ENABLE' $other 2>/dev/null; then
        echo -e "${YELLOW}$(t bench_other_override)${NC}"
        return 1
    fi

    local mname
    mname="${MODEL#ollama:}"
    case "$mname" in *:*) : ;; *) mname="$mname:latest" ;; esac
    if ! curl -fsS --max-time 5 "$OLLAMA_URL/api/tags" 2>/dev/null | grep -q "\"$mname\""; then
        echo -e "${RED}$(t doc_model)${NC}" >&2
        return 1
    fi

    echo -e "${BLUE}$(t bench_intro) $BP_GNAME${NC}"
    show_equiv "sudo mkdir -p $BENCH_OVERRIDE_DIR && printf '[Service]\nEnvironment=OLLAMA_IGPU_ENABLE=1\n' | sudo tee $BENCH_OVERRIDE_FILE"
    show_equiv "sudo systemctl daemon-reload && sudo systemctl restart ollama"
    show_equiv "$(t bench_equiv_measure)"
    show_equiv "sudo rm -f $BENCH_OVERRIDE_FILE && sudo systemctl daemon-reload && sudo systemctl restart ollama"

    if [ "$dry" -eq 1 ]; then
        echo -e "${YELLOW}$(t bench_dryrun_note)${NC}"
        return 0
    fi

    core_confirm "$(t bench_confirm)" || { echo "$(t cancelled)"; return 0; }
    sudo -v || { echo -e "${RED}$(t bench_nosudo)${NC}" >&2; return 1; }

    _bench_restore_now() {
        sudo rm -f "$BENCH_OVERRIDE_FILE" 2>/dev/null
        sudo systemctl daemon-reload 2>/dev/null
        sudo systemctl restart ollama 2>/dev/null
        bench_wait_ready
    }
    trap _bench_restore_now EXIT INT TERM

    echo -e "${BLUE}$(t bench_running_cpu)${NC}"
    sudo mkdir -p "$BENCH_OVERRIDE_DIR"
    sudo rm -f "$BENCH_OVERRIDE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    if ! bench_wait_ready; then
        echo -e "${RED}$(t bench_notready)${NC}" >&2
        return 1
    fi
    local cpu_tps
    cpu_tps=$(bench_measure) || { echo -e "${RED}$(t bench_measure_fail)${NC}" >&2; return 1; }

    echo -e "${BLUE}$(t bench_running_gpu)${NC}"
    printf '[Service]\nEnvironment=OLLAMA_IGPU_ENABLE=1\n' | sudo tee "$BENCH_OVERRIDE_FILE" >/dev/null
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    if ! bench_wait_ready; then
        echo -e "${RED}$(t bench_notready)${NC}" >&2
        return 1
    fi
    local gpu_tps
    gpu_tps=$(bench_measure) || { echo -e "${RED}$(t bench_measure_fail)${NC}" >&2; return 1; }

    trap - EXIT INT TERM
    _bench_restore_now

    bench_verdict "$cpu_tps" "$gpu_tps"
    # You just measured this machine, so tell it the other thing it can now
    # answer: how much conversation it holds. Reported, not owned - the probe
    # is a function everyone calls (-c uses it at every start, --doctor shows
    # it). Nobody has to survive `-m bench` to get a right-sized window: this
    # command already refused every machine without an Intel iGPU 60 lines ago.
    chat_ctx_probe "${MODEL#ollama:}"
    echo -e "${BLUE}$(t bench_ctx)${NC} $(chat_ctx_line)"
    write_log "model bench" "$BP_GNAME cpu=${cpu_tps}tok/s gpu=${gpu_tps}tok/s ctx=${CHAT_CTX}(${CHAT_CTX_WHY})"
}
