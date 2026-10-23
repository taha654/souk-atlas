#!/bin/bash
# =============================================================================
# Lance les tests navigateur (Playwright + Chromium) dans un conteneur Docker,
# sans rien installer sur la machine. À lancer depuis l'hôte, site démarré :
#
#   ./tests/navigateur/lancer.sh                 (tous les tests)
#   ./tests/navigateur/lancer.sh catalogue       (un seul fichier)
#
# Premier lancement : téléchargement de l'image (environ 3,5 Go) et de
# @playwright/test (npm). Les captures d'écran vont dans docs/captures/.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."

# Comptes créés par les tests (test-…@exemple.ma), commandes et stock : remis en ordre à la fin
nettoyer() {
    # Fichiers des photos envoyées par les vendeurs de test, puis les données
    docker compose exec -T oracle bash -c 'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' <<'SQL' \
        | grep '^/uploads/' | while read -r chemin; do rm -f "public$chemin"; done
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT ph.chemin FROM produit_photo ph JOIN produit p ON p.id = ph.id_produit JOIN boutique b ON b.id = p.id_boutique
  JOIN utilisateur u ON u.id = b.id_vendeur WHERE u.email LIKE 'test-%' AND ph.chemin LIKE '/uploads/%';
EXIT
SQL
    docker compose exec -T oracle bash -c \
        'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' > /dev/null <<'SQL'
@/opt/souk/database/tests/nettoyer_comptes_test.sql
EXIT
SQL
    grep -l '^To: test-' var/mails/*.eml 2>/dev/null | xargs -r rm -f
}
trap nettoyer EXIT

# --user : fichiers créés (node_modules, captures) à votre nom, pas à root
docker run --rm --init \
    --network souk-atlas_default \
    --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD:/projet" -w /projet/tests/navigateur \
    mcr.microsoft.com/playwright:v1.49.1-noble \
    sh -c "npm install --no-audit --no-fund --silent && npx playwright test $*"
