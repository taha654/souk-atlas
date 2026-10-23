<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Database;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Session;

/**
 * Panier de l'utilisateur, connecté ou non.
 *
 *  - Connecté : le panier est en base, géré par PKG_PANIER.
 *  - Visiteur : la session ne garde que [id_produit => quantité]. Les prix, le
 *    stock et la disponibilité sont TOUJOURS relus en base, jamais stockés en
 *    session (un prix en session serait périmé, voire falsifiable).
 *  - À la connexion, fusionner() verse le panier de session dans le panier en base.
 */
final class Panier
{
    private const CLE_SESSION = '_panier';
    public const QUANTITE_MAX = 99;

    public function __construct(
        private readonly Database $db,
        private readonly ?int $idUtilisateur,
    ) {
    }

    // =========================================================================
    // Modifications
    // =========================================================================

    public function ajouter(int $idProduit, int $quantite): void
    {
        if ($this->idUtilisateur !== null) {
            $this->appeler('BEGIN pkg_panier.ajouter(:u, :p, :q); END;', $idProduit, $quantite);
            return;
        }
        $panier = $this->panierSession();
        $total = ($panier[$idProduit] ?? 0) + $quantite;
        $this->verifierPourVisiteur($idProduit, $total);
        $panier[$idProduit] = $total;
        Session::set(self::CLE_SESSION, $panier);
    }

    public function modifier(int $idProduit, int $quantite): void
    {
        if ($quantite === 0) {
            $this->retirer($idProduit);
            return;
        }
        if ($this->idUtilisateur !== null) {
            $this->appeler('BEGIN pkg_panier.modifier_quantite(:u, :p, :q); END;', $idProduit, $quantite);
            return;
        }
        $panier = $this->panierSession();
        if (!isset($panier[$idProduit])) {
            throw new ErreurMetier(ErreurMetier::INTROUVABLE, 'Ce produit n\'est pas dans le panier.');
        }
        $this->verifierPourVisiteur($idProduit, $quantite);
        $panier[$idProduit] = $quantite;
        Session::set(self::CLE_SESSION, $panier);
    }

    public function retirer(int $idProduit): void
    {
        if ($this->idUtilisateur !== null) {
            $this->appeler('BEGIN pkg_panier.retirer(:u, :p); END;', $idProduit);
            return;
        }
        $panier = $this->panierSession();
        unset($panier[$idProduit]);
        Session::set(self::CLE_SESSION, $panier);
    }

    /**
     * À la connexion : chaque ligne du panier de session est ajoutée au panier en
     * base (stock revérifié par PKG_PANIER). Une ligne refusée n'empêche pas les autres.
     *
     * @return list<string> messages des lignes qui n'ont pas pu être reprises
     */
    public function fusionnerDepuisSession(): array
    {
        $refus = [];
        foreach ($this->panierSession() as $idProduit => $quantite) {
            try {
                $this->ajouter((int) $idProduit, (int) $quantite);
            } catch (ErreurMetier $erreur) {
                $refus[] = $erreur->getMessage();
            }
        }
        Session::retirer(self::CLE_SESSION);
        return $refus;
    }

    // =========================================================================
    // Lecture
    // =========================================================================

    public function nbArticles(): int
    {
        if ($this->idUtilisateur !== null) {
            return (int) $this->db->valeur('SELECT pkg_panier.nb_articles(:u) FROM dual', ['u' => $this->idUtilisateur]);
        }
        return array_sum($this->panierSession());
    }

    /**
     * Lignes et totaux, recalculés en base. TVA arrondie PAR BOUTIQUE, comme
     * PKG_COMMANDE : le total affiché est exactement celui qui sera facturé.
     *
     * @return array{lignes: list<array<string, mixed>>, total_ht: float, tva: float, total_ttc: float, nb_articles: int}
     */
    public function contenu(): array
    {
        if ($this->idUtilisateur !== null) {
            $lignes = array_map(self::ligne(...),
                $this->db->curseur('pkg_panier.lignes(:u)', ['u' => $this->idUtilisateur]));
            // Totaux : la procédure du package, source unique de la règle de calcul
            $p = ['u' => $this->idUtilisateur, 'ht' => null, 'tva' => null, 'ttc' => null, 'nb' => null];
            $this->db->appeler('BEGIN pkg_panier.calculer_totaux(:u, :ht, :tva, :ttc, :nb); END;', $p);
            return ['lignes' => $lignes, 'total_ht' => (float) $p['ht'], 'tva' => (float) $p['tva'],
                    'total_ttc' => (float) $p['ttc'], 'nb_articles' => (int) $p['nb']];
        }

        $lignes = $this->lignesVisiteur();
        // Visiteur : même règle. HT par boutique, puis TTC de chaque boutique
        // calculé en base par pkg_catalogue.ttc (taux unique, arrondi au centime)
        $htParBoutique = [];
        foreach ($lignes as $ligne) {
            $htParBoutique[$ligne['id_boutique']] = ($htParBoutique[$ligne['id_boutique']] ?? 0) + $ligne['total_ligne_ht'];
        }
        $totalHt = round(array_sum($htParBoutique), 2);
        $totalTtc = 0.0;
        if ($htParBoutique !== []) {
            $parametres = [];
            foreach (array_values($htParBoutique) as $i => $ht) {
                $parametres['h' . $i] = round($ht, 2);
            }
            $totalTtc = (float) $this->db->valeur('SELECT '
                . implode(' + ', array_map(static fn ($n) => "pkg_catalogue.ttc(:$n)", array_keys($parametres)))
                . ' FROM dual', $parametres);
        }
        return [
            'lignes' => $lignes,
            'total_ht' => $totalHt,
            'tva' => round($totalTtc - $totalHt, 2),
            'total_ttc' => $totalTtc,
            'nb_articles' => (int) array_sum(array_column($lignes, 'quantite')),
        ];
    }

