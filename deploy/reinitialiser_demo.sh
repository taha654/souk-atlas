#!/bin/bash
# =============================================================================
# Réinitialise le site de démonstration : base remise aux données de
# 05_seed.sql, photos envoyées et emails simulés effacés, sessions vidées.
# Lancé chaque nuit par cron (installé par deploy.sh) :
#
#   0 3 * * * /home/ubuntu/souk-atlas/deploy/reinitialiser_demo.sh
#
# Ne fait RIEN si le site n'est pas en mode démonstration (DEMO_MODE=1).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
COMPOSE=(docker compose -f docker-compose.prod.yml)

echo "=== $(date '+%F %T') Réinitialisation de la démonstration"

# Garde-fou : on lit la valeur RÉELLE dans le conteneur PHP, pas le .env
# (c'est elle qui compte, et un .env modifié sans redémarrage mentirait)
if [[ "$("${COMPOSE[@]}" exec -T php printenv DEMO_MODE 2>/dev/null || true)" != 1 ]]; then
    echo "DEMO_MODE n'est pas à 1 dans le conteneur PHP : aucune donnée n'est effacée."
    exit 0
fi

# 1. PHP arrêté pendant l'opération : aucune session Oracle ouverte ne peut
#    bloquer la suppression des tables (verrous), et aucun visiteur ne voit
#    un site à moitié vide. Caddy répond 502 pendant une à deux minutes.
"${COMPOSE[@]}" stop php

# 2. Base : suppression du schéma SOUK puis réinstallation complète (schéma,
#    packages, triggers, jobs, données de démo), comme au premier démarrage
"${COMPOSE[@]}" exec -T oracle /opt/souk/database/installer.sh --reinitialiser

# 3. Fichiers des visiteurs, dans les volumes (un conteneur jetable les monte,
#    puisque PHP est arrêté). .gitkeep est gardé.
"${COMPOSE[@]}" run --rm --no-deps --entrypoint sh php -c \
    'find /var/www/html/public/uploads /var/www/html/var -mindepth 1 ! -name .gitkeep -delete'

# 4. Nouveau conteneur PHP : sessions (/tmp) et connexions Oracle persistantes
#    repartent de zéro
"${COMPOSE[@]}" up -d --force-recreate --no-deps php

echo "=== $(date '+%F %T') Terminé"
