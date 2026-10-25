# PHP 8.3 + Apache, avec l'extension OCI8 pour parler à Oracle, le moteur C++
# (souk-moteur) appelé par app/Services/CppEngine.php et l'outil souk-console.
#
# Trois étapes :
#   moteur      compile le C++ (le compilateur ne va pas dans l'image finale)
#   production  image du serveur : code copié DANS l'image, php.ini de production
#   dev         image locale : code monté depuis WSL, php.ini de développement
# "dev" est la DERNIÈRE étape : c'est celle que construit "docker compose up"
# sans précision. docker-compose.prod.yml demande "target: production".
#
# Multi-architecture : la même recette se construit en linux/amd64 (PC) et en
# linux/arm64 (serveur Oracle Cloud Ampere). Seul l'Instant Client change.

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

# --- Étape 2 : socle commun aux images de production et de développement
FROM php:8.3-apache-bookworm AS base

# 1. Oracle Instant Client : bibliothèques clientes d'Oracle dont OCI8 a besoin.
#    "basic" contient les bibliothèques, "sdk" les en-têtes pour compiler l'extension.
#    libaio1 est une dépendance système de l'Instant Client.
#    TARGETARCH est rempli par Docker (BuildKit) : amd64 sur un PC, arm64 sur le
#    serveur Ampere. Oracle publie un zip par architecture, sous deux noms différents.
ARG TARGETARCH
RUN case "${TARGETARCH:-amd64}" in \
        amd64) archive=linuxx64 ;; \
        arm64) archive=linux-arm64 ;; \
        *) echo "Architecture non prise en charge par l'Instant Client : $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && apt-get update \
    && apt-get install -y --no-install-recommends unzip libaio1 curl ca-certificates \
    && mkdir -p /opt/oracle && cd /opt/oracle \
    && curl -fsSLo basic.zip "https://download.oracle.com/otn_software/linux/instantclient/instantclient-basic-$archive.zip" \
    && curl -fsSLo sdk.zip "https://download.oracle.com/otn_software/linux/instantclient/instantclient-sdk-$archive.zip" \
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

# Nos réglages PHP (sessions, fuseau horaire, envois de fichiers)
COPY souk.ini "$PHP_INI_DIR/conf.d/zz-souk.ini"

# Programmes C++ compilés à l'étape 1 (même Debian bookworm : même libstdc++) :
# le moteur appelé par PHP, et l'outil console d'administration
COPY --from=moteur /opt/souk/bin/souk-moteur /opt/souk/bin/souk-console /usr/local/bin/

# --- Étape 3 : image de production (docker-compose.prod.yml)
FROM base AS production

# php.ini "production" fourni par PHP (erreurs jamais affichées, seulement
# journalisées), puis nos réglages de production par-dessus (zzz : lu en dernier)
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY souk-prod.ini "$PHP_INI_DIR/conf.d/zzz-souk-prod.ini"

# OPcache : PHP garde le code compilé en mémoire au lieu de relire et recompiler
# chaque fichier à chaque requête (gain net sur les 2 cœurs de la VM)
RUN docker-php-ext-install opcache

# Derrière Caddy : mod_remoteip remplace REMOTE_ADDR par la vraie IP du visiteur
# (voir apache-prod.conf). Sans lui, tous les visiteurs auraient l'IP de Caddy.
COPY apache-prod.conf /etc/apache2/conf-available/souk-prod.conf
RUN a2enmod remoteip && a2enconf souk-prod

# Le code est COPIÉ dans l'image (contexte "code" = racine du dépôt, filtré par
# .dockerignore) : l'image est un tout figé, identique à ce qui a été testé.
# Il appartient à root : même compromis, PHP (www-data) ne peut pas le modifier.
COPY --from=code app /var/www/html/app
COPY --from=code public /var/www/html/public
# Seuls les dossiers des photos envoyées et des emails simulés sont modifiables
# par www-data (ils seront des volumes Docker, voir docker-compose.prod.yml)
RUN mkdir -p /var/www/html/var /var/www/html/public/uploads \
    && chown www-data:www-data /var/www/html/var /var/www/html/public/uploads

# --- Étape 4 : image de développement (docker-compose.yml, étape par défaut)
FROM base AS dev

# Configuration PHP : base "development" (erreurs affichées)
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

# www-data (utilisateur SANS privilèges qui exécute Apache et PHP) prend l'uid et
# le gid de l'utilisateur de la machine. Les fichiers écrits par le site dans le
# dossier monté (emails simulés, photos) lui appartiennent, sans sudo.
# (Mettre "#1000" dans APACHE_RUN_USER ne marche pas : sans compte uid 1000 dans
#  le conteneur, Apache ne peut pas quitter root et garde ses processus en root.)
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN groupmod -o -g "$HOST_GID" www-data && usermod -o -u "$HOST_UID" -g "$HOST_GID" www-data
