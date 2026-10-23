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
