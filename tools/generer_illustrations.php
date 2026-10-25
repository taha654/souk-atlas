<?php
// =============================================================================
// Génère les illustrations SVG des produits de démonstration, une par ligne de
// PRODUIT_PHOTO (les chemins viennent de la base : une seule source de vérité).
// Depuis l'arrivée des photos Pixabay, la base pointe vers /images/demo/*.webp :
// l'illustration de même nom sert d'image de repli (App\Services\PhotosDemo).
//
//   docker compose exec --user "$(id -u):$(id -g)" php php tools/generer_illustrations.php
// (--user : les fichiers appartiennent à votre utilisateur, pas à root)
//
// Couleur et pictogramme dépendent de la catégorie racine du produit ;
// chaque "vue" (1, 2, 3) varie le décor. Fichiers libres de droits, légers.
// =============================================================================
declare(strict_types=1);

use App\Core\Database;
use App\Services\PhotosDemo;

$racine = dirname(__DIR__);
require $racine . '/app/Core/Autoloader.php';
App\Core\Autoloader::enregistrer($racine . '/app');
$config = require $racine . '/app/config.php';

// Catégorie racine → [couleur foncée, couleur claire, pictogramme]
const THEMES = [
    'Électronique'     => ['#1f3a93', '#dfe6fb', 'ecran'],
    'Maison & cuisine' => ['#b4532a', '#fbe7dc', 'maison'],
    'Mode'             => ['#6b3a7e', '#efe2f4', 'vetement'],
    'Beauté & santé'   => ['#a8475f', '#f8e1e7', 'flacon'],
    'Sport & loisirs'  => ['#1e6b3a', '#dcf1e3', 'ballon'],
    'Bébé & jouets'    => ['#a86a12', '#f9ecd6', 'etoile'],
    'Véhicules'        => ['#2f4f4f', '#e2ecec', 'voiture'],
    'Immobilier'       => ['#5a4a8a', '#e9e5f5', 'maison'],
];

/** Pictogrammes : formes simples centrées sur (300, 175) */
function pictogramme(string $type, string $couleur): string
{
    return match ($type) {
        'ecran' => "<rect x='240' y='95' width='120' height='170' rx='16' fill='$couleur'/>"
            . "<rect x='252' y='112' width='96' height='128' rx='4' fill='#fff' opacity='.85'/>"
            . "<circle cx='300' cy='252' r='6' fill='#fff'/>",
        'maison' => "<polygon points='300,90 385,160 360,160 360,255 240,255 240,160 215,160' fill='$couleur'/>"
            . "<rect x='282' y='200' width='36' height='55' fill='#fff' opacity='.85'/>",
        'vetement' => "<path d='M255 95 L215 125 L238 160 L255 148 L255 260 L345 260 L345 148 L362 160 L385 125 "
            . "L345 95 Q300 130 255 95 Z' fill='$couleur'/>",
        'flacon' => "<rect x='283' y='88' width='34' height='30' rx='4' fill='$couleur'/>"
            . "<rect x='250' y='118' width='100' height='145' rx='24' fill='$couleur'/>"
            . "<rect x='268' y='160' width='64' height='50' rx='6' fill='#fff' opacity='.85'/>",
        'ballon' => "<circle cx='300' cy='175' r='85' fill='$couleur'/>"
            . "<path d='M215 175 H385 M300 90 V260' stroke='#fff' stroke-width='6' opacity='.85'/>"
            . "<circle cx='300' cy='175' r='45' fill='none' stroke='#fff' stroke-width='6' opacity='.85'/>",
        'voiture' => "<path d='M215 210 L235 160 Q240 148 255 148 L345 148 Q360 148 365 160 L385 210 L385 245 L215 245 Z' fill='$couleur'/>"
            . "<rect x='250' y='162' width='100' height='38' rx='6' fill='#fff' opacity='.85'/>"
            . "<circle cx='250' cy='248' r='20' fill='#1d1d1f'/><circle cx='350' cy='248' r='20' fill='#1d1d1f'/>",
        default => "<polygon points='300,88 324,148 388,150 337,190 356,252 300,215 244,252 263,190 212,150 276,148' "
            . "fill='$couleur'/>",
    };
}

