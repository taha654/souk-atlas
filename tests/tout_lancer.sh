#!/bin/bash
# =============================================================================
# Lance TOUTES les suites de tests et affiche un bilan (site démarré) :
#   ./tests/tout_lancer.sh
# Code de retour 0 seulement si tout passe.
# =============================================================================
cd "$(dirname "$0")/.."
echec=0
lancer() {   # lancer "Nom" commande…
    local sortie; sortie=$("${@:2}" 2>&1); local code=$?
    printf '%-12s %s\n' "$1" "$(grep -E 'TOTAL|BILAN|passed|failed' <<< "$sortie" | tail -1 | sed 's/^ *//')"
    [[ $code -eq 0 ]] || { echec=1; grep -E 'ÉCHEC  |PLANTAGE|✘' <<< "$sortie" | head -10 | sed 's/^/    /'; }
}
lancer "PL/SQL"     docker compose exec -T oracle /opt/souk/database/tests/lancer_tests.sh
lancer "PHP"        docker compose exec -T php php tests/php/test_unitaires.php
for f in tests/http/test_*.sh; do
    nom=$(basename "$f" .sh); lancer "HTTP ${nom#test_}" "$f"
done
lancer "Navigateur" tests/navigateur/lancer.sh
echo
[[ $echec -eq 0 ]] && echo "Tout est vert." || echo "Des tests échouent (voir ci-dessus)."
exit $echec
