-- Tests de PKG_COMMANDE (parcours complet), de PKG_AVIS et du trigger de note moyenne
DECLARE
    v_client  NUMBER;   -- client créé par le test : aucun historique
    c_carte   CONSTANT VARCHAR2(20) := '4111 1111 1111 1111';
    v_annee   NUMBER := EXTRACT(YEAR FROM SYSDATE) + 1;
    v_ref     VARCHAR2(20);
    v_ref2    VARCHAR2(20);
    v_stock1  NUMBER;
    v_stock7  NUMBER;
    v_stock18 NUMBER;
    v_nombre  NUMBER;
    v_texte   VARCHAR2(4000);
    v_cmd_b1  NUMBER;   -- commande de la boutique 1 (Atlas Électronique)
    v_cmd_b7  NUMBER;   -- commande de la boutique 7 (Info Pro Maroc)
    v_cmd_cod NUMBER;   -- commande payée à la livraison
    v_nb_avis NUMBER;
    v_id_avis NUMBER;

    -- Transaction AUTONOME : elle s'exécute à part, comme si un autre client
    -- essayait au même moment de verrouiller le produit. NOWAIT échoue
    -- immédiatement (ORA-00054) si la ligne est déjà verrouillée.
    FUNCTION ligne_verrouillee(p_id_produit IN NUMBER) RETURN BOOLEAN IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_id NUMBER;
    BEGIN
        SELECT id INTO v_id FROM produit WHERE id = p_id_produit FOR UPDATE NOWAIT;
        ROLLBACK;
        RETURN FALSE;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE = -54 THEN
                RETURN TRUE;
            END IF;
            RAISE;
    END ligne_verrouillee;
