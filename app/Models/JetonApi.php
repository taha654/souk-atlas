<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;
use App\Core\Erreurs\ErreurMetier;

/**
 * Jetons d'accès à l'API pour l'outil console C++ (PKG_UTILISATEUR).
 *
 * Le jeton est un secret aléatoire de 256 bits, montré UNE seule fois à sa
 * création. La base ne garde que son empreinte SHA-256 : comme pour un mot de
 * passe, une fuite de la table ne donne aucun jeton utilisable.
 * Pourquoi SHA-256 et pas password_hash (bcrypt) ? bcrypt est volontairement
 * lent pour résister à l'essai de millions de mots de passe humains, faciles à
 * deviner. Un jeton de 256 bits tirés au hasard est impossible à deviner : un
 * hachage rapide suffit, et la vérification reste rapide à chaque requête.
 */
final class JetonApi
{
    public const PREFIXE = 'souk_';
    public const DUREES = [7, 30, 90, 365];

    public function __construct(private readonly Database $db)
    {
    }

    public static function generer(): string
    {
        // random_bytes : générateur cryptographique du système (et non rand())
        return self::PREFIXE . bin2hex(random_bytes(32));
    }

    public static function empreinte(string $jeton): string
    {
        return hash('sha256', $jeton);
    }

    /** @return array{id: int, jeton: string}  le jeton en clair, à afficher une seule fois */
    public function creer(int $idUtilisateur, string $libelle, int $jours): array
    {
        $jeton = self::generer();
        $p = ['u' => $idUtilisateur, 'empreinte' => self::empreinte($jeton), 'libelle' => $libelle,
              'jours' => $jours, 'id' => null];
        $this->db->appeler('BEGIN pkg_utilisateur.creer_jeton(:u, :empreinte, :libelle, :jours, :id); END;', $p);
        return ['id' => (int) $p['id'], 'jeton' => $jeton];
    }

    public function revoquer(int $id, int $idUtilisateur): void
    {
        $p = ['id' => $id, 'u' => $idUtilisateur];
        $this->db->appeler('BEGIN pkg_utilisateur.revoquer_jeton(:id, :u); END;', $p);
    }

    /** @return list<array{id: int, libelle: string, creation: string, expiration: string, derniere_utilisation: ?string, etat: string}> */
    public function liste(int $idUtilisateur): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'libelle' => $l['LIBELLE'], 'creation' => $l['DATE_CREATION'],
            'expiration' => $l['DATE_EXPIRATION'], 'derniere_utilisation' => $l['DATE_DERNIERE_UTILISATION'],
            'etat' => $l['ETAT'],
        ], $this->db->lignes(
            "SELECT id, libelle, date_creation, date_expiration, date_derniere_utilisation,
                    CASE WHEN revoque = 1 THEN 'Révoqué' WHEN date_expiration <= SYSDATE THEN 'Expiré' ELSE 'Valide' END AS etat
               FROM jeton_api WHERE id_utilisateur = :u ORDER BY date_creation DESC, id DESC",
            ['u' => $idUtilisateur]));
    }

    /**
     * Compte associé à un jeton valide, ou null (inconnu, expiré, révoqué, compte désactivé).
     *
     * @return array{id: int, nom: string, role: string}|null
     */
    public function utilisateur(string $jeton): ?array
    {
        if (!str_starts_with($jeton, self::PREFIXE) || strlen($jeton) !== strlen(self::PREFIXE) + 64) {
            return null;   // inutile d'interroger la base pour un jeton mal formé
        }
        $p = ['empreinte' => self::empreinte($jeton), 'id' => null, 'role' => null];
        try {
            $this->db->appeler('BEGIN pkg_utilisateur.utilisateur_du_jeton(:empreinte, :id, :role); END;', $p);
        } catch (ErreurMetier $erreur) {
            if ($erreur->codeOracle === ErreurMetier::COMPTE_INTROUVABLE) {
                return null;
            }
            throw $erreur;
        }
        $nom = (string) $this->db->valeur('SELECT nom FROM utilisateur WHERE id = :id', ['id' => (int) $p['id']]);
        return ['id' => (int) $p['id'], 'nom' => $nom, 'role' => (string) $p['role']];
    }
}
