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
      (raw-content '("return 301 https://guix.org.cn/;")))))))

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
  (list (service nginx-service-type %nginx-configuration)
        (simple-service 'web-log-rotations
                        rottlog-service-type
                        %web-log-rotations)))
