<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/** Commandes REÇUES par une boutique (vue du vendeur) */
final class CommandeVendeur
{
    public function __construct(private readonly Database $db)
    {
    }

    /** @return list<array<string, mixed>> */
    public function liste(int $idBoutique, ?string $statut): array
    {
        $lignes = $this->db->lignes(
            'SELECT c.numero, c.statut, c.total_ttc, c.total_ht, c.mode_paiement, c.date_commande, c.ville_livraison,
                    c.score_risque,
                    u.nom AS client,
                    (SELECT SUM(cl.quantite) FROM commande_ligne cl WHERE cl.id_commande = c.id) AS articles
               FROM commande c JOIN utilisateur u ON u.id = c.id_client
              WHERE c.id_boutique = :boutique AND (:statut IS NULL OR c.statut = :statut)
              ORDER BY c.date_commande DESC
              FETCH FIRST 100 ROWS ONLY',
            ['boutique' => $idBoutique, 'statut' => $statut],
        );
        return array_map(static fn (array $l) => [
            'numero' => $l['NUMERO'],
            'statut' => $l['STATUT'],
            'total_ttc' => (float) $l['TOTAL_TTC'],
            'total_ht' => (float) $l['TOTAL_HT'],
            'mode_paiement' => $l['MODE_PAIEMENT'],
            'date' => $l['DATE_COMMANDE'],
            'ville' => $l['VILLE_LIVRAISON'],
            'client' => Produit::nomCourt($l['CLIENT']),
            'articles' => (int) $l['ARTICLES'],
            'score_risque' => $l['SCORE_RISQUE'] === null ? null : (int) $l['SCORE_RISQUE'],
        ], $lignes);
    }

    /** @return array<string, int> nombre de commandes par statut */
    public function compteurs(int $idBoutique): array
    {
        $compteurs = array_fill_keys(array_keys(Commande::STATUTS), 0);
        foreach ($this->db->lignes('SELECT statut, COUNT(*) AS nb FROM commande WHERE id_boutique = :b GROUP BY statut',
                     ['b' => $idBoutique]) as $l) {
            $compteurs[$l['STATUT']] = (int) $l['NB'];
        }
        return $compteurs;
    }

    /** @return array<string, mixed>|null */
    public function detail(string $numero, int $idBoutique): ?array
    {
        $c = $this->db->ligne(
            "SELECT c.id, c.numero, c.statut, c.total_ht, c.tva, c.total_ttc, c.mode_paiement,
                    c.adresse_livraison, c.ville_livraison, c.telephone_livraison, c.date_commande,
                    c.date_paiement, c.date_expedition, c.date_livraison, c.date_annulation,
                    c.score_risque, u.nom AS client, p.statut AS statut_paiement
               FROM commande c JOIN utilisateur u ON u.id = c.id_client
               LEFT JOIN paiement p ON p.id_commande = c.id
              WHERE c.numero = :numero AND c.id_boutique = :boutique",
            ['numero' => $numero, 'boutique' => $idBoutique],
        );
        if ($c === null) {
            return null;
        }
        return [
            'id' => (int) $c['ID'],
            'numero' => $c['NUMERO'],
            'statut' => $c['STATUT'],
            'total_ht' => (float) $c['TOTAL_HT'],
            'tva' => (float) $c['TVA'],
            'total_ttc' => (float) $c['TOTAL_TTC'],
            'mode_paiement' => $c['MODE_PAIEMENT'],
            'statut_paiement' => $c['STATUT_PAIEMENT'],
            // Calculé par le moteur C++ au moment de la commande (null : pas de score)
            'score_risque' => $c['SCORE_RISQUE'] === null ? null : (int) $c['SCORE_RISQUE'],
            // Le vendeur a besoin de l'adresse pour expédier : c'est son seul usage
            'client' => $c['CLIENT'],
            'adresse' => $c['ADRESSE_LIVRAISON'],
            'ville' => $c['VILLE_LIVRAISON'],
            'telephone' => $c['TELEPHONE_LIVRAISON'],
            'date' => $c['DATE_COMMANDE'],
            'dates' => ['EN_ATTENTE' => $c['DATE_COMMANDE'], 'PAYEE' => $c['DATE_PAIEMENT'],
                        'EXPEDIEE' => $c['DATE_EXPEDITION'], 'LIVREE' => $c['DATE_LIVRAISON'],
                        'ANNULEE' => $c['DATE_ANNULATION']],
            'lignes' => $this->db->lignes(
                'SELECT nom_produit, quantite, prix_unitaire_ht, total_ligne_ht FROM commande_ligne
                  WHERE id_commande = :id ORDER BY id', ['id' => (int) $c['ID']]),
            'actions' => self::actionsPossibles($c['STATUT'], $c['MODE_PAIEMENT']),
        ];
    }

    /** Même seuil que PKG_ANNONCE.c_seuil_moderation : au-delà, on vérifie avant d'expédier */
    public const SEUIL_RISQUE = 60;

    public function changerStatut(int $idCommande, int $idBoutique, string $statut): void
    {
        $p = ['commande' => $idCommande, 'boutique' => $idBoutique, 'statut' => $statut];
        $this->db->appeler('BEGIN pkg_commande.changer_statut_par_vendeur(:commande, :boutique, :statut); END;', $p);
    }

    /**
     * Boutons à proposer au vendeur selon l'état de la commande. Ce n'est qu'un
     * affichage : PKG_COMMANDE refuse de toute façon une transition interdite.
     *
     * @return array<string, string> statut cible → libellé du bouton
     */
    public static function actionsPossibles(string $statut, string $mode): array
    {
        return match (true) {
            $statut === 'PAYEE', $statut === 'EN_ATTENTE' && $mode === 'LIVRAISON'
                => ['EXPEDIEE' => 'Marquer comme expédiée', 'ANNULEE' => 'Annuler la commande'],
            $statut === 'EN_ATTENTE' => ['ANNULEE' => 'Annuler la commande'],
            $statut === 'EXPEDIEE' => ['LIVREE' => 'Confirmer la livraison'],
            default => [],
        };
    }
}
