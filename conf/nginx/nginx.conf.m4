worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '[$time_local] $remote_addr "$request"'
                      '\n  fastcgi_script_name: $fastcgi_script_name'
                      '\n  document_root: $document_root'
                      '\n  document_uri:  $document_uri'
                      '\n  request_uri:   $request_uri'
                      '\n  query_string:  $query_string';

    access_log  logs/access.log  main;
    error_log logs/error.log debug;
    rewrite_log on;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    # HTTP File server redirect
    server {
        listen HTTP_PORT;
        server_name ~^((?<subdomain>.*)\.)(?<domain>[^.]+)\.(?<tld>[^.]+)$;
        return 301 https://$subdomain.$domain:HTTPS_PORT$request_uri;
    }

    # Data Subdomain
    server {
        listen HTTPS_PORT;
        server_name ~^ patsubst(TDRZ_DATA_SUBDOMAIN.SERVER_NAME,\.,\\.);
        ssl on;
        ssl_certificate CERT_PATH;
        ssl_certificate_key CERT_KEY_PATH;

        location ~ ^/(.*) {
            rewrite ^/(.*) Request.php?f=$1;
            break;
            
            root DOCUMENT_ROOT;

            include fastcgi.conf;

            # Mitigate https://httpoxy.org/ vulnerabilities
            fastcgi_param HTTP_PROXY "";
            fastcgi_pass PHP_BIND;
        }
    }

    # HTTPS File server
    server {
        listen HTTPS_PORT;
        server_name SERVER_NAME;
        ssl on;
        ssl_certificate CERT_PATH;
        ssl_certificate_key CERT_KEY_PATH;

        # Raw data files
        location ~ /raw(.*) {
            root TDRZ_DATA_DIR;
            try_files $1 $1;
        }

        location / {
            index index.php Index.php index.html Index.html;
            root DOCUMENT_ROOT;
        }

        location ~* (.*)\.php$ {
            root DOCUMENT_ROOT;

            fastcgi_split_path_info ^(.+?\.php)(/.*)$;
            if (!-f DOCUMENT_ROOT$fastcgi_script_name) {
                return 404;
            }

            include fastcgi.conf;

            # Mitigate https://httpoxy.org/ vulnerabilities
            fastcgi_param HTTP_PROXY "";
            fastcgi_pass PHP_BIND;
        }

        # Required for certbot
        location ^~ /.well-known {
            alias CERTBOT_WELL_KNOWN_PATH/.well-known;
        }
    }
}