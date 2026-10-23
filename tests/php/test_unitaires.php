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
use App\Models\Commande;
use App\Models\FiltresCatalogue;
use App\Services\Mailer;
use App\Models\Produit;
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

// ----------------------------------------------------------------- Filtres du catalogue
echo "--- Filtres du catalogue\n";
$f = FiltresCatalogue::depuisRequete(['q' => '  samsung ', 'categorie' => '3', 'prix_min' => '100',
    'prix_max' => '2000,5', 'tri' => 'prix_asc', 'page' => '2', 'en_stock' => '1']);
verifier('filtres valides lus et typés', $f->texte === 'samsung' && $f->categorie === 3 && $f->prixMin === 100.0
    && $f->prixMax === 2000.5 && $f->tri === 'prix_asc' && $f->page === 2 && $f->enStock);
$f = FiltresCatalogue::depuisRequete(['categorie' => 'abc', 'page' => '-3', 'tri' => 'DROP TABLE', 'prix_min' => '-5']);
verifier('valeurs invalides → valeurs par défaut', $f->categorie === null && $f->page === 1
    && $f->tri === 'pertinence' && $f->prixMin === null);
$f = FiltresCatalogue::depuisRequete(['page' => '1.5', 'categorie' => '12abc']);
verifier('"1.5" et "12abc" refusés (FILTER_VALIDATE_INT)', $f->page === 1 && $f->categorie === null);
$f = FiltresCatalogue::depuisRequete(['prix_min' => '500', 'prix_max' => '100']);
verifier('bornes de prix inversées remises dans l\'ordre', $f->prixMin === 100.0 && $f->prixMax === 500.0);
$f = FiltresCatalogue::depuisRequete(['page' => '999999']);
verifier('page plafonnée', $f->page === 1000);
$f = FiltresCatalogue::depuisRequete(['q' => ['tableau'], 'tri' => ['x']]);
verifier('un tableau dans ?q[]= ne fait pas planter', $f->texte === '' && $f->tri === 'pertinence');
$f = FiltresCatalogue::depuisRequete(['q' => str_repeat('é', 300)]);
verifier('texte tronqué à 100 caractères', mb_strlen($f->texte) === 100);
$f = FiltresCatalogue::depuisRequete(['q' => 'tapis', 'categorie' => '14', 'page' => '3']);
verifier('URL sans valeurs par défaut', $f->url() === '/catalogue?q=tapis&categorie=14&page=3', $f->url());
verifier('URL de la page 1 : sans ?page', $f->url(['page' => 1]) === '/catalogue?q=tapis&categorie=14');
verifier('URL échappée (http_build_query)', FiltresCatalogue::depuisRequete(['q' => 'a&b=c'])->url() === '/catalogue?q=a%26b%3Dc');

// ----------------------------------------------------------------- Affichage
echo "--- Affichage\n";
verifier('format_prix : 3948 → "3 948,00 MAD" (espaces insécables)', format_prix(3948) === "3\u{00A0}948,00\u{00A0}MAD");
verifier('format_prix : 52.92', format_prix(52.92) === "52,92\u{00A0}MAD");
verifier('texte_note sans avis', texte_note(null, 0) === "Pas encore d'avis");
verifier('texte_note : virgule décimale', texte_note(4.25, 8) === '★ 4,3 sur 5 (8 avis)', texte_note(4.25, 8));
verifier('texte_stock', texte_stock(0) === 'Épuisé' && texte_stock(3) === 'Plus que 3 en stock' && texte_stock(40) === 'En stock');
verifier('pages_a_afficher : peu de pages', pages_a_afficher(1, 3) === [1, 2, 3]);
verifier('pages_a_afficher : 1 … 4 5 6 7 8 … 20', pages_a_afficher(6, 20) === [1, null, 4, 5, 6, 7, 8, null, 20]);
verifier('nomCourt : prénom + initiale', Produit::nomCourt('Fatima Zahra Bennani') === 'Fatima Zahra B.'
    && Produit::nomCourt('Amine') === 'Amine');

// ----------------------------------------------------------------- Commande
echo "--- Formulaire de commande\n";
$commandeValide = ['mode' => 'CARTE', 'adresse' => '12 rue des Orangers', 'ville' => 'Rabat', 'telephone' => '0612345678',
       'carte' => '4111 1111 1111 1111', 'mois' => '12', 'annee' => '2030', 'cvv' => '123'];
verifier('commande par carte valide', Commande::validerFormulaire($commandeValide) === [],
    json_encode(Commande::validerFormulaire($commandeValide), JSON_UNESCAPED_UNICODE));
verifier('livraison : la carte n\'est pas exigée',
    Commande::validerFormulaire(['mode' => 'LIVRAISON', 'carte' => '', 'cvv' => ''] + $commandeValide) === []);
$e = Commande::validerFormulaire(['adresse' => 'ici', 'ville' => '', 'telephone' => '123'] + $commandeValide);
verifier('adresse, ville et téléphone invalides détectés', isset($e['adresse'], $e['ville'], $e['telephone']));
verifier('mode de paiement inconnu', isset(Commande::validerFormulaire(['mode' => 'BITCOIN'] + $commandeValide)['mode']));
verifier('CVV à 2 chiffres refusé', isset(Commande::validerFormulaire(['cvv' => '12'] + $commandeValide)['cvv']));
verifier('carte avec lettres refusée', isset(Commande::validerFormulaire(['carte' => '4111-abcd-1111'] + $commandeValide)['carte']));
verifier('expiration manquante', isset(Commande::validerFormulaire(['mois' => ''] + $commandeValide)['expiration']));

echo "--- Mailer simulé\n";
$dossier = sys_get_temp_dir() . '/souk-test-mails-' . bin2hex(random_bytes(3));
$mailer = new Mailer($dossier);
$fichier = $mailer->envoyer('client@exemple.ma', 'Votre achat — référence ACH-1', "Bonjour,\nmerci.");
$contenu = (string) file_get_contents($fichier);
verifier('fichier .eml écrit', is_file($fichier) && str_ends_with($fichier, '.eml'));
// Un en-tête d'email doit être en ASCII : la partie accentuée est encodée (RFC 2047),
// les mots ASCII du début peuvent rester en clair ("Subject: Votre achat =?UTF-8?B?…")
preg_match('/^Subject: .*(?:\r\n .*)*/m', $contenu, $sujet);
verifier('sujet accentué encodé (RFC 2047), en-tête 100 % ASCII',
    str_contains($sujet[0] ?? '', '=?UTF-8?B?') && preg_match('/^[\x20-\x7E\r\n]+$/', $sujet[0] ?? '') === 1);
verifier('corps en UTF-8 conservé', str_contains($contenu, "Bonjour,\r\nmerci."));
verifierException('injection d\'en-tête dans le sujet refusée', InvalidArgumentException::class,
    fn () => $mailer->envoyer('client@exemple.ma', "Sujet\r\nBcc: pirate@exemple.ma", 'x'));
verifierException('adresse invalide refusée', InvalidArgumentException::class,
    fn () => $mailer->envoyer('pas-une-adresse', 'Sujet', 'x'));
array_map('unlink', glob($dossier . '/*.eml'));
rmdir($dossier);

echo "\nBILAN PHP : $ok OK, $echecs ÉCHEC\n";
exit($echecs === 0 ? 0 : 1);
