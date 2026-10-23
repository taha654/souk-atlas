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
    $router->get('/vendeur', 'VendeurController@index');
    $router->get('/admin', 'AdminController@index');

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

    // API JSON (appelée par le JavaScript)
    $router->get('/api/panier', 'Api\\PanierApiController@etat');
    $router->post('/api/panier', 'Api\\PanierApiController@operation');
    $router->get('/api/produits', 'Api\\CatalogueApiController@produits');
    $router->get('/api/suggestions', 'Api\\CatalogueApiController@suggestions');
};
