;;; init.el --- Emacs configuration -*- lexical-binding: t; -*-

;; An Emacs opened from the Dock or Finder gets launchd's PATH, without the
;; Nix profiles or ~/.local/bin (claude, sessions); give it a terminal's, as
;; the daemon's launchd agent does (hosts/mac.nix).
(when (eq system-type 'darwin)
  (dolist (d (reverse (list "~/.local/bin" "~/.nix-profile/bin"
                            (format "/etc/profiles/per-user/%s/bin" user-login-name)
                            "/run/current-system/sw/bin"
                            "/nix/var/nix/profiles/default/bin")))
    (let ((d (expand-file-name d)))
      (when (and (file-directory-p d) (not (member d exec-path)))
        (push d exec-path)
        (setenv "PATH" (concat d ":" (getenv "PATH")))))))


(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)

;; Built-in dark theme (Modus, since Emacs 28): high contrast.
(load-theme 'modus-vivendi t)


(use-package nix-mode
  :mode "\\.nix\\'")

(use-package magit
  :commands magit-status)

(require 'server)

;; The daemon (hosts/mac.nix) starts its own server; a GUI Emacs started
;; beside it leaves the server to it.
(unless (or (daemonp) (server-running-p))
  (server-start))

;; A terminal in Emacs (M-x vterm), for Claude Code or anything else.
(use-package vterm
  :commands vterm)

;; M-x sessions: every Mac's Claude Code sessions (sessions.el).
(load (expand-file-name "sessions" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(use-package markdown-mode
  :mode "\\.md\\'")

(use-package gptel
  :commands (gptel gptel-send gptel-menu))

(use-package rust-mode
  :mode "\\.rs\\'")

;; (use-package gptel
;;   :config
;;   (require 'gptel-openai-oauth)
;;   (setq gptel-openai-oauth-login-method 'device
;;         gptel-model 'gpt-5.6-luna
;;         gptel-backend
;;         (gptel-make-openai-oauth "OpenAI-sub")))

;; (use-package gptel
;;   :demand t
;;   :commands (gptel gptel-send gptel-menu)
;;   :config
;;   (require 'gptel-openai-oauth)
;;   (setq gptel-model 'gpt-5.6-luna
;;         gptel-openai-oauth-login-method 'device
;;         gptel-backend
;;         (gptel-make-openai-oauth "OpenAI-sub")))

(use-package gptel
  :ensure nil
  :demand t
  :config
  (require 'gptel-openai-oauth)
  (setq gptel--openai-oauth-token-file
        (expand-file-name
         "gptel-openai"
         (or (getenv "XDG_DATA_HOME")
             (expand-file-name "~/.local/share"))))
  (setq gptel-model 'gpt-5.6-luna
        gptel-openai-oauth-login-method 'device
        gptel-backend
        (gptel-make-openai-oauth "OpenAI-sub")))


(use-package gptel-agent
  :ensure nil
  :after gptel)


;; Platform-specific code
;; Probably refactored out to ~/repos/nix-config/hosts/ once warranted
(when (eq system-type 'darwin)
  (setq mac-command-modifier 'meta))

(when (eq system-type 'gnu/linux)
  ;; Linux-specific settings
  )
