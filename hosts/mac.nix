{ config, pkgs, ... }:
let
  # The Macs `sessions` asks, by their ssh names (ssh/config, over Tailscale).
  hosts = [
    "m4"
    "m2"
  ];
  # What runs on this Mac, as one JSON object: Claude Code's sessions (claude
  # agents, however they were started), and its ai-proxy
  # (CLIProxyAPI): whether it answers, and its sign-ins by provider (from the
  # auth files' names, never their contents).
  sessions-here = pkgs.writeShellScriptBin "sessions-here" ''
    set -u
    agents="$(claude agents --json 2>/dev/null)" || agents='[]'
    code="$(curl -s -o /dev/null -m 2 -w '%{http_code}' http://127.0.0.1:8317/ 2>/dev/null)" || code=000
    proxy=down; [ "$code" = 000 ] || proxy=up
    providers="$(cd "$HOME/.local/state/ai-proxy/auth" 2>/dev/null && ls -- *.json 2>/dev/null | sed 's/-.*//' | sort | uniq -c | awk '{ print $2 " " $1 }' | paste -sd, -)" || providers=""
    ${pkgs.jq}/bin/jq -n --argjson agents "$agents" --arg proxy "$proxy" --arg providers "$providers" \
      '{ agents: $agents, proxy: $proxy, providers: $providers }'
  '';
  # Every Mac's Claude Code sessions and ai-proxy. A Mac's Emacs: `ssh HOST`,
  # then `emacsclient -t`.
  sessions = pkgs.writeShellScriptBin "sessions" ''
    set -u
    for h in ${toString hosts}; do
      if ! out="$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$h" "zsh -lc sessions-here" 2>/dev/null)"; then
        echo "$h: unreachable, or sessions-here isn't installed there yet"
        continue
      fi
      printf '%s\n' "$out" | ${pkgs.jq}/bin/jq -r --arg h "$h" '
        "\($h):",
        (.agents[] | "  claude  \(.name)  \(.status)  \(.kind)  \(.cwd | sub("^/Users/[^/]+"; "~"))"),
        "  ai-proxy \(.proxy)\(if .providers != "" then " (\(.providers))" else "" end)"'
    done
  '';
in
{
  # MacOS-specific user packages/settings go here.

  home.packages = [
    sessions
    sessions-here
  ];

  # Emacs as a daemon from login, kept running, so its buffers outlast any
  # terminal or connection: `ssh HOST`, then `emacsclient -t`, from anywhere.
  # Started by a login
  # zsh, so it has a terminal's PATH (claude, the nix tools). A GUI frame is
  # `emacsclient -c`.
  launchd.agents.emacs = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/zsh"
        "-lc"
        "exec ${config.programs.emacs.finalPackage}/bin/emacs --fg-daemon"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/emacs-daemon.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/emacs-daemon.log";
    };
  };

  # Home Manager owns ~/.zshrc, so the session variables and paths it sets
  # (home.sessionVariables, home.sessionPath) reach every shell. nix-darwin
  # leaves the shells' /etc files alone (darwin/mini.nix).
  # nix-darwin's tools (docker, tmux, darwin-rebuild, ...). /etc/paths.d adds
  # them for login shells only; `ssh host cmd` and other non-login shells
  # need them here too.
  home.sessionPath = [
    "$HOME/.local/bin" # claude, and other self-updating user tools
    "/run/current-system/sw/bin"
  ];

  programs.zsh = {
    enable = true;
    history = {
      size = 100000;
      save = 100000;
      share = true;
    };
  };
}
