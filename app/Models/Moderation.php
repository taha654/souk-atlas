<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/** Modération (admin) : annonces à vérifier, signalements, avis */
final class Moderation
{
    public const MOTIFS = ['ARNAQUE' => 'Arnaque', 'CONTREFACON' => 'Contrefaçon', 'INAPPROPRIE' => 'Contenu inapproprié',
                           'DOUBLON' => 'Doublon', 'AUTRE' => 'Autre'];

    public function __construct(private readonly Database $db)
    {
    }

    /** Annonces EN_MODERATION, les plus risquées d'abord @return list<array<string, mixed>> */
    public function annoncesAVerifier(): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'titre' => $l['TITRE'], 'prix' => (float) $l['PRIX'], 'ville' => $l['VILLE'],
            'score' => $l['SCORE_RISQUE'] === null ? null : (int) $l['SCORE_RISQUE'], 'auteur' => $l['AUTEUR'],
            'date' => $l['DATE_PUBLICATION'], 'description' => $l['DESCRIPTION'],
            'compte_jours' => (int) $l['COMPTE_JOURS'],
        ], $this->db->lignes(
            "SELECT a.id, a.titre, a.prix, a.ville, a.score_risque, a.date_publication, a.description, u.nom AS auteur,
                    TRUNC(SYSDATE - u.date_creation) AS compte_jours
               FROM annonce a JOIN utilisateur u ON u.id = a.id_utilisateur
              WHERE a.statut = 'EN_MODERATION'
              ORDER BY a.score_risque DESC NULLS LAST, a.date_publication"));
    }

    public function modererAnnonce(int $id, string $decision, string $motif): void
    {
        $p = ['id' => $id, 'decision' => $decision, 'motif' => $motif === '' ? null : $motif];
        $this->db->appeler('BEGIN pkg_annonce.moderer(:id, :decision, :motif); END;', $p);
    }

    /**
     * Signalements, regroupés par cible : plusieurs signalements sur la même
     * annonce n'occupent qu'une ligne (avec leur nombre).
     *
     * @return list<array<string, mixed>>
     */
    public function signalements(string $statut): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'type' => $l['TYPE_CIBLE'], 'id_cible' => (int) $l['ID_CIBLE'],
            'cible' => $l['LIBELLE_CIBLE'], 'motif' => $l['MOTIF'], 'nb' => (int) $l['NB'],
            'date' => $l['DATE_SIGNALEMENT'], 'statut' => $l['STATUT'],
        ], $this->db->lignes(
            "SELECT MIN(s.id) AS id,
                    CASE WHEN s.id_annonce IS NOT NULL THEN 'ANNONCE' WHEN s.id_avis IS NOT NULL THEN 'AVIS' ELSE 'PRODUIT' END AS type_cible,
                    COALESCE(s.id_annonce, s.id_avis, s.id_produit) AS id_cible,
                    MAX(COALESCE(a.titre, p.nom, SUBSTR(av.commentaire, 1, 80))) AS libelle_cible,
                    -- Motif le plus fréquent pour cette cible (fonction analytique STATS_MODE)
                    STATS_MODE(s.motif) AS motif, COUNT(*) AS nb, MIN(s.date_signalement) AS date_signalement,
                    MAX(s.statut) AS statut
               FROM signalement s
               LEFT JOIN annonce a ON a.id = s.id_annonce
               LEFT JOIN produit p ON p.id = s.id_produit
               LEFT JOIN avis av ON av.id = s.id_avis
              WHERE s.statut = :statut
              GROUP BY s.id_annonce, s.id_avis, s.id_produit
              ORDER BY COUNT(*) DESC, MIN(s.date_signalement)
              FETCH FIRST 100 ROWS ONLY",
            ['statut' => $statut]));
    }

    /** Un signalement, sa cible et tous les signalements sur la même cible @return array<string, mixed>|null */
    public function signalement(int $id): ?array
    {
        $s = $this->db->ligne(
            'SELECT id, id_annonce, id_avis, id_produit, statut FROM signalement WHERE id = :id', ['id' => $id]);
        if ($s === null) {
            return null;
        }
        $cible = match (true) {
            $s['ID_ANNONCE'] !== null => $this->db->ligne(
                "SELECT 'ANNONCE' AS type, a.id, a.titre AS libelle, a.description AS texte, a.prix, a.statut,
                        a.score_risque, u.nom AS auteur, '/annonce/' || a.id AS url
                   FROM annonce a JOIN utilisateur u ON u.id = a.id_utilisateur WHERE a.id = :id", ['id' => $s['ID_ANNONCE']]),
            $s['ID_AVIS'] !== null => $this->db->ligne(
                "SELECT 'AVIS' AS type, av.id, p.nom AS libelle, av.commentaire AS texte, av.note AS prix, av.statut,
                        NULL AS score_risque, u.nom AS auteur, '/produit/' || p.id AS url
                   FROM avis av JOIN produit p ON p.id = av.id_produit JOIN utilisateur u ON u.id = av.id_utilisateur
                  WHERE av.id = :id", ['id' => $s['ID_AVIS']]),
            default => $this->db->ligne(
                "SELECT 'PRODUIT' AS type, p.id, p.nom AS libelle, p.description AS texte, p.prix_ht AS prix, p.statut,
                        NULL AS score_risque, b.nom AS auteur, '/produit/' || p.id AS url
                   FROM produit p JOIN boutique b ON b.id = p.id_boutique WHERE p.id = :id", ['id' => $s['ID_PRODUIT']]),
        };
        $tous = $this->db->lignes(
            'SELECT s.motif, s.commentaire, s.statut, s.date_signalement, u.nom AS auteur
               FROM signalement s JOIN utilisateur u ON u.id = s.id_auteur
              WHERE (s.id_annonce = :a OR s.id_avis = :v OR s.id_produit = :p) ORDER BY s.date_signalement',
            ['a' => $s['ID_ANNONCE'], 'v' => $s['ID_AVIS'], 'p' => $s['ID_PRODUIT']]);
        return ['id' => (int) $s['ID'], 'statut' => $s['STATUT'], 'cible' => $cible, 'signalements' => $tous];
    }

    public function traiterSignalement(int $id, int $idModerateur, string $decision): void
    {
        $p = ['id' => $id, 'admin' => $idModerateur, 'decision' => $decision];
        $this->db->appeler('BEGIN pkg_moderation.traiter(:id, :admin, :decision); END;', $p);
    }

    /** Derniers avis (publiés et masqués) @return list<array<string, mixed>> */
    public function avis(): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'note' => (int) $l['NOTE'], 'commentaire' => $l['COMMENTAIRE'] ?? '',
            'statut' => $l['STATUT'], 'produit' => $l['PRODUIT'], 'id_produit' => (int) $l['ID_PRODUIT'],
            'auteur' => $l['AUTEUR'], 'date' => $l['DATE_AVIS'],
        ], $this->db->lignes(
            'SELECT av.id, av.note, av.commentaire, av.statut, av.date_avis, av.id_produit, p.nom AS produit, u.nom AS auteur
               FROM avis av JOIN produit p ON p.id = av.id_produit JOIN utilisateur u ON u.id = av.id_utilisateur
              ORDER BY av.date_avis DESC FETCH FIRST 50 ROWS ONLY'));
    }

    public function changerStatutAvis(int $id, string $statut): void
    {
        $p = ['id' => $id, 'statut' => $statut];
        $this->db->appeler('BEGIN pkg_avis.changer_statut(:id, :statut); END;', $p);
    }
}
