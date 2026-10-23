CREATE OR REPLACE PACKAGE BODY pkg_erreurs AS

    PROCEDURE lever(p_code IN PLS_INTEGER, p_message IN VARCHAR2) IS
    BEGIN
        -- Seule la plage -20000..-20999 est réservée aux erreurs applicatives
        IF p_code NOT BETWEEN -20999 AND -20000 THEN
            RAISE_APPLICATION_ERROR(-20999, 'Code d''erreur hors plage : ' || p_code);
        END IF;
        RAISE_APPLICATION_ERROR(p_code, p_message);
    END lever;

END pkg_erreurs;
/
