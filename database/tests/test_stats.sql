-- Tests de PKG_STATS : chaque résultat est comparé à une requête "naïve" directe
DECLARE
    v_debut    DATE := TRUNC(SYSDATE) - 29;
    v_fin      DATE := TRUNC(SYSDATE);
    v_curseur  SYS_REFCURSOR;
    v_attendu  NUMBER;
    v_obtenu   NUMBER;
    v_nb       NUMBER;
    v_ca       NUMBER;
    v_moyen    NUMBER;
    v_articles NUMBER;
BEGIN
    pkg_test.debut('PKG_STATS');

    SELECT NVL(SUM(total_ht), 0) INTO v_attendu FROM commande
     WHERE statut <> 'ANNULEE' AND date_commande >= v_debut AND date_commande < v_fin + 1;
    pkg_test.verifier('données : des ventes sur les 30 derniers jours', v_attendu > 0);

    v_curseur := pkg_stats.ca_par_jour(v_debut, v_fin);
    pkg_test.verifier_egal('ca_par_jour : 30 lignes, jours sans vente compris', 30, pkg_test.nb_lignes(v_curseur));
    v_curseur := pkg_stats.ca_par_jour(v_debut, v_fin);
    pkg_test.verifier_egal('ca_par_jour : somme = CA de la période', v_attendu, pkg_test.somme(v_curseur, 'ca_ht'));
    v_curseur := pkg_stats.ca_par_jour(v_debut, v_fin);
    pkg_test.verifier_egal('ca_par_jour : le cumul final = CA de la période', TO_CHAR(v_attendu),
                           pkg_test.valeur(v_curseur, 'ca_cumule', -1));

    v_curseur := pkg_stats.ca_par_mois(EXTRACT(YEAR FROM SYSDATE));
    pkg_test.verifier_egal('ca_par_mois : 12 mois', 12, pkg_test.nb_lignes(v_curseur));
    SELECT NVL(SUM(total_ht), 0) INTO v_attendu FROM commande
     WHERE statut <> 'ANNULEE' AND EXTRACT(YEAR FROM date_commande) = EXTRACT(YEAR FROM SYSDATE);
    v_curseur := pkg_stats.ca_par_mois(EXTRACT(YEAR FROM SYSDATE));
    pkg_test.verifier_egal('ca_par_mois : somme = CA de l''année', v_attendu, pkg_test.somme(v_curseur, 'ca_ht'));

    v_curseur := pkg_stats.ca_par_vendeur(SYSDATE - 365, SYSDATE);
    v_obtenu := pkg_test.somme(v_curseur, 'part_pct');
    pkg_test.verifier('ca_par_vendeur : les parts font 100 % (à l''arrondi près)', ABS(v_obtenu - 100) <= 0.5,
                      'somme des parts : ' || v_obtenu);
    SELECT MAX(SUM(total_ht)) INTO v_attendu FROM commande
     WHERE statut <> 'ANNULEE' AND date_commande >= TRUNC(SYSDATE - 365) GROUP BY id_boutique;
    v_curseur := pkg_stats.ca_par_vendeur(SYSDATE - 365, SYSDATE);
    pkg_test.verifier_egal('ca_par_vendeur : le rang 1 a le plus gros CA', TO_CHAR(v_attendu),
                           pkg_test.valeur(v_curseur, 'ca_ht'));

    v_curseur := pkg_stats.meilleures_ventes(SYSDATE - 365, SYSDATE, 5);
    pkg_test.verifier('meilleures_ventes : au moins 5 lignes (ex aequo possibles)', pkg_test.nb_lignes(v_curseur) >= 5);
    SELECT MAX(SUM(cl.quantite)) INTO v_attendu
      FROM commande_ligne cl JOIN commande c ON c.id = cl.id_commande
     WHERE c.statut <> 'ANNULEE' AND c.date_commande >= TRUNC(SYSDATE - 365) GROUP BY cl.id_produit;
    v_curseur := pkg_stats.meilleures_ventes(SYSDATE - 365, SYSDATE, 5);
    pkg_test.verifier_egal('meilleures_ventes : le n°1 a la plus grosse quantité', TO_CHAR(v_attendu),
                           pkg_test.valeur(v_curseur, 'quantite'));

    SELECT ROUND(AVG(total_achat), 2) INTO v_attendu
      FROM (SELECT SUM(total_ttc) AS total_achat FROM commande
             WHERE statut <> 'ANNULEE' AND date_commande >= v_debut AND date_commande < v_fin + 1
             GROUP BY reference_achat);
    pkg_test.verifier_egal('panier_moyen : moyenne des achats TTC', v_attendu, pkg_stats.panier_moyen(v_debut, v_fin));
    pkg_test.verifier_egal('panier_moyen : 0 sur une période sans vente', 0,
                           pkg_stats.panier_moyen(DATE '2000-01-01', DATE '2000-01-31'));

    pkg_stats.resume_boutique(1, SYSDATE - 365, SYSDATE, v_nb, v_ca, v_moyen, v_articles);
    SELECT COUNT(*) INTO v_attendu FROM commande
     WHERE id_boutique = 1 AND statut <> 'ANNULEE' AND date_commande >= TRUNC(SYSDATE - 365);
    pkg_test.verifier_egal('resume_boutique : nombre de commandes', v_attendu, v_nb);
    SELECT SUM(total_ht) INTO v_attendu FROM commande
     WHERE id_boutique = 1 AND statut <> 'ANNULEE' AND date_commande >= TRUNC(SYSDATE - 365);
    pkg_test.verifier_egal('resume_boutique : chiffre d''affaires', v_attendu, v_ca);
    pkg_test.verifier('resume_boutique : articles vendus >= commandes', v_articles >= v_nb);

    pkg_test.fin;
END;
/
ROLLBACK;
