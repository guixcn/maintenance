(use-modules (guix gexp)
             (zoo))


(define %monkeys
  (list (monkey
         (name "meiyu")
         (comment "Peng Mei Yu")
         (supplementary-groups '("wheel"))
         (shell (file-append zsh "/bin/zsh"))
         (ssh-public-key
          (plain-file "meiyu.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICGixg7L7vRFgmxBS2GmI4/UqPw7pERi3qbKFUPaEZIF")))
        (monkey
         (name "qblade")
         (comment "luhux")
         (supplementary-groups '("wheel"))
         (ssh-public-key
          (plain-file "luhux.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIbLzIHSgPsTHirnDDVteW8gcumLnzizb05syPgLiDve")))
        (monkey
         (name "pandagix")
         (comment "PandaGix")
         (ssh-public-key
          (plain-file "pandagix.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPZ3/HBVQ+t8mtGuYXJUbbKR8yynheYl3RpbIs82ANv2")))
        (monkey
         (name "c4droid")
         (comment "c4droid")
         (ssh-public-key
          (plain-file "c4droid.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkcKq+wYarvlUl3cdrREM3SYwgB4s0QwaS1JCCc44mb")))
        (monkey
         (name "Z572")
         (comment "Z572")
         (supplementary-groups '("wheel"))
         (ssh-public-key
          (plain-file "z572.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKGGhcSQkHGf5XMWt5iRlrpHvrViHuZ7ApnU88IRETbF")))
        (monkey
         (name "gukig")
         (comment "Gukig Gao")
         (ssh-public-key
          (plain-file "gukig.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKISWkTOqTxPbadbuas9v34DUI/ZR3bG3z7AuTKlPaTa")))
        (monkey
         (name "minung")
         (comment "Minung Kuo")
         (ssh-public-key
          (plain-file "minung.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbadWYTSurbHn+u1t0FEbmzOPM05/wsYPQ0AGOElNRu")))
	(monkey 
         (name "spuch")
         (comment "picospuch")
         (ssh-public-key
          (plain-file "spuch.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGYruQYL5dSNIUgYpzZBWueIJv6bEaAFj56pKhA6Keje")))))
