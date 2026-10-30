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
    # mosh: a terminal session that survives sleep and network changes
    # (`mosh m4 -- emacsclient -t`). It logs in with ssh, then talks UDP
    # (60000-61000) over the tailnet; mosh-server must be on each Mac's PATH.
    pkgs.mosh
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

  # The daemon runs Emacs from a fixed path, ~/.local/share/emacs-daemon (a
  # link to this generation's emacs-daemon), not from its store path, so the
  # agent's plist doesn't change when the packages do and a switch doesn't
  # restart the daemon and close every emacsclient frame. The running daemon
  # keeps its build until it's restarted (a crash, a login, or by hand:
  # `launchctl kickstart -k gui/$(id -u)/org.nix-community.home.emacs`).
  # Restart it before collecting garbage once its generation has expired:
  # it loads Lisp lazily from its own store path.
  home.file.".local/share/emacs-daemon".source = emacs-daemon;

  home.activation.emacsDaemonNotice = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    link="''${oldGenPath:-/nonexistent}/home-files/.local/share/emacs-daemon"
    if [[ -e "$link" && "$(readlink -f "$link")" != "${emacs-daemon}" ]]; then
      echo "The Emacs daemon's build changed; the running daemon keeps the old one until restarted:"
      echo "  launchctl kickstart -k gui/$(id -u)/org.nix-community.home.emacs"
    fi
  '';

  launchd.agents.emacs = {
    enable = true;
    config = {
      ProgramArguments = [
        "${config.home.homeDirectory}/.local/share/emacs-daemon/bin/emacs"
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
  # Option is Meta for Emacs. ssh is plain ssh: TERM=xterm-ghostty goes to
  # the other host, and these Macs have its terminfo from the activation
  # below, so Emacs there gets 24-bit colour and the rest. No ssh shell
  # integration: ssh-terminfo wraps every `ssh` to install the terminfo on
  # first contact, and ran an `ssh host 'command'` inside that step with its
  # output hidden; ssh-env sets TERM=xterm-256color, and the COLORTERM it
  # sends with it is dropped by sshd (AcceptEnv is LANG and LC_* only), which
  # leaves 256 colours. On a host without the terminfo:
  # export TERM=xterm-256color there.
  #
  # The app is ghostty-bin, the developer's notarized build, re-signed
  # ad-hoc (the way Nix signs the apps it builds). Home Manager copies its
  # apps into ~/Applications/Home Manager Apps (for Spotlight) and checks
  # first that it may modify them. Once a developer-signed app has been
  # launched, macOS's App Management protection lets only programs holding
  # that permission modify it, and over ssh or from a Claude Code session
  # nothing does (short of Full Disk Access for every remote login), so with
  # the notarized build every switch there aborted. Ad-hoc signed, it's as
  # modifiable as Emacs.app; it runs the same. Re-sign any other
  # developer-signed app (a `-bin` package) the same way.
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        /usr/bin/codesign --force --deep --sign - --preserve-metadata=entitlements \
          "$out/Applications/Ghostty.app"
      '';
    });
    settings = {
      macos-option-as-alt = true;
      shell-integration-features = "no-ssh-env,no-ssh-terminfo";
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
    # Before every prompt, switch off the terminal modes a full-screen
    # program turns on (mouse reporting, focus events, the kitty keyboard
    # protocol). One that dies without switching them off (a dropped ssh,
    # Emacs or claude attach killed) left Ghostty sending touchpad moves and
    # focus changes as typed text into this shell until the tab was closed.
    initContent = ''
      _tt_reset_tty_modes() {
        printf '\e[?1000l\e[?1002l\e[?1003l\e[?1005l\e[?1006l\e[?1015l\e[?1004l\e[=0;1u'
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd _tt_reset_tty_modes
    '';
  };
}
