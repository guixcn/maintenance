;;; Copyright © 2020 Peng Mei Yu <i@pengmeiyu.com>

(use-modules (gnu packages version-control)
             (gnu packages web)
             (gnu services admin)
             (gnu services certbot)
             (gnu services mcron)
             (gnu services version-control)
             (gnu services web)
             (guix packages)
             (guix utils))

(define %nginx-package
  (package
    (inherit nginx)
    (arguments
     (substitute-keyword-arguments (package-arguments nginx)
       ((#:configure-flags flags ''())
        `(cons "--with-http_stub_status_module" ,flags))))))

(define %nginx-reload
  (program-file "nginx-reload"
                #~(let ((pid (call-with-input-file "/var/run/nginx/pid"
                               read)))
                    (kill pid SIGHUP))))

(define %certbot-configuration
  (certbot-configuration
   (email "admin@guix.org.cn")
   (certificates (list (certificate-configuration
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

(define %guix-ci-upstream-configuration
  (nginx-upstream-configuration
   (name "guix-ci")
   ;; Repeat server here to force nginx to retry this server when there is an
   ;; error.
   (servers '("guix-mirror.pengmeiyu.com:443 max_fails=0"
              "guix-mirror.pengmeiyu.com:443 max_fails=0"
              "guix-mirror.pengmeiyu.com:443 max_fails=0"
              "guix-mirror.pengmeiyu.com:443 max_fails=0"))))

(define %guix-mirror-nginx-location-configurations
  (let* ((upstream "guix-ci")
         (domain "guix-mirror.pengmeiyu.com"))
    (list (nginx-location-configuration
           (uri "~ \\.narinfo$")
           (body (list
                  (string-append "proxy_pass https://" upstream ";")
                  (string-append "proxy_set_header Host " domain ";")
                  "proxy_ssl_server_name on;"
                  (string-append "proxy_ssl_name " domain ";")

                  ;; Try next upstream server when there is an error.
                  "proxy_next_upstream error timeout invalid_header;"
                  "proxy_next_upstream_timeout 20s;"

                  ;; Die quickly and try next upstream server.
                  "proxy_connect_timeout 2s;"
                  "proxy_read_timeout 3s;"
                  "proxy_send_timeout 2s;"

                  "proxy_cache narinfo;"
                  "proxy_cache_valid 200 206 60d;"
                  "proxy_cache_valid any 5m;"

                  "proxy_ignore_client_abort on;"
                  "proxy_hide_header Set-Cookie;"
                  "proxy_ignore_headers Set-Cookie;")))
          (nginx-location-configuration
           (uri "~ ^/nar/")
           (body (list
                  (string-append "proxy_pass https://" upstream ";")
                  (string-append "proxy_set_header Host " domain ";")
                  "proxy_ssl_server_name on;"
                  (string-append "proxy_ssl_name " domain ";")

                  ;; Try next upstream server when there is an error.
                  "proxy_next_upstream error timeout invalid_header;"

                  ;; Die quickly and try next upstream server.
                  "proxy_connect_timeout 2s;"
                  "proxy_read_timeout 30s;"
                  "proxy_send_timeout 30s;"

                  "proxy_cache nar;"
                  "proxy_cache_valid 200 206 60d;"
                  "proxy_cache_valid any 5m;"
                  "gzip off;"

                  "proxy_ignore_client_abort on;"
                  "proxy_hide_header Set-Cookie;"
                  "proxy_ignore_headers Set-Cookie;"))))))

(define %nginx-status-stub-configuration
  (nginx-location-configuration
   (uri "/nginx_status")
   (body '("stub_status on;"
           "access_log off;"))))

(define %nginx-configuration
  (nginx-configuration
   (nginx %nginx-package)
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
      (root "/srv/www/guix.org.cn")
      (locations (list %nginx-status-stub-configuration))
      (raw-content '("access_log /var/log/nginx/guix.org.cn.access.log;"
                     "error_log /var/log/nginx/guix.org.cn.error.log;")))

     (nginx-server-configuration
      (server-name (list "mirror.guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/mirror.guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/mirror.guix.org.cn/privkey.pem")
      (locations `(;; Cuirass
                   ,(nginx-location-configuration
                     (uri "/")
                     (body '("set $upstream \"https://ci.guix.gnu.org\";"
                             "proxy_pass $upstream;"
                             "proxy_ssl_server_name on;"
                             "proxy_ssl_name ci.guix.gnu.org;"
                             "proxy_set_header Host ci.guix.gnu.org;")))
                   ;; Mirror
                   ,@%guix-mirror-nginx-location-configurations
                   ,%git-http-nginx-location-configuration
                   ;; Status
                   ,%nginx-status-stub-configuration))
      (raw-content '("access_log /var/log/nginx/mirror.guix.org.cn.access.log;"
                     "error_log /var/log/nginx/mirror.guix.org.cn.error.log;")))))
   (upstream-blocks (list %guix-ci-upstream-configuration))
   (extra-content "
resolver 114.114.114.114 9.9.9.9 ipv6=off;

# Cache for nar.
proxy_cache_path /srv/cache/nginx/nar
    levels=2
    inactive=60d                # Remove inactive keys after this period.
    keys_zone=nar:20m           # About 8 thousand keys per megabyte.
    max_size=30g;               # Total cache data size.

# Cache for narinfo.
proxy_cache_path /srv/cache/nginx/narinfo
    levels=2
    inactive=60d                # Remove inactive keys after this period.
    keys_zone=narinfo:20m       # About 8 thousand keys per megabyte.
    max_size=1g;                # Total cache data size.
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
