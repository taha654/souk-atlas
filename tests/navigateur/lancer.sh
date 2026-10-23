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

# --user : fichiers créés (node_modules, captures) à votre nom, pas à root
docker run --rm --init \
    --network souk-atlas_default \
    --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD:/projet" -w /projet/tests/navigateur \
    mcr.microsoft.com/playwright:v1.49.1-noble \
    sh -c "npm install --no-audit --no-fund --silent && npx playwright test $*"
