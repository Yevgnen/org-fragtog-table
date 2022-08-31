;; -*- lexical-binding: t; -*-
;;; org-fragtog-table.el ---
;;
;; Copyright (C) 2017 Yevgnen Koh
;;
;; Author: Yevgnen Koh <wherejoystarts@gmail.com>
;; Version: 0.1.0
;; Keywords:
;; Package-Requires: ((emacs "27.1") (org "9.3") (org-fragtog "0.4.2"))
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;;; Commentary:
;;
;; Add Org table preview support for `org-fragtog'.
;;
;; See documentation on https://github.com/Yevgnen/org-fragtog-table.

;;; Code:

(require 'org-fragtog)

(defun org-fragtog-table-table-at-point ()
  (let* ((element (org-element-at-point))
         (type (org-element-type element)))
    (cond ((eq type 'table)
           element)
          ((eq type 'table-row)
           (org-element-property :parent element))
          (t nil))))

(defun org-fragtog-table-preview (table)
  (let* ((begin (org-element-property :begin table))
         (end (let ((pos (org-element-property :end table)))
                (goto-char pos)
                (while (looking-back "^[ \t\n]*" (line-beginning-position))
                  (forward-line -1)
                  (end-of-line))
                (end-of-line)
                (point)))
         (tabletxt (buffer-substring-no-properties begin end))
         (img (with-temp-buffer
                (insert tabletxt)
                (mark-whole-buffer)
                (org-latex-convert-region-to-latex)
                (org-preview-latex-fragment)
                (goto-char (point-min))
                (overlay-get (car (overlays-at (point))) 'display)))
         (overlay (make-overlay begin end)))
    (overlay-put overlay 'display img)
    (overlay-put overlay 'org-overlay-type 'org-latex-overlay)
    (forward-line -1)))

;;;###autoload
(defun org-fragtog-table-preview-at-point ()
  (interactive)
  (if-let ((table (org-fragtog-table-table-at-point)))
      (progn
        (org-fragtog-table-preview table)
        t)))

;;;###autoload
(defun org-fragtog-table-org-tables-in-buffer ()
  (interactive)
  (save-excursion
    (org-element-map (org-element-parse-buffer) 'table 'org-fragtog-table-preview)))

(defun org-fragtog-table--org-fragtog--cursor-frag (&rest args)
  (org-fragtog-table-table-at-point))

(defun org-fragtog-table--org-fragtog--enable-frag (frag)
  "Enable the Org LaTeX fragment preview for the fragment FRAG."

  ;; The fragment must be disabled before `org-latex-preview', since
  ;; `org-latex-preview' only toggles, leaving no guarantee that it's enabled
  ;; afterwards.
  (save-excursion
    (org-fragtog--disable-frag frag))

  ;; Move to fragment and enable
  (save-excursion
    (goto-char (org-fragtog--frag-start frag))
    ;; Org's "\begin ... \end" style LaTeX fragments consider whitespace
    ;; before the fragment as part of the fragment.
    ;; Some users overload `org-latex-preview' to functions with similar functionality,
    ;; such as `math-preview-at-point' from the `math-preview' package on MELPA.
    ;; These alternatives might get confused if they're asked to enable a fragment at
    ;; point when point is on whitespace before the fragment.
    ;; So, advance to the nearest non-whitespace character before enabling.
    (re-search-forward "[^ \t]")
    (or (org-fragtog-table-preview-at-point)
        (ignore-errors (org-latex-preview)))))

;;;###autoload
(define-minor-mode org-fragtog-table-mode
  "A minor mode that enables table preview by `org-fragtog' in Org mode."
  :init-value nil
  :global t
  (if org-fragtog-table-mode
      (progn
        (advice-add 'org-fragtog--cursor-frag :after-until #'org-fragtog-table--org-fragtog--cursor-frag)
        (advice-add 'org-fragtog--enable-frag :override #'org-fragtog-table--org-fragtog--enable-frag))
    (advice-remove 'org-fragtog--cursor-frag #'org-fragtog-table--org-fragtog--cursor-frag)
    (advice-remove 'org-fragtog--enable-frag #'org-fragtog-table--org-fragtog--enable-frag)))

(provide 'org-fragtog-table)

;;; org-fragtog-table.el ends here
