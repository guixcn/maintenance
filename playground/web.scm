;;; Copyright © 2020-2023 Peng Mei Yu <pmy@xqzp.net>

(use-modules (gnu packages web)
             (gnu services admin)
             (gnu services certbot)
             (gnu services mcron)
             (gnu services web)
             (guix packages)
             (guix utils))


(define %nginx-reload
  (program-file "nginx-reload"
                #~(let ((pid (call-with-input-file "/var/run/nginx/pid"
                               read)))
                    (kill pid SIGHUP))))

(define %certbot-configuration
  (certbot-configuration
   (email "admin@guix.org.cn")
   (certificates (list (certificate-configuration
                        (domains '("guix.org.cn"))
                        (deploy-hook %nginx-reload))
                       (certificate-configuration
                        (domains '("ci.guix.org.cn"))
                        (deploy-hook %nginx-reload))
                       (certificate-configuration
                        (domains '("user.guix.org.cn"))
                        (deploy-hook %nginx-reload))))))


(define %nginx-configuration
  (nginx-configuration
   (nginx nginx)
   (server-blocks
    (list
     (nginx-server-configuration
      (server-name (list 'default))
      (listen '("80 default_server" "[::]:80 default_server"))
      (raw-content '("return 301 https://guix.org.cn/;")))

     (nginx-server-configuration
      (server-name (list "guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/guix.org.cn/privkey.pem")
      (root "/srv/http/guix.org.cn")
      (raw-content '("access_log /var/log/nginx/guix.org.cn.access.log;"
                     "error_log /var/log/nginx/guix.org.cn.error.log;")))

     (nginx-server-configuration
      (server-name (list "ci.guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/ci.guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/ci.guix.org.cn/privkey.pem")
      (locations (list (nginx-location-configuration
                        (uri "/")
                        (body (list "proxy_pass http://127.0.0.1:8181;")))))
      (raw-content '("access_log /var/log/nginx/ci.guix.org.cn.access.log;"
                     "error_log /var/log/nginx/ci.guix.org.cn.error.log;")))

     (nginx-server-configuration
      (server-name (list "user.guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/user.guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/user.guix.org.cn/privkey.pem")
      (root "/srv/http/user")
      (raw-content '("autoindex on;"
                     "access_log /var/log/nginx/user.guix.org.cn.access.log;"
                     "error_log /var/log/nginx/user.guix.org.cn.error.log;")))))))

(define %web-log-rotations
  (list (log-rotation
         (files (list "/var/log/nginx/*.log"))
         (frequency 'daily)
         (post-rotate #~(let ((pid (call-with-input-file "/var/run/nginx/pid"
                                     read)))
                          (kill pid SIGUSR1)))
         (options '("nostoredir"
                    "storefile @BASENAME-@YEAR@MONTH@DAY.@COMP_EXT")))))

(define %web-services
  (list (service certbot-service-type %certbot-configuration)
        (service nginx-service-type %nginx-configuration)
        (simple-service 'web-log-rotations
                        rottlog-service-type
                        %web-log-rotations)))
