<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

final class Avis
{
    public function __construct(private readonly Database $db)
    {
    }

    /** Via PKG_AVIS : uniquement après livraison, un seul avis par produit (erreurs -20010 / -20017) */
    public function deposer(int $idUtilisateur, int $idProduit, int $note, string $commentaire): void
    {
        $p = ['u' => $idUtilisateur, 'p' => $idProduit, 'note' => $note,
              'commentaire' => $commentaire === '' ? null : $commentaire, 'id' => null];
        $this->db->appeler('BEGIN pkg_avis.deposer(:u, :p, :note, :commentaire, :id); END;', $p);
    }
}
