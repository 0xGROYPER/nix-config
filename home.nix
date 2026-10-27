{ config, pkgs, lib, ... }:

let
  # cargo, building into one target per repository on this machine,
  # ~/.cache/cargo-target/<repo>/target, <repo> named by the repository's
  # common Git folder, so every worktree shares its main checkout's
  # (tinytrader-deploy's scripts/cargo-shim, decision 0016). As the cargo on
  # PATH it covers every shell, interactive or not, agents' too. A
  # CARGO_TARGET_DIR already set is kept (the Nomad build jobs set their
  # own); outside a repository it changes nothing. tinytrader-deploy's
  # daily disk-hygiene job deletes a target idle for 7 days.
  cargo = pkgs.writeShellScriptBin "cargo" ''
    if [ -z "''${CARGO_TARGET_DIR:-}" ] && common="$(${pkgs.git}/bin/git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
      repo="''${common%/.git}"
      repo="''${repo##*/}"
      export CARGO_TARGET_DIR="$HOME/.cache/cargo-target/''${repo%.git}/target"
    fi
    exec ${pkgs.cargo}/bin/cargo "$@"
  '';
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "26.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  services.syncthing = {
    enable = true;
  };

  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    # cli tools 
    pkgs.tree

    # python: uv (Astral), for tinytrader-ops' pyproject.toml/uv.lock
    pkgs.uv

    # rust dev stuff: cargo builds into one target per repository (above)
    cargo
    pkgs.rustc
    pkgs.rust-analyzer
    pkgs.rustfmt
    pkgs.clippy

    # ricer stuff 
    pkgs.screenfetch
    pkgs.ffmpeg

  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
    ".ssh/config".source = ./ssh/config;
    # ".emacs.d".source = ./emacs;
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/daws/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # A repo's .envrc (`use flake`) loads its dev shell on cd, so cargo there is
  # the repo's pinned toolchain, not the one installed above. Each repo needs
  # `direnv allow` once.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Dawson Shay";
        email = "292910774+dawson-shay@users.noreply.github.com";
      };
    };
    # tinytrader-ops' versioned Git hooks (its scripts/hooks: pre-push runs
    # CI's checks), on in every clone on every machine, instead of running
    # its scripts/install-hooks once per clone. The relative path resolves
    # from the root of the worktree the hook runs in, so each checkout and
    # worktree uses its own copy. Matched by location (~/repos/tinytrader-ops
    # and its worktrees, wherever they are checked out) and by remote, for a
    # clone kept anywhere else. A repository's own core.hooksPath, set by
    # install-hooks, still wins.
    includes =
      let
        hooks = condition: {
          inherit condition;
          contents.core.hooksPath = "scripts/hooks";
        };
      in
      map hooks [
        "gitdir:~/repos/tinytrader-ops/"
        "hasconfig:remote.*.url:https://github.com/dawson-shay/tinytrader-ops*"
        "hasconfig:remote.*.url:git@github.com:dawson-shay/tinytrader-ops*"
      ];
  };


  programs.gh = {
    enable = true;

    settings = {
      git_protocol = "https"; # change to ssh later 
    };
  };

  

  programs.emacs = {
    enable = true;

    extraPackages = epkgs: [
      epkgs.nix-mode
      epkgs.magit
      epkgs.gptel
      epkgs.gptel-agent
      epkgs.rust-mode
      epkgs.tree-sitter-langs
      epkgs.markdown-mode
      epkgs.vterm # a terminal in Emacs
      # epkgs.treesit-grammars.with-rust-grammar
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      epkgs.exwm
    ];
  };

  xdg.configFile."emacs".source = ./emacs;
}
