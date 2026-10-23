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

    // API JSON (appelée par le JavaScript)
    $router->get('/api/produits', 'Api\\CatalogueApiController@produits');
    $router->get('/api/suggestions', 'Api\\CatalogueApiController@suggestions');
};
