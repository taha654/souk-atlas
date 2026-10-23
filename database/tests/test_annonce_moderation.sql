-- Tests de PKG_ANNONCE et PKG_MODERATION
DECLARE
    c_auteur  CONSTANT NUMBER := 21;   -- Ghita, cliente
    c_autre   CONSTANT NUMBER := 22;   -- Adil, client
    v_id      NUMBER;
    v_id2     NUMBER;
    v_sig     NUMBER;
    v_nombre  NUMBER;
    v_texte   VARCHAR2(4000);
    v_date    DATE;
BEGIN
    pkg_test.debut('PKG_ANNONCE');

    -- ----- Publication -----
    pkg_annonce.publier(c_auteur, 30, 'Citroën C3 2018 essence', 'Très bon état, 70 000 km.',
                        95000, 'Rabat', NULL, v_id);
    SELECT statut, date_expiration INTO v_texte, v_date FROM annonce WHERE id = v_id;
    pkg_test.verifier_egal('publier sans score : directement EN_LIGNE', 'EN_LIGNE', v_texte);
    pkg_test.verifier_egal('publier : expiration dans 30 jours', 30, ROUND(v_date - SYSDATE));

    pkg_annonce.publier(c_auteur, 3, 'Téléphone neuf à moitié prix', 'Paiement par virement.',
                        500, 'Rabat', 75, v_id2);
    SELECT statut INTO v_texte FROM annonce WHERE id = v_id2;
    pkg_test.verifier_egal('publier score 75 : part EN_MODERATION', 'EN_MODERATION', v_texte);

    BEGIN
        pkg_annonce.publier(c_auteur, 3, 'Tél', 'Description', 100, 'Rabat', NULL, v_nombre);
        pkg_test.echec('publier : titre trop court refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('publier : titre trop court refusé', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_annonce.publier(c_auteur, 3, 'Téléphone usagé', 'Description', -1, 'Rabat', NULL, v_nombre);
        pkg_test.echec('publier : prix négatif refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('publier : prix négatif refusé', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_annonce.publier(25, 3, 'Téléphone usagé', 'Description', 100, 'Oujda', NULL, v_nombre);
        pkg_test.echec('publier : compte désactivé refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('publier : compte désactivé refusé', -20009, SQLCODE, SQLERRM);
    END;

    -- ----- Modération -----
    BEGIN
        pkg_annonce.moderer(v_id2, 'REFUSER', NULL);
        pkg_test.echec('moderer : refus sans motif refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('moderer : refus sans motif refusé', -20017, SQLCODE, SQLERRM);
    END;
    pkg_annonce.moderer(v_id2, 'APPROUVER');
    SELECT statut INTO v_texte FROM annonce WHERE id = v_id2;
    pkg_test.verifier_egal('moderer APPROUVER : EN_LIGNE', 'EN_LIGNE', v_texte);
    BEGIN
        pkg_annonce.moderer(v_id2, 'APPROUVER');
        pkg_test.echec('moderer : seulement une annonce EN_MODERATION', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('moderer : seulement une annonce EN_MODERATION', -20011, SQLCODE, SQLERRM);
    END;
    pkg_annonce.moderer(31, 'REFUSER', 'Arnaque probable');
    SELECT statut || '/' || motif_refus INTO v_texte FROM annonce WHERE id = 31;
    pkg_test.verifier_egal('moderer REFUSER : statut et motif', 'REFUSEE/Arnaque probable', v_texte);

    -- ----- Vente, renouvellement, expiration -----
    BEGIN
        pkg_annonce.marquer_vendue(v_id, c_autre);
        pkg_test.echec('marquer_vendue : réservé à l''auteur', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('marquer_vendue : réservé à l''auteur', -20012, SQLCODE, SQLERRM);
    END;
    pkg_annonce.marquer_vendue(v_id, c_auteur);
    SELECT statut INTO v_texte FROM annonce WHERE id = v_id;
    pkg_test.verifier_egal('marquer_vendue : VENDUE', 'VENDUE', v_texte);
    BEGIN
        pkg_annonce.renouveler(v_id, c_auteur);
        pkg_test.echec('renouveler : impossible pour une annonce vendue', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('renouveler : impossible pour une annonce vendue', -20011, SQLCODE, SQLERRM);
    END;

    -- Annonce publiée il y a 31 jours : le job doit l'expirer
    UPDATE annonce SET date_publication = SYSDATE - 31, date_expiration = SYSDATE - 1 WHERE id = v_id2;
    pkg_annonce.expirer_annonces(v_nombre);
    pkg_test.verifier('expirer_annonces : au moins une annonce expirée', v_nombre >= 1);
    SELECT statut INTO v_texte FROM annonce WHERE id = v_id2;
    pkg_test.verifier_egal('expirer_annonces : annonce de 31 jours EXPIREE', 'EXPIREE', v_texte);
    SELECT COUNT(*) INTO v_nombre FROM annonce WHERE statut = 'EN_LIGNE' AND date_expiration < SYSDATE;
    pkg_test.verifier_egal('expirer_annonces : plus aucune annonce en ligne périmée', 0, v_nombre);

    pkg_annonce.renouveler(v_id2, c_auteur);
    SELECT statut, date_expiration INTO v_texte, v_date FROM annonce WHERE id = v_id2;
    pkg_test.verifier_egal('renouveler : de nouveau EN_LIGNE', 'EN_LIGNE', v_texte);
    pkg_test.verifier_egal('renouveler : 30 jours de plus', 30, ROUND(v_date - SYSDATE));

    -- ----- Modification, recherche, photos -----
    pkg_annonce.modifier(v_id2, c_auteur, 3, 'Téléphone reconditionné', 'Bon état général.', 450, 'Rabat');
    SELECT titre || '/' || prix INTO v_texte FROM annonce WHERE id = v_id2;
    pkg_test.verifier_egal('modifier : titre et prix changés', 'Téléphone reconditionné/450', v_texte);
    BEGIN
        pkg_annonce.modifier(v_id2, c_autre, 3, 'Volée', 'x', 1, 'Rabat');
        pkg_test.echec('modifier : réservé à l''auteur', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('modifier : réservé à l''auteur', -20012, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_annonce.modifier(v_id, c_auteur, 30, 'Citroën C3 2018', 'x', 1, 'Rabat');   -- v_id est VENDUE
        pkg_test.echec('modifier : impossible pour une annonce vendue', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('modifier : impossible pour une annonce vendue', -20011, SQLCODE, SQLERRM);
    END;

    DECLARE
        v_curseur SYS_REFCURSOR;
    BEGIN
        v_curseur := pkg_annonce.rechercher(p_texte => 'TELEPHONE RECONDITIONNE');
        pkg_test.verifier_egal('rechercher : casse et accents ignorés', TO_CHAR(v_id2), pkg_test.valeur(v_curseur, 'id'));
        v_curseur := pkg_annonce.rechercher(p_ville => 'fes', p_taille_page => 100);
        SELECT COUNT(*) INTO v_nombre FROM annonce WHERE statut = 'EN_LIGNE' AND ville = 'Fès';
        pkg_test.verifier_egal('rechercher : "fes" trouve les annonces de Fès', v_nombre, pkg_test.nb_lignes(v_curseur));
        v_curseur := pkg_annonce.rechercher(p_id_categorie => 29, p_taille_page => 100);   -- Véhicules
        SELECT COUNT(*) INTO v_nombre FROM annonce WHERE statut = 'EN_LIGNE' AND id_categorie IN (30, 31);
        pkg_test.verifier_egal('rechercher : sous-catégories (voitures + motos)', v_nombre, pkg_test.nb_lignes(v_curseur));
        v_curseur := pkg_annonce.rechercher(p_texte => 'Citroën');                         -- vendue
        pkg_test.verifier_egal('rechercher : annonce vendue absente', 0, pkg_test.nb_lignes(v_curseur));
        v_curseur := pkg_annonce.rechercher(p_tri => 'prix_desc');
        SELECT MAX(prix) INTO v_nombre FROM annonce WHERE statut = 'EN_LIGNE';
        pkg_test.verifier_egal('rechercher : tri par prix décroissant', TO_CHAR(v_nombre), pkg_test.valeur(v_curseur, 'prix'));
    END;

    pkg_annonce.ajouter_photo(v_id2, c_auteur, '/uploads/annonces/a.jpg', v_nombre);
    pkg_annonce.ajouter_photo(v_id2, c_auteur, '/uploads/annonces/b.jpg', v_nombre);
    BEGIN
        pkg_annonce.ajouter_photo(v_id2, c_autre, '/uploads/annonces/c.jpg', v_nombre);
        pkg_test.echec('ajouter_photo : réservé à l''auteur', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('ajouter_photo : réservé à l''auteur', -20012, SQLCODE, SQLERRM);
    END;
    SELECT MIN(id) INTO v_nombre FROM annonce_photo WHERE id_annonce = v_id2;
    pkg_annonce.retirer_photo(v_nombre, c_auteur, v_texte);
    SELECT LISTAGG(ordre || ':' || chemin, ',') WITHIN GROUP (ORDER BY ordre) INTO v_texte
      FROM annonce_photo WHERE id_annonce = v_id2;
    pkg_test.verifier_egal('retirer_photo : la restante renumérotée', '1:/uploads/annonces/b.jpg', v_texte);

    -- ----- Favoris -----
    pkg_annonce.ajouter_favori(c_autre, v_id2);
    pkg_annonce.ajouter_favori(c_autre, v_id2);   -- deux fois : pas d'erreur
    SELECT COUNT(*) INTO v_nombre FROM favori WHERE id_utilisateur = c_autre AND id_annonce = v_id2;
    pkg_test.verifier_egal('ajouter_favori : une seule ligne même si ajouté deux fois', 1, v_nombre);
    pkg_annonce.retirer_favori(c_autre, v_id2);
    SELECT COUNT(*) INTO v_nombre FROM favori WHERE id_utilisateur = c_autre AND id_annonce = v_id2;
    pkg_test.verifier_egal('retirer_favori : supprimé', 0, v_nombre);

    pkg_test.fin;

    -- -------------------------------------------------------------------------
    pkg_test.debut('PKG_MODERATION');

    pkg_moderation.signaler(c_autre, 'ANNONCE', v_id2, 'ARNAQUE', 'Prix suspect', v_sig);
    pkg_moderation.signaler(23, 'ANNONCE', v_id2, 'ARNAQUE', NULL, v_nombre);
    BEGIN
        pkg_moderation.signaler(c_autre, 'ANNONCE', v_id2, 'ARNAQUE', 'Encore', v_nombre);
        pkg_test.echec('signaler : deux fois le même contenu refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('signaler : deux fois le même contenu refusé', -20017, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_moderation.signaler(c_autre, 'ANNONCE', 999999, 'ARNAQUE', NULL, v_nombre);
        pkg_test.echec('signaler : annonce inexistante (ORA-02291 traduite)', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('signaler : annonce inexistante (ORA-02291 traduite)', -20018, SQLCODE, SQLERRM);
    END;
    BEGIN
        pkg_moderation.signaler(c_autre, 'VENDEUR', 2, 'ARNAQUE', NULL, v_nombre);
        pkg_test.echec('signaler : type de cible inconnu refusé', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('signaler : type de cible inconnu refusé', -20017, SQLCODE, SQLERRM);
    END;

    pkg_moderation.traiter(v_sig, 1, 'APPROUVER');
    SELECT statut INTO v_texte FROM annonce WHERE id = v_id2;
    pkg_test.verifier_egal('traiter APPROUVER : l''annonce est retirée', 'REFUSEE', v_texte);
    SELECT COUNT(*) INTO v_nombre FROM signalement WHERE id_annonce = v_id2 AND statut = 'OUVERT';
    pkg_test.verifier_egal('traiter : tous les signalements de la cible sont clos', 0, v_nombre);
    SELECT COUNT(*) INTO v_nombre FROM signalement WHERE id_annonce = v_id2 AND id_moderateur = 1;
    pkg_test.verifier_egal('traiter : le modérateur est enregistré', 2, v_nombre);
    BEGIN
        pkg_moderation.traiter(v_sig, 1, 'REJETER');
        pkg_test.echec('traiter : déjà traité', 'aucune erreur levée');
    EXCEPTION WHEN OTHERS THEN
        pkg_test.verifier_erreur('traiter : déjà traité', -20002, SQLCODE, SQLERRM);
    END;

    -- Signalement d'un avis approuvé : l'avis est masqué
    SELECT MIN(id) INTO v_id FROM avis WHERE statut = 'PUBLIE';
    pkg_moderation.signaler(c_autre, 'AVIS', v_id, 'INAPPROPRIE', NULL, v_sig);
    pkg_moderation.traiter(v_sig, 1, 'APPROUVER');
    SELECT statut INTO v_texte FROM avis WHERE id = v_id;
    pkg_test.verifier_egal('traiter APPROUVER sur un avis : MASQUE', 'MASQUE', v_texte);

    -- Signalement d'un produit rejeté : rien ne change
    pkg_moderation.signaler(c_autre, 'PRODUIT', 26, 'CONTREFACON', NULL, v_sig);
    pkg_moderation.traiter(v_sig, 1, 'REJETER');
    SELECT statut INTO v_texte FROM produit WHERE id = 26;
    pkg_test.verifier_egal('traiter REJETER sur un produit : il reste ACTIF', 'ACTIF', v_texte);

    pkg_test.fin;
END;
/
ROLLBACK;
