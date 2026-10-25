<?php
// =============================================================================
// Télécharge de vraies photos (Pixabay) pour les produits et annonces de démo.
//
//   docker compose exec --user "$(id -u):$(id -g)" php php tools/photos_demo.php [options]
//
//   --limite=N        traite au plus N produits ou annonces (pour un essai)
//   --refaire=a,b     refuse les photos actuelles de ces éléments (produit-12, annonce-3)
//                     et en cherche d'autres
//   --verifier        liste les photos actuelles dont les tags n'ont pas le mot principal
//   --simulation      affiche les requêtes construites, sans appeler Pixabay
//
// Pour chaque produit (ou annonce) : UNE recherche Pixabay, en anglais, construite
// à partir du nom et de la catégorie. Chaque photo trouvée est notée d'après ses
// tags (voir noter()) : sans le mot principal de la requête, elle est écartée.
// Les vues du produit reçoivent les photos les mieux notées ; s'il n'y en a pas
// assez, les vues restantes gardent leur illustration SVG (mieux qu'une photo fausse).
//
// tools/photos_choix.json (versionné) garde les décisions prises à la main :
// "choix" impose une photo pour une vue ("produit-12-1": identifiant Pixabay)
// ou l'illustration SVG ("produit-12-1": null) quand Pixabay n'a rien de juste,
// "exclues" liste les photos refusées, qui ne seront jamais reprises.
//
// Règles de Pixabay (https://pixabay.com/api/docs/) respectées ici :
//  - pas de lien direct vers leurs images : chaque photo est téléchargée, recadrée
//    en 800 x 600 px et enregistrée en WebP dans public/images/demo/ (avec GD) ;
//  - réponses de l'API gardées 24 h dans var/pixabay/cache/ : relancer le script
//    ne refait pas les mêmes recherches ;
//  - 100 requêtes par minute au plus : les heures des requêtes sont gardées dans
//    var/pixabay/requetes.json (fenêtre glissante d'une minute, qui survit à une
//    interruption). Le téléchargement des images ne compte pas dans cette limite.
//
// Reprise : chaque photo terminée est inscrite tout de suite dans
// public/images/demo/credits.json (auteur, lien Pixabay) ; une photo déjà
// présente n'est jamais redemandée. On peut donc interrompre (Ctrl+C) et relancer.
//
// La clé PIXABAY_API_KEY est lue dans l'environnement ou dans .env (jamais versionné).
// Pixabay la veut dans l'URL : on n'affiche donc jamais une URL d'API.
// =============================================================================
declare(strict_types=1);

use App\Core\Database;
use App\Services\PhotosDemo;

$racine = dirname(__DIR__);
require $racine . '/app/Core/Autoloader.php';
App\Core\Autoloader::enregistrer($racine . '/app');
$config = require $racine . '/app/config.php';

const LIMITE_PAR_MINUTE = 100;
const DUREE_CACHE = 24 * 3600;
// 4:3, comme les illustrations SVG (600 x 450) : les cartes restent alignées
const LARGEUR = 800;
const HAUTEUR = 600;
const QUALITE_WEBP = 80;
const RESULTATS_PAR_RECHERCHE = 50;

// -----------------------------------------------------------------------------
// Construction de la requête anglaise
// -----------------------------------------------------------------------------