/** Découpe le nom en 3 lignes de 26 caractères au plus (sans couper les mots) */
function lignes(string $texte): array
{
    $lignes = explode("\n", wordwrap($texte, 26, "\n", true));
    if (count($lignes) > 3) {
        $lignes = array_slice($lignes, 0, 3);
        $lignes[2] = rtrim(mb_substr($lignes[2], 0, 24)) . '…';
    }
    return $lignes;
}

function svg(string $nom, string $racineCategorie, int $vue, int $nbVues): string
{
    [$fonce, $clair, $picto] = THEMES[$racineCategorie] ?? ['#55565b', '#ececec', 'etoile'];
    // Échappement XML : un nom comme "Plateau & thé" casserait le fichier sinon
    $x = static fn (string $t): string => htmlspecialchars($t, ENT_XML1 | ENT_QUOTES, 'UTF-8');

    // Chaque vue a son propre décor
    $decor = match ($vue) {
        1 => "<circle cx='520' cy='60' r='110' fill='$fonce' opacity='.08'/>"
            . "<circle cx='60' cy='400' r='90' fill='$fonce' opacity='.08'/>",
        2 => "<rect x='-40' y='300' width='700' height='200' fill='$fonce' opacity='.07' transform='rotate(-8 300 400)'/>",
        default => "<path d='M0 0 L600 0 L600 120 Q300 40 0 120 Z' fill='$fonce' opacity='.07'/>",
    };
    $texte = '';
    foreach (lignes($nom) as $i => $ligne) {
        $texte .= "<text x='300' y='" . (320 + $i * 30) . "' text-anchor='middle' font-size='24' "
            . "font-family='system-ui, sans-serif' font-weight='600' fill='#1d1d1f'>" . $x($ligne) . '</text>';
    }

    return "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 600 450' width='600' height='450' role='img'>"
        . '<title>' . $x($nom) . " (vue $vue)</title>"
        . "<rect width='600' height='450' fill='$clair'/>" . $decor . pictogramme($picto, $fonce) . $texte
        . "<text x='580' y='435' text-anchor='end' font-size='14' font-family='system-ui, sans-serif' "
        . "fill='$fonce'>Illustration $vue/$nbVues · Souk Atlas</text></svg>\n";
}

$db = new Database($config['db']);
$photos = $db->lignes(
    "SELECT ph.chemin, ph.ordre, p.nom,
            (SELECT COUNT(*) FROM produit_photo x WHERE x.id_produit = p.id) AS nb_vues,
            -- On remonte l'arbre ; la racine est la seule ligne sans parent
            (SELECT c.nom FROM categorie c WHERE c.id_parent IS NULL
              START WITH c.id = p.id_categorie CONNECT BY c.id = PRIOR c.id_parent) AS racine
       FROM produit_photo ph JOIN produit p ON p.id = ph.id_produit
     UNION ALL
     -- Annonces : une illustration chacune, même principe
     SELECT ph.chemin, ph.ordre, a.titre, 1,
            (SELECT c.nom FROM categorie c WHERE c.id_parent IS NULL
              START WITH c.id = a.id_categorie CONNECT BY c.id = PRIOR c.id_parent)
       FROM annonce_photo ph JOIN annonce a ON a.id = ph.id_annonce
      ORDER BY 1",
);

foreach (['produits', 'annonces'] as $sousDossier) {
    if (!is_dir($racine . '/public/assets/img/' . $sousDossier)) {
        mkdir($racine . '/public/assets/img/' . $sousDossier, 0755, true);
    }
}
// Photos envoyées par les utilisateurs : pas d'illustration
$photos = array_filter($photos, static fn (array $p) => PhotosDemo::cle($p['CHEMIN']) !== null);
foreach ($photos as $photo) {
    file_put_contents($racine . '/public' . PhotosDemo::illustration(PhotosDemo::cle($photo['CHEMIN'])),
        svg($photo['NOM'], (string) $photo['RACINE'], (int) $photo['ORDRE'], (int) $photo['NB_VUES']));
}
echo count($photos) . " illustration(s) générée(s) dans public/assets/img/produits/ et annonces/\n";
