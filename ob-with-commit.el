;; Heavily borrowed from ob-async.el
(defun get-dir()
  "Get :dir from header of source block"
  (setq ob-wc-shell-dir (cdr (assoc :dir (nth 2 (or info (org-babel-get-src-block-info))))))
  (message "dir is currently %s" ob-wc-shell-dir)
  (if (eq ob-wc-shell-dir nil)
      (concat (replace-regexp-in-string "\n$" "" (shell-command-to-string "pwd")) "/")
    (expand-file-name ob-wc-shell-dir)))
  

(defun ob-with-commit (&optional orig-fun arg info params)
  "Calls  org-babel-execute-src-block after checking for valid git repo and commit."
  (interactive "P")
  (cond
   ;; If this function is not called as advice, do nothing
   ((not orig-fun)
    (warn "ob-with-commit does nothing")
    nil)
   ;; If there is no :vc parameter, call the original function
   ((not (assoc :vc
                (nth 2
                     (or info
                         (org-babel-get-src-block-info)))))
    (funcall orig-fun arg info params))
   ;; Otherwise, check for git repos
   (t
    (let ((dirparam (get-dir))
          (vcparam (cdr (assoc :vc (nth 2 (or info (org-babel-get-src-block-info)))))))

      (if (not (eq vcparam nil))
          ;; Check if in git repo
          (progn
            (setq git-repo-p (shell-command-to-string (format "git -C %s rev-parse" dirparam)))
            (if git-repo-p
                ;; execute checkout
                (progn
                  ;; 1. Get current commit
                  (setq original-state (get-current-commit dirparam))
                  (message "os: %s" original-state)
                  ;; 2. checkout vcparam
                  (setq git-response
                        (shell-command-to-string
                         (format "git --git-dir=%s.git --work-tree=%s checkout %s"
                                 dirparam
                                 dirparam
                                 vcparam)))
                  ;; 3. If successful, continue with execution...
                  (if (not (or (eq "error:" (car (split-string git-response)))
                               (eq "fatal:" (car (split-string git-response)))))
                      (progn
                        (funcall orig-fun arg info params)
                        ;; Finally: reset to original commit
                        ;; NOTE: I am storing original state, so if that isn't
                        ;; master, it would make sense to switch to it.
                        (shell-command-to-string
                         (format "git --git-dir=%s.git --work-tree=%s checkout master"
                                 dirparam
                                 dirparam
                                 )))
                    ;; else, print message, continue with execution
                    (progn (message "Git checkout failed")
                           (funcall orig-fun arg info params))))))
        (funcall orig-fun arg info params))))))

(defun get-current-commit (dirparam)
  "Returns commit hash of current state of repo at DIRPARAM."
  (car (split-string (shell-command-to-string
                      (format "git --git-dir=%s.git show --oneline -s"
                              dirparam)))))

(advice-add 'org-babel-execute-src-block :around 'ob-with-commit)