// Mots du nom (sans accents, en minuscules) → requête anglaise.
// L'ordre compte : la première expression trouvée gagne, donc les expressions
// précises ("tapis de yoga") passent avant les mots généraux ("tapis").
const EXPRESSIONS = [
    'protection d\'ecran' => 'phone screen protector',
    'ecran gamer'         => 'gaming monitor',
    'tapis de yoga'       => 'yoga mat',
    'tapis de course'     => 'treadmill',
    'tapis berbere'       => 'berber rug',
    'sacoche pour ordinateur' => 'laptop bag',
    'ordinateur portable' => 'laptop computer',
    'ordinateur de bureau' => 'desktop computer',
    'console de jeux'     => 'handheld game console',
    'machine a cafe'      => 'espresso machine',
    'machine a laver'     => 'washing machine',
    'robot patissier'     => 'stand mixer kitchen',
    'mixeur plongeant'    => 'hand blender',
    'barre de son'        => 'soundbar',
    'batterie externe'    => 'power bank',
    'disque ssd'          => 'external hard drive',
    'cle usb'             => 'usb flash drive',
    'souris'              => 'computer mouse',
    'clavier'             => 'computer keyboard',
    'imprimante'          => 'printer',
    'enceinte'            => 'portable speaker',
    'ecouteurs'           => 'wireless earbuds',
    'chargeur'            => 'phone charger',
    'coque'               => 'phone case',
    'televiseur'          => 'television living room',
    'ecran'               => 'computer monitor',
    'montre connectee'    => 'smartwatch',
    'manettes'            => 'game controller',
    'tablette'            => 'tablet computer',
    'smartphone'          => 'smartphone',
    'lanterne'            => 'moroccan lantern',
    'pouf'                => 'moroccan leather pouf',
    'miroir'              => 'moroccan mirror',
    'plateau a the'       => 'moroccan tea tray',
    'verres a the'        => 'moroccan tea glasses',
    'theiere'             => 'moroccan teapot',
    'plateau en bois'     => 'wooden tray',
    'kilim'               => 'kilim cushions',
    'tajine'              => 'tagine pot',
    'couscoussier'        => 'couscous',
    'salon marocain'      => 'moroccan living room',
    'canape'              => 'sofa living room',
    'table basse'         => 'wooden coffee table',
    'table en bois'       => 'wooden dining table',
    'refrigerateur'       => 'refrigerator',
    'climatiseur'         => 'air conditioner',
    'djellaba'            => 'djellaba',
    'jabador'             => 'moroccan traditional clothing',
    'caftan'              => 'moroccan kaftan',
    'babouches'           => 'moroccan slippers',
    'chemise en lin'      => 'linen shirt',
    'sac a main'          => 'leather handbag',
    'huile d\'argan'      => 'argan oil',
    'savon noir'          => 'natural soap',
    'ghassoul'            => 'clay powder cosmetic',
    'eau de rose'         => 'rose water',
    'hammam'              => 'spa products',
    'parfum'              => 'perfume bottle',
    'halteres'            => 'dumbbells',
    'velo vtt'            => 'mountain bike',
    'velo de course'      => 'road bike',
    'ballon de football'  => 'soccer ball',
    'maillot de football' => 'soccer jersey',
    'gourde'              => 'water bottle',
    'siege auto'          => 'baby car seat',
    'poussette'           => 'baby stroller',
    'lit bebe'            => 'baby crib',
    'briques de construction' => 'toy building blocks',
    'jeu de construction' => 'toy building blocks',
    'guitare'             => 'acoustic guitar',
    'scooter electrique'  => 'electric scooter',
    'scooter'             => 'scooter',
    'moto'                => 'motorcycle',
    'location de vacances' => 'beach house',
    'villa'               => 'villa with garden',
    'studio'              => 'studio apartment interior',
    'appartement'         => 'apartment interior',
    'voiture'             => 'car',
];

// Catégorie → requête, quand le nom ne contient qu'une marque ("Renault Clio 4")
const CATEGORIES = [
    'Smartphones' => 'smartphone', 'Tablettes' => 'tablet computer', 'Accessoires téléphone' => 'phone accessories',
    'Ordinateurs portables' => 'laptop computer', 'Périphériques' => 'computer accessories',
    'TV, audio & consoles' => 'home entertainment', 'Électroménager' => 'home appliance',
    'Cuisine & art de la table' => 'kitchenware', 'Décoration & meubles' => 'home decor',
    'Tapis & artisanat' => 'moroccan handicraft', 'Homme' => 'men fashion', 'Femme' => 'women fashion',
    'Tenues traditionnelles' => 'moroccan traditional clothing', 'Soins & cosmétiques' => 'natural cosmetics',
    'Parfums' => 'perfume bottle', 'Fitness' => 'fitness equipment', 'Vélos' => 'bicycle',
    'Football' => 'football', 'Puériculture' => 'baby products', 'Jouets' => 'toys',
    'Voitures' => 'car', 'Motos & scooters' => 'motorcycle', 'Ventes immobilières' => 'house for sale',
    'Locations' => 'apartment interior',
];

// Catégorie Pixabay (paramètre "category" de l'API) quand l'une d'elles correspond
// vraiment : elle écarte les photos d'autres domaines qui partagent un mot
const CATEGORIES_PIXABAY = [
    'Smartphones' => 'computer', 'Tablettes' => 'computer', 'Accessoires téléphone' => 'computer',
    'Ordinateurs portables' => 'computer', 'Périphériques' => 'computer', 'TV, audio & consoles' => 'computer',
    'Cuisine & art de la table' => 'food', 'Homme' => 'fashion', 'Femme' => 'fashion',
    'Tenues traditionnelles' => 'fashion', 'Soins & cosmétiques' => 'health', 'Fitness' => 'sports',
    'Vélos' => 'sports', 'Football' => 'sports', 'Voitures' => 'transportation',
    'Motos & scooters' => 'transportation', 'Ventes immobilières' => 'buildings', 'Locations' => 'buildings',
];

