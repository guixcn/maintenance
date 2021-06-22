;;; Copyright © 2020-2021 Peng Mei Yu <pengmyu@gmail.com>

(use-modules (gnu)
             (gnu packages)
             (gnu system)
             (guix store)
             (zoo))

(use-package-modules bash linux shells)
(use-service-modules desktop networking nix ssh sysctl web linux)

(include "monkeys.scm")
(include "web.scm")


(define %motd
  (plain-file "motd"
              "\x1b[1;37mWelcome to the Guix China server!\x1b[0m\n\n"))

(define %root-ssh-public-key
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICGixg7L7vRFgmxBS2GmI4/UqPw7pERi3qbKFUPaEZIF")

(define %bots
  (list (bot
         (name "github")
         (comment "GitHub bot")
         (shell (file-append bash "/bin/bash"))
         (ssh-public-key
          (plain-file "github.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDDcJqdm4yqZdcz4IAN00gEkHf7XU1+IH0ehiFi0CZWU")))))

(define %substitute-urls
  (append '("https://mirror.sjtu.edu.cn/guix")
          %default-substitute-urls))

(define-public %packages
  (append
   %base-packages
   (map (compose list specification->package+output)
        '("bind:utils" "btrfs-progs" "certbot" "curl" "dosfstools" "emacs"
          "fish" "git" "gnupg" "guile-readline" "htop" "iftop" "ncurses"
          "neofetch" "nftables" "nss-certs" "openssh" "pinentry" "python"
          "rsync" "stow" "tmux" "tree" "wget" "zsh" ))))

(define %services
  (append
   (list
    (service elogind-service-type)
    (service dhcp-client-service-type)
    (service nftables-service-type
             (nftables-configuration (ruleset (local-file "nftables.conf"))))
    (service nix-service-type)
    (service openssh-service-type
             (openssh-configuration
              (permit-root-login 'prohibit-password)
              (password-authentication? #f)
              (authorized-keys
               `(("root" ,(plain-file "authorized_keys"
                                      %root-ssh-public-key))))))
    (service guix-publish-service-type
             (guix-publish-configuration
              (port 8181)
              (cache "/var/cache/guix/publish")
              (compression '(("lzip" 9)))
              (ttl (* 30 24 60 60))))
    (service zoo-service-type (append %bots %monkeys))
    (service earlyoom-service-type)
    (simple-service 'sysctl-settings sysctl-service-type
                    '(("net.core.default_qdisc" . "fq")
                      ("net.ipv4.tcp_congestion_control" . "bbr"))))
   %web-services
   (modify-services %base-services
     (guix-service-type
      config => (guix-configuration
                 (inherit config)
                 (substitute-urls %substitute-urls)
                 (extra-options '("--max-jobs" "4"))))
     (login-service-type
      config => (login-configuration
                 (inherit config)
                 (motd %motd))))))

(operating-system
  (host-name "shanghai.guix.org.cn")
  (timezone "Asia/Shanghai")
  (locale "en_US.UTF-8")

  (kernel linux-libre-lts)

  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (target "/dev/vda")))

  (file-systems (cons* (file-system
                         (device "/dev/vda1")
                         (mount-point "/")
                         (type "ext4"))
                       (file-system
                         (device "/dev/vdb1")
                         (mount-point "/srv")
                         (type "btrfs")
                         (options "compress=zstd"))
                       (file-system
                         (device "/dev/vdb1")
                         (mount-point "/home")
                         (type "btrfs")
                         (options "compress=zstd,subvol=home"))
                       %base-file-systems))

  (swap-devices '("/var/swapfile"))

  (users %base-user-accounts)

  (hosts-file
   (plain-file "hosts"
               (string-append (local-host-aliases host-name)
                              "127.0.0.1 mirror.guix.org.cn")))

  (packages %packages)

  (services %services))
