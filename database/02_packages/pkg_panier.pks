-- =============================================================================
-- PKG_PANIER : panier d'un utilisateur connecté (un panier par utilisateur)
-- Le panier d'un visiteur non connecté vit dans la session PHP ; il est versé
-- ici à la connexion (appels successifs à ajouter).
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_panier AS

    -- TVA marocaine standard ; utilisée aussi par PKG_COMMANDE
    c_taux_tva CONSTANT NUMBER := 0.20;

    -- Ajoute p_quantite exemplaires (cumulés avec ceux déjà présents).
    -- Erreurs : -20004 produit indisponible, -20005 quantité invalide,
    --           -20001 stock insuffisant pour la quantité totale.
    PROCEDURE ajouter(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER, p_quantite IN NUMBER DEFAULT 1);

    -- Fixe la quantité ; 0 retire la ligne
    PROCEDURE modifier_quantite(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER, p_quantite IN NUMBER);

    PROCEDURE retirer(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER);
    PROCEDURE vider(p_id_utilisateur IN NUMBER);

    -- Totaux recalculés à partir des prix EN BASE (promotions comprises),
    -- jamais à partir de ce qu'envoie le navigateur. TVA arrondie par boutique,
    -- comme les commandes : le total affiché est celui qui sera facturé.
    PROCEDURE calculer_totaux(
        p_id_utilisateur IN  NUMBER,
        p_total_ht       OUT NUMBER,
        p_tva            OUT NUMBER,
        p_total_ttc      OUT NUMBER,
        p_nb_articles    OUT NUMBER);

    -- Pour le badge du panier
    FUNCTION nb_articles(p_id_utilisateur IN NUMBER) RETURN NUMBER;

    -- Lignes du panier : id_produit, nom, id_boutique, boutique, quantite, stock,
    -- prix_unitaire_ht, prix_unitaire_ttc, total_ligne_ht, disponible (1/0)
    FUNCTION lignes(p_id_utilisateur IN NUMBER) RETURN SYS_REFCURSOR;

    -- Appelée par le job JOB_PURGE_PANIERS ; p_nb = paniers supprimés
    PROCEDURE purger_paniers_abandonnes(p_jours IN NUMBER DEFAULT 30, p_nb OUT NUMBER);

END pkg_panier;
/
