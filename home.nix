{ config, pkgs, lib, ... }:

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

    # rust dev stuff 
    pkgs.cargo
    pkgs.rustc
    pkgs.rust-analyzer
    pkgs.rustfmt
    pkgs.clippy

    # ricer stuff 
    pkgs.screenfetch
    pkgs.maim
    pkgs.ffmpeg
    pkgs.xrandr

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

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Dawson Shay";
        email = "dawson.shay@icloud.com";
      };
    };
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
      # epkgs.treesit-grammars.with-rust-grammar
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      epkgs.exwm
    ];
  };

  xdg.configFile."emacs".source = ./emacs;
  
}
