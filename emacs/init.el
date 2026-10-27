;;; init.el --- Emacs configuration -*- lexical-binding: t; -*-


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

;; Claude Code sessions as vterm buffers named *claude: DIR*. They live in
;; this Emacs, a daemon on each Mac: `ssh HOST', then `ec', from anywhere.
(use-package vterm
  :commands vterm)

(defun tt-claude (dir)
  "Start Claude Code in DIR in a vterm buffer, or switch to the one there."
  (interactive
   (list (read-directory-name "Claude in: " (or (vc-root-dir) default-directory))))
  (let* ((dir (file-name-as-directory (expand-file-name dir)))
         (name (format "*claude: %s*" (abbreviate-file-name (directory-file-name dir))))
         (buf (get-buffer name)))
    (if (buffer-live-p buf)
        (pop-to-buffer-same-window buf)
      (let ((default-directory dir)
            (vterm-shell (or (executable-find "claude") "claude")))
        (vterm name)))))

(defun tt-claude-list ()
  "This Emacs's Claude buffers, separated by | (`sessions')."
  (mapconcat #'buffer-name
             (seq-filter (lambda (b) (string-prefix-p "*claude: " (buffer-name b)))
                         (buffer-list))
             "|"))

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
