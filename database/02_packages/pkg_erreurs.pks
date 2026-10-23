-- =============================================================================
-- PKG_ERREURS : codes des erreurs métier (tableau complet : database/codes_erreurs.md)
--
-- Chaque code a :
--   * une constante (c_...) pour LEVER l'erreur : pkg_erreurs.lever(pkg_erreurs.c_stock_insuffisant, '...')
--   * une exception nommée (e_...) pour l'INTERCEPTER : EXCEPTION WHEN pkg_erreurs.e_stock_insuffisant THEN ...
-- PRAGMA EXCEPTION_INIT associe le nom au numéro ; il exige un littéral, d'où la répétition.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_erreurs AS

    c_stock_insuffisant      CONSTANT PLS_INTEGER := -20001;
    c_transition_interdite   CONSTANT PLS_INTEGER := -20002;
    c_panier_vide            CONSTANT PLS_INTEGER := -20003;
    c_produit_indisponible   CONSTANT PLS_INTEGER := -20004;
    c_quantite_invalide      CONSTANT PLS_INTEGER := -20005;
    c_carte_refusee          CONSTANT PLS_INTEGER := -20006;
    c_carte_expiree          CONSTANT PLS_INTEGER := -20007;
    c_email_deja_utilise     CONSTANT PLS_INTEGER := -20008;
    c_compte_introuvable     CONSTANT PLS_INTEGER := -20009;
    c_avis_non_autorise      CONSTANT PLS_INTEGER := -20010;
    c_etat_annonce_invalide  CONSTANT PLS_INTEGER := -20011;
    c_non_proprietaire       CONSTANT PLS_INTEGER := -20012;
    c_conversation_invalide  CONSTANT PLS_INTEGER := -20013;
    c_role_invalide          CONSTANT PLS_INTEGER := -20014;
    c_promotion_invalide     CONSTANT PLS_INTEGER := -20015;
    c_annulation_impossible  CONSTANT PLS_INTEGER := -20016;
    c_donnee_invalide        CONSTANT PLS_INTEGER := -20017;
    c_introuvable            CONSTANT PLS_INTEGER := -20018;

    e_stock_insuffisant      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_stock_insuffisant,     -20001);
    e_transition_interdite   EXCEPTION;  PRAGMA EXCEPTION_INIT(e_transition_interdite,  -20002);
    e_panier_vide            EXCEPTION;  PRAGMA EXCEPTION_INIT(e_panier_vide,           -20003);
    e_produit_indisponible   EXCEPTION;  PRAGMA EXCEPTION_INIT(e_produit_indisponible,  -20004);
    e_quantite_invalide      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_quantite_invalide,     -20005);
    e_carte_refusee          EXCEPTION;  PRAGMA EXCEPTION_INIT(e_carte_refusee,         -20006);
    e_carte_expiree          EXCEPTION;  PRAGMA EXCEPTION_INIT(e_carte_expiree,         -20007);
    e_email_deja_utilise     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_email_deja_utilise,    -20008);
    e_compte_introuvable     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_compte_introuvable,    -20009);
    e_avis_non_autorise      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_avis_non_autorise,     -20010);
    e_etat_annonce_invalide  EXCEPTION;  PRAGMA EXCEPTION_INIT(e_etat_annonce_invalide, -20011);
    e_non_proprietaire       EXCEPTION;  PRAGMA EXCEPTION_INIT(e_non_proprietaire,      -20012);
    e_conversation_invalide  EXCEPTION;  PRAGMA EXCEPTION_INIT(e_conversation_invalide, -20013);
    e_role_invalide          EXCEPTION;  PRAGMA EXCEPTION_INIT(e_role_invalide,         -20014);
    e_promotion_invalide     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_promotion_invalide,    -20015);
    e_annulation_impossible  EXCEPTION;  PRAGMA EXCEPTION_INIT(e_annulation_impossible, -20016);
    e_donnee_invalide        EXCEPTION;  PRAGMA EXCEPTION_INIT(e_donnee_invalide,       -20017);
    e_introuvable            EXCEPTION;  PRAGMA EXCEPTION_INIT(e_introuvable,           -20018);

    -- Lève l'erreur métier p_code avec un message lisible (affiché par PHP)
    PROCEDURE lever(p_code IN PLS_INTEGER, p_message IN VARCHAR2);

END pkg_erreurs;
/
