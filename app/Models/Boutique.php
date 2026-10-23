<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

final class Boutique
{
    public function __construct(private readonly Database $db)
    {
    }

    /** @return array<string, mixed>|null */
    public function duVendeur(int $idVendeur): ?array
    {
        return $this->db->ligne(
            'SELECT id, nom, ville, statut,
                    (SELECT COUNT(*) FROM produit p WHERE p.id_boutique = b.id) AS nb_produits
               FROM boutique b WHERE id_vendeur = :id',
            ['id' => $idVendeur],
        );
    }
}
