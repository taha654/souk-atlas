CREATE OR REPLACE PACKAGE BODY pkg_stats AS

    FUNCTION ca_par_jour(p_debut IN DATE, p_fin IN DATE, p_id_boutique IN NUMBER DEFAULT NULL)
        RETURN SYS_REFCURSOR
    IS
        v_curseur SYS_REFCURSOR;
    BEGIN
        OPEN v_curseur FOR
            -- "calendrier" : une ligne par jour de la période, générée avec
            -- CONNECT BY LEVEL sur DUAL (astuce classique d'Oracle)
            WITH calendrier AS (
                SELECT TRUNC(p_debut) + LEVEL - 1 AS jour
                  FROM dual
               CONNECT BY LEVEL <= TRUNC(p_fin) - TRUNC(p_debut) + 1
            ), ventes AS (
                SELECT TRUNC(date_commande) AS jour, COUNT(*) AS nb_commandes, SUM(total_ht) AS ca_ht
                  FROM commande
                 WHERE statut <> 'ANNULEE'
                   AND date_commande >= TRUNC(p_debut)
                   AND date_commande <  TRUNC(p_fin) + 1
                   AND (p_id_boutique IS NULL OR id_boutique = p_id_boutique)
                 GROUP BY TRUNC(date_commande)
            )
            SELECT c.jour,
                   NVL(v.nb_commandes, 0) AS nb_commandes,
                   NVL(v.ca_ht, 0)        AS ca_ht,
                   -- Somme glissante : du premier jour jusqu'au jour courant
                   SUM(NVL(v.ca_ht, 0)) OVER (ORDER BY c.jour) AS ca_cumule
              FROM calendrier c
              LEFT JOIN ventes v ON v.jour = c.jour
             ORDER BY c.jour;
        RETURN v_curseur;
    END ca_par_jour;

    FUNCTION ca_par_mois(p_annee IN NUMBER, p_id_boutique IN NUMBER DEFAULT NULL) RETURN SYS_REFCURSOR IS
        v_curseur SYS_REFCURSOR;
        v_debut   DATE := TO_DATE(p_annee || '-01-01', 'YYYY-MM-DD');
    BEGIN
        OPEN v_curseur FOR
            WITH mois AS (
                SELECT LEVEL AS mois FROM dual CONNECT BY LEVEL <= 12
            ), ventes AS (
                SELECT EXTRACT(MONTH FROM date_commande) AS mois,
                       COUNT(*) AS nb_commandes, SUM(total_ht) AS ca_ht
                  FROM commande
                 WHERE statut <> 'ANNULEE'
                   AND date_commande >= v_debut
                   AND date_commande <  ADD_MONTHS(v_debut, 12)
                   AND (p_id_boutique IS NULL OR id_boutique = p_id_boutique)
                 GROUP BY EXTRACT(MONTH FROM date_commande)
            ), mensuel AS (
                SELECT m.mois, NVL(v.nb_commandes, 0) AS nb_commandes, NVL(v.ca_ht, 0) AS ca_ht
                  FROM mois m LEFT JOIN ventes v ON v.mois = m.mois
            )
            SELECT mois, nb_commandes, ca_ht,
                   -- LAG lit la valeur de la ligne précédente (le mois d'avant) ;
                   -- NULLIF évite une division par zéro
                   ROUND(100 * (ca_ht - LAG(ca_ht) OVER (ORDER BY mois))
                             / NULLIF(LAG(ca_ht) OVER (ORDER BY mois), 0), 1) AS evolution_pct
              FROM mensuel
             ORDER BY mois;
        RETURN v_curseur;
    END ca_par_mois;

    FUNCTION ca_par_vendeur(p_debut IN DATE, p_fin IN DATE) RETURN SYS_REFCURSOR IS
        v_curseur SYS_REFCURSOR;
    BEGIN
        OPEN v_curseur FOR
            SELECT RANK() OVER (ORDER BY SUM(c.total_ht) DESC) AS rang,
                   b.id AS id_boutique, b.nom AS boutique,
                   COUNT(*) AS nb_commandes,
                   SUM(c.total_ht) AS ca_ht,
                   -- RATIO_TO_REPORT : part de chaque ligne dans le total de toutes les lignes
                   ROUND(100 * RATIO_TO_REPORT(SUM(c.total_ht)) OVER (), 1) AS part_pct
              FROM commande c
              JOIN boutique b ON b.id = c.id_boutique
             WHERE c.statut <> 'ANNULEE'
               AND c.date_commande >= TRUNC(p_debut)
               AND c.date_commande <  TRUNC(p_fin) + 1
             GROUP BY b.id, b.nom
             ORDER BY rang, b.nom;
        RETURN v_curseur;
    END ca_par_vendeur;

    FUNCTION meilleures_ventes(
        p_debut IN DATE, p_fin IN DATE, p_limite IN NUMBER DEFAULT 10, p_id_boutique IN NUMBER DEFAULT NULL)
        RETURN SYS_REFCURSOR
    IS
        v_curseur SYS_REFCURSOR;
    BEGIN
        -- Une fonction analytique ne peut pas apparaître dans le WHERE de sa
        -- propre requête : on la calcule dans une sous-requête, puis on filtre
        OPEN v_curseur FOR
            SELECT rang, id_produit, nom, quantite, ca_ht
              FROM (SELECT RANK() OVER (ORDER BY SUM(cl.quantite) DESC) AS rang,
                           cl.id_produit, p.nom,
                           SUM(cl.quantite) AS quantite,
                           SUM(cl.total_ligne_ht) AS ca_ht
                      FROM commande_ligne cl
                      JOIN commande c ON c.id = cl.id_commande
                      JOIN produit p  ON p.id = cl.id_produit
                     WHERE c.statut <> 'ANNULEE'
                       AND c.date_commande >= TRUNC(p_debut)
                       AND c.date_commande <  TRUNC(p_fin) + 1
                       AND (p_id_boutique IS NULL OR c.id_boutique = p_id_boutique)
                     GROUP BY cl.id_produit, p.nom)
             WHERE rang <= p_limite
             ORDER BY rang, nom;
        RETURN v_curseur;
    END meilleures_ventes;

    FUNCTION panier_moyen(p_debut IN DATE, p_fin IN DATE, p_id_boutique IN NUMBER DEFAULT NULL) RETURN NUMBER IS
        v_moyenne NUMBER;
    BEGIN
        -- AVG(SUM(...)) : agrégats imbriqués, propres à Oracle. On fait d'abord
        -- la somme par groupe (un achat), puis la moyenne de ces sommes.
        SELECT ROUND(AVG(SUM(total_ttc)), 2)
          INTO v_moyenne
          FROM commande
         WHERE statut <> 'ANNULEE'
           AND date_commande >= TRUNC(p_debut)
           AND date_commande <  TRUNC(p_fin) + 1
           AND (p_id_boutique IS NULL OR id_boutique = p_id_boutique)
         GROUP BY CASE WHEN p_id_boutique IS NULL THEN reference_achat ELSE numero END;
        RETURN NVL(v_moyenne, 0);
    END panier_moyen;

    PROCEDURE resume_boutique(
        p_id_boutique     IN  NUMBER,
        p_debut           IN  DATE,
        p_fin             IN  DATE,
        p_nb_commandes    OUT NUMBER,
        p_ca_ht           OUT NUMBER,
        p_panier_moyen    OUT NUMBER,
        p_articles_vendus OUT NUMBER)
    IS
        -- RECORD déclaré à la main : regroupe les résultats d'un SELECT … INTO
        TYPE t_resume IS RECORD (
            nb_commandes  NUMBER,
            ca_ht         NUMBER,
            ttc_moyen     NUMBER);
        v_resume t_resume;
    BEGIN
        SELECT COUNT(*), NVL(SUM(total_ht), 0), NVL(ROUND(AVG(total_ttc), 2), 0)
          INTO v_resume
          FROM commande
         WHERE id_boutique = p_id_boutique
           AND statut <> 'ANNULEE'
           AND date_commande >= TRUNC(p_debut)
           AND date_commande <  TRUNC(p_fin) + 1;

        SELECT NVL(SUM(cl.quantite), 0)
          INTO p_articles_vendus
          FROM commande_ligne cl
          JOIN commande c ON c.id = cl.id_commande
         WHERE c.id_boutique = p_id_boutique
           AND c.statut <> 'ANNULEE'
           AND c.date_commande >= TRUNC(p_debut)
           AND c.date_commande <  TRUNC(p_fin) + 1;

        p_nb_commandes := v_resume.nb_commandes;
        p_ca_ht        := v_resume.ca_ht;
        p_panier_moyen := v_resume.ttc_moyen;
    END resume_boutique;

END pkg_stats;
/
