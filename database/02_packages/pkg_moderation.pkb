CREATE OR REPLACE PACKAGE BODY pkg_moderation AS

    -- ORA-02291 : la clé étrangère pointe vers une ligne qui n'existe pas
    e_cible_inexistante EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_cible_inexistante, -2291);

    PROCEDURE signaler(
        p_id_auteur    IN  NUMBER,
        p_type_cible   IN  VARCHAR2,
        p_id_cible     IN  NUMBER,
        p_motif        IN  VARCHAR2,
        p_commentaire  IN  VARCHAR2,
        p_id           OUT NUMBER)
    IS
        v_id_annonce  NUMBER;
        v_id_avis     NUMBER;
        v_id_produit  NUMBER;
        v_deja        PLS_INTEGER;
    BEGIN
        CASE p_type_cible
            WHEN 'ANNONCE' THEN v_id_annonce := p_id_cible;
            WHEN 'AVIS'    THEN v_id_avis    := p_id_cible;
            WHEN 'PRODUIT' THEN v_id_produit := p_id_cible;
            ELSE pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Type de cible inconnu : ' || p_type_cible);
        END CASE;

        IF p_motif IS NULL OR p_motif NOT IN ('ARNAQUE', 'CONTREFACON', 'INAPPROPRIE', 'DOUBLON', 'AUTRE') THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Motif de signalement inconnu.');
        END IF;

        SELECT COUNT(*) INTO v_deja FROM signalement
         WHERE id_auteur = p_id_auteur AND statut = 'OUVERT'
           AND (id_annonce = v_id_annonce OR id_avis = v_id_avis OR id_produit = v_id_produit);
        IF v_deja > 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Vous avez déjà signalé ce contenu.');
        END IF;

        INSERT INTO signalement (id_auteur, id_annonce, id_avis, id_produit, motif, commentaire)
        VALUES (p_id_auteur, v_id_annonce, v_id_avis, v_id_produit, p_motif, TRIM(p_commentaire))
        RETURNING id INTO p_id;
    EXCEPTION
        WHEN e_cible_inexistante THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Le contenu signalé n''existe pas.');
    END signaler;

    PROCEDURE traiter(p_id_signalement IN NUMBER, p_id_moderateur IN NUMBER, p_decision IN VARCHAR2) IS
        v_sig     signalement%ROWTYPE;
        v_statut  signalement.statut%TYPE;
    BEGIN
        BEGIN
            SELECT * INTO v_sig FROM signalement WHERE id = p_id_signalement FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Signalement introuvable : ' || p_id_signalement);
        END;
        IF v_sig.statut <> 'OUVERT' THEN
            pkg_erreurs.lever(pkg_erreurs.c_transition_interdite, 'Ce signalement a déjà été traité.');
        END IF;

        CASE p_decision
            WHEN 'APPROUVER' THEN v_statut := 'APPROUVE';
            WHEN 'REJETER'   THEN v_statut := 'REJETE';
            ELSE pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Décision inconnue : ' || p_decision);
        END CASE;

        -- Signalement approuvé : on retire le contenu visé
        IF v_statut = 'APPROUVE' THEN
            IF v_sig.id_annonce IS NOT NULL THEN
                UPDATE annonce SET statut = 'REFUSEE', motif_refus = 'Retirée après signalement (' || v_sig.motif || ')'
                 WHERE id = v_sig.id_annonce;
            ELSIF v_sig.id_avis IS NOT NULL THEN
                pkg_avis.changer_statut(v_sig.id_avis, 'MASQUE');
            ELSE
                UPDATE produit SET statut = 'INACTIF' WHERE id = v_sig.id_produit;
            END IF;
        END IF;

        -- Une comparaison avec NULL n'est jamais vraie : seule la colonne
        -- renseignée de la cible fait correspondre les lignes
        UPDATE signalement
           SET statut = v_statut, id_moderateur = p_id_moderateur, date_traitement = SYSDATE
         WHERE statut = 'OUVERT'
           AND (id_annonce = v_sig.id_annonce OR id_avis = v_sig.id_avis OR id_produit = v_sig.id_produit);
    END traiter;

END pkg_moderation;
/
