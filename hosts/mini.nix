{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
in
{
  # The M4 only (dawsonshay@mini, with hosts/mac.nix).

  # JupyterLab for research, from the tinytrader-ops checkout: the notebooks
  # Emacs edits (research/*.py, paired by jupytext) are the ones it shows.
  # On the tailnet only, at http://mini:8888, with no token: Tailscale's
  # login is the gate, as for the other tailnet services. Data comes from the
  # store's API on the M2 (research/tt.py's TT_STORE), never the drives.
  # `uv run --frozen` uses the checkout's uv.lock (its notebook group).
  # Tailscale's address is fixed (tinytrader-ops inventory, tailnetAddress);
  # until it's up, launchd starts it again a minute later.
  launchd.agents.jupyterlab = {
    enable = true;
    config = {
      WorkingDirectory = "${home}/repos/tinytrader-ops";
      ProgramArguments = [
        "${pkgs.uv}/bin/uv"
        "run"
        "--frozen"
        "jupyter"
        "lab"
        "--ip=100.120.168.125"
        "--port=8888"
        "--no-browser"
        "--IdentityProvider.token="
        "--ServerApp.password="
        "--ServerApp.allow_remote_access=True"
      ];
      EnvironmentVariables = {
        TT_STORE = "http://dawsons-mac-mini:9120";
        PATH = "${home}/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 60;
      StandardOutPath = "${home}/Library/Logs/jupyterlab.log";
      StandardErrorPath = "${home}/Library/Logs/jupyterlab.log";
    };
  };
}
