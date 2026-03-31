;;; zenote.el --- A minimalist note based on org  -*- lexical-binding: t -*-

;;; Copyright (C) 2023 GZJ

;; Author: GZJ <gzj00@outlook.com>
;; Keywords: note
;; Version: 1.0.1

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

;; zenote is a minimalist note based on org.

;;; Code:
;;;; ------------------ require ------------------------------
(require 'org)

;;;; ------------------ customize ------------------------------
(defgroup zenote nil
  "zenote group"
  :group 'note)

(defcustom zenote-path ""
  "zenote path"
  :type 'string
  :group 'zenote)

(defcustom zenote-window-width 400
  "zenote path"
  :group 'zenote)

;;;; ------------------ variables ------------------------------
(defvar-local zenote-visual-active nil "Whether visual line mode is active.")
(defvar-local zenote-visual-anchor nil "The anchor line number for visual selection.")
(defvar-local zenote-visual-overlays nil "Overlays for visual selection highlighting.")

(defface zenote-visual-selection-face
  '((t :background "#3a3a5a" :extend t))
  "Face for visual line selection in zenote tree."
  :group 'zenote)

;;;; ------------------  mode ------------------------------
;;;; mode keymap
(defvar zenote-tree-mode-map nil "Keymap for `zenote-tree-mode'")
(progn
  (setq zenote-tree-mode-map (make-sparse-keymap))
  (define-key zenote-tree-mode-map (kbd "<return>") 'zenote-item-open)
  (define-key zenote-tree-mode-map (kbd "j") 'zenote-item-next)
  (define-key zenote-tree-mode-map (kbd "k") 'zenote-item-prev)
  (define-key zenote-tree-mode-map (kbd "d") 'zenote-item-delete-confirm)
  (define-key zenote-tree-mode-map (kbd "D") 'zenote-item-delete)
  (define-key zenote-tree-mode-map (kbd "r") 'zenote-item-rename)
  (define-key zenote-tree-mode-map (kbd "i") 'zenote-item-insert-next)
  (define-key zenote-tree-mode-map (kbd "I") 'zenote-item-insert-prev)
  (define-key zenote-tree-mode-map (kbd "J") 'zenote-item-move-down)
  (define-key zenote-tree-mode-map (kbd "K") 'zenote-item-move-up)
  (define-key zenote-tree-mode-map (kbd "G") 'zenote-tree-update)
  (define-key zenote-tree-mode-map (kbd "V") 'zenote-visual-enter)
  (define-key zenote-tree-mode-map (kbd "y") 'zenote-yank-files)
  (define-key zenote-tree-mode-map (kbd "<escape>") 'zenote-visual-exit)
  )

;;;###autoload
(define-derived-mode zenote-mode org-mode
  "zenote"
  )

;;;###autoload
(define-derived-mode zenote-tree-mode org-mode
  "zenote-tree"
  (use-local-map zenote-tree-mode-map)
  )

;;;; ------------------ function ------------------------------
(defun zenote-tree-open(path)
  (interactive)
  (unless (and path (file-directory-p path))
    (error "Invalid or missing path"))
  (customize-set-variable 'zenote-path path)
  (let ((new-buffer (generate-new-buffer "zenote-tree"))
	(p (expand-file-name path))
	)
    (with-current-buffer new-buffer
      (zenote-tree-insert p)
      (cd p)
      (read-only-mode 1)
      (zenote-tree-mode)
      )
    (setq w (display-buffer-in-side-window new-buffer '((side . left)) ))
    (set-window-parameter w  'no-delete-other-windows t)
    (set-window-parameter w 'window-width  zenote-window-width)
    (set-window-dedicated-p w t)
    )
  )

(defun zenote-tree-insert (path)
  (setq org-files-list (directory-files path nil "\\.org$"))
  (dolist (org-file org-files-list)
    (let ((file-name-no-ext (file-name-sans-extension org-file)))
      (insert file-name-no-ext)
      (newline)
      )
    )
  )

(defun zenote-tree-update()
  (interactive)
  (let ((inhibit-read-only t)
        (inhibit-redisplay t)
        (inhibit-modification-hooks t))
    (font-lock-mode -1)
    (erase-buffer)
    (zenote-tree-insert zenote-path)
    (font-lock-mode 1)
    )
  )

;;;; ------------------ function item ------------------------------
(defun zenote-item-open()
  (interactive)
  (let ((item (zenote-item-read-to-org-path))
	)
    (select-window  (window-right (selected-window)))
    (find-file item)
    (zenote-mode)
    )
  )

(defun zenote-item-insert-prev()
  (interactive)
  (let ((inhibit-read-only t)
	(note-name (read-string "note name:"))
	)
    (save-excursion (goto-char (line-beginning-position)) (insert note-name) (newline))
    (select-window  (window-right (selected-window)))
    (find-file (zenote-item-to-org-path note-name))
    )
  )

(defun zenote-item-insert-next()
  (interactive)
  (let ((inhibit-read-only t)
	(note-name (read-string "note name:"))
	)
    (save-excursion (goto-char (line-end-position)) (newline) (insert note-name))
    (select-window  (window-right (selected-window)))
    (find-file (zenote-item-to-org-path note-name))
    )
  )

(defun zenote-item-rename()
  (interactive)
  (let ((inhibit-read-only t)
	(old-name (zenote-item-read-to-org-path))
	(new-name (read-string "new note name:"))
	)
    (rename-file old-name (zenote-item-to-org-path new-name))
    (beginning-of-line)
    (kill-line)
    (insert new-name)
    )
  )

(defun zenote-item-move-up()
  (interactive)
  (let ((inhibit-read-only t))
    (zenote-move-current-line-up)
    )
  )

(defun zenote-item-move-down()
  (interactive)
  (let ((inhibit-read-only t))
    (zenote-move-current-line-down)
    )
  )

(defun zenote-move-current-line-up ()
  (interactive)
  (let ((col (current-column)))
    (transpose-lines 1)
    (previous-line 2)
    (move-to-column col)
    )
  )

(defun zenote-move-current-line-down ()
  (interactive)
  (let ((col (current-column)))
    (next-line)
    (transpose-lines 1)
    (previous-line 1)
    (move-to-column col)
    )
  )

(defun zenote-item-read()
  (string-trim-right (thing-at-point 'line t)) ;;string-trim-right delete newline character
  )

(defun zenote-item-read-to-org-path()
  (zenote-item-to-org-path (zenote-item-read))
  )

(defun zenote-item-to-org-path(item)
  (concat (file-name-as-directory zenote-path) (concat item ".org"))
  )

(defun zenote-item-delete()
  (interactive)
  (let ((inhibit-read-only t)
	(note (zenote-item-read-to-org-path))
	)
    (setq delete-by-moving-to-trash t)
    (delete-file note t)
    (beginning-of-line)
    (kill-line)
    (kill-line)  ;;delete line break
    (message (format "note %s deleted" note))
    )
  )

(defun zenote-item-delete-confirm()
  (interactive)
  (if (y-or-n-p "Are you sure you want to delete the note?")
      (zenote-item-delete)
    (message "Deletion canceled"))
  )

(defun zenote-item-next()
  (interactive)
  (forward-line 1)
  (when zenote-visual-active
    (zenote-visual-update))
  )

(defun zenote-item-prev()
  (interactive)
  (forward-line -1)
  (when zenote-visual-active
    (zenote-visual-update))
  )

;;;; ------------------ visual line mode ------------------------------
(defun zenote-visual-enter ()
  "Toggle visual line selection mode."
  (interactive)
  (if zenote-visual-active
      (zenote-visual-exit)
    (setq zenote-visual-active t)
    (setq zenote-visual-anchor (line-number-at-pos))
    (zenote-visual-update)
    (message "-- VISUAL LINE --")))

(defun zenote-visual-exit ()
  "Exit visual line selection mode."
  (interactive)
  (setq zenote-visual-active nil)
  (setq zenote-visual-anchor nil)
  (zenote-visual-clear-overlays)
  (message ""))

(defun zenote-visual-clear-overlays ()
  "Clear all visual selection overlays."
  (mapc #'delete-overlay zenote-visual-overlays)
  (setq zenote-visual-overlays nil))

(defun zenote-visual-update ()
  "Update the visual selection highlighting."
  (zenote-visual-clear-overlays)
  (when zenote-visual-active
    (let* ((current (line-number-at-pos))
           (start (min zenote-visual-anchor current))
           (end (max zenote-visual-anchor current)))
      (save-excursion
        (goto-char (point-min))
        (forward-line (1- start))
        (dotimes (_ (1+ (- end start)))
          (let ((ov (make-overlay (line-beginning-position)
                                  (min (1+ (line-end-position)) (point-max)))))
            (overlay-put ov 'face 'zenote-visual-selection-face)
            (push ov zenote-visual-overlays))
          (forward-line 1))))))

(defun zenote-visual-get-selected-items ()
  "Get list of items in the visual selection, or current item if no selection."
  (let (items)
    (if zenote-visual-active
        (let* ((current (line-number-at-pos))
               (start (min zenote-visual-anchor current))
               (end (max zenote-visual-anchor current)))
          (save-excursion
            (goto-char (point-min))
            (forward-line (1- start))
            (dotimes (_ (1+ (- end start)))
              (let ((item (string-trim-right (thing-at-point 'line t))))
                (when (and item (not (string-empty-p item)))
                  (push item items)))
              (forward-line 1))))
      (let ((item (zenote-item-read)))
        (when (and item (not (string-empty-p item)))
          (push item items))))
    (nreverse items)))

(defun zenote-yank-files ()
  "Copy selected file contents (or current file) to clipboard."
  (interactive)
  (let* ((items (zenote-visual-get-selected-items))
         (contents ""))
    (dolist (item items)
      (let ((src (zenote-item-to-org-path item)))
        (when (file-exists-p src)
          (setq contents (concat contents (with-temp-buffer
                                            (insert-file-contents src)
                                            (buffer-string)) "\n")))))
    (kill-new (string-trim-right contents))
    (when zenote-visual-active
      (zenote-visual-exit))
    (message "Copied %d file(s) content to clipboard" (length items))))

(provide 'zenote)
