CREATE OR REPLACE PACKAGE BODY pkg_catalogue AS

    -- =========================================================================
    -- Prix
    -- =========================================================================
    FUNCTION pourcentage_promo(p_id_produit IN produit.id%TYPE) RETURN NUMBER IS
        v_pourcentage NUMBER;
    BEGIN
        SELECT NVL(MAX(pr.pourcentage), 0)
          INTO v_pourcentage
          FROM promotion pr
         WHERE pr.actif = 1
           AND SYSDATE BETWEEN pr.date_debut AND pr.date_fin
           AND (pr.id_produit = p_id_produit
                -- Remonte l'arbre depuis la catégorie du produit jusqu'à la racine :
                -- une promo sur "Électronique" s'applique aussi aux smartphones
                OR pr.id_categorie IN (
                       SELECT c.id
                         FROM categorie c
                        START WITH c.id = (SELECT id_categorie FROM produit WHERE id = p_id_produit)
                      CONNECT BY c.id = PRIOR c.id_parent));
        RETURN v_pourcentage;
    END pourcentage_promo;

    FUNCTION prix_courant(p_id_produit IN produit.id%TYPE) RETURN NUMBER IS
        v_prix_ht produit.prix_ht%TYPE;
    BEGIN
        SELECT prix_ht INTO v_prix_ht FROM produit WHERE id = p_id_produit;
        RETURN ROUND(v_prix_ht * (1 - pourcentage_promo(p_id_produit) / 100), 2);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Produit introuvable : ' || p_id_produit);
    END prix_courant;

    FUNCTION prix_courant_ttc(p_id_produit IN produit.id%TYPE) RETURN NUMBER IS
    BEGIN
        -- Une constante de package (pkg_panier.c_taux_tva) est utilisable ici,
        -- en PL/SQL, mais pas directement dans un ordre SQL : d'où cette fonction
        RETURN ttc(prix_courant(p_id_produit));
    END prix_courant_ttc;

    FUNCTION ttc(p_montant_ht IN NUMBER) RETURN NUMBER DETERMINISTIC IS
    BEGIN
        RETURN ROUND(p_montant_ht * (1 + pkg_panier.c_taux_tva), 2);
    END ttc;

    FUNCTION normaliser(p_texte IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    BEGIN
        -- TRANSLATE remplace chaque caractère de la 2e chaîne par celui de même
        -- position dans la 3e. Même expression que la colonne PRODUIT.nom_recherche.
        RETURN TRANSLATE(LOWER(p_texte), 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ',
                                         'aaaaaaceeeeiiiinooooouuuuyy');
    END normaliser;

    -- =========================================================================
    -- Catégories
    -- =========================================================================
    FUNCTION arbre_categories RETURN SYS_REFCURSOR IS
        v_curseur SYS_REFCURSOR;
    BEGIN
        -- CONNECT BY descend de la racine (id_parent NULL) vers les feuilles.
        -- LEVEL, SYS_CONNECT_BY_PATH et CONNECT_BY_ISLEAF sont propres aux
        -- requêtes hiérarchiques ; ORDER SIBLINGS BY trie les frères entre eux
        -- sans casser l'ordre parent → enfants.
        OPEN v_curseur FOR
            SELECT id, nom, id_parent,
                   LEVEL AS niveau,
                   LTRIM(SYS_CONNECT_BY_PATH(nom, ' > '), ' > ') AS chemin,
                   CONNECT_BY_ISLEAF AS est_feuille
              FROM categorie
             START WITH id_parent IS NULL
           CONNECT BY PRIOR id = id_parent
             -- NLSSORT … FRENCH : tri alphabétique français (« É » avec les « E »).
             -- Un tri binaire classerait « Électronique » après « Sport » (É = code 201).
             ORDER SIBLINGS BY NLSSORT(nom, 'NLS_SORT=FRENCH');
        RETURN v_curseur;
    END arbre_categories;

    FUNCTION chemin_categorie(p_id_categorie IN categorie.id%TYPE) RETURN VARCHAR2 IS
        v_chemin VARCHAR2(1000);
    BEGIN
        -- On remonte de la catégorie vers la racine, puis LISTAGG recolle les
        -- noms du plus haut (LEVEL le plus grand) au plus bas
        SELECT LISTAGG(nom, ' > ') WITHIN GROUP (ORDER BY LEVEL DESC)
          INTO v_chemin
          FROM categorie
         START WITH id = p_id_categorie
       CONNECT BY id = PRIOR id_parent;
        RETURN v_chemin;
    END chemin_categorie;

    -- =========================================================================
    -- Recherche
    -- =========================================================================
    FUNCTION rechercher(
        p_texte         IN VARCHAR2 DEFAULT NULL,
        p_id_categorie  IN NUMBER   DEFAULT NULL,
        p_prix_min      IN NUMBER   DEFAULT NULL,
        p_prix_max      IN NUMBER   DEFAULT NULL,
        p_tri           IN VARCHAR2 DEFAULT 'pertinence',
        p_page          IN NUMBER   DEFAULT 1,
        p_taille_page   IN NUMBER   DEFAULT 20,
        p_en_stock      IN NUMBER   DEFAULT 0) RETURN SYS_REFCURSOR
    IS
        v_curseur SYS_REFCURSOR;
        v_texte   VARCHAR2(200) := normaliser(TRIM(p_texte));
        -- Bornes de sécurité : PHP ne doit pas pouvoir demander 1 million de lignes
        v_taille  NUMBER := LEAST(GREATEST(NVL(p_taille_page, 20), 1), 100);
        v_page    NUMBER := GREATEST(NVL(p_page, 1), 1);
    BEGIN
        -- Requête statique : les variables PL/SQL deviennent automatiquement des
        -- variables liées, donc aucune injection SQL possible.
        -- Un filtre dont le paramètre est NULL est neutralisé par "IS NULL OR …".
        OPEN v_curseur FOR
            SELECT r.*, COUNT(*) OVER () AS total
              FROM (SELECT p.id, p.nom, p.id_categorie, b.nom AS boutique,
                           p.prix_ht,
                           pkg_catalogue.pourcentage_promo(p.id) AS pourcentage_promo,
                           pkg_catalogue.prix_courant(p.id)      AS prix_courant_ht,
                           pkg_catalogue.prix_courant_ttc(p.id)  AS prix_courant_ttc,
                           pkg_catalogue.ttc(p.prix_ht)          AS prix_ttc,
                           p.stock, p.note_moyenne, p.nb_avis, p.date_creation,
                           (SELECT MIN(ph.chemin) KEEP (DENSE_RANK FIRST ORDER BY ph.ordre)
                              FROM produit_photo ph WHERE ph.id_produit = p.id) AS photo,
                           -- Pertinence : 2 si le nom commence par le texte, 1 sinon
                           CASE WHEN p.nom_recherche LIKE v_texte || '%' THEN 2 ELSE 1 END AS pertinence
                      FROM produit p
                      JOIN boutique b ON b.id = p.id_boutique
                     WHERE p.statut = 'ACTIF'
                       AND b.statut = 'VALIDEE'
                       AND (NVL(p_en_stock, 0) = 0 OR p.stock > 0)
                       AND (v_texte IS NULL
                            OR p.nom_recherche LIKE '%' || v_texte || '%'
                            OR pkg_catalogue.normaliser(p.description) LIKE '%' || v_texte || '%')
                       AND (p_id_categorie IS NULL
                            OR p.id_categorie IN (SELECT c.id FROM categorie c
                                                   START WITH c.id = p_id_categorie
                                                 CONNECT BY PRIOR c.id = c.id_parent))) r
             WHERE (p_prix_min IS NULL OR r.prix_courant_ttc >= p_prix_min)
               AND (p_prix_max IS NULL OR r.prix_courant_ttc <= p_prix_max)
             -- Tri choisi sans SQL dynamique : un seul CASE est "actif" à la fois,
             -- les autres valent NULL pour toutes les lignes et ne trient rien
             ORDER BY CASE WHEN p_tri = 'prix_asc'  THEN r.prix_courant_ht END ASC,
                      CASE WHEN p_tri = 'prix_desc' THEN r.prix_courant_ht END DESC,
                      CASE WHEN p_tri = 'note'      THEN r.note_moyenne END DESC NULLS LAST,
                      CASE WHEN p_tri = 'recent'    THEN r.date_creation END DESC,
                      r.pertinence DESC, r.nb_avis DESC, r.id
            OFFSET (v_page - 1) * v_taille ROWS FETCH NEXT v_taille ROWS ONLY;
        RETURN v_curseur;
    END rechercher;

    FUNCTION suggestions(p_prefixe IN VARCHAR2, p_limite IN NUMBER DEFAULT 8) RETURN SYS_REFCURSOR IS
        v_curseur SYS_REFCURSOR;
        v_prefixe VARCHAR2(100) := normaliser(TRIM(p_prefixe));
    BEGIN
        OPEN v_curseur FOR
            SELECT p.id, p.nom
              FROM produit p
              JOIN boutique b ON b.id = p.id_boutique
             WHERE p.statut = 'ACTIF'
               AND b.statut = 'VALIDEE'
               AND v_prefixe IS NOT NULL
               AND (p.nom_recherche LIKE v_prefixe || '%'           -- début du nom
                    OR p.nom_recherche LIKE '% ' || v_prefixe || '%') -- début d'un autre mot
             ORDER BY CASE WHEN p.nom_recherche LIKE v_prefixe || '%' THEN 0 ELSE 1 END, p.nom
             FETCH FIRST LEAST(NVL(p_limite, 8), 20) ROWS ONLY;
        RETURN v_curseur;
    END suggestions;

    -- =========================================================================
    -- Produits
    -- =========================================================================

    -- Vérifie que le produit existe ET appartient à la boutique
    PROCEDURE verifier_proprietaire(p_id IN produit.id%TYPE, p_id_boutique IN NUMBER) IS
        v_id_boutique produit.id_boutique%TYPE;
    BEGIN
        SELECT id_boutique INTO v_id_boutique FROM produit WHERE id = p_id;
        IF v_id_boutique <> p_id_boutique THEN
            pkg_erreurs.lever(pkg_erreurs.c_non_proprietaire,
                'Ce produit n''appartient pas à votre boutique.');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Produit introuvable : ' || p_id);
    END verifier_proprietaire;

    PROCEDURE verifier_donnees_produit(p_nom IN VARCHAR2, p_prix_ht IN NUMBER) IS
    BEGIN
        IF TRIM(p_nom) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le nom du produit est obligatoire.');
        END IF;
        IF p_prix_ht IS NULL OR p_prix_ht <= 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le prix doit être strictement positif.');
        END IF;
    END verifier_donnees_produit;

    PROCEDURE creer_produit(
        p_id_boutique   IN  produit.id_boutique%TYPE,
        p_id_categorie  IN  produit.id_categorie%TYPE,
        p_nom           IN  produit.nom%TYPE,
        p_description   IN  produit.description%TYPE,
        p_prix_ht       IN  produit.prix_ht%TYPE,
        p_stock         IN  produit.stock%TYPE,
        p_id            OUT produit.id%TYPE)
    IS
    BEGIN
        verifier_donnees_produit(p_nom, p_prix_ht);
        IF p_stock IS NULL OR p_stock < 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_quantite_invalide, 'Le stock initial ne peut pas être négatif.');
        END IF;

        INSERT INTO produit (id_boutique, id_categorie, nom, description, prix_ht, stock)
        VALUES (p_id_boutique, p_id_categorie, TRIM(p_nom), p_description, p_prix_ht, p_stock)
        RETURNING id INTO p_id;
    END creer_produit;

    PROCEDURE modifier_produit(
        p_id            IN produit.id%TYPE,
        p_id_boutique   IN produit.id_boutique%TYPE,
        p_id_categorie  IN produit.id_categorie%TYPE,
        p_nom           IN produit.nom%TYPE,
        p_description   IN produit.description%TYPE,
        p_prix_ht       IN produit.prix_ht%TYPE,
        p_statut        IN produit.statut%TYPE)
    IS
    BEGIN
        verifier_proprietaire(p_id, p_id_boutique);
        verifier_donnees_produit(p_nom, p_prix_ht);
        -- Si le prix change, le trigger TRG_PRODUIT_HISTORIQUE_PRIX l'archive
        UPDATE produit
           SET id_categorie = p_id_categorie,
               nom          = TRIM(p_nom),
               description  = p_description,
               prix_ht      = p_prix_ht,
               statut       = p_statut
         WHERE id = p_id;
    END modifier_produit;

    PROCEDURE ajuster_stock(
        p_id IN produit.id%TYPE, p_id_boutique IN produit.id_boutique%TYPE, p_delta IN NUMBER)
    IS
        v_stock produit.stock%TYPE;
    BEGIN
        verifier_proprietaire(p_id, p_id_boutique);
        -- FOR UPDATE : verrouille la ligne pour que personne ne modifie le stock
        -- entre notre lecture et notre écriture
        SELECT stock INTO v_stock FROM produit WHERE id = p_id FOR UPDATE;
        IF v_stock + p_delta < 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_stock_insuffisant,
                'Stock insuffisant : ' || v_stock || ' en stock, retrait de ' || ABS(p_delta) || ' demandé.');
        END IF;
        UPDATE produit SET stock = stock + p_delta WHERE id = p_id;
    END ajuster_stock;

    -- =========================================================================
    -- Catégories
    -- =========================================================================
    PROCEDURE creer_categorie(p_nom IN VARCHAR2, p_id_parent IN NUMBER, p_id OUT NUMBER) IS
    BEGIN
        IF LENGTH(TRIM(p_nom)) < 2 OR TRIM(p_nom) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le nom de la catégorie doit faire au moins 2 caractères.');
        END IF;
        INSERT INTO categorie (nom, id_parent) VALUES (TRIM(p_nom), p_id_parent) RETURNING id INTO p_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Cette catégorie existe déjà à cet endroit de l''arbre.');
    END creer_categorie;

    PROCEDURE renommer_categorie(p_id IN NUMBER, p_nom IN VARCHAR2) IS
    BEGIN
        IF LENGTH(TRIM(p_nom)) < 2 OR TRIM(p_nom) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le nom de la catégorie doit faire au moins 2 caractères.');
        END IF;
        UPDATE categorie SET nom = TRIM(p_nom) WHERE id = p_id;
        IF SQL%ROWCOUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Catégorie introuvable : ' || p_id);
        END IF;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Une catégorie porte déjà ce nom à cet endroit de l''arbre.');
    END renommer_categorie;

    PROCEDURE supprimer_categorie(p_id IN NUMBER) IS
        v_enfants   PLS_INTEGER;
        v_produits  PLS_INTEGER;
        v_annonces  PLS_INTEGER;
    BEGIN
        SELECT (SELECT COUNT(*) FROM categorie WHERE id_parent = p_id),
               (SELECT COUNT(*) FROM produit WHERE id_categorie = p_id),
               (SELECT COUNT(*) FROM annonce WHERE id_categorie = p_id)
          INTO v_enfants, v_produits, v_annonces
          FROM dual;
        -- Message précis : l'admin sait quoi déplacer avant de réessayer
        IF v_enfants + v_produits + v_annonces > 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Catégorie non vide : ' || v_enfants
                || ' sous-catégorie(s), ' || v_produits || ' produit(s), ' || v_annonces || ' annonce(s).');
        END IF;
        DELETE FROM promotion WHERE id_categorie = p_id;
        DELETE FROM categorie WHERE id = p_id;
        IF SQL%ROWCOUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Catégorie introuvable : ' || p_id);
        END IF;
    END supprimer_categorie;

    -- =========================================================================
    -- Photos
    -- =========================================================================
    PROCEDURE ajouter_photo(p_id_produit IN NUMBER, p_id_boutique IN NUMBER, p_chemin IN VARCHAR2, p_id OUT NUMBER) IS
        v_nb PLS_INTEGER;
    BEGIN
        verifier_proprietaire(p_id_produit, p_id_boutique);
        SELECT COUNT(*) INTO v_nb FROM produit_photo WHERE id_produit = p_id_produit;
        IF v_nb >= c_photos_max THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Un produit a au plus ' || c_photos_max || ' photos.');
        END IF;
        INSERT INTO produit_photo (id_produit, chemin, ordre)
        VALUES (p_id_produit, p_chemin, v_nb + 1)
        RETURNING id INTO p_id;
    END ajouter_photo;

    PROCEDURE retirer_photo(p_id_photo IN NUMBER, p_id_boutique IN NUMBER, p_chemin OUT VARCHAR2) IS
        v_id_produit produit_photo.id_produit%TYPE;
    BEGIN
        BEGIN
            SELECT id_produit, chemin INTO v_id_produit, p_chemin FROM produit_photo WHERE id = p_id_photo;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Photo introuvable : ' || p_id_photo);
        END;
        verifier_proprietaire(v_id_produit, p_id_boutique);
        DELETE FROM produit_photo WHERE id = p_id_photo;
        -- Renumérote les photos restantes (1, 2, 3…) : ROW_NUMBER dans un MERGE
        MERGE INTO produit_photo ph
        USING (SELECT id, ROW_NUMBER() OVER (ORDER BY ordre, id) AS nouvel_ordre
                 FROM produit_photo WHERE id_produit = v_id_produit) n
           ON (ph.id = n.id)
         WHEN MATCHED THEN UPDATE SET ph.ordre = n.nouvel_ordre;
    END retirer_photo;

    -- =========================================================================
    -- Promotions
    -- =========================================================================
    PROCEDURE creer_promotion(
        p_libelle       IN  promotion.libelle%TYPE,
        p_pourcentage   IN  promotion.pourcentage%TYPE,
        p_date_debut    IN  promotion.date_debut%TYPE,
        p_date_fin      IN  promotion.date_fin%TYPE,
        p_id_produit    IN  promotion.id_produit%TYPE,
        p_id_categorie  IN  promotion.id_categorie%TYPE,
        p_id            OUT promotion.id%TYPE)
    IS
    BEGIN
        IF p_pourcentage IS NULL OR p_pourcentage <= 0 OR p_pourcentage > 90 THEN
            pkg_erreurs.lever(pkg_erreurs.c_promotion_invalide,
                'Le pourcentage doit être compris entre 0 (exclu) et 90.');
        END IF;
        IF p_date_debut IS NULL OR p_date_fin IS NULL OR p_date_fin <= p_date_debut THEN
            pkg_erreurs.lever(pkg_erreurs.c_promotion_invalide,
                'La date de fin doit être postérieure à la date de début.');
        END IF;
        IF (p_id_produit IS NULL) = (p_id_categorie IS NULL) THEN
            pkg_erreurs.lever(pkg_erreurs.c_promotion_invalide,
                'Une promotion vise soit un produit, soit une catégorie.');
        END IF;

        INSERT INTO promotion (libelle, pourcentage, date_debut, date_fin, id_produit, id_categorie)
        VALUES (p_libelle, p_pourcentage, p_date_debut, p_date_fin, p_id_produit, p_id_categorie)
        RETURNING id INTO p_id;
    END creer_promotion;

    PROCEDURE desactiver_promotion(p_id IN NUMBER) IS
    BEGIN
        UPDATE promotion SET actif = 0 WHERE id = p_id;
        IF SQL%ROWCOUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Promotion introuvable : ' || p_id);
        END IF;
    END desactiver_promotion;

    PROCEDURE desactiver_promotions_terminees(p_nb OUT NUMBER) IS
    BEGIN
        UPDATE promotion SET actif = 0 WHERE actif = 1 AND date_fin < SYSDATE;
        p_nb := SQL%ROWCOUNT;
    END desactiver_promotions_terminees;

END pkg_catalogue;
/
