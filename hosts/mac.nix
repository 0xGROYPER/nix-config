{ config, lib, pkgs, ... }:
let
  # The Macs `sessions` asks, by their ssh names (ssh/config, over Tailscale).
  hosts = [
    "m4"
    "m2"
    "laptop"
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
  # Every Mac's Claude Code sessions and ai-proxy, and messages between
  # sessions on different Macs over Tailscale ssh (scripts/sessions).
  sessions = pkgs.writeShellApplication {
    name = "sessions";
    runtimeInputs = [ pkgs.jq ];
    runtimeEnv.SESSIONS_HOSTS = toString hosts;
    text = builtins.readFile ../scripts/sessions/sessions.sh;
  };
  sessions-deliver = pkgs.writeShellApplication {
    name = "sessions-deliver";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ../scripts/sessions/sessions-deliver.sh;
  };
  # The Emacs daemon is a terminal-only build (emacs-nox) with the same
  # packages. The GUI (NS) build, as a daemon serving only `emacsclient -t`
  # frames, froze every client from time to time at 0% CPU, parked in
  # Cocoa's event loop until a Cocoa event woke it (a lost wakeup in the NS
  # port, or App Nap; not pinned down). emacs-nox has no Cocoa event loop.
  # The shared daemon is reached with `emacsclient -t` (from Ghostty, or
  # over ssh); Emacs.app is a GUI Emacs of its own, which leaves the server
  # to the daemon (emacs/init.el).
  emacs = config.programs.emacs.finalPackage;
  emacs-daemon = (pkgs.emacsPackagesFor pkgs.emacs-nox).emacsWithPackages config.programs.emacs.extraPackages;
in
{
  # MacOS-specific user packages/settings go here.

  home.packages = [
    pkgs.julia-bin # the upstream build
    pkgs.ollama # local models; `ollama serve` when wanted
    pkgs.zed-editor
    sessions
    sessions-here
    sessions-deliver
  ];

  # Emacs as a daemon from login, kept running, so its buffers outlast any
  # terminal or connection: `ssh HOST`, then `emacsclient -t`, from anywhere.
  # It's terminal-only (emacs-daemon, above), so no `emacsclient -c`.
  # launchd gives no shell's PATH, so it gets a terminal's here (claude, the
  # nix tools). While another Emacs holds the server (a GUI Emacs started on
  # its own), it retries each minute.
  # A switch updates emacs/sessions.el; a running Emacs reloads it then, so
  # M-x sessions needs no restart. Nothing else is reloaded.
  home.activation.reloadEmacsSessions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${emacs}/bin/emacsclient --eval '(load (expand-file-name "sessions" user-emacs-directory) nil t)' >/dev/null 2>&1 || true
  '';

  launchd.agents.emacs = {
    enable = true;
    config = {
      ProgramArguments = [
        "${emacs-daemon}/bin/emacs"
        "--fg-daemon"
      ];
      EnvironmentVariables.PATH = builtins.concatStringsSep ":" [
        "${config.home.homeDirectory}/.local/bin"
        "${config.home.homeDirectory}/.nix-profile/bin"
        "/etc/profiles/per-user/${config.home.username}/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 60;
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

  # Ghostty, the terminal: GPU-rendered, true colour, mouse and the kitty
  # graphics protocol, so `ssh m4` then `emacsclient -t` is close to the GUI.
  # Option is Meta for Emacs. Over ssh it installs its terminfo on another
  # host that lacks it (or falls back to xterm-256color); on these Macs the
  # activation below has already put it where macOS's zsh looks.
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      macos-option-as-alt = true;
      shell-integration-features = "ssh-env,ssh-terminfo";
      mouse-hide-while-typing = true;
      window-save-state = "always";
    };
  };

  # Ghostty's terminfo, compiled by macOS's own tic into ~/.terminfo. The
  # copy in the Nix profile is in ncurses 6's format, which the login shell
  # (/bin/zsh, on macOS's older ncurses) can't read: logged in from Ghostty,
  # it had no terminal definition and couldn't move the cursor, so Delete and
  # C-a looked broken. Ghostty's ssh-terminfo didn't step in, as Nix's
  # infocmp finds the entry. ~/.terminfo is searched before TERMINFO_DIRS.
  home.activation.ghosttyTerminfo =
    let
      source = pkgs.runCommand "xterm-ghostty.terminfo" { nativeBuildInputs = [ pkgs.ncurses ]; } ''
        TERMINFO_DIRS=${config.programs.ghostty.package.terminfo}/share/terminfo \
          infocmp -x xterm-ghostty > "$out"
      '';
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run /usr/bin/tic -x -o "$HOME/.terminfo" ${source} 2>/dev/null
    '';

  programs.zsh = {
    enable = true;
    history = {
      size = 100000;
      save = 100000;
      share = true;
    };
  };
}
