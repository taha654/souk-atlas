<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Session PHP sécurisée.
 *
 * Réglages fixes dans docker/php/souk.ini : use_strict_mode, use_only_cookies,
 * cookie HttpOnly et SameSite=Lax. Ici, ce qui dépend de la requête et du .env :
 *  - le flag Secure du cookie ;
 *  - l'expiration après une période d'inactivité.
 */
final class Session
{
    private const CLE_ACTIVITE = '_derniere_activite';
    private const CLE_FLASH = '_flash';

    private static bool $vientDExpirer = false;

    /**
     * @param array{nom: string, inactivite_secondes: int, cookie_secure_force: bool} $config
     */
    public static function demarrer(array $config, bool $requeteHttps): void
    {
        $inactivite = $config['inactivite_secondes'];

        // Le ramasse-miettes de PHP ne doit pas supprimer une session encore valable
        ini_set('session.gc_maxlifetime', (string) max($inactivite, 60));
        session_name($config['nom']);
        session_set_cookie_params([
            'lifetime' => 0,        // cookie "de session" : effacé à la fermeture du navigateur
            'path' => '/',
            // Secure : le navigateur n'envoie le cookie QUE sur une connexion HTTPS.
            // En HTTP, le cookie circule en clair : sur un Wi-Fi public, un voisin
            // peut le lire et se connecter à la place de l'utilisateur. On ne
            // l'active pas en local (http://localhost), sinon le cookie ne serait
            // pas renvoyé de façon fiable et la session serait perdue à chaque page.
            'secure' => $requeteHttps || $config['cookie_secure_force'],
            'httponly' => true,
            'samesite' => 'Lax',
        ]);
        session_start();

        // Expiration après inactivité : on compare l'heure actuelle à celle de
        // la dernière requête. Trop ancienne → la session est entièrement détruite.
        $maintenant = time();
        $derniere = $_SESSION[self::CLE_ACTIVITE] ?? null;
        if (is_int($derniere) && $maintenant - $derniere > $inactivite) {
            self::detruire();
            session_start();
            self::$vientDExpirer = true;
        }
        $_SESSION[self::CLE_ACTIVITE] = $maintenant;
    }

    /** Vrai si la session de cette requête vient d'être détruite pour inactivité */
    public static function vientDExpirer(): bool
    {
        return self::$vientDExpirer;
    }

    public static function get(string $cle, mixed $defaut = null): mixed
    {
        return $_SESSION[$cle] ?? $defaut;
    }

    public static function set(string $cle, mixed $valeur): void
    {
        $_SESSION[$cle] = $valeur;
    }

    public static function retirer(string $cle): void
    {
        unset($_SESSION[$cle]);
    }

    /**
     * Nouvel identifiant de session, en gardant les données. À appeler à chaque
     * changement de privilège (connexion) : un identifiant connu d'un attaquant
     * avant la connexion ne vaut plus rien après (fixation de session).
     */
    public static function regenerer(): void
    {
        session_regenerate_id(true); // true : l'ancienne session est supprimée du serveur
    }

    public static function detruire(): void
    {
        $_SESSION = [];
        if (session_status() === PHP_SESSION_ACTIVE) {
            session_destroy();
        }
    }

    /** Message affiché une seule fois, à la page suivante ("Bienvenue !") */
    public static function flash(string $type, string $message): void
    {
        $_SESSION[self::CLE_FLASH][] = ['type' => $type, 'message' => $message];
    }

    /** @return list<array{type: string, message: string}> */
    public static function lireFlashs(): array
    {
        $flashs = $_SESSION[self::CLE_FLASH] ?? [];
        unset($_SESSION[self::CLE_FLASH]);
        return $flashs;
    }
}
