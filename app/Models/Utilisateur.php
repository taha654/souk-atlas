<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/**
 * Comptes utilisateurs : lectures directes et appels à PKG_UTILISATEUR.
 */
final class Utilisateur
{
    public const MDP_LONGUEUR_MIN = 8;
    // bcrypt n'utilise que les 72 premiers OCTETS et ignore le reste sans
    // prévenir : on refuse plutôt que de tronquer en silence
    public const MDP_OCTETS_MAX = 72;

    public function __construct(private readonly Database $db)
    {
    }

    /** @return array<string, mixed>|null */
    public function trouverParEmail(string $email): ?array
    {
        return $this->db->ligne(
            'SELECT id, email, nom, role, statut, mot_de_passe_hash FROM utilisateur WHERE email = :email',
            ['email' => mb_strtolower(trim($email))],
        );
    }

    /** @return array<string, mixed>|null */
    public function trouverParId(int $id): ?array
    {
        return $this->db->ligne(
            'SELECT id, email, nom, telephone, ville, role, statut, date_creation, date_derniere_connexion
               FROM utilisateur WHERE id = :id',
            ['id' => $id],
        );
    }

    /**
     * Crée le compte via PKG_UTILISATEUR. Le mot de passe est haché ICI, en PHP :
     * Oracle ne voit jamais le mot de passe en clair.
     * PASSWORD_DEFAULT = bcrypt aujourd'hui ; le sel aléatoire est inclus dans le hash.
     *
     * @param array{email: string, nom: string, telephone: string, ville: string, role: string} $donnees
     */
    public function creer(array $donnees, string $motDePasse): int
    {
        $p = [
            'email' => $donnees['email'],
            'hash' => password_hash($motDePasse, PASSWORD_DEFAULT),
            'nom' => $donnees['nom'],
            'telephone' => $donnees['telephone'] === '' ? null : $donnees['telephone'],
            'ville' => $donnees['ville'] === '' ? null : $donnees['ville'],
            'role' => $donnees['role'],
            'id' => null,
        ];
        $this->db->appeler(
            'BEGIN pkg_utilisateur.creer_compte(:email, :hash, :nom, :telephone, :ville, :role, :id); END;',
            $p,
        );
        return (int) $p['id'];
    }

    public function changerHash(int $id, string $motDePasse): void
    {
        $p = ['id' => $id, 'hash' => password_hash($motDePasse, PASSWORD_DEFAULT)];
        $this->db->appeler('BEGIN pkg_utilisateur.changer_hash(:id, :hash); END;', $p);
    }

    public function enregistrerConnexion(int $id): void
    {
        $p = ['id' => $id];
        $this->db->appeler('BEGIN pkg_utilisateur.enregistrer_connexion(:id); END;', $p);
    }

    public function enregistrerTentative(string $email, string $ip, bool $reussie): void
    {
        $p = ['email' => $email, 'ip' => $ip, 'reussie' => $reussie ? 1 : 0];
        $this->db->appeler('BEGIN pkg_utilisateur.enregistrer_tentative(:email, :ip, :reussie); END;', $p);
    }

    public function nbEchecsEmail(string $email, int $minutes): int
    {
        return (int) $this->db->valeur(
            'SELECT pkg_utilisateur.nb_echecs_recents(:email, :minutes) FROM dual',
            ['email' => $email, 'minutes' => $minutes],
        );
    }

    public function nbEchecsIp(string $ip, int $minutes): int
    {
        return (int) $this->db->valeur(
            'SELECT pkg_utilisateur.nb_echecs_ip(:ip, :minutes) FROM dual',
            ['ip' => $ip, 'minutes' => $minutes],
        );
    }

    /**
     * Validation du formulaire d'inscription (fonction pure, sans base : testable seule).
     * Renvoie les erreurs par champ ; un tableau vide signifie "tout est valide".
     *
     * @param array<string, string> $champs
     * @return array<string, string>
     */
    public static function validerInscription(array $champs): array
    {
        $erreurs = [];
        $nom = $champs['nom'] ?? '';
        $email = $champs['email'] ?? '';
        $telephone = $champs['telephone'] ?? '';
        $mdp = $champs['mot_de_passe'] ?? '';

        if (mb_strlen($nom) < 2 || mb_strlen($nom) > 100) {
            $erreurs['nom'] = 'Le nom doit contenir entre 2 et 100 caractères.';
        }
        if (filter_var($email, FILTER_VALIDATE_EMAIL) === false || strlen($email) > 254) {
            $erreurs['email'] = 'Adresse email invalide.';
        }
        // Téléphone marocain facultatif : 0X XX XX XX XX ou +212 X XX XX XX XX
        if ($telephone !== '' && preg_match('/^(\+212\s?|0)[5-7](\s?\d{2}){4}$/', $telephone) !== 1) {
            $erreurs['telephone'] = 'Numéro attendu : 06 12 34 56 78 ou +212 6 12 34 56 78.';
        }
        if (!in_array($champs['role'] ?? '', ['CLIENT', 'VENDEUR'], true)) {
            $erreurs['role'] = 'Choisissez un type de compte.';
        }
        // mb_strlen compte les CARACTÈRES ("é" = 1) ; strlen compte les OCTETS ("é" = 2)
        if (mb_strlen($mdp) < self::MDP_LONGUEUR_MIN) {
            $erreurs['mot_de_passe'] = 'Le mot de passe doit contenir au moins '
                . self::MDP_LONGUEUR_MIN . ' caractères.';
        } elseif (strlen($mdp) > self::MDP_OCTETS_MAX) {
            $erreurs['mot_de_passe'] = 'Le mot de passe est trop long (72 octets au maximum).';
        }
        if (($champs['confirmation'] ?? '') !== $mdp) {
            $erreurs['confirmation'] = 'Les deux mots de passe ne correspondent pas.';
        }
        return $erreurs;
    }
}
