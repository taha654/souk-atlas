# PHP 8.3 + Apache, avec l'extension OCI8 pour parler à Oracle, le moteur C++
# (souk-moteur) appelé par app/Services/CppEngine.php et l'outil souk-console.

# --- Étape 1 : compilation du moteur C++ (construction "multi-étapes").
# Le compilateur reste dans cette image intermédiaire : l'image finale ne
# reçoit que l'exécutable. Si un test C++ échoue, la construction s'arrête.
FROM debian:bookworm-slim AS moteur
RUN apt-get update \
    && apt-get install -y --no-install-recommends g++ cmake make \
    && rm -rf /var/lib/apt/lists/*
COPY --from=cpp . /src
RUN cmake -S /src -B /build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /build -j"$(nproc)" \
    && ctest --test-dir /build --output-on-failure \
    && cmake --install /build --prefix /opt/souk

# --- Étape 2 : l'image du site
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

# 2 bis. Fuseaux horaires à jour : PHP embarque sa propre copie (figée à la
#    compilation), plus ancienne que celle du système. Pour le Maroc, elle donnait
#    une heure de décalage avec Oracle. L'extension timezonedb la remplace.
# Version volontairement non figée : pour des fuseaux horaires, la plus récente est la bonne.
RUN pecl install timezonedb && docker-php-ext-enable timezonedb

# 2 ter. GD avec JPEG, PNG et WebP : tools/photos_demo.php recadre les photos
#    Pixabay en 800 x 600 et les enregistre en WebP sur notre serveur.
#    Les bibliothèques -dev servent à la compilation ; on garde les versions d'exécution.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libjpeg62-turbo-dev libpng-dev libwebp-dev \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install gd \
    && apt-get install -y --no-install-recommends libjpeg62-turbo libpng16-16 libwebp7 \
    && apt-get purge -y libjpeg62-turbo-dev libpng-dev libwebp-dev && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 3. Apache : seul le dossier public/ est exposé sur le web ;
#    app/, database/, cpp/… restent inaccessibles depuis le navigateur.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf
# URL propres (FallbackResource vers index.php), pas de listing de dossiers
COPY apache-souk.conf /etc/apache2/conf-available/souk.conf
# mod_headers : en-têtes ajoutés par Apache (dossier uploads)
RUN a2enmod headers && a2enconf souk

# Configuration PHP : base "development", puis nos réglages (sessions, fuseau horaire)
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY souk.ini "$PHP_INI_DIR/conf.d/zz-souk.ini"

# www-data (utilisateur SANS privilèges qui exécute Apache et PHP) prend l'uid et
# le gid de l'utilisateur de la machine. Les fichiers écrits par le site dans le
# dossier monté (emails simulés, photos) lui appartiennent, sans sudo.
# (Mettre "#1000" dans APACHE_RUN_USER ne marche pas : sans compte uid 1000 dans
#  le conteneur, Apache ne peut pas quitter root et garde ses processus en root.)
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN groupmod -o -g "$HOST_GID" www-data && usermod -o -u "$HOST_UID" -g "$HOST_GID" www-data

# Programmes C++ compilés à l'étape 1 (même Debian bookworm : même libstdc++) :
# le moteur appelé par PHP, et l'outil console d'administration
COPY --from=moteur /opt/souk/bin/souk-moteur /opt/souk/bin/souk-console /usr/local/bin/
