<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

final class Promotion
{
    public function __construct(private readonly Database $db)
    {
    }

    /** @return list<array<string, mixed>> */
    public function liste(): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'libelle' => $l['LIBELLE'], 'pourcentage' => (float) $l['POURCENTAGE'],
            'debut' => $l['DATE_DEBUT'], 'fin' => $l['DATE_FIN'], 'actif' => (int) $l['ACTIF'] === 1,
            'cible' => $l['CIBLE'], 'etat' => $l['ETAT'],
        ], $this->db->lignes(
            "SELECT pr.id, pr.libelle, pr.pourcentage, pr.date_debut, pr.date_fin, pr.actif,
                    COALESCE('Produit : ' || p.nom, 'Catégorie : ' || pkg_catalogue.chemin_categorie(pr.id_categorie)) AS cible,
                    CASE WHEN pr.actif = 0 THEN 'TERMINEE'
                         WHEN SYSDATE < pr.date_debut THEN 'A_VENIR'
                         WHEN SYSDATE > pr.date_fin THEN 'TERMINEE'
                         ELSE 'EN_COURS' END AS etat
               FROM promotion pr LEFT JOIN produit p ON p.id = pr.id_produit
              ORDER BY pr.date_debut DESC"));
    }

    public function creer(string $libelle, float $pourcentage, string $debut, string $fin, ?int $idProduit, ?int $idCategorie): int
    {
        $p = ['libelle' => $libelle, 'pct' => $pourcentage, 'debut' => $debut, 'fin' => $fin,
              'produit' => $idProduit, 'categorie' => $idCategorie, 'id' => null];
        // Dates reçues au format ISO (champ <input type="date">) ; la fin couvre toute la journée
        $this->db->appeler("BEGIN pkg_catalogue.creer_promotion(:libelle, :pct, TO_DATE(:debut, 'YYYY-MM-DD'),
                                TO_DATE(:fin, 'YYYY-MM-DD') + 1 - 1/86400, :produit, :categorie, :id); END;", $p);
        return (int) $p['id'];
    }

    public function desactiver(int $id): void
    {
        $p = ['id' => $id];
        $this->db->appeler('BEGIN pkg_catalogue.desactiver_promotion(:id); END;', $p);
    }
}
