# Daily use

How the Macs are used day to day. The rest of this repository says how
they're built.

## The Macs

| | Role | Reach it |
|---|---|---|
| M4 (`m4`, `mini`) | The hub: Claude Code sessions, the shared Emacs, JupyterLab, the live services | `ssh m4` |
| M2 (`m2`) | The store and its data drives; jobs | `ssh m2` |
| Laptop (`laptop`) | A client: Ghostty, a browser, Emacs.app | |

All on the tailnet; a Tailscale login is the only gate. Work happens on the
M4, in its checkouts (`~/repos/…`); the other Macs are reached from there.

## Emacs

- **The shared Emacs** is the M4's daemon (terminal-only):
  `ssh -t m4 emacsclient -t`, from Ghostty anywhere. `C-x C-c` closes your
  frame; the daemon, its buffers and sessions keep running. Every frame,
  from any Mac, is the same Emacs.
- **A GUI Emacs** (images, native windows) is Emacs.app on the Mac in front
  of you. It's a separate Emacs, with no buffers or history in common with
  the daemon. Open the M4's files in place with TRAMP:
  `C-x C-f /ssh:m4:~/repos/…`. Only files are shared: with a file open in
  both, save in one and `M-x revert-buffer` in the other.

## Claude Code sessions

- `M-x sessions` lists every Mac's. `RET` opens one, `c` starts one in the
  background, `b` moves a terminal session to the background (quit it there
  first), `g` refreshes. From a shell: `sessions`.
- Or attach directly: `ssh -t m4 claude attach ID`.
- **Detach, don't `/exit`:** a background session keeps running when its
  window closes. Start them from a folder in `~/repos`.
- After an `/exit`: `cd ~/repos && claude --bg --resume ID`.

## Notebooks and plots

- JupyterLab runs on the M4: <http://mini:8888/lab>, from any browser on
  the tailnet. It works in `~/repos/tinytrader-ops` and gets data from the
  store's API.
- Each notebook in `research/` is paired with a `.py` (`# %%` cells): edit
  the `.py` in Emacs, reload in the browser; the outputs stay in the
  `.ipynb`. Terminal Emacs can't show images; the browser or Emacs.app can.

## Changing a Mac's setup

Edit here on the M4, open a PR, merge, then switch each Mac:

- **M4:** run the new generation's `activate` in Ghostty on the M4's own
  screen. It needs macOS's App Management permission, which ssh and
  Claude Code don't have.
- **M2:** push `master` to it from the M4
  (`git push m2:repos/nix-config master:refs/remotes/origin/master`),
  fast-forward its checkout, then build and activate there over ssh. Store
  paths copied from the M4 are refused (unsigned).
- **Laptop:** the same, but it has no GitHub login, so the build points the
  private inputs at local stand-ins:

  ```
  nix build --no-link --print-out-paths --no-write-lock-file \
    --override-input tinytrader-ops "git+file://$HOME/repos/tinytrader-ops?rev=<locked rev>" \
    --override-input nix-secrets path:$HOME/.cache/no-secrets \
    '.#homeConfigurations."daws@mac".activationPackage'
  ```

  then `HOME_MANAGER_BACKUP_EXT=hm-backup <result>/activate`.
  (`~/.cache/no-secrets/flake.nix` is `{ outputs = _: { }; }`; Home Manager
  uses neither input.)

## Rules of thumb

- No builds or deploys 09:25–16:20 New York time on trading days: the M4
  runs the live services. A push to tinytrader-ops runs checks on the M4 too.
- Market data comes through the store's API, never from the drives directly.
- A terminal acting strangely after `ssh m4` (Delete moves right, `C-a`
  does nothing) is missing its terminal definition: open a new window after
  a switch. `reset` won't fix it.
