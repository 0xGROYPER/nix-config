(use-package nix-mode
  :mode "\\.nix\\'")

(use-package magit
  :commands magit-status)

(require 'sever)

(unless (server-running-p)
  (server-start))
