(use-package nix-mode
  :mode "\\.nix\\'")

(use-package magit
  :commands magit-status)

(require 'server)

(unless (server-running-p)
  (server-start))

(use-package markdown-mode
  :mode "\\.md\\'")

(use-package gptel
  :commands (gptel gptel-send gptel-menu))
