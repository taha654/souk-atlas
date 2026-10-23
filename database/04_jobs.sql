-- =============================================================================
-- Souk Atlas : jobs planifiés (DBMS_SCHEDULER)
--
-- Contrairement aux procédures appelées par PHP, un job tourne dans sa propre
-- session, sans personne pour valider la transaction : son bloc PL/SQL se
-- termine donc par COMMIT.
--
-- Pas de "CREATE JOB IF NOT EXISTS" : on supprime d'abord les jobs existants
-- (script relançable sans erreur).
-- =============================================================================
BEGIN
    FOR j IN (SELECT job_name FROM user_scheduler_jobs
               WHERE job_name IN ('JOB_EXPIRATION_ANNONCES', 'JOB_FIN_PROMOTIONS', 'JOB_PURGE_PANIERS')) LOOP
        DBMS_SCHEDULER.DROP_JOB(j.job_name, force => TRUE);
    END LOOP;

    -- Toutes les heures : annonces en ligne depuis plus de 30 jours → EXPIREE
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_EXPIRATION_ANNONCES',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'DECLARE v_nb NUMBER; BEGIN pkg_annonce.expirer_annonces(v_nb); COMMIT; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=HOURLY; BYMINUTE=0',
        enabled         => TRUE,
        comments        => 'Expire les annonces dont la date d''expiration est dépassée');

    -- Chaque nuit à 00h05 : promotions terminées → actif = 0
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_FIN_PROMOTIONS',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'DECLARE v_nb NUMBER; BEGIN pkg_catalogue.desactiver_promotions_terminees(v_nb); COMMIT; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=5',
        enabled         => TRUE,
        comments        => 'Désactive les promotions dont la date de fin est passée');

    -- Chaque nuit à 03h00 : paniers non modifiés depuis 30 jours → supprimés
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_PURGE_PANIERS',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'DECLARE v_nb NUMBER; BEGIN pkg_panier.purger_paniers_abandonnes(30, v_nb); COMMIT; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=3; BYMINUTE=0',
        enabled         => TRUE,
        comments        => 'Supprime les paniers abandonnés depuis plus de 30 jours');
END;
/
