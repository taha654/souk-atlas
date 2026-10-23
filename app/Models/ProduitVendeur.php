<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/**
 * Produits vus par leur vendeur : tous les produits de SA boutique, y compris
 * inactifs ou épuisés. Chaque écriture passe par PKG_CATALOGUE, qui vérifie en
 * base que le produit appartient bien à la boutique (-20012 sinon).
 */
final class ProduitVendeur
{
    public const PRIX_MAX = 10_000_000;
    public const STOCK_MAX = 1_000_000;

    public function __construct(private readonly Database $db)
    {
    }

    /** @return list<array<string, mixed>> */
    public function liste(int $idBoutique): array
    {
        $lignes = $this->db->lignes(
            "SELECT p.id, p.nom, p.prix_ht, p.stock, p.statut, p.nb_avis, p.note_moyenne,
                    pkg_catalogue.prix_courant_ttc(p.id) AS prix_ttc,
                    (SELECT MIN(ph.chemin) KEEP (DENSE_RANK FIRST ORDER BY ph.ordre)
                       FROM produit_photo ph WHERE ph.id_produit = p.id) AS photo,
                    (SELECT NVL(SUM(cl.quantite), 0) FROM commande_ligne cl JOIN commande c ON c.id = cl.id_commande
                      WHERE cl.id_produit = p.id AND c.statut <> 'ANNULEE') AS vendus
               FROM produit p
              WHERE p.id_boutique = :boutique
              ORDER BY p.statut, p.nom",
            ['boutique' => $idBoutique],
        );
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'],
            'nom' => $l['NOM'],
            'prix_ht' => (float) $l['PRIX_HT'],
            'prix_ttc' => (float) $l['PRIX_TTC'],
            'stock' => (int) $l['STOCK'],
            'statut' => $l['STATUT'],
            'nb_avis' => (int) $l['NB_AVIS'],
            'note_moyenne' => $l['NOTE_MOYENNE'] === null ? null : (float) $l['NOTE_MOYENNE'],
            'photo' => $l['PHOTO'],
            'vendus' => (int) $l['VENDUS'],
        ], $lignes);
    }

    /**
     * Produit de la boutique (quel que soit son statut), avec ses photos ; null
     * s'il n'existe pas ou appartient à une autre boutique.
     *
     * @return array<string, mixed>|null
     */
    public function fiche(int $id, int $idBoutique): ?array
    {
        $l = $this->db->ligne(
            'SELECT id, nom, description, id_categorie, prix_ht, stock, statut FROM produit
              WHERE id = :id AND id_boutique = :boutique',
            ['id' => $id, 'boutique' => $idBoutique],
        );
        if ($l === null) {
            return null;
        }
        return [
            'id' => (int) $l['ID'],
            'nom' => $l['NOM'],
            'description' => $l['DESCRIPTION'] ?? '',
            'id_categorie' => (int) $l['ID_CATEGORIE'],
            'prix_ht' => (float) $l['PRIX_HT'],
            'stock' => (int) $l['STOCK'],
            'statut' => $l['STATUT'],
            'photos' => array_map(static fn (array $ph) => ['id' => (int) $ph['ID'], 'chemin' => $ph['CHEMIN']],
                $this->db->lignes('SELECT id, chemin FROM produit_photo WHERE id_produit = :id ORDER BY ordre', ['id' => $id])),
            'historique_prix' => $this->db->lignes(
                'SELECT ancien_prix_ht, nouveau_prix_ht, date_changement FROM historique_prix
                  WHERE id_produit = :id ORDER BY date_changement DESC FETCH FIRST 5 ROWS ONLY',
                ['id' => $id]),
        ];
    }

    /** @param array{nom: string, description: string, id_categorie: int, prix_ht: float, stock: int} $v */
    public function creer(int $idBoutique, array $v): int
    {
        $p = ['boutique' => $idBoutique, 'categorie' => $v['id_categorie'], 'nom' => $v['nom'],
              'description' => $v['description'], 'prix' => $v['prix_ht'], 'stock' => $v['stock'], 'id' => null];
        $this->db->appeler('BEGIN pkg_catalogue.creer_produit(:boutique, :categorie, :nom, :description,
                                                              :prix, :stock, :id); END;', $p);
        return (int) $p['id'];
    }

    /** @param array{nom: string, description: string, id_categorie: int, prix_ht: float, statut: string} $v */
    public function modifier(int $id, int $idBoutique, array $v): void
    {
        $p = ['id' => $id, 'boutique' => $idBoutique, 'categorie' => $v['id_categorie'], 'nom' => $v['nom'],
              'description' => $v['description'], 'prix' => $v['prix_ht'], 'statut' => $v['statut']];
        $this->db->appeler('BEGIN pkg_catalogue.modifier_produit(:id, :boutique, :categorie, :nom, :description,
                                                                 :prix, :statut); END;', $p);
    }

    public function ajusterStock(int $id, int $idBoutique, int $delta): void
    {
        $p = ['id' => $id, 'boutique' => $idBoutique, 'delta' => $delta];
        $this->db->appeler('BEGIN pkg_catalogue.ajuster_stock(:id, :boutique, :delta); END;', $p);
    }

    public function ajouterPhoto(int $id, int $idBoutique, string $chemin): void
    {
        $p = ['id' => $id, 'boutique' => $idBoutique, 'chemin' => $chemin, 'photo' => null];
        $this->db->appeler('BEGIN pkg_catalogue.ajouter_photo(:id, :boutique, :chemin, :photo); END;', $p);
    }

    /** Renvoie le chemin du fichier à effacer */
    public function retirerPhoto(int $idPhoto, int $idBoutique): string
    {
        $p = ['photo' => $idPhoto, 'boutique' => $idBoutique, 'chemin' => null];
        $this->db->appeler('BEGIN pkg_catalogue.retirer_photo(:photo, :boutique, :chemin); END;', $p);
        return (string) $p['chemin'];
    }

    /**
     * Validation du formulaire produit (fonction pure, testable).
     * Renvoie [valeurs normalisées, erreurs par champ].
     *
     * @param array<string, string> $champs
     * @return array{0: array<string, mixed>, 1: array<string, string>}
     */
    public static function validerFormulaire(array $champs, bool $creation): array
    {
        $erreurs = [];
        $nom = $champs['nom'] ?? '';
        $description = $champs['description'] ?? '';
        // "1 290,50" ou "1290.50" : espaces retirés, virgule acceptée
        $prixTexte = str_replace([' ', "\u{00A0}", ','], ['', '', '.'], $champs['prix_ht'] ?? '');
        $prix = filter_var($prixTexte, FILTER_VALIDATE_FLOAT);
        $categorie = filter_var($champs['id_categorie'] ?? '', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);

        if (mb_strlen($nom) < 3 || mb_strlen($nom) > 200) {
            $erreurs['nom'] = 'Le nom doit faire entre 3 et 200 caractères.';
        }
        if (mb_strlen($description) > 4000) {
            $erreurs['description'] = 'La description est limitée à 4000 caractères.';
        }
        if ($prix === false || $prix <= 0 || $prix > self::PRIX_MAX || round($prix, 2) != $prix) {
            $erreurs['prix_ht'] = 'Prix HT invalide (nombre positif, 2 décimales au plus).';
        }
        if ($categorie === false) {
            $erreurs['id_categorie'] = 'Choisissez une catégorie.';
        }
        $valeurs = ['nom' => $nom, 'description' => $description,
                    'prix_ht' => $prix === false ? 0.0 : (float) $prix, 'id_categorie' => $categorie === false ? 0 : $categorie];

        if ($creation) {
            $stock = filter_var($champs['stock'] ?? '', FILTER_VALIDATE_INT,
                ['options' => ['min_range' => 0, 'max_range' => self::STOCK_MAX]]);
            if ($stock === false) {
                $erreurs['stock'] = 'Stock initial invalide (entier positif ou nul).';
            }
            $valeurs['stock'] = $stock === false ? 0 : $stock;
        } else {
            $statut = $champs['statut'] ?? '';
            if (!in_array($statut, ['ACTIF', 'INACTIF'], true)) {
                $erreurs['statut'] = 'Statut invalide.';
            }
            $valeurs['statut'] = $statut;
        }
        return [$valeurs, $erreurs];
    }
}
