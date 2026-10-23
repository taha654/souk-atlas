<?php
declare(strict_types=1);

namespace App\Core;

/** Configuration de l'application (app/config.php), chargée une fois par le contrôleur frontal */
final class Config
{
    /** @var array<string, mixed> */
    private static array $valeurs = [];

    /** @param array<string, mixed> $valeurs */
    public static function charger(array $valeurs): void
    {
        self::$valeurs = $valeurs;
    }

    public static function get(string $cle): mixed
    {
        if (!array_key_exists($cle, self::$valeurs)) {
            throw new \RuntimeException('Clé de configuration inconnue : ' . $cle);
        }
        return self::$valeurs[$cle];
    }
}
