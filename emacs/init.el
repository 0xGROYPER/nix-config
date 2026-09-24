;; Emacs source init.el file
;; Activ file is under ~/.config/emacs/

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

(use-package rust-mode
  :mode "\\.rs\\'")

(use-package gptel
  :config
  (require 'gptel-openai-oauth)
  (setq gptel-openai-oauth-login-method 'device
        gptel-model 'gpt-5.6-luna
        gptel-backend
        (gptel-make-openai-oauth "OpenAI-sub")))



;; Platform-specific code
;; Probably refactored out to ~/.config/home-manager/hosts/ once warranted
(when (eq system-type 'darwin)
  (setq mac-command-modifier 'meta))

(when (eq system-type 'gnu/linux)
  ;; Linux-specific settings
  )
