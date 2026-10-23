-- Tests de PKG_CATALOGUE et des triggers sur PRODUIT
DECLARE
    v_curseur  SYS_REFCURSOR;
    v_id       NUMBER;
    v_nombre   NUMBER;
    v_attendu  NUMBER;
    v_texte    VARCHAR2(4000);
BEGIN
    pkg_test.debut('PKG_CATALOGUE');

    -- Les promotions de démonstration dépendent de la date d'installation :
    -- on les neutralise pour que les tests donnent toujours le même résultat
    UPDATE promotion SET actif = 0;

    -- ----- Arbre des catégories -----
    v_curseur := pkg_catalogue.arbre_categories;
    pkg_test.verifier_egal('arbre_categories : toutes les catégories', 34, pkg_test.nb_lignes(v_curseur));
    v_curseur := pkg_catalogue.arbre_categories;
    pkg_test.verifier_egal('arbre_categories : la 1re ligne est une racine (niveau 1)', '1',
                           pkg_test.valeur(v_curseur, 'niveau'));
    SELECT COUNT(*) INTO v_nombre FROM categorie WHERE id_parent IS NULL;
    pkg_test.verifier_egal('données : 8 catégories racines', 8, v_nombre);
    pkg_test.verifier_egal('chemin_categorie : fil d''Ariane des smartphones',
                           'Électronique > Téléphones & tablettes > Smartphones', pkg_catalogue.chemin_categorie(3));

    -- ----- Prix et promotions -----
    pkg_test.verifier_egal('prix_courant : sans promotion = prix HT', 3290, pkg_catalogue.prix_courant(1));

    pkg_catalogue.creer_promotion('Test catégorie', 10, SYSDATE - 1, SYSDATE + 1, NULL, 1, v_id);
    pkg_test.verifier_egal('pourcentage_promo : hérité de la catégorie racine Électronique', 10,
                           pkg_catalogue.pourcentage_promo(1));
    pkg_catalogue.creer_promotion('Test produit', 15, SYSDATE - 1, SYSDATE + 1, 1, NULL, v_id);
    pkg_test.verifier_egal('pourcentage_promo : la meilleure promotion l''emporte', 15,
                           pkg_catalogue.pourcentage_promo(1));
    pkg_test.verifier_egal('prix_courant : 3290 - 15 % = 2796,5', 2796.5, pkg_catalogue.prix_courant(1));
    pkg_test.verifier_egal('pourcentage_promo : pas de promo hors de la catégorie', 0,
                           pkg_catalogue.pourcentage_promo(44));
    pkg_catalogue.creer_promotion('Test future', 20, SYSDATE + 5, SYSDATE + 9, NULL, 19, v_id);
    pkg_test.verifier_egal('pourcentage_promo : promo pas encore commencée ignorée', 0,
                           pkg_catalogue.pourcentage_promo(44));

    BEGIN
        pkg_catalogue.creer_promotion('Trop forte', 95, SYSDATE, SYSDATE + 1, 1, NULL, v_id);
        pkg_test.echec('creer_promotion : pourcentage > 90 refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_promotion : pourcentage > 90 refusé', -20015, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_catalogue.creer_promotion('Deux cibles', 10, SYSDATE, SYSDATE + 1, 1, 1, v_id);
        pkg_test.echec('creer_promotion : deux cibles refusées', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_promotion : deux cibles refusées', -20015, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_catalogue.creer_promotion('Dates inversées', 10, SYSDATE + 2, SYSDATE + 1, 1, NULL, v_id);
        pkg_test.echec('creer_promotion : fin avant début refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_promotion : fin avant début refusée', -20015, SQLCODE, SQLERRM);
    END;

    INSERT INTO promotion (libelle, pourcentage, date_debut, date_fin, id_produit, actif)
    VALUES ('Test terminée', 10, SYSDATE - 10, SYSDATE - 1, 2, 1);
    pkg_catalogue.desactiver_promotions_terminees(v_nombre);
    pkg_test.verifier('desactiver_promotions_terminees : au moins une désactivée', v_nombre >= 1);
    SELECT COUNT(*) INTO v_nombre FROM promotion WHERE actif = 1 AND date_fin < SYSDATE;
    pkg_test.verifier_egal('desactiver_promotions_terminees : plus aucune terminée active', 0, v_nombre);
    UPDATE promotion SET actif = 0;   -- retour à un catalogue sans promotion

    -- ----- Recherche -----
    v_curseur := pkg_catalogue.rechercher(p_texte => 'samsung');
    pkg_test.verifier_egal('rechercher "samsung" : 3 produits', 3, pkg_test.nb_lignes(v_curseur));
    v_curseur := pkg_catalogue.rechercher(p_texte => 'SAMSUNG');
    pkg_test.verifier_egal('rechercher : insensible à la casse', '3', pkg_test.valeur(v_curseur, 'total'));

    -- Catégorie "Téléphones & tablettes" (2) : ses sous-catégories 3, 4 et 5 sont incluses
    SELECT COUNT(*) INTO v_attendu FROM produit WHERE id_categorie IN (3, 4, 5) AND statut = 'ACTIF';
    v_curseur := pkg_catalogue.rechercher(p_id_categorie => 2, p_taille_page => 100);
    pkg_test.verifier_egal('rechercher par catégorie : sous-catégories incluses', v_attendu, pkg_test.nb_lignes(v_curseur));

    v_curseur := pkg_catalogue.rechercher(p_texte => 'thuya');
    pkg_test.verifier_egal('rechercher : produits d''une boutique non validée invisibles', 0, pkg_test.nb_lignes(v_curseur));
    v_curseur := pkg_catalogue.rechercher(p_texte => 'jabador');
    pkg_test.verifier_egal('rechercher : produit INACTIF invisible', 0, pkg_test.nb_lignes(v_curseur));

    SELECT MIN(p.prix_ht) INTO v_attendu FROM produit p JOIN boutique b ON b.id = p.id_boutique
     WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE';
    v_curseur := pkg_catalogue.rechercher(p_tri => 'prix_asc');
    pkg_test.verifier_egal('rechercher tri prix_asc : le moins cher en premier', TO_CHAR(v_attendu),
                           pkg_test.valeur(v_curseur, 'prix_courant_ht'));
    SELECT MAX(p.prix_ht) INTO v_attendu FROM produit p JOIN boutique b ON b.id = p.id_boutique
     WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE';
    v_curseur := pkg_catalogue.rechercher(p_tri => 'prix_desc');
    pkg_test.verifier_egal('rechercher tri prix_desc : le plus cher en premier', TO_CHAR(v_attendu),
                           pkg_test.valeur(v_curseur, 'prix_courant_ht'));

    v_curseur := pkg_catalogue.rechercher(p_prix_min => 1000, p_prix_max => 2000, p_taille_page => 100);
    SELECT COUNT(*) INTO v_attendu FROM produit p JOIN boutique b ON b.id = p.id_boutique
     WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE' AND p.prix_ht BETWEEN 1000 AND 2000;
    pkg_test.verifier_egal('rechercher : filtre prix entre 1000 et 2000', v_attendu, pkg_test.nb_lignes(v_curseur));

    v_curseur := pkg_catalogue.rechercher(p_page => 2, p_taille_page => 5);
    pkg_test.verifier_egal('rechercher : page 2 de 5 résultats', 5, pkg_test.nb_lignes(v_curseur));
    SELECT COUNT(*) INTO v_attendu FROM produit p JOIN boutique b ON b.id = p.id_boutique
     WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE';
    v_curseur := pkg_catalogue.rechercher(p_page => 2, p_taille_page => 5);
    pkg_test.verifier_egal('rechercher : total = tous les résultats, pas la page', TO_CHAR(v_attendu),
                           pkg_test.valeur(v_curseur, 'total'));
    v_curseur := pkg_catalogue.rechercher(p_taille_page => 100000);
    pkg_test.verifier_egal('rechercher : taille de page plafonnée à 100', LEAST(v_attendu, 100),
                           pkg_test.nb_lignes(v_curseur));

    v_curseur := pkg_catalogue.suggestions('smart');
    pkg_test.verifier_egal('suggestions "smart" : 4 smartphones', 4, pkg_test.nb_lignes(v_curseur));
    v_curseur := pkg_catalogue.suggestions('galaxy');
    pkg_test.verifier('suggestions : trouve aussi un mot au milieu du nom',
                      pkg_test.nb_lignes(v_curseur) >= 2);

    -- ----- Gestion des produits -----
    BEGIN
        pkg_catalogue.creer_produit(1, 3, 'Produit gratuit', NULL, 0, 5, v_id);
        pkg_test.echec('creer_produit : prix nul refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('creer_produit : prix nul refusé', -20017, SQLCODE, SQLERRM);
    END;

    pkg_catalogue.creer_produit(1, 3, 'Smartphone de test', 'Description', 1000, 5, v_id);
    pkg_test.verifier('creer_produit : produit créé', v_id IS NOT NULL);

    BEGIN
        pkg_catalogue.modifier_produit(v_id, 2, 3, 'Volé', NULL, 1, 'ACTIF');
        pkg_test.echec('modifier_produit : interdit à une autre boutique', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('modifier_produit : interdit à une autre boutique', -20012, SQLCODE, SQLERRM);
    END;

    pkg_catalogue.modifier_produit(v_id, 1, 3, 'Smartphone de test', 'Description', 900, 'ACTIF');
    SELECT COUNT(*) INTO v_nombre FROM historique_prix
     WHERE id_produit = v_id AND ancien_prix_ht = 1000 AND nouveau_prix_ht = 900;
    pkg_test.verifier_egal('trigger historique : changement de prix archivé', 1, v_nombre);
    pkg_catalogue.modifier_produit(v_id, 1, 3, 'Nouveau nom', 'Description', 900, 'ACTIF');
    SELECT COUNT(*) INTO v_nombre FROM historique_prix WHERE id_produit = v_id;
    pkg_test.verifier_egal('trigger historique : rien si le prix ne change pas', 1, v_nombre);

    pkg_catalogue.ajuster_stock(v_id, 1, -5);
    SELECT stock INTO v_nombre FROM produit WHERE id = v_id;
    pkg_test.verifier_egal('ajuster_stock : 5 - 5 = 0', 0, v_nombre);
    BEGIN
        pkg_catalogue.ajuster_stock(v_id, 1, -1);
        pkg_test.echec('ajuster_stock : stock négatif refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ajuster_stock : stock négatif refusé', -20001, SQLCODE, SQLERRM);
    END;
    BEGIN
        UPDATE produit SET stock = -3 WHERE id = v_id;
        pkg_test.echec('trigger : UPDATE direct à un stock négatif refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('trigger : UPDATE direct à un stock négatif refusé', -20001, SQLCODE, SQLERRM);
    END;

    SELECT COUNT(*) INTO v_nombre FROM journal_audit WHERE nom_table = 'PRODUIT' AND id_ligne = v_id;
    pkg_test.verifier('audit : créations et modifications du produit journalisées', v_nombre >= 4,
                      v_nombre || ' ligne(s)');

    pkg_test.fin;
END;
/
ROLLBACK;
