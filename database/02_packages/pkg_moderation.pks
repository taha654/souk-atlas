-- =============================================================================
-- PKG_MODERATION : signalements des utilisateurs, traités par un admin
-- Un signalement vise une ANNONCE, un AVIS ou un PRODUIT.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_moderation AS

    -- p_type_cible : 'ANNONCE', 'AVIS' ou 'PRODUIT'
    -- p_motif      : 'ARNAQUE', 'CONTREFACON', 'INAPPROPRIE', 'DOUBLON' ou 'AUTRE'
    -- -20018 si la cible n'existe pas, -20017 si l'auteur l'a déjà signalée
    PROCEDURE signaler(
        p_id_auteur    IN  NUMBER,
        p_type_cible   IN  VARCHAR2,
        p_id_cible     IN  NUMBER,
        p_motif        IN  VARCHAR2,
        p_commentaire  IN  VARCHAR2,
        p_id           OUT NUMBER);

    -- p_decision : 'APPROUVER' (la cible est retirée) ou 'REJETER' (rien ne change).
    -- La décision s'applique à TOUS les signalements ouverts sur la même cible.
    -- -20002 si le signalement est déjà traité.
    PROCEDURE traiter(p_id_signalement IN NUMBER, p_id_moderateur IN NUMBER, p_decision IN VARCHAR2);

END pkg_moderation;
/
