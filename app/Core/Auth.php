<?php
declare(strict_types=1);

namespace App\Core;

use App\Core\Erreurs\AccesRefuse;
use App\Core\Erreurs\NonConnecte;

/**
 * Utilisateur connecté et contrôle des rôles.
 *
 * Le contrôle se fait CÔTÉ SERVEUR, dans chaque action, avec exigerRole().
 * Masquer un lien dans le menu ne protège rien : n'importe qui peut taper l'URL.
 */
final class Auth
{
    private const CLE = '_utilisateur';

    /** @var array{id: int, nom: string, email: string, role: string}|null */
    private static ?array $utilisateur = null;

    /**
     * À chaque requête, on relit le compte en base : un compte désactivé ou
     * dont le rôle a changé est pris en compte immédiatement, sans attendre
     * que l'utilisateur se reconnecte.
     */
    public static function charger(Database $db): void
    {
        $id = Session::get(self::CLE);
        if (!is_int($id)) {
            return;
        }
        $ligne = $db->ligne(
            'SELECT id, nom, email, role, statut FROM utilisateur WHERE id = :id',
            ['id' => $id],
        );
        if ($ligne === null || $ligne['STATUT'] !== 'ACTIF') {
            self::deconnecter();
            return;
        }
        self::$utilisateur = [
            'id' => (int) $ligne['ID'],
            'nom' => $ligne['NOM'],
            'email' => $ligne['EMAIL'],
            'role' => $ligne['ROLE'],
        ];
    }

    public static function connecter(int $idUtilisateur): void
    {
        // Changement de privilège : nouvel identifiant de session et nouveau jeton CSRF
        Session::regenerer();
        Csrf::renouveler();
        Session::set(self::CLE, $idUtilisateur);
    }

    public static function deconnecter(): void
    {
        self::$utilisateur = null;
        Session::retirer(self::CLE);
        Session::regenerer();
        Csrf::renouveler();
    }

    /** @return array{id: int, nom: string, email: string, role: string}|null */
    public static function utilisateur(): ?array
    {
        return self::$utilisateur;
    }

    public static function estConnecte(): bool
    {
        return self::$utilisateur !== null;
    }

    public static function aLeRole(string ...$roles): bool
    {
        return self::$utilisateur !== null && in_array(self::$utilisateur['role'], $roles, true);
    }

    /**
     * Arrête l'action si l'utilisateur n'a pas l'un des rôles demandés.
     *
     * @return array{id: int, nom: string, email: string, role: string}
     * @throws NonConnecte  visiteur : redirection vers /connexion
     * @throws AccesRefuse  connecté avec un autre rôle : 403
     */
    public static function exigerRole(string ...$roles): array
    {
        if (self::$utilisateur === null) {
            throw new NonConnecte();
        }
        if (!in_array(self::$utilisateur['role'], $roles, true)) {
            throw new AccesRefuse('Rôle ' . self::$utilisateur['role'] . ' insuffisant');
        }
        return self::$utilisateur;
    }

    /** Page d'accueil propre à chaque rôle, après la connexion */
    public static function accueilDuRole(string $role): string
    {
        return match ($role) {
            'ADMIN' => '/admin',
            'VENDEUR' => '/vendeur',
            default => '/compte',
        };
    }

    /**
     * Le paramètre ?retour=… vient du navigateur : on n'accepte qu'un chemin
     * interne. Sinon, un lien piégé /connexion?retour=https://site-pirate.ma
     * renverrait la victime, juste connectée, vers un faux site (open redirect).
     */
    public static function retourSur(string $retour): ?string
    {
        // Un seul "/" au début ("//site.ma" est une URL externe pour le navigateur),
        // pas de "\" (certains navigateurs le lisent comme "/")
        if (preg_match('#^/(?![/\\\\])[^\\\\\s]*$#', $retour) !== 1) {
            return null;
        }
        return $retour;
    }
}
