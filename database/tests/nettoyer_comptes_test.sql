-- =============================================================================
-- Supprime les comptes créés par les tests HTTP et navigateur (emails
-- "test-…@exemple.ma") et tout ce qui en dépend. Le stock décrémenté par leurs
-- commandes est d'abord rendu aux produits.
-- Lancé par les scripts de tests ; sans effet si aucun compte de test n'existe.
-- =============================================================================
DECLARE
    -- SYS.ODCINUMBERLIST : collection de nombres définie au niveau SQL par Oracle.
    -- Contrairement à un type déclaré dans ce bloc, l'ordre SQL la connaît :
    -- on peut donc écrire TABLE(v_comptes) dans un SELECT (compatible 19c).
    v_comptes    SYS.ODCINUMBERLIST;
    v_commandes  SYS.ODCINUMBERLIST;
BEGIN
    SELECT id BULK COLLECT INTO v_comptes FROM utilisateur WHERE email LIKE 'test-%@exemple.ma';
    IF v_comptes.COUNT = 0 THEN
        RETURN;
    END IF;

    SELECT id BULK COLLECT INTO v_commandes
      FROM commande WHERE id_client IN (SELECT COLUMN_VALUE FROM TABLE(v_comptes));

    -- 1. Stock rendu (les commandes annulées l'ont déjà été par PKG_COMMANDE.annuler)
    UPDATE produit p
       -- NVL : sur un ensemble vide (que des lignes annulées), SUM renvoie NULL, et
       -- stock + NULL = NULL (ORA-01407, la colonne est NOT NULL)
       SET p.stock = p.stock + (SELECT NVL(SUM(cl.quantite), 0)
                                  FROM commande_ligne cl JOIN commande c ON c.id = cl.id_commande
                                 WHERE cl.id_produit = p.id AND c.statut <> 'ANNULEE'
                                   AND c.id IN (SELECT COLUMN_VALUE FROM TABLE(v_commandes)))
     WHERE p.id IN (SELECT cl.id_produit FROM commande_ligne cl
                     WHERE cl.id_commande IN (SELECT COLUMN_VALUE FROM TABLE(v_commandes)));

    -- 2. Dépendances, des feuilles vers la racine (ordre imposé par les clés étrangères)
    DELETE FROM signalement WHERE id_auteur IN (SELECT COLUMN_VALUE FROM TABLE(v_comptes))
        OR id_avis IN (SELECT id FROM avis WHERE id_utilisateur IN (SELECT COLUMN_VALUE FROM TABLE(v_comptes)));
    DELETE FROM avis WHERE id_utilisateur IN (SELECT COLUMN_VALUE FROM TABLE(v_comptes));
    DELETE FROM paiement WHERE id_commande IN (SELECT COLUMN_VALUE FROM TABLE(v_commandes));
    DELETE FROM commande_ligne WHERE id_commande IN (SELECT COLUMN_VALUE FROM TABLE(v_commandes));
    DELETE FROM commande WHERE id IN (SELECT COLUMN_VALUE FROM TABLE(v_commandes));
    DELETE FROM panier WHERE id_utilisateur IN (SELECT COLUMN_VALUE FROM TABLE(v_comptes));
    DELETE FROM favori WHERE id_utilisateur IN (SELECT COLUMN_VALUE FROM TABLE(v_comptes));
    DELETE FROM tentative_connexion WHERE email LIKE 'test-%@exemple.ma';
    DELETE FROM journal_audit
     WHERE (nom_table = 'UTILISATEUR' AND id_ligne IN (SELECT COLUMN_VALUE FROM TABLE(v_comptes)))
        OR (nom_table = 'COMMANDE' AND id_ligne IN (SELECT COLUMN_VALUE FROM TABLE(v_commandes)));
    DELETE FROM utilisateur WHERE id IN (SELECT COLUMN_VALUE FROM TABLE(v_comptes));

    DBMS_OUTPUT.PUT_LINE(v_comptes.COUNT || ' compte(s) de test et ' || v_commandes.COUNT || ' commande(s) supprimés.');
END;
/
COMMIT;
