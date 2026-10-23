<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/**
 * Produits du catalogue, lus via PKG_CATALOGUE.
 *
 * Oracle renvoie tout sous forme de texte ("3948", "1393.2") avec des clés en
 * MAJUSCULES : versTableau() convertit une ligne en tableau typé, en minuscules.
 * C'est ce tableau qui sert à la fois aux vues HTML et à l'API JSON.
 */
final class Produit
{
    public function __construct(private readonly Database $db)
    {
    }

    /**
     * @return array{produits: list<array<string, mixed>>, total: int}
     */
    public function rechercher(FiltresCatalogue $filtres): array
    {
        $lignes = $this->db->curseur(
            'pkg_catalogue.rechercher(p_texte => :texte, p_id_categorie => :categorie,
                                      p_prix_min => :prix_min, p_prix_max => :prix_max, p_tri => :tri,
                                      p_page => :page, p_taille_page => :taille, p_en_stock => :en_stock)',
            [
                'texte' => $filtres->texte === '' ? null : $filtres->texte,
                'categorie' => $filtres->categorie,
                'prix_min' => $filtres->prixMin,
                'prix_max' => $filtres->prixMax,
                'tri' => $filtres->tri,
                'page' => $filtres->page,
                'taille' => FiltresCatalogue::TAILLE_PAGE,
                'en_stock' => $filtres->enStock ? 1 : 0,
            ],
        );
        return [
            'produits' => array_map(self::versTableau(...), $lignes),
            // COUNT(*) OVER () : chaque ligne porte le total ; une page vide n'en a pas
            'total' => $lignes === [] ? $this->compter($filtres) : (int) $lignes[0]['TOTAL'],
        ];
    }

    /** Total sans pagination, quand la page demandée est au-delà des résultats */
    private function compter(FiltresCatalogue $filtres): int
    {
        if ($filtres->page === 1) {
            return 0;
        }
        return $this->rechercher(new FiltresCatalogue($filtres->texte, $filtres->categorie, $filtres->prixMin,
            $filtres->prixMax, $filtres->tri, 1, $filtres->enStock))['total'];
    }

    /** @return list<array{id: int, nom: string}> */
    public function suggestions(string $prefixe): array
    {
        if (mb_strlen(trim($prefixe)) < 2) {
            return [];
        }
        $lignes = $this->db->curseur('pkg_catalogue.suggestions(:prefixe, 8)', ['prefixe' => mb_substr($prefixe, 0, 50)]);
        return array_map(static fn (array $l) => ['id' => (int) $l['ID'], 'nom' => $l['NOM']], $lignes);
    }

    /**
     * Identifiant et nom de chaque produit visible (au plus 5000 : au-delà, la
     * recherche tolérante devrait se faire côté serveur).
     *
     * @return list<array{id: int, nom: string}>
     */
    public function titres(): array
    {
        return array_map(static fn (array $l) => ['id' => (int) $l['ID'], 'nom' => $l['NOM']], $this->db->lignes(
            "SELECT p.id, p.nom FROM produit p JOIN boutique b ON b.id = p.id_boutique
              WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE'
              ORDER BY p.nb_avis DESC, p.id FETCH FIRST 5000 ROWS ONLY"));
    }

    /**
     * Fiche d'un produit visible (produit ACTIF d'une boutique VALIDEE), ou null.
     *
     * @return array<string, mixed>|null
     */
    public function fiche(int $id): ?array
    {
        $ligne = $this->db->ligne(
            "SELECT p.id, p.nom, p.description, p.id_categorie, p.prix_ht, p.stock, p.note_moyenne, p.nb_avis,
                    p.date_creation, b.id AS id_boutique, b.nom AS boutique, b.ville AS ville_boutique,
                    pkg_catalogue.pourcentage_promo(p.id) AS pourcentage_promo,
                    pkg_catalogue.prix_courant(p.id) AS prix_courant_ht,
                    pkg_catalogue.prix_courant_ttc(p.id) AS prix_courant_ttc,
                    pkg_catalogue.ttc(p.prix_ht) AS prix_ttc
               FROM produit p JOIN boutique b ON b.id = p.id_boutique
              WHERE p.id = :id AND p.statut = 'ACTIF' AND b.statut = 'VALIDEE'",
            ['id' => $id],
        );
        if ($ligne === null) {
            return null;
        }
        $produit = self::versTableau($ligne);
        $produit['description'] = $ligne['DESCRIPTION'] ?? '';
        $produit['id_boutique'] = (int) $ligne['ID_BOUTIQUE'];
        $produit['ville_boutique'] = $ligne['VILLE_BOUTIQUE'];
        $produit['photos'] = array_column($this->db->lignes(
            'SELECT chemin FROM produit_photo WHERE id_produit = :id ORDER BY ordre',
            ['id' => $id],
        ), 'CHEMIN');
        return $produit;
    }

    /** @return list<array{nom: string, note: int, commentaire: string, date: string}> */
    public function avis(int $idProduit, int $limite = 10): array
    {
        $lignes = $this->db->lignes(
            "SELECT u.nom, a.note, a.commentaire, a.date_avis
               FROM avis a JOIN utilisateur u ON u.id = a.id_utilisateur
              WHERE a.id_produit = :id AND a.statut = 'PUBLIE'
              ORDER BY a.date_avis DESC
              FETCH FIRST :limite ROWS ONLY",
            ['id' => $idProduit, 'limite' => $limite],
        );
        return array_map(static fn (array $l) => [
            // Prénom et initiale seulement : on n'affiche pas le nom complet d'un client
            'nom' => self::nomCourt($l['NOM']),
            'note' => (int) $l['NOTE'],
            'commentaire' => $l['COMMENTAIRE'] ?? '',
            'date' => $l['DATE_AVIS'],
        ], $lignes);
    }

    /**
     * Ligne Oracle → tableau typé (clés en minuscules, nombres convertis).
     *
     * @param array<string, mixed> $l
     * @return array<string, mixed>
     */
    public static function versTableau(array $l): array
    {
        return [
            'id' => (int) $l['ID'],
            'nom' => $l['NOM'],
            'id_categorie' => (int) $l['ID_CATEGORIE'],
            'boutique' => $l['BOUTIQUE'],
            'prix_ht' => (float) $l['PRIX_HT'],
            'pourcentage_promo' => (float) $l['POURCENTAGE_PROMO'],
            'prix_courant_ht' => (float) $l['PRIX_COURANT_HT'],
            'prix_courant_ttc' => (float) $l['PRIX_COURANT_TTC'],
            // Prix d'origine TTC (barré quand il y a une promotion), calculé en base
            'prix_ttc' => (float) $l['PRIX_TTC'],
            'stock' => (int) $l['STOCK'],
            'note_moyenne' => $l['NOTE_MOYENNE'] === null ? null : (float) $l['NOTE_MOYENNE'],
            'nb_avis' => (int) $l['NB_AVIS'],
            'photo' => $l['PHOTO'] ?? null,
            'url' => '/produit/' . (int) $l['ID'],
        ];
    }

    /** "Fatima Zahra Bennani" → "Fatima Zahra B." */
    public static function nomCourt(string $nom): string
    {
        $mots = preg_split('/\s+/', trim($nom)) ?: [$nom];
        if (count($mots) === 1) {
            return $mots[0];
        }
        $dernier = array_pop($mots);
        return implode(' ', $mots) . ' ' . mb_substr($dernier, 0, 1) . '.';
    }
}
