;;; sessions.el --- Every Mac's Claude Code sessions, in one list -*- lexical-binding: t; -*-

;; M-x sessions lists what `sessions --json' (hosts/mac.nix) finds on every
;; Mac. RET opens a background session (claude --bg) in a vterm buffer,
;; attached over ssh when it runs on another Mac; c starts a background
;; session on a Mac; b moves a session started in a terminal to the
;; background once you've quit it there (claude --bg --resume), so it opens
;; from here; g refreshes.

(require 'tabulated-list)
(defvar vterm-shell)  ; vterm's, bound around (vterm) below

(defvar sessions--here nil
  "The Macs the last refresh found to be this one.")

(defun sessions--read ()
  "Every Mac's entry from `sessions --json'."
  (with-temp-buffer
    (unless (zerop (call-process "sessions" nil t nil "--json"))
      (error "sessions --json failed: %s" (string-trim (buffer-string))))
    (goto-char (point-min))
    (json-parse-buffer :object-type 'alist :array-type 'list
                       :null-object nil :false-object nil)))

(defun sessions--entries ()
  "Rows for `tabulated-list-entries', one per session (or unreachable Mac)."
  (let (rows)
    (setq sessions--here nil)
    (dolist (m (sessions--read))
      (let ((host (alist-get 'host m)))
        (when (alist-get 'here m) (push host sessions--here))
        (if (not (alist-get 'reachable m))
            (push (list (list host nil nil nil nil) (vector host "" "unreachable" "" "")) rows)
          (dolist (a (alist-get 'agents m))
            (let ((name (or (alist-get 'name a) ""))
                  (kind (or (alist-get 'kind a) "")))
              (push (list (list host name kind (alist-get 'sessionId a) (alist-get 'cwd a))
                          (vector host name (format "%s" (or (alist-get 'status a) ""))
                                  kind
                                  (replace-regexp-in-string
                                   "\\`/Users/[^/]+" "~" (or (alist-get 'cwd a) ""))))
                    rows))))))
    (nreverse rows)))

(defun sessions--refresh ()
  (setq tabulated-list-entries (sessions--entries)))

(defun sessions--command (host cmd)
  "CMD as a shell command run on HOST: here, or over ssh with a terminal."
  (if (member host sessions--here)
      cmd
    (format "ssh -t %s %s" (shell-quote-argument host)
            (shell-quote-argument (format "zsh -lc %s" (shell-quote-argument cmd))))))

(defun sessions-open ()
  "Open the background session on this line in a vterm buffer."
  (interactive)
  (pcase-let ((`(,host ,name ,kind . ,_) (tabulated-list-get-id)))
    (cond
     ((not name) (user-error "%s can't be reached" host))
     ((not (equal kind "background"))
      (user-error "%s was started in a terminal: quit it there, then press b to move it to the background" name))
     (t
      (require 'vterm)
      (let ((buf (format "*session: %s/%s*" host name)))
        (if (get-buffer buf)
            (pop-to-buffer-same-window buf)
          (let ((vterm-shell (sessions--command
                              host (format "claude attach %s" (shell-quote-argument name)))))
            (vterm buf))))))))

(defun sessions-start (host dir prompt)
  "Start a background Claude Code session on HOST in DIR with PROMPT."
  (interactive
   (list (completing-read "Mac: " (delete-dups (mapcar (lambda (e) (car (car e)))
                                                        tabulated-list-entries))
                          nil t)
         (read-string "Folder on that Mac: " "~/repos/")
         (read-string "First prompt: ")))
  (let* ((cmd (format "cd %s && claude --bg %s" dir (shell-quote-argument prompt)))
         (out (with-temp-buffer
                (call-process "sh" nil t nil "-c" (sessions--command host cmd))
                (string-trim (buffer-string)))))
    (message "%s" out)
    (when (derived-mode-p 'sessions-mode) (revert-buffer))))

(defun sessions-background ()
  "Continue the terminal session on this line in the background, once quit.
Claude Code can resume a session in the background under the same ID only
after it has stopped in its terminal (otherwise it starts a copy)."
  (interactive)
  (pcase-let ((`(,host ,name ,kind ,id ,cwd) (tabulated-list-get-id)))
    (cond
     ((not name) (user-error "%s can't be reached" host))
     ((equal kind "background") (user-error "%s already runs in the background: RET opens it" name))
     ((not (y-or-n-p (format "Have you quit %s in its terminal (/exit)? " name)))
      (message "Quit it there first, then press b again"))
     ((seq-some (lambda (e) (equal (nth 3 (car e)) id)) (sessions--entries))
      (user-error "%s is still running on %s: quit it in its terminal first" name host))
     (t
      (let ((out (with-temp-buffer
                   (call-process "sh" nil t nil "-c"
                                 (sessions--command
                                  host (format "cd %s && claude --bg --resume %s"
                                               (shell-quote-argument cwd)
                                               (shell-quote-argument id))))
                   (string-trim (buffer-string)))))
        (message "%s" out)
        (revert-buffer))))))

(defvar-keymap sessions-mode-map
  :parent tabulated-list-mode-map
  "RET" #'sessions-open
  "b" #'sessions-background
  "c" #'sessions-start)

(define-derived-mode sessions-mode tabulated-list-mode "Sessions"
  "Every Mac's Claude Code sessions."
  (setq tabulated-list-format
        [("Mac" 6 t) ("Session" 36 t) ("Status" 9 t) ("Kind" 12 t) ("Folder" 0 t)])
  (setq tabulated-list-padding 1)
  (add-hook 'tabulated-list-revert-hook #'sessions--refresh nil t)
  (tabulated-list-init-header))

(defun sessions ()
  "List every Mac's Claude Code sessions."
  (interactive)
  (let ((buf (get-buffer-create "*sessions*")))
    (with-current-buffer buf
      (sessions-mode)
      (sessions--refresh)
      (tabulated-list-print))
    (pop-to-buffer-same-window buf)))

(provide 'sessions)
;;; sessions.el ends here
