CREATE OR REPLACE PACKAGE BODY pkg_avis AS

    FUNCTION a_recu_produit(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER) RETURN BOOLEAN IS
        v_nb PLS_INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_nb
          FROM commande c
          JOIN commande_ligne cl ON cl.id_commande = c.id
         WHERE c.id_client = p_id_utilisateur
           AND cl.id_produit = p_id_produit
           AND c.statut = 'LIVREE';
        RETURN v_nb > 0;
    END a_recu_produit;

    PROCEDURE deposer(
        p_id_utilisateur IN  NUMBER,
        p_id_produit     IN  NUMBER,
        p_note           IN  NUMBER,
        p_commentaire    IN  VARCHAR2,
        p_id             OUT NUMBER)
    IS
    BEGIN
        IF p_note IS NULL OR p_note NOT BETWEEN 1 AND 5 OR p_note <> TRUNC(p_note) THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'La note doit être un entier de 1 à 5.');
        END IF;
        IF NOT a_recu_produit(p_id_utilisateur, p_id_produit) THEN
            pkg_erreurs.lever(pkg_erreurs.c_avis_non_autorise,
                'Vous pourrez donner votre avis une fois le produit livré.');
        END IF;

        INSERT INTO avis (id_produit, id_utilisateur, note, commentaire)
        VALUES (p_id_produit, p_id_utilisateur, p_note, TRIM(p_commentaire))
        RETURNING id INTO p_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            pkg_erreurs.lever(pkg_erreurs.c_avis_non_autorise,
                'Vous avez déjà donné votre avis sur ce produit.');
    END deposer;

    PROCEDURE changer_statut(p_id_avis IN NUMBER, p_statut IN VARCHAR2) IS
    BEGIN
        IF p_statut NOT IN ('PUBLIE', 'MASQUE') THEN
            pkg_erreurs.lever(pkg_erreurs.c_donnee_invalide, 'Statut d''avis invalide : ' || p_statut);
        END IF;
        UPDATE avis SET statut = p_statut WHERE id = p_id_avis;
        IF SQL%ROWCOUNT = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_introuvable, 'Avis introuvable : ' || p_id_avis);
        END IF;
    END changer_statut;

    FUNCTION peut_donner_avis(p_id_utilisateur IN NUMBER, p_id_produit IN NUMBER) RETURN NUMBER IS
        v_deja PLS_INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_deja FROM avis
         WHERE id_utilisateur = p_id_utilisateur AND id_produit = p_id_produit;
        RETURN CASE WHEN v_deja = 0 AND a_recu_produit(p_id_utilisateur, p_id_produit) THEN 1 ELSE 0 END;
    END peut_donner_avis;

END pkg_avis;
/
