;;;
;;; Copyright (C) 2009 The Android Open Source Project
;;;
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;;
;;;      http://www.apache.org/licenses/LICENSE-2.0
;;;
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.

;;; Helper functions to compile Android file within emacs.
;;; In your .emacs load this file (e.g (require 'android-compile)) then:
;;;
;;;   (add-hook 'c++-mode-hook 'android-compile)
;;;   (add-hook 'java-mode-hook 'android-compile)
;;; and/or
;;;   (global-set-key [f9] 'android-compile)


;; TODO: Maybe we could cache the result of the compile function in buffer local vars.

(require 'compile)

(defun android-find-build-tree-root ()
  "Ascend the current path until the root of the android build tree is found.
Similarly to the shell functions in envsetup.sh, for the root both ./Makefile
and ./build/core/envsetup.mk are exiting files.
Return the root of the build tree. Signal an error if not found."
  (let ((default-directory default-directory))
    (while (and (> (length default-directory) 2)
                (not (file-exists-p (concat default-directory "Makefile")))
                (not (file-exists-p (concat default-directory "build/core/envsetup.mk"))))
      (setq default-directory
            (substring default-directory 0
                       (string-match "[^/]+/$" default-directory))))
    (if (> (length default-directory) 2)
        default-directory
      (error "Not in a valid android tree."))))

(defun android-find-makefile (topdir)
  "Ascend the current path until an Android makefile is found.
Makefiles are named Android.mk except in the root directory where
the file is named Makefile.
TOPDIR is the root directory of the build.
Return a list with 2 elements (MAKEFILE_PATH IS_ROOT_MAKEFILE).
Signal an error if no Makefile was found."
  ; TODO: Could check that topdir is the start of default-directory.
  (if (not (> (length topdir) 2))
      (error "Topdir invalid %s for current dir %s" topdir default-directory))
  (let ((default-directory default-directory))
    ; Ascend the path.
    (while (and (> (length default-directory) (length topdir))
                (not (file-exists-p (concat default-directory "Makefile")))
                (not (file-exists-p (concat default-directory "Android.mk"))))
      (setq default-directory
            (substring default-directory 0
                       (string-match "[^/]+/$" default-directory))))
    ; Top dir has a Makefile, otherwise Android.mk files.
    (if (file-exists-p (concat default-directory "Makefile"))
        (list (substring (concat default-directory "Makefile")
                         (length topdir) nil) t)
      (if (file-exists-p (concat default-directory "Android.mk"))
          (list (substring (concat default-directory "Android.mk")
                           (length topdir) nil) nil)
        (error "Not in a valid android tree.")))))

(defun android-project-p ()
"Return nil if not in an android build tree."
  (condition-case nil
      (android-find-build-tree-root)
    (error nil)))

;; TODO: Cannot pass additional flags (e.g -j4).
(defun android-compile ()
  "Elisp equivalent of mm shell function.
Walk up the path until a makefile is found and build it.
You need to have a proper buildspec.mk in your top dir."
  (interactive)
  (if (android-project-p)
      (let* ((topdir (android-find-build-tree-root))
             (makefile (android-find-makefile topdir)))
        (if (not (file-exists-p (concat topdir "buildspec.mk")))
            (error "buildspec.mk missing in %s." topdir))
        (set (make-local-variable 'compile-command)
             (if (cadr makefile)
                 ;; The root Makefile is not invoked using ONE_SHOT_MAKEFILE.
                 (concat "make -C " topdir " files ")
               (concat "ONE_SHOT_MAKEFILE=" (car makefile)
                       " make -C " topdir " files ")))
        (if (interactive-p)
            (compile compile-command)))))

(provide 'android-compile)
