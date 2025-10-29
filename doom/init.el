;;; init.el -*- lexical-binding: t; -*-

(doom! :completion
       vertico               ; simple and fast completion

       :ui
       doom                  ; Doom UI
       doom-dashboard        ; startup screen
       modeline              ; status bar
       (popup +defaults)     ; popup windows management

       :editor
       (evil +everywhere)    ; Vim keybindings

       :emacs
       dired                 ; file manager
       undo                  ; smarter undo
       
       :lang
       (org)                 ; Org-mode (no roam, only tasks)
       
       :config
       (default +bindings +smartparens))
