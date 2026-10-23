-- Tests des procédures de l'espace vendeur (étape 5)
DECLARE
    c_vendeur   CONSTANT NUMBER := 2;   -- Youssef, boutique 1 (Atlas Électronique)
    c_boutique  CONSTANT NUMBER := 1;
    v_id        NUMBER;
    v_id2       NUMBER;
    v_texte     VARCHAR2(4000);
    v_nombre    NUMBER;
    v_ref       VARCHAR2(20);
    v_commande  NUMBER;
BEGIN
    pkg_test.debut('ESPACE VENDEUR');

    -- ----- Boutique -----
    pkg_utilisateur.modifier_boutique(c_vendeur, 'Atlas Électronique', 'Nouvelle description', 'Casablanca');
    SELECT statut || '/' || description INTO v_texte FROM boutique WHERE id = c_boutique;
    pkg_test.verifier_egal('modifier_boutique : description changée, statut inchangé', 'VALIDEE/Nouvelle description', v_texte);
    pkg_utilisateur.modifier_boutique(c_vendeur, 'Atlas High-Tech', 'Nouvelle description', 'Casablanca');
    SELECT statut INTO v_texte FROM boutique WHERE id = c_boutique;
    pkg_test.verifier_egal('modifier_boutique : nouveau nom → revalidation', 'EN_ATTENTE', v_texte);
    BEGIN
        pkg_utilisateur.modifier_boutique(c_vendeur, 'Maison Zellige', NULL, NULL);
        pkg_test.echec('modifier_boutique : nom d''une autre boutique refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('modifier_boutique : nom d''une autre boutique refusé', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_utilisateur.modifier_boutique(10, 'Boutique fantôme', NULL, NULL);   -- client sans boutique
        pkg_test.echec('modifier_boutique : sans boutique', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('modifier_boutique : sans boutique', -20018, SQLCODE, SQLERRM);
    END;
    UPDATE boutique SET statut = 'VALIDEE' WHERE id = c_boutique;

    -- ----- Photos -----
    pkg_catalogue.ajouter_photo(5, c_boutique, '/uploads/produits/test-a.jpg', v_id);
    SELECT ordre INTO v_nombre FROM produit_photo WHERE id = v_id;
    SELECT COUNT(*) INTO v_id2 FROM produit_photo WHERE id_produit = 5;
    pkg_test.verifier_egal('ajouter_photo : en dernière position', v_id2, v_nombre);
    BEGIN
        pkg_catalogue.ajouter_photo(25, c_boutique, '/uploads/produits/vol.jpg', v_id2);   -- produit de Maison Zellige
        pkg_test.echec('ajouter_photo : produit d''une autre boutique', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ajouter_photo : produit d''une autre boutique', -20012, SQLCODE, SQLERRM);
    END;
    WHILE TRUE LOOP
        SELECT COUNT(*) INTO v_nombre FROM produit_photo WHERE id_produit = 5;
        EXIT WHEN v_nombre >= pkg_catalogue.c_photos_max;
        pkg_catalogue.ajouter_photo(5, c_boutique, '/uploads/produits/remplissage.jpg', v_id2);
    END LOOP;
    BEGIN
        pkg_catalogue.ajouter_photo(5, c_boutique, '/uploads/produits/en-trop.jpg', v_id2);
        pkg_test.echec('ajouter_photo : au-delà de 6 photos', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ajouter_photo : au-delà de 6 photos', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_catalogue.retirer_photo(v_id, 2, v_texte);   -- boutique 2 n'est pas propriétaire
        pkg_test.echec('retirer_photo : photo d''une autre boutique', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('retirer_photo : photo d''une autre boutique', -20012, SQLCODE, SQLERRM);
    END;
    SELECT MIN(id) INTO v_id2 FROM produit_photo WHERE id_produit = 5;
    pkg_catalogue.retirer_photo(v_id2, c_boutique, v_texte);
    pkg_test.verifier('retirer_photo : renvoie le chemin du fichier', v_texte LIKE '/%');
    SELECT LISTAGG(ordre, ',') WITHIN GROUP (ORDER BY ordre) INTO v_texte FROM produit_photo WHERE id_produit = 5;
    pkg_test.verifier_egal('retirer_photo : les photos restantes sont renumérotées', '1,2,3,4,5', v_texte);

    -- ----- Commandes reçues -----
    -- Une commande payée, adressée à la boutique 1
    pkg_panier.vider(12);
    pkg_panier.ajouter(12, 7, 1);
    pkg_commande.passer_commande(12, 'CARTE', '1 rue Test', 'Fès', '0600000012',
                                 '4111111111111111', 12, EXTRACT(YEAR FROM SYSDATE) + 1, '123', v_ref);
    SELECT id INTO v_commande FROM commande WHERE reference_achat = v_ref;
    BEGIN
        pkg_commande.changer_statut_par_vendeur(v_commande, 2, 'EXPEDIEE');   -- boutique 2
        pkg_test.echec('changer_statut_par_vendeur : commande d''une autre boutique', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('changer_statut_par_vendeur : commande d''une autre boutique', -20012, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_commande.changer_statut_par_vendeur(v_commande, c_boutique, 'PAYEE');
        pkg_test.echec('changer_statut_par_vendeur : PAYEE interdit au vendeur', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('changer_statut_par_vendeur : PAYEE interdit au vendeur', -20002, SQLCODE, SQLERRM);
    END;
    pkg_commande.changer_statut_par_vendeur(v_commande, c_boutique, 'EXPEDIEE');
    pkg_commande.changer_statut_par_vendeur(v_commande, c_boutique, 'LIVREE');
    SELECT statut INTO v_texte FROM commande WHERE id = v_commande;
    pkg_test.verifier_egal('changer_statut_par_vendeur : expédiée puis livrée', 'LIVREE', v_texte);

    pkg_test.fin;
END;
/
ROLLBACK;
