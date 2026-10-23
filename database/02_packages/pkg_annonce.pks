-- =============================================================================
-- PKG_ANNONCE : petites annonces « Occasion » et favoris
--
-- Cycle de vie :
--   publication → EN_LIGNE (ou EN_MODERATION si le score de risque est élevé)
--   EN_MODERATION → EN_LIGNE (approuvée) ou REFUSEE
--   EN_LIGNE → VENDUE (par son auteur) ou EXPIREE (job, après 30 jours)
--   EXPIREE ou EN_LIGNE → EN_LIGNE pour 30 jours de plus (renouveler)
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_annonce AS

    c_duree_jours       CONSTANT PLS_INTEGER := 30;
    -- À partir de ce score (calculé par le moteur C++), l'annonce attend un modérateur
    c_seuil_moderation  CONSTANT PLS_INTEGER := 60;

    PROCEDURE publier(
        p_id_utilisateur IN  NUMBER,
        p_id_categorie   IN  NUMBER,
        p_titre          IN  VARCHAR2,
        p_description    IN  VARCHAR2,
        p_prix           IN  NUMBER,
        p_ville          IN  VARCHAR2,
        p_score_risque   IN  NUMBER DEFAULT NULL,
        p_id             OUT NUMBER);

    -- p_decision : 'APPROUVER' ou 'REFUSER' (p_motif obligatoire pour un refus)
    PROCEDURE moderer(p_id_annonce IN NUMBER, p_decision IN VARCHAR2, p_motif IN VARCHAR2 DEFAULT NULL);

    -- Actions réservées à l'auteur de l'annonce (-20012 sinon)
    PROCEDURE renouveler(p_id_annonce IN NUMBER, p_id_utilisateur IN NUMBER);
    PROCEDURE marquer_vendue(p_id_annonce IN NUMBER, p_id_utilisateur IN NUMBER);

    -- Appelée par le job JOB_EXPIRATION_ANNONCES ; p_nb = annonces expirées
    PROCEDURE expirer_annonces(p_nb OUT NUMBER);

    -- Favoris (ajouter deux fois la même annonce n'est pas une erreur)
    PROCEDURE ajouter_favori(p_id_utilisateur IN NUMBER, p_id_annonce IN NUMBER);
    PROCEDURE retirer_favori(p_id_utilisateur IN NUMBER, p_id_annonce IN NUMBER);

END pkg_annonce;
/
