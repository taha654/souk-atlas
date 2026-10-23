-- Tests de PKG_UTILISATEUR (et du journal d'audit sur UTILISATEUR)
DECLARE
    v_id      NUMBER;
    v_id2     NUMBER;
    v_texte   VARCHAR2(4000);
    v_nombre  NUMBER;
BEGIN
    pkg_test.debut('PKG_UTILISATEUR');

    -- Création de compte
    pkg_utilisateur.creer_compte('  Nouveau.Client@Exemple.MA ', '$2y$10$hashfictif', 'Nouveau Client',
                                 '0600000099', 'Rabat', 'CLIENT', v_id);
    SELECT email INTO v_texte FROM utilisateur WHERE id = v_id;
    pkg_test.verifier_egal('creer_compte : email nettoyé et en minuscules', 'nouveau.client@exemple.ma', v_texte);
    SELECT role || '/' || statut INTO v_texte FROM utilisateur WHERE id = v_id;
    pkg_test.verifier_egal('creer_compte : rôle CLIENT et statut ACTIF', 'CLIENT/ACTIF', v_texte);

    BEGIN
        pkg_utilisateur.creer_compte('NOUVEAU.CLIENT@exemple.ma', 'h', 'Doublon', NULL, NULL, 'CLIENT', v_id2);
        pkg_test.echec('creer_compte : email en double refusé (casse différente)', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_compte : email en double refusé (casse différente)', -20008, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_utilisateur.creer_compte('pirate@exemple.ma', 'h', 'Pirate', NULL, NULL, 'ADMIN', v_id2);
        pkg_test.echec('creer_compte : rôle ADMIN interdit à l''inscription', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_compte : rôle ADMIN interdit à l''inscription', -20014, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_utilisateur.creer_compte('sansnom@exemple.ma', 'h', '   ', NULL, NULL, 'CLIENT', v_id2);
        pkg_test.echec('creer_compte : nom vide refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_compte : nom vide refusé', -20017, SQLCODE, SQLERRM);
    END;

    -- Changement de rôle + audit avec l'identifiant posé par PHP
    DBMS_SESSION.SET_IDENTIFIER('1');   -- l'admin (id 1) est "connecté"
    pkg_utilisateur.changer_role(v_id, 'VENDEUR');
    SELECT role INTO v_texte FROM utilisateur WHERE id = v_id;
    pkg_test.verifier_egal('changer_role : CLIENT → VENDEUR', 'VENDEUR', v_texte);
    SELECT MAX(auteur) KEEP (DENSE_RANK LAST ORDER BY id), MAX(nouvelle_valeur) KEEP (DENSE_RANK LAST ORDER BY id)
      INTO v_texte, v_nombre
      FROM (SELECT id, auteur, CASE WHEN nouvelle_valeur LIKE '%role=VENDEUR%' THEN 1 ELSE 0 END AS nouvelle_valeur
              FROM journal_audit WHERE nom_table = 'UTILISATEUR' AND id_ligne = v_id AND operation = 'UPDATE');
    pkg_test.verifier_egal('audit : auteur = client identifier de la session', '1', v_texte);
    pkg_test.verifier_egal('audit : nouvelle valeur contient le rôle', 1, v_nombre);
    SELECT COUNT(*) INTO v_nombre FROM journal_audit
     WHERE nom_table = 'UTILISATEUR' AND (ancienne_valeur LIKE '%$2y$%' OR nouvelle_valeur LIKE '%$2y$%');
    pkg_test.verifier_egal('audit : aucun hash de mot de passe dans le journal', 0, v_nombre);
    DBMS_SESSION.CLEAR_IDENTIFIER;

    BEGIN
        pkg_utilisateur.changer_role(v_id, 'SUPERADMIN');
        pkg_test.echec('changer_role : rôle inconnu refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('changer_role : rôle inconnu refusé', -20014, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_utilisateur.changer_role(999999, 'CLIENT');
        pkg_test.echec('changer_role : compte inexistant', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('changer_role : compte inexistant', -20009, SQLCODE, SQLERRM);
    END;

    -- Désactivation : les annonces en ligne du compte disparaissent
    SELECT COUNT(*) INTO v_nombre FROM annonce WHERE id_utilisateur = 10 AND statut = 'EN_LIGNE';
    pkg_test.verifier('données : Amine (id 10) a au moins une annonce en ligne', v_nombre > 0);
    pkg_utilisateur.desactiver(10);
    SELECT COUNT(*) INTO v_nombre FROM annonce WHERE id_utilisateur = 10 AND statut = 'EN_LIGNE';
    pkg_test.verifier_egal('desactiver : plus aucune annonce en ligne', 0, v_nombre);
    SELECT statut INTO v_texte FROM utilisateur WHERE id = 10;
    pkg_test.verifier_egal('desactiver : statut DESACTIVE', 'DESACTIVE', v_texte);
    pkg_utilisateur.reactiver(10);
    SELECT statut INTO v_texte FROM utilisateur WHERE id = 10;
    pkg_test.verifier_egal('reactiver : statut ACTIF', 'ACTIF', v_texte);

    -- Tentatives de connexion
    pkg_utilisateur.enregistrer_tentative('Amine.Lahlou@exemple.ma', '10.0.0.1', 0);
    pkg_utilisateur.enregistrer_tentative('amine.lahlou@exemple.ma', '10.0.0.1', 0);
    pkg_utilisateur.enregistrer_tentative('amine.lahlou@exemple.ma', '10.0.0.1', 1);
    pkg_utilisateur.enregistrer_tentative('amine.lahlou@exemple.ma', '10.0.0.1', 0);
    pkg_test.verifier_egal('nb_echecs_recents : 3 échecs (la réussite ne compte pas)', 3,
                           pkg_utilisateur.nb_echecs_recents('AMINE.LAHLOU@exemple.ma'));
    UPDATE tentative_connexion SET date_tentative = SYSTIMESTAMP - INTERVAL '1' HOUR
     WHERE email = 'amine.lahlou@exemple.ma';
    pkg_test.verifier_egal('nb_echecs_recents : les vieux échecs sont oubliés', 0,
                           pkg_utilisateur.nb_echecs_recents('amine.lahlou@exemple.ma', 15));

    -- Boutiques
    BEGIN
        pkg_utilisateur.creer_boutique(11, 'Boutique de client', NULL, 'Casablanca', v_id2);
        pkg_test.echec('creer_boutique : refusée à un client', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_boutique : refusée à un client', -20014, SQLCODE, SQLERRM);
    END;

    pkg_utilisateur.creer_boutique(v_id, 'Boutique de test', 'Description', 'Rabat', v_id2);
    SELECT statut INTO v_texte FROM boutique WHERE id = v_id2;
    pkg_test.verifier_egal('creer_boutique : créée EN_ATTENTE', 'EN_ATTENTE', v_texte);

    BEGIN
        pkg_utilisateur.creer_boutique(v_id, 'Deuxième boutique', NULL, 'Rabat', v_id2);
        pkg_test.echec('creer_boutique : une seule boutique par vendeur', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_boutique : une seule boutique par vendeur', -20017, SQLCODE, SQLERRM);
    END;

    SELECT id INTO v_id2 FROM boutique WHERE id_vendeur = v_id;
    pkg_utilisateur.changer_statut_boutique(v_id2, 'VALIDEE');
    SELECT statut INTO v_texte FROM boutique WHERE id = v_id2;
    pkg_test.verifier_egal('changer_statut_boutique : VALIDEE', 'VALIDEE', v_texte);

    BEGIN
        pkg_utilisateur.changer_statut_boutique(999999, 'VALIDEE');
        pkg_test.echec('changer_statut_boutique : boutique inexistante', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('changer_statut_boutique : boutique inexistante', -20018, SQLCODE, SQLERRM);
    END;

    pkg_test.fin;
END;
/
ROLLBACK;
