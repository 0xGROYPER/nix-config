{ pkgs, ... }:
{
  # MacOS-specific user packages/settings go here.

  # Home Manager owns ~/.zshrc, so the session variables and paths it sets
  # (home.sessionVariables, home.sessionPath) reach every shell. nix-darwin
  # leaves the shells' /etc files alone (darwin/mini.nix).
  programs.zsh = {
    enable = true;
    history = {
      size = 100000;
      save = 100000;
      share = true;
    };
  };
}
