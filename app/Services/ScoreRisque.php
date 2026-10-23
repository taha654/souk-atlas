<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Database;

/**
 * Score de risque (0 à 100) calculé par le moteur C++ :
 *  - d'une annonce, AVANT sa publication : à partir de 60, elle attend un
 *    modérateur au lieu d'être mise en ligne (règle appliquée par PKG_ANNONCE) ;
 *  - des commandes d'un achat, APRÈS leur enregistrement : le vendeur voit
 *    s'il doit vérifier une commande avant de l'expédier.
 *
 * Si le moteur ne répond pas, le score vaut null : le site continue de
 * fonctionner (l'annonce part en ligne sans score, comme avant l'étape 8).
 */
final class ScoreRisque
{
    public function __construct(
        private readonly Database $db,
        private readonly CppEngine $moteur,
    ) {
    }

    /**
     * @param array{id_categorie: int, titre: string, description: string, prix: float} $annonce
     * @return array{score: int, niveau: string, raisons: list<array{regle: string, points: int, detail: string}>}|null
     */
    public function annonce(int $idAuteur, array $annonce): ?array
    {
        $contexte = $this->db->curseur('pkg_annonce.contexte_risque(:u, :cat)',
            ['u' => $idAuteur, 'cat' => $annonce['id_categorie']])[0] ?? [];
        return $this->calculer([
            'action' => 'risque_annonce',
            'annonce' => ['titre' => $annonce['titre'], 'description' => $annonce['description'],
                          'prix' => (float) $annonce['prix']],
            'categorie' => ['prix_median' => (float) ($contexte['PRIX_MEDIAN'] ?? 0),
                            'nb_annonces' => (int) ($contexte['NB_ANNONCES'] ?? 0)],
            'auteur' => ['annonces_24h' => (int) ($contexte['ANNONCES_24H'] ?? 0)],
            'compte' => ['anciennete_jours' => (float) ($contexte['ANCIENNETE_JOURS'] ?? 365)],
        ]);
    }

    /**
     * Note chaque commande d'un achat et VALIDE les scores. Ne lève jamais
     * d'exception : la commande est déjà enregistrée, un score manquant n'est
     * pas une raison de montrer une erreur au client.
     */
    public function achat(string $reference): void
    {
        try {
            foreach ($this->db->curseur('pkg_commande.contexte_risque(:ref)', ['ref' => $reference]) as $c) {
                $resultat = $this->calculer([
                    'action' => 'risque_commande',
                    'commande' => ['total_ttc' => (float) $c['TOTAL_TTC'], 'quantite_max' => (int) $c['QUANTITE_MAX'],
                                   'mode_paiement' => $c['MODE_PAIEMENT']],
                    'client' => ['commandes_precedentes' => (int) $c['COMMANDES_PRECEDENTES'],
                                 'panier_moyen' => (float) $c['PANIER_MOYEN'],
                                 'commandes_24h' => (int) $c['COMMANDES_24H']],
                    'compte' => ['anciennete_jours' => (float) $c['ANCIENNETE_JOURS']],
                ]);
                if ($resultat !== null) {
                    $p = ['id' => (int) $c['ID'], 'score' => $resultat['score']];
                    $this->db->appeler('BEGIN pkg_commande.definir_score(:id, :score); END;', $p);
                }
            }
            $this->db->valider();
        } catch (\Throwable $erreur) {
            $this->db->annuler();
            error_log('[Souk Atlas] Score de risque de l\'achat ' . $reference . ' non calculé : ' . $erreur->getMessage());
        }
    }

    /** @param array<string, mixed> $requete */
    private function calculer(array $requete): ?array
    {
        try {
            $reponse = $this->moteur->executer($requete);
            return ['score' => (int) $reponse['score'], 'niveau' => (string) $reponse['niveau'],
                    'raisons' => $reponse['raisons'] ?? []];
        } catch (ErreurMoteur $erreur) {
            error_log('[Souk Atlas] ' . $erreur->getMessage());
            return null;
        }
    }
}
