# Codes d'erreur métier

Les packages lèvent leurs erreurs avec `RAISE_APPLICATION_ERROR` (via `pkg_erreurs.lever`), dans la plage réservée `-20000 … -20999`. PHP lit le code (`oci_error()['code']`, positif : `20001`) et affiche un message lisible ; le message Oracle sert au journal de développement.

| Code | Constante (`PKG_ERREURS`) | Signification | Levée par |
|---|---|---|---|
| -20001 | `c_stock_insuffisant` | Stock insuffisant | `PKG_PANIER.ajouter`, `PKG_COMMANDE.passer_commande`, `PKG_CATALOGUE.ajuster_stock`, trigger `TRG_PRODUIT_STOCK_POSITIF` |
| -20002 | `c_transition_interdite` | Changement de statut interdit | `PKG_COMMANDE.changer_statut`, `PKG_MODERATION.traiter` |
| -20003 | `c_panier_vide` | Panier vide | `PKG_COMMANDE.passer_commande` |
| -20004 | `c_produit_indisponible` | Produit retiré de la vente ou boutique non validée | `PKG_PANIER`, `PKG_COMMANDE.passer_commande` |
| -20005 | `c_quantite_invalide` | Quantité nulle, négative ou non entière | `PKG_PANIER`, `PKG_CATALOGUE.creer_produit` |
| -20006 | `c_carte_refusee` | Numéro de carte (Luhn) ou CVV invalide | `PKG_PAIEMENT.verifier_carte` |
| -20007 | `c_carte_expiree` | Carte expirée | `PKG_PAIEMENT.verifier_carte` |
| -20008 | `c_email_deja_utilise` | Email déjà utilisé | `PKG_UTILISATEUR.creer_compte` |
| -20009 | `c_compte_introuvable` | Compte inexistant ou désactivé | `PKG_UTILISATEUR`, `PKG_COMMANDE`, `PKG_ANNONCE.publier` |
| -20010 | `c_avis_non_autorise` | Avis avant livraison, ou deuxième avis | `PKG_AVIS.deposer` |
| -20011 | `c_etat_annonce_invalide` | Action impossible dans l'état actuel de l'annonce | `PKG_ANNONCE`, `PKG_MESSAGERIE.ouvrir_conversation` |
| -20012 | `c_non_proprietaire` | Action réservée au propriétaire ou aux participants | `PKG_CATALOGUE`, `PKG_ANNONCE`, `PKG_MESSAGERIE` |
| -20013 | `c_conversation_invalide` | Se contacter soi-même, message vide ou trop long | `PKG_MESSAGERIE` |
| -20014 | `c_role_invalide` | Rôle inconnu ou non autorisé | `PKG_UTILISATEUR` |
| -20015 | `c_promotion_invalide` | Pourcentage, dates ou cible de promotion invalides | `PKG_CATALOGUE.creer_promotion` |
| -20016 | `c_annulation_impossible` | Commande déjà expédiée, livrée ou annulée | `PKG_COMMANDE.annuler` |
| -20017 | `c_donnee_invalide` | Donnée de formulaire invalide (champ vide, valeur hors liste…) | tous les packages |
| -20018 | `c_introuvable` | Élément inexistant (produit, commande, annonce…) | tous les packages |

Codes réservés aux outils : `-20990` (lecture de curseur dans `PKG_TEST`), `-20999` (code hors plage dans `pkg_erreurs.lever`, erreurs de compilation détectées par `installer.sh`).

## Intercepter une erreur en PL/SQL

```sql
BEGIN
    pkg_commande.passer_commande(...);
EXCEPTION
    WHEN pkg_erreurs.e_stock_insuffisant THEN
        -- exception nommée, associée à -20001 par PRAGMA EXCEPTION_INIT
        ...
END;
```
