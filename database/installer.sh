#!/bin/bash
# =============================================================================
# Installe le schéma Souk Atlas : 01_schema → 02_packages → 03_triggers
# → 04_jobs → 05_seed. S'exécute DANS le conteneur Oracle :
#
#   docker compose exec oracle /opt/souk/database/installer.sh
#   docker compose exec oracle /opt/souk/database/installer.sh --reinitialiser
#
# --reinitialiser supprime d'abord tous les objets du schéma (00_reinitialiser.sql).
# Le script s'arrête à la première erreur SQL ou de compilation PL/SQL.
# =============================================================================
set -euo pipefail

DOSSIER="$(cd "$(dirname "$0")" && pwd)"
# Service Oracle : FREEPDB1 (Oracle Free 23ai), XEPDB1 pour vérifier sur Oracle XE 21c
CONNEXION="${APP_USER}/${APP_USER_PASSWORD}@//localhost/${DB_SERVICE:-FREEPDB1}"
# UTF-8 côté client, sinon les accents des scripts seraient mal convertis
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

# Exécute un fichier SQL ; quitte avec une erreur au premier ORA- ou SP2-
executer() {
    local fichier="$1"
    echo "==> ${fichier#"$DOSSIER"/}"
    sqlplus -s -L "$CONNEXION" <<SQL
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
WHENEVER OSERROR EXIT FAILURE ROLLBACK
SET FEEDBACK OFF DEFINE OFF SERVEROUTPUT ON SIZE UNLIMITED
@"$fichier"
COMMIT;
EXIT SUCCESS
SQL
}

# Une erreur de compilation PL/SQL n'est PAS une erreur SQL pour SQL*Plus
# ("créé avec des erreurs de compilation") : on interroge USER_ERRORS.
verifier_compilation() {
    sqlplus -s -L "$CONNEXION" <<'SQL'
WHENEVER SQLERROR EXIT FAILURE
SET FEEDBACK OFF SERVEROUTPUT ON LINESIZE 200 PAGESIZE 100
COLUMN objet FORMAT A35
COLUMN erreur FORMAT A120
SELECT name || ' (' || type || ') ligne ' || line AS objet, text AS erreur
  FROM user_errors ORDER BY name, type, sequence;
DECLARE
    v_nb NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_nb FROM user_errors;
    IF v_nb > 0 THEN
        RAISE_APPLICATION_ERROR(-20999, v_nb || ' erreur(s) de compilation PL/SQL');
    END IF;
END;
/
EXIT SUCCESS
SQL
}

if [[ "${1:-}" == "--reinitialiser" ]]; then
    executer "$DOSSIER/00_reinitialiser.sql"
fi

executer "$DOSSIER/01_schema.sql"
executer "$DOSSIER/02_packages/installer_packages.sql"
verifier_compilation
executer "$DOSSIER/03_triggers.sql"
verifier_compilation
executer "$DOSSIER/04_jobs.sql"
executer "$DOSSIER/05_seed.sql"

echo "Installation terminée."
