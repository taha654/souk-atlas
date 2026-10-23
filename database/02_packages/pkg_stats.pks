-- =============================================================================
-- PKG_STATS : statistiques de ventes (tableaux de bord vendeur et admin)
--
-- Une vente = une commande non ANNULEE. Les montants sont HORS TAXE (le
-- chiffre d'affaires d'un vendeur ne comprend pas la TVA qu'il reverse à l'État).
-- p_id_boutique NULL = toutes les boutiques (admin).
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_stats AS

    -- Un jour par ligne, y compris les jours sans vente :
    -- jour, nb_commandes, ca_ht, ca_cumule (SUM … OVER)
    FUNCTION ca_par_jour(p_debut IN DATE, p_fin IN DATE, p_id_boutique IN NUMBER DEFAULT NULL)
        RETURN SYS_REFCURSOR;

    -- Les 12 mois de l'année : mois (1-12), nb_commandes, ca_ht,
    -- evolution_pct par rapport au mois précédent (LAG)
    FUNCTION ca_par_mois(p_annee IN NUMBER, p_id_boutique IN NUMBER DEFAULT NULL) RETURN SYS_REFCURSOR;

    -- Classement des boutiques : rang (RANK), boutique, nb_commandes, ca_ht,
    -- part_pct (RATIO_TO_REPORT : part du CA total)
    FUNCTION ca_par_vendeur(p_debut IN DATE, p_fin IN DATE) RETURN SYS_REFCURSOR;

    -- Produits les plus vendus en quantité : rang, id_produit, nom, quantite, ca_ht.
    -- Avec RANK, deux produits ex aequo ont le même rang (on peut donc
    -- obtenir un peu plus de p_limite lignes).
    FUNCTION meilleures_ventes(
        p_debut IN DATE, p_fin IN DATE, p_limite IN NUMBER DEFAULT 10, p_id_boutique IN NUMBER DEFAULT NULL)
        RETURN SYS_REFCURSOR;

    -- Panier moyen TTC : par achat (toutes boutiques) ou par commande (une boutique)
    FUNCTION panier_moyen(p_debut IN DATE, p_fin IN DATE, p_id_boutique IN NUMBER DEFAULT NULL) RETURN NUMBER;

    -- Chiffres clés d'une boutique sur la période (tuiles du tableau de bord)
    PROCEDURE resume_boutique(
        p_id_boutique     IN  NUMBER,
        p_debut           IN  DATE,
        p_fin             IN  DATE,
        p_nb_commandes    OUT NUMBER,
        p_ca_ht           OUT NUMBER,
        p_panier_moyen    OUT NUMBER,
        p_articles_vendus OUT NUMBER);

END pkg_stats;
/
