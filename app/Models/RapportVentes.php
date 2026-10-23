<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/** Rapport de ventes sur une période (commande « rapport » de l'outil console), via PKG_STATS */
final class RapportVentes
{
    public const JOURS_MAX = 366;

    public function __construct(private readonly Database $db)
    {
    }

    /**
     * Valide la période "AAAA-MM-JJ" ; renvoie un message d'erreur, ou null si elle est correcte.
     */
    public static function erreurPeriode(string $debut, string $fin): ?string
    {
        $d = \DateTimeImmutable::createFromFormat('!Y-m-d', $debut);
        $f = \DateTimeImmutable::createFromFormat('!Y-m-d', $fin);
        // createFromFormat accepte "2026-02-31" (→ 3 mars) : on vérifie l'aller-retour
        if ($d === false || $f === false || $d->format('Y-m-d') !== $debut || $f->format('Y-m-d') !== $fin) {
            return 'Dates attendues au format AAAA-MM-JJ.';
        }
        if ($d > $f) {
            return 'La date de début est après la date de fin.';
        }
        if ($d->diff($f)->days + 1 > self::JOURS_MAX) {
            return 'Période limitée à ' . self::JOURS_MAX . ' jours.';
        }
        return null;
    }

    /**
     * @param int|null $idBoutique null : toutes les boutiques (admin)
     * @return array<string, mixed>
     */
    public function generer(string $debut, string $fin, ?int $idBoutique): array
    {
        $p = ['debut' => $debut, 'fin' => $fin, 'boutique' => $idBoutique];
        $jours = array_map(static fn (array $l) => [
            'jour' => substr($l['JOUR'], 0, 10),
            'nb_commandes' => (int) $l['NB_COMMANDES'],
            'ca_ht' => (float) $l['CA_HT'],
            'ca_cumule' => (float) $l['CA_CUMULE'],
        ], $this->db->curseur("pkg_stats.ca_par_jour(TO_DATE(:debut, 'YYYY-MM-DD'), TO_DATE(:fin, 'YYYY-MM-DD'), :boutique)", $p));

        $meilleures = array_map(static fn (array $l) => [
            'rang' => (int) $l['RANG'], 'produit' => $l['NOM'], 'quantite' => (int) $l['QUANTITE'], 'ca_ht' => (float) $l['CA_HT'],
        ], $this->db->curseur("pkg_stats.meilleures_ventes(TO_DATE(:debut, 'YYYY-MM-DD'), TO_DATE(:fin, 'YYYY-MM-DD'), 10, :boutique)", $p));

        $boutiques = $idBoutique !== null ? [] : array_map(static fn (array $l) => [
            'rang' => (int) $l['RANG'], 'boutique' => $l['BOUTIQUE'], 'nb_commandes' => (int) $l['NB_COMMANDES'],
            'ca_ht' => (float) $l['CA_HT'], 'part_pct' => (float) $l['PART_PCT'],
        ], $this->db->curseur("pkg_stats.ca_par_vendeur(TO_DATE(:debut, 'YYYY-MM-DD'), TO_DATE(:fin, 'YYYY-MM-DD'))",
            ['debut' => $debut, 'fin' => $fin]));

        return [
            'debut' => $debut,
            'fin' => $fin,
            'perimetre' => $idBoutique === null ? 'toutes les boutiques' : 'boutique ' . $idBoutique,
            'total' => [
                'nb_commandes' => array_sum(array_column($jours, 'nb_commandes')),
                'ca_ht' => round(array_sum(array_column($jours, 'ca_ht')), 2),
                'panier_moyen_ttc' => (float) $this->db->valeur(
                    "SELECT pkg_stats.panier_moyen(TO_DATE(:debut, 'YYYY-MM-DD'), TO_DATE(:fin, 'YYYY-MM-DD'), :boutique) FROM DUAL", $p),
            ],
            'jours' => $jours,
            'meilleures_ventes' => $meilleures,
            'boutiques' => $boutiques,
        ];
    }
}
