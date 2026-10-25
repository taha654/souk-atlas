<?php
declare(strict_types=1);

namespace App\Services;

/**
 * Photos des données de démonstration.
 *
 * Chaque photo de démo existe sous deux formes, reliées par leur nom de fichier :
 *   /images/demo/produit-12-1.webp      vraie photo (Pixabay, tools/photos_demo.php)
 *   /assets/img/produits/produit-12-1.svg  illustration de repli (tools/generer_illustrations.php)
 * La base enregistre la photo WebP ; l'illustration sert si la photo manque
 * (photos-repli.js côté navigateur). Les crédits sont dans credits.json.
 */
final class PhotosDemo
{
    public const DOSSIER = '/images/demo/';
    public const CREDITS = '/images/demo/credits.json';

    /** "produit-12-1" ou "annonce-7" → chemin de la photo WebP */
    public static function photo(string $cle): string
    {
        return self::DOSSIER . $cle . '.webp';
    }

    /** "produit-12-1" ou "annonce-7" → chemin de l'illustration SVG de repli */
    public static function illustration(string $cle): string
    {
        $sousDossier = str_starts_with($cle, 'annonce-') ? 'annonces' : 'produits';
        return '/assets/img/' . $sousDossier . '/' . $cle . '.svg';
    }

    /** Clé d'un chemin de démo (WebP ou SVG), null pour une photo envoyée par un utilisateur */
    public static function cle(string $chemin): ?string
    {
        $motif = '#^(?:/images/demo|/assets/img/(?:produits|annonces))/((?:produit-\d+-\d+)|(?:annonce-\d+))\.(?:webp|svg)$#';
        return preg_match($motif, $chemin, $m) === 1 ? $m[1] : null;
    }

    /**
     * Crédits des photos, triés comme le site (produits puis annonces).
     * @return array<string, array<string, mixed>>
     */
    public static function credits(string $dossierPublic): array
    {
        $fichier = $dossierPublic . self::CREDITS;
        if (!is_file($fichier)) {
            return [];
        }
        $credits = json_decode((string) file_get_contents($fichier), true, 8, JSON_THROW_ON_ERROR);
        // Tri naturel : produit-2 avant produit-10
        uksort($credits, 'strnatcmp');
        return $credits;
    }
}
