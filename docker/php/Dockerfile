FROM php:8.1-fpm

ARG DOCKER_PHP_EXT=1.5.14
ADD https://github.com/mlocati/docker-php-extension-installer/releases/download/${DOCKER_PHP_EXT}/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions

RUN \
    apt-get update; \
    apt-get install -y --fix-missing \
        apt-utils \
        bash-completion \
        g++ \
        gcc \
        git \
        gnupg \
        make \
        nano \
        unzip \
    ; \
    install-php-extensions \
        amqp \
        apcu \
        bcmath \
        csv \
        decimal \
        exif \
        imagick \
        intl \
        mcrypt \
        opcache \
        pdo_mysql \
        sockets \
        xdebug \
        xmldiff \
        xmlrpc \
        xsl \
        zip \
    ; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    truncate -s 0 /var/log/*log;

# Setting up PHP's timezone
ARG TZ
RUN echo "date.timezone = ${TZ}" > ${PHP_INI_DIR}/conf.d/timezone.ini

# Setting up xDebug
ARG APP_ENV=dev
RUN set -xe; \
    mkdir -p /xdebug; \
    chown -R www-data:www-data /xdebug; \
    chmod -R ugo+rw /xdebug; \
    echo "xdebug.client_host=host.docker.internal" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
    echo "xdebug.client_port=9003" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
    echo "xdebug.idekey=Recipes Book" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
    if [ "${APP_ENV}" = "test" ]; then \
        echo "xdebug.mode=coverage" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
    else \
        echo "xdebug.mode=debug" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini; \
    fi

# Install APCu & OPCache
ARG APCU_VERSION=5.1.21
RUN pecl install apcu-${APCU_VERSION}; \
	pecl clear-cache; \
	docker-php-ext-enable apcu opcache;

# Install cachetool
ARG CACHETOOL_VERSION=8.4.0
RUN \
    curl -slL https://github.com/gordalina/cachetool/releases/download/${CACHETOOL_VERSION}/cachetool.phar -o /usr/local/bin/cachetool; \
    chmod +x /usr/local/bin/cachetool;

# Install composer
RUN \
    curl -slL https://getcomposer.org/composer-2.phar -o /usr/local/bin/composer; \
    chmod +x /usr/local/bin/composer;

# Create user
ARG UID
RUN \
    useradd -ms /bin/bash --uid ${UID} docker; \
    usermod -a -G www-data docker;
COPY ./php/.bashrc /home/docker/.bashrc
RUN \
    chown -R docker:docker /home/docker; \
    chown -R docker /var/www/html;
USER docker

# Setting up user
RUN \
    echo "set linenumbers" > /home/docker/.nanorc

WORKDIR /var/www/html
