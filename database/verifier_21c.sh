#!/bin/bash
# =============================================================================
# Vérifie que la base s'installe et que tous les tests passent sur un VRAI
# Oracle Database 21c (Express Edition), la version utilisée en cours.
# Notre conteneur principal tourne en 23ai, plus tolérant : une syntaxe
# propre à 23ai passerait inaperçue sans cette vérification.
#
# À lancer depuis la machine hôte (pas dans un conteneur) :
#   ./database/verifier_21c.sh
#
# Crée un conteneur temporaire (sans port exposé), puis le supprime.
# Premier lancement : téléchargement de l'image (environ 2,6 Go).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

NOM=souk-verif-xe21
# Conteneur jetable, inaccessible de l'extérieur : ces mots de passe ne protègent rien
MDP_ADMIN=VerifXe21
MDP_SOUK=VerifSouk21

nettoyer() { docker rm -f "$NOM" > /dev/null 2>&1 || true; }
trap nettoyer EXIT
nettoyer

echo "Démarrage d'Oracle XE 21c (1 à 3 minutes)…"
docker run -d --name "$NOM" \
    -e ORACLE_PASSWORD="$MDP_ADMIN" -e APP_USER=SOUK -e APP_USER_PASSWORD="$MDP_SOUK" \
    -e TZ=Africa/Casablanca \
    -v "$PWD/database:/opt/souk/database:ro" \
    gvenzl/oracle-xe:21-slim > /dev/null

for _ in $(seq 1 120); do
    docker logs "$NOM" 2>&1 | grep -q "DATABASE IS READY" && break
    sleep 5
done
docker logs "$NOM" 2>&1 | grep -q "DATABASE IS READY" || { echo "Oracle 21c n'a pas démarré"; exit 1; }

# Sur 21c, l'image n'accorde pas CREATE JOB à l'utilisateur applicatif
# (sur 23ai, le rôle DB_DEVELOPER_ROLE l'inclut) : on l'ajoute comme le
# ferait un administrateur sur un Oracle 19c / 21c classique.
docker exec "$NOM" bash -c "sqlplus -s system/$MDP_ADMIN@//localhost/XEPDB1 <<< 'GRANT CREATE JOB TO SOUK;'"

docker exec -e APP_USER=SOUK -e APP_USER_PASSWORD="$MDP_SOUK" -e DB_SERVICE=XEPDB1 "$NOM" \
    bash -c '/opt/souk/database/installer.sh && /opt/souk/database/tests/lancer_tests.sh'
