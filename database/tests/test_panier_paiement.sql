-- Tests de PKG_PANIER et PKG_PAIEMENT
DECLARE
    -- Client sans panier dans les données de démo
    c_client CONSTANT NUMBER := 12;
    v_ht      NUMBER;
    v_tva     NUMBER;
    v_ttc     NUMBER;
    v_nb      NUMBER;
    v_curseur SYS_REFCURSOR;
BEGIN
    pkg_test.debut('PKG_PANIER');
    UPDATE promotion SET actif = 0;   -- prix sans promotion, résultats stables

    pkg_panier.vider(c_client);
    pkg_test.verifier_egal('panier vide au départ', 0, pkg_panier.nb_articles(c_client));

    pkg_panier.ajouter(c_client, 24, 2);          -- clé USB 69 DH, stock 3
    pkg_panier.ajouter(c_client, 24, 1);
    pkg_test.verifier_egal('ajouter deux fois : les quantités se cumulent', 3, pkg_panier.nb_articles(c_client));

    BEGIN
        pkg_panier.ajouter(c_client, 24, 1);
        pkg_test.echec('ajouter : au-delà du stock refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ajouter : au-delà du stock refusé', -20001, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_panier.ajouter(c_client, 1, 0);
        pkg_test.echec('ajouter : quantité 0 refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ajouter : quantité 0 refusée', -20005, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_panier.ajouter(c_client, 43, 1);
        pkg_test.echec('ajouter : produit INACTIF refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ajouter : produit INACTIF refusé', -20004, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_panier.ajouter(c_client, 59, 1);
        pkg_test.echec('ajouter : boutique non validée refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ajouter : boutique non validée refusée', -20004, SQLCODE, SQLERRM);
    END;

    pkg_panier.ajouter(c_client, 44, 2);          -- huile d'argan 120 DH
    pkg_panier.calculer_totaux(c_client, v_ht, v_tva, v_ttc, v_nb);
    pkg_test.verifier_egal('calculer_totaux : HT = 3 x 69 + 2 x 120 = 447', 447, v_ht);
    pkg_test.verifier_egal('calculer_totaux : TVA 20 % = 89,40', 89.4, v_tva);
    pkg_test.verifier_egal('calculer_totaux : TTC = 536,40', 536.4, v_ttc);
    pkg_test.verifier_egal('calculer_totaux : 5 articles', 5, v_nb);

    v_curseur := pkg_panier.lignes(c_client);
    pkg_test.verifier_egal('lignes : 2 lignes', 2, pkg_test.nb_lignes(v_curseur));

    pkg_panier.modifier_quantite(c_client, 44, 1);
    pkg_test.verifier_egal('modifier_quantite : 3 + 1 = 4 articles', 4, pkg_panier.nb_articles(c_client));
    pkg_panier.modifier_quantite(c_client, 44, 0);
    pkg_test.verifier_egal('modifier_quantite 0 : la ligne est retirée', 3, pkg_panier.nb_articles(c_client));
    BEGIN
        pkg_panier.modifier_quantite(c_client, 1, 2);
        pkg_test.echec('modifier_quantite : produit absent du panier', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('modifier_quantite : produit absent du panier', -20018, SQLCODE, SQLERRM);
    END;

    pkg_panier.retirer(c_client, 24);
    pkg_test.verifier_egal('retirer : panier vide', 0, pkg_panier.nb_articles(c_client));

    -- Purge : un panier ancien part, un panier récent reste
    pkg_panier.ajouter(13, 44, 1);
    UPDATE panier SET date_maj = SYSDATE - 40 WHERE id_utilisateur = 13;
    pkg_panier.ajouter(14, 44, 1);
    pkg_panier.purger_paniers_abandonnes(30, v_nb);
    pkg_test.verifier('purger_paniers_abandonnes : au moins un panier supprimé', v_nb >= 1);
    SELECT COUNT(*) INTO v_nb FROM panier WHERE id_utilisateur = 13;
    pkg_test.verifier_egal('purger_paniers_abandonnes : le panier de 40 jours est supprimé', 0, v_nb);
    SELECT COUNT(*) INTO v_nb FROM panier WHERE id_utilisateur = 14;
    pkg_test.verifier_egal('purger_paniers_abandonnes : le panier récent reste', 1, v_nb);

    pkg_test.fin;

    -- -------------------------------------------------------------------------
    pkg_test.debut('PKG_PAIEMENT');

    -- Numéros de test publics (Visa, Mastercard, American Express)
    pkg_test.verifier_egal('luhn : Visa de test valide', 1, pkg_paiement.luhn_valide('4111111111111111'));
    pkg_test.verifier_egal('luhn : Mastercard de test valide', 1, pkg_paiement.luhn_valide('5555555555554444'));
    pkg_test.verifier_egal('luhn : Amex (15 chiffres) valide', 1, pkg_paiement.luhn_valide('378282246310005'));
    pkg_test.verifier_egal('luhn : espaces et tirets acceptés', 1, pkg_paiement.luhn_valide('4111 1111-1111 1111'));
    pkg_test.verifier_egal('luhn : dernier chiffre faux', 0, pkg_paiement.luhn_valide('4111111111111112'));
    pkg_test.verifier_egal('luhn : trop court', 0, pkg_paiement.luhn_valide('1234'));
    pkg_test.verifier_egal('luhn : lettres refusées', 0, pkg_paiement.luhn_valide('4111abcd11111111'));
    pkg_test.verifier_egal('luhn : NULL refusé', 0, pkg_paiement.luhn_valide(NULL));

    pkg_test.verifier_egal('carte_expiree : mois en cours encore valable', 0,
        pkg_paiement.carte_expiree(EXTRACT(MONTH FROM SYSDATE), EXTRACT(YEAR FROM SYSDATE)));
    pkg_test.verifier_egal('carte_expiree : mois dernier expiré', 1,
        pkg_paiement.carte_expiree(EXTRACT(MONTH FROM ADD_MONTHS(SYSDATE, -1)), EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -1))));
    pkg_test.verifier_egal('carte_expiree : année prochaine valable', 0,
        pkg_paiement.carte_expiree(1, EXTRACT(YEAR FROM SYSDATE) + 1));
    pkg_test.verifier_egal('carte_expiree : mois 13 refusé', 1, pkg_paiement.carte_expiree(13, 2030));
    pkg_test.verifier_egal('carte_expiree : mois NULL refusé', 1, pkg_paiement.carte_expiree(NULL, 2030));

    BEGIN
        pkg_paiement.verifier_carte('4111111111111112', 12, EXTRACT(YEAR FROM SYSDATE) + 1, '123');
        pkg_test.echec('verifier_carte : numéro faux', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('verifier_carte : numéro faux', -20006, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_paiement.verifier_carte('4111111111111111', 12, EXTRACT(YEAR FROM SYSDATE) + 1, '12');
        pkg_test.echec('verifier_carte : CVV à 2 chiffres', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('verifier_carte : CVV à 2 chiffres', -20006, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_paiement.verifier_carte('4111111111111111', 1, 2020, '123');
        pkg_test.echec('verifier_carte : carte expirée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('verifier_carte : carte expirée', -20007, SQLCODE, SQLERRM);
    END;

    pkg_test.fin;
END;
/
ROLLBACK;
