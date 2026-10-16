# The local AI endpoint (pkgs/ai-proxy.nix: CLIProxyAPI in front of
# OpenRouter, plus any subscriptions signed in with scripts/ai-login), as a
# boot-time daemon run as you, on http://127.0.0.1:8317/v1. Clients send the
# key scripts/ai-client-key prints.
#
# - State: ~/.local/state/ai-proxy (mode 700): the config it renders at each
#   start (mode 600, with the keys in it) and auth/, the OAuth sign-ins.
# - Keys: nix-secrets' ai-proxy.env (OPENROUTER_API_KEY, AI_PROXY_KEY),
#   decrypted by sops-nix with this Mac's SSH host key into
#   /run/secrets/ai-proxy.env, readable only by you. Change them with
#   scripts/ai-key.
# - Logs: ~/Library/Logs/ai-proxy.{out,err}.log.
#   sudo launchctl kickstart -k system/org.nixos.ai-proxy   restarts it
{
  config,
  pkgs,
  lib,
  nix-secrets,
  ...
}:
let
  user = config.system.primaryUser;
  home = "/Users/${user}";
  state = "${home}/.local/state/ai-proxy";
  cliproxyapi = pkgs.callPackage ../pkgs/cliproxyapi.nix { };
  ai-proxy = pkgs.callPackage ../pkgs/ai-proxy.nix { inherit cliproxyapi; };
  keys = config.sops.secrets."ai-proxy.env".path;

  run = pkgs.writeShellScript "ai-proxy-daemon" ''
    set -euo pipefail
    # sops-nix writes /run/secrets at activation and, since /run is emptied at
    # each boot, from its own boot daemon: wait for it rather than fail.
    for _ in $(seq 120); do [ -r ${keys} ] && break; sleep 1; done
    [ -r ${keys} ] || { echo "ai-proxy: ${keys} missing (sops-nix)" >&2; exit 1; }
    # The two keys, read as data (not sourced), into this process only.
    while IFS='=' read -r k v || [ -n "$k" ]; do
      case "$k" in OPENROUTER_API_KEY | AI_PROXY_KEY) export "$k=$v" ;; esac
    done < ${keys}
    export AI_PROXY_HOST=127.0.0.1 AI_PROXY_PORT=8317 AI_PROXY_STATE=${state}
    umask 077 # the config and the sign-ins: owner-only
    mkdir -p ${state}
    chmod 700 ${state}
    exec ${lib.getExe ai-proxy}
  '';
in
{
  sops.secrets."ai-proxy.env" = {
    sopsFile = nix-secrets.secrets.ai-proxy;
    format = "dotenv";
    owner = user;
    group = "staff";
    mode = "0400";
  };

  # cliproxyapi on PATH, for scripts/ai-login.
  environment.systemPackages = [ cliproxyapi ];

  launchd.daemons.ai-proxy = {
    command = "${run}";
    serviceConfig = {
      UserName = user;
      GroupName = "staff";
      RunAtLoad = true;
      # Restarted when it exits: no network yet at boot (it reads
      # OpenRouter's model list at start), or 8317 still taken.
      KeepAlive = true;
      ThrottleInterval = 30;
      EnvironmentVariables = {
        HOME = home;
        USER = user;
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "${home}/Library/Logs/ai-proxy.out.log";
      StandardErrorPath = "${home}/Library/Logs/ai-proxy.err.log";
    };
  };
}
