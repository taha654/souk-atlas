<?php
declare(strict_types=1);

// Table des routes : méthode + URL → Contrôleur@action.
// Le contrôle des rôles se fait DANS chaque action (Auth::exigerRole).

use App\Core\Router;

return static function (Router $router): void {
    $router->get('/', 'AccueilController@index');

    $router->get('/inscription', 'AuthController@formulaireInscription');
    $router->post('/inscription', 'AuthController@inscrire');
    $router->get('/connexion', 'AuthController@formulaireConnexion');
    $router->post('/connexion', 'AuthController@connecter');
    $router->post('/deconnexion', 'AuthController@deconnecter');

    $router->get('/compte', 'CompteController@index');
    $router->get('/compte/jetons', 'CompteController@jetons');
    $router->post('/compte/jetons', 'CompteController@creerJeton');
    $router->post('/compte/jetons/{id}/revoquer', 'CompteController@revoquerJeton');

    // API de l'outil console C++ : authentification par jeton (Authorization: Bearer)
    $router->get('/api/console/moi', 'Api\\ConsoleApiController@moi');
    $router->get('/api/console/categories', 'Api\\ConsoleApiController@categories');
    $router->post('/api/console/produits', 'Api\\ConsoleApiController@importerProduits');
    $router->get('/api/console/signalements', 'Api\\ConsoleApiController@signalements');
    $router->post('/api/console/signalements/{id}', 'Api\\ConsoleApiController@traiterSignalement');
    $router->get('/api/console/rapport', 'Api\\ConsoleApiController@rapport');
    // Espace vendeur (Auth::exigerRole('VENDEUR') dans chaque action)
    $router->get('/vendeur', 'VendeurController@index');
    $router->get('/vendeur/boutique', 'VendeurController@formulaireBoutique');
    $router->post('/vendeur/boutique', 'VendeurController@enregistrerBoutique');
    $router->get('/vendeur/produits', 'VendeurController@produits');
    $router->get('/vendeur/produits/nouveau', 'VendeurController@nouveauProduit');   // avant {id}
    $router->post('/vendeur/produits', 'VendeurController@creerProduit');
    $router->get('/vendeur/produits/{id}', 'VendeurController@produit');
    $router->post('/vendeur/produits/{id}', 'VendeurController@modifierProduit');
    $router->post('/vendeur/produits/{id}/stock', 'VendeurController@ajusterStock');
    $router->post('/vendeur/produits/{id}/photos', 'VendeurController@ajouterPhoto');
    $router->post('/vendeur/produits/{id}/photos/{photo}/supprimer', 'VendeurController@supprimerPhoto');
    $router->get('/vendeur/commandes', 'VendeurController@commandes');
    $router->get('/vendeur/commandes/{numero}', 'VendeurController@commande');
    $router->post('/vendeur/commandes/{numero}/statut', 'VendeurController@changerStatutCommande');
    $router->get('/api/vendeur/statistiques', 'Api\\StatistiquesApiController@vendeur');
    // Espace administrateur (Auth::exigerRole('ADMIN') dans chaque action)
    $router->get('/admin', 'AdminController@index');
    $router->get('/api/admin/statistiques', 'AdminController@apiStatistiques');
    $router->get('/admin/moderation', 'AdminController@moderation');
    $router->post('/admin/annonces/{id}/moderer', 'AdminController@modererAnnonce');
    $router->get('/admin/signalements', 'AdminController@signalements');
    $router->get('/admin/signalements/{id}', 'AdminController@signalement');
    $router->post('/admin/signalements/{id}/traiter', 'AdminController@traiterSignalement');
    $router->get('/admin/avis', 'AdminController@avis');
    $router->post('/admin/avis/{id}/statut', 'AdminController@statutAvis');
    $router->get('/admin/boutiques', 'AdminController@boutiques');
    $router->post('/admin/boutiques/{id}/statut', 'AdminController@statutBoutique');
    $router->get('/admin/utilisateurs', 'AdminController@utilisateurs');
    $router->post('/admin/utilisateurs/{id}', 'AdminController@modifierUtilisateur');
    $router->get('/admin/categories', 'AdminController@categories');
    $router->post('/admin/categories', 'AdminController@creerCategorie');
    $router->post('/admin/categories/{id}', 'AdminController@renommerCategorie');
    $router->post('/admin/categories/{id}/supprimer', 'AdminController@supprimerCategorie');
    $router->get('/admin/promotions', 'AdminController@promotions');
    $router->post('/admin/promotions', 'AdminController@creerPromotion');
    $router->post('/admin/promotions/{id}/desactiver', 'AdminController@desactiverPromotion');
    $router->get('/admin/journal', 'AdminController@journal');
    $router->post('/admin/recommandations', 'AdminController@recalculerRecommandations');

    // Catalogue
    $router->get('/catalogue', 'CatalogueController@index');
    $router->get('/produit/{id}', 'ProduitController@fiche');

    // Panier (fonctionne sans JavaScript)
    $router->get('/panier', 'PanierController@index');
    $router->post('/panier/ajouter', 'PanierController@ajouter');
    $router->post('/panier/modifier', 'PanierController@modifier');
    $router->post('/panier/retirer', 'PanierController@retirer');

    // Commande, suivi, facture, avis
    $router->get('/commande', 'CommandeController@formulaire');
    $router->post('/commande', 'CommandeController@passer');
    $router->get('/achat/{reference}', 'CommandeController@achat');
    $router->get('/achat/{reference}/facture', 'CommandeController@facture');
    $router->get('/mes-commandes', 'CommandeController@liste');
    $router->get('/commande/{numero}', 'CommandeController@detail');
    $router->post('/commande/{numero}/annuler', 'CommandeController@annuler');
    $router->post('/produit/{id}/avis', 'AvisController@deposer');

    // Petites annonces
    $router->get('/annonces', 'AnnonceController@index');
    $router->get('/annonces/nouvelle', 'AnnonceController@nouvelle');
    $router->post('/annonces', 'AnnonceController@publier');
    $router->get('/annonce/{id}', 'AnnonceController@fiche');
    $router->post('/annonce/{id}/favori', 'AnnonceController@basculerFavori');
    $router->post('/annonce/{id}/contacter', 'AnnonceController@contacter');
    $router->post('/annonce/{id}/signaler', 'AnnonceController@signaler');
    $router->get('/mes-annonces', 'AnnonceController@mesAnnonces');
    $router->get('/mes-annonces/{id}', 'AnnonceController@edition');
    $router->post('/mes-annonces/{id}', 'AnnonceController@modifier');
    $router->post('/mes-annonces/{id}/photos', 'AnnonceController@ajouterPhoto');
    $router->post('/mes-annonces/{id}/photos/{photo}/supprimer', 'AnnonceController@supprimerPhoto');
    $router->post('/mes-annonces/{id}/{action}', 'AnnonceController@action');
    $router->get('/favoris', 'AnnonceController@favoris');

    // Messagerie
    $router->get('/messages', 'MessagerieController@index');
    $router->get('/messages/{id}', 'MessagerieController@conversation');
    $router->post('/messages/{id}', 'MessagerieController@envoyer');
    $router->get('/api/messages/{id}', 'MessagerieController@apiNouveaux');
    $router->post('/api/messages/{id}', 'MessagerieController@apiEnvoyer');

    // API JSON (appelée par le JavaScript)
    $router->get('/api/panier', 'Api\\PanierApiController@etat');
    $router->post('/api/panier', 'Api\\PanierApiController@operation');
    $router->get('/api/produits', 'Api\\CatalogueApiController@produits');
    $router->get('/api/suggestions', 'Api\\CatalogueApiController@suggestions');
};
