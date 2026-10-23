-- Tests des jobs DBMS_SCHEDULER.
-- ATTENTION : ce fichier exécute RÉELLEMENT les trois jobs de maintenance
-- (leur bloc se termine par COMMIT). Ils font exactement ce qu'ils feraient
-- à leur prochaine heure planifiée : expirer, désactiver, purger.
DECLARE
    v_nombre NUMBER;
    v_texte  VARCHAR2(4000);
BEGIN
    pkg_test.debut('JOBS DBMS_SCHEDULER');

    FOR j IN (SELECT 'JOB_EXPIRATION_ANNONCES' AS nom FROM dual
              UNION ALL SELECT 'JOB_FIN_PROMOTIONS' FROM dual
              UNION ALL SELECT 'JOB_PURGE_PANIERS' FROM dual) LOOP
        SELECT MAX(enabled || '/' || state) INTO v_texte FROM user_scheduler_jobs WHERE job_name = j.nom;
        pkg_test.verifier_egal(j.nom || ' : planifié et actif', 'TRUE/SCHEDULED', v_texte);
    END LOOP;

    -- use_current_session => TRUE : le job tourne ici, tout de suite, et une
    -- éventuelle erreur remonte dans ce bloc
    DBMS_SCHEDULER.RUN_JOB('JOB_EXPIRATION_ANNONCES', use_current_session => TRUE);
    SELECT COUNT(*) INTO v_nombre FROM annonce WHERE statut = 'EN_LIGNE' AND date_expiration < SYSDATE;
    pkg_test.verifier_egal('JOB_EXPIRATION_ANNONCES : plus aucune annonce périmée en ligne', 0, v_nombre);

    DBMS_SCHEDULER.RUN_JOB('JOB_FIN_PROMOTIONS', use_current_session => TRUE);
    SELECT COUNT(*) INTO v_nombre FROM promotion WHERE actif = 1 AND date_fin < SYSDATE;
    pkg_test.verifier_egal('JOB_FIN_PROMOTIONS : plus aucune promotion terminée active', 0, v_nombre);
    SELECT actif INTO v_nombre FROM promotion WHERE libelle = 'Soldes d''été';
    pkg_test.verifier_egal('JOB_FIN_PROMOTIONS : les « Soldes d''été » sont désactivées', 0, v_nombre);

    DBMS_SCHEDULER.RUN_JOB('JOB_PURGE_PANIERS', use_current_session => TRUE);
    SELECT COUNT(*) INTO v_nombre FROM panier WHERE date_maj < SYSDATE - 30;
    pkg_test.verifier_egal('JOB_PURGE_PANIERS : plus aucun panier abandonné', 0, v_nombre);

    pkg_test.fin;
END;
/
