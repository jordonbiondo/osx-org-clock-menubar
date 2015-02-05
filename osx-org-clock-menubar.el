;;; osx-org-clock-menubar.el --- simple menubar integration for org-clock

;; Copyright (C) 2015  Jordon Biondo

;; Author: Jordon Biondo <jordonbiondo@gmail.com>
;; Version: 0.1.1
;; Keywords: org, osx
;; URL: https://github.com/jordonbiondo/osx-org-clock-menubar
;; Package-Requires: ()
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This tool will display your current org-clock task in the osx menubar
;; like org-clock displays it in the modeline
;;
;; The server that displays items in the menubar requires MacRuby to be
;; installed.
;;
;; You can run the server process external of emacs or as a subprocess
;;
;; Simpley run M-x `org-clock-menubar-mode' to start things off, you will be
;; prompted to start the server if it is not running.
;;
;; If you would not like to be prompted, set `ocm-start-server-no-prompt' to t.
;;
;; Disabling `org-clock-menubar-mode' does not stop the server, if you  would
;; like to kill the subprocess use `ocm-stop-emacs-server-process'.
;;

;;; Code:

(require 'org)

(defvar ocm-network-process nil
  "Network connection to the menubar server.
use `ocm-get-process' when using.")

(defvar ocm-network-port "65432"
  "Menubar server port string.")

(defvar ocm-network-host "127.0.0.1"
  "Host ip string.")

(defvar ocm-start-server-no-prompt nil
  "When non-nil, the server will be started from within emacs a prompt.
If one already exists outside of emacs, it will be used instead.")

(defvar ocm-no-task-string "[-]"
  "What to display when there is no current task.")

(defvar ocm--server-process nil)

(defvar ocm--last-sent-string ""
  "Used so we don't send updates when we don't need to.")

(defvar ocm--timer nil)

(defvar ocm-server-file ""
  "The path to the ocm-server.rb file.")

(defun ocm--make-process ()
  "Return a new network process that connects to the ocm-server."
  (setq ocm-network-process
        (open-network-stream
         "ocm-network-process"
         (get-buffer-create "*ocm-network-process*")
         ocm-network-host
         ocm-network-port
         :type 'plain)))

(defun ocm--get-process ()
  "Return the current ocm process or create a new one if needed."
  (or (and (processp ocm-network-process)
           (process-live-p ocm-network-process)
           ocm-network-process)
      (ocm--make-process)))

(defun ocm--string-for-task ()
  "Return the string that will be displayed in the menu bar."
  (if (and org-clock-menubar-mode org-clock-current-task)
      (org-clock-get-clock-string)
    ocm-no-task-string))

(defun ocm--update-menu-bar (string)
  "Send STRING to be displayed on the menu bar."
  (when (and t (not (equal ocm--last-sent-string string))
             (ocm--get-process))
    (setq ocm--last-sent-string string)
    (process-send-string (ocm--get-process) (format "%s\n" string))))

(defun ocm--try-starting-server-in-emacs ()
  (cond
   ((and (processp ocm--server-process) (process-live-p ocm--server-process))
    (message "Org clock menubar server is already running!."))
   ((not (executable-find "macruby"))
    (message "`osx-org-clock-menubar' requires macruby to be installed."))
   ((not (and ocm-server-file (file-exists-p ocm-server-file)))
    (message "Cannot find server file, please specify the path in the `ocm-server-file' variable."))
   (t (setq ocm--server-process
            (start-process
             "ocm-server"
             "*ocm-server*"
             "macruby" ocm-server-file))))
  (ocm--emacs-server-live-p))

(defun ocm--kill-server-process ()
  (and (processp ocm--server-process)
       (kill-process ocm--server-process)))

(defun ocm--emacs-server-live-p ()
  (and (processp ocm--server-process)
       (process-live-p ocm--server-process)))

(define-minor-mode org-clock-menubar-mode
  "Minor mode to display the current org clock task and time in the OSX menu bar."
  :init-value nil
  :lighter "[]"
  :keymap nil
  :global t
  (when org-clock-menubar-mode
    (condition-case nil
        (ocm--make-process)
      (file-error
       (if (and (not (ocm--emacs-server-live-p))
                (yes-or-no-p (format "Could not connect to ocm-server on '%s:%s', would you ilke to start the server in emacs? "
                                     ocm-network-host ocm-network-port))
                (ocm--try-starting-server-in-emacs))
           (run-with-timer 1 nil 'ocm--maybe-update-or-disable)
         (org-clock-menubar-mode -1)))))
  (ignore-errors (ocm--update-menu-bar (ocm--string-for-task)))
  (ocm--setup-org-hooks)
  (ocm--configure-timer))

(defun ocm-stop-emacs-server-process ()
  "If the ocm server is running inside emacs, stop it."
  (interactive)
  (ocm--kill-server-process))

(defalias 'oxs-org-clock-menubar-mode 'org-clock-menubar-mode)

(defun ocm--maybe-update-or-disable ()
  "If `org-clock-menubar-mode' is enabled, attempt to update the menu text.
If there is an error, `org-clock-menubar-mode' will be disabled."
  (when org-clock-menubar-mode
    (condition-case nil
        (ocm--update-menu-bar (ocm--string-for-task))
      (file-error
       (message "Error communicating with ocm-server, disabling `org-clock-menubar-mode'.")
       (org-clock-menubar-mode -1)))))

(defun ocm--setup-org-hooks ()
  (dolist (hook '(org-clock-in-hook org-clock-out-hook))
    (add-to-list hook 'ocm--maybe-update-or-disable)))

(defun ocm--configure-timer ()
  "Run or stop running a timer to update the menu bar appropriately."
  (when (timerp ocm--timer) (cancel-timer ocm--timer))
  (when org-clock-menubar-mode
    (setq ocm--timer (run-with-timer 15 15 'ocm--maybe-update-or-disable))))

(when load-file-name
  (setq ocm-server-file (concat (expand-file-name
                                 (file-name-directory load-file-name))
                                "ocm-server.rb")))

(provide 'osx-org-clock-menubar)
;;; osx-org-clock-menubar.el ends here