// Mot principal d'une requête : il DOIT figurer dans les tags de la photo.
// Par défaut, c'est le dernier mot, au singulier ("yoga mat" → "mat",
// "dumbbells" → "dumbbell") ; on le précise ici quand
// ce n'est pas le cas ou quand Pixabay emploie d'autres mots ("|" = ou).
const MOTS_PRINCIPAUX = [
    'smartphone' => 'smartphone|mobile phone|cell phone|cellphone',
    'tablet computer' => 'tablet', 'laptop computer' => 'laptop|notebook',
    'phone accessories' => 'phone|smartphone', 'computer accessories' => 'computer|keyboard|mouse',
    'phone case' => 'case|cover', 'phone charger' => 'charger|charging',
    'phone screen protector' => 'screen protector|protector|tempered glass',
    'wireless earbuds' => 'earbud|earphone|headphone|headset', 'portable speaker' => 'speaker',
    'power bank' => 'power bank|powerbank', 'external hard drive' => 'hard drive|hard disk|ssd',
    'usb flash drive' => 'usb', 'computer mouse' => 'mouse', 'computer keyboard' => 'keyboard',
    'computer monitor' => 'monitor', 'game controller' => 'controller|gamepad|joystick',
    'television living room' => 'television|tv', 'home entertainment' => 'television|tv',
    'espresso machine' => 'espresso machine|coffee machine|coffee maker',
    'washing machine' => 'washing machine|washer', 'stand mixer kitchen' => 'mixer',
    'home appliance' => 'appliance', 'refrigerator' => 'refrigerator|fridge',
    'air conditioner' => 'air conditioner|air conditioning',
    'moroccan living room' => 'living room|lounge', 'sofa living room' => 'sofa|couch',
    'wooden coffee table' => 'table', 'tagine pot' => 'tagine|tajine', 'home decor' => 'decor|decoration',
    'moroccan handicraft' => 'handicraft|handmade|craft', 'moroccan kaftan' => 'kaftan|caftan',
    'moroccan slippers' => 'slipper|babouche', 'moroccan tea glasses' => 'glass', 'moroccan traditional clothing' => 'traditional|costume',
    'men fashion' => 'fashion|clothing', 'women fashion' => 'fashion|clothing',
    'leather handbag' => 'handbag|bag|purse', 'argan oil' => 'argan', 'clay powder cosmetic' => 'clay',
    'rose water' => 'rose water|rosewater', 'spa products' => 'spa', 'natural cosmetics' => 'cosmetics',
    'perfume bottle' => 'perfume|fragrance', 'fitness equipment' => 'fitness|gym',
    'mountain bike' => 'bike|bicycle', 'road bike' => 'bike|bicycle', 'soccer ball' => 'ball',
    'soccer jersey' => 'jersey|shirt', 'baby car seat' => 'car seat', 'baby stroller' => 'stroller|pram|buggy',
    'baby crib' => 'crib|cot', 'baby products' => 'baby', 'toy building blocks' => 'block|brick',
    'toys' => 'toy', 'electric scooter' => 'scooter', 'villa with garden' => 'villa',
    'studio apartment interior' => 'interior|apartment', 'apartment interior' => 'interior|apartment',
    'house for sale' => 'house|home',
];

// Tags qui signalent une photo hors sujet (scène de bureau, montage, fond d'écran…) :
// chacun retire des points, sauf s'il fait partie de la requête
const TAGS_PENALISES = [
    'people', 'person', 'man', 'woman', 'meeting', 'business', 'teamwork', 'collage', 'background',
    'wallpaper', 'composing', 'miniature',
];
const POINTS_MOT_PRINCIPAL = 10;
const POINTS_MOT_PRINCIPAL_EN_TETE = 2;   // dans les 3 premiers tags (Pixabay les trie par pertinence)
const POINTS_AUTRE_MOT = 3;
const POINTS_TAG_PENALISE = -3;

