-- =============================================================================
-- Migration (étape 8) : table des recommandations calculées par le moteur C++.
-- 01_schema.sql la contient déjà pour une installation neuve ; ce script
-- l'ajoute à une base EXISTANTE, sans toucher aux données. Ensuite, recompiler
-- les packages (installer_packages.sql).
--   docker compose exec -T oracle bash -c 'sqlplus -s "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1" @/opt/souk/database/migrations/2026-10-25_recommandation.sql'
-- =============================================================================
WHENEVER SQLERROR EXIT FAILURE
CREATE TABLE recommandation (
    id_produit             NUMBER        NOT NULL,
    id_produit_recommande  NUMBER        NOT NULL,
    -- Similarité cosinus (0 à 1) calculée par le moteur
    score                  NUMBER(5, 4)  NOT NULL,
    -- Nombre d'achats contenant les deux produits
    nb_communs             NUMBER(10)    NOT NULL,
    date_calcul            DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_recommandation PRIMARY KEY (id_produit, id_produit_recommande),
    CONSTRAINT fk_recommandation_produit FOREIGN KEY (id_produit) REFERENCES produit (id) ON DELETE CASCADE,
    CONSTRAINT fk_recommandation_recommande FOREIGN KEY (id_produit_recommande) REFERENCES produit (id) ON DELETE CASCADE,
    CONSTRAINT ck_recommandation_distincts CHECK (id_produit <> id_produit_recommande),
    CONSTRAINT ck_recommandation_score CHECK (score BETWEEN 0 AND 1),
    CONSTRAINT ck_recommandation_communs CHECK (nb_communs >= 1)
);
-- La clé primaire indexe déjà id_produit (première colonne) ; il reste la seconde FK
CREATE INDEX ix_recommandation_recommande ON recommandation (id_produit_recommande);
EXIT
