CREATE OR REPLACE PACKAGE BODY pkg_annonce AS

    -- Lit et verrouille l'annonce dans un RECORD de type annonce%ROWTYPE
    -- (un champ par colonne de la table, mis à jour automatiquement si la
    -- table change)
    FUNCTION verrouiller(p_id_annonce IN NUMBER) RETURN annonce%ROWTYPE IS
        v_annonce annonce%ROWTYPE;
    BEGIN
        SELECT * INTO v_annonce FROM annonce WHERE id = p_id_annonce FOR UPDATE;
        RETURN v_annonce;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Annonce introuvable : ' || p_id_annonce);
    END verrouiller;

    PROCEDURE verifier_auteur(p_annonce IN annonce%ROWTYPE, p_id_utilisateur IN NUMBER) IS
    BEGIN
        IF p_annonce.id_utilisateur <> p_id_utilisateur THEN
            pkg_erreurs.lever(pkg_erreurs.c_non_proprietaire, 'Cette annonce ne vous appartient pas.');
        END IF;
    END verifier_auteur;

    -- Déclarée AVANT publier et modifier, qui l'appellent (sinon PLS-00313)
    PROCEDURE verifier_donnees(p_titre IN VARCHAR2, p_description IN VARCHAR2, p_prix IN NUMBER, p_ville IN VARCHAR2) IS
    BEGIN
        IF LENGTH(TRIM(p_titre)) < 5 OR TRIM(p_titre) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le titre doit faire au moins 5 caractères.');
        END IF;
        IF TRIM(p_description) IS NULL OR TRIM(p_ville) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'La description et la ville sont obligatoires.');
        END IF;
        IF p_prix IS NULL OR p_prix < 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le prix ne peut pas être négatif.');
        END IF;
    END verifier_donnees;

    PROCEDURE publier(
        p_id_utilisateur IN  NUMBER,
        p_id_categorie   IN  NUMBER,
        p_titre          IN  VARCHAR2,
        p_description    IN  VARCHAR2,
        p_prix           IN  NUMBER,
        p_ville          IN  VARCHAR2,
        p_score_risque   IN  NUMBER DEFAULT NULL,
        p_id             OUT NUMBER)
    IS
        v_statut_compte utilisateur.statut%TYPE;
        v_statut        annonce.statut%TYPE;
    BEGIN
        BEGIN
            SELECT statut INTO v_statut_compte FROM utilisateur WHERE id = p_id_utilisateur;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_statut_compte := NULL;
        END;
        IF v_statut_compte IS NULL OR v_statut_compte <> 'ACTIF' THEN
            pkg_erreurs.lever(pkg_erreurs.c_compte_introuvable, 'Compte introuvable ou désactivé.');
        END IF;
        verifier_donnees(p_titre, p_description, p_prix, p_ville);

        -- Sans score (moteur C++ absent), l'annonce part directement en ligne
        v_statut := CASE WHEN p_score_risque >= c_seuil_moderation THEN 'EN_MODERATION' ELSE 'EN_LIGNE' END;

        INSERT INTO annonce (id_utilisateur, id_categorie, titre, description, prix, ville,
                             statut, score_risque, date_publication, date_expiration)
        VALUES (p_id_utilisateur, p_id_categorie, TRIM(p_titre), TRIM(p_description), p_prix,
                TRIM(p_ville), v_statut, p_score_risque, SYSDATE, SYSDATE + c_duree_jours)
        RETURNING id INTO p_id;
    END publier;

    PROCEDURE moderer(p_id_annonce IN NUMBER, p_decision IN VARCHAR2, p_motif IN VARCHAR2 DEFAULT NULL) IS
        v_annonce annonce%ROWTYPE := verrouiller(p_id_annonce);
    BEGIN
        IF v_annonce.statut <> 'EN_MODERATION' THEN
            pkg_erreurs.lever(pkg_erreurs.c_etat_annonce_invalide,
                'Cette annonce n''attend pas de modération (statut ' || v_annonce.statut || ').');
        END IF;

        IF p_decision = 'APPROUVER' THEN
            -- Les 30 jours commencent à la mise en ligne, pas au dépôt
            UPDATE annonce
               SET statut = 'EN_LIGNE', date_publication = SYSDATE,
                   date_expiration = SYSDATE + c_duree_jours
             WHERE id = p_id_annonce;
        ELSIF p_decision = 'REFUSER' THEN
            IF TRIM(p_motif) IS NULL THEN
                pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Un refus doit être motivé.');
            END IF;
            UPDATE annonce SET statut = 'REFUSEE', motif_refus = TRIM(p_motif) WHERE id = p_id_annonce;
        ELSE
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Décision inconnue : ' || p_decision);
        END IF;
    END moderer;

    PROCEDURE renouveler(p_id_annonce IN NUMBER, p_id_utilisateur IN NUMBER) IS
        v_annonce annonce%ROWTYPE := verrouiller(p_id_annonce);
    BEGIN
        verifier_auteur(v_annonce, p_id_utilisateur);
        IF v_annonce.statut NOT IN ('EN_LIGNE', 'EXPIREE') THEN
            pkg_erreurs.lever(pkg_erreurs.c_etat_annonce_invalide,
                'Seule une annonce en ligne ou expirée peut être renouvelée.');
        END IF;
        UPDATE annonce
           SET statut = 'EN_LIGNE', date_expiration = SYSDATE + c_duree_jours
         WHERE id = p_id_annonce;
    END renouveler;

    PROCEDURE marquer_vendue(p_id_annonce IN NUMBER, p_id_utilisateur IN NUMBER) IS
        v_annonce annonce%ROWTYPE := verrouiller(p_id_annonce);
    BEGIN
        verifier_auteur(v_annonce, p_id_utilisateur);
        IF v_annonce.statut <> 'EN_LIGNE' THEN
            pkg_erreurs.lever(pkg_erreurs.c_etat_annonce_invalide,
                'Seule une annonce en ligne peut être marquée vendue.');
        END IF;
        UPDATE annonce SET statut = 'VENDUE' WHERE id = p_id_annonce;
    END marquer_vendue;

    PROCEDURE expirer_annonces(p_nb OUT NUMBER) IS
    BEGIN
        UPDATE annonce SET statut = 'EXPIREE'
         WHERE statut = 'EN_LIGNE' AND date_expiration < SYSDATE;
        p_nb := SQL%ROWCOUNT;
    END expirer_annonces;

    PROCEDURE modifier(
        p_id_annonce     IN NUMBER,
        p_id_utilisateur IN NUMBER,
        p_id_categorie   IN NUMBER,
        p_titre          IN VARCHAR2,
        p_description    IN VARCHAR2,
        p_prix           IN NUMBER,
        p_ville          IN VARCHAR2,
        p_score_risque   IN NUMBER DEFAULT NULL)
    IS
        v_annonce annonce%ROWTYPE := verrouiller(p_id_annonce);
    BEGIN
        verifier_auteur(v_annonce, p_id_utilisateur);
        IF v_annonce.statut NOT IN ('EN_LIGNE', 'EN_MODERATION') THEN
            pkg_erreurs.lever(pkg_erreurs.c_etat_annonce_invalide,
                'Une annonce ' || LOWER(v_annonce.statut) || ' ne peut plus être modifiée.');
        END IF;
        verifier_donnees(p_titre, p_description, p_prix, p_ville);
        UPDATE annonce
           SET id_categorie = p_id_categorie, titre = TRIM(p_titre), description = TRIM(p_description),
               prix = p_prix, ville = TRIM(p_ville),
               -- Sans nouveau score (moteur indisponible), on garde l'ancien
               score_risque = NVL(p_score_risque, score_risque),
               -- Une annonce EN_MODERATION y reste : seul un modérateur la libère
               statut = CASE WHEN statut = 'EN_LIGNE' AND p_score_risque >= c_seuil_moderation
                             THEN 'EN_MODERATION' ELSE statut END
         WHERE id = p_id_annonce;
    END modifier;

    FUNCTION contexte_risque(p_id_utilisateur IN NUMBER, p_id_categorie IN NUMBER) RETURN SYS_REFCURSOR IS
        v_curseur   SYS_REFCURSOR;
        v_categorie categorie.id%TYPE := p_id_categorie;
        v_parent    categorie.id_parent%TYPE;
        v_median    NUMBER;
        v_nb        NUMBER;
    BEGIN
        -- On remonte l'arbre des catégories tant que l'échantillon est trop petit
        -- pour qu'une médiane ait un sens (racine atteinte : on garde ce qu'on a)
        LOOP
            SELECT MEDIAN(a.prix), COUNT(*) INTO v_median, v_nb
              FROM annonce a
             WHERE a.statut IN ('EN_LIGNE', 'VENDUE', 'EXPIREE')
               AND a.id_categorie IN (SELECT c.id FROM categorie c
                                       START WITH c.id = v_categorie
                                     CONNECT BY PRIOR c.id = c.id_parent);
            EXIT WHEN v_nb >= c_annonces_min_mediane;
            BEGIN
                SELECT id_parent INTO v_parent FROM categorie WHERE id = v_categorie;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN v_parent := NULL;   -- catégorie inconnue
            END;
            EXIT WHEN v_parent IS NULL;
            v_categorie := v_parent;
        END LOOP;

        OPEN v_curseur FOR
            SELECT v_median AS prix_median,
                   v_nb AS nb_annonces,
                   (SELECT COUNT(*) FROM annonce a
                     WHERE a.id_utilisateur = p_id_utilisateur
                       AND a.date_publication > SYSDATE - 1) AS annonces_24h,
                   (SELECT SYSDATE - u.date_creation FROM utilisateur u
                     WHERE u.id = p_id_utilisateur) AS anciennete_jours
              FROM DUAL;
        RETURN v_curseur;
    END contexte_risque;

    FUNCTION rechercher(
        p_texte         IN VARCHAR2 DEFAULT NULL,
        p_id_categorie  IN NUMBER   DEFAULT NULL,
        p_ville         IN VARCHAR2 DEFAULT NULL,
        p_prix_min      IN NUMBER   DEFAULT NULL,
        p_prix_max      IN NUMBER   DEFAULT NULL,
        p_tri           IN VARCHAR2 DEFAULT 'recent',
        p_page          IN NUMBER   DEFAULT 1,
        p_taille_page   IN NUMBER   DEFAULT 20) RETURN SYS_REFCURSOR
    IS
        v_curseur SYS_REFCURSOR;
        v_texte   VARCHAR2(200) := pkg_catalogue.normaliser(TRIM(p_texte));
        v_ville   VARCHAR2(60)  := pkg_catalogue.normaliser(TRIM(p_ville));
        v_taille  NUMBER := LEAST(GREATEST(NVL(p_taille_page, 20), 1), 100);
        v_page    NUMBER := GREATEST(NVL(p_page, 1), 1);
    BEGIN
        OPEN v_curseur FOR
            SELECT a.id, a.titre, a.prix, a.ville, a.id_categorie, c.nom AS categorie, a.date_publication,
                   (SELECT MIN(ph.chemin) KEEP (DENSE_RANK FIRST ORDER BY ph.ordre)
                      FROM annonce_photo ph WHERE ph.id_annonce = a.id) AS photo,
                   COUNT(*) OVER () AS total
              FROM annonce a
              JOIN categorie c ON c.id = a.id_categorie
             WHERE a.statut = 'EN_LIGNE'
               AND (v_texte IS NULL
                    OR a.titre_recherche LIKE '%' || v_texte || '%'
                    OR pkg_catalogue.normaliser(a.description) LIKE '%' || v_texte || '%')
               -- Ville sans accents ni majuscules : "fes" trouve "Fès"
               AND (v_ville IS NULL OR pkg_catalogue.normaliser(a.ville) = v_ville)
               AND (p_prix_min IS NULL OR a.prix >= p_prix_min)
               AND (p_prix_max IS NULL OR a.prix <= p_prix_max)
               AND (p_id_categorie IS NULL
                    OR a.id_categorie IN (SELECT d.id FROM categorie d
                                           START WITH d.id = p_id_categorie
                                         CONNECT BY PRIOR d.id = d.id_parent))
             ORDER BY CASE WHEN p_tri = 'prix_asc'  THEN a.prix END ASC,
                      CASE WHEN p_tri = 'prix_desc' THEN a.prix END DESC,
                      a.date_publication DESC, a.id DESC
            OFFSET (v_page - 1) * v_taille ROWS FETCH NEXT v_taille ROWS ONLY;
        RETURN v_curseur;
    END rechercher;

    PROCEDURE ajouter_photo(p_id_annonce IN NUMBER, p_id_utilisateur IN NUMBER, p_chemin IN VARCHAR2, p_id OUT NUMBER) IS
        v_annonce annonce%ROWTYPE := verrouiller(p_id_annonce);
        v_nb      PLS_INTEGER;
    BEGIN
        verifier_auteur(v_annonce, p_id_utilisateur);
        SELECT COUNT(*) INTO v_nb FROM annonce_photo WHERE id_annonce = p_id_annonce;
        IF v_nb >= c_photos_max THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Une annonce a au plus ' || c_photos_max || ' photos.');
        END IF;
        INSERT INTO annonce_photo (id_annonce, chemin, ordre) VALUES (p_id_annonce, p_chemin, v_nb + 1)
        RETURNING id INTO p_id;
    END ajouter_photo;

    PROCEDURE retirer_photo(p_id_photo IN NUMBER, p_id_utilisateur IN NUMBER, p_chemin OUT VARCHAR2) IS
        v_id_annonce annonce_photo.id_annonce%TYPE;
    BEGIN
        BEGIN
            SELECT id_annonce, chemin INTO v_id_annonce, p_chemin FROM annonce_photo WHERE id = p_id_photo;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Photo introuvable : ' || p_id_photo);
        END;
        verifier_auteur(verrouiller(v_id_annonce), p_id_utilisateur);
        DELETE FROM annonce_photo WHERE id = p_id_photo;
        MERGE INTO annonce_photo ph
        USING (SELECT id, ROW_NUMBER() OVER (ORDER BY ordre, id) AS nouvel_ordre
                 FROM annonce_photo WHERE id_annonce = v_id_annonce) n
           ON (ph.id = n.id)
         WHEN MATCHED THEN UPDATE SET ph.ordre = n.nouvel_ordre;
    END retirer_photo;

    PROCEDURE ajouter_favori(p_id_utilisateur IN NUMBER, p_id_annonce IN NUMBER) IS
    BEGIN
        INSERT INTO favori (id_utilisateur, id_annonce) VALUES (p_id_utilisateur, p_id_annonce);
    EXCEPTION
        -- Déjà en favori : le résultat voulu est atteint, on ne signale rien
        WHEN DUP_VAL_ON_INDEX THEN NULL;
    END ajouter_favori;

    PROCEDURE retirer_favori(p_id_utilisateur IN NUMBER, p_id_annonce IN NUMBER) IS
    BEGIN
        DELETE FROM favori WHERE id_utilisateur = p_id_utilisateur AND id_annonce = p_id_annonce;
    END retirer_favori;

END pkg_annonce;
/