BEGIN
    pkg_test.debut('PKG_COMMANDE');
    UPDATE promotion SET actif = 0;
    pkg_utilisateur.creer_compte('client.test@exemple.ma', 'h', 'Client Test', '0600000099', 'Fès', 'CLIENT', v_client);
    pkg_panier.vider(v_client);

    -- ----- Panier vide -----
    BEGIN
        pkg_commande.passer_commande(v_client, 'CARTE', '1 rue Test', 'Fès', '0600000099',
                                     c_carte, 12, v_annee, '123', v_ref);
        pkg_test.echec('passer_commande : panier vide refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : panier vide refusé', -20003, SQLCODE, SQLERRM);
    END;

    -- ----- Commande par carte sur deux boutiques -----
    SELECT stock INTO v_stock1  FROM produit WHERE id = 1;
    SELECT stock INTO v_stock7  FROM produit WHERE id = 7;
    SELECT stock INTO v_stock18 FROM produit WHERE id = 18;
    pkg_panier.ajouter(v_client, 1, 2);    -- Galaxy A55, 3290 DH, boutique 1
    pkg_panier.ajouter(v_client, 7, 3);    -- coque, 79 DH, boutique 1
    pkg_panier.ajouter(v_client, 18, 1);   -- souris, 129 DH, boutique 7

    pkg_commande.passer_commande(v_client, 'CARTE', '1 rue Test', 'Fès', '0600000099',
                                 c_carte, 12, v_annee, '123', v_ref);
    pkg_test.verifier('passer_commande : référence ACH-AAAA-NNNNNN', REGEXP_LIKE(v_ref, '^ACH-[0-9]{4}-[0-9]{6}$'), v_ref);

    SELECT COUNT(*) INTO v_nombre FROM commande WHERE reference_achat = v_ref;
    pkg_test.verifier_egal('passer_commande : une commande par boutique', 2, v_nombre);
    SELECT id INTO v_cmd_b1 FROM commande WHERE reference_achat = v_ref AND id_boutique = 1;
    SELECT id INTO v_cmd_b7 FROM commande WHERE reference_achat = v_ref AND id_boutique = 7;

    SELECT total_ht || ' / ' || tva || ' / ' || total_ttc INTO v_texte FROM commande WHERE id = v_cmd_b1;
    pkg_test.verifier_egal('totaux boutique 1 : 2x3290 + 3x79 = 6817 HT, TVA 1363,4', '6817 / 1363.4 / 8180.4', v_texte);
    SELECT total_ht || ' / ' || tva || ' / ' || total_ttc INTO v_texte FROM commande WHERE id = v_cmd_b7;
    pkg_test.verifier_egal('totaux boutique 7 : 129 HT, TVA 25,8', '129 / 25.8 / 154.8', v_texte);

    SELECT COUNT(*) INTO v_nombre FROM commande WHERE reference_achat = v_ref AND statut = 'PAYEE';
    pkg_test.verifier_egal('carte : les deux commandes sont PAYEE', 2, v_nombre);
    SELECT COUNT(*) INTO v_nombre FROM paiement
     WHERE id_commande IN (v_cmd_b1, v_cmd_b7) AND statut = 'ACCEPTE' AND carte_4_derniers = '1111';
    pkg_test.verifier_egal('paiement : ACCEPTE, seuls les 4 derniers chiffres gardés', 2, v_nombre);

    SELECT stock INTO v_nombre FROM produit WHERE id = 1;
    pkg_test.verifier_egal('stock : Galaxy A55 diminué de 2', v_stock1 - 2, v_nombre);
    SELECT stock INTO v_nombre FROM produit WHERE id = 7;
    pkg_test.verifier_egal('stock : coque diminuée de 3', v_stock7 - 3, v_nombre);
    SELECT stock INTO v_nombre FROM produit WHERE id = 18;
    pkg_test.verifier_egal('stock : souris diminuée de 1', v_stock18 - 1, v_nombre);

    SELECT prix_unitaire_ht INTO v_nombre FROM commande_ligne WHERE id_commande = v_cmd_b1 AND id_produit = 1;
    pkg_test.verifier_egal('ligne : prix unitaire copié dans la commande', 3290, v_nombre);
    pkg_test.verifier_egal('panier vidé après la commande', 0, pkg_panier.nb_articles(v_client));

    pkg_test.verifier('verrou : le produit reste verrouillé jusqu''au COMMIT/ROLLBACK', ligne_verrouillee(1));
    pkg_test.verifier('verrou : un produit non commandé n''est pas verrouillé', NOT ligne_verrouillee(2));

    SELECT COUNT(*) INTO v_nombre FROM journal_audit WHERE nom_table = 'COMMANDE' AND id_ligne = v_cmd_b1;
    pkg_test.verifier('audit : création et paiement de la commande journalisés', v_nombre >= 2, v_nombre || ' ligne(s)');

    -- ----- Stock insuffisant : refus propre, rien n'est créé -----
    pkg_panier.ajouter(v_client, 24, 3);            -- clé USB, stock 3
    UPDATE produit SET stock = 1 WHERE id = 24;     -- un autre client en a acheté entre-temps
    SELECT COUNT(*) INTO v_nombre FROM commande WHERE id_client = v_client;
    BEGIN
        pkg_commande.passer_commande(v_client, 'CARTE', '1 rue Test', 'Fès', '0600000099',
                                     c_carte, 12, v_annee, '123', v_ref2);
        pkg_test.echec('passer_commande : stock insuffisant refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : stock insuffisant refusé', -20001, SQLCODE, SQLERRM);
    END;
    SELECT COUNT(*) - v_nombre INTO v_nombre FROM commande WHERE id_client = v_client;
    pkg_test.verifier_egal('stock insuffisant : aucune commande créée', 0, v_nombre);
    pkg_test.verifier_egal('stock insuffisant : le panier est conservé', 3, pkg_panier.nb_articles(v_client));
    SELECT stock INTO v_nombre FROM produit WHERE id = 24;
    pkg_test.verifier_egal('stock insuffisant : le stock n''a pas bougé', 1, v_nombre);

    -- ----- Autres refus -----
    UPDATE produit SET stock = 3, statut = 'INACTIF' WHERE id = 24;
    BEGIN
        pkg_commande.passer_commande(v_client, 'CARTE', '1 rue Test', 'Fès', '0600000099',
                                     c_carte, 12, v_annee, '123', v_ref2);
        pkg_test.echec('passer_commande : produit retiré de la vente refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : produit retiré de la vente refusé', -20004, SQLCODE, SQLERRM);
    END;
    UPDATE produit SET statut = 'ACTIF' WHERE id = 24;

    BEGIN
        pkg_commande.passer_commande(v_client, 'CARTE', '1 rue Test', 'Fès', '0600000099',
                                     '4111111111111112', 12, v_annee, '123', v_ref2);
        pkg_test.echec('passer_commande : carte invalide refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : carte invalide refusée', -20006, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_commande.passer_commande(v_client, 'CARTE', '1 rue Test', 'Fès', '0600000099',
                                     c_carte, 1, 2020, '123', v_ref2);
        pkg_test.echec('passer_commande : carte expirée refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : carte expirée refusée', -20007, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_commande.passer_commande(v_client, 'CHEQUE', '1 rue Test', 'Fès', '0600000099',
                                     NULL, NULL, NULL, NULL, v_ref2);
        pkg_test.echec('passer_commande : mode de paiement inconnu refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : mode de paiement inconnu refusé', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_commande.passer_commande(v_client, 'LIVRAISON', '  ', 'Fès', '0600000099',
                                     NULL, NULL, NULL, NULL, v_ref2);
        pkg_test.echec('passer_commande : adresse vide refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : adresse vide refusée', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_commande.passer_commande(25, 'LIVRAISON', '1 rue Test', 'Oujda', '0600000025',
                                     NULL, NULL, NULL, NULL, v_ref2);
        pkg_test.echec('passer_commande : compte désactivé refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : compte désactivé refusé', -20009, SQLCODE, SQLERRM);
    END;

    -- Produit de sa propre boutique glissé dans le panier (ex. avant de devenir vendeur)
    INSERT INTO panier_ligne (id_panier, id_produit, quantite)
    SELECT id, 1, 1 FROM panier WHERE id_utilisateur = 2;
    IF SQL%ROWCOUNT = 0 THEN
        INSERT INTO panier (id_utilisateur) VALUES (2);
        INSERT INTO panier_ligne (id_panier, id_produit, quantite)
        SELECT id, 1, 1 FROM panier WHERE id_utilisateur = 2;
    END IF;
    BEGIN
        pkg_commande.passer_commande(2, 'LIVRAISON', '1 rue Test', 'Casablanca', '0600000002',
                                     NULL, NULL, NULL, NULL, v_ref2);
        pkg_test.echec('passer_commande : achat dans sa propre boutique refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('passer_commande : achat dans sa propre boutique refusé', -20012, SQLCODE, SQLERRM);
    END;

    -- ----- Paiement à la livraison et cycle de vie -----
    pkg_panier.modifier_quantite(v_client, 24, 1);
    pkg_commande.passer_commande(v_client, 'LIVRAISON', '1 rue Test', 'Fès', '0600000099',
                                 NULL, NULL, NULL, NULL, v_ref2);
    SELECT id INTO v_cmd_cod FROM commande WHERE reference_achat = v_ref2;
    SELECT c.statut || '/' || p.statut INTO v_texte
      FROM commande c JOIN paiement p ON p.id_commande = c.id WHERE c.id = v_cmd_cod;
    pkg_test.verifier_egal('livraison : commande et paiement EN_ATTENTE', 'EN_ATTENTE/EN_ATTENTE', v_texte);

    BEGIN
        pkg_commande.changer_statut(v_cmd_cod, 'PAYEE');
        pkg_test.echec('transition : EN_ATTENTE → PAYEE interdite à la livraison', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('transition : EN_ATTENTE → PAYEE interdite à la livraison', -20002, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_commande.changer_statut(v_cmd_cod, 'LIVREE');
        pkg_test.echec('transition : EN_ATTENTE → LIVREE interdite (étape sautée)', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('transition : EN_ATTENTE → LIVREE interdite (étape sautée)', -20002, SQLCODE, SQLERRM);
    END;

    pkg_commande.changer_statut(v_cmd_cod, 'EXPEDIEE');
    pkg_commande.changer_statut(v_cmd_cod, 'LIVREE');
    SELECT c.statut || '/' || p.statut || '/' || NVL2(c.date_expedition, 'E', '-') || NVL2(c.date_livraison, 'L', '-')
      INTO v_texte
      FROM commande c JOIN paiement p ON p.id_commande = c.id WHERE c.id = v_cmd_cod;
    pkg_test.verifier_egal('livraison : LIVREE, paiement ACCEPTE, dates remplies', 'LIVREE/ACCEPTE/EL', v_texte);

    BEGIN
        pkg_commande.changer_statut(v_cmd_cod, 'ANNULEE');
        pkg_test.echec('annulation : impossible une fois livrée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('annulation : impossible une fois livrée', -20016, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_commande.changer_statut(999999, 'EXPEDIEE');
        pkg_test.echec('changer_statut : commande inexistante', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('changer_statut : commande inexistante', -20018, SQLCODE, SQLERRM);
    END;

    -- ----- Annulation d'une commande payée : stock rendu, remboursement -----
    SELECT stock INTO v_stock18 FROM produit WHERE id = 18;
    pkg_commande.annuler(v_cmd_b7);
    SELECT stock INTO v_nombre FROM produit WHERE id = 18;
    pkg_test.verifier_egal('annuler : la souris revient en stock', v_stock18 + 1, v_nombre);
    SELECT c.statut || '/' || p.statut INTO v_texte
      FROM commande c JOIN paiement p ON p.id_commande = c.id WHERE c.id = v_cmd_b7;
    pkg_test.verifier_egal('annuler : commande ANNULEE, paiement REMBOURSE', 'ANNULEE/REMBOURSE', v_texte);
    BEGIN
        pkg_commande.annuler(v_cmd_b7);
        pkg_test.echec('annuler : deux fois impossible', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('annuler : deux fois impossible', -20016, SQLCODE, SQLERRM);
    END;

    pkg_test.verifier_egal('transition_autorisee : PAYEE → EXPEDIEE', 1,
                           pkg_commande.transition_autorisee('PAYEE', 'EXPEDIEE', 'CARTE'));
    pkg_test.verifier_egal('transition_autorisee : EXPEDIEE → PAYEE', 0,
                           pkg_commande.transition_autorisee('EXPEDIEE', 'PAYEE', 'CARTE'));
    pkg_test.verifier_egal('transition_autorisee : EN_ATTENTE → EXPEDIEE par carte', 0,
                           pkg_commande.transition_autorisee('EN_ATTENTE', 'EXPEDIEE', 'CARTE'));
    pkg_test.fin;

    -- -------------------------------------------------------------------------
    pkg_test.debut('PKG_AVIS et note moyenne');

    SELECT nb_avis INTO v_nb_avis FROM produit WHERE id = 24;
    pkg_test.verifier_egal('peut_donner_avis : oui après la livraison', 1, pkg_avis.peut_donner_avis(v_client, 24));
    pkg_avis.deposer(v_client, 24, 4, 'Bonne clé, rapide.', v_id_avis);
    SELECT nb_avis INTO v_nombre FROM produit WHERE id = 24;
    pkg_test.verifier_egal('trigger composé : nb_avis + 1', v_nb_avis + 1, v_nombre);
    SELECT ROUND(AVG(note), 2) INTO v_nombre FROM avis WHERE id_produit = 24 AND statut = 'PUBLIE';
    SELECT note_moyenne INTO v_stock1 FROM produit WHERE id = 24;
    pkg_test.verifier_egal('trigger composé : note moyenne recalculée', v_nombre, v_stock1);
    pkg_test.verifier_egal('peut_donner_avis : non après un premier avis', 0, pkg_avis.peut_donner_avis(v_client, 24));

    BEGIN
        pkg_avis.deposer(v_client, 24, 5, 'Encore', v_nombre);
        pkg_test.echec('deposer : un seul avis par produit', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('deposer : un seul avis par produit', -20010, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_avis.deposer(v_client, 1, 5, 'Pas encore reçu', v_nombre);
        pkg_test.echec('deposer : refusé avant la livraison', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('deposer : refusé avant la livraison', -20010, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_avis.deposer(v_client, 24, 6, 'Trop bien', v_nombre);
        pkg_test.echec('deposer : note 6 refusée', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('deposer : note 6 refusée', -20017, SQLCODE, SQLERRM);
    END;

    pkg_avis.changer_statut(v_id_avis, 'MASQUE');
    SELECT nb_avis INTO v_nombre FROM produit WHERE id = 24;
    pkg_test.verifier_egal('trigger composé : un avis masqué ne compte plus', v_nb_avis, v_nombre);

    pkg_test.fin;
END;
/
ROLLBACK;
