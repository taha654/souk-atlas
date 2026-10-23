<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

final class Boutique
{
    public const STATUTS = [
        'EN_ATTENTE' => 'en attente de validation par l\'administrateur',
        'VALIDEE' => 'validée : vos produits sont en vente',
        'REFUSEE' => 'refusée par l\'administrateur',
        'SUSPENDUE' => 'suspendue : vos produits ne sont plus visibles',
    ];

    public function __construct(private readonly Database $db)
    {
    }

    /** @return array<string, mixed>|null */
    public function duVendeur(int $idVendeur): ?array
    {
        $ligne = $this->db->ligne(
            'SELECT b.id, b.nom, b.description, b.ville, b.statut, b.date_creation,
                    (SELECT COUNT(*) FROM produit p WHERE p.id_boutique = b.id) AS nb_produits
               FROM boutique b WHERE b.id_vendeur = :id',
            ['id' => $idVendeur],
        );
        return $ligne === null ? null : [
            'id' => (int) $ligne['ID'],
            'nom' => $ligne['NOM'],
            'description' => $ligne['DESCRIPTION'] ?? '',
            'ville' => $ligne['VILLE'] ?? '',
            'statut' => $ligne['STATUT'],
            'date_creation' => $ligne['DATE_CREATION'],
            'nb_produits' => (int) $ligne['NB_PRODUITS'],
        ];
    }

    public function creer(int $idVendeur, string $nom, string $description, string $ville): int
    {
        $p = ['vendeur' => $idVendeur, 'nom' => $nom, 'description' => $description, 'ville' => $ville, 'id' => null];
        $this->db->appeler('BEGIN pkg_utilisateur.creer_boutique(:vendeur, :nom, :description, :ville, :id); END;', $p);
        return (int) $p['id'];
    }

    public function modifier(int $idVendeur, string $nom, string $description, string $ville): void
    {
        $p = ['vendeur' => $idVendeur, 'nom' => $nom, 'description' => $description, 'ville' => $ville];
        $this->db->appeler('BEGIN pkg_utilisateur.modifier_boutique(:vendeur, :nom, :description, :ville); END;', $p);
    }

    /** @param array<string, string> $champs @return array<string, string> */
    public static function validerFormulaire(array $champs): array
    {
        $erreurs = [];
        if (mb_strlen($champs['nom'] ?? '') < 3 || mb_strlen($champs['nom'] ?? '') > 100) {
            $erreurs['nom'] = 'Le nom de la boutique doit faire entre 3 et 100 caractères.';
        }
        if (mb_strlen($champs['description'] ?? '') > 2000) {
            $erreurs['description'] = 'La description est limitée à 2000 caractères.';
        }
        if (mb_strlen($champs['ville'] ?? '') < 2 || mb_strlen($champs['ville'] ?? '') > 60) {
            $erreurs['ville'] = 'Indiquez la ville de la boutique.';
        }
        return $erreurs;
    }
}
