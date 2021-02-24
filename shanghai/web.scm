;;; Copyright © 2020-2021 Peng Mei Yu <i@pengmeiyu.com>

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
                        (domains '("guix.org.cn"
                                   "www.guix.org.cn"))
                        (deploy-hook %nginx-reload))
                       (certificate-configuration
                        (domains '("ci.guix.org.cn"))
                        (deploy-hook %nginx-reload))
                       (certificate-configuration
                        (domains '("mirror.guix.org.cn"))
                        (deploy-hook %nginx-reload))
                       (certificate-configuration
                        (domains '("user.guix.org.cn"))
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
      (server-name (list "ci.guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/ci.guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/ci.guix.org.cn/privkey.pem")
      (locations (list (nginx-location-configuration
                        (uri "/")
                        (body (list "proxy_pass http://localhost:8181;")))
                       %nginx-status-stub-configuration))
      (raw-content '("access_log /var/log/nginx/ci.guix.org.cn.access.log;"
                     "error_log /var/log/nginx/ci.guix.org.cn.error.log;")))

     (nginx-server-configuration
      (server-name (list "mirror.guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/mirror.guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/mirror.guix.org.cn/privkey.pem")
      (locations (list %git-http-nginx-location-configuration
                       %nginx-status-stub-configuration))
      (raw-content '("access_log /var/log/nginx/mirror.guix.org.cn.access.log;"
                     "error_log /var/log/nginx/mirror.guix.org.cn.error.log;")))

     (nginx-server-configuration
      (server-name (list "user.guix.org.cn"))
      (listen '("443 ssl" "[::]:443 ssl"))
      (ssl-certificate "/etc/letsencrypt/live/user.guix.org.cn/fullchain.pem")
      (ssl-certificate-key "/etc/letsencrypt/live/user.guix.org.cn/privkey.pem")
      (root "/srv/www/user")
      (locations (list %nginx-status-stub-configuration))
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
        (service fcgiwrap-service-type)
        (service nginx-service-type %nginx-configuration)
        (simple-service 'git-repository-mirror-jobs
                        mcron-service-type
                        %git-repository-mirror-jobs)
        (simple-service 'web-log-rotations
                        rottlog-service-type
                        %web-log-rotations)))
