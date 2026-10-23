# PHP 8.3 + Apache, avec l'extension OCI8 pour parler à Oracle.
FROM php:8.3-apache-bookworm

# 1. Oracle Instant Client : bibliothèques clientes d'Oracle dont OCI8 a besoin.
#    "basic" contient les bibliothèques, "sdk" les en-têtes pour compiler l'extension.
#    libaio1 est une dépendance système de l'Instant Client.
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip libaio1 curl ca-certificates \
    && mkdir -p /opt/oracle && cd /opt/oracle \
    && curl -fsSLo basic.zip https://download.oracle.com/otn_software/linux/instantclient/instantclient-basic-linuxx64.zip \
    && curl -fsSLo sdk.zip https://download.oracle.com/otn_software/linux/instantclient/instantclient-sdk-linuxx64.zip \
    && unzip -qo basic.zip && unzip -qo sdk.zip && rm basic.zip sdk.zip \
    && mv instantclient_* instantclient \
    # Indique au système où trouver les bibliothèques Oracle
    && echo /opt/oracle/instantclient > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*

# 2. Extension OCI8 : encore livrée avec les sources de PHP 8.3, on la compile ici.
RUN docker-php-ext-configure oci8 --with-oci8=instantclient,/opt/oracle/instantclient \
    && docker-php-ext-install oci8

# 3. Apache : seul le dossier public/ est exposé sur le web ;
#    app/, database/, cpp/… restent inaccessibles depuis le navigateur.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf \
    # mod_rewrite servira au routeur (URL propres) à l'étape 2
    && a2enmod rewrite

# Configuration PHP de développement (erreurs affichées)
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
