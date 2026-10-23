CREATE OR REPLACE PACKAGE BODY pkg_commande AS

    -- Une ligne du panier, enrichie de ce qu'il faut pour commander
    TYPE t_ligne IS RECORD (
        id_produit       produit.id%TYPE,
        nom              produit.nom%TYPE,
        quantite         panier_ligne.quantite%TYPE,
        stock            produit.stock%TYPE,
        statut           produit.statut%TYPE,
        statut_boutique  boutique.statut%TYPE,
        id_boutique      produit.id_boutique%TYPE,
        prix_unitaire    produit.prix_ht%TYPE);

    -- Collection de lignes, remplie d'un coup par BULK COLLECT
    TYPE t_lignes IS TABLE OF t_ligne;

    -- Tableau associatif id_boutique → id_commande : il "regroupe" les lignes
    -- par boutique sans requête supplémentaire
    TYPE t_commande_par_boutique IS TABLE OF commande.id%TYPE INDEX BY PLS_INTEGER;

    -- Curseur explicite. FOR UPDATE OF p.stock verrouille UNIQUEMENT les lignes
    -- de PRODUIT concernées, dès l'OPEN : deux clients qui achètent le même
    -- produit au même moment passent l'un après l'autre, et le second voit le
    -- stock déjà décrémenté par le premier.
    CURSOR c_panier(p_id_client NUMBER) IS
        SELECT p.id, p.nom, pl.quantite, p.stock, p.statut, b.statut, p.id_boutique, NULL
          FROM panier_ligne pl
          JOIN panier pa  ON pa.id = pl.id_panier
          JOIN produit p  ON p.id = pl.id_produit
          JOIN boutique b ON b.id = p.id_boutique
         WHERE pa.id_utilisateur = p_id_client
         ORDER BY p.id
           FOR UPDATE OF p.stock;

    -- -------------------------------------------------------------------------
    PROCEDURE verifier_client_et_adresse(
        p_id_client IN NUMBER, p_mode_paiement IN VARCHAR2,
        p_adresse IN VARCHAR2, p_ville IN VARCHAR2, p_telephone IN VARCHAR2)
    IS
        v_statut utilisateur.statut%TYPE;
    BEGIN
        BEGIN
            SELECT statut INTO v_statut FROM utilisateur WHERE id = p_id_client;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_statut := NULL;
        END;
        IF v_statut IS NULL OR v_statut <> 'ACTIF' THEN
            pkg_erreurs.lever(pkg_erreurs.c_compte_introuvable, 'Compte client introuvable ou désactivé.');
        END IF;
        IF p_mode_paiement IS NULL OR p_mode_paiement NOT IN ('CARTE', 'LIVRAISON') THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Mode de paiement invalide.');
        END IF;
        IF TRIM(p_adresse) IS NULL OR TRIM(p_ville) IS NULL OR TRIM(p_telephone) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide,
                'L''adresse, la ville et le téléphone de livraison sont obligatoires.');
        END IF;
    END verifier_client_et_adresse;

    -- -------------------------------------------------------------------------
    PROCEDURE passer_commande(
        p_id_client      IN  NUMBER,
        p_mode_paiement  IN  VARCHAR2,
        p_adresse        IN  VARCHAR2,
        p_ville          IN  VARCHAR2,
        p_telephone      IN  VARCHAR2,
        p_numero_carte   IN  VARCHAR2 DEFAULT NULL,
        p_mois_exp       IN  NUMBER   DEFAULT NULL,
        p_annee_exp      IN  NUMBER   DEFAULT NULL,
        p_cvv            IN  VARCHAR2 DEFAULT NULL,
        p_reference      OUT VARCHAR2)
    IS
        v_lignes     t_lignes;
        v_commandes  t_commande_par_boutique;
        v_id_boutique PLS_INTEGER;
        v_total_ht   NUMBER;
        v_tva        NUMBER;
    BEGIN
        -- 1. Contrôles qui ne demandent aucun verrou
        verifier_client_et_adresse(p_id_client, p_mode_paiement, p_adresse, p_ville, p_telephone);
        IF p_mode_paiement = 'CARTE' THEN
            pkg_paiement.verifier_carte(p_numero_carte, p_mois_exp, p_annee_exp, p_cvv);
        END IF;

        -- 2. Lecture ET verrouillage des produits du panier
        OPEN c_panier(p_id_client);
        FETCH c_panier BULK COLLECT INTO v_lignes;
        CLOSE c_panier;

        IF v_lignes.COUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_panier_vide, 'Votre panier est vide.');
        END IF;

        -- 3. Disponibilité : maintenant que les lignes sont verrouillées, le
        --    stock lu ne peut plus changer jusqu'à la fin de la transaction
        FOR i IN 1 .. v_lignes.COUNT LOOP
            IF v_lignes(i).statut <> 'ACTIF' OR v_lignes(i).statut_boutique <> 'VALIDEE' THEN
                pkg_erreurs.lever(pkg_erreurs.c_produit_indisponible,
                    v_lignes(i).nom || ' n''est plus en vente.');
            END IF;
            IF v_lignes(i).quantite > v_lignes(i).stock THEN
                pkg_erreurs.lever(pkg_erreurs.c_stock_insuffisant,
                    'Stock insuffisant pour ' || v_lignes(i).nom || ' : ' || v_lignes(i).stock
                    || ' disponible(s), ' || v_lignes(i).quantite || ' demandé(s).');
            END IF;
        END LOOP;

        -- 4. Création des commandes (une par boutique) et de leurs lignes
        p_reference := 'ACH-' || TO_CHAR(SYSDATE, 'YYYY') || '-'
                       || LPAD(seq_reference_achat.NEXTVAL, 6, '0');

        FOR i IN 1 .. v_lignes.COUNT LOOP
            -- Le prix est celui de la BASE au moment de la commande, promo comprise
            v_lignes(i).prix_unitaire := pkg_catalogue.prix_courant(v_lignes(i).id_produit);
            v_id_boutique := v_lignes(i).id_boutique;

            IF NOT v_commandes.EXISTS(v_id_boutique) THEN
                INSERT INTO commande (numero, reference_achat, id_client, id_boutique, mode_paiement,
                                      adresse_livraison, ville_livraison, telephone_livraison)
                VALUES ('CMD-' || TO_CHAR(SYSDATE, 'YYYY') || '-' || LPAD(seq_numero_commande.NEXTVAL, 6, '0'),
                        p_reference, p_id_client, v_id_boutique, p_mode_paiement,
                        TRIM(p_adresse), TRIM(p_ville), TRIM(p_telephone))
                RETURNING id INTO v_commandes(v_id_boutique);
            END IF;

            INSERT INTO commande_ligne (id_commande, id_produit, nom_produit,
                                        prix_unitaire_ht, quantite, total_ligne_ht)
            VALUES (v_commandes(v_id_boutique), v_lignes(i).id_produit, v_lignes(i).nom,
                    v_lignes(i).prix_unitaire, v_lignes(i).quantite,
                    v_lignes(i).prix_unitaire * v_lignes(i).quantite);
        END LOOP;

        -- 5. Décrément du stock : FORALL envoie tous les UPDATE en un seul
        --    aller-retour entre PL/SQL et le moteur SQL (plus rapide qu'une boucle)
        FORALL i IN 1 .. v_lignes.COUNT
            UPDATE produit SET stock = stock - v_lignes(i).quantite
             WHERE id = v_lignes(i).id_produit;

        -- 6. Totaux et paiement de chaque commande. On parcourt le tableau
        --    associatif avec FIRST / NEXT : ses indices (id de boutique) ne se suivent pas.
        v_id_boutique := v_commandes.FIRST;
        WHILE v_id_boutique IS NOT NULL LOOP
            SELECT SUM(total_ligne_ht) INTO v_total_ht
              FROM commande_ligne WHERE id_commande = v_commandes(v_id_boutique);
            v_tva := ROUND(v_total_ht * pkg_panier.c_taux_tva, 2);

            UPDATE commande
               SET total_ht = v_total_ht, tva = v_tva, total_ttc = v_total_ht + v_tva
             WHERE id = v_commandes(v_id_boutique);

            IF p_mode_paiement = 'CARTE' THEN
                pkg_paiement.enregistrer_carte(v_commandes(v_id_boutique), p_numero_carte, v_total_ht + v_tva);
                UPDATE commande SET statut = 'PAYEE', date_paiement = SYSDATE
                 WHERE id = v_commandes(v_id_boutique);
            ELSE
                pkg_paiement.enregistrer_livraison(v_commandes(v_id_boutique), v_total_ht + v_tva);
            END IF;

            v_id_boutique := v_commandes.NEXT(v_id_boutique);
        END LOOP;

        -- 7. Le panier est vidé dans la même transaction : si quoi que ce soit
        --    échoue plus haut, PHP fait ROLLBACK et le panier reste intact
        pkg_panier.vider(p_id_client);
    EXCEPTION
        WHEN OTHERS THEN
            -- Un curseur resté ouvert après une erreur gaspillerait des ressources
            IF c_panier%ISOPEN THEN
                CLOSE c_panier;
            END IF;
            RAISE;
    END passer_commande;

    -- -------------------------------------------------------------------------
    FUNCTION transition_autorisee(
        p_ancien IN VARCHAR2, p_nouveau IN VARCHAR2, p_mode_paiement IN VARCHAR2) RETURN NUMBER IS
    BEGIN
        RETURN CASE
            WHEN p_ancien = 'EN_ATTENTE' AND p_nouveau = 'PAYEE'    AND p_mode_paiement = 'CARTE'     THEN 1
            WHEN p_ancien = 'EN_ATTENTE' AND p_nouveau = 'EXPEDIEE' AND p_mode_paiement = 'LIVRAISON' THEN 1
            WHEN p_ancien = 'PAYEE'      AND p_nouveau = 'EXPEDIEE'                                   THEN 1
            WHEN p_ancien = 'EXPEDIEE'   AND p_nouveau = 'LIVREE'                                     THEN 1
            WHEN p_ancien IN ('EN_ATTENTE', 'PAYEE') AND p_nouveau = 'ANNULEE'                        THEN 1
            ELSE 0
        END;
    END transition_autorisee;

    -- Lit et verrouille la commande ; -20018 si elle n'existe pas
    PROCEDURE verrouiller(p_id_commande IN NUMBER, p_statut OUT VARCHAR2, p_mode OUT VARCHAR2) IS
    BEGIN
        SELECT statut, mode_paiement INTO p_statut, p_mode
          FROM commande WHERE id = p_id_commande
           FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Commande introuvable : ' || p_id_commande);
    END verrouiller;

    -- -------------------------------------------------------------------------
    PROCEDURE changer_statut(p_id_commande IN NUMBER, p_nouveau_statut IN VARCHAR2) IS
        v_statut commande.statut%TYPE;
        v_mode   commande.mode_paiement%TYPE;
    BEGIN
        IF p_nouveau_statut = 'ANNULEE' THEN
            annuler(p_id_commande);
            RETURN;
        END IF;

        verrouiller(p_id_commande, v_statut, v_mode);
        IF transition_autorisee(v_statut, p_nouveau_statut, v_mode) = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_transition_interdite,
                'Passage de ' || v_statut || ' à ' || p_nouveau_statut || ' interdit.');
        END IF;

        UPDATE commande
           SET statut          = p_nouveau_statut,
               date_paiement   = CASE WHEN p_nouveau_statut = 'PAYEE'
                                        OR (p_nouveau_statut = 'LIVREE' AND v_mode = 'LIVRAISON')
                                      THEN SYSDATE ELSE date_paiement END,
               date_expedition = CASE WHEN p_nouveau_statut = 'EXPEDIEE' THEN SYSDATE ELSE date_expedition END,
               date_livraison  = CASE WHEN p_nouveau_statut = 'LIVREE'   THEN SYSDATE ELSE date_livraison END
         WHERE id = p_id_commande;

        IF p_nouveau_statut = 'LIVREE' AND v_mode = 'LIVRAISON' THEN
            pkg_paiement.confirmer_livraison(p_id_commande);
        END IF;
    END changer_statut;

    -- -------------------------------------------------------------------------
    PROCEDURE annuler(p_id_commande IN NUMBER) IS
        v_statut commande.statut%TYPE;
        v_mode   commande.mode_paiement%TYPE;
    BEGIN
        verrouiller(p_id_commande, v_statut, v_mode);
        IF transition_autorisee(v_statut, 'ANNULEE', v_mode) = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_annulation_impossible,
                'Une commande ' || v_statut || ' ne peut plus être annulée.');
        END IF;

        -- Remise en stock : UPDATE corrélé (la sous-requête est évaluée pour
        -- chaque produit de la commande)
        UPDATE produit p
           SET p.stock = p.stock + (SELECT cl.quantite FROM commande_ligne cl
                                     WHERE cl.id_commande = p_id_commande AND cl.id_produit = p.id)
         WHERE p.id IN (SELECT id_produit FROM commande_ligne WHERE id_commande = p_id_commande);

        pkg_paiement.rembourser(p_id_commande);

        UPDATE commande SET statut = 'ANNULEE', date_annulation = SYSDATE WHERE id = p_id_commande;
    END annuler;

END pkg_commande;
/