// Photo écartée si un de ses tags contient l'un de ces mots : on veut le type de
// produit, sans marque, logo ni modèle reconnaissable, et sans montage photo.
// Le filtre ne voit que les tags, pas l'image : un logo non tagué passe.
const TAGS_EXCLUS = [
    // Marques et logos
    'apple', 'iphone', 'ipad', 'macbook', 'imac', 'airpods', 'samsung', 'galaxy', 'xiaomi', 'huawei',
    'pixel', 'sony', 'playstation', 'ps4', 'ps5', 'nintendo', 'xbox', 'lenovo', 'asus', 'dell', 'logitech',
    'lego', 'nike', 'adidas', 'puma', 'logo', 'brand', 'dacia', 'peugeot', 'renault', 'bmw', 'mercedes',
    'audi', 'toyota', 'volkswagen', 'ford', 'tesla', 'porsche', 'ferrari', 'vespa', 'yamaha', 'honda',
    'kawasaki', 'harley', 'canon', 'nikon', 'beats', 'bose', 'jbl', 'chanel', 'dior', 'starbucks',
    'opel', 'buick', 'cadillac', 'fiat', 'chevrolet', 'mustang', 'jaguar', 'atari', 'lynx', 'mac', 'gameboy',
    'marshall', 'lancome', 'premier league', 'doritos', 'football club', 'jersey',
    // Voitures anciennes reconnaissables (souvent des modèles américains, à La Havane)
    'vintage car', 'classic car', 'oldtimer', 'havana',
    // Montages et images retouchées
    'manipulation', 'surreal', 'composite', 'fantasy',
];

// Comptes Pixabay qui republient des photos d'autres banques d'images : le vrai
// auteur n'y est pas nommé, on ne pourrait donc pas le créditer correctement
const COMPTES_RELAIS = ['pexels', 'free-photos', 'stocksnap', 'unsplash', 'pexels-photos'];

function sansAccents(string $texte): string
{
    $texte = mb_strtolower($texte);
    // Même idée que pkg_catalogue.normaliser : on compare sans accents
    return strtr($texte, ['é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e', 'à' => 'a', 'â' => 'a', 'î' => 'i',
        'ï' => 'i', 'ô' => 'o', 'ö' => 'o', 'û' => 'u', 'ù' => 'u', 'ü' => 'u', 'ç' => 'c', '’' => '\'']);
}

function requeteAnglaise(string $nom, string $categorie): string
{
    $nom = sansAccents($nom);
    foreach (EXPRESSIONS as $francais => $anglais) {
        // \b : "moto" ne doit pas se trouver dans "motorisé"
        if (preg_match('/\b' . preg_quote($francais, '/') . '\b/u', $nom) === 1) {
            return $anglais;
        }
    }
    return CATEGORIES[$categorie] ?? 'product';
}

/** Motif du mot principal ; un "s" ou "es" final est accepté (case → cases) */
function motifPrincipal(string $requete): string
{
    // Singulier par défaut : le motif accepte le pluriel, pas l'inverse
    $mots = MOTS_PRINCIPAUX[$requete] ?? preg_replace('/(?<!s)s$/', '', substr(strrchr(' ' . $requete, ' '), 1));
    $alternatives = array_map(static fn (string $m) => preg_quote($m, '/'), explode('|', $mots));
    return '/\b(?:' . implode('|', $alternatives) . ')(?:e?s)?\b/';
}

/**
 * Note d'une photo d'après ses tags, ou null si le mot principal manque (photo écartée).
 * Le détail du calcul est affiché par le script : on voit pourquoi une photo gagne.
 */
function noter(array $photo, string $requete): ?int
{
    $tags = array_map('trim', explode(',', strtolower($photo['tags'])));
    $motif = motifPrincipal($requete);
    $rangs = array_keys(array_filter($tags, static fn (string $t) => preg_match($motif, $t) === 1));
    if ($rangs === []) {
        return null;
    }
    $note = POINTS_MOT_PRINCIPAL + ($rangs[0] < 3 ? POINTS_MOT_PRINCIPAL_EN_TETE : 0);
    $texte = ' ' . implode(' , ', $tags) . ' ';
    // Autres mots de la requête ("moroccan", "wooden"…), hors mot principal
    foreach (explode(' ', $requete) as $mot) {
        if (strlen($mot) >= 3 && preg_match($motif, $mot) !== 1 && preg_match('/\b' . preg_quote($mot, '/') . '\b/', $texte) === 1) {
            $note += POINTS_AUTRE_MOT;
        }
    }
    foreach (TAGS_PENALISES as $tag) {
        if (!str_contains($requete, $tag) && preg_match('/\b' . preg_quote($tag, '/') . '\b/', $texte) === 1) {
            $note += POINTS_TAG_PENALISE;
        }
    }
    return $note;
}

function aUnTagExclu(string $tags): bool
{
    $tags = mb_strtolower($tags);
    foreach (TAGS_EXCLUS as $mot) {
        if (preg_match('/\b' . preg_quote($mot, '/') . '\b/u', $tags) === 1) {
            return true;
        }
    }
    return false;
}

