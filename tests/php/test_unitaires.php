<?php
// =============================================================================
// Tests unitaires PHP, sans framework (même esprit que PKG_TEST côté Oracle).
// Ils testent les classes "pures", sans base ni serveur web.
//
//   docker compose exec php php tests/php/test_unitaires.php
// =============================================================================
declare(strict_types=1);

use App\Core\Auth;
use App\Core\Csrf;
use App\Core\Database;
use App\Core\Erreurs\ErreurBaseDeDonnees;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Erreurs\MethodeNonAutorisee;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Router;
use App\Models\Utilisateur;

$racine = dirname(__DIR__, 2);
require $racine . '/app/Core/Autoloader.php';
require $racine . '/app/Core/fonctions.php';
App\Core\Autoloader::enregistrer($racine . '/app');

$ok = 0;
$echecs = 0;

function verifier(string $libelle, bool $condition, string $detail = ''): void
{
    global $ok, $echecs;
    if ($condition) {
        $ok++;
        echo "OK     $libelle\n";
    } else {
        $echecs++;
        echo "ÉCHEC  $libelle" . ($detail !== '' ? " — $detail" : '') . "\n";
    }
}

/** Vérifie que $code lève une exception de la classe $classe */
function verifierException(string $libelle, string $classe, callable $code): void
{
    try {
        $code();
        verifier($libelle, false, 'aucune exception');
    } catch (Throwable $e) {
        verifier($libelle, $e instanceof $classe, 'exception obtenue : ' . $e::class);
    }
}

// ----------------------------------------------------------------- Router
echo "--- Router\n";
$router = new Router();
$router->get('/', 'AccueilController@index');
$router->get('/produit/{id}', 'ProduitController@fiche');
$router->get('/annonces/{ville}/{id}', 'AnnonceController@fiche');
$router->post('/deconnexion', 'AuthController@deconnecter');
$router->get('/fichier.txt', 'X@y');

$r = $router->trouver('GET', '/');
verifier('route racine', $r['action'] === 'AccueilController@index');
$r = $router->trouver('GET', '/produit/42');
verifier('paramètre {id} extrait', $r['parametres'] === ['id' => '42'], json_encode($r['parametres']));
$r = $router->trouver('GET', '/annonces/Rabat/7');
verifier('deux paramètres extraits dans l\'ordre', $r['parametres'] === ['ville' => 'Rabat', 'id' => '7']);
$r = $router->trouver('GET', '/produit/42/');
verifier('barre finale ignorée', $r['action'] === 'ProduitController@fiche');
verifierException('URL inconnue → RouteIntrouvable', RouteIntrouvable::class,
    fn () => $router->trouver('GET', '/inconnue'));
verifierException('un paramètre ne traverse pas les "/"', RouteIntrouvable::class,
    fn () => $router->trouver('GET', '/produit/42/supprimer'));
verifierException('le "." du motif est littéral (preg_quote)', RouteIntrouvable::class,
    fn () => $router->trouver('GET', '/fichierXtxt'));
try {
    $router->trouver('GET', '/deconnexion');
    verifier('GET sur une route POST → MethodeNonAutorisee', false, 'aucune exception');
} catch (MethodeNonAutorisee $e) {
    verifier('GET sur une route POST → MethodeNonAutorisee', $e->methodesAutorisees === ['POST']);
}

// ----------------------------------------------------------------- Csrf
echo "--- Csrf\n";
$_SESSION = []; // en ligne de commande, la session est un simple tableau
$jeton = Csrf::jeton();
verifier('jeton de 64 caractères hexadécimaux', preg_match('/^[0-9a-f]{64}$/', $jeton) === 1);
verifier('jeton stable pendant la session', Csrf::jeton() === $jeton);
verifier('bon jeton accepté', Csrf::verifier($jeton));
verifier('mauvais jeton refusé', !Csrf::verifier(str_repeat('0', 64)));
verifier('jeton absent refusé', !Csrf::verifier(null));
verifier('jeton vide refusé', !Csrf::verifier(''));
Csrf::renouveler();
verifier('après renouvellement, l\'ancien jeton est refusé', !Csrf::verifier($jeton));
verifier('champ caché échappé et nommé _csrf',
    str_contains(Csrf::champ(), 'name="_csrf" value="' . Csrf::jeton() . '"'));

// ----------------------------------------------------------------- Validation de l'inscription
echo "--- Inscription\n";
$valide = ['nom' => 'Amina Test', 'email' => 'amina@exemple.ma', 'telephone' => '06 12 34 56 78',
           'role' => 'CLIENT', 'mot_de_passe' => 'motdepasse', 'confirmation' => 'motdepasse'];
verifier('formulaire valide : aucune erreur', Utilisateur::validerInscription($valide) === [],
    json_encode(Utilisateur::validerInscription($valide), JSON_UNESCAPED_UNICODE));

