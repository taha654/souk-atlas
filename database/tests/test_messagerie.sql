-- Tests de PKG_MESSAGERIE
DECLARE
    c_vendeur   CONSTANT NUMBER := 11;   -- Fatima Zahra, auteure de l'annonce 2
    c_acheteur  CONSTANT NUMBER := 12;
    c_intrus    CONSTANT NUMBER := 13;
    v_conv      NUMBER;
    v_conv2     NUMBER;
    v_msg       NUMBER;
    v_nombre    NUMBER;
    v_non_lus   NUMBER;
    v_curseur   SYS_REFCURSOR;
BEGIN
    pkg_test.debut('PKG_MESSAGERIE');

    pkg_messagerie.ouvrir_conversation(2, c_acheteur, v_conv);
    pkg_test.verifier('ouvrir_conversation : conversation créée', v_conv IS NOT NULL);
    pkg_messagerie.ouvrir_conversation(2, c_acheteur, v_conv2);
    pkg_test.verifier_egal('ouvrir_conversation : la même est réutilisée', v_conv, v_conv2);

    BEGIN
        pkg_messagerie.ouvrir_conversation(2, c_vendeur, v_conv2);
        pkg_test.echec('ouvrir_conversation : se contacter soi-même interdit', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ouvrir_conversation : se contacter soi-même interdit', -20013, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_messagerie.ouvrir_conversation(38, c_acheteur, v_conv2);   -- annonce expirée
        pkg_test.echec('ouvrir_conversation : annonce expirée refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ouvrir_conversation : annonce expirée refusée', -20011, SQLCODE, SQLERRM);
    END;

    -- Une conversation existante reste accessible après la vente
    pkg_annonce.marquer_vendue(1, 10);
    pkg_messagerie.ouvrir_conversation(1, 11, v_conv2);
    pkg_test.verifier('ouvrir_conversation : conversation existante sur annonce vendue', v_conv2 IS NOT NULL);

    -- Messages
    v_non_lus := pkg_messagerie.nb_non_lus(c_vendeur);
    pkg_messagerie.envoyer_message(v_conv, c_acheteur, 'Bonjour, est-il encore disponible ?', v_msg);
    pkg_messagerie.envoyer_message(v_conv, c_acheteur, 'Je peux venir ce soir.', v_msg);
    pkg_test.verifier_egal('nb_non_lus : +2 pour le vendeur', v_non_lus + 2, pkg_messagerie.nb_non_lus(c_vendeur));

    BEGIN
        pkg_messagerie.envoyer_message(v_conv, c_intrus, 'Je m''incruste', v_nombre);
        pkg_test.echec('envoyer_message : non-participant refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('envoyer_message : non-participant refusé', -20012, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_messagerie.envoyer_message(v_conv, c_acheteur, '   ', v_nombre);
        pkg_test.echec('envoyer_message : message vide refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('envoyer_message : message vide refusé', -20013, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_messagerie.envoyer_message(v_conv, c_acheteur, RPAD('a', 2001, 'a'), v_nombre);
        pkg_test.echec('envoyer_message : plus de 2000 caractères refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('envoyer_message : plus de 2000 caractères refusé', -20013, SQLCODE, SQLERRM);
    END;

    v_curseur := pkg_messagerie.messages(v_conv, c_vendeur);
    pkg_test.verifier_egal('messages : 2 messages', 2, pkg_test.nb_lignes(v_curseur));
    v_curseur := pkg_messagerie.messages(v_conv, c_vendeur, v_msg);
    pkg_test.verifier_egal('messages après le dernier id : rien de nouveau (polling)', 0, pkg_test.nb_lignes(v_curseur));
    BEGIN
        v_curseur := pkg_messagerie.messages(v_conv, c_intrus);
        pkg_test.echec('messages : lecture interdite à un non-participant', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('messages : lecture interdite à un non-participant', -20012, SQLCODE, SQLERRM);
    END;

    pkg_messagerie.marquer_comme_lu(v_conv, c_acheteur, v_nombre);
    pkg_test.verifier_egal('marquer_comme_lu : ses propres messages ne comptent pas', 0, v_nombre);
    pkg_messagerie.marquer_comme_lu(v_conv, c_vendeur, v_nombre);
    pkg_test.verifier_egal('marquer_comme_lu : 2 messages marqués', 2, v_nombre);
    pkg_test.verifier_egal('nb_non_lus : revenu à la valeur de départ', v_non_lus, pkg_messagerie.nb_non_lus(c_vendeur));

    pkg_test.fin;
END;
/
ROLLBACK;
