# ai-proxy: a local, OpenAI/Anthropic/Gemini-compatible AI endpoint
# (CLIProxyAPI's release binary, pinned by checksum: cliproxyapi.nix) in front
# of OpenRouter, serving its free models by default, plus any subscriptions
# signed in with scripts/ai-login. Loopback only; clients authenticate with a
# key. darwin/ai-proxy.nix runs it on mini; it was tinytrader's nix/ai-proxy.nix.
#
# Configuration comes from the environment (each secret also as NAME_FILE):
#   OPENROUTER_API_KEY  the OpenRouter key (required)
#   AI_PROXY_KEY        the key clients send (required)
#   AI_PROXY_MODELS     "free" (default: OpenRouter's current :free models,
#                       read at each start) or a comma-separated list of
#                       OpenRouter model ids
#   AI_PROXY_POOL_EXCLUDE  models left out of the "free-pool" alias (an
#                       extended regex; default: classifiers and tiny models)
#   AI_PROXY_HOST       default 127.0.0.1;  AI_PROXY_PORT  default 8317
#   AI_PROXY_STATE      default $XDG_STATE_HOME/ai-proxy (holds the rendered
#                       config, mode 600, and CLIProxyAPI's auth folder)
# Two routed aliases: "free" is OpenRouter's own router over the free models
# available at the time (openrouter/free); "free-pool" is a pool of the
# served models, round-robin, moving on to the next model in the same request
# when one fails or is rate-limited before answering.
# CLIProxyAPI reads keys only from its config file, so the file is written at
# each start into the private state folder and never anywhere else.
{
  writeShellApplication,
  cliproxyapi,
  curl,
  jq,
  coreutils,
  gnugrep,
}:
writeShellApplication {
  name = "ai-proxy";
  runtimeInputs = [ cliproxyapi curl jq coreutils gnugrep ];
  text = ''
    secret() { # NAME: the value of NAME, or of the file named by NAME_FILE
      local v="''${!1:-}" f="''${1}_FILE"
      if [ -z "$v" ] && [ -n "''${!f:-}" ]; then v="$(tr -d '\n' < "''${!f}")"; fi
      [ -n "$v" ] || { echo "ai-proxy: set $1 or $1_FILE" >&2; exit 2; }
      printf '%s' "$v"
    }
    openrouter="$(secret OPENROUTER_API_KEY)"
    client="$(secret AI_PROXY_KEY)"
    port="''${AI_PROXY_PORT:-8317}"
    host="''${AI_PROXY_HOST:-127.0.0.1}"
    state="''${AI_PROXY_STATE:-''${XDG_STATE_HOME:-$HOME/.local/state}/ai-proxy}"
    mkdir -p "$state/auth"
    chmod 700 "$state"

    if [ "''${AI_PROXY_MODELS:-free}" = free ]; then
      models="$(curl -fsS --max-time 30 https://openrouter.ai/api/v1/models \
        | jq -r '.data[].id | select(endswith(":free"))')"
    else
      models="$(tr ',' '\n' <<<"$AI_PROXY_MODELS")"
    fi
    [ -n "$models" ] || { echo "ai-proxy: no models to serve" >&2; exit 1; }

    config="$state/config.yaml"
    umask 077
    {
      printf 'host: "%s"\nport: %s\n' "$host" "$port"
      printf 'remote-management:\n  allow-remote: false\n  secret-key: ""\n  disable-control-panel: true\n'
      printf 'auth-dir: "%s"\n' "$state/auth"
      printf 'api-keys:\n  - %s\n' "$(jq -Rn --arg k "$client" '$k')"
      printf 'openai-compatibility:\n  - name: "openrouter"\n    base-url: "https://openrouter.ai/api/v1"\n'
      printf '    api-key-entries:\n      - api-key: %s\n    models:\n' "$(jq -Rn --arg k "$openrouter" '$k')"
      while read -r m; do
        [ -n "$m" ] && printf '      - name: %s\n        alias: %s\n' "$(jq -Rn --arg m "$m" '$m')" "$(jq -Rn --arg m "''${m%:free}" '$m')"
      done <<<"$models"
      printf '      - name: "openrouter/free"\n        alias: "free"\n'
      exclude="''${AI_PROXY_POOL_EXCLUDE:-content-safety|lfm-}"
      while read -r m; do
        [ -n "$m" ] && ! grep -qE "$exclude" <<<"$m" && printf '      - name: %s\n        alias: "free-pool"\n' "$(jq -Rn --arg m "$m" '$m')"
      done <<<"$models"
    } > "$config.tmp"
    mv "$config.tmp" "$config"
    echo "ai-proxy: serving $(grep -c '^      - name:' "$config") OpenRouter models on http://$host:$port/v1" >&2
    exec cliproxyapi -config "$config"
  '';
}
