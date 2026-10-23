<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

final class Categorie
{
    public function __construct(private readonly Database $db)
    {
    }

    /**
     * Arbre complet, dans l'ordre d'affichage (parent puis enfants), avec le
     * nombre de produits visibles de chaque catégorie ET de ses sous-catégories.
     *
     * @return list<array{id: int, nom: string, id_parent: ?int, niveau: int, nb_produits: int}>
     */
    public function arbre(): array
    {
        // Le comptage cumulé (sous-catégories comprises) se fait en SQL : pour
        // chaque catégorie, on parcourt sa descendance avec CONNECT BY
        $lignes = $this->db->lignes(
            "SELECT c.id, c.nom, c.id_parent, LEVEL AS niveau,
                    (SELECT COUNT(*)
                       FROM produit p JOIN boutique b ON b.id = p.id_boutique
                      WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE'
                        AND p.id_categorie IN (SELECT d.id FROM categorie d
                                                START WITH d.id = c.id
                                              CONNECT BY PRIOR d.id = d.id_parent)) AS nb_produits
               FROM categorie c
              START WITH c.id_parent IS NULL
            CONNECT BY PRIOR c.id = c.id_parent
              -- Tri français : « Électronique » avant « Maison » (un tri binaire la mettrait après « Sport »)
              ORDER SIBLINGS BY NLSSORT(c.nom, 'NLS_SORT=FRENCH')",
        );
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'],
            'nom' => $l['NOM'],
            'id_parent' => $l['ID_PARENT'] === null ? null : (int) $l['ID_PARENT'],
            'niveau' => (int) $l['NIVEAU'],
            'nb_produits' => (int) $l['NB_PRODUITS'],
        ], $lignes);
    }

    public function creer(string $nom, ?int $idParent): int
    {
        $p = ['nom' => $nom, 'parent' => $idParent, 'id' => null];
        $this->db->appeler('BEGIN pkg_catalogue.creer_categorie(:nom, :parent, :id); END;', $p);
        return (int) $p['id'];
    }

    public function renommer(int $id, string $nom): void
    {
        $p = ['id' => $id, 'nom' => $nom];
        $this->db->appeler('BEGIN pkg_catalogue.renommer_categorie(:id, :nom); END;', $p);
    }

    public function supprimer(int $id): void
    {
        $p = ['id' => $id];
        $this->db->appeler('BEGIN pkg_catalogue.supprimer_categorie(:id); END;', $p);
    }

    /** Nombre d'annonces EN LIGNE par catégorie (pour l'écran d'administration) @return array<int, int> */
    public function nbAnnoncesParCategorie(): array
    {
        $compte = [];
        foreach ($this->db->lignes('SELECT id_categorie, COUNT(*) AS nb FROM annonce GROUP BY id_categorie') as $l) {
            $compte[(int) $l['ID_CATEGORIE']] = (int) $l['NB'];
        }
        return $compte;
    }

    /**
     * Fil d'Ariane, de la racine à la catégorie : [['id' => 1, 'nom' => 'Électronique'], …]
     *
     * @return list<array{id: int, nom: string}>
     */
    public function chemin(int $id): array
    {
        $lignes = $this->db->lignes(
            'SELECT id, nom FROM categorie
              START WITH id = :id CONNECT BY id = PRIOR id_parent
              ORDER BY LEVEL DESC',
            ['id' => $id],
        );
        return array_map(static fn (array $l) => ['id' => (int) $l['ID'], 'nom' => $l['NOM']], $lignes);
    }
}
