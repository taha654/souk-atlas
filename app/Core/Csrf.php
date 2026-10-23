<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Protection CSRF (Cross-Site Request Forgery).
 *
 * L'attaque : un site malveillant contient un formulaire caché qui envoie un
 * POST vers notre site. Le navigateur y joint automatiquement le cookie de
 * session de la victime : sans protection, l'action serait faite en son nom.
 *
 * La parade : chaque formulaire contient un jeton secret, stocké en session.
 * Le site malveillant ne peut pas le lire, donc ne peut pas le recopier.
 */
final class Csrf
{
    public const CHAMP = '_csrf';
    private const CLE_SESSION = '_csrf_jeton';

    public static function jeton(): string
    {
        $jeton = Session::get(self::CLE_SESSION);
        if (!is_string($jeton)) {
            // random_bytes : générateur cryptographique (rand() serait prévisible)
            $jeton = bin2hex(random_bytes(32));
            Session::set(self::CLE_SESSION, $jeton);
        }
        return $jeton;
    }

    public static function verifier(?string $jetonRecu): bool
    {
        $jeton = Session::get(self::CLE_SESSION);
        // hash_equals compare en temps constant : la durée de la comparaison ne
        // révèle pas combien de caractères étaient corrects
        return is_string($jeton) && is_string($jetonRecu) && hash_equals($jeton, $jetonRecu);
    }

    /** Nouveau jeton (à la connexion et à la déconnexion) */
    public static function renouveler(): void
    {
        Session::retirer(self::CLE_SESSION);
    }

    /** Champ caché à placer dans chaque formulaire POST */
    public static function champ(): string
    {
        return '<input type="hidden" name="' . self::CHAMP . '" value="' . e(self::jeton()) . '">';
    }
}
