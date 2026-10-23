CREATE OR REPLACE PACKAGE BODY pkg_messagerie AS

    c_longueur_max CONSTANT PLS_INTEGER := 2000;

    -- Lève -20012 si l'utilisateur n'est ni l'acheteur ni le vendeur
    PROCEDURE verifier_participant(p_id_conversation IN NUMBER, p_id_utilisateur IN NUMBER) IS
        v_acheteur conversation.id_acheteur%TYPE;
        v_vendeur  conversation.id_vendeur%TYPE;
    BEGIN
        SELECT id_acheteur, id_vendeur INTO v_acheteur, v_vendeur
          FROM conversation WHERE id = p_id_conversation;
        IF p_id_utilisateur NOT IN (v_acheteur, v_vendeur) THEN
            pkg_erreurs.lever(pkg_erreurs.c_non_proprietaire, 'Vous ne participez pas à cette conversation.');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Conversation introuvable : ' || p_id_conversation);
    END verifier_participant;

    PROCEDURE ouvrir_conversation(p_id_annonce IN NUMBER, p_id_acheteur IN NUMBER, p_id OUT NUMBER) IS
        v_statut   annonce.statut%TYPE;
        v_vendeur  annonce.id_utilisateur%TYPE;
    BEGIN
        BEGIN
            SELECT statut, id_utilisateur INTO v_statut, v_vendeur FROM annonce WHERE id = p_id_annonce;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Annonce introuvable : ' || p_id_annonce);
        END;
        IF v_vendeur = p_id_acheteur THEN
            pkg_erreurs.lever(pkg_erreurs.c_conversation_invalide,
                'Vous ne pouvez pas vous contacter vous-même.');
        END IF;

        -- Conversation déjà ouverte : on la réutilise (même si l'annonce est
        -- vendue entre-temps, l'historique reste accessible)
        BEGIN
            SELECT id INTO p_id FROM conversation
             WHERE id_annonce = p_id_annonce AND id_acheteur = p_id_acheteur;
            RETURN;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN NULL;
        END;

        IF v_statut <> 'EN_LIGNE' THEN
            pkg_erreurs.lever(pkg_erreurs.c_etat_annonce_invalide, 'Cette annonce n''est plus en ligne.');
        END IF;

        INSERT INTO conversation (id_annonce, id_acheteur, id_vendeur)
        VALUES (p_id_annonce, p_id_acheteur, v_vendeur)
        RETURNING id INTO p_id;
    END ouvrir_conversation;

    PROCEDURE envoyer_message(
        p_id_conversation IN NUMBER, p_id_expediteur IN NUMBER, p_contenu IN VARCHAR2, p_id OUT NUMBER) IS
    BEGIN
        verifier_participant(p_id_conversation, p_id_expediteur);
        IF TRIM(p_contenu) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_conversation_invalide, 'Le message est vide.');
        END IF;
        IF LENGTH(p_contenu) > c_longueur_max THEN
            pkg_erreurs.lever(pkg_erreurs.c_conversation_invalide,
                'Le message dépasse ' || c_longueur_max || ' caractères.');
        END IF;

        INSERT INTO message (id_conversation, id_expediteur, contenu)
        VALUES (p_id_conversation, p_id_expediteur, TRIM(p_contenu))
        RETURNING id INTO p_id;

        UPDATE conversation SET date_dernier_message = SYSDATE WHERE id = p_id_conversation;
    END envoyer_message;

    PROCEDURE marquer_comme_lu(p_id_conversation IN NUMBER, p_id_lecteur IN NUMBER, p_nb OUT NUMBER) IS
    BEGIN
        verifier_participant(p_id_conversation, p_id_lecteur);
        UPDATE message SET lu = 1
         WHERE id_conversation = p_id_conversation
           AND id_expediteur <> p_id_lecteur
           AND lu = 0;
        p_nb := SQL%ROWCOUNT;
    END marquer_comme_lu;

    FUNCTION nb_non_lus(p_id_utilisateur IN NUMBER) RETURN NUMBER IS
        v_nb NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_nb
          FROM message m
          JOIN conversation c ON c.id = m.id_conversation
         WHERE p_id_utilisateur IN (c.id_acheteur, c.id_vendeur)
           AND m.id_expediteur <> p_id_utilisateur
           AND m.lu = 0;
        RETURN v_nb;
    END nb_non_lus;

    FUNCTION messages(p_id_conversation IN NUMBER, p_id_lecteur IN NUMBER, p_apres_id IN NUMBER DEFAULT 0)
        RETURN SYS_REFCURSOR
    IS
        v_curseur SYS_REFCURSOR;
    BEGIN
        verifier_participant(p_id_conversation, p_id_lecteur);
        OPEN v_curseur FOR
            SELECT m.id, m.id_expediteur, u.nom AS expediteur, m.contenu, m.lu, m.date_envoi
              FROM message m
              JOIN utilisateur u ON u.id = m.id_expediteur
             WHERE m.id_conversation = p_id_conversation
               AND m.id > NVL(p_apres_id, 0)
             ORDER BY m.id;
        RETURN v_curseur;
    END messages;

END pkg_messagerie;
/
