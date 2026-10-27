# Working across the Macs

Claude Code sessions belong on the M4 (ssh name `m4`, the mini): the other
Macs are reached from there, not worked on directly. If this session runs on
another machine (`hostname`), tell the user before doing more than reading.

- **Another Mac:** run commands there with `ssh m2 '…'`, one command at a
  time, so each step says which machine it touches. Edit code in the M4's
  M4's own checkouts (`~/repos/…`), never in another Mac's over ssh.
- **Builds and tests** that are more than a quick check go to Nomad, not this
  shell: tinytrader-deploy's `scripts/job run tinytrader-build package=NAME`
  (or `tinytrader-test`), then `scripts/job logs RUN`. They run where the
  site's inventory allows builds. Never build or deploy between 09:25 and
  16:20 New York time on a trading day unless the user asks; the M4 also
  runs the live services.
- **Market data** comes through the store's API (`tt store …`, or its HTTP
  endpoints), never by reading the data drives directly.
- **Long-running work** on another Mac goes in a Nomad job or a `tmux`
  session there, to be checked on later, not in a foreground ssh.
- **Other sessions:** `sessions` lists every Mac's; `sessions send HOST
  SESSION TEXT` messages one (it arrives as a message from another session).
