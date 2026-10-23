-- =============================================================================
-- PKG_CATALOGUE : recherche, catégories en arbre, prix promotionnels, produits
--
-- Les fonctions qui renvoient SYS_REFCURSOR sont lues par PHP avec oci_new_cursor :
-- un curseur ouvert côté Oracle, dont PHP parcourt les lignes.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_catalogue AS

    -- ----- Prix -----
    -- Meilleur pourcentage de promotion actif aujourd'hui pour ce produit :
    -- promotion sur le produit lui-même, sur sa catégorie ou sur une catégorie parente.
    -- Déclarées dans la spécification pour être utilisables dans un SELECT.
    FUNCTION pourcentage_promo(p_id_produit IN produit.id%TYPE) RETURN NUMBER;
    -- Prix HT après promotion, arrondi au centime
    FUNCTION prix_courant(p_id_produit IN produit.id%TYPE) RETURN NUMBER;
    -- Même prix, TVA comprise (prix affiché aux particuliers)
    FUNCTION prix_courant_ttc(p_id_produit IN produit.id%TYPE) RETURN NUMBER;
    -- Montant HT → TTC, avec le taux unique de pkg_panier.c_taux_tva
    FUNCTION ttc(p_montant_ht IN NUMBER) RETURN NUMBER DETERMINISTIC;

    -- Texte en minuscules et sans accents, pour comparer "Téléphone" et "telephone".
    -- DETERMINISTIC : même entrée, même sortie (Oracle peut mettre le résultat en cache).
    FUNCTION normaliser(p_texte IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

    -- ----- Catégories -----
    -- Arbre complet : id, nom, id_parent, niveau, chemin, est_feuille
    FUNCTION arbre_categories RETURN SYS_REFCURSOR;
    -- Fil d'Ariane : "Électronique > Téléphones > Smartphones"
    FUNCTION chemin_categorie(p_id_categorie IN categorie.id%TYPE) RETURN VARCHAR2;

    -- ----- Recherche -----
    -- Recherche insensible à la casse et aux accents (nom et description).
    -- p_id_categorie inclut toutes les sous-catégories.
    -- p_prix_min / p_prix_max : prix TTC, celui que voit l'acheteur.
    -- p_en_stock = 1 : seulement les produits disponibles.
    -- p_tri : 'pertinence' (défaut), 'prix_asc', 'prix_desc', 'recent', 'note'.
    -- Colonnes : id, nom, id_categorie, boutique, prix_ht, pourcentage_promo,
    --            prix_courant_ht, prix_courant_ttc, prix_ttc (avant promo), stock, note_moyenne, nb_avis,
    --            date_creation, photo, pertinence, total
    -- (total = nombre de résultats sans pagination, calculé par COUNT(*) OVER ()).
    FUNCTION rechercher(
        p_texte         IN VARCHAR2 DEFAULT NULL,
        p_id_categorie  IN NUMBER   DEFAULT NULL,
        p_prix_min      IN NUMBER   DEFAULT NULL,
        p_prix_max      IN NUMBER   DEFAULT NULL,
        p_tri           IN VARCHAR2 DEFAULT 'pertinence',
        p_page          IN NUMBER   DEFAULT 1,
        p_taille_page   IN NUMBER   DEFAULT 20,
        p_en_stock      IN NUMBER   DEFAULT 0) RETURN SYS_REFCURSOR;

    -- Autocomplétion : produits dont un mot commence par p_prefixe
    FUNCTION suggestions(p_prefixe IN VARCHAR2, p_limite IN NUMBER DEFAULT 8) RETURN SYS_REFCURSOR;

    -- ----- Produits (espace vendeur) -----
    -- p_id_boutique identifie la boutique du vendeur connecté : un vendeur ne
    -- touche qu'à ses propres produits (-20012 sinon).
    PROCEDURE creer_produit(
        p_id_boutique   IN  produit.id_boutique%TYPE,
        p_id_categorie  IN  produit.id_categorie%TYPE,
        p_nom           IN  produit.nom%TYPE,
        p_description   IN  produit.description%TYPE,
        p_prix_ht       IN  produit.prix_ht%TYPE,
        p_stock         IN  produit.stock%TYPE,
        p_id            OUT produit.id%TYPE);

    PROCEDURE modifier_produit(
        p_id            IN produit.id%TYPE,
        p_id_boutique   IN produit.id_boutique%TYPE,
        p_id_categorie  IN produit.id_categorie%TYPE,
        p_nom           IN produit.nom%TYPE,
        p_description   IN produit.description%TYPE,
        p_prix_ht       IN produit.prix_ht%TYPE,
        p_statut        IN produit.statut%TYPE);

    -- Ajoute (delta > 0) ou retire (delta < 0) du stock ; -20001 si le stock deviendrait négatif
    PROCEDURE ajuster_stock(
        p_id IN produit.id%TYPE, p_id_boutique IN produit.id_boutique%TYPE, p_delta IN NUMBER);

    -- ----- Catégories (admin) -----
    -- p_id_parent NULL = catégorie racine ; -20017 si le nom existe déjà au même niveau
    PROCEDURE creer_categorie(p_nom IN VARCHAR2, p_id_parent IN NUMBER, p_id OUT NUMBER);
    PROCEDURE renommer_categorie(p_id IN NUMBER, p_nom IN VARCHAR2);
    -- Refusée (-20017) si la catégorie a des sous-catégories, des produits ou des annonces
    PROCEDURE supprimer_categorie(p_id IN NUMBER);

    -- ----- Photos (espace vendeur) -----
    c_photos_max CONSTANT PLS_INTEGER := 6;
    -- Ajoute une photo en dernière position ; -20012 si le produit n'est pas à la
    -- boutique, -20017 au-delà de c_photos_max photos
    PROCEDURE ajouter_photo(p_id_produit IN NUMBER, p_id_boutique IN NUMBER, p_chemin IN VARCHAR2, p_id OUT NUMBER);
    -- Supprime la photo et renvoie son chemin (PHP efface ensuite le fichier)
    PROCEDURE retirer_photo(p_id_photo IN NUMBER, p_id_boutique IN NUMBER, p_chemin OUT VARCHAR2);

    -- ----- Promotions (admin) -----
    -- Exactement une cible : p_id_produit OU p_id_categorie (-20015 sinon)
    PROCEDURE creer_promotion(
        p_libelle       IN  promotion.libelle%TYPE,
        p_pourcentage   IN  promotion.pourcentage%TYPE,
        p_date_debut    IN  promotion.date_debut%TYPE,
        p_date_fin      IN  promotion.date_fin%TYPE,
        p_id_produit    IN  promotion.id_produit%TYPE,
        p_id_categorie  IN  promotion.id_categorie%TYPE,
        p_id            OUT promotion.id%TYPE);

    -- Arrêt anticipé d'une promotion par l'admin
    PROCEDURE desactiver_promotion(p_id IN NUMBER);

    -- Appelée par le job JOB_FIN_PROMOTIONS ; p_nb = nombre de promotions désactivées
    PROCEDURE desactiver_promotions_terminees(p_nb OUT NUMBER);

END pkg_catalogue;
/
