# sessions-deliver SESSION: one message line (JSON, from sessions send) on
# stdin, into that Claude Code session's inbox socket on this Mac. SESSION is
# its name, session ID or pid (claude agents). Claude Code labels it a message
# from another session and runs it through that session's inbound controls.
target="${1:?usage: sessions-deliver SESSION}"
line="$(head -n 1)"
agents="$(claude agents --json)"
mapfile -t pids < <(jq -r --arg t "$target" \
  '.[] | select(.name == $t or .sessionId == $t or (.pid | tostring) == $t) | .pid' <<<"$agents")
host="$(hostname -s)"
if [ "${#pids[@]}" -eq 0 ]; then
  echo "sessions-deliver: no session $target on $host; these are: $(jq -r '[.[].name] | join(", ")' <<<"$agents")" >&2
  exit 1
fi
if [ "${#pids[@]}" -gt 1 ]; then
  echo "sessions-deliver: ${#pids[@]} sessions are called $target on $host; name one by pid: ${pids[*]}" >&2
  exit 2
fi
pid="${pids[0]}"
sock=""
for d in /tmp/cc-socks "/tmp/cc-socks-$(id -u)"; do
  if [ -S "$d/$pid.sock" ] && [ ! -L "$d/$pid.sock" ]; then sock="$d/$pid.sock"; break; fi
done
[ -n "$sock" ] || { echo "sessions-deliver: session $target (pid $pid) on $host has no inbox socket" >&2; exit 1; }
printf '%s\n' "$line" | nc -U -w 2 "$sock"
echo "delivered to $target (pid $pid) on $host"
