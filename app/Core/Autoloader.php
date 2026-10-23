<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Chargement automatique des classes, écrit à la main (sans Composer).
 *
 * Règle : le nom complet de la classe donne son chemin.
 *   App\Core\Router            → app/Core/Router.php
 *   App\Controllers\Accueil…   → app/Controllers/Accueil….php
 * PHP appelle charger() la première fois qu'une classe inconnue est utilisée.
 */
final class Autoloader
{
    private const PREFIXE = 'App\\';

    public static function enregistrer(string $dossierApp): void
    {
        spl_autoload_register(static function (string $classe) use ($dossierApp): void {
            if (!str_starts_with($classe, self::PREFIXE)) {
                return; // pas une classe du projet : on laisse PHP chercher ailleurs
            }
            $relatif = substr($classe, strlen(self::PREFIXE));
            $fichier = $dossierApp . '/' . str_replace('\\', '/', $relatif) . '.php';
            if (is_file($fichier)) {
                require $fichier;
            }
        });
    }
}
