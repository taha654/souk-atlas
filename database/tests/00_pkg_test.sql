-- =============================================================================
-- PKG_TEST : mini-framework de tests PL/SQL (installé par lancer_tests.sh)
--
-- Chaque vérification affiche une ligne :
--   OK     libellé
--   ÉCHEC  libellé — attendu : …, obtenu : …
-- puis fin() affiche le bilan de la suite.
--
-- Tester qu'une erreur est bien levée :
--   BEGIN
--       pkg_panier.ajouter(12, 24, 99);
--       pkg_test.echec('stock insuffisant refusé', 'aucune erreur levée');
--   EXCEPTION WHEN OTHERS THEN
--       pkg_test.verifier_erreur('stock insuffisant refusé', -20001, SQLCODE, SQLERRM);
--   END;
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_test AS

    PROCEDURE debut(p_suite IN VARCHAR2);
    PROCEDURE fin;

    PROCEDURE verifier(p_libelle IN VARCHAR2, p_condition IN BOOLEAN, p_detail IN VARCHAR2 DEFAULT NULL);
    -- Surcharge (overloading) : même nom, types de paramètres différents
    PROCEDURE verifier_egal(p_libelle IN VARCHAR2, p_attendu IN NUMBER,   p_obtenu IN NUMBER);
    PROCEDURE verifier_egal(p_libelle IN VARCHAR2, p_attendu IN VARCHAR2, p_obtenu IN VARCHAR2);
    PROCEDURE verifier_erreur(p_libelle IN VARCHAR2, p_code_attendu IN NUMBER,
                              p_code_obtenu IN NUMBER, p_message IN VARCHAR2 DEFAULT NULL);
    PROCEDURE echec(p_libelle IN VARCHAR2, p_detail IN VARCHAR2);

    -- Lecture générique d'un SYS_REFCURSOR, quelles que soient ses colonnes
    -- (grâce à DBMS_SQL). Chaque fonction consomme et ferme le curseur.
    FUNCTION nb_lignes(p_curseur IN OUT SYS_REFCURSOR) RETURN NUMBER;
    -- p_ligne = -1 : dernière ligne
    FUNCTION valeur(p_curseur IN OUT SYS_REFCURSOR, p_colonne IN VARCHAR2, p_ligne IN NUMBER DEFAULT 1)
        RETURN VARCHAR2;
    FUNCTION somme(p_curseur IN OUT SYS_REFCURSOR, p_colonne IN VARCHAR2) RETURN NUMBER;

END pkg_test;
/

