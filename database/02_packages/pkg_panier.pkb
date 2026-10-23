CREATE OR REPLACE PACKAGE BODY pkg_panier AS

    -- Renvoie l'id du panier de l'utilisateur, en le créant au besoin
    FUNCTION id_panier(p_id_utilisateur IN NUMBER) RETURN NUMBER IS
        v_id panier.id%TYPE;
    BEGIN
        SELECT id INTO v_id FROM panier WHERE id_utilisateur = p_id_utilisateur;
        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO panier (id_utilisateur) VALUES (p_id_utilisateur)
            RETURNING id INTO v_id;
            RETURN v_id;
    END id_panier;

    PROCEDURE toucher(p_id_panier IN NUMBER) IS
    BEGIN
        -- date_maj sert à repérer les paniers abandonnés
        UPDATE panier SET date_maj = SYSDATE WHERE id = p_id_panier;
    END toucher;

    -- Contrôles communs à ajouter et modifier_quantite
    PROCEDURE verifier_disponibilite(p_id_produit IN NUMBER, p_quantite_totale IN NUMBER) IS
        v_stock            produit.stock%TYPE;
        v_statut           produit.statut%TYPE;
        v_nom              produit.nom%TYPE;
        v_statut_boutique  boutique.statut%TYPE;
    BEGIN
        IF p_quantite_totale IS NULL OR p_quantite_totale <= 0
           OR p_quantite_totale <> TRUNC(p_quantite_totale) THEN
            pkg_erreurs.lever(pkg_erreurs.c_quantite_invalide, 'La quantité doit être un entier positif.');
        END IF;

        BEGIN
            SELECT p.stock, p.statut, p.nom, b.statut
              INTO v_stock, v_statut, v_nom, v_statut_boutique
              FROM produit p JOIN boutique b ON b.id = p.id_boutique
             WHERE p.id = p_id_produit;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_erreurs.lever(pkg_erreurs.c_produit_indisponible, 'Produit introuvable.');
        END;

        -- Un produit d'une boutique non validée (ou suspendue) n'est pas en vente
        IF v_statut <> 'ACTIF' OR v_statut_boutique <> 'VALIDEE' THEN
            pkg_erreurs.lever(pkg_erreurs.c_produit_indisponible, v_nom || ' n''est plus en vente.');
        END IF;
        -- Pas de verrou ici : le stock sera vérifié à nouveau, verrouillé, à la commande
        IF p_quantite_totale > v_stock THEN
            pkg_erreurs.lever(pkg_erreurs.c_stock_insuffisant,
                'Stock insuffisant pour ' || v_nom || ' : ' || v_stock || ' disponible(s).');
        END IF;
    END verifier_disponibilite;

    -- Un vendeur n'achète pas dans sa propre boutique : il gonflerait ses ventes
    -- et pourrait ensuite laisser des avis sur ses propres produits
    PROCEDURE verifier_pas_son_produit(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER) IS
        v_nb PLS_INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_nb
          FROM produit p JOIN boutique b ON b.id = p.id_boutique
         WHERE p.id = p_id_produit AND b.id_vendeur = p_id_utilisateur;
        IF v_nb > 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_non_proprietaire,
                'Vous ne pouvez pas acheter les produits de votre propre boutique.');
        END IF;
    END verifier_pas_son_produit;

    PROCEDURE ajouter(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER, p_quantite IN NUMBER DEFAULT 1) IS
        v_id_panier  NUMBER;
        v_deja       NUMBER;
    BEGIN
        verifier_pas_son_produit(p_id_utilisateur, p_id_produit);
        v_id_panier := id_panier(p_id_utilisateur);
        IF p_quantite IS NULL OR p_quantite <= 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_quantite_invalide, 'La quantité doit être un entier positif.');
        END IF;

        SELECT NVL(MAX(quantite), 0) INTO v_deja
          FROM panier_ligne WHERE id_panier = v_id_panier AND id_produit = p_id_produit;
        verifier_disponibilite(p_id_produit, v_deja + p_quantite);

        -- MERGE : met à jour la ligne si elle existe, l'insère sinon (un seul ordre SQL)
        MERGE INTO panier_ligne pl
        USING (SELECT v_id_panier AS id_panier, p_id_produit AS id_produit FROM dual) src
           ON (pl.id_panier = src.id_panier AND pl.id_produit = src.id_produit)
         WHEN MATCHED THEN
            UPDATE SET pl.quantite = pl.quantite + p_quantite
         WHEN NOT MATCHED THEN
            INSERT (id_panier, id_produit, quantite) VALUES (src.id_panier, src.id_produit, p_quantite);

        toucher(v_id_panier);
    END ajouter;

    PROCEDURE modifier_quantite(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER, p_quantite IN NUMBER) IS
        v_id_panier NUMBER := id_panier(p_id_utilisateur);
    BEGIN
        IF p_quantite = 0 THEN
            retirer(p_id_utilisateur, p_id_produit);
            RETURN;
        END IF;
        verifier_disponibilite(p_id_produit, p_quantite);

        UPDATE panier_ligne SET quantite = p_quantite
         WHERE id_panier = v_id_panier AND id_produit = p_id_produit;
        IF SQL%ROWCOUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Ce produit n''est pas dans le panier.');
        END IF;
        toucher(v_id_panier);
    END modifier_quantite;

    PROCEDURE retirer(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER) IS
        v_id_panier NUMBER := id_panier(p_id_utilisateur);
    BEGIN
        DELETE FROM panier_ligne WHERE id_panier = v_id_panier AND id_produit = p_id_produit;
        toucher(v_id_panier);
    END retirer;

    PROCEDURE vider(p_id_utilisateur IN NUMBER) IS
    BEGIN
        DELETE FROM panier_ligne
         WHERE id_panier = (SELECT id FROM panier WHERE id_utilisateur = p_id_utilisateur);
    END vider;

    PROCEDURE calculer_totaux(
        p_id_utilisateur IN  NUMBER,
        p_total_ht       OUT NUMBER,
        p_tva            OUT NUMBER,
        p_total_ttc      OUT NUMBER,
        p_nb_articles    OUT NUMBER)
    IS
    BEGIN
        -- TVA arrondie PAR BOUTIQUE puis additionnée, exactement comme
        -- PKG_COMMANDE.passer_commande (une commande par boutique) : le total
        -- affiché dans le panier est au centime près celui qui sera facturé.
        -- (Arrondir une seule fois sur le total global peut donner 1 centime d'écart.)
        SELECT NVL(SUM(ht_boutique), 0), NVL(SUM(ROUND(ht_boutique * c_taux_tva, 2)), 0), NVL(SUM(articles), 0)
          INTO p_total_ht, p_tva, p_nb_articles
          FROM (SELECT p.id_boutique,
                       SUM(pkg_catalogue.prix_courant(pl.id_produit) * pl.quantite) AS ht_boutique,
                       SUM(pl.quantite) AS articles
                  FROM panier_ligne pl
                  JOIN panier pa ON pa.id = pl.id_panier
                  JOIN produit p ON p.id = pl.id_produit
                 WHERE pa.id_utilisateur = p_id_utilisateur
                 GROUP BY p.id_boutique);

        p_total_ttc := p_total_ht + p_tva;
    END calculer_totaux;

    FUNCTION nb_articles(p_id_utilisateur IN NUMBER) RETURN NUMBER IS
        v_nb NUMBER;
    BEGIN
        SELECT NVL(SUM(pl.quantite), 0) INTO v_nb
          FROM panier_ligne pl JOIN panier pa ON pa.id = pl.id_panier
         WHERE pa.id_utilisateur = p_id_utilisateur;
        RETURN v_nb;
    END nb_articles;

    FUNCTION lignes(p_id_utilisateur IN NUMBER) RETURN SYS_REFCURSOR IS
        v_curseur SYS_REFCURSOR;
    BEGIN
        OPEN v_curseur FOR
            SELECT p.id AS id_produit, p.nom, p.id_boutique, b.nom AS boutique, pl.quantite, p.stock,
                   pkg_catalogue.prix_courant(p.id) AS prix_unitaire_ht,
                   pkg_catalogue.prix_courant_ttc(p.id) AS prix_unitaire_ttc,
                   pkg_catalogue.prix_courant(p.id) * pl.quantite AS total_ligne_ht,
                   CASE WHEN p.statut = 'ACTIF' AND b.statut = 'VALIDEE' AND p.stock >= pl.quantite
                        THEN 1 ELSE 0 END AS disponible
              FROM panier_ligne pl
              JOIN panier pa   ON pa.id = pl.id_panier
              JOIN produit p   ON p.id = pl.id_produit
              JOIN boutique b  ON b.id = p.id_boutique
             WHERE pa.id_utilisateur = p_id_utilisateur
             ORDER BY pl.date_ajout, p.id;
        RETURN v_curseur;
    END lignes;

    PROCEDURE purger_paniers_abandonnes(p_jours IN NUMBER DEFAULT 30, p_nb OUT NUMBER) IS
    BEGIN
        -- Les lignes partent avec leur panier (ON DELETE CASCADE)
        DELETE FROM panier WHERE date_maj < SYSDATE - p_jours;
        p_nb := SQL%ROWCOUNT;
    END purger_paniers_abandonnes;

END pkg_panier;
/
