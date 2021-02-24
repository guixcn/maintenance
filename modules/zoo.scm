;;; Copyright © 2021 Peng Mei Yu <pengmyu@gmail.com>

(define-module (zoo)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services ssh)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages bash)
  #:use-module (ice-9 match)
  #:export (monkey
            zoo-service-type))

(define-record-type* <monkey> monkey make-monkey monkey?
  (name monkey-name)
  (comment monkey-comment (default ""))
  (uid monkey-uid (default #f))
  (group monkey-group (default "users"))
  (supplementary-groups  monkey-supplementary-groups (default '()))
  (shell monkey-shell (default (file-append bash "/bin/bash")))
  (ssh-public-key monkey-ssh-public-key))

(define (monkey->account monkey)
  (match monkey
    (($ <monkey> name comment uid group supplementary-groups shell _)
     (user-account
      (name name)
      (comment comment)
      (uid uid)
      (group group)
      (supplementary-groups supplementary-groups)
      (shell shell)))))

(define (monkey->authorized-key monkey)
  (list (monkey-name monkey)
        (monkey-ssh-public-key monkey)))

(define zoo-service-type
  (service-type
   (name 'zoo)
   (extensions
    (list (service-extension account-service-type
                             (lambda (lst)
                               (map monkey->account lst)))
          (service-extension openssh-service-type
                             (lambda (lst)
                               (map monkey->authorized-key lst)))))))
