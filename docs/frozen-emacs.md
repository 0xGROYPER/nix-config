# Frozen Emacs (emacsclient from the laptop to the M4)

Found 2026-10-29 on the M4 (`mini`).

## Symptom

`ssh m4` then `emacsclient -t` hangs, or an open `emacsclient -t` frame
stops responding. Every client freezes at once, including new ones:
`emacsclient -e t` prints "Server not responding" and waits, sometimes for
minutes. Sometimes it recovers on its own (one probe took 1m48s).

## Unfreeze it now

From any shell on the M4 (for example a plain `ssh m4`):

```
osascript -e 'tell application "System Events" to set frontmost of (first process whose unix id is '"$(pgrep -f 'emacs.*--fg-daemon' | head -1)"') to true'
```

That sends the daemon one Cocoa event, which wakes it. It answered
instantly afterwards, with all frames and buffers intact. No restart is
needed. (`kill -USR1` does not wake it.)

## Cause

The daemon was the **macOS GUI (NS) build** of Emacs 31.1, run by launchd
(`org.nix-community.home.emacs`, `emacs --fg-daemon`), serving only terminal
frames. When frozen:

- the main thread was parked in Cocoa's event loop (`read_char` -> `sit_for`
  -> `wait_reading_process_output` -> `ns_select_1` -> `-[NSApplication run]`
  -> `nextEventMatchingMask` -> `mach_msg2_trap`), not in a write, not in Lisp;
- the NS port's fd-watching thread (`-[EmacsApp fd_handler:]`) was in `pselect`;
- the server socket went unanswered for minutes, at 0% CPU;
- one Cocoa event (activating the process) released it instantly.
  `kill -USR1` did not.

What exactly drops the wakeup is **not pinned down**. I found no specific
upstream Emacs bug. Two candidates, both specific to a window-less GUI app
on macOS:

- a lost wakeup in the NS port's handoff between `fd_handler` and the main
  thread;
- **App Nap** throttling a background Cocoa app until it's activated.
  launchd's `ProcessType Interactive` doesn't necessarily prevent that, so
  my first "ruled out" was too hasty.

The terminal-only build (emacs-nox) has no Cocoa event loop, so either way
it can't freeze like this.

### Ruled out

- **The respawn loop in `~/Library/Logs/emacs-daemon.log`** ("Unable to start
  the daemon"): it's old, from before the current daemon started on Oct 27
  at 11:57, and the log hasn't been written since.
- **A stalled ssh connection blocking tty writes:** that was my first theory.
  The keepalive gaps behind it are real (see below), but the hung stack
  isn't in a write.

### Contributing, but not the cause

- `emacs/sessions.el` (`M-x sessions`, `g`) runs `sessions --json` with a
  synchronous `call-process`. That's about 0.6 s normally, and 10 s or more
  when a Mac (often the sleeping laptop) is unreachable, because ssh
  `ConnectTimeout=5` is tried twice. Everything freezes for that long.
- No ssh keepalives on either end: the laptop's `ServerAliveInterval` is 0,
  and the M4's sshd has no `ClientAliveInterval`. The laptop sleeps after 1
  minute idle (`pmset sleep 1`). Dead sessions and their `emacsclient -t`
  frames linger on the M4 for a long time.

## Fixes (nix-config #20 and #21, on master as 2022ca3)

Applied on 2026-10-29 to the M4, the M2 and the laptop. Each now runs
`emacs-nox-31.1 --fg-daemon`.

1. **The daemon is emacs-nox** (terminal-only, same packages, `hosts/mac.nix`).
   `emacs/init.el` guards `tool-bar-mode` and `scroll-bar-mode`, which
   emacs-nox lacks.
2. **The shared daemon is `emacsclient -t`,** from Ghostty (the Dock app for
   it) or over ssh. Emacs.app is a separate GUI Emacs, which leaves the server
   to the daemon. "Emacs Client.app" is gone.
3. **`M-x sessions` / `g` refresh in the background** (`make-process`), so a
   sleeping Mac can't freeze the daemon.

Deliberately not done: **ssh keepalives.** Connections should stay up
indefinitely, and keepalives would end them 45 s into a laptop's sleep.

Open: GUI frames on the shared daemon need the NS build back, with an uptime
guarantee first. One option: App Nap off for it
(`defaults write org.gnu.Emacs NSAppSleepDisabled -bool YES`), plus a
watchdog that logs and wakes it, to learn which candidate cause it is.

### Applying Home Manager on these Macs

- **M4:** the activation refuses to run from a Claude Code session, from
  Terminal.app, or over ssh (that needs "Allow full disk access for remote
  users"). Run it in Ghostty:
  `open -na "$HOME/Applications/Home Manager Apps/Ghostty.app" --args -e /bin/zsh -lc 'export PATH=/nix/var/nix/profiles/default/bin:$PATH; <generation>/activate'`
- **M2 and laptop:** build and activate over ssh from their own
  `~/repos/nix-config`; store paths copied from the M4 are refused (unsigned).
  The laptop has no GitHub login. Push `master` to it from the M4, and build
  with `--no-write-lock-file --override-input tinytrader-ops
  "git+file:///Users/daws/repos/tinytrader-ops?rev=<locked rev>"`.
