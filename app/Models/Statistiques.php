<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/** Statistiques de ventes d'une boutique, via PKG_STATS (fonctions analytiques Oracle) */
final class Statistiques
{
    public function __construct(private readonly Database $db)
    {
    }

    /** @return array<string, mixed> */
    public function tableauDeBord(int $idBoutique, int $jours): array
    {
        $debut = date('Y-m-d', strtotime('-' . ($jours - 1) . ' days'));
        $fin = date('Y-m-d');
        $dates = ['debut' => $debut, 'fin' => $fin, 'boutique' => $idBoutique];

        $resume = ['boutique' => $idBoutique, 'debut' => $debut, 'fin' => $fin,
                   'nb' => null, 'ca' => null, 'moyen' => null, 'articles' => null];
        $this->db->appeler("BEGIN pkg_stats.resume_boutique(:boutique, TO_DATE(:debut, 'YYYY-MM-DD'),
                                TO_DATE(:fin, 'YYYY-MM-DD'), :nb, :ca, :moyen, :articles); END;", $resume);

        $parJour = $this->db->curseur("pkg_stats.ca_par_jour(TO_DATE(:debut, 'YYYY-MM-DD'),
                                       TO_DATE(:fin, 'YYYY-MM-DD'), :boutique)", $dates);
        $parMois = $this->db->curseur('pkg_stats.ca_par_mois(:annee, :boutique)',
            ['annee' => (int) date('Y'), 'boutique' => $idBoutique]);
        $meilleures = $this->db->curseur("pkg_stats.meilleures_ventes(TO_DATE(:debut, 'YYYY-MM-DD'),
                                          TO_DATE(:fin, 'YYYY-MM-DD'), 5, :boutique)", $dates);

        return [
            'jours' => $jours,
            'resume' => [
                'nb_commandes' => (int) $resume['nb'],
                'ca_ht' => (float) $resume['ca'],
                'panier_moyen' => (float) $resume['moyen'],
                'articles_vendus' => (int) $resume['articles'],
            ],
            'par_jour' => array_map(static fn (array $l) => [
                'jour' => substr($l['JOUR'], 0, 10),
                'ca_ht' => (float) $l['CA_HT'],
                'nb_commandes' => (int) $l['NB_COMMANDES'],
                'ca_cumule' => (float) $l['CA_CUMULE'],
            ], $parJour),
            'par_mois' => array_map(static fn (array $l) => [
                'mois' => (int) $l['MOIS'],
                'ca_ht' => (float) $l['CA_HT'],
                'evolution_pct' => $l['EVOLUTION_PCT'] === null ? null : (float) $l['EVOLUTION_PCT'],
            ], $parMois),
            'meilleures_ventes' => array_map(static fn (array $l) => [
                'rang' => (int) $l['RANG'],
                'nom' => $l['NOM'],
                'quantite' => (int) $l['QUANTITE'],
                'ca_ht' => (float) $l['CA_HT'],
            ], $meilleures),
        ];
    }
}