    // =========================================================================
    // Visiteur : panier en session
    // =========================================================================

    /** @return array<int, int> */
    private function panierSession(): array
    {
        $panier = Session::get(self::CLE_SESSION, []);
        return is_array($panier) ? $panier : [];
    }

    /** Mêmes contrôles que PKG_PANIER, mêmes codes d'erreur */
    private function verifierPourVisiteur(int $idProduit, int $quantite): void
    {
        if ($quantite <= 0 || $quantite > self::QUANTITE_MAX) {
            throw new ErreurMetier(ErreurMetier::QUANTITE_INVALIDE, 'Quantité invalide (1 à ' . self::QUANTITE_MAX . ').');
        }
        $produit = $this->db->ligne(
            'SELECT p.nom, p.stock, p.statut, b.statut AS statut_boutique
               FROM produit p JOIN boutique b ON b.id = p.id_boutique WHERE p.id = :id',
            ['id' => $idProduit],
        );
        if ($produit === null || $produit['STATUT'] !== 'ACTIF' || $produit['STATUT_BOUTIQUE'] !== 'VALIDEE') {
            throw new ErreurMetier(ErreurMetier::PRODUIT_INDISPONIBLE, 'Ce produit n\'est plus en vente.');
        }
        if ($quantite > (int) $produit['STOCK']) {
            throw new ErreurMetier(ErreurMetier::STOCK_INSUFFISANT,
                'Stock insuffisant pour ' . $produit['NOM'] . ' : ' . $produit['STOCK'] . ' disponible(s).');
        }
    }

    /** @return list<array<string, mixed>> */
    private function lignesVisiteur(): array
    {
        $panier = $this->panierSession();
        if ($panier === []) {
            return [];
        }
        // IN (:p0, :p1, …) : on génère autant de VARIABLES LIÉES que de produits.
        // Le texte SQL ne contient que des noms de variables, jamais les valeurs.
        $parametres = [];
        foreach (array_keys($panier) as $i => $idProduit) {
            $parametres['p' . $i] = (int) $idProduit;
        }
        $lignes = $this->db->lignes(
            "SELECT p.id AS id_produit, p.nom, p.id_boutique, b.nom AS boutique, p.stock,
                    pkg_catalogue.prix_courant(p.id) AS prix_unitaire_ht,
                    pkg_catalogue.prix_courant_ttc(p.id) AS prix_unitaire_ttc,
                    CASE WHEN p.statut = 'ACTIF' AND b.statut = 'VALIDEE' THEN 1 ELSE 0 END AS en_vente
               FROM produit p JOIN boutique b ON b.id = p.id_boutique
              WHERE p.id IN (:" . implode(', :', array_keys($parametres)) . ')
              ORDER BY p.id',
            $parametres,
        );
        return array_map(static function (array $l) use ($panier): array {
            $quantite = $panier[(int) $l['ID_PRODUIT']];
            return self::ligne($l + [
                'QUANTITE' => $quantite,
                'TOTAL_LIGNE_HT' => round((float) $l['PRIX_UNITAIRE_HT'] * $quantite, 2),
                'DISPONIBLE' => (int) $l['EN_VENTE'] === 1 && (int) $l['STOCK'] >= $quantite ? 1 : 0,
            ]);
        }, $lignes);
    }

    /**
     * @param array<string, mixed> $l ligne Oracle (clés en majuscules)
     * @return array<string, mixed>
     */
    private static function ligne(array $l): array
    {
        return [
            'id_produit' => (int) $l['ID_PRODUIT'],
            'nom' => $l['NOM'],
            'id_boutique' => (int) $l['ID_BOUTIQUE'],
            'boutique' => $l['BOUTIQUE'],
            'quantite' => (int) $l['QUANTITE'],
            'stock' => (int) $l['STOCK'],
            'prix_unitaire_ht' => (float) $l['PRIX_UNITAIRE_HT'],
            'prix_unitaire_ttc' => (float) $l['PRIX_UNITAIRE_TTC'],
            'total_ligne_ht' => (float) $l['TOTAL_LIGNE_HT'],
            'disponible' => (int) $l['DISPONIBLE'] === 1,
            'url' => '/produit/' . (int) $l['ID_PRODUIT'],
        ];
    }

    private function appeler(string $plsql, int $idProduit, ?int $quantite = null): void
    {
        $p = ['u' => $this->idUtilisateur, 'p' => $idProduit];
        if ($quantite !== null) {
            if ($quantite <= 0 || $quantite > self::QUANTITE_MAX) {
                throw new ErreurMetier(ErreurMetier::QUANTITE_INVALIDE, 'Quantité invalide (1 à ' . self::QUANTITE_MAX . ').');
            }
            $p['q'] = $quantite;
        }
        $this->db->appeler($plsql, $p);
    }
}
