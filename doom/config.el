;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Set theme
(setq doom-theme 'doom-gruvbox)

;; Enable line numbers
(setq display-line-numbers-type t)

;; Org-mode directory
(setq org-directory "~/org/")

;; Org agenda files (all .org files inside org-directory)
(setq org-agenda-files (directory-files-recursively "~/org/" "\\.org$"))

;; Default directory
(setq default-directory "~/org/")

;; Set font
(setq doom-font (font-spec :family "MesloLGSNerdFontMono" :size 12)
      doom-variable-pitch-font (font-spec :family "MesloLGSNerdFontMono" :size 12))
