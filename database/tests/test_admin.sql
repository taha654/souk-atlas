-- Tests des procédures de l'espace admin (étape 7)
DECLARE
    v_id      NUMBER;
    v_id2     NUMBER;
    v_texte   VARCHAR2(4000);
    v_nombre  NUMBER;
    v_sig     NUMBER;
BEGIN
    pkg_test.debut('ESPACE ADMIN');

    -- ----- Catégories -----
    pkg_catalogue.creer_categorie('Instruments de musique', 22, v_id);
    SELECT pkg_catalogue.chemin_categorie(v_id) INTO v_texte FROM dual;
    pkg_test.verifier_egal('creer_categorie : sous-catégorie de Sport & loisirs', 'Sport & loisirs > Instruments de musique', v_texte);
    BEGIN
        pkg_catalogue.creer_categorie('Instruments de musique', 22, v_id2);
        pkg_test.echec('creer_categorie : doublon au même niveau refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_categorie : doublon au même niveau refusé', -20017, SQLCODE, SQLERRM);
    END;
    pkg_catalogue.creer_categorie('Guitares', v_id, v_id2);
    pkg_catalogue.renommer_categorie(v_id, 'Musique');
    SELECT nom INTO v_texte FROM categorie WHERE id = v_id;
    pkg_test.verifier_egal('renommer_categorie', 'Musique', v_texte);
    BEGIN
        pkg_catalogue.supprimer_categorie(v_id);
        pkg_test.echec('supprimer_categorie : refusée avec une sous-catégorie', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('supprimer_categorie : refusée avec une sous-catégorie', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_catalogue.supprimer_categorie(3);   -- Smartphones : des produits
        pkg_test.echec('supprimer_categorie : refusée avec des produits', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier('supprimer_categorie : refusée avec des produits (message précis)',
                          SQLCODE = -20017 AND SQLERRM LIKE '%produit(s)%', SQLERRM);
    END;
    pkg_catalogue.supprimer_categorie(v_id2);
    pkg_catalogue.supprimer_categorie(v_id);
    SELECT COUNT(*) INTO v_nombre FROM categorie WHERE id IN (v_id, v_id2);
    pkg_test.verifier_egal('supprimer_categorie : feuille puis parent vide', 0, v_nombre);

    -- ----- Promotions -----
    pkg_catalogue.creer_promotion('Test admin', 25, SYSDATE - 1, SYSDATE + 5, 44, NULL, v_id);
    pkg_test.verifier_egal('promotion active appliquée', 25, pkg_catalogue.pourcentage_promo(44));
    pkg_catalogue.desactiver_promotion(v_id);
    pkg_test.verifier_egal('desactiver_promotion : plus appliquée', 0, pkg_catalogue.pourcentage_promo(44));

    -- ----- Signalement traité de bout en bout -----
    pkg_moderation.signaler(10, 'ANNONCE', 2, 'ARNAQUE', 'Test', v_sig);
    pkg_moderation.traiter(v_sig, 1, 'APPROUVER');
    SELECT a.statut || '/' || s.statut INTO v_texte FROM annonce a JOIN signalement s ON s.id_annonce = a.id WHERE s.id = v_sig;
    pkg_test.verifier_egal('signalement approuvé : annonce retirée, signalement clos', 'REFUSEE/APPROUVE', v_texte);

    pkg_test.fin;
END;
/
ROLLBACK;
