;;; Copyright © 2020 Peng Mei Yu <i@pengmeiyu.com>

(use-modules (gnu packages version-control)
             (gnu services admin)
             (gnu services certbot)
             (gnu services mcron)
             (gnu services version-control)
             (gnu services web))


(define %nginx-reload
  (program-file "nginx-reload"
                #~(let ((pid (call-with-input-file "/var/run/nginx/pid"
                               read)))
                    (kill pid SIGHUP))))

(define %certbot-configuration
  (certbot-configuration
   (email "admin@guix.org.cn")
   (certificates (list (certificate-configuration
                        (domains '("guix.org.cn"
                                   "www.guix.org.cn"))
                        (deploy-hook %nginx-reload))
                       (certificate-configuration
                        (domains '("ci.guix.org.cn"))
                        (deploy-hook %nginx-reload))
                       (certificate-configuration
                        (domains '("mirror.guix.org.cn"))
                        (deploy-hook %nginx-reload))))))

(define %git-http-nginx-location-configuration
  (git-http-nginx-location-configuration
   (git-http-configuration
    (export-all? #t)
    (git-root "/srv/git")
    (uri-path "/git/"))))

(define %git-repository-mirror-jobs
  (list #~(job '(next-minute (range 0 60 10))
               #$(program-file
                  "git-mirror-job"
                  #~(begin
                      (setenv "GIT_SSL_CAINFO" "/etc/ssl/certs/ca-certificates.crt")
                      (system* #$(file-append git "/bin/git")
                               "--git-dir=/srv/git/guix.git"
                               "fetch"))))))

(define %guix-mirror-nginx-location-configuration
  (nginx-location-configuration
   (uri "~ ^/nix-cache-info|^/nar/|\\.narinfo$")
   (body '("proxy_pass https://guix-mirror.pengmeiyu.com;"
           "proxy_ssl_server_name on;"
           "proxy_ssl_name guix-mirror.pengmeiyu.com;"
           "proxy_set_header Host guix-mirror.pengmeiyu.com;"

           "proxy_cache guix-mirror;"
           "proxy_cache_valid 200 60d;"
           "proxy_cache_valid any 3m;"
           "proxy_connect_timeout 60s;"
           "proxy_ignore_client_abort on;"

           "client_body_buffer_size 256k;"
           "proxy_hide_header Set-Cookie;"
           "proxy_ignore_headers Set-Cookie;"
           "gzip off;"))))

(define %nginx-configuration
  (nginx-configuration
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
      (raw-content '("return 301 https://guix-china.github.io/;"
                     "access_log /var/log/nginx/guix.org.cn.access.log;"
                     "error_log /var/log/nginx/guix.org.cn.error.log;")))

     (nginx-server-configuration
      (server-name (list "ci.guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/ci.guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/ci.guix.org.cn/privkey.pem")
      (locations (list (nginx-location-configuration
                        (uri "/")
                        (body (list "proxy_pass http://localhost:8181;")))))
      (raw-content '("access_log /var/log/nginx/ci.guix.org.cn.access.log;"
                     "error_log /var/log/nginx/ci.guix.org.cn.error.log;")))

     (nginx-server-configuration
      (server-name (list "mirror.guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/mirror.guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/mirror.guix.org.cn/privkey.pem")
      (locations (list
                  ;; Cuirass
                  (nginx-location-configuration
                   (uri "/")
                   (body '("proxy_pass https://ci.guix.gnu.org;"
                           "proxy_ssl_server_name on;"
                           "proxy_ssl_name ci.guix.gnu.org;"
                           "proxy_set_header Host ci.guix.gnu.org;")))
                  ;; Mirror
                  %guix-mirror-nginx-location-configuration
                  %git-http-nginx-location-configuration))
      (raw-content '("access_log /var/log/nginx/mirror.guix.org.cn.access.log;"
                     "error_log /var/log/nginx/mirror.guix.org.cn.error.log;")))))
   (extra-content "
# cache for guix mirror
proxy_cache_path /srv/cache/guix-mirror
    levels=2
    inactive=30d              # remove inactive keys after this period
    keys_zone=guix-mirror:8m  # about 8 thousand keys per megabyte
    max_size=40g;             # total cache data size
")))

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
        (service fcgiwrap-service-type)
        (service nginx-service-type %nginx-configuration)
        (simple-service 'git-repository-mirror-jobs
                        mcron-service-type
                        %git-repository-mirror-jobs)
        (simple-service 'web-log-rotations
                        rottlog-service-type
                        %web-log-rotations)))
