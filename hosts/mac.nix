{ config, pkgs, ... }:
let
  # The Macs whose Emacs daemons `hop` reaches, by their ssh names (ssh/config,
  # over Tailscale).
  hosts = [
    "m4"
    "m2"
  ];
  hop = pkgs.writeShellScriptBin "hop" ''
    # hop HOST   this terminal becomes a frame of HOST's Emacs daemon: its
    #            buffers, its Claude sessions (emacs/init.el, tt-claude),
    #            started if it isn't running
    # hop        each host's Claude sessions
    set -eu
    if [ $# -eq 0 ]; then
      for h in ${toString hosts}; do
        echo "$h:"
        if out="$(ssh -o ConnectTimeout=5 "$h" "zsh -lc 'emacsclient --eval \"(tt-claude-list)\"'" 2>/dev/null)"; then
          printf '%s\n' "$out" | sed -e 's/^"//' -e 's/"$//' | tr '|' '\n' | sed -e '/^$/d' -e 's/^/  /'
        else
          echo "  (unreachable, or no Emacs daemon)"
        fi
      done
      exit 0
    fi
    exec ssh -t "$1" "zsh -lc 'exec emacsclient -t -a \"\"'"
  '';
in
{
  # MacOS-specific user packages/settings go here.

  home.packages = [ hop ];

  # Emacs as a daemon from login, kept running: Claude sessions live in its
  # vterm buffers (emacs/init.el, tt-claude), so they outlast any terminal or
  # connection, and `hop HOST` reaches them from anywhere. Started by a login
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
