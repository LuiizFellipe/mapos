# Multi-stage build para otimizar tamanho da imagem
FROM php:8.4-fpm-alpine AS base

# Instalar extensões PHP necessárias
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    zlib-dev \
    libzip-dev \
    git \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    opcache \
    && docker-php-ext-enable \
    mysqli \
    pdo_mysql \
    opcache

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Estágio de produção
FROM base as production

WORKDIR /app

# Configurações PHP para produção
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.revalidate_freq=60" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "upload_max_filesize=50M" >> /usr/local/etc/php/conf.d/upload.ini && \
    echo "post_max_size=50M" >> /usr/local/etc/php/conf.d/upload.ini && \
    echo "max_file_uploads=100" >> /usr/local/etc/php/conf.d/upload.ini

# Copiar arquivos da aplicação
COPY . .

# Instalar dependências composer
RUN composer install --no-dev --no-interaction --no-progress --no-suggest && \
    chmod -R 755 application/cache && \
    chmod -R 755 application/logs && \
    chmod -R 755 assets

# Criar user não-root
RUN addgroup -g 1000 mapos && \
    adduser -D -u 1000 -G mapos mapos && \
    chown -R mapos:mapos /app

USER mapos

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9000/ping || exit 1

EXPOSE 9000

CMD ["php-fpm"]

# Estágio de desenvolvimento
FROM base as development

WORKDIR /app

# Instalar extensões extras para desenvolvimento
RUN apk add --no-cache xdebug && \
    docker-php-ext-install xdebug

# Configurações PHP para desenvolvimento
RUN echo "display_errors=1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "log_errors=1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

COPY . .

RUN composer install --no-interaction --no-progress && \
    chmod -R 777 application/cache && \
    chmod -R 777 application/logs && \
    chmod -R 777 assets

EXPOSE 9000

CMD ["php-fpm"]
