;;; anything-launcher.el --- Anything-based launcher

;; /home/mathias/doc/src/el/anything-launcher.el

;; Copyright (C) 2009 Mathias Dahl

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;; I am not sure I can claim copyright on all below as I have borrowed
;; things from various places in anything-config.el. Anyway, I'd
;; thought there should be a name there...

;;; Code:
(set-background-color "black")
(set-foreground-color "green")
(set-cursor-color "red")

(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)

(set-frame-font "-misc-fixed-medium-r-normal--13-*-*-*-c-70-iso8859-1")

;; A special title is needed so that we can fetch the window ID which
;; is needed by xdotool.

(setq frame-title-format "ANYTHING-LAUNCHER")

(setq server-name "anything-launcher")

(server-start)

(modify-frame-parameters
 (selected-frame)
 '((width . 179)
   (height . 45)
   (top . 150)
   (left . 1)))

(setq load-path (cons "/usr/share/emacs/site-lisp/" load-path))

;;; Commentary:
;; See http://www.emacswiki.org/emacs/AnythingLauncher

;;; History:
;; See http://github.com/brakjoller/anything-launcher

(require 'cl)
(require 'anything)

;; I like to use the full window

(setq anything-samewindow t)

;; Change some faces to match the colors better.

(set-face-attribute 'highlight nil :background "chocolate")
(set-face-attribute 'anything-header nil :background "grey40" :foreground "yellow")

;;;;
;;;; Action helpers
;;;;

(defun gnome-open (file)
  "Use `gnome-open' to open FILE."
  (shell-command (concat "gnome-open " (shell-quote-argument file))))

(defvar mp3-root "/home/mathias/mp3/artist/")

(defun open-artist (artist)
  "Open mp3 folder for ARTIST."
  (gnome-open (concat mp3-root artist)))

(defun play-mp3 (file)
  "Play FILE."
  (start-process "play-mp3" "*play-mp3*" "gmplayer"
		 (concat mp3-root file)))

(defun play-movie (file)
  "Play movie FILE."
  (start-process "play-movie" "*play-movie*" "mplayer"
		 (concat "/home/mathias/Videos/movies/" file)))

(defun terminal-open (folder)
  "Open FOLDER in terminal."
  (let ((default-directory (file-name-as-directory folder)))
    (start-process "rxvt" "*rxvt*" "rxvt")))

(defun open-common-url-from-name (name)
  "Open URL from NAME."
  (browse-url
   (let ((url (first (rassoc name (url-urls-names)))))
     (if (string-match "^https?://" url)
         url
       (concat "http://" url)))))

(defun terminal-run (command &rest args)
  "Run COMMAND with optional ARGS in terminal."
  (apply 'start-process (append (list "rxvt" "*rxvt*" "rxvt" "-e" command) args)))

(defun play-radio-from-name (name)
  "Listen to radio station NAME."
  (terminal-run "mplayer" (cadr (assoc name (list-radio)))))

(defun run (command &rest args)
  "Run COMMAND with optional ARGS."
  (apply 'start-process (append (list command "*run*" command) args)))

(defun run-command (name)
  "Run pre-defined command NAME.  See `list-commands'."
  (let ((stuff (cdr (assoc name (list-commands)))))
    (cond ((stringp stuff)
           (run stuff))
          ((eq (car stuff) 'lambda)
           (funcall stuff))
          ((and (listp stuff)
                (stringp (car stuff)))
           (apply 'run (append (list (car stuff)) (cdr stuff))))
          ((and (listp stuff)
                (eq (car stuff) 'tr))
           (apply 'terminal-run (cadr stuff) (cddr stuff)))
          (t
           (error "Don't know how to run %s" name)))))

;;;;
;;;; Candidate sources
;;;;

(defun find-mp3-file (pattern)
  "Quickly locate a mp3 file using PATTERN.
Uses a pre-generated file listing created by `find'"
  (with-temp-buffer
    (shell-command (concat "grep -i " (shell-quote-argument pattern)
                           " ~/mp3/.allmp3.no.root") t)
    (split-string (buffer-substring-no-properties
                     (point-min) (point-max)) "\n" t)))

(defun find-movies ()
  "Find all movie files."
  (with-temp-buffer
    (shell-command "find /home/mathias/Videos/movies -type f" t)
    (remove-if-not (lambda (x)
		     (string-match "\\.\\(avi\\|iso\\)" x))
		   (mapcar (lambda (x)
			     (substring x 28))
			   (split-string (buffer-substring-no-properties
					  (point-min) (point-max)) "\n" t)))))

(defun url-lines ()
  "List URL lines."
  (with-temp-buffer
    (insert-file-contents "~/.common-urls")
    (split-string (buffer-substring-no-properties
                   (point-min) (point-max)) "\n" t)))

(defun url-urls-names ()
  "Extract URLs and their names."
  (mapcar
   (lambda (x)
     (let ((y (split-string x "|")))
       (cons (first y) (second y))))
   (url-lines)))

(defun url-names ()
  "Extract URL names."
  (mapcar
   (lambda (x)
     (second
      (split-string x "|")))
   (url-lines)))

(defun list-radio ()
  "List radio stations.
The .radiorc file is on the following format:

STATION-NAME    URL

Example:

tags                http://somafm.com/startstream=tags.pls
unitedbreaks        http://74.52.13.138:8000"
  (with-temp-buffer
    (insert-file-contents "~/bin/.radiorc")
    (mapcar (lambda (x) (split-string x " " t))
            (split-string (buffer-substring-no-properties
                           (point-min) (point-max)) "\n" t))))

(defun radio-names ()
  "Get all radio station names."
  (mapcar 'first (list-radio)))

(defun list-commands ()
  "Various commands.
A simple string runs that command.

A list of strings run the first string as the command and uses
the rest as arguments.

A lambda results in a `funcall' of that lambda.

A list starting with `tr' will run the strings as a command in a
terminal."

  '(("Rtorrent" . (lambda () (let ((default-directory "~/Desktop/tmp/"))
                               (terminal-run "rtorrent"))))
    ("Emacs -Q" . ("emacs" "-Q"))
    ("Spotify" . ("wine" "C:\\Program Files\\Spotify\\spotify.exe"))
    ("Rxvt Terminal" . (lambda () (let ((default-directory "~/"))
                                    (run "rxvt"))))
    ("Gnome Terminal" . (lambda () (let ((default-directory "~/"))
                                     (run "gnome-terminal"))))
    ("Pidgin" . "pidgin")
    ("Gimp" . "gimp")
    ("Top" . (tr "top"))
    ("Tail Syslog Follow" . (tr "tail" "-f" "/var/log/syslog"))))

;;;;;;;;;;;;;;
;;;;;;;;;;;;;; SOURCES
;;;;;;;;;;;;;;


(defvar anything-c-source-mp3-artists
 '((name . "MP3 Artists")
   (candidates . (lambda ()
                   (directory-files
                    mp3-root nil "^[^.]")))
   (volatile)
   (action . (("Open directory in Nautilus" . open-artist)
              ("Open in terminal" .
               (lambda (x)
                 (terminal-open
                  (concat mp3-root x))))))))

(defvar anything-c-source-mp3-files
 '((name . "MP3 Songs")
   (candidates . (lambda ()
                   (find-mp3-file anything-pattern)))
   (volatile)
   (requires-pattern . 3)
   (action . (("Play mp3 file" . play-mp3)))))

(defvar anything-c-source-common-folders
  '((name . "Bookmarks")
    (candidates . (lambda ()
                    (with-temp-buffer
                      (insert-file-contents "~/.common-folders")
                      (split-string (buffer-substring-no-properties
                                     (point-min) (point-max)) "\n" t))))
    (action . (("Open with Gnome" . gnome-open)
               ("Open in terminal" . terminal-open)))))

(defvar anything-c-source-movies
 '((name . "Movies")
   (candidates . find-movies)
   (action . (("Show movie" . play-movie)))))

(defvar anything-c-source-urls
 '((name . "Web Sites")
   (candidates . url-names)
   (action . (("Open URL" . open-common-url-from-name)))))

(defvar anything-c-source-radio
 '((name . "Radio")
   (candidates . radio-names)
   (action . (("Play radio" . play-radio-from-name)))))

(defvar anything-c-source-commands
 '((name . "Commands")
   (candidates . (lambda () (mapcar 'car (list-commands))))
   (action . (("Execute command" . run-command)))))

(defvar anything-c-source-special
 '((name . "Special Commands")
   (candidates . ("Cancel" "Quit"))
   (action . (("Cancel" .
               (lambda (x)
                 (cond ((string= x "Cancel")
                        (message "Canceled" x))
                       ((string= x "Quit")
                        (let ((kill-emacs-hook nil))
                          (kill-emacs))))))))))

;;;;
;;;; The launcher itself
;;;;

(defun anything-launcher ()
  "Main launcher."
  (interactive)
  (let ((anything-sources
         (list
          anything-c-source-special
          anything-c-source-commands
          anything-c-source-common-folders
          anything-c-source-urls
          anything-c-source-movies
          anything-c-source-radio
          anything-c-source-mp3-files
          anything-c-source-mp3-artists
          )))
        (call-interactively 'anything)))


(provide 'anything-launcher)

;;; anything-launcher.el ends here
