-- =============================================================================
-- Migration (étape 6) : recherche d'annonces insensible aux accents.
-- 01_schema.sql contient déjà ces changements pour une installation neuve ;
-- ce script les applique à une base EXISTANTE, sans perdre ses données.
--   docker compose exec -T oracle bash -c 'sqlplus -s "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1" @/opt/souk/database/migrations/2026-10-24_annonce_titre_recherche.sql'
-- =============================================================================
WHENEVER SQLERROR EXIT FAILURE
ALTER TABLE annonce ADD (
    titre_recherche VARCHAR2(150 CHAR) GENERATED ALWAYS AS (
        TRANSLATE(LOWER(titre), 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy')) VIRTUAL
);
CREATE INDEX ix_annonce_titre_recherche ON annonce (titre_recherche);
EXIT
