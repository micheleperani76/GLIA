# --------------------- MAIN ------------------------
# Once a custom name exists, 'glia' itself becomes only the recovery command:
# it may run just -h / --help (or no args). Any real request points back to the
# chosen name, so there are never two active names doing actual work.
if [ "$PROG" = "glia" ] && [ "$ASSIST_NAME" != "glia" ]; then
    case "${1:-}" in
        -h|--help|-V|--version) : ;;
        "")  show_help_paged; exit 0 ;;
        *) echo -e "${YELLOW}$(t glia_inhibited)${NC}" >&2; exit 1 ;;
    esac
fi

