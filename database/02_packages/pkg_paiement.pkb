CREATE OR REPLACE PACKAGE BODY pkg_paiement AS

    -- Retire espaces et tirets : "4111 1111-1111 1111" → "4111111111111111"
    FUNCTION nettoyer(p_numero IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN REGEXP_REPLACE(p_numero, '[ -]', '');
    END nettoyer;

    FUNCTION luhn_valide(p_numero IN VARCHAR2) RETURN NUMBER IS
        v_numero  VARCHAR2(30) := nettoyer(p_numero);
        v_somme   PLS_INTEGER := 0;
        v_chiffre PLS_INTEGER;
        v_double  BOOLEAN := FALSE;  -- BOOLEAN est permis en PL/SQL, même en 19c
    BEGIN
        IF v_numero IS NULL OR NOT REGEXP_LIKE(v_numero, '^[0-9]{13,19}$') THEN
            RETURN 0;
        END IF;

        -- On parcourt les chiffres de DROITE à GAUCHE ; un chiffre sur deux est
        -- doublé (si le double dépasse 9, on retire 9). Le numéro est valide si
        -- la somme est un multiple de 10.
        FOR i IN REVERSE 1 .. LENGTH(v_numero) LOOP
            v_chiffre := TO_NUMBER(SUBSTR(v_numero, i, 1));
            IF v_double THEN
                v_chiffre := v_chiffre * 2;
                IF v_chiffre > 9 THEN
                    v_chiffre := v_chiffre - 9;
                END IF;
            END IF;
            v_somme  := v_somme + v_chiffre;
            v_double := NOT v_double;
        END LOOP;

        RETURN CASE WHEN MOD(v_somme, 10) = 0 THEN 1 ELSE 0 END;
    END luhn_valide;

    FUNCTION carte_expiree(p_mois IN NUMBER, p_annee IN NUMBER) RETURN NUMBER IS
        v_fin_validite DATE;
    BEGIN
        -- Attention à NULL : "NULL NOT BETWEEN 1 AND 12" ne vaut pas TRUE mais NULL,
        -- d'où les tests IS NULL explicites
        IF p_mois IS NULL OR p_annee IS NULL OR p_mois NOT BETWEEN 1 AND 12 THEN
            RETURN 1;
        END IF;
        -- LAST_DAY : dernier jour du mois ; la carte est valable jusqu'à 23:59:59
        v_fin_validite := LAST_DAY(TO_DATE(p_annee || '-' || p_mois || '-01', 'YYYY-MM-DD')) + 1;
        RETURN CASE WHEN SYSDATE >= v_fin_validite THEN 1 ELSE 0 END;
    END carte_expiree;

    PROCEDURE verifier_carte(
        p_numero IN VARCHAR2, p_mois IN NUMBER, p_annee IN NUMBER, p_cvv IN VARCHAR2) IS
    BEGIN
        IF luhn_valide(p_numero) = 0 THEN
            pkg_erreurs.lever(pkg_erreurs.c_carte_refusee, 'Numéro de carte invalide.');
        END IF;
        IF p_cvv IS NULL OR NOT REGEXP_LIKE(p_cvv, '^[0-9]{3}$') THEN
            pkg_erreurs.lever(pkg_erreurs.c_carte_refusee, 'Le cryptogramme (CVV) doit comporter 3 chiffres.');
        END IF;
        IF carte_expiree(p_mois, p_annee) = 1 THEN
            pkg_erreurs.lever(pkg_erreurs.c_carte_expiree, 'Carte expirée.');
        END IF;
    END verifier_carte;

    PROCEDURE enregistrer_carte(p_id_commande IN NUMBER, p_numero IN VARCHAR2, p_montant IN NUMBER) IS
        -- Calculé en PL/SQL : NETTOYER est privée (absente de la spécification),
        -- elle n'est donc pas appelable à l'intérieur d'un ordre SQL (PLS-00231)
        v_4_derniers CHAR(4) := SUBSTR(nettoyer(p_numero), -4);
    BEGIN
        -- Seuls les 4 derniers chiffres sont conservés ; le numéro complet et le
        -- CVV ne sont écrits nulle part
        INSERT INTO paiement (id_commande, mode_paiement, montant, statut, carte_4_derniers)
        VALUES (p_id_commande, 'CARTE', p_montant, 'ACCEPTE', v_4_derniers);
    END enregistrer_carte;

    PROCEDURE enregistrer_livraison(p_id_commande IN NUMBER, p_montant IN NUMBER) IS
    BEGIN
        INSERT INTO paiement (id_commande, mode_paiement, montant, statut)
        VALUES (p_id_commande, 'LIVRAISON', p_montant, 'EN_ATTENTE');
    END enregistrer_livraison;

    PROCEDURE confirmer_livraison(p_id_commande IN NUMBER) IS
    BEGIN
        UPDATE paiement SET statut = 'ACCEPTE', date_paiement = SYSDATE
         WHERE id_commande = p_id_commande AND mode_paiement = 'LIVRAISON' AND statut = 'EN_ATTENTE';
    END confirmer_livraison;

    PROCEDURE rembourser(p_id_commande IN NUMBER) IS
    BEGIN
        UPDATE paiement SET statut = 'REMBOURSE'
         WHERE id_commande = p_id_commande AND statut = 'ACCEPTE';
    END rembourser;

END pkg_paiement;
/
