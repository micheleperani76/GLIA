case "$1" in
    -h|--help)
        show_help_paged
        ;;
    "")
        interactive_mode
        ;;
    -V|--version)
        version_line
        ;;
    --danger)
        shift
        danger_cmd "$@"
        ;;
    --doctor)
        doctor
        ;;
    --channel)
        shift
        set_channel "${1:-}"
        ;;
    -U|--update)
        shift
        case "${1:-}" in
            help|-h|--help)      page update_help ;;
            --check|check)       glia_self_update --check ;;
            engine|ollama)       engine_update ;;            # hidden aliases (old behaviour)
            glia|"$ASSIST_NAME") glia_self_update ;;         # hidden alias (anchor name)
            ""|*)                glia_self_update ;;          # bare = GLIA (Q1), anything else too
        esac
        ;;
    --update-engine)
        engine_update
        ;;
    --rollback)
        glia_rollback
        ;;
    --kaboom)
        kaboom
        ;;
    -p|--project)
        # v2.18: -p EDITS an existing file. The old -p (generate a new project)
        # moved to --new: the two are opposite jobs and must not share a flag.
        shift
        case "${1:-}" in
            help|-h|--help|"") page pmode_help ;;
            --undo|undo)       pmode_undo ;;       # Phase 2 (v2.18)
            *)                 pmode_main "$@" ;;
        esac
        ;;
    -n|--new)
        # v2.18: this is the pre-2.18 -p, behaviour unchanged.
        shift
        case "${1:-}" in
            help|-h|--help|"") page project_help ;;
            *)                 project_mode "$@" ;;
        esac
        ;;
    --rename)
        shift
        rename_assistant "$1"
        ;;
    --lang)
        shift
        set_language "$1"
        ;;
    -m|--model)
        shift
        case "${1:-}" in
            help|-h|--help) page model_help ;;
            "")             model_menu ;;          # guided: list + pick default
            list|ls)        model_menu ;;          # ollama-style aliases (v2.10)
            ps)             ollama ps ;;           # who is in RAM now (v2.11)
            stop)           shift; model_stop "${1:-}" ;;
            pull)           shift
                            if [ -n "${1:-}" ]; then model_pull "$1"; else model_pull_menu; fi ;;
            update)         shift; model_update "${1:-}" ;;
            rm)             shift; model_rm "${1:-}" ;;
            role|roles)     shift; role_cmd "$@" ;;   # D2: see/assign the AI roles
            bench)          shift; bench_cmd "$@" ;;  # D6b: CPU vs iGPU, measured on this machine
            *)
                sel=$(model_resolve "$1") || { echo -e "${RED}$(t model_badsel)${NC}" >&2; exit 1; }
                shift
                if [ -n "$*" ]; then
                    echo -e "${BLUE}$(t model_oneoff) ${GREEN}$sel${NC}"
                    check_ai
                    case "$1" in
                        -w|--web)        shift; WEB_OVERRIDE="$sel"; web_answer "$*" 0 ;;
                        -w+|--web-deep)  shift; WEB_OVERRIDE="$sel"; web_answer "$*" 1 ;;
                        -T|--translate)  shift; TRANS_OVERRIDE="$sel"; translate_file "${1:-}" "${2:-}" ;;
                        *)
                            m_def="${MODEL#ollama:}"
                            swap_in "$sel" "$m_def"     # one-off: free RAM only if needed
                            MODEL="ollama:$sel"          # this request only
                            propose_and_run "$@"
                            swap_out "$sel" "$m_def"     # restore the default afterwards
                            ;;
                    esac
                else
                    set_model "$sel"               # permanent default
                fi ;;
        esac
        ;;
    --remember)
        shift
        remember_fact "$@"
        ;;
    --memory)
        shift
        case "${1:-}" in
            help|-h|--help) page memory_help ;;
            *)              show_memory ;;
        esac
        ;;
    --forget)
        shift
        forget_fact "$1"
        ;;
    --cache-clear|--clear-cache)
        rm -f "$CACHEFILE"
        echo -e "${GREEN}$(t cache_cleared)${NC}"
        show_equiv "rm ${CACHEFILE/#$HOME/\~}"
        ;;
    -a|--alias)
        shift
        case "${1:-}" in
            ""|list|ls)     alias_list ;;
            add)            shift; alias_add "$@" ;;
            save)           shift; alias_save_last "$1" ;;
            rm|remove)      shift; alias_rm "$1" ;;
            edit)           alias_edit ;;
            help|-h|--help) page alias_help ;;
            *)              alias_run "$1" ;;
        esac
        ;;
    -i|--interactive)
        shift
        case "${1:-}" in
            help|-h|--help) page int_help ;;
            *)              interactive_mode ;;
        esac
        ;;
    -c|--chat)
        shift
        case "${1:-}" in
            help|-h|--help) page chat_help ;;
            --fonte|--source|--quelle)
                # one document as the ONLY knowledge base of this session
                # (v2.25): loaded inside chat_mode, after the window probe
                shift
                [ -n "${1:-}" ] || { echo -e "${YELLOW}$(t src_usage)${NC}" >&2; exit 1; }
                CHAT_SOURCE_PENDING="$1"; shift
                chat_mode "$*" ;;
            *)              chat_mode "$*" ;;
        esac
        ;;
    -d|--ask)
        shift
        check_ai
        read_piped
        # session context so follow-ups work in ask mode too (v2.7); the
        # question is stored before exec (the streamed answer can't be)
        MEMCTX="$(memory_context)$(session_context)$(piped_context)"
        # v2.22: --ask knows itself too. Same sheet as the chat (chat_blk_help,
        # i.e. show_help: ONE source of truth), same /contesto switch - turn
        # "help" off there and this mode stops paying for it as well. Only the
        # intro differs: this mode answers once, no dialogue. The separator is
        # added HERE because $(...) eats trailing newlines (the v2.21 lesson).
        ASKSHEET=""
        [ "$(chat_blk_state help)" = "on" ] && ASKSHEET="$(chat_blk_help ask)"
        [ -n "$ASKSHEET" ] && ASKSHEET="${ASKSHEET}"$'\n\n'
        session_add "$*" "(answered in words via -d)"
        case "$UILANG" in
            it) exec aichat --model "$MODEL" "${ASKSHEET}${MEMCTX}Rispondi in italiano. $*$(nothink)" ;;
            de) exec aichat --model "$MODEL" "${ASKSHEET}${MEMCTX}Antworte auf Deutsch. $*$(nothink)" ;;
            *)  exec aichat --model "$MODEL" "${ASKSHEET}${MEMCTX}$*$(nothink)" ;;
        esac
        ;;
    -w|--web)
        shift
        case "${1:-}" in
            help|-h|--help) page web_help ;;
            "")             echo -e "${YELLOW}$(t web_usage)${NC}" >&2; exit 1 ;;
            *)              web_answer "$*" 0 ;;
        esac
        ;;
    -w+|--web-deep)
        shift
        case "${1:-}" in
            help|-h|--help) page web_help ;;
            "")             echo -e "${YELLOW}$(t web_usage)${NC}" >&2; exit 1 ;;
            *)              web_answer "$*" 1 ;;
        esac
        ;;
    -ws|--web-search)
        shift
        case "${1:-}" in
            help|-h|--help) page web_help ;;
            "")             echo -e "${YELLOW}$(t ws_usage)${NC}" >&2; exit 1 ;;
            *)              web_raw "$*" ;;
        esac
        ;;
    --web-engine|--webengine)
        shift
        web_engine_cmd "$@"
        ;;
    -D|--dice)
        # GREEN: no check_ai on purpose - the whole point is that a d20
        # works with ollama stopped, on the server, in a dead shell.
        shift
        case "${1:-}" in
            help|-h|--help) page dice_help ;;
            "")             echo -e "${YELLOW}$(t dice_usage)${NC}" >&2; exit 1 ;;
            *)              dice_cmd "$@" ;;
        esac
        ;;
    -T|--translate)
        shift
        case "${1:-}" in
            help|-h|--help) page translate_help ;;
            "")             echo -e "${YELLOW}$(t tr_usage)${NC}" >&2; exit 1 ;;
            *)              translate_file "$1" "${2:-}" ;;
        esac
        ;;
    --web-model|--webmodel)
        shift
        web_model_cmd "$@"
        ;;
    --translate-model|--translatemodel)
        shift
        translate_model_cmd "$@"
        ;;
    --project-model|--projectmodel|--code-model|--codemodel)
        shift
        project_model_cmd "$@"
        ;;
    -l|--log)
        if [ -f "$LOGFILE" ]; then
            cat "$LOGFILE"
        else
            echo "$(t no_log)"
        fi
        ;;
    -?*)
        # An unrecognized flag is a TYPO, not a sentence (v2.24). A normal
        # terminal program says "unknown option"; handing "-ask comando -c"
        # to the model got back an invented echo with a confident voice -
        # the design pillar (standard conventions) violated by the fallback
        # itself. Natural language does not start with a dash; a typo does.
        case "$1" in
            -[a-zA-Z][a-zA-Z]*)
                echo -e "${YELLOW}$(t flag_unknown) $1 · $(t flag_dashes) --${1#-}) $(t flag_list)${NC}" >&2 ;;
            *)  echo -e "${YELLOW}$(t flag_unknown) $1 $(t flag_list)${NC}" >&2 ;;
        esac
        exit 2
        ;;
    *)
        check_ai
        read_piped
        propose_and_run "$@"
        ;;
esac
