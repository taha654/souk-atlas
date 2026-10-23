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
        IF LENGTH(TRIM(p_titre)) < 5 OR TRIM(p_titre) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le titre doit faire au moins 5 caractères.');
        END IF;
        IF TRIM(p_description) IS NULL OR TRIM(p_ville) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'La description et la ville sont obligatoires.');
        END IF;
        IF p_prix IS NULL OR p_prix < 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le prix ne peut pas être négatif.');
        END IF;

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
