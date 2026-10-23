<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/** Messagerie entre acheteurs et auteurs d'annonces (PKG_MESSAGERIE) */
final class Messagerie
{
    public function __construct(private readonly Database $db)
    {
    }

    /** Conversation existante ou nouvelle (règles : PKG_MESSAGERIE) */
    public function ouvrir(int $idAnnonce, int $idAcheteur): int
    {
        $p = ['a' => $idAnnonce, 'u' => $idAcheteur, 'id' => null];
        $this->db->appeler('BEGIN pkg_messagerie.ouvrir_conversation(:a, :u, :id); END;', $p);
        return (int) $p['id'];
    }

    public function envoyer(int $idConversation, int $idExpediteur, string $contenu): int
    {
        $p = ['c' => $idConversation, 'u' => $idExpediteur, 'contenu' => $contenu, 'id' => null];
        $this->db->appeler('BEGIN pkg_messagerie.envoyer_message(:c, :u, :contenu, :id); END;', $p);
        return (int) $p['id'];
    }

    public function marquerLu(int $idConversation, int $idLecteur): void
    {
        $p = ['c' => $idConversation, 'u' => $idLecteur, 'nb' => null];
        $this->db->appeler('BEGIN pkg_messagerie.marquer_comme_lu(:c, :u, :nb); END;', $p);
    }

    public function nbNonLus(int $idUtilisateur): int
    {
        return (int) $this->db->valeur('SELECT pkg_messagerie.nb_non_lus(:u) FROM dual', ['u' => $idUtilisateur]);
    }

    /**
     * Messages d'id > $apresId (polling : le navigateur ne redemande que les nouveaux).
     * PKG_MESSAGERIE refuse un lecteur qui ne participe pas (-20012).
     *
     * @return list<array<string, mixed>>
     */
    public function messages(int $idConversation, int $idLecteur, int $apresId = 0): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'],
            'moi' => (int) $l['ID_EXPEDITEUR'] === $idLecteur,
            'expediteur' => Produit::nomCourt($l['EXPEDITEUR']),
            'contenu' => $l['CONTENU'],
            'lu' => (int) $l['LU'] === 1,
            // date_envoi est un TIMESTAMP : format renvoyé par Oracle selon la session
            'date' => substr((string) $l['DATE_ENVOI'], 0, 19),
        ], $this->db->curseur("pkg_messagerie.messages(:c, :u, :apres)",
            ['c' => $idConversation, 'u' => $idLecteur, 'apres' => $apresId]));
    }

    /**
     * Conversations de l'utilisateur (acheteur ou vendeur), la plus récente d'abord.
     *
     * @return list<array<string, mixed>>
     */
    public function conversations(int $idUtilisateur): array
    {
        return array_map(static fn (array $l) => [
            'id' => (int) $l['ID'], 'id_annonce' => (int) $l['ID_ANNONCE'], 'titre' => $l['TITRE'],
            'statut_annonce' => $l['STATUT'], 'interlocuteur' => Produit::nomCourt($l['INTERLOCUTEUR']),
            'je_vends' => (int) $l['ID_VENDEUR'] === $idUtilisateur, 'date' => $l['DATE_DERNIER_MESSAGE'],
            'non_lus' => (int) $l['NON_LUS'], 'apercu' => $l['APERCU'],
        ], $this->db->lignes(
            'SELECT c.id, c.id_annonce, a.titre, a.statut, c.id_vendeur, c.date_dernier_message,
                    u.nom AS interlocuteur,
                    (SELECT COUNT(*) FROM message m WHERE m.id_conversation = c.id
                        AND m.id_expediteur <> :u AND m.lu = 0) AS non_lus,
                    (SELECT SUBSTR(MAX(m.contenu) KEEP (DENSE_RANK LAST ORDER BY m.id), 1, 80)
                       FROM message m WHERE m.id_conversation = c.id) AS apercu
               FROM conversation c
               JOIN annonce a ON a.id = c.id_annonce
               JOIN utilisateur u ON u.id = CASE WHEN c.id_acheteur = :u THEN c.id_vendeur ELSE c.id_acheteur END
              WHERE :u IN (c.id_acheteur, c.id_vendeur)
              ORDER BY c.date_dernier_message DESC',
            ['u' => $idUtilisateur]));
    }

    /** @return array<string, mixed>|null en-tête d'une conversation dont l'utilisateur est participant */
    public function conversation(int $idConversation, int $idUtilisateur): ?array
    {
        $l = $this->db->ligne(
            'SELECT c.id, c.id_annonce, a.titre, a.prix, a.statut, c.id_vendeur, u.nom AS interlocuteur
               FROM conversation c JOIN annonce a ON a.id = c.id_annonce
               JOIN utilisateur u ON u.id = CASE WHEN c.id_acheteur = :u THEN c.id_vendeur ELSE c.id_acheteur END
              WHERE c.id = :c AND :u IN (c.id_acheteur, c.id_vendeur)',
            ['c' => $idConversation, 'u' => $idUtilisateur]);
        return $l === null ? null : [
            'id' => (int) $l['ID'], 'id_annonce' => (int) $l['ID_ANNONCE'], 'titre' => $l['TITRE'],
            'prix' => (float) $l['PRIX'], 'statut_annonce' => $l['STATUT'],
            'je_vends' => (int) $l['ID_VENDEUR'] === $idUtilisateur, 'interlocuteur' => Produit::nomCourt($l['INTERLOCUTEUR']),
        ];
    }
}
