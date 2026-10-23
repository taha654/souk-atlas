-- =============================================================================
-- PKG_MESSAGERIE : conversations entre un acheteur et l'auteur d'une annonce
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_messagerie AS

    -- Renvoie la conversation existante ou en crée une.
    -- -20011 si l'annonce n'est pas en ligne, -20013 si on se contacte soi-même.
    PROCEDURE ouvrir_conversation(p_id_annonce IN NUMBER, p_id_acheteur IN NUMBER, p_id OUT NUMBER);

    -- -20012 si l'expéditeur ne participe pas à la conversation,
    -- -20013 si le message est vide ou trop long (2000 caractères maximum)
    PROCEDURE envoyer_message(
        p_id_conversation IN NUMBER, p_id_expediteur IN NUMBER, p_contenu IN VARCHAR2, p_id OUT NUMBER);

    -- Marque comme lus les messages REÇUS par p_id_lecteur ; p_nb = messages marqués
    PROCEDURE marquer_comme_lu(p_id_conversation IN NUMBER, p_id_lecteur IN NUMBER, p_nb OUT NUMBER);

    -- Pour le badge "messages non lus"
    FUNCTION nb_non_lus(p_id_utilisateur IN NUMBER) RETURN NUMBER;

    -- Messages d'id > p_apres_id : le JavaScript ne demande que les nouveaux (polling).
    -- Colonnes : id, id_expediteur, expediteur, contenu, lu, date_envoi
    FUNCTION messages(p_id_conversation IN NUMBER, p_id_lecteur IN NUMBER, p_apres_id IN NUMBER DEFAULT 0)
        RETURN SYS_REFCURSOR;

END pkg_messagerie;
/
