;;; Copyright © 2020 Peng Mei Yu <pengmyu@gmail.com>

(use-modules (gnu)
             (gnu packages)
             (gnu system)
             (guix store))

(use-package-modules shells)
(use-service-modules networking ssh sysctl web)

(include "web.scm")


(define %motd
  (plain-file "motd"
              "\x1b[1;37mWelcome to the Guix China server!\x1b[0m\n\n"))

(define %ssh-public-key
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCj1ZPwtIShm3hMX7/uw151jVZeg927viEakb12/FTQ+gj+wmbEvnsjFvavLZ+u0e2yqijK0b/i/ptcJ/o1duNs228N4Nqib55HXPSsmq6nwOYyMk7DQc2KcjzCRPgqUsiQeFFKkDoWZGS5C7sJCO5QDfYIpfMSwKOSJM2TipdkWJlioP4xTS9ma+KtkNMc/B2ceMXRRyepF4DgaySOALE0dx1xcglwMKrqf9f7e1ceyc9sFNJRLEa5p9tvGWRmTNcb/WWybc1RHrxuUA7onB0MhqHYJgYpUy3q/kHk3vIeKLdATBILIPlj3uwwW62R0H6a3eKxqIwmL34hD+O/3D+WrtPWpTw4aRqoSyIH+tWnvKGz08yFlxcxkmxxwA1oXsTkRXXO6Wi3VJoWdcD6FIfknBj+m/v7veGECeavLSX5p3SLFQkftU62l82mNE7M/4yr2uXqRsSeHoQLarBaij+2eQilcOsVzxDD53xdSibPvz+jmSss+6WYqowyBuAimIQq9z6N2yzkfc772SwLDpab5AvLKNfmKQJXpZD+uT/cA5LiCcmo72CAJkp8e6OQqqtGpbVsFxRTf5uPlk8xC12RxBQzHpG0F8/ltLIBDvypktMBJ69hxI6yq9HjjMAK467VxHP1DeYtcr1KZNnVo0oQWBILuhMTtfpMf/m5LmS7yw== meiyu")

(define %substitute-urls
  '("https://mirror.guix.org.cn"))

(define-public %packages
  (append
   %base-packages
   (map (compose list specification->package+output)
        '("bind:utils" "btrfs-progs" "certbot" "curl" "dosfstools" "emacs"
          "fish" "git" "gnupg" "guile-readline" "htop" "iftop" "nftables"
          "nss-certs" "openssh" "pinentry" "python" "rsync" "stow" "tmux"
          "tree" "wget" "zsh"
          "termite"))))

(define %services
  (cons*
   (service dhcp-client-service-type)
   (service nftables-service-type
            (nftables-configuration (ruleset (local-file "nftables.conf"))))
   (service openssh-service-type
            (openssh-configuration
             (permit-root-login 'without-password)
             (password-authentication? #f)
             (authorized-keys
              `(("root" ,(plain-file "authorized_keys"
                                     %ssh-public-key))
                ("meiyu" ,(plain-file "authorized_keys"
                                      %ssh-public-key))))))
   (service sysctl-service-type
            (sysctl-configuration
             (settings '(("net.core.default_qdisc" . "fq")
                         ("net.ipv4.tcp_congestion_control" . "bbr")))))
   (service guix-publish-service-type
            (guix-publish-configuration
             (port 8181)
             (cache "/var/cache/guix/publish")
             (compression '(("lzip" 9)))
             (ttl (* 30 24 60 60))))
   (service certbot-service-type %certbot-configuration)
   (service nginx-service-type %nginx-configuration)
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
  (host-name "pangu.guix.org.cn")
  (timezone "Asia/Shanghai")
  (locale "en_US.UTF-8")

  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (target "/dev/vda")))

  (file-systems (cons* (file-system
                         (device "/dev/vda1")
                         (mount-point "/")
                         (type "ext4"))
                       %base-file-systems))

  (users (cons (user-account
                (name "meiyu")
                (comment "Peng Mei Yu")
                (group "users")
                (supplementary-groups '("wheel"))
                (shell (file-append zsh "/bin/zsh")))
               %base-user-accounts))

  (hosts-file
   (plain-file "hosts"
               (string-append (local-host-aliases host-name)
                              "127.0.0.1 mirror.guix.org.cn")))

  (packages %packages)

  (services %services))
