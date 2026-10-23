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
    # Un nettoyage ne doit JAMAIS s'arrêter en cours de route : on désactive
    # "set -e" ici (un grep sans résultat n'est pas une erreur à ce stade)
    set +e
    # Même nettoyage que les tests HTTP : comptes, données et fichiers envoyés
    BASE=unused TMP=/tmp source tests/http/outils.sh
    supprimer_comptes_test
    # Messages écrits par les tests dans les conversations de démo : tous ceux
    # créés après le début des tests (id supérieur au maximum relevé avant)
    sql "DELETE FROM message WHERE id > ${DERNIER_MESSAGE:-0};
COMMIT;" > /dev/null
}
DERNIER_MESSAGE=$(BASE=unused bash -c 'source tests/http/outils.sh; sql "SELECT NVL(MAX(id), 0) FROM message;"')
trap nettoyer EXIT

# --user : fichiers créés (node_modules, captures) à votre nom, pas à root
docker run --rm --init \
    --network souk-atlas_default \
    --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD:/projet" -w /projet/tests/navigateur \
    mcr.microsoft.com/playwright:v1.49.1-noble \
    sh -c "npm install --no-audit --no-fund --silent && npx playwright test $*"
