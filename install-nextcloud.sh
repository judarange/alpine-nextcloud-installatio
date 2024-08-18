#!/bin/sh

# Mise à jour et installation des paquets nécessaires
apk update
apk upgrade
apk add nginx php82 php82-fpm php82-session php82-opcache php82-gd php82-json php82-mbstring php82-curl php82-intl php82-ctype php82-dom php82-xmlreader php82-xmlwriter php82-simplexml php82-fileinfo php82-pdo_mysql php82-tokenizer php82-xml php82-zip mariadb mariadb-client redis

# Démarrage et activation des services nécessaires
rc-update add nginx default
rc-update add php82-fpm default
rc-update add mariadb default
rc-update add redis default

service nginx start
service php82-fpm start
service mariadb setup
service mariadb start
service redis start

# Configuration de MariaDB (MySQL)
mysql_secure_installation <<EOF

y
password_root_mysql
password_root_mysql
y
y
y
y
EOF

# Création de la base de données Nextcloud
mysql -uroot -ppassword_root_mysql -e "CREATE DATABASE nextcloud;"
mysql -uroot -ppassword_root_mysql -e "CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'nextcloud_password';"
mysql -uroot -ppassword_root_mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"
mysql -uroot -ppassword_root_mysql -e "FLUSH PRIVILEGES;"

# Configuration de PHP-FPM
cat <<EOF > /etc/php82/php-fpm.d/www.conf
[www]
user = nobody
group = nobody
listen = 127.0.0.1:9000
listen.owner = nobody
listen.group = nobody
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOF

# Configuration de Nginx pour Nextcloud
cat <<EOF > /etc/nginx/http.d/nextcloud.conf
server {
    listen 80;
    server_name localhost;
    root /var/www/nextcloud;

    index index.php index.html /index.php\$request_uri;

    location / {
        try_files \$uri \$uri/ /index.php\$request_uri;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
        deny all;
    }

    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
        deny all;
    }

    location ~ ^/(?:updater|ocs-provider|ocm-provider)/ {
        try_files \$uri/ =404;
        index index.php;
    }

    location ~ \.php(?:\$|/) {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    location ~* \.(?:css|js|woff2?|svg|gif)$ {
        try_files \$uri /index.php\$request_uri;
        add_header Cache-Control "public, max-age=15778463";
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Robots-Tag none;
        add_header X-Download-Options noopen;
        add_header X-Permitted-Cross-Domain-Policies none;
    }

    location ~* \.(?:png|html|ttf|ico|jpg|jpeg)$ {
        try_files \$uri /index.php\$request_uri;
        access_log off;
    }
}
EOF

# Téléchargement et configuration de Nextcloud
NEXTCLOUD_VERSION="24.0.3"
wget https://download.nextcloud.com/server/releases/nextcloud-\$NEXTCLOUD_VERSION.tar.bz2
tar -xjf nextcloud-\$NEXTCLOUD_VERSION.tar.bz2 -C /var/www/
chown -R nobody:nobody /var/www/nextcloud

# Redémarrer les services
service php82-fpm restart
service nginx restart

echo "Installation complète ! Accédez à votre instance Nextcloud à http://<votre-ip>"
