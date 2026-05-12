FROM php:8.4-fpm-alpine

# Instalar pacotes
RUN apk add --no-cache \
    libpng-dev libjpeg-turbo-dev freetype-dev zlib-dev libzip-dev \
    git curl nginx

# Extensões PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd mysqli pdo pdo_mysql zip opcache && \
    docker-php-ext-enable mysqli pdo_mysql opcache

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /app

COPY . .

# Instalar dependências PHP
RUN composer install --no-dev --no-interaction --no-progress 2>&1 | grep -v "Warning"

# Permissões
RUN mkdir -p application/cache application/logs && \
    chmod -R 755 application/cache application/logs assets

# PHP Config
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "upload_max_filesize=50M" >> /usr/local/etc/php/conf.d/upload.ini && \
    echo "post_max_size=50M" >> /usr/local/etc/php/conf.d/upload.ini

# Nginx Config (embutido - SEM arquivo externo!)
RUN cat > /etc/nginx/conf.d/default.conf << 'NGINX'
upstream php {
    server 127.0.0.1:9000;
}

server {
    listen 80;
    server_name _;
    root /app;
    index index.php;
    
    client_max_body_size 50M;

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~ ^/(application|system) {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass php;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 300s;
        include fastcgi_params;
    }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
}
NGINX

# Startup script
RUN cat > /startup.sh << 'STARTUP'
#!/bin/sh
set -e
echo "Starting PHP-FPM..."
php-fpm -D
echo "Starting Nginx..."
nginx -g "daemon off;"
STARTUP
RUN chmod +x /startup.sh

EXPOSE 80

CMD ["/startup.sh"]