// -----------------------------------------------------------------------------
// Fichiers de travail
// -----------------------------------------------------------------------------

function lireJson(string $fichier): array
{
    return is_file($fichier) ? json_decode((string) file_get_contents($fichier), true, 16, JSON_THROW_ON_ERROR) : [];
}

/** Écriture atomique : un Ctrl+C pendant l'écriture ne laisse jamais un fichier à moitié écrit */
function ecrireJson(string $fichier, array $donnees): void
{
    file_put_contents($fichier . '.tmp',
        json_encode($donnees, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR) . "\n");
    rename($fichier . '.tmp', $fichier);
}

function cleApi(string $racine): string
{
    $cle = getenv('PIXABAY_API_KEY') ?: '';
    if ($cle === '' && is_file($racine . '/.env')) {
        foreach (file($racine . '/.env', FILE_IGNORE_NEW_LINES) as $ligne) {
            if (preg_match('/^\s*PIXABAY_API_KEY\s*=\s*"?([^"\s]+)"?\s*$/', $ligne, $m) === 1) {
                $cle = $m[1];
            }
        }
    }
    if ($cle === '') {
        fwrite(STDERR, "PIXABAY_API_KEY absente : ajoutez-la dans .env (jamais dans git).\n");
        exit(2);
    }
    return $cle;
}

// -----------------------------------------------------------------------------
// Appels HTTP
// -----------------------------------------------------------------------------

/** Attend, si besoin, qu'une requête d'API soit permise ; la note ensuite */
function reserverRequete(string $journal): void
{
    while (true) {
        $uneMinute = time() - 60;
        $heures = array_values(array_filter(lireJson($journal), static fn (int $t) => $t > $uneMinute));
        if (count($heures) < LIMITE_PAR_MINUTE) {
            $heures[] = time();
            ecrireJson($journal, $heures);
            return;
        }
        $attente = min($heures) + 60 - time() + 1;
        echo "  Limite de " . LIMITE_PAR_MINUTE . " requêtes/minute atteinte : attente de {$attente} s.\n";
        sleep(max(1, $attente));
    }
}

/** @return array{code: int, corps: string, entetes: array<string, string>} */
function telecharger(string $url): array
{
    $recues = [];
    $curl = curl_init($url);
    curl_setopt_array($curl, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_USERAGENT => 'souk-atlas/1.0 (projet de portfolio, tools/photos_demo.php)',
        CURLOPT_HEADERFUNCTION => static function ($c, string $ligne) use (&$recues): int {
            if (str_contains($ligne, ':')) {
                [$nom, $valeur] = explode(':', $ligne, 2);
                $recues[strtolower(trim($nom))] = trim($valeur);
            }
            return strlen($ligne);
        },
    ]);
    $corps = curl_exec($curl);
    if ($corps === false) {
        // curl_error ne contient pas l'URL : la clé ne peut pas s'afficher ici
        throw new RuntimeException('Réseau : ' . curl_error($curl));
    }
    return ['code' => curl_getinfo($curl, CURLINFO_RESPONSE_CODE), 'corps' => $corps, 'entetes' => $recues];
}

/** Efface les réponses de plus de 24 h : Pixabay demande de ne pas les garder plus longtemps */
function purgerCache(string $dossierCache): void
{
    foreach (glob($dossierCache . '*.json') ?: [] as $fichier) {
        if (filemtime($fichier) < time() - DUREE_CACHE) {
            unlink($fichier);
        }
    }
}

/**
 * Appel de l'API (recherche ou photo précise), avec cache de 24 h.
 * @return list<array<string, mixed>> photos renvoyées
 */
