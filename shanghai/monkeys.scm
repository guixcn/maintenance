(use-modules (guix gexp)
             (zoo))


(define %monkeys
  (list (monkey
         (name "meiyu")
         (comment "Peng Mei Yu")
         (shell (file-append zsh "/bin/zsh"))
         (ssh-public-key
          (plain-file "meiyu.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICGixg7L7vRFgmxBS2GmI4/UqPw7pERi3qbKFUPaEZIF")))
        (monkey
         (name "qblade")
         (comment "luhux")
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
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKlfAalEYpKNamHSye6fdiQXziKPhh8JI/jgt/ItI8eo")))
        (monkey
         (name "Z572")
         (comment "Z572")
         (ssh-public-key
          (plain-file "z572.pub"
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKGGhcSQkHGf5XMWt5iRlrpHvrViHuZ7ApnU88IRETbF")))))
