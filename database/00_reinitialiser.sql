-- =============================================================================
-- Supprime TOUS les objets du schéma courant (SOUK) : jobs, tables, packages…
-- À n'utiliser qu'en développement : les données de démonstration sont perdues.
-- Lancé par "installer.sh --reinitialiser".
--
-- Avant 23ai, "DROP TABLE IF EXISTS" n'existe pas : on parcourt le dictionnaire
-- (USER_OBJECTS) et on exécute chaque DROP en SQL dynamique.
-- =============================================================================
SET SERVEROUTPUT ON

DECLARE
    v_nb PLS_INTEGER := 0;
BEGIN
    -- 1. Les jobs DBMS_SCHEDULER ne se suppriment pas avec DROP
    FOR j IN (SELECT job_name FROM user_scheduler_jobs) LOOP
        DBMS_SCHEDULER.DROP_JOB(j.job_name, force => TRUE);
        v_nb := v_nb + 1;
    END LOOP;

    -- 2. Les tables (CASCADE CONSTRAINTS évite de devoir respecter l'ordre des FK ;
    --    PURGE évite de remplir la corbeille d'Oracle)
    FOR t IN (SELECT table_name FROM user_tables) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE "' || t.table_name || '" CASCADE CONSTRAINTS PURGE';
        v_nb := v_nb + 1;
    END LOOP;

    -- 3. Le reste (les corps de package partent avec leur spécification)
    FOR o IN (SELECT object_name, object_type
                FROM user_objects
               WHERE object_type IN ('PACKAGE', 'PROCEDURE', 'FUNCTION', 'SEQUENCE',
                                     'VIEW', 'TYPE', 'TRIGGER', 'SYNONYM')
                 -- Les séquences des colonnes IDENTITY partent avec leur table
                 AND object_name NOT LIKE 'ISEQ$$%') LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' "' || o.object_name || '"'
                          || CASE o.object_type WHEN 'TYPE' THEN ' FORCE' END;
        v_nb := v_nb + 1;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_nb || ' objet(s) supprimé(s).');
END;
/
