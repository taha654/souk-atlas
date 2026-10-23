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

    PROCEDURE modifier_boutique(
        p_id_vendeur   IN boutique.id_vendeur%TYPE,
        p_nom          IN boutique.nom%TYPE,
        p_description  IN boutique.description%TYPE,
        p_ville        IN boutique.ville%TYPE)
    IS
        v_boutique boutique%ROWTYPE;
    BEGIN
        IF TRIM(p_nom) IS NULL OR LENGTH(TRIM(p_nom)) < 3 THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Le nom de la boutique doit faire au moins 3 caractères.');
        END IF;
        BEGIN
            SELECT * INTO v_boutique FROM boutique WHERE id_vendeur = p_id_vendeur FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Vous n''avez pas encore de boutique.');
        END;
        -- Un nouveau nom doit être revu par l'admin : sinon une boutique validée
        -- pourrait se renommer en n'importe quoi sans contrôle
        UPDATE boutique
           SET nom = TRIM(p_nom), description = p_description, ville = p_ville,
               statut = CASE WHEN statut = 'VALIDEE' AND nom <> TRIM(p_nom) THEN 'EN_ATTENTE' ELSE statut END
         WHERE id = v_boutique.id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Ce nom de boutique est déjà pris.');
    END modifier_boutique;

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

    -- ----- Jetons d'accès à l'API -----

    PROCEDURE creer_jeton(
        p_id_utilisateur IN  NUMBER,
        p_empreinte      IN  VARCHAR2,
        p_libelle        IN  VARCHAR2,
        p_jours          IN  NUMBER,
        p_id             OUT NUMBER)
    IS
        v_role   utilisateur.role%TYPE;
        v_actifs PLS_INTEGER;
    BEGIN
        BEGIN
            SELECT role INTO v_role FROM utilisateur WHERE id = p_id_utilisateur AND statut = 'ACTIF';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_erreurs.lever(pkg_erreurs.c_compte_introuvable, 'Compte introuvable ou désactivé.');
        END;
        IF v_role NOT IN ('VENDEUR', 'ADMIN') THEN
            pkg_erreurs.lever(pkg_erreurs.c_role_invalide, 'Les jetons d''API sont réservés aux vendeurs et aux administrateurs.');
        END IF;
        IF p_jours IS NULL OR p_jours NOT BETWEEN 1 AND 365 OR p_jours <> TRUNC(p_jours) THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Durée de validité invalide (1 à 365 jours).');
        END IF;
        IF TRIM(p_libelle) IS NULL OR LENGTH(TRIM(p_libelle)) > 100 THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Donnez un nom au jeton (100 caractères au plus).');
        END IF;
        -- Une empreinte SHA-256 en hexadécimal : 64 caractères 0-9 a-f
        IF p_empreinte IS NULL OR NOT REGEXP_LIKE(p_empreinte, '^[0-9a-f]{64}$') THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Empreinte de jeton invalide.');
        END IF;

        SELECT COUNT(*) INTO v_actifs FROM jeton_api
         WHERE id_utilisateur = p_id_utilisateur AND revoque = 0 AND date_expiration > SYSDATE;
        IF v_actifs >= c_jetons_max THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide,
                'Vous avez déjà ' || c_jetons_max || ' jetons valides : révoquez-en un d''abord.');
        END IF;

        INSERT INTO jeton_api (id_utilisateur, empreinte, libelle, date_expiration)
        VALUES (p_id_utilisateur, p_empreinte, TRIM(p_libelle), SYSDATE + p_jours)
        RETURNING id INTO p_id;
    END creer_jeton;

    PROCEDURE revoquer_jeton(p_id_jeton IN NUMBER, p_id_utilisateur IN NUMBER) IS
    BEGIN
        UPDATE jeton_api SET revoque = 1 WHERE id = p_id_jeton AND id_utilisateur = p_id_utilisateur;
        IF SQL%ROWCOUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_non_proprietaire, 'Ce jeton n''existe pas ou ne vous appartient pas.');
        END IF;
    END revoquer_jeton;

    PROCEDURE utilisateur_du_jeton(
        p_empreinte      IN  VARCHAR2,
        p_id_utilisateur OUT NUMBER,
        p_role           OUT VARCHAR2)
    IS
        v_id_jeton jeton_api.id%TYPE;
    BEGIN
        SELECT j.id, u.id, u.role INTO v_id_jeton, p_id_utilisateur, p_role
          FROM jeton_api j JOIN utilisateur u ON u.id = j.id_utilisateur
         WHERE j.empreinte = p_empreinte
           AND j.revoque = 0 AND j.date_expiration > SYSDATE
           AND u.statut = 'ACTIF';
        UPDATE jeton_api SET date_derniere_utilisation = SYSDATE WHERE id = v_id_jeton;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pkg_erreurs.lever(pkg_erreurs.c_compte_introuvable, 'Jeton d''API invalide, expiré ou révoqué.');
    END utilisateur_du_jeton;

END pkg_utilisateur;
/
