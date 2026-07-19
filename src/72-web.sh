# ============================================================
#  Web search (v2.13): DuckDuckGo via w3m -> summary with sources
# ============================================================
web_urlenc() { printf '%s' "${*// /+}"; }

web_deps_ok() {
    command -v w3m >/dev/null 2>&1 && return 0
    echo -e "${YELLOW}$(t web_now3m)${NC}" >&2
    show_equiv "$(pkg_install_cmd w3m)" >&2
    return 1
}

# --- engine selection (v2.18): ddg | bing | searx -------------------
# One-off choice comes from the "engine:" prefix ("-w bing: query"), the
# persistent one from --web-engine; anything else falls back to the default.
web_engine() {
    local e="${WEB_ENGINE_ONEOFF:-}"
    [ -z "$e" ] && [ -s "$WEBENGINEFILE" ] && e="$(head -n1 "$WEBENGINEFILE")"
    case "$e" in ddg|bing|searx) ;; *) e="$WEB_ENGINE_DEFAULT" ;; esac
    printf '%s' "$e"
}

# web_engine_url <engine> <urlencoded query> -> full search URL.
# Fails (return 1) only for searx without a configured instance.
web_engine_url() {
    local u
    case "$1" in
        bing)  printf '%s%s' "$WEB_URL_BING" "$2" ;;
        searx) u="$(head -n1 "$SEARXURLFILE" 2>/dev/null)"
               [ -n "$u" ] || return 1
               printf '%s/search?q=%s' "${u%/}" "$2" ;;
        *)     printf '%s%s&kl=%s' "$WEB_URL" "$2" "$WEB_REGION" ;;
    esac
}

# Parsers: one per engine, each written against a REAL w3m dump of that
# engine (2026-07-16), not guessed. All emit: URL <TAB> TITLE <TAB> SNIPPET.

# ddg lite layout:  "N.  title" line, then URL text below.
web_parse_ddg() {
    awk -v n="$WEB_RESULTS" '
        function emit(){ if(title!="" && c<n){ c++; printf "https://%s\t%s\t%s\n", url, title, snip } }
        /^ *[0-9]+\.  / { emit(); line=$0; sub(/^ *[0-9]+\.  */,"",line); title=line; url=""; snip=""; next }
        { if(title=="") next; t=$0; gsub(/^[ \t]+|[ \t]+$/,"",t); if(t=="") next;
          if(url!=""){ snip=snip (snip==""?"":" ") url } url=t }
        END{ emit() }
    '
}

# bing layout: " N." alone, then domain, then a breadcrumb URL
# ("https://host › seg › seg..."), blank, title, blank, snippet.
# The breadcrumb is rebuilt into a URL; a truncated last segment is dropped
# (better a valid parent page than a broken link).
web_parse_bing() {
    awk -v n="$WEB_RESULTS" '
        function fixurl(u){ gsub(/ › /,"/",u); if (u ~ /(\.\.\.|…)$/) sub(/\/[^\/]*$/,"",u); return u }
        function emit(){ if(url!="" && title!="" && c<n){ c++; printf "%s\t%s\t%s\n", url, title, snip } }
        /^ *[0-9]+\.[ \t]*$/ { emit(); st=1; url=""; title=""; snip=""; next }
        st==0 { next }
        { t=$0; gsub(/^[ \t]+|[ \t]+$/,"",t); if(t=="") next }
        st==1 { st=2; next }
        st==2 { if (t ~ /^https?:\/\//) { url=fixurl(t); st=3 } else st=0; next }
        st==3 { title=t; st=4; next }
        st==4 { snip=t; st=0; next }
        END{ emit() }
    '
}

# SearXNG (simple theme) layout: breadcrumb URL line, blank, title, blank,
# snippet, then a line naming the upstream engines. The instance echoes the
# search URL itself once ("/search?q=..."): that line is skipped.
web_parse_searx() {
    awk -v n="$WEB_RESULTS" '
        function fixurl(u){ gsub(/ › /,"/",u); if (u ~ /(\.\.\.|…)$/) sub(/\/[^\/]*$/,"",u); return u }
        function emit(){ if(url!="" && title!="" && c<n){ c++; printf "%s\t%s\t%s\n", url, title, snip } }
        { t=$0; gsub(/^[ \t]+|[ \t]+$/,"",t) }
        t ~ /\/search\?q=/ { next }
        t ~ /^https?:\/\// { emit(); url=fixurl(t); title=""; snip=""; st=1; next }
        st==0 || t=="" { next }
        st==1 { title=t; st=2; next }
        st==2 { snip=t; st=0; next }
        END{ emit() }
    '
}

# web_search <query> -> lines:  URL <TAB> TITLE <TAB> SNIPPET
web_search() {
    local eng q url
    eng="$(web_engine)"; q="$(web_urlenc "$*")"
    url="$(web_engine_url "$eng" "$q")" || { echo -e "${RED}$(t web_searx_nourl)${NC}" >&2; return 1; }
    w3m -dump -cols "$WEB_COLS" "$url" 2>/dev/null | "web_parse_$eng"
}

# web_fetch <url> -> clean readable text, capped at WEB_MAXCHARS
web_fetch() { w3m -dump "$1" 2>/dev/null | sed '/^[[:space:]]*$/d' | head -c "$WEB_MAXCHARS"; }

# build_web_context <query> <pages_to_read_in_full>
build_web_context() {
    local q="$1" pages="${2:-0}" i=0 url title snip page ctx=""
    while IFS=$'\t' read -r url title snip; do
        [ -z "$url" ] && continue
        i=$((i+1))
        ctx+="[$i] $title"$'\n'"URL: $url"$'\n'"$(t web_extract): $snip"$'\n'
        if [ "$i" -le "$pages" ]; then
            page="$(web_fetch "$url")"
            [ -n "$page" ] && ctx+="$(t web_page): $page"$'\n'
        fi
        ctx+=$'\n'
    done < <(web_search "$q")
    printf '%s' "$ctx"
}

# streaming filter (python stdlib): prints tokens as they arrive and drops
# any <think>...</think> block (reasoning models) even when split across chunks
WEB_STREAM_PY='
import sys,json
skip=False
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try: d=json.loads(line)
    except Exception: continue
    c=d.get("message",{}).get("content","")
    while c:
        if not skip:
            i=c.find("<think>")
            if i<0: sys.stdout.write(c); c=""
            else: sys.stdout.write(c[:i]); c=c[i+7:]; skip=True
        else:
            j=c.find("</think>")
            if j<0: c=""
            else: c=c[j+8:]; skip=False
    sys.stdout.flush()
    if d.get("done"): break
sys.stdout.write("\n")
'

