;;; osx-org-clock-menubar.el --- simple menubar integration for org-clock  -*- lexical-binding: t; -*-

;; Copyright (C) 2015  Jordon Biondo

;; Author: Jordon Biondo <jordonbiondo@gmail.com>
;; Keywords: 

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

;;; Code:

(require 'org)


(defvar ocm-network-process nil
  "Network connection to the menubar server.
use `ocm-get-process' when using.")

(defvar ocm-network-port "65432"
  "Menubar server port string.")

(defvar ocm-network-host "127.0.0.1"
  "Host ip string.")

(defvar ocm-no-task-string "[-]"
  "What to display when there is no current task.")

(defvar ocm--last-sent-string ""
  "Used so we don't send updates when we don't need to.")

(defun ocm--make-process ()
  (setq ocm-network-process
        (open-network-stream "ocm-network-process"
                             (get-buffer-create "*ocm-network-process*")
                             ocm-network-host
                             ocm-network-port
                             :type 'plain)))

(defun ocm-get-process ()
  (or (and (processp ocm-network-process)
           (process-live-p ocm-network-process)
           ocm-network-process)
      (ocm--make-process)))

(defun ocm--string-for-task ()
  (if (and org-clock-menubar-mode org-clock-current-task)
      (org-clock-get-clock-string)
    ocm-no-task-string))

(defun ocm-update-menu-bar (string)
  (when (and t (not (equal ocm--last-sent-string string))
             (ocm-get-process))
    (setq ocm--last-sent-string string)
    (process-send-string (ocm-get-process) (format "%s\n" string))))
  
(define-minor-mode org-clock-menubar-mode
  "Minor mode to display the current org clock task and time in the OSX menu bar."
  :init-value nil
  :lighter "[]"
  :keymap nil
  :global t
  (when org-clock-menubar-mode
    (condition-case nil
        (ocm--make-process)
      (file-error (message "Could not connect to ocm-server on '%s:%s', are you sure it's running?"
                           ocm-network-host ocm-network-port)
                  (org-clock-menubar-mode -1))))
  (ignore-errors (ocm-update-menu-bar (ocm--string-for-task))))

(defun ocm--maybe-update-or-disable ()
  "If `org-clock-menubar-mode' is enabled, attempt to update the menu text.
If there is an error, `org-clock-menubar-mode' will be disabled."
  (when org-clock-menubar-mode
    (condition-case nil
        (ocm-update-menu-bar (ocm--string-for-task))
      (file-error
       (message "Error communicating with ocm-server, disabling `org-clock-menubar-mode'.")
       (org-clock-menubar-mode -1)))))

(defadvice org-clock-in (after ocm-update-clock-in activate)
  (ocm--maybe-update-or-disable))

(defadvice org-clock-out (after ocm-update-clock-out activate)
  (ocm--maybe-update-or-disable))

(provide 'osx-org-clock-menubar)
;;; osx-org-clock-menubar.el ends here

