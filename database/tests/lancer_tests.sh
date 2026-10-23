#!/bin/bash
# =============================================================================
# Lance tous les tests de la base et affiche le bilan. S'exécute DANS le conteneur :
#
#   docker compose exec oracle /opt/souk/database/tests/lancer_tests.sh
#   docker compose exec oracle /opt/souk/database/tests/lancer_tests.sh test_panier   (un seul fichier)
#
# Chaque fichier test_*.sql tourne dans sa propre session et se termine par
# ROLLBACK : les données de démonstration ne sont pas modifiées (sauf
# test_jobs.sql, qui exécute réellement les jobs de maintenance).
# Code de retour : 0 si tout passe, 1 sinon.
# =============================================================================
set -uo pipefail

DOSSIER="$(cd "$(dirname "$0")" && pwd)"
# Service Oracle : FREEPDB1 (Oracle Free 23ai), XEPDB1 pour vérifier sur Oracle XE 21c
CONNEXION="${APP_USER}/${APP_USER_PASSWORD}@//localhost/${DB_SERVICE:-FREEPDB1}"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

executer() {
    sqlplus -s -L "$CONNEXION" <<SQL
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET FEEDBACK OFF DEFINE OFF SERVEROUTPUT ON SIZE UNLIMITED LINESIZE 300
@"$1"
EXIT SUCCESS
SQL
}

# 1. Le framework lui-même
if ! executer "$DOSSIER/00_pkg_test.sql" > /dev/null; then
    echo "Impossible d'installer PKG_TEST"; exit 1
fi

# 2. Les suites de tests (test_jobs en dernier : il valide des modifications)
FICHIERS=$(ls "$DOSSIER"/test_*.sql | grep -v test_jobs.sql; ls "$DOSSIER"/test_jobs.sql 2>/dev/null)
if [[ $# -gt 0 ]]; then
    FICHIERS="$DOSSIER/$1.sql"
fi

total_ok=0
total_echecs=0
plantages=0
for fichier in $FICHIERS; do
    sortie=$(executer "$fichier")
    code=$?
    echo "$sortie"
    if [[ $code -ne 0 ]]; then
        # Erreur SQL non interceptée : le script s'est arrêté avant la fin
        echo "PLANTAGE  $(basename "$fichier") (erreur non interceptée, voir ci-dessus)"
        plantages=$((plantages + 1))
    fi
    total_ok=$((total_ok + $(grep -c '^OK ' <<< "$sortie")))
    total_echecs=$((total_echecs + $(grep -c '^ÉCHEC ' <<< "$sortie")))
done

echo
echo "================================================"
echo " TOTAL : $total_ok OK, $total_echecs ÉCHEC, $plantages plantage(s)"
echo "================================================"
[[ $total_echecs -eq 0 && $plantages -eq 0 ]]
