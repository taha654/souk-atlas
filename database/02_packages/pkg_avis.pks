-- =============================================================================
-- PKG_AVIS : avis des clients sur les produits
-- La note moyenne du produit est recalculée par le trigger TRG_AVIS_NOTE_MOYENNE.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_avis AS

    -- Uniquement après une commande LIVREE contenant le produit, et un seul
    -- avis par client et par produit (-20010 sinon) ; note entière de 1 à 5 (-20017)
    PROCEDURE deposer(
        p_id_utilisateur IN  NUMBER,
        p_id_produit     IN  NUMBER,
        p_note           IN  NUMBER,
        p_commentaire    IN  VARCHAR2,
        p_id             OUT NUMBER);

    -- Modération : 'PUBLIE' ou 'MASQUE'
    PROCEDURE changer_statut(p_id_avis IN NUMBER, p_statut IN VARCHAR2);

    -- 1 si l'utilisateur peut encore donner son avis sur ce produit (pour afficher le formulaire)
    FUNCTION peut_donner_avis(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER) RETURN NUMBER;

END pkg_avis;
/
