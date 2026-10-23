<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Gabarits PHP : un fichier de app/Views/ produit le contenu de la page,
 * puis le layout l'entoure (en-tête, menu, pied de page).
 *
 *   View::rendre('auth/connexion', ['email' => $email], 'Connexion');
 */
final class View
{
    private static string $dossier = __DIR__ . '/../Views';

    /** @var array<string, mixed> données communes à toutes les pages (ex. nombre d'articles du panier) */
    private static array $partage = [];

    public static function partager(string $cle, mixed $valeur): void
    {
        self::$partage[$cle] = $valeur;
    }

    public static function partage(string $cle, mixed $defaut = null): mixed
    {
        return self::$partage[$cle] ?? $defaut;
    }

    /** @param array<string, mixed> $donnees variables disponibles dans le gabarit */
    public static function rendre(string $gabarit, array $donnees = [], string $titre = 'Souk Atlas',
                                  string $layout = 'layouts/principal'): string
    {
        $contenu = self::fragment($gabarit, $donnees);
        return self::fragment($layout, ['contenu' => $contenu, 'titre' => $titre]);
    }

    /** @param array<string, mixed> $donnees */
    public static function fragment(string $gabarit, array $donnees = []): string
    {
        $fichier = self::$dossier . '/' . $gabarit . '.php';
        if (!is_file($fichier)) {
            throw new \RuntimeException('Gabarit introuvable : ' . $gabarit);
        }
        // extract transforme ['email' => …] en variable $email dans le gabarit ;
        // ob_start capture ce que le gabarit affiche au lieu de l'envoyer
        extract($donnees, EXTR_SKIP);
        ob_start();
        try {
            require $fichier;
            return (string) ob_get_clean();
        } catch (\Throwable $erreur) {
            ob_end_clean();
            throw $erreur;
        }
    }
}
