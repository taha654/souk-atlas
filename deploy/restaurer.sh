#!/bin/bash
# =============================================================================
# Restaure une sauvegarde faite par deploy/sauvegarder.sh.
#
#   ./deploy/restaurer.sh ~/souk-sauvegardes/souk_2026-11-02_0230.dmp.gz
#   ./deploy/restaurer.sh ~/souk-sauvegardes/souk_….dmp.gz ~/souk-sauvegardes/uploads_….tar.gz
#
# ATTENTION : le schéma actuel est entièrement remplacé par celui de la
# sauvegarde (et les photos aussi, si l'archive est donnée). Le .env doit
# être celui de la sauvegarde ou du même serveur (mêmes mots de passe).
# =============================================================================
set -euo pipefail
DUMP_GZ="$(realpath "${1:?Usage : $0 <souk_….dmp.gz> [uploads_….tar.gz]}")"
UPLOADS="${2:+$(realpath "$2")}"
cd "$(dirname "$0")/.."
COMPOSE=(docker compose -f docker-compose.prod.yml)

[[ -f "$DUMP_GZ" ]] || { echo "Fichier introuvable : $DUMP_GZ" >&2; exit 1; }
[[ -z "$UPLOADS" || -f "$UPLOADS" ]] || { echo "Fichier introuvable : $UPLOADS" >&2; exit 1; }

if [[ -t 0 ]]; then
    read -rp "Le schéma actuel va être REMPLACÉ par $(basename "$DUMP_GZ"). Continuer ? (oui/non) " reponse
    [[ "$reponse" == oui ]] || { echo "Abandon."; exit 1; }
fi

echo "==> Arrêt de PHP (plus aucune connexion à la base)"
"${COMPOSE[@]}" stop php

echo "==> Copie de la sauvegarde dans le dossier DATA_PUMP_DIR du conteneur"
DOSSIER_DUMP=$("${COMPOSE[@]}" exec -T oracle bash -c '
    sqlplus -s "system/${ORACLE_PASSWORD}@//localhost/FREEPDB1" <<SQL
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT directory_path FROM dba_directories WHERE directory_name = '"'"'DATA_PUMP_DIR'"'"';
SQL' | tr -d '[:space:]')
gunzip -c "$DUMP_GZ" | "${COMPOSE[@]}" exec -T oracle bash -c "cat > '$DOSSIER_DUMP/restauration.dmp'"

echo "==> Suppression des objets du schéma actuel (00_reinitialiser.sql)"
"${COMPOSE[@]}" exec -T oracle bash -c '
    sqlplus -s -L "${APP_USER}/${APP_USER_PASSWORD}@//localhost/FREEPDB1" <<SQL
WHENEVER SQLERROR EXIT FAILURE
@/opt/souk/database/00_reinitialiser.sql
EXIT SUCCESS
SQL'

echo "==> Import Data Pump (impdp)"
"${COMPOSE[@]}" exec -T oracle bash -c '
    impdp "system/${ORACLE_PASSWORD}@//localhost/FREEPDB1" schemas="$APP_USER" directory=DATA_PUMP_DIR \
        dumpfile=restauration.dmp logfile=restauration.log
    statut=$?
    rm -f "'"$DOSSIER_DUMP"'/restauration.dmp"
    # 0 = succès ; 5 = terminé avec des avertissements. ORA-31684 « USER already
    # exists » est attendu : on importe dans le schéma existant, vidé juste avant.
    [[ $statut -eq 0 || $statut -eq 5 ]]'

echo "==> Recompilation du schéma"
# impdp crée les corps de packages dans un ordre qui en laisse certains
# INVALID (une dépendance arrive après eux) : on recompile, puis on vérifie
"${COMPOSE[@]}" exec -T oracle bash -c '
    sqlplus -s -L "${APP_USER}/${APP_USER_PASSWORD}@//localhost/FREEPDB1" <<SQL
WHENEVER SQLERROR EXIT FAILURE
SET FEEDBACK OFF SERVEROUTPUT ON
EXEC DBMS_UTILITY.COMPILE_SCHEMA(USER, compile_all => FALSE)
DECLARE
    v_nb PLS_INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb FROM user_objects WHERE status <> '"'"'VALID'"'"';
    IF v_nb > 0 THEN
        RAISE_APPLICATION_ERROR(-20999, v_nb || '"'"' objet(s) invalide(s) après la restauration'"'"');
    END IF;
    DBMS_OUTPUT.PUT_LINE('"'"'Tous les objets du schéma sont valides.'"'"');
END;
/
EXIT SUCCESS
SQL'

if [[ -n "$UPLOADS" ]]; then
    echo "==> Restauration des photos envoyées"
    "${COMPOSE[@]}" run --rm --no-deps -T --entrypoint sh php -c \
        'find /var/www/html/public/uploads -mindepth 1 ! -name .gitkeep -delete && tar -C /var/www/html/public -xzf -' \
        < "$UPLOADS"
fi

echo "==> Redémarrage de PHP"
"${COMPOSE[@]}" up -d --force-recreate --no-deps php
echo "Restauration terminée."
