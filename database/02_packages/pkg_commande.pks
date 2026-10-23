-- =============================================================================
-- PKG_COMMANDE : passage de commande, cycle de vie, annulation
--
-- Cycle de vie (voir transition_autorisee) :
--   CARTE     : EN_ATTENTE → PAYEE → EXPEDIEE → LIVREE
--   LIVRAISON : EN_ATTENTE → EXPEDIEE → LIVREE (le paiement est encaissé à la livraison)
--   ANNULEE   : possible depuis EN_ATTENTE ou PAYEE (remise en stock, remboursement)
--
-- Aucune procédure ne fait COMMIT : c'est PHP qui valide (oci_commit) ou annule
-- (oci_rollback) la transaction entière.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_commande AS

    -- Transforme le panier du client en commandes (une par boutique) dans UNE
    -- transaction : verrouillage du stock, contrôles, création des commandes et
    -- des lignes, décrément du stock, paiement, vidage du panier.
    -- p_reference reçoit la référence d'achat commune ("ACH-2026-000042").
    -- Erreurs : -20003 panier vide, -20004 produit indisponible, -20001 stock
    --           insuffisant, -20006/-20007 carte, -20017 adresse ou mode invalide.
    PROCEDURE passer_commande(
        p_id_client      IN  NUMBER,
        p_mode_paiement  IN  VARCHAR2,
        p_adresse        IN  VARCHAR2,
        p_ville          IN  VARCHAR2,
        p_telephone      IN  VARCHAR2,
        p_numero_carte   IN  VARCHAR2 DEFAULT NULL,
        p_mois_exp       IN  NUMBER   DEFAULT NULL,
        p_annee_exp      IN  NUMBER   DEFAULT NULL,
        p_cvv            IN  VARCHAR2 DEFAULT NULL,
        p_reference      OUT VARCHAR2);

    -- 1 si on peut passer de p_ancien à p_nouveau pour ce mode de paiement
    FUNCTION transition_autorisee(
        p_ancien IN VARCHAR2, p_nouveau IN VARCHAR2, p_mode_paiement IN VARCHAR2) RETURN NUMBER;

    -- -20002 si la transition est interdite ; ANNULEE délègue à annuler
    PROCEDURE changer_statut(p_id_commande IN NUMBER, p_nouveau_statut IN VARCHAR2);

    -- Le vendeur fait avancer SES commandes : EXPEDIEE, LIVREE ou ANNULEE.
    -- -20012 si la commande n'est pas de sa boutique, -20002 pour un autre statut
    -- (PAYEE ne dépend que du paiement, jamais du vendeur)
    PROCEDURE changer_statut_par_vendeur(p_id_commande IN NUMBER, p_id_boutique IN NUMBER, p_nouveau_statut IN VARCHAR2);

    -- Remet le stock et rembourse ; -20016 si la commande est déjà expédiée
    PROCEDURE annuler(p_id_commande IN NUMBER);

    -- Score de risque (0 à 100) calculé par le moteur C++ après la commande ;
    -- -20017 hors de [0, 100], -20018 si la commande n'existe pas
    PROCEDURE definir_score(p_id_commande IN NUMBER, p_score IN NUMBER);

    -- Données dont le moteur a besoin pour noter les commandes d'un achat.
    -- Colonnes : id, numero, total_ttc, quantite_max, mode_paiement,
    --            commandes_precedentes, panier_moyen, commandes_24h, anciennete_jours
    FUNCTION contexte_risque(p_reference_achat IN VARCHAR2) RETURN SYS_REFCURSOR;

END pkg_commande;
/