function appelApi(array $parametres, string $cle, string $journal, string $dossierCache): array
{
    // Le nom du fichier de cache ne dépend que des paramètres, jamais de la clé
    $fichierCache = $dossierCache . sha1(http_build_query($parametres)) . '.json';
    if (is_file($fichierCache) && filemtime($fichierCache) >= time() - DUREE_CACHE) {
        return lireJson($fichierCache)['hits'];
    }

    $url = 'https://pixabay.com/api/?' . http_build_query(['key' => $cle] + $parametres);
    while (true) {
        reserverRequete($journal);
        $reponse = telecharger($url);
        if ($reponse['code'] === 429) {
            // Limite vue par Pixabay (autre script…) : X-RateLimit-Reset = secondes avant la remise à zéro
            $attente = max(5, (int) ($reponse['entetes']['x-ratelimit-reset'] ?? 60));
            echo "  Pixabay répond 429 (reste " . ($reponse['entetes']['x-ratelimit-remaining'] ?? '?')
                . ', « ' . mb_substr(trim(strip_tags($reponse['corps'])), 0, 80) . " ») : attente de {$attente} s.\n";
            sleep($attente);
            continue;
        }
        if ($reponse['code'] === 400 && isset($parametres['id'])) {
            return [];   // identifiant inconnu : Pixabay répond 400, pas une liste vide
        }
        if ($reponse['code'] !== 200) {
            $quoi = $parametres['q'] ?? 'photo ' . $parametres['id'];
            throw new RuntimeException("Pixabay répond {$reponse['code']} pour « $quoi »");
        }
        $donnees = json_decode($reponse['corps'], true, 16, JSON_THROW_ON_ERROR);
        ecrireJson($fichierCache, ['parametres' => $parametres, 'hits' => $donnees['hits']]);
        return $donnees['hits'];
    }
}

/** @return list<array<string, mixed>> photos trouvées */
function rechercher(string $requete, ?string $categorie, string $cle, string $journal, string $dossierCache): array
{
    $parametres = ['q' => $requete, 'image_type' => 'photo', 'orientation' => 'horizontal',
        'min_width' => LARGEUR, 'min_height' => HAUTEUR, 'safesearch' => 'true',
        'per_page' => RESULTATS_PAR_RECHERCHE];
    if ($categorie !== null) {
        $parametres['category'] = $categorie;
    }
    return appelApi($parametres, $cle, $journal, $dossierCache);
}

/** Photo imposée dans photos_choix.json, ou null si l'identifiant n'existe pas */
function photoParId(int $id, string $cle, string $journal, string $dossierCache): ?array
{
    return appelApi(['id' => $id], $cle, $journal, $dossierCache)[0] ?? null;
}

/** Dimensions de largeImageURL : Pixabay la réduit à 1280 px sur le plus grand côté */
function tailleGrande(array $photo): array
{
    $echelle = min(1, 1280 / max($photo['imageWidth'], $photo['imageHeight']));
    return [(int) floor($photo['imageWidth'] * $echelle), (int) floor($photo['imageHeight'] * $echelle)];
}

/** Assez grande pour un recadrage 4:3 en 800 x 600 sans agrandir (un panorama ne l'est pas) */
function assezGrande(array $photo): bool
{
    [$l, $h] = tailleGrande($photo);
    return min($l, $h * LARGEUR / HAUTEUR) >= LARGEUR;
}

/** Télécharge la photo, la recadre au centre en 4:3, la réduit à 800 x 600 et l'enregistre en WebP */
function enregistrerWebp(array $photo, string $fichier): void
{
    $reponse = telecharger($photo['largeImageURL']);
    if ($reponse['code'] !== 200) {
        throw new RuntimeException("Image {$photo['id']} : réponse {$reponse['code']}");
    }
    // On ne croit pas l'en-tête Content-Type : on lit le contenu, comme pour un upload
    $type = (new finfo(FILEINFO_MIME_TYPE))->buffer($reponse['corps']);
    $source = in_array($type, ['image/jpeg', 'image/png'], true) ? imagecreatefromstring($reponse['corps']) : false;
    if ($source === false) {
        throw new RuntimeException("Image {$photo['id']} : $type reçu");
    }

    // Plus grand rectangle 4:3 au centre de la photo
    $l = imagesx($source);
    $h = imagesy($source);
    $largeurCoupe = (int) min($l, round($h * LARGEUR / HAUTEUR));
    $hauteurCoupe = (int) round($largeurCoupe * HAUTEUR / LARGEUR);
    $cible = imagecreatetruecolor(LARGEUR, HAUTEUR);
    // imagecopyresampled fait une vraie moyenne des pixels (imagecopyresized en sauterait)
    imagecopyresampled($cible, $source, 0, 0, intdiv($l - $largeurCoupe, 2), intdiv($h - $hauteurCoupe, 2),
        LARGEUR, HAUTEUR, $largeurCoupe, $hauteurCoupe);

    imagewebp($cible, $fichier . '.tmp', QUALITE_WEBP);
    $taille = getimagesize($fichier . '.tmp');
    if ($taille === false || $taille['mime'] !== 'image/webp' || [$taille[0], $taille[1]] !== [LARGEUR, HAUTEUR]) {
        unlink($fichier . '.tmp');
        throw new RuntimeException("Image {$photo['id']} : conversion WebP ratée");
    }
    rename($fichier . '.tmp', $fichier);
}

