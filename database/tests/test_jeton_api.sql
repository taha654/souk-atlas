-- Tests des jetons d'API (outil console C++) et de la recherche de catégorie par nom
DECLARE
    c_admin    CONSTANT NUMBER := 1;
    c_vendeur  CONSTANT NUMBER := 2;    -- Youssef, Atlas Électronique
    c_client   CONSTANT NUMBER := 21;   -- Ghita, cliente
    -- Empreintes fictives (64 caractères hexadécimaux)
    c_e1       CONSTANT VARCHAR2(64) := RPAD('a1', 64, '0');
    c_e2       CONSTANT VARCHAR2(64) := RPAD('b2', 64, '0');
    v_id       NUMBER;
    v_id2      NUMBER;
    v_util     NUMBER;
    v_role     VARCHAR2(10);
    v_nombre   NUMBER;
    v_date     DATE;
BEGIN
    pkg_test.debut('Jetons d''API');

    pkg_utilisateur.creer_jeton(c_vendeur, c_e1, 'Ordinateur du bureau', 30, v_id);
    pkg_test.verifier('creer_jeton : jeton créé pour un vendeur', v_id IS NOT NULL);
    SELECT ROUND(date_expiration - SYSDATE) INTO v_nombre FROM jeton_api WHERE id = v_id;
    pkg_test.verifier_egal('creer_jeton : expire dans 30 jours', 30, v_nombre);

    pkg_utilisateur.utilisateur_du_jeton(c_e1, v_util, v_role);
    pkg_test.verifier_egal('utilisateur_du_jeton : bon compte', c_vendeur, v_util);
    pkg_test.verifier_egal('utilisateur_du_jeton : rôle renvoyé', 'VENDEUR', v_role);
    SELECT date_derniere_utilisation INTO v_date FROM jeton_api WHERE id = v_id;
    pkg_test.verifier('utilisateur_du_jeton : date de dernière utilisation notée', v_date IS NOT NULL);

    BEGIN
        pkg_utilisateur.creer_jeton(c_client, c_e2, 'Client', 30, v_id2);
        pkg_test.echec('creer_jeton : refusé à un client', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_jeton : refusé à un client', -20014, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_utilisateur.creer_jeton(c_admin, c_e2, 'Admin', 400, v_id2);
        pkg_test.echec('creer_jeton : durée > 365 jours refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_jeton : durée > 365 jours refusée', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_utilisateur.creer_jeton(c_admin, 'motdepasse', 'Admin', 30, v_id2);
        pkg_test.echec('creer_jeton : empreinte non SHA-256 refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_jeton : empreinte non SHA-256 refusée', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_utilisateur.utilisateur_du_jeton(c_e2, v_util, v_role);
        pkg_test.echec('utilisateur_du_jeton : jeton inconnu refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('utilisateur_du_jeton : jeton inconnu refusé', -20009, SQLCODE, SQLERRM);
    END;

    -- Révocation : par le propriétaire seulement
    BEGIN
        pkg_utilisateur.revoquer_jeton(v_id, c_admin);
        pkg_test.echec('revoquer_jeton : réservé au propriétaire', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('revoquer_jeton : réservé au propriétaire', -20012, SQLCODE, SQLERRM);
    END;
    pkg_utilisateur.revoquer_jeton(v_id, c_vendeur);
    BEGIN
        pkg_utilisateur.utilisateur_du_jeton(c_e1, v_util, v_role);
        pkg_test.echec('utilisateur_du_jeton : jeton révoqué refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('utilisateur_du_jeton : jeton révoqué refusé', -20009, SQLCODE, SQLERRM);
    END;

    -- Jeton expiré, puis compte désactivé
    pkg_utilisateur.creer_jeton(c_vendeur, c_e2, 'Portable', 1, v_id2);
    UPDATE jeton_api SET date_creation = SYSDATE - 3, date_expiration = SYSDATE - 1 WHERE id = v_id2;
    BEGIN
        pkg_utilisateur.utilisateur_du_jeton(c_e2, v_util, v_role);
        pkg_test.echec('utilisateur_du_jeton : jeton expiré refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('utilisateur_du_jeton : jeton expiré refusé', -20009, SQLCODE, SQLERRM);
    END;
    UPDATE jeton_api SET date_expiration = SYSDATE + 1 WHERE id = v_id2;
    pkg_utilisateur.desactiver(c_vendeur);
    BEGIN
        pkg_utilisateur.utilisateur_du_jeton(c_e2, v_util, v_role);
        pkg_test.echec('utilisateur_du_jeton : compte désactivé refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('utilisateur_du_jeton : compte désactivé refusé', -20009, SQLCODE, SQLERRM);
    END;
    pkg_utilisateur.reactiver(c_vendeur);

    -- Limite de jetons valides par compte (les jetons révoqués ne comptent pas)
    FOR i IN 1 .. 4 LOOP
        pkg_utilisateur.creer_jeton(c_vendeur, RPAD('c' || i, 64, '0'), 'Jeton ' || i, 10, v_id);
    END LOOP;
    BEGIN
        pkg_utilisateur.creer_jeton(c_vendeur, RPAD('d', 64, '0'), 'Jeton de trop', 10, v_id);
        pkg_test.echec('creer_jeton : au plus 5 jetons valides', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_jeton : au plus 5 jetons valides', -20017, SQLCODE, SQLERRM);
    END;

    -- ----- Catégorie par nom (import CSV) -----
    SELECT id INTO v_nombre FROM categorie WHERE nom = 'Électroménager';
    pkg_test.verifier_egal('categorie_par_nom : sans accents ni majuscules', v_nombre,
                           pkg_catalogue.categorie_par_nom('  electromenager '));
    pkg_test.verifier('categorie_par_nom : inconnue → NULL', pkg_catalogue.categorie_par_nom('Hoverboards') IS NULL);

    pkg_test.fin;
END;
/
ROLLBACK;
