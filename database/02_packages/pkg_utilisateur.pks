-- =============================================================================
-- PKG_UTILISATEUR : comptes, rôles, boutiques des vendeurs, tentatives de connexion
-- Le mot de passe arrive DÉJÀ haché par PHP (password_hash) : la base ne voit
-- jamais le mot de passe en clair.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_utilisateur AS

    -- Inscription : seuls les rôles CLIENT et VENDEUR sont possibles (-20014 sinon).
    -- -20008 si l'email est déjà utilisé.
    PROCEDURE creer_compte(
        p_email      IN  utilisateur.email%TYPE,
        p_hash       IN  utilisateur.mot_de_passe_hash%TYPE,
        p_nom        IN  utilisateur.nom%TYPE,
        p_telephone  IN  utilisateur.telephone%TYPE,
        p_ville      IN  utilisateur.ville%TYPE,
        p_role       IN  utilisateur.role%TYPE DEFAULT 'CLIENT',
        p_id         OUT utilisateur.id%TYPE);

    -- Réservé à l'admin (contrôlé côté PHP) : CLIENT, VENDEUR ou ADMIN
    PROCEDURE changer_role(p_id IN utilisateur.id%TYPE, p_role IN utilisateur.role%TYPE);

    PROCEDURE desactiver(p_id IN utilisateur.id%TYPE);
    PROCEDURE reactiver(p_id IN utilisateur.id%TYPE);

    -- Appelée après une connexion réussie
    PROCEDURE enregistrer_connexion(p_id IN utilisateur.id%TYPE);

    -- Remplace le hash (PHP le recalcule quand password_needs_rehash le demande)
    PROCEDURE changer_hash(p_id IN utilisateur.id%TYPE, p_hash IN utilisateur.mot_de_passe_hash%TYPE);

    -- Limitation des tentatives de connexion : par email ET par adresse IP
    PROCEDURE enregistrer_tentative(
        p_email IN VARCHAR2, p_adresse_ip IN VARCHAR2, p_reussie IN NUMBER);
    FUNCTION nb_echecs_recents(p_email IN VARCHAR2, p_minutes IN NUMBER DEFAULT 15) RETURN NUMBER;
    FUNCTION nb_echecs_ip(p_adresse_ip IN VARCHAR2, p_minutes IN NUMBER DEFAULT 15) RETURN NUMBER;

    -- Boutique d'un vendeur : créée EN_ATTENTE, validée ensuite par l'admin
    PROCEDURE creer_boutique(
        p_id_vendeur   IN  boutique.id_vendeur%TYPE,
        p_nom          IN  boutique.nom%TYPE,
        p_description  IN  boutique.description%TYPE,
        p_ville        IN  boutique.ville%TYPE,
        p_id           OUT boutique.id%TYPE);

    -- Le vendeur modifie SA boutique (identifiée par son id de vendeur) ; un
    -- changement de nom d'une boutique validée la renvoie EN_ATTENTE de validation
    PROCEDURE modifier_boutique(
        p_id_vendeur   IN boutique.id_vendeur%TYPE,
        p_nom          IN boutique.nom%TYPE,
        p_description  IN boutique.description%TYPE,
        p_ville        IN boutique.ville%TYPE);

    -- p_statut : VALIDEE, REFUSEE ou SUSPENDUE
    PROCEDURE changer_statut_boutique(p_id IN boutique.id%TYPE, p_statut IN boutique.statut%TYPE);

END pkg_utilisateur;
/