CREATE OR REPLACE PACKAGE BODY pkg_test AS

    -- Variables de package : elles gardent leur valeur pendant toute la session
    g_suite  VARCHAR2(100);
    g_ok     PLS_INTEGER := 0;
    g_echecs PLS_INTEGER := 0;

    PROCEDURE debut(p_suite IN VARCHAR2) IS
    BEGIN
        g_suite := p_suite;
        g_ok := 0;
        g_echecs := 0;
        DBMS_OUTPUT.PUT_LINE('--- ' || p_suite);
    END debut;

    PROCEDURE fin IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('BILAN ' || g_suite || ' : ' || g_ok || ' OK, ' || g_echecs || ' ÉCHEC');
    END fin;

    PROCEDURE verifier(p_libelle IN VARCHAR2, p_condition IN BOOLEAN, p_detail IN VARCHAR2 DEFAULT NULL) IS
    BEGIN
        -- NVL : une condition NULL (comparaison avec NULL) compte comme un échec
        IF NVL(p_condition, FALSE) THEN
            g_ok := g_ok + 1;
            DBMS_OUTPUT.PUT_LINE('OK     ' || p_libelle);
        ELSE
            echec(p_libelle, p_detail);
        END IF;
    END verifier;

    PROCEDURE verifier_egal(p_libelle IN VARCHAR2, p_attendu IN NUMBER, p_obtenu IN NUMBER) IS
    BEGIN
        verifier(p_libelle, p_attendu = p_obtenu
                            OR (p_attendu IS NULL AND p_obtenu IS NULL),
                 'attendu : ' || NVL(TO_CHAR(p_attendu), 'NULL') || ', obtenu : ' || NVL(TO_CHAR(p_obtenu), 'NULL'));
    END verifier_egal;

    PROCEDURE verifier_egal(p_libelle IN VARCHAR2, p_attendu IN VARCHAR2, p_obtenu IN VARCHAR2) IS
    BEGIN
        verifier(p_libelle, p_attendu = p_obtenu
                            OR (p_attendu IS NULL AND p_obtenu IS NULL),
                 'attendu : ' || NVL(p_attendu, 'NULL') || ', obtenu : ' || NVL(p_obtenu, 'NULL'));
    END verifier_egal;

    PROCEDURE verifier_erreur(p_libelle IN VARCHAR2, p_code_attendu IN NUMBER,
                              p_code_obtenu IN NUMBER, p_message IN VARCHAR2 DEFAULT NULL) IS
    BEGIN
        verifier(p_libelle, p_code_attendu = p_code_obtenu,
                 'erreur attendue : ' || p_code_attendu || ', obtenue : ' || p_code_obtenu || ' ' || p_message);
    END verifier_erreur;

    PROCEDURE echec(p_libelle IN VARCHAR2, p_detail IN VARCHAR2) IS
    BEGIN
        g_echecs := g_echecs + 1;
        DBMS_OUTPUT.PUT_LINE('ÉCHEC  ' || p_libelle || CASE WHEN p_detail IS NOT NULL THEN ' — ' || p_detail END);
    END echec;

    -- ----- Lecture de curseurs -----

    -- Convertit le REF CURSOR en curseur DBMS_SQL et renvoie la position de la colonne
    FUNCTION ouvrir(p_curseur IN OUT SYS_REFCURSOR, p_colonne IN VARCHAR2, p_id OUT INTEGER) RETURN INTEGER IS
        v_nb_colonnes INTEGER;
        v_colonnes    DBMS_SQL.DESC_TAB;
    BEGIN
        p_id := DBMS_SQL.TO_CURSOR_NUMBER(p_curseur);
        IF p_colonne IS NULL THEN
            RETURN NULL;
        END IF;
        DBMS_SQL.DESCRIBE_COLUMNS(p_id, v_nb_colonnes, v_colonnes);
        FOR i IN 1 .. v_nb_colonnes LOOP
            IF v_colonnes(i).col_name = UPPER(p_colonne) THEN
                RETURN i;
            END IF;
        END LOOP;
        DBMS_SQL.CLOSE_CURSOR(p_id);
        RAISE_APPLICATION_ERROR(-20990, 'Colonne absente du curseur : ' || p_colonne);
    END ouvrir;

    FUNCTION nb_lignes(p_curseur IN OUT SYS_REFCURSOR) RETURN NUMBER IS
        v_id  INTEGER;
        v_pos INTEGER := ouvrir(p_curseur, NULL, v_id);
        v_nb  NUMBER := 0;
    BEGIN
        WHILE DBMS_SQL.FETCH_ROWS(v_id) > 0 LOOP
            v_nb := v_nb + 1;
        END LOOP;
        DBMS_SQL.CLOSE_CURSOR(v_id);
        RETURN v_nb;
    END nb_lignes;

    FUNCTION valeur(p_curseur IN OUT SYS_REFCURSOR, p_colonne IN VARCHAR2, p_ligne IN NUMBER DEFAULT 1)
        RETURN VARCHAR2
    IS
        v_id     INTEGER;
        v_pos    INTEGER := ouvrir(p_curseur, p_colonne, v_id);
        v_valeur VARCHAR2(4000);
        v_numero NUMBER := 0;
    BEGIN
        DBMS_SQL.DEFINE_COLUMN(v_id, v_pos, v_valeur, 4000);
        WHILE DBMS_SQL.FETCH_ROWS(v_id) > 0 LOOP
            v_numero := v_numero + 1;
            DBMS_SQL.COLUMN_VALUE(v_id, v_pos, v_valeur);
            EXIT WHEN v_numero = p_ligne;
        END LOOP;
        DBMS_SQL.CLOSE_CURSOR(v_id);
        RETURN CASE WHEN v_numero = p_ligne OR (p_ligne = -1 AND v_numero > 0) THEN v_valeur END;
    END valeur;

    FUNCTION somme(p_curseur IN OUT SYS_REFCURSOR, p_colonne IN VARCHAR2) RETURN NUMBER IS
        v_id     INTEGER;
        v_pos    INTEGER := ouvrir(p_curseur, p_colonne, v_id);
        v_valeur NUMBER;
        v_somme  NUMBER := 0;
    BEGIN
        DBMS_SQL.DEFINE_COLUMN(v_id, v_pos, v_valeur);
        WHILE DBMS_SQL.FETCH_ROWS(v_id) > 0 LOOP
            DBMS_SQL.COLUMN_VALUE(v_id, v_pos, v_valeur);
            v_somme := v_somme + NVL(v_valeur, 0);
        END LOOP;
        DBMS_SQL.CLOSE_CURSOR(v_id);
        RETURN v_somme;
    END somme;

END pkg_test;
/
