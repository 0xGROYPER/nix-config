# sessions                               every Mac's Claude Code sessions and ai-proxy
# sessions --json                        the same as one JSON array, a Mac per entry:
#                                        {host, here, reachable, agents, proxy, providers}
# sessions send [--from NAME] HOST SESSION TEXT
#                                        a message to SESSION (its name, session ID
#                                        or pid) on HOST, over ssh; TEXT - reads stdin.
#                                        It arrives as a message from another session,
#                                        never as typed input, with how to reply.
# HOST is an ssh name (ssh/config) or user@host. SESSIONS_HOSTS lists the Macs.
hosts="${SESSIONS_HOSTS:?SESSIONS_HOSTS: the Macs, by ssh name}"

# Run a login-shell command on HOST: here when HOST is this Mac (it needn't
# accept ssh from itself; told by HOST's address being one of this Mac's),
# else over ssh.
here() {
  local name ip
  name="$(ssh -G "$1" 2>/dev/null | awk '$1 == "hostname" { print $2 }' || true)"
  ip="$(dscacheutil -q host -a name "$name" 2>/dev/null | awk '/^ip_address/ { print $2; exit }' || true)"
  [ -n "$ip" ] && ifconfig 2>/dev/null | awk '$1 == "inet" { print $2 }' | grep -qxF "$ip"
}
on() {
  local h="$1" cmd="$2"
  if here "$h"; then
    zsh -lc "$cmd"
  else
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$h" "zsh -lc $(printf '%q' "$cmd")"
  fi
}

# Each Mac's sessions-here, as {host, here, reachable, ...}, one JSON per line.
each() {
  local h out here_now=false
  for h in $hosts; do
    if here "$h"; then here_now=true; else here_now=false; fi
    if out="$(on "$h" sessions-here 2>/dev/null)" && jq -e . >/dev/null 2>&1 <<<"$out"; then
      jq -c --arg h "$h" --argjson here "$here_now" '{host: $h, here: $here, reachable: true} + .' <<<"$out"
    else
      jq -cn --arg h "$h" --argjson here "$here_now" '{host: $h, here: $here, reachable: false, agents: [], proxy: "unknown", providers: ""}'
    fi
  done
}

list() {
  each | jq -r '
    if .reachable | not then "\(.host): unreachable, or sessions-here is not installed there yet"
    else
      "\(.host):",
      (.agents[] | "  claude  \(.name)  \(.status)  \(.kind)  \(.cwd | sub("^/Users/[^/]+"; "~"))"),
      "  ai-proxy \(.proxy)\(if .providers != "" then " (\(.providers))" else "" end)"
    end'
}

send() {
  from=""
  if [ "${1:-}" = --from ]; then from="$2"; shift 2; fi
  [ $# -ge 3 ] || { echo "usage: sessions send [--from NAME] HOST SESSION TEXT|-" >&2; exit 2; }
  host="$1" target="$2"; shift 2
  if [ "$*" = - ]; then text="$(cat)"; else text="$*"; fi
  [ -n "$text" ] || { echo "sessions send: nothing to send" >&2; exit 2; }
  # Where a reply comes back: this Mac by its name in SESSIONS_HOSTS.
  me=""
  for h in $hosts; do here "$h" && { me="$h"; break; }; done
  [ -n "$me" ] || me="$(id -un)@$(hostname -s)"
  who="${from:-a shell}"
  reply="To reply: sessions send $me ${from:-<the sender>} TEXT"
  line="$(jq -cn --arg c "$text"$'\n\n'"(Sent by $who on $me with sessions send. $reply)" \
    '{type: "user", message: {role: "user", content: $c}}')"
  printf '%s\n' "$line" | on "$host" "sessions-deliver $(printf '%q' "$target")"
}

case "${1:-}" in
  "") list ;;
  --json) each | jq -s . ;;
  send) shift; send "$@" ;;
  *) echo "usage: sessions [--json] | sessions send [--from NAME] HOST SESSION TEXT|-" >&2; exit 2 ;;
esac