// -----------------------------------------------------------------------------
// Programme
// -----------------------------------------------------------------------------

$options = getopt('', ['limite:', 'refaire:', 'simulation', 'verifier']);
$limite = isset($options['limite']) ? (int) $options['limite'] : PHP_INT_MAX;
$aRefaire = isset($options['refaire']) ? explode(',', (string) $options['refaire']) : [];
$simulation = isset($options['simulation']);

$dossier = $racine . '/public' . PhotosDemo::DOSSIER;
$fichierCredits = $racine . '/public' . PhotosDemo::CREDITS;
$journal = $racine . '/var/pixabay/requetes.json';
$dossierCache = $racine . '/var/pixabay/cache/';
foreach ([$dossier, $dossierCache] as $d) {
    if (!is_dir($d)) {
        mkdir($d, 0755, true);
    }
}

// Les éléments à illustrer viennent de la base (lignes de démo de PRODUIT_PHOTO
// et ANNONCE_PHOTO, en SVG ou déjà en WebP) : une seule source de vérité
$db = new Database($config['db']);
$lignes = $db->lignes(
    "SELECT 'produit-' || p.id AS element, ph.chemin, p.nom, c.nom AS categorie
       FROM produit_photo ph JOIN produit p ON p.id = ph.id_produit JOIN categorie c ON c.id = p.id_categorie
     UNION ALL
     SELECT 'annonce-' || a.id, ph.chemin, a.titre, c.nom
       FROM annonce_photo ph JOIN annonce a ON a.id = ph.id_annonce JOIN categorie c ON c.id = a.id_categorie",
);
$elements = [];
foreach ($lignes as $l) {
    $cle = PhotosDemo::cle($l['CHEMIN']);
    if ($cle !== null) {
        $elements[$l['ELEMENT']]['nom'] = $l['NOM'];
        $elements[$l['ELEMENT']]['categorie'] = $l['CATEGORIE'];
        $elements[$l['ELEMENT']]['cles'][] = $cle;
    }
}
uksort($elements, 'strnatcmp');
purgerCache($dossierCache);

$credits = lireJson($fichierCredits);
// Décisions à la main (fichier versionné) : photos imposées ("produit-12-1": identifiant,
// ou null pour garder l'illustration SVG)
// et photos refusées (identifiants jamais repris, ajoutés aussi par --refaire)
$fichierChoix = __DIR__ . '/photos_choix.json';
$decisions = lireJson($fichierChoix);
$choix = array_map(static fn ($id) => $id === null ? null : (int) $id, $decisions['choix'] ?? []);

/** Oublie une photo : crédit ET fichier, sinon le site continuerait de l'afficher */
$oublier = static function (string $cle) use (&$credits, $dossier): void {
    unset($credits[$cle]);
    if (is_file($dossier . $cle . '.webp')) {
        unlink($dossier . $cle . '.webp');
    }
};

// --verifier : photos actuelles dont les tags ne contiennent pas le mot principal
if (isset($options['verifier'])) {
    $rates = [];
    foreach ($elements as $element => $e) {
        foreach ($e['cles'] as $cle) {
            $c = $credits[$cle] ?? null;
            if ($c !== null && !array_key_exists($cle, $choix)
                && noter(['tags' => $c['description']], requeteAnglaise($e['nom'], $e['categorie'])) === null) {
                echo "$cle  « {$e['nom']} »  ({$c['description']})\n";
                $rates[$element] = true;
            }
        }
    }
    echo "\n--refaire=" . implode(',', array_keys($rates)) . "\n";
    exit(0);
}

// --refaire : les photos actuelles de ces éléments rejoignent les photos refusées.
// La liste est enregistrée tout de suite : elle ne dépend pas d'une nouvelle photo trouvée.
foreach ($aRefaire as $element) {
    foreach ($elements[$element]['cles'] ?? [] as $cle) {
        if (isset($credits[$cle])) {
            $decisions['exclues'][] = $credits[$cle]['pixabay_id'];
        }
    }
}
$exclues = array_values(array_unique(array_map('intval', $decisions['exclues'] ?? [])));
if ($aRefaire !== []) {
    $decisions['exclues'] = $exclues;
    ecrireJson($fichierChoix, $decisions);
}
// Une photo refusée (par --refaire ou à la main) disparaît du site.
// TAGS_EXCLUS ne s'applique qu'aux recherches : les photos déjà validées restent.
foreach ($credits as $cle => $c) {
    if (in_array($c['pixabay_id'], $exclues, true)) {
        $oublier($cle);
    }
}
// Un choix imposé passe avant tout : une autre photo à cette place est remplacée (ou retirée)
foreach ($choix as $cle => $id) {
    if (isset($credits[$cle]) && $credits[$cle]['pixabay_id'] !== $id) {
        $oublier($cle);
    }
}
// Tout de suite : une photo retirée ne doit plus être créditée, même si rien ne la remplace
ecrireJson($fichierCredits, $credits);

