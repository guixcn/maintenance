;;; Copyright © 2021-2023 Peng Mei Yu <pmy@xqzp.net>

(define-module (zoo)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services ssh)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages bash)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (bot
            monkey
            zoo-service-type))

(define-record-type* <bot> bot make-bot bot?
  (name bot-name)
  (comment bot-comment (default "bot"))
  (uid bot-uid (default #f))
  (group bot-group (default "bots"))
  (supplementary-groups bot-supplementary-groups (default '()))
  (home-directory bot-home-directory (default "/var/empty"))
  (shell bot-shell (default (file-append shadow "/sbin/nologin")))
  (ssh-public-key bot-ssh-public-key (default #f))
  (system? system? (default #t)))

(define-record-type* <monkey> monkey make-monkey monkey?
  (name monkey-name)
  (comment monkey-comment (default "monkey"))
  (uid monkey-uid (default #f))
  (group monkey-group (default "users"))
  (supplementary-groups monkey-supplementary-groups (default '()))
  (shell monkey-shell (default (file-append bash "/bin/bash")))
  (ssh-public-key monkey-ssh-public-key))

(define (animal->account animal)
  (match animal
    (($ <bot> name comment uid group supplementary-groups home-directory shell
              ssh-public-key system?)
     (user-account
      (name name)
      (comment comment)
      (uid uid)
      (group group)
      (supplementary-groups supplementary-groups)
      (home-directory home-directory)
      (shell shell)
      (system? system?)))
    (($ <monkey> name comment uid group supplementary-groups shell
                 ssh-public-key)
     (user-account
      (name name)
      (comment comment)
      (uid uid)
      (group group)
      (supplementary-groups supplementary-groups)
      (shell shell)))))

(define (animal->authorized-key animal)
  (match animal
    (($ <bot> name comment uid group supplementary-groups home-directory shell
              ssh-public-key system?)
     (if ssh-public-key
         (list name ssh-public-key)
         #f))
    (($ <monkey> name comment uid group supplementary-groups shell
                 ssh-public-key)
     (if ssh-public-key
         (list name ssh-public-key)
         #f))))

(define %zoo-accounts
  (list (user-group
         (name "bots")
         (system? #t))))

(define zoo-service-type
  (service-type
   (name 'zoo)
   (extensions
    (list (service-extension account-service-type
                             (lambda (lst)
                               (append %zoo-accounts
                                       (map animal->account lst))))
          (service-extension openssh-service-type
                             (lambda (lst)
                               (filter-map animal->authorized-key lst)))))
   (description "User accounts.")))
