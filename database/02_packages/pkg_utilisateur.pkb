CREATE OR REPLACE PACKAGE BODY pkg_utilisateur AS

    -- Vérifie que le compte existe ; lève -20009 sinon
    PROCEDURE verifier_existe(p_id IN utilisateur.id%TYPE) IS
        v_nb PLS_INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_nb FROM utilisateur WHERE id = p_id;
        IF v_nb = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_compte_introuvable, 'Compte introuvable : ' || p_id);
        END IF;
    END verifier_existe;

    PROCEDURE creer_compte(
        p_email      IN  utilisateur.email%TYPE,
        p_hash       IN  utilisateur.mot_de_passe_hash%TYPE,
        p_nom        IN  utilisateur.nom%TYPE,
        p_telephone  IN  utilisateur.telephone%TYPE,
        p_ville      IN  utilisateur.ville%TYPE,
        p_role       IN  utilisateur.role%TYPE DEFAULT 'CLIENT',
        p_id         OUT utilisateur.id%TYPE)
    IS
    BEGIN
        IF p_role NOT IN ('CLIENT', 'VENDEUR') THEN
            pkg_erreurs.lever(pkg_erreurs.c_role_invalide,
                'Rôle impossible à l''inscription : ' || p_role);
        END IF;
        IF TRIM(p_nom) IS NULL THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le nom est obligatoire.');
        END IF;

        INSERT INTO utilisateur (email, mot_de_passe_hash, nom, telephone, ville, role)
        VALUES (LOWER(TRIM(p_email)), p_hash, TRIM(p_nom), p_telephone, p_ville, p_role)
        RETURNING id INTO p_id;
    EXCEPTION
        -- L'index unique UQ_UTILISATEUR_EMAIL fait le contrôle, sans course possible
        -- entre deux inscriptions simultanées (un SELECT préalable ne le garantirait pas)
        WHEN DUP_VAL_ON_INDEX THEN
            pkg_erreurs.lever(pkg_erreurs.c_email_deja_utilise,
                'Un compte existe déjà avec l''email ' || LOWER(TRIM(p_email)) || '.');
    END creer_compte;

    PROCEDURE changer_role(p_id IN utilisateur.id%TYPE, p_role IN utilisateur.role%TYPE) IS
    BEGIN
        IF p_role NOT IN ('CLIENT', 'VENDEUR', 'ADMIN') THEN
            pkg_erreurs.lever(pkg_erreurs.c_role_invalide, 'Rôle inconnu : ' || p_role);
        END IF;
        verifier_existe(p_id);
        UPDATE utilisateur SET role = p_role WHERE id = p_id;
    END changer_role;

    PROCEDURE desactiver(p_id IN utilisateur.id%TYPE) IS
    BEGIN
        verifier_existe(p_id);
        UPDATE utilisateur SET statut = 'DESACTIVE' WHERE id = p_id;
        -- Les annonces d'un compte désactivé ne doivent plus être visibles
        UPDATE annonce SET statut = 'EXPIREE'
         WHERE id_utilisateur = p_id AND statut IN ('EN_LIGNE', 'EN_MODERATION');
    END desactiver;

    PROCEDURE reactiver(p_id IN utilisateur.id%TYPE) IS
    BEGIN
        verifier_existe(p_id);
        UPDATE utilisateur SET statut = 'ACTIF' WHERE id = p_id;
    END reactiver;

    PROCEDURE enregistrer_connexion(p_id IN utilisateur.id%TYPE) IS
    BEGIN
        UPDATE utilisateur SET date_derniere_connexion = SYSDATE WHERE id = p_id;
    END enregistrer_connexion;

    PROCEDURE enregistrer_tentative(
        p_email IN VARCHAR2, p_adresse_ip IN VARCHAR2, p_reussie IN NUMBER) IS
    BEGIN
        INSERT INTO tentative_connexion (email, adresse_ip, reussie)
        VALUES (LOWER(TRIM(p_email)), p_adresse_ip, p_reussie);
    END enregistrer_tentative;

    FUNCTION nb_echecs_recents(p_email IN VARCHAR2, p_minutes IN NUMBER DEFAULT 15) RETURN NUMBER IS
        v_nb NUMBER;
    BEGIN
        -- NUMTODSINTERVAL convertit un nombre de minutes en intervalle de temps
        SELECT COUNT(*) INTO v_nb
          FROM tentative_connexion
         WHERE email = LOWER(TRIM(p_email))
           AND reussie = 0
           AND date_tentative > SYSTIMESTAMP - NUMTODSINTERVAL(p_minutes, 'MINUTE');
        RETURN v_nb;
    END nb_echecs_recents;

    FUNCTION nb_echecs_ip(p_adresse_ip IN VARCHAR2, p_minutes IN NUMBER DEFAULT 15) RETURN NUMBER IS
        v_nb NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_nb
          FROM tentative_connexion
         WHERE adresse_ip = p_adresse_ip
           AND reussie = 0
           AND date_tentative > SYSTIMESTAMP - NUMTODSINTERVAL(p_minutes, 'MINUTE');
        RETURN v_nb;
    END nb_echecs_ip;

    PROCEDURE changer_hash(p_id IN utilisateur.id%TYPE, p_hash IN utilisateur.mot_de_passe_hash%TYPE) IS
    BEGIN
        UPDATE utilisateur SET mot_de_passe_hash = p_hash WHERE id = p_id;
        IF SQL%ROWCOUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_compte_introuvable, 'Compte introuvable : ' || p_id);
        END IF;
    END changer_hash;

    PROCEDURE creer_boutique(
        p_id_vendeur   IN  boutique.id_vendeur%TYPE,
        p_nom          IN  boutique.nom%TYPE,
        p_description  IN  boutique.description%TYPE,
        p_ville        IN  boutique.ville%TYPE,
        p_id           OUT boutique.id%TYPE)
    IS
        v_role utilisateur.role%TYPE;
    BEGIN
        BEGIN
            SELECT role INTO v_role FROM utilisateur WHERE id = p_id_vendeur;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_erreurs.lever(pkg_erreurs.c_compte_introuvable, 'Vendeur introuvable.');
        END;
        IF v_role <> 'VENDEUR' THEN
            pkg_erreurs.lever(pkg_erreurs.c_role_invalide,
                'Seul un compte vendeur peut ouvrir une boutique.');
        END IF;

        INSERT INTO boutique (id_vendeur, nom, description, ville)
        VALUES (p_id_vendeur, TRIM(p_nom), p_description, p_ville)
        RETURNING id INTO p_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide,
                'Ce vendeur a déjà une boutique, ou ce nom de boutique est pris.');
    END creer_boutique;

    PROCEDURE changer_statut_boutique(p_id IN boutique.id%TYPE, p_statut IN boutique.statut%TYPE) IS
    BEGIN
        IF p_statut NOT IN ('VALIDEE', 'REFUSEE', 'SUSPENDUE') THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Statut de boutique invalide : ' || p_statut);
        END IF;
        UPDATE boutique SET statut = p_statut WHERE id = p_id;
        -- SQL%ROWCOUNT : nombre de lignes touchées par le dernier ordre SQL
        IF SQL%ROWCOUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Boutique introuvable : ' || p_id);
        END IF;
    END changer_statut_boutique;

END pkg_utilisateur;
/