$erreurs = Utilisateur::validerInscription(['mot_de_passe' => '1234567', 'confirmation' => '1234567'] + $valide);
verifier('mot de passe de 7 caractères refusé', isset($erreurs['mot_de_passe']));
$erreurs = Utilisateur::validerInscription(['mot_de_passe' => '12345678', 'confirmation' => '12345678'] + $valide);
verifier('mot de passe de 8 caractères accepté', !isset($erreurs['mot_de_passe']));
// "éééééééé" : 8 caractères mais 16 octets ; mb_strlen compte bien 8
$erreurs = Utilisateur::validerInscription(['mot_de_passe' => 'éééééééé', 'confirmation' => 'éééééééé'] + $valide);
verifier('8 caractères accentués acceptés (mb_strlen)', !isset($erreurs['mot_de_passe']));
$long = str_repeat('a', 73);
$erreurs = Utilisateur::validerInscription(['mot_de_passe' => $long, 'confirmation' => $long] + $valide);
verifier('plus de 72 octets refusé (limite de bcrypt)', isset($erreurs['mot_de_passe']));
$erreurs = Utilisateur::validerInscription(['confirmation' => 'autrechose'] + $valide);
verifier('confirmation différente refusée', isset($erreurs['confirmation']));
$erreurs = Utilisateur::validerInscription(['email' => 'pas-un-email'] + $valide);
verifier('email invalide refusé', isset($erreurs['email']));
$erreurs = Utilisateur::validerInscription(['role' => 'ADMIN'] + $valide);
verifier('rôle ADMIN refusé à l\'inscription', isset($erreurs['role']));
$erreurs = Utilisateur::validerInscription(['telephone' => '12345'] + $valide);
verifier('téléphone invalide refusé', isset($erreurs['telephone']));
$erreurs = Utilisateur::validerInscription(['telephone' => '+212 6 12 34 56 78'] + $valide);
verifier('téléphone +212 accepté', !isset($erreurs['telephone']));

// bcrypt ignore vraiment ce qui dépasse 72 octets : la raison de la limite ci-dessus
$hash = password_hash(str_repeat('a', 72) . 'X', PASSWORD_DEFAULT);
verifier('démonstration : bcrypt ignore le 73e octet', password_verify(str_repeat('a', 72) . 'Y', $hash));

// ----------------------------------------------------------------- Redirection après connexion
echo "--- Retour après connexion (open redirect)\n";
verifier('chemin interne accepté', Auth::retourSur('/compte') === '/compte');
verifier('chemin avec paramètres accepté', Auth::retourSur('/annonces?ville=Rabat') === '/annonces?ville=Rabat');
verifier('URL externe refusée', Auth::retourSur('https://pirate.ma') === null);
verifier('URL "//pirate.ma" refusée', Auth::retourSur('//pirate.ma') === null);
verifier('URL "/\\pirate.ma" refusée', Auth::retourSur('/\\pirate.ma') === null);
verifier('chaîne vide refusée', Auth::retourSur('') === null);
verifier('accueil selon le rôle', Auth::accueilDuRole('ADMIN') === '/admin'
    && Auth::accueilDuRole('VENDEUR') === '/vendeur' && Auth::accueilDuRole('CLIENT') === '/compte');

// ----------------------------------------------------------------- Traduction des erreurs Oracle
echo "--- Erreurs Oracle\n";
$e = Database::traduire(20008, "ORA-20008: Un compte existe déjà avec l'email x@y.ma.\nORA-06512: at \"SOUK.PKG_ERREURS\", line 9");
verifier('-20008 → ErreurMetier', $e instanceof ErreurMetier);
verifier('code métier conservé', $e instanceof ErreurMetier && $e->codeOracle === ErreurMetier::EMAIL_DEJA_UTILISE);
verifier('message nettoyé (sans ORA- ni pile)', $e->getMessage() === "Un compte existe déjà avec l'email x@y.ma.", $e->getMessage());
$e = Database::traduire(942, 'ORA-00942: table or view does not exist');
verifier('ORA-00942 → ErreurBaseDeDonnees (technique)', $e instanceof ErreurBaseDeDonnees);

// ----------------------------------------------------------------- Échappement
echo "--- Échappement HTML\n";
verifier('balise neutralisée', e('<script>alert(1)</script>') === '&lt;script&gt;alert(1)&lt;/script&gt;');
verifier('guillemets échappés (attributs)', e('" onmouseover="x') === '&quot; onmouseover=&quot;x');
verifier('apostrophe échappée', e("l'ami") === 'l&#039;ami');
verifier('date_fr', date_fr('2026-10-23 14:05:00') === '23/10/2026' && date_fr(null) === '—');

echo "\nBILAN PHP : $ok OK, $echecs ÉCHEC\n";
exit($echecs === 0 ? 0 : 1);
