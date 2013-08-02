
;; http://www.masteringemacs.org/articles/2013/07/31/comint-writing-command-interpreter/

(defvar metamap-cli-file-path "/mnt/public_mm/bin/metamap12"
  "Path to the program used by `run-metamap'")

(defvar metamap-cli-arguments '("--XMLf")
  "Commandline arguments to pass to `metamap-cli'")

(defvar metamap-mode-map
  (let ((map (nconc (make-sparse-keymap) comint-mode-map)))
    ;; example definition
    (define-key map (kbd "<tab>") 'metamap/toggle-element)
    map)
  "Basic mode map for `run-metamap'")

(defvar metamap-prompt-regexp "^\\(|:\\)"
  "Prompt for `run-metamap'.")

(defun run-metamap ()
  "Run an inferior instance of `cassandra-cli' inside Emacs."
  (interactive)
  (let* ((metamap-program metamap-cli-file-path)
         (buffer (comint-check-proc "Metamap")))
    ;; pop to the "*Metamap*" buffer if the process is dead, the
    ;; buffer is missing or it's got the wrong mode.
    (pop-to-buffer-same-window
     (if (or buffer (not (derived-mode-p 'metamap-mode))
             (comint-check-proc (current-buffer)))
         (get-buffer-create (or buffer "*Metamap*"))
       (current-buffer)))
    ;; create the comint process if there is no buffer.
    (unless buffer
      (apply 'make-comint-in-buffer "Metamap" buffer
             metamap-program nil metamap-cli-arguments)
      (metamap-mode))))


(defun metamap--initialize ()
  "Helper function to initialize Cassandra"
  (setq comint-process-echoes t)
  (setq comint-use-prompt-regexp t))

(define-derived-mode metamap-mode comint-mode "Metamap"
  "Major mode for `run-metamap'.

\\<metamap-mode-map>"
  nil "Metamap"
  ;; this sets up the prompt so it matches things like: |:
  (setq comint-prompt-regexp metamap-prompt-regexp)
  ;; this makes it read only; a contentious subject as some prefer the
  ;; buffer to be overwritable.
  (setq comint-prompt-read-only t)
  ;; this makes it so commands like M-{ and M-} work.
  (set (make-local-variable 'paragraph-separate) "^\n")
  (set (make-local-variable 'font-lock-defaults) '(metamap-font-lock-keywords t))
  (set (make-local-variable 'paragraph-start) metamap-prompt-regexp))

;; this has to be done in a hook. grumble grumble.
(add-hook 'metamap-mode-hook 'metamap--initialize)


(defconst metamap-keywords
  '("MMOS"))

(defvar metamap-font-lock-keywords
  (list
   ;; highlight all the reserved commands.
   `(,(concat "\\_<" (regexp-opt metamap-keywords) "\\_>") . font-lock-keyword-face))
  "Additional expressions to highlight in `metamap-mode'.")

(defun metamap/toggle-element ()
  (interactive)
  (save-excursion 
    (let* ((end (progn (sgml-skip-tag-forward 1) (point)))
	   (start (progn (sgml-skip-tag-backward 1) (point)))
	   (eol (progn (move-end-of-line 1) (point)))
	   (ol-list (overlays-in start eol)))
      (if (> (length ol-list) 0)
	  ; if there is an overlay,  remove it
	  (delete-overlay (car ol-list))
	;if no overlay, add it
	(let ((ol (make-overlay start end (current-buffer) t nil))
	      (before-text (concat (buffer-substring-no-properties start eol) "..." )))       
	  (overlay-put ol 'invisible t)
	  (overlay-put ol 'before-string before-text))))))

(provide 'metamap-mode)