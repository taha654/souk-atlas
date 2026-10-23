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

    -- Modification par l'auteur (annonce EN_LIGNE ou EN_MODERATION ; -20011 sinon).
    -- Le texte change : le score est recalculé. Une annonce en ligne dont le
    -- nouveau score atteint le seuil repart en modération (sinon, il suffirait de
    -- publier un texte anodin puis de le modifier pour échapper au contrôle).
    PROCEDURE modifier(
        p_id_annonce     IN NUMBER,
        p_id_utilisateur IN NUMBER,
        p_id_categorie   IN NUMBER,
        p_titre          IN VARCHAR2,
        p_description    IN VARCHAR2,
        p_prix           IN NUMBER,
        p_ville          IN VARCHAR2,
        p_score_risque   IN NUMBER DEFAULT NULL);

    -- Données dont le moteur C++ a besoin pour noter une annonce (une seule ligne) :
    --   prix_median, nb_annonces : annonces de la catégorie et de ses sous-catégories
    --                              (MEDIAN résiste mieux que AVG aux prix extrêmes)
    --   annonces_24h             : annonces publiées par l'auteur sur 24 h
    --   anciennete_jours         : âge du compte
    FUNCTION contexte_risque(p_id_utilisateur IN NUMBER, p_id_categorie IN NUMBER) RETURN SYS_REFCURSOR;

    -- Recherche des annonces EN LIGNE (insensible à la casse et aux accents).
    -- p_tri : 'recent' (défaut), 'prix_asc', 'prix_desc'.
    -- Colonnes : id, titre, prix, ville, id_categorie, categorie, date_publication,
    --            photo, total (nombre total de résultats, COUNT(*) OVER ())
    FUNCTION rechercher(
        p_texte         IN VARCHAR2 DEFAULT NULL,
        p_id_categorie  IN NUMBER   DEFAULT NULL,
        p_ville         IN VARCHAR2 DEFAULT NULL,
        p_prix_min      IN NUMBER   DEFAULT NULL,
        p_prix_max      IN NUMBER   DEFAULT NULL,
        p_tri           IN VARCHAR2 DEFAULT 'recent',
        p_page          IN NUMBER   DEFAULT 1,
        p_taille_page   IN NUMBER   DEFAULT 20) RETURN SYS_REFCURSOR;

    -- Photos d'annonce, réservées à l'auteur (-20012) ; au plus c_photos_max (-20017)
    c_photos_max CONSTANT PLS_INTEGER := 6;
    PROCEDURE ajouter_photo(p_id_annonce IN NUMBER, p_id_utilisateur IN NUMBER, p_chemin IN VARCHAR2, p_id OUT NUMBER);
    PROCEDURE retirer_photo(p_id_photo IN NUMBER, p_id_utilisateur IN NUMBER, p_chemin OUT VARCHAR2);

    -- Favoris (ajouter deux fois la même annonce n'est pas une erreur)
    PROCEDURE ajouter_favori(p_id_utilisateur IN NUMBER, p_id_annonce IN NUMBER);
    PROCEDURE retirer_favori(p_id_utilisateur IN NUMBER, p_id_annonce IN NUMBER);

END pkg_annonce;
/
