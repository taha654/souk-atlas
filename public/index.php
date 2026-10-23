<?php
// =============================================================================
// Contrôleur frontal : TOUTES les requêtes (sauf les fichiers de assets/)
// arrivent ici, grâce à FallbackResource dans la configuration d'Apache.
//
// Déroulé : configuration → base → session → utilisateur → CSRF → route
//           → action du contrôleur → réponse (ou page d'erreur).
// =============================================================================
declare(strict_types=1);

use App\Core\Auth;
use App\Core\Autoloader;
use App\Core\Config;
use App\Core\Csrf;
use App\Core\Database;
use App\Core\Erreurs\AccesRefuse;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Erreurs\MethodeNonAutorisee;
use App\Core\Erreurs\NonConnecte;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Request;
use App\Core\Response;
use App\Core\Router;
use App\Core\Session;
use App\Core\View;
use App\Models\Messagerie;
use App\Services\Panier;

$dossierApp = dirname(__DIR__) . '/app';
require $dossierApp . '/Core/Autoloader.php';
require $dossierApp . '/Core/fonctions.php';
Autoloader::enregistrer($dossierApp);
Config::charger(require $dossierApp . '/config.php');

$request = Request::depuisGlobales();

// En-têtes de sécurité, envoyés avec chaque page
header('X-Content-Type-Options: nosniff');           // le navigateur respecte le Content-Type annoncé
header('X-Frame-Options: DENY');                     // la page ne peut pas être affichée dans une iframe (clickjacking)
header('Referrer-Policy: same-origin');              // l'URL complète n'est pas transmise aux autres sites
// CSP : seuls nos propres fichiers CSS, JS et images sont autorisés. Un script
// injecté directement dans la page (<script>…</script>) ne s'exécuterait pas.
header("Content-Security-Policy: default-src 'self'; img-src 'self' data:; object-src 'none'; "
    . "base-uri 'self'; form-action 'self'; frame-ancestors 'none'");

/** Erreur avec le bon code HTTP : en JSON pour l'API, en page HTML sinon */
$pageErreur = static function (int $statut, string $titre, string $message) use ($request): Response {
    if (str_starts_with($request->chemin, '/api/')) {
        return Response::json(['erreur' => $titre, 'message' => $message], $statut);
    }
    return Response::html(View::rendre('erreurs/erreur',
        ['statut' => $statut, 'titre_erreur' => $titre, 'message' => $message], $titre), $statut);
};

try {
    $db = new Database(Config::get('db'));
    Session::demarrer(Config::get('session'), $request->https);
    Auth::charger($db);
    $db->definirUtilisateur(Auth::utilisateur()['id'] ?? null);

    // CSRF : vérifié ici pour TOUS les POST, avant même de chercher la route.
    // Impossible d'oublier la vérification dans un contrôleur.
    // Le jeton vient du champ caché d'un formulaire, ou de l'en-tête X-CSRF-Token
    // pour les appels fetch() du JavaScript (un autre site ne peut pas l'ajouter).
    $jetonRecu = $request->post[Csrf::CHAMP] ?? $request->entete('X-CSRF-Token');
    if ($request->methode === 'POST' && !Csrf::verifier(is_string($jetonRecu) ? $jetonRecu : null)) {
        throw new AccesRefuse('Jeton CSRF absent ou invalide');
    }

    // Nombre d'articles du panier, pour le badge de l'en-tête (pages HTML seulement)
    if (!str_starts_with($request->chemin, '/api/')) {
        View::partager('nb_articles', (new Panier($db, Auth::utilisateur()['id'] ?? null))->nbArticles());
        if (Auth::aLeRole('CLIENT', 'VENDEUR')) {
            View::partager('nb_non_lus', (new Messagerie($db))->nbNonLus(Auth::utilisateur()['id']));
        }
    }

    $router = new Router();
    (require $dossierApp . '/routes.php')($router);
    $route = $router->trouver($request->methode, $request->chemin);

    // "AuthController@connecter" → new App\Controllers\AuthController(...)->connecter()
    [$classe, $action] = explode('@', $route['action']);
    $classe = 'App\\Controllers\\' . $classe;
    $controleur = new $classe($request, $db);
    $reponse = $controleur->$action(...$route['parametres']);

} catch (NonConnecte) {
    // Une API ne redirige pas vers une page HTML : elle répond 401 en JSON
    if (str_starts_with($request->chemin, '/api/')) {
        (Response::json(['erreur' => 'Non connecté', 'message' => 'Connectez-vous pour accéder à cette ressource.'], 401))->envoyer();
        exit;
    }
    $retour = $request->methode === 'GET' ? '?retour=' . rawurlencode($request->chemin) : '';
    if (Session::vientDExpirer()) {
        Session::flash('info', 'Votre session a expiré après une période d\'inactivité. Reconnectez-vous.');
    }
    $reponse = Response::redirection('/connexion' . $retour);
} catch (AccesRefuse $erreur) {
    $message = str_starts_with($erreur->getMessage(), 'Jeton CSRF')
        ? 'Le formulaire a expiré ou ne vient pas de ce site. Rechargez la page et réessayez.'
        : 'Vous n\'avez pas accès à cette page.';
    $reponse = $pageErreur(403, 'Accès refusé', $message);
} catch (ErreurMetier $erreur) {
    // Filet de sécurité : une règle métier non interceptée par le contrôleur
    // (stock insuffisant…) donne son message et un 422, pas une page 500
    $reponse = $pageErreur(422, 'Action impossible', $erreur->getMessage());
} catch (RouteIntrouvable) {
    $reponse = $pageErreur(404, 'Page introuvable', 'Cette page n\'existe pas ou a été déplacée.');
} catch (MethodeNonAutorisee $erreur) {
    $reponse = $pageErreur(405, 'Méthode non autorisée', 'Cette adresse ne s\'utilise pas ainsi.');
    $reponse = new Response($reponse->corps, 405, $reponse->entetes + ['Allow' => implode(', ', $erreur->methodesAutorisees)]);
} catch (\Throwable $erreur) {
    // Erreur imprévue : le détail va dans le journal du serveur, jamais chez un visiteur en production
    error_log('[Souk Atlas] ' . $erreur::class . ' : ' . $erreur->getMessage() . ' dans '
        . $erreur->getFile() . ':' . $erreur->getLine());
    $detail = Config::get('env') === 'dev' ? ' (' . $erreur::class . ' : ' . $erreur->getMessage() . ')' : '';
    $reponse = $pageErreur(500, 'Erreur interne', 'Une erreur est survenue. Réessayez plus tard.' . $detail);
}

$reponse->envoyer();
