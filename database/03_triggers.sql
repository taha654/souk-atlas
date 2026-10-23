-- =============================================================================
-- Souk Atlas : triggers
--   * historique des prix
--   * stock jamais négatif (message clair, en plus de la contrainte CK_PRODUIT_STOCK)
--   * note moyenne des produits (trigger COMPOSÉ, voir l'explication plus bas)
--   * journal d'audit sur UTILISATEUR, PRODUIT et COMMANDE
--
-- "Auteur" d'une modification : PHP se connecte toujours avec le même compte
-- Oracle (SOUK). Pour savoir QUEL utilisateur du site agit, PHP pose un
-- "client identifier" sur la session (oci_set_client_identifier) que les
-- triggers relisent avec SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER').
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Historique des prix : une ligne à chaque changement de prix_ht
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_produit_historique_prix
AFTER UPDATE OF prix_ht ON produit
FOR EACH ROW
-- La clause WHEN évite d'exécuter le corps si le prix ne change pas vraiment
-- (dans WHEN, on écrit OLD/NEW sans les deux-points)
WHEN (OLD.prix_ht <> NEW.prix_ht)
BEGIN
    INSERT INTO historique_prix (id_produit, ancien_prix_ht, nouveau_prix_ht, modifie_par)
    VALUES (:OLD.id, :OLD.prix_ht, :NEW.prix_ht,
            NVL(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), USER));
END;
/

-- -----------------------------------------------------------------------------
-- Stock négatif : la contrainte CHECK suffirait à l'interdire, mais elle
-- produit "ORA-02290: check constraint violated". Ce trigger BEFORE intercepte
-- le cas avant la contrainte et lève l'erreur métier -20001, que PHP sait traduire.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_produit_stock_positif
BEFORE INSERT OR UPDATE OF stock ON produit
FOR EACH ROW
WHEN (NEW.stock < 0)
BEGIN
    RAISE_APPLICATION_ERROR(-20001,
        'Stock insuffisant pour ' || :NEW.nom || ' : le stock ne peut pas devenir négatif.');
END;
/

-- -----------------------------------------------------------------------------
-- Note moyenne : TRIGGER COMPOSÉ (Oracle 11g+)
--
-- Un trigger FOR EACH ROW sur AVIS ne peut pas relire la table AVIS : elle est
-- "en mutation" pendant l'ordre SQL (erreur ORA-04091). Le trigger composé
-- contourne le problème en deux temps :
--   1. AFTER EACH ROW  : on mémorise seulement les id de produits concernés ;
--   2. AFTER STATEMENT : l'ordre est terminé, AVIS n'est plus en mutation,
--      on recalcule la moyenne de chaque produit mémorisé.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_avis_note_moyenne
FOR INSERT OR UPDATE OF note, statut, id_produit OR DELETE ON avis
COMPOUND TRIGGER

    -- Tableau associatif utilisé comme un "ensemble" : l'indice est l'id du
    -- produit, la valeur ne sert à rien (un même produit n'est stocké qu'une fois)
    TYPE t_ensemble_id IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    g_produits t_ensemble_id;

    AFTER EACH ROW IS
    BEGIN
        IF INSERTING OR UPDATING THEN
            g_produits(:NEW.id_produit) := TRUE;
        END IF;
        IF DELETING OR UPDATING THEN
            g_produits(:OLD.id_produit) := TRUE;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id PLS_INTEGER := g_produits.FIRST;
    BEGIN
        WHILE v_id IS NOT NULL LOOP
            -- Seuls les avis PUBLIES comptent ; sans avis, la note redevient NULL
            UPDATE produit p
               SET (p.note_moyenne, p.nb_avis) =
                   (SELECT ROUND(AVG(a.note), 2), COUNT(*)
                      FROM avis a
                     WHERE a.id_produit = v_id AND a.statut = 'PUBLIE')
             WHERE p.id = v_id;
            v_id := g_produits.NEXT(v_id);
        END LOOP;
        g_produits.DELETE;
    END AFTER STATEMENT;

