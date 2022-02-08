;; tal-mode.el
;;
;; by d_m
;;
;; prior art: https://github.com/xaderfos/uxntal-mode

;; use rx for regular expressions
(require 'rx)

;; set up a mode hook
(defvar tal-mode-hook nil)

;; set up a mode map for keybindings
(defvar tal-mode-map
  (let ((map (make-keymap)))
    (define-key map (kbd "C-c d") 'tal-decimal-value)
    map)
  "Keymap for Tal major mode")

;; open .tal files with this mode
(add-to-list 'auto-mode-alist '("\\.tal\\'" . tal-mode))

;; macro definitions like %MOD
(defconst tal-mode-macro-define-re
  (rx (group "%" (1+ (not (in space))) eow)))

;; includes like ~util.tal
(defconst tal-mode-include-re
  (rx (group "~" (1+ (not (in space))) eow)))

;; labels like @foo
(defconst tal-mode-label-define-re
  (rx (group "@" (1+ (not (in space))) eow)))

;; subabels like &bar
(defconst tal-mode-sublabel-define-re
  (rx (group "&" (1+ (not (in space))) eow)))

;; raw characters like 'a or '[
(defconst tal-mode-raw-char-re
  (rx (group "'" (in "!-~") eow)))

;; raw strings like "foo or "a-b-c-d-e
(defconst tal-mode-raw-str-re
  (rx (group "\"" (1+ (in "!-~")) eow)))

;; absolute pads like |a0 or |0100
(defconst tal-mode-absolute-pad-re
  (rx (group
       "|"
       (repeat 2 (in "0-9a-f"))
       (\? (repeat 2 (in "0-9a-f")))
       eow)))

;; pads like $1 $1f $300 $1000
(defconst tal-mode-relative-pad-re
  (rx (group "$" (repeat 1 4 (in "0-9a-f")) eow)))

;; addresses such as .foo ,bar ;baz :qux
(defconst tal-mode-addr-zeropage-re
  (rx (group "." (1+ (not (in space))) eow)))
(defconst tal-mode-addr-relative-re
  (rx (group "," (1+ (not (in space))) eow)))
(defconst tal-mode-addr-absolute-re
  (rx (group ";" (1+ (not (in space))) eow)))
(defconst tal-mode-addr-raw-re
  (rx (group ":" (1+ (not (in space))) eow)))

;; literal numbers like #ff or #abcd
(defconst tal-mode-number-re
  (rx (group
       "#"
       (repeat 2 (in "0-9a-f"))
       (\? (repeat 2 (in "0-9a-f")))
       eow)))

;; raw numbers like ff or abcd
(defconst tal-mode-raw-number-re
  (rx (group
       (repeat 2 (in "0-9a-f"))
       (\? (repeat 2 (in "0-9a-f")))
       eow)))

;; tal instructions like ADD or JMP2r
(defconst tal-mode-inst-re
  (rx (group
       (or "BRK"
           (group "LIT" (\? "2") (\? "r"))
           (group (or "INC" "POP" "DUP" "NIP" "SWP" "OVR" "ROT"
                      "EQU" "NEQ" "GTH" "LTH"
                      "JMP" "JCN" "JSR" "STH"
                      "LDZ" "STZ" "LDR" "STR" "LDA" "STA"
                      "DEI" "DEO"
                      "ADD" "SUB" "MUL" "DIV"
                      "AND" "ORA" "EOR" "SFT")
                  (\? "2") (\? "k") (\? "r")))
       eow)))

;; all previous rules joined together into a list
(defconst tal-font-lock-keywords-1
  (list
   ;; macros (%)
   (list tal-mode-macro-define-re 1 font-lock-keyword-face)
   ;; addresses (. , ; :)
   (list tal-mode-addr-zeropage-re 1 font-lock-variable-name-face)
   (list tal-mode-addr-relative-re 1 font-lock-variable-name-face)
   (list tal-mode-addr-absolute-re 1 font-lock-variable-name-face)
   (list tal-mode-addr-raw-re 1 font-lock-variable-name-face)
   ;; labels (@ &)
   (list tal-mode-label-define-re 1 font-lock-function-name-face)
   (list tal-mode-sublabel-define-re 1 font-lock-function-name-face)
   ;; padding (| $)
   (list tal-mode-absolute-pad-re 1 font-lock-preprocessor-face)
   (list tal-mode-relative-pad-re 1 font-lock-preprocessor-face)
   ;; includes (~)
   (list tal-mode-include-re 1 font-lock-preprocessor-face)
   ;; instructions
   (list tal-mode-inst-re 1 font-lock-builtin-face)
   ;; constant numbers (#)
   (list tal-mode-number-re 1 font-lock-constant-face)
   ;; raw values (' ")
   (list tal-mode-raw-number-re 1 font-lock-string-face)
   (list tal-mode-raw-char-re 1 font-lock-string-face)
   (list tal-mode-raw-str-re 1 font-lock-string-face)
   )
  "Level one font lock.")

;; set up syntax table
;;
;; TODO: figure out how to more correctly handle comments
;;
;; right now, we'll highlight (foo) as a comment (which is wrong).
;;
;; the commented out definitions require "( " and " )" for comments,
;; which would prevent issues like that.
;;
;; however, they would introduce two new problems:
;;
;;   1. tabs and especially newlines are also valid; it's not clear
;;      newlines can be used as a "second character" in syntax.
;;
;;   2. things like "( )" are legal comments but aren't handled
;;      correctly, since emacs thinks we want "(" and ")" to each have
;;      their own space character (rather than sharing the one).
;;
;; it's not clear to me that emacs syntax tables can precisely match
;; what we need. we could change how the mode works to tokenize the
;; entire file and _then_ highlight it but for now that's too heavy of
;; a lift.
;;
;; given all that tal-mode prefers to ensure all actual comments show
;; up correctly rather than "catching" situations where comments
;; aren't correctly padded. sorry! :/
(defvar tal-mode-syntax-table
  (let ((table (make-syntax-table))
        (c 0))
    (while (< c ?!)
      (modify-syntax-entry c " " table)
      (setq c (1+ c)))
    ;; treat almost all printable characters as word characters
    (while (< c 127)
      (modify-syntax-entry c "w" table)
      (setq c (1+ c)))
    ;;;; definitions to make commented regions stricter
    ;; (modify-syntax-entry ?\( "()1nb" table)
    ;; (modify-syntax-entry ?\) ")(4nb" table)
    ;; (modify-syntax-entry ?\s " 123" table)
    (modify-syntax-entry ?\( "<)nb" table)
    (modify-syntax-entry ?\) ">(nb" table)
    ;; delimiters, ignored by uxnasm
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    table)
  "Syntax table in use in `tal-mode' buffers.")

;; set up mode
(defun tal-mode ()
  "Major mode for editing Tal files"
  (interactive)
  (kill-all-local-variables)
  (set-syntax-table tal-mode-syntax-table)
  (use-local-map tal-mode-map)
  (set (make-local-variable 'font-lock-defaults) '(tal-font-lock-keywords-1 nil nil))
  (setq major-mode 'tal-mode)
  (make-local-variable 'comment-start)
  (make-local-variable 'comment-end)
  (setq comment-start "( ")
  (setq comment-end " )")
  (setq mode-name "Tal")
  (run-hooks 'tal-mode-hook))

;; set up M-x compile to call uxnasm
(add-hook 'tal-mode-hook
  (lambda ()
    (let* ((in (file-relative-name buffer-file-name))
           (out (concat (file-name-sans-extension in) ".rom")))
        (set (make-local-variable 'compile-command)
             (concat "uxnasm " in " " out)))))

;; regex to strip prefix from numbers like #99 |0100 $8
(defconst extract-number-re
  (rx (seq bot (opt (in "#|$")) (group (1+ (in "0-9a-f"))) eot)))

;; function to interpret hex numbers as decimal
(defun tal-decimal-value ()
  "Translate hexadecimal numbers to decimal"
  (interactive)
  (let ((word (current-word t t)))
    (if (eq word nil)
      (message "No word selected")
      (let ((m (string-match extract-number-re word)))
        (if (eq m nil)
          (message "`%s' is not a number" word)
          (let* ((s (match-string 1 word))
                 (n (string-to-number s 16)))
            (message "Decimal value of `%s' is %d" word n)))))))

;; provide mode
(provide 'tal-mode)
