<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Database;
use App\Models\Produit;

/**
 * « Souvent achetés ensemble » : Oracle fournit les achats, le moteur C++
 * calcule les recommandations (graphe des co-achats, similarité cosinus),
 * Oracle les stocke (table RECOMMANDATION) et la fiche produit les relit.
 *
 * Le calcul est relancé au plus une fois par période (24 h par défaut), par la
 * première visite d'une fiche après expiration, ou à la demande de l'admin.
 */
final class Recommandations
{
    // Une paire vue dans moins de 2 achats est une coïncidence, pas une tendance
    private const SUPPORT_MIN = 2;
    private const PAR_PRODUIT = 4;

    public function __construct(
        private readonly Database $db,
        private readonly CppEngine $moteur,
        private readonly float $ageMaxHeures = 24,
    ) {
    }

    /**
     * Produits recommandés pour une fiche (tableaux de Produit::versTableau).
     * Si le moteur est indisponible, on affiche les anciennes recommandations
     * (ou aucune) : la fiche produit ne doit jamais tomber en erreur pour ça.
     *
     * @return list<array<string, mixed>>
     */
    public function pour(int $idProduit, int $limite = self::PAR_PRODUIT): array
    {
        $this->rafraichirSiNecessaire();
        $lignes = $this->db->curseur('pkg_catalogue.recommandations(:id, :limite)', ['id' => $idProduit, 'limite' => $limite]);
        return array_map(static fn (array $l) => Produit::versTableau($l) + ['score' => (float) $l['SCORE']], $lignes);
    }

    public function rafraichirSiNecessaire(): void
    {
        $age = $this->db->valeur('SELECT pkg_catalogue.age_recommandations FROM DUAL');
        if ($age !== null && (float) $age < $this->ageMaxHeures) {
            return;
        }
        try {
            $this->recalculer();
        } catch (ErreurMoteur $erreur) {
            $this->db->annuler();
            error_log('[Souk Atlas] Recommandations non recalculées : ' . $erreur->getMessage());
        }
    }

    /**
     * Recalcule et VALIDE toutes les recommandations. Renvoie le nombre de lignes.
     *
     * @throws ErreurMoteur
     */
    public function recalculer(): int
    {
        // 1. Les achats, regroupés en paniers : référence d'achat → produits
        $paniers = [];
        foreach ($this->db->curseur('pkg_catalogue.paniers_achetes') as $ligne) {
            $paniers[$ligne['REFERENCE_ACHAT']][] = (int) $ligne['ID_PRODUIT'];
        }

        // 2. Le calcul, en C++
        $reponse = $this->moteur->executer([
            'action' => 'recommandations',
            'paniers' => array_values($paniers),
            'limite' => self::PAR_PRODUIT * 2,   // de la marge : certains seront épuisés ou retirés
            'support_min' => self::SUPPORT_MIN,
        ]);

        // 3. Le stockage : quatre tableaux parallèles, insérés d'un coup (FORALL)
        $tableaux = ['produits' => [], 'recommandes' => [], 'scores' => [], 'communs' => []];
        foreach ($reponse['recommandations'] ?? [] as $idProduit => $liste) {
            foreach ($liste as $reco) {
                $tableaux['produits'][] = (int) $idProduit;
                $tableaux['recommandes'][] = (int) $reco['produit'];
                $tableaux['scores'][] = (float) $reco['score'];
                $tableaux['communs'][] = (int) $reco['communs'];
            }
        }
        $p = ['nb' => null];
        $this->db->appelerAvecTableaux(
            'BEGIN pkg_catalogue.remplacer_recommandations(:produits, :recommandes, :scores, :communs, :nb); END;',
            $tableaux, $p);
        $this->db->valider();
        return (int) $p['nb'];
    }
}
