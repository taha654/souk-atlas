#!/bin/bash
# Exécuté une seule fois, à la création de la base (premier démarrage du conteneur).
# On se connecte avec l'utilisateur applicatif pour que la table lui appartienne.
# APP_USER et APP_USER_PASSWORD viennent de docker-compose.yml.
set -e

sqlplus -s "${APP_USER}/${APP_USER_PASSWORD}@//localhost/FREEPDB1" <<'SQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- Table temporaire de l'étape 0 : prouve que PHP lit bien dans Oracle.
-- Elle sera supprimée à l'étape 1, quand le vrai schéma arrivera.
CREATE TABLE hello (
    id       NUMBER GENERATED ALWAYS AS IDENTITY,
    message  VARCHAR2(200) NOT NULL,
    CONSTRAINT pk_hello PRIMARY KEY (id)
);

INSERT INTO hello (message) VALUES ('Bonjour depuis Oracle ! Souk Atlas est prêt.');
COMMIT;
EXIT
SQL
