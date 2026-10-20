{ pkgs, ... }:
{
  # MacOS-specific user packages/settings go here.

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
