FROM php:8.4-fpm-alpine
 
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    zlib-dev \
    libzip-dev \
    git \
    curl \
    nginx \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    opcache \
    && docker-php-ext-enable mysqli pdo_mysql opcache
 
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
 
WORKDIR /app
 
COPY . .
 
RUN composer install --no-dev --no-interaction --no-progress
 
RUN mkdir -p application/cache application/logs \
    && chmod -R 755 application/cache \
    && chmod -R 755 application/logs \
    && chmod -R 755 assets
 
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "upload_max_filesize=50M" >> /usr/local/etc/php/conf.d/upload.ini && \
    echo "post_max_size=50M" >> /usr/local/etc/php/conf.d/upload.ini
 
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
 
RUN echo '#!/bin/sh' > /startup.sh && \
    echo 'php-fpm -D' >> /startup.sh && \
    echo 'nginx -g "daemon off;"' >> /startup.sh && \
    chmod +x /startup.sh
 
EXPOSE 80
 
CMD ["/startup.sh"]