END trg_avis_note_moyenne;
/

-- -----------------------------------------------------------------------------
-- Journal d'audit
-- Les valeurs sont résumées en texte "colonne=valeur; …". Le hash du mot de
-- passe n'est JAMAIS recopié dans le journal.
--
-- Remarque 19c : INSERTING / UPDATING / DELETING sont des BOOLEAN PL/SQL ; ils
-- ne peuvent pas apparaître dans l'ordre INSERT (SQL). On calcule donc les
-- valeurs dans des variables avant l'INSERT.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_audit_utilisateur
AFTER INSERT OR UPDATE OF email, role, statut OR DELETE ON utilisateur
FOR EACH ROW
DECLARE
    v_operation  journal_audit.operation%TYPE;
    v_ancien     journal_audit.ancienne_valeur%TYPE;
    v_nouveau    journal_audit.nouvelle_valeur%TYPE;
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSE
        v_operation := 'DELETE';
    END IF;
    IF NOT INSERTING THEN
        v_ancien := 'email=' || :OLD.email || '; role=' || :OLD.role || '; statut=' || :OLD.statut;
    END IF;
    IF NOT DELETING THEN
        v_nouveau := 'email=' || :NEW.email || '; role=' || :NEW.role || '; statut=' || :NEW.statut;
    END IF;

    INSERT INTO journal_audit (nom_table, id_ligne, operation, auteur, ancienne_valeur, nouvelle_valeur)
    VALUES ('UTILISATEUR', NVL(:NEW.id, :OLD.id), v_operation,
            NVL(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), USER), v_ancien, v_nouveau);
END;
/

CREATE OR REPLACE TRIGGER trg_audit_produit
AFTER INSERT OR UPDATE OF nom, prix_ht, stock, statut OR DELETE ON produit
FOR EACH ROW
DECLARE
    v_operation  journal_audit.operation%TYPE;
    v_ancien     journal_audit.ancienne_valeur%TYPE;
    v_nouveau    journal_audit.nouvelle_valeur%TYPE;
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSE
        v_operation := 'DELETE';
    END IF;
    IF NOT INSERTING THEN
        v_ancien := 'nom=' || :OLD.nom || '; prix_ht=' || :OLD.prix_ht
                 || '; stock=' || :OLD.stock || '; statut=' || :OLD.statut;
    END IF;
    IF NOT DELETING THEN
        v_nouveau := 'nom=' || :NEW.nom || '; prix_ht=' || :NEW.prix_ht
                  || '; stock=' || :NEW.stock || '; statut=' || :NEW.statut;
    END IF;

    INSERT INTO journal_audit (nom_table, id_ligne, operation, auteur, ancienne_valeur, nouvelle_valeur)
    VALUES ('PRODUIT', NVL(:NEW.id, :OLD.id), v_operation,
            NVL(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), USER), v_ancien, v_nouveau);
END;
/

CREATE OR REPLACE TRIGGER trg_audit_commande
AFTER INSERT OR UPDATE OF statut, total_ttc OR DELETE ON commande
FOR EACH ROW
DECLARE
    v_operation  journal_audit.operation%TYPE;
    v_ancien     journal_audit.ancienne_valeur%TYPE;
    v_nouveau    journal_audit.nouvelle_valeur%TYPE;
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSE
        v_operation := 'DELETE';
    END IF;
    IF NOT INSERTING THEN
        v_ancien := 'numero=' || :OLD.numero || '; statut=' || :OLD.statut || '; total_ttc=' || :OLD.total_ttc;
    END IF;
    IF NOT DELETING THEN
        v_nouveau := 'numero=' || :NEW.numero || '; statut=' || :NEW.statut || '; total_ttc=' || :NEW.total_ttc;
    END IF;

    INSERT INTO journal_audit (nom_table, id_ligne, operation, auteur, ancienne_valeur, nouvelle_valeur)
    VALUES ('COMMANDE', NVL(:NEW.id, :OLD.id), v_operation,
            NVL(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), USER), v_ancien, v_nouveau);
END;
/
