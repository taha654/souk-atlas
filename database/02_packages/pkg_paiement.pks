-- =============================================================================
-- PKG_PAIEMENT : paiement SIMULÉ (aucune banque n'est contactée)
--
-- Les fonctions de contrôle renvoient NUMBER (1 = vrai, 0 = faux) et non
-- BOOLEAN : avant Oracle 23ai, une fonction BOOLEAN n'est pas appelable en SQL
-- (SELECT pkg_paiement.luhn_valide('…') FROM dual) ni depuis PHP.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_paiement AS

    -- Algorithme de Luhn : la "clé" que vérifient tous les numéros de carte
    FUNCTION luhn_valide(p_numero IN VARCHAR2) RETURN NUMBER;

    -- 1 si la carte est expirée (valable jusqu'au dernier jour du mois indiqué)
    FUNCTION carte_expiree(p_mois IN NUMBER, p_annee IN NUMBER) RETURN NUMBER;

    -- Contrôle complet ; lève -20006 (carte refusée) ou -20007 (carte expirée)
    PROCEDURE verifier_carte(
        p_numero IN VARCHAR2, p_mois IN NUMBER, p_annee IN NUMBER, p_cvv IN VARCHAR2);

    -- Enregistrent le paiement d'une commande (ne contrôlent pas la carte :
    -- verifier_carte est appelée AVANT de créer les commandes)
    PROCEDURE enregistrer_carte(p_id_commande IN NUMBER, p_numero IN VARCHAR2, p_montant IN NUMBER);
    PROCEDURE enregistrer_livraison(p_id_commande IN NUMBER, p_montant IN NUMBER);

    -- Paiement à la livraison encaissé (commande LIVREE)
    PROCEDURE confirmer_livraison(p_id_commande IN NUMBER);

    -- Remboursement d'une commande payée puis annulée
    PROCEDURE rembourser(p_id_commande IN NUMBER);

END pkg_paiement;
/
