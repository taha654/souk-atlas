<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/** Administration générale : chiffres globaux, boutiques, utilisateurs, journal d'audit */
final class Administration
{
    public function __construct(private readonly Database $db)
    {
    }

    /** @return array<string, int> */
    public function aTraiter(): array
    {
        $l = $this->db->ligne(
            "SELECT (SELECT COUNT(*) FROM boutique WHERE statut = 'EN_ATTENTE') AS boutiques,
                    (SELECT COUNT(*) FROM annonce WHERE statut = 'EN_MODERATION') AS annonces,
                    (SELECT COUNT(*) FROM signalement WHERE statut = 'OUVERT') AS signalements,
                    (SELECT COUNT(*) FROM utilisateur) AS utilisateurs,
                    (SELECT COUNT(*) FROM produit WHERE statut = 'ACTIF') AS produits,
                    (SELECT COUNT(*) FROM annonce WHERE statut = 'EN_LIGNE') AS annonces_en_ligne,
                    -- Score >= 60 calculé par le moteur C++, commande pas encore expédiée
                    (SELECT COUNT(*) FROM commande
                      WHERE score_risque >= 60 AND statut IN ('EN_ATTENTE', 'PAYEE')) AS commandes_risquees
               FROM dual");
        return array_map('intval', array_change_key_case($l, CASE_LOWER));
    }

    /** @return array{paires: int, produits: int, age_heures: float|null} */
    public function etatRecommandations(): array
    {
        $l = $this->db->ligne('SELECT COUNT(*) AS paires, COUNT(DISTINCT id_produit) AS produits,
                                      pkg_catalogue.age_recommandations AS age FROM recommandation');
        return ['paires' => (int) $l['PAIRES'], 'produits' => (int) $l['PRODUITS'],
                'age_heures' => $l['AGE'] === null ? null : (float) $l['AGE']];
    }

    /** Graphiques du tableau de bord global (PKG_STATS sans filtre de boutique) @return array<string, mixed> */
    public function statistiques(int $jours): array
    {
        $debut = date('Y-m-d', strtotime('-' . ($jours - 1) . ' days'));
        $dates = ['debut' => $debut, 'fin' => date('Y-m-d')];
        return [
            'jours' => $jours,
            'panier_moyen' => (float) $this->db->valeur(
                "SELECT pkg_stats.panier_moyen(TO_DATE(:debut, 'YYYY-MM-DD'), TO_DATE(:fin, 'YYYY-MM-DD')) FROM dual", $dates),
            'par_jour' => array_map(static fn (array $l) => ['jour' => substr($l['JOUR'], 0, 10), 'ca_ht' => (float) $l['CA_HT'],
                'nb_commandes' => (int) $l['NB_COMMANDES']],
                $this->db->curseur("pkg_stats.ca_par_jour(TO_DATE(:debut, 'YYYY-MM-DD'), TO_DATE(:fin, 'YYYY-MM-DD'))", $dates)),
            'par_vendeur' => array_map(static fn (array $l) => ['rang' => (int) $l['RANG'], 'boutique' => $l['BOUTIQUE'],
                'nb_commandes' => (int) $l['NB_COMMANDES'], 'ca_ht' => (float) $l['CA_HT'], 'part_pct' => (float) $l['PART_PCT']],
                $this->db->curseur("pkg_stats.ca_par_vendeur(TO_DATE(:debut, 'YYYY-MM-DD'), TO_DATE(:fin, 'YYYY-MM-DD'))", $dates)),
        ];
    }

    /** @return list<array<string, mixed>> */
    public function boutiques(?string $statut): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'nom' => $l['NOM'], 'ville' => $l['VILLE'], 'statut' => $l['STATUT'],
            'vendeur' => $l['VENDEUR'], 'email' => $l['EMAIL'], 'nb_produits' => (int) $l['NB_PRODUITS'],
            'description' => $l['DESCRIPTION'] ?? '', 'date' => $l['DATE_CREATION'],
        ], $this->db->lignes(
            "SELECT b.id, b.nom, b.ville, b.statut, b.description, b.date_creation, u.nom AS vendeur, u.email,
                    (SELECT COUNT(*) FROM produit p WHERE p.id_boutique = b.id) AS nb_produits
               FROM boutique b JOIN utilisateur u ON u.id = b.id_vendeur
              WHERE :statut IS NULL OR b.statut = :statut
              ORDER BY CASE b.statut WHEN 'EN_ATTENTE' THEN 0 ELSE 1 END, b.date_creation DESC",
            ['statut' => $statut]));
    }

    public function changerStatutBoutique(int $id, string $statut): void
    {
        $p = ['id' => $id, 'statut' => $statut];
        $this->db->appeler('BEGIN pkg_utilisateur.changer_statut_boutique(:id, :statut); END;', $p);
    }

    /** @return list<array<string, mixed>> */
    public function utilisateurs(string $recherche): array
    {
        $motif = '%' . mb_strtolower($recherche) . '%';
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'nom' => $l['NOM'], 'email' => $l['EMAIL'], 'role' => $l['ROLE'],
            'statut' => $l['STATUT'], 'ville' => $l['VILLE'], 'date' => $l['DATE_CREATION'],
            'derniere_connexion' => $l['DATE_DERNIERE_CONNEXION'],
        ], $this->db->lignes(
            'SELECT id, nom, email, role, statut, ville, date_creation, date_derniere_connexion
               FROM utilisateur
              WHERE :recherche IS NULL OR LOWER(nom) LIKE :motif OR email LIKE :motif
              ORDER BY date_creation DESC FETCH FIRST 100 ROWS ONLY',
            ['recherche' => $recherche === '' ? null : $recherche, 'motif' => $motif]));
    }

    /** $action : role:CLIENT|VENDEUR|ADMIN, desactiver, reactiver */
    public function modifierUtilisateur(int $id, string $action): void
    {
        $p = ['id' => $id];
        if (str_starts_with($action, 'role:')) {
            $p['role'] = substr($action, 5);
            $this->db->appeler('BEGIN pkg_utilisateur.changer_role(:id, :role); END;', $p);
            return;
        }
        $procedure = ['desactiver' => 'desactiver', 'reactiver' => 'reactiver'][$action] ?? null;
        if ($procedure === null) {
            throw new \InvalidArgumentException('Action inconnue');
        }
        $this->db->appeler("BEGIN pkg_utilisateur.$procedure(:id); END;", $p);
    }

    /** Dernières entrées du journal d'audit (écrites par les triggers) @return list<array<string, mixed>> */
    public function journal(?string $table): array
    {
        return array_map(static fn (array $l) => [
            'date' => $l['DATE_ACTION'], 'table' => $l['NOM_TABLE'], 'id_ligne' => (int) $l['ID_LIGNE'],
            'operation' => $l['OPERATION'], 'auteur' => $l['AUTEUR_NOM'] ?? $l['AUTEUR'],
            'avant' => $l['ANCIENNE_VALEUR'], 'apres' => $l['NOUVELLE_VALEUR'],
        ], $this->db->lignes(
            // auteur = id de l'utilisateur du site (client identifier posé par PHP) ou compte Oracle
            "SELECT j.date_action, j.nom_table, j.id_ligne, j.operation, j.auteur, j.ancienne_valeur, j.nouvelle_valeur,
                    u.nom || ' (' || u.role || ')' AS auteur_nom
               FROM journal_audit j
               LEFT JOIN utilisateur u ON TO_CHAR(u.id) = j.auteur
              WHERE :nom_table IS NULL OR j.nom_table = :nom_table
              ORDER BY j.id DESC FETCH FIRST 100 ROWS ONLY",
            // ":table" serait refusé (ORA-01745) : TABLE est un mot réservé d'Oracle
            ['nom_table' => $table]));
    }
}
