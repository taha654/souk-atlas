-- Tests de l'étape 8, côté Oracle : stockage des recommandations calculées par
-- le moteur C++ (FORALL), lecture des données envoyées au moteur, scores de risque
DECLARE
    c_auteur   CONSTANT NUMBER := 21;   -- Ghita, cliente
    v_produits pkg_catalogue.t_nombres;
    v_recos    pkg_catalogue.t_nombres;
    v_scores   pkg_catalogue.t_nombres;
    v_communs  pkg_catalogue.t_nombres;
    v_vide     pkg_catalogue.t_nombres;
    v_nb       NUMBER;
    v_nombre   NUMBER;
    v_texte    VARCHAR2(4000);
    v_id       NUMBER;
    v_curseur  SYS_REFCURSOR;
    v_ref      commande.reference_achat%TYPE;
    v_id_cmd   NUMBER;
BEGIN
    pkg_test.debut('Recommandations et scores de risque');

    -- ----- Données envoyées au moteur -----
    v_curseur := pkg_catalogue.paniers_achetes;
    v_nombre := pkg_test.nb_lignes(v_curseur);
    pkg_test.verifier('paniers_achetes : historique des achats lu', v_nombre > 300, v_nombre || ' ligne(s)');
    SELECT COUNT(*) INTO v_nb
      FROM (SELECT DISTINCT c.reference_achat, l.id_produit
              FROM commande c JOIN commande_ligne l ON l.id_commande = c.id
             WHERE c.statut <> 'ANNULEE');
    pkg_test.verifier_egal('paniers_achetes : commandes annulées exclues, doublons fusionnés', v_nb, v_nombre);

    -- ----- Remplacement des recommandations (indices non consécutifs : INDICES OF) -----
    v_produits(0) := 1;  v_recos(0) := 7;  v_scores(0) := 0.9;     v_communs(0) := 12;
    v_produits(1) := 1;  v_recos(1) := 10; v_scores(1) := 0.51234; v_communs(1) := 8;
    v_produits(5) := 7;  v_recos(5) := 1;  v_scores(5) := 0.9;     v_communs(5) := 12;
    pkg_catalogue.remplacer_recommandations(v_produits, v_recos, v_scores, v_communs, v_nb);
    pkg_test.verifier_egal('remplacer_recommandations : 3 lignes insérées', 3, v_nb);
    SELECT COUNT(*) INTO v_nombre FROM recommandation;
    pkg_test.verifier_egal('remplacer_recommandations : les anciennes sont supprimées', 3, v_nombre);
    SELECT score INTO v_nombre FROM recommandation WHERE id_produit = 1 AND id_produit_recommande = 10;
    pkg_test.verifier_egal('remplacer_recommandations : score arrondi à 4 décimales', 0.5123, v_nombre);
    pkg_test.verifier('age_recommandations : calcul tout juste fait', pkg_catalogue.age_recommandations < 0.1);

    v_curseur := pkg_catalogue.recommandations(1, 4);
    pkg_test.verifier_egal('recommandations : meilleur score en premier', 7,
                           TO_NUMBER(pkg_test.valeur(v_curseur, 'ID', 1)));
    v_curseur := pkg_catalogue.recommandations(1, 1);
    pkg_test.verifier_egal('recommandations : limite respectée', 1, pkg_test.nb_lignes(v_curseur));

    -- Un produit épuisé ou retiré n'est pas recommandé
    UPDATE produit SET stock = 0 WHERE id = 7;
    v_curseur := pkg_catalogue.recommandations(1, 4);
    pkg_test.verifier_egal('recommandations : produit épuisé masqué', 10,
                           TO_NUMBER(pkg_test.valeur(v_curseur, 'ID', 1)));
    UPDATE produit SET statut = 'INACTIF' WHERE id = 10;
    v_curseur := pkg_catalogue.recommandations(1, 4);
    pkg_test.verifier_egal('recommandations : produit inactif masqué', 0, pkg_test.nb_lignes(v_curseur));

    -- Erreurs
    v_scores(1) := 1.5;
    BEGIN
        pkg_catalogue.remplacer_recommandations(v_produits, v_recos, v_scores, v_communs, v_nb);
        pkg_test.echec('remplacer_recommandations : score > 1 refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('remplacer_recommandations : score > 1 refusé', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_catalogue.remplacer_recommandations(v_produits, v_recos, v_vide, v_communs, v_nb);
        pkg_test.echec('remplacer_recommandations : tableaux de tailles différentes', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('remplacer_recommandations : tableaux de tailles différentes', -20017, SQLCODE, SQLERRM);
    END;
    SELECT COUNT(*) INTO v_nombre FROM recommandation;
    pkg_test.verifier_egal('remplacer_recommandations : rien d''effacé après une erreur', 3, v_nombre);

    -- Tableaux vides : la table est vidée (aucun achat commun)
    pkg_catalogue.remplacer_recommandations(v_vide, v_vide, v_vide, v_vide, v_nb);
    pkg_test.verifier_egal('remplacer_recommandations : tableaux vides acceptés', 0, v_nb);
    pkg_test.verifier('age_recommandations : NULL sans calcul', pkg_catalogue.age_recommandations IS NULL);

    -- ----- Score de risque d'une commande -----
    SELECT MAX(reference_achat) KEEP (DENSE_RANK LAST ORDER BY id) INTO v_ref FROM commande;
    v_curseur := pkg_commande.contexte_risque(v_ref);
    v_nombre := pkg_test.nb_lignes(v_curseur);
    pkg_test.verifier('contexte_risque (commande) : une ligne par commande de l''achat', v_nombre >= 1);
    v_curseur := pkg_commande.contexte_risque(v_ref);
    v_id_cmd := TO_NUMBER(pkg_test.valeur(v_curseur, 'ID', 1));
    v_curseur := pkg_commande.contexte_risque(v_ref);
    pkg_test.verifier('contexte_risque (commande) : quantité maximale lue',
                      TO_NUMBER(pkg_test.valeur(v_curseur, 'QUANTITE_MAX', 1)) >= 1);
    v_curseur := pkg_commande.contexte_risque('INCONNUE');
    pkg_test.verifier_egal('contexte_risque (commande) : référence inconnue → aucune ligne', 0,
                           pkg_test.nb_lignes(v_curseur));

    pkg_commande.definir_score(v_id_cmd, 72.4);
    SELECT score_risque INTO v_nombre FROM commande WHERE id = v_id_cmd;
    pkg_test.verifier_egal('definir_score : score enregistré (arrondi)', 72, v_nombre);
    BEGIN
        pkg_commande.definir_score(v_id_cmd, 101);
        pkg_test.echec('definir_score : score > 100 refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('definir_score : score > 100 refusé', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_commande.definir_score(-1, 10);
        pkg_test.echec('definir_score : commande inconnue', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('definir_score : commande inconnue', -20018, SQLCODE, SQLERRM);
    END;

    -- ----- Score de risque d'une annonce -----
    -- Catégorie 2 (Téléphonie) : la médiane couvre aussi ses sous-catégories (CONNECT BY)
    v_curseur := pkg_annonce.contexte_risque(c_auteur, 2);
    pkg_test.verifier('contexte_risque (annonce) : médiane des sous-catégories',
                      TO_NUMBER(pkg_test.valeur(v_curseur, 'NB_ANNONCES', 1)) >= 3);
    SELECT MEDIAN(prix) INTO v_nombre FROM annonce
     WHERE id_categorie = 3 AND statut IN ('EN_LIGNE', 'VENDUE', 'EXPIREE');
    v_curseur := pkg_annonce.contexte_risque(c_auteur, 3);
    pkg_test.verifier_egal('contexte_risque (annonce) : MEDIAN des smartphones', v_nombre,
                           TO_NUMBER(pkg_test.valeur(v_curseur, 'PRIX_MEDIAN', 1)));

    pkg_annonce.publier(c_auteur, 3, 'Smartphone de test', 'Rien à signaler.', 2000, 'Rabat', 10, v_id);
    v_curseur := pkg_annonce.contexte_risque(c_auteur, 3);
    pkg_test.verifier('contexte_risque (annonce) : annonce récente comptée',
                      TO_NUMBER(pkg_test.valeur(v_curseur, 'ANNONCES_24H', 1)) >= 1);

    -- Modification : le nouveau score renvoie l'annonce en modération
    pkg_annonce.modifier(v_id, c_auteur, 3, 'Smartphone de test', 'Rien à signaler.', 2000, 'Rabat', 20);
    SELECT statut || '/' || score_risque INTO v_texte FROM annonce WHERE id = v_id;
    pkg_test.verifier_egal('modifier : score faible, reste EN_LIGNE', 'EN_LIGNE/20', v_texte);
    pkg_annonce.modifier(v_id, c_auteur, 3, 'Smartphone URGENT', 'Paiement par virement.', 200, 'Rabat', 75);
    SELECT statut || '/' || score_risque INTO v_texte FROM annonce WHERE id = v_id;
    pkg_test.verifier_egal('modifier : score élevé, repart EN_MODERATION', 'EN_MODERATION/75', v_texte);
    pkg_annonce.modifier(v_id, c_auteur, 3, 'Smartphone de test', 'Rien à signaler.', 2000, 'Rabat', 5);
    SELECT statut INTO v_texte FROM annonce WHERE id = v_id;
    pkg_test.verifier_egal('modifier : un score redevenu faible ne suffit pas à sortir de modération',
                           'EN_MODERATION', v_texte);
    pkg_annonce.modifier(v_id, c_auteur, 3, 'Smartphone de test', 'Rien à signaler.', 2000, 'Rabat');
    SELECT score_risque INTO v_nombre FROM annonce WHERE id = v_id;
    pkg_test.verifier_egal('modifier : sans score (moteur absent), l''ancien est gardé', 5, v_nombre);

    pkg_test.fin;
END;
/
ROLLBACK;
