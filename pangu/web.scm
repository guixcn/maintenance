;;; Copyright © 2020 Peng Mei Yu <pengmyu@gmail.com>

(use-modules (gnu services certbot)
             (gnu services web))


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
      (root "/srv/www/guix.org.cn")
      (raw-content '("access_log /var/log/nginx/guix.org.cn.access.log;"
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
      (locations (list (nginx-location-configuration
                        (uri "/")
                        (body '("proxy_pass https://guix-mirror.pengmeiyu.com;"
                                "proxy_cache guix-mirror;"
                                "proxy_cache_valid 200 60d;"
                                "proxy_cache_valid any 3m;"
                                "proxy_connect_timeout 60s;"
                                "proxy_ignore_client_abort on;"

                                "client_body_buffer_size 256k;"
                                "proxy_hide_header Set-Cookie;"
                                "proxy_ignore_headers Set-Cookie;"
                                "gzip off;")))))
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
                                   "ci.guix.org.cn"
                                   "mirror.guix.org.cn"))
                        (deploy-hook %nginx-reload))))))
