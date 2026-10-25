#!/bin/bash
# =============================================================================
# Sauvegarde de production : schéma Oracle (Data Pump), photos envoyées, .env.
# Lancé chaque nuit par cron (installé par deploy.sh), avant la réinitialisation
# de la démo. Restauration : docs/deploiement.md, section « Sauvegardes ».
#
#   ./deploy/sauvegarder.sh                 → ~/souk-sauvegardes/
#   SAUVEGARDES=/autre/dossier GARDER_JOURS=14 ./deploy/sauvegarder.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
COMPOSE=(docker compose -f docker-compose.prod.yml)

DESTINATION="${SAUVEGARDES:-$HOME/souk-sauvegardes}"
GARDER_JOURS="${GARDER_JOURS:-7}"
HORODATAGE="$(date +%Y-%m-%d_%H%M)"
DUMP="souk_$HORODATAGE.dmp"

# Dossier lisible par son seul propriétaire : il contiendra le .env
mkdir -p "$DESTINATION"
chmod 700 "$DESTINATION"
echo "=== $(date '+%F %T') Sauvegarde vers $DESTINATION"

# 1. Base : export Data Pump (expdp) du schéma de l'application, fait par SYSTEM
#    dans le dossier Oracle DATA_PUMP_DIR, à l'intérieur du conteneur.
#    Les variables ORACLE_PASSWORD et APP_USER sont celles du conteneur.
"${COMPOSE[@]}" exec -T -e DUMP="$DUMP" oracle bash -c '
    set -euo pipefail
    connexion="system/${ORACLE_PASSWORD}@//localhost/FREEPDB1"
    expdp "$connexion" schemas="$APP_USER" directory=DATA_PUMP_DIR \
        dumpfile="$DUMP" logfile="${DUMP%.dmp}.log" reuse_dumpfiles=yes >/dev/null 2>&1 \
        || { echo "expdp a échoué" >&2; exit 1; }
'
# Chemin réel de DATA_PUMP_DIR dans le conteneur
DOSSIER_DUMP=$("${COMPOSE[@]}" exec -T oracle bash -c '
    sqlplus -s "system/${ORACLE_PASSWORD}@//localhost/FREEPDB1" <<SQL
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT directory_path FROM dba_directories WHERE directory_name = '"'"'DATA_PUMP_DIR'"'"';
SQL' | tr -d '[:space:]')
# Le fichier sort du conteneur (compressé), puis est effacé à l'intérieur :
# il ne doit pas grossir le volume de la base
"${COMPOSE[@]}" exec -T oracle cat "$DOSSIER_DUMP/$DUMP" | gzip > "$DESTINATION/$DUMP.gz"
"${COMPOSE[@]}" exec -T oracle rm -f "$DOSSIER_DUMP/$DUMP" "$DOSSIER_DUMP/${DUMP%.dmp}.log"
echo "Base   : $DUMP.gz ($(du -h "$DESTINATION/$DUMP.gz" | cut -f1))"

# 2. Photos envoyées par les visiteurs (volume "uploads")
"${COMPOSE[@]}" exec -T php tar -C /var/www/html/public -czf - uploads > "$DESTINATION/uploads_$HORODATAGE.tar.gz"
echo "Photos : uploads_$HORODATAGE.tar.gz"

# 3. .env : sans lui, impossible de relire la base restaurée (mots de passe)
install -m 600 .env "$DESTINATION/env_$HORODATAGE"
echo "Config : env_$HORODATAGE"

# 4. Rotation : on ne garde que les GARDER_JOURS derniers jours
find "$DESTINATION" -maxdepth 1 -type f \( -name 'souk_*' -o -name 'uploads_*' -o -name 'env_*' \) \
    -mtime +"$GARDER_JOURS" -delete
echo "=== Terminé (sauvegardes de plus de $GARDER_JOURS jours supprimées)"