$traites = 0;
foreach ($elements as $element => $e) {
    sort($e['cles'], SORT_NATURAL);
    $manquantes = array_values(array_filter($e['cles'],
        static fn (string $c) => !isset($credits[$c]) || !is_file($dossier . $c . '.webp')));
    if ($manquantes === []) {
        continue;   // déjà fait (reprise)
    }
    if ($traites++ >= $limite) {
        break;
    }
    $requete = requeteAnglaise($e['nom'], $e['categorie']);
    $categorie = CATEGORIES_PIXABAY[$e['categorie']] ?? null;
    echo "$element  « {$e['nom']} »  →  \"$requete\"" . ($categorie !== null ? " [$categorie]" : '') . "\n";
    if ($simulation) {
        continue;
    }

    // Une photo ne sert qu'une fois dans tout le site (les choix imposés sont réservés)
    $dejaPrises = array_merge($exclues, array_column($credits, 'pixabay_id'), array_values(array_filter($choix)));
    $classees = [];
    if (array_diff($manquantes, array_keys($choix)) !== []) {
        foreach (rechercher($requete, $categorie, cleApi($racine), $journal, $dossierCache) as $p) {
            $note = noter($p, $requete);
            if ($note !== null && !in_array($p['id'], $dejaPrises, true) && !aUnTagExclu($p['tags'])
                && !in_array(strtolower($p['user']), COMPTES_RELAIS, true) && assezGrande($p)) {
                $classees[] = $p + ['note' => $note];
            }
        }
        // Meilleure note d'abord ; à égalité, l'ordre de Pixabay (usort est stable depuis PHP 8)
        usort($classees, static fn (array $a, array $b) => $b['note'] <=> $a['note']);
    }
    // Certains auteurs publient deux fois la même photo : même auteur et mêmes tags = doublon
    $empreinte = static fn (string $auteur, string $tags) => strtolower($auteur) . '|' . strtolower($tags);
    $dejaVues = array_map(static fn (array $c) => $empreinte($c['auteur'], $c['description']), $credits);

    foreach ($manquantes as $cle) {
        if (array_key_exists($cle, $choix) && $choix[$cle] === null) {
            echo "  $cle : illustration SVG imposée (photos_choix.json).\n";
            continue;
        }
        if (isset($choix[$cle])) {
            $photo = photoParId($choix[$cle], cleApi($racine), $journal, $dossierCache);
            if ($photo === null) {
                echo "  $cle : la photo imposée {$choix[$cle]} n'existe pas sur Pixabay, l'illustration SVG reste.\n";
                continue;
            }
            $photo['note'] = null;
        } else {
            do {
                $photo = array_shift($classees);
            } while ($photo !== null && in_array($empreinte($photo['user'], $photo['tags']), $dejaVues, true));
            if ($photo === null) {
                echo "  $cle : aucune photo convenable (mot principal absent, photo déjà prise ou refusée), l'illustration SVG reste.\n";
                continue;
            }
        }
        enregistrerWebp($photo, $dossier . $cle . '.webp');
        $credits[$cle] = [
            'element' => $e['nom'],
            'requete' => $requete,
            'pixabay_id' => $photo['id'],
            'url' => $photo['pageURL'],
            'auteur' => $photo['user'],
            // Adresse publique du profil, de la forme indiquée dans la documentation de l'API
            'auteur_url' => 'https://pixabay.com/users/' . rawurlencode($photo['user']) . '-' . $photo['user_id'] . '/',
            'description' => $photo['tags'],
            'note' => $photo['note'],   // null = photo imposée dans photos_choix.json
        ];
        $dejaVues[] = $empreinte($photo['user'], $photo['tags']);
        ecrireJson($fichierCredits, $credits);   // tout de suite : c'est ce qui permet la reprise
        echo "  $cle : photo {$photo['id']} " . ($photo['note'] === null ? '(imposée)' : "note {$photo['note']}")
            . " ({$photo['tags']})\n";
    }
}

$total = array_sum(array_map(static fn (array $e) => count($e['cles']), $elements));
echo "\n" . count($credits) . " photo(s) sur $total dans public/images/demo/.\n";
