<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\Database;

/**
 * Commandes du client : passage (PKG_COMMANDE), lecture, annulation.
 * Un ACHAT (reference_achat) regroupe une commande par boutique.
 *
 * Chaque lecture filtre sur id_client : un client ne voit jamais les commandes
 * d'un autre, même en changeant le numéro dans l'URL.
 */
final class Commande
{
    public const ETAPES = ['EN_ATTENTE' => 'Reçue', 'PAYEE' => 'Payée', 'EXPEDIEE' => 'Expédiée', 'LIVREE' => 'Livrée'];
    public const STATUTS = [
        'EN_ATTENTE' => 'En attente', 'PAYEE' => 'Payée', 'EXPEDIEE' => 'Expédiée',
        'LIVREE' => 'Livrée', 'ANNULEE' => 'Annulée',
    ];

    public function __construct(private readonly Database $db)
    {
    }

    /**
     * Validation du formulaire de livraison et de paiement (fonction pure, testable).
     * La carte n'est contrôlée ici que sur la forme : Luhn et date d'expiration
     * sont vérifiés en base par PKG_PAIEMENT (une seule source de vérité).
     *
     * @param array<string, string> $champs
     * @return array<string, string> erreurs par champ
     */
    public static function validerFormulaire(array $champs): array
    {
        $erreurs = [];
        $longueur = static fn (string $cle) => mb_strlen($champs[$cle] ?? '');
        if ($longueur('adresse') < 5 || $longueur('adresse') > 400) {
            $erreurs['adresse'] = 'Indiquez une adresse de livraison complète (5 à 400 caractères).';
        }
        if ($longueur('ville') < 2 || $longueur('ville') > 60) {
            $erreurs['ville'] = 'Indiquez la ville de livraison.';
        }
        if (!Utilisateur::telephoneValide($champs['telephone'] ?? '')) {
            $erreurs['telephone'] = 'Numéro attendu : 06 12 34 56 78 ou +212 6 12 34 56 78.';
        }
        $mode = $champs['mode'] ?? '';
        if (!in_array($mode, ['CARTE', 'LIVRAISON'], true)) {
            $erreurs['mode'] = 'Choisissez un mode de paiement.';
        } elseif ($mode === 'CARTE') {
            if (preg_match('/^[\d -]{13,23}$/', $champs['carte'] ?? '') !== 1) {
                $erreurs['carte'] = 'Numéro de carte incomplet.';
            }
            if (!ctype_digit($champs['mois'] ?? '') || !ctype_digit($champs['annee'] ?? '')) {
                $erreurs['expiration'] = 'Indiquez le mois et l\'année d\'expiration.';
            }
            if (preg_match('/^\d{3}$/', $champs['cvv'] ?? '') !== 1) {
                $erreurs['cvv'] = 'Le cryptogramme comporte 3 chiffres.';
            }
        }
        return $erreurs;
    }

    /**
     * Passe la commande en UNE transaction (PKG_COMMANDE.passer_commande).
     * Le numéro de carte n'est que transmis : le package ne garde que 4 chiffres.
     * Ne valide PAS la transaction : c'est le contrôleur qui fait valider().
     *
     * @param array{mode: string, adresse: string, ville: string, telephone: string,
     *              carte: string, mois: string, annee: string, cvv: string} $donnees
     */
    public function passer(int $idClient, array $donnees): string
    {
        $carte = $donnees['mode'] === 'CARTE';
        $p = [
            'client' => $idClient,
            'mode' => $donnees['mode'],
            'adresse' => $donnees['adresse'],
            'ville' => $donnees['ville'],
            'telephone' => $donnees['telephone'],
            'carte' => $carte ? $donnees['carte'] : null,
            'mois' => $carte && ctype_digit($donnees['mois']) ? (int) $donnees['mois'] : null,
            'annee' => $carte && ctype_digit($donnees['annee']) ? (int) $donnees['annee'] : null,
            'cvv' => $carte ? $donnees['cvv'] : null,
            'reference' => null,
        ];
        $this->db->appeler(
            'BEGIN pkg_commande.passer_commande(:client, :mode, :adresse, :ville, :telephone,
                                                :carte, :mois, :annee, :cvv, :reference); END;',
            $p,
        );
        return (string) $p['reference'];
    }

    /**
     * Un achat complet (toutes ses commandes, avec lignes et paiement), ou null
     * s'il n'existe pas OU n'appartient pas à ce client.
     *
     * @return array<string, mixed>|null
     */
    public function achat(string $reference, int $idClient): ?array
    {
        $commandes = $this->db->lignes(
            "SELECT c.id, c.numero, c.statut, c.total_ht, c.tva, c.total_ttc, c.mode_paiement,
                    c.adresse_livraison, c.ville_livraison, c.telephone_livraison, c.date_commande,
                    b.nom AS boutique, b.ville AS ville_boutique,
                    p.statut AS statut_paiement, p.carte_4_derniers
               FROM commande c
               JOIN boutique b ON b.id = c.id_boutique
               LEFT JOIN paiement p ON p.id_commande = c.id
              WHERE c.reference_achat = :reference AND c.id_client = :client
              ORDER BY c.numero",
            ['reference' => $reference, 'client' => $idClient],
        );
        if ($commandes === []) {
            return null;
        }
        $commandes = array_map(fn (array $c) => self::commandeDepuisLigne($c) + ['lignes' => $this->lignes((int) $c['ID'])],
            $commandes);
        return [
            'reference' => $reference,
            'date' => $commandes[0]['date'],
            'mode_paiement' => $commandes[0]['mode_paiement'],
            'carte_4_derniers' => $commandes[0]['carte_4_derniers'],
            'adresse' => $commandes[0]['adresse'],
            'ville' => $commandes[0]['ville'],
            'telephone' => $commandes[0]['telephone'],
            'commandes' => $commandes,
            'total_ht' => round(array_sum(array_column($commandes, 'total_ht')), 2),
            'tva' => round(array_sum(array_column($commandes, 'tva')), 2),
            'total_ttc' => round(array_sum(array_column($commandes, 'total_ttc')), 2),
        ];
    }

    /**
     * Achats du client, du plus récent au plus ancien (un résumé par achat).
     *
     * @return list<array<string, mixed>>
     */
    public function achatsDuClient(int $idClient): array
    {
        $lignes = $this->db->lignes(
            "SELECT reference_achat, MIN(date_commande) AS date_achat, COUNT(*) AS nb_commandes,
                    SUM(total_ttc) AS total_ttc,
                    LISTAGG(numero || ':' || statut, ',') WITHIN GROUP (ORDER BY numero) AS statuts
               FROM commande
              WHERE id_client = :client
              GROUP BY reference_achat
              ORDER BY MIN(date_commande) DESC",
            ['client' => $idClient],
        );
        return array_map(static function (array $l): array {
            $commandes = [];
            foreach (explode(',', $l['STATUTS']) as $paire) {
                [$numero, $statut] = explode(':', $paire);
                $commandes[] = ['numero' => $numero, 'statut' => $statut];
            }
            return [
                'reference' => $l['REFERENCE_ACHAT'],
                'date' => $l['DATE_ACHAT'],
                'total_ttc' => (float) $l['TOTAL_TTC'],
                'commandes' => $commandes,
            ];
        }, $lignes);
    }

    /**
     * Une commande du client, avec ses dates de suivi (null si absente ou d'un autre client).
     *
     * @return array<string, mixed>|null
     */
    public function commande(string $numero, int $idClient): ?array
    {
        $ligne = $this->db->ligne(
            "SELECT c.id, c.numero, c.reference_achat, c.statut, c.total_ht, c.tva, c.total_ttc, c.mode_paiement,
                    c.adresse_livraison, c.ville_livraison, c.telephone_livraison, c.date_commande,
                    c.date_paiement, c.date_expedition, c.date_livraison, c.date_annulation,
                    b.nom AS boutique, b.ville AS ville_boutique,
                    p.statut AS statut_paiement, p.carte_4_derniers
               FROM commande c
               JOIN boutique b ON b.id = c.id_boutique
               LEFT JOIN paiement p ON p.id_commande = c.id
              WHERE c.numero = :numero AND c.id_client = :client",
            ['numero' => $numero, 'client' => $idClient],
        );
        if ($ligne === null) {
            return null;
        }
        return self::commandeDepuisLigne($ligne) + [
            'reference' => $ligne['REFERENCE_ACHAT'],
            'dates' => [
                'EN_ATTENTE' => $ligne['DATE_COMMANDE'],
                'PAYEE' => $ligne['DATE_PAIEMENT'],
                'EXPEDIEE' => $ligne['DATE_EXPEDITION'],
                'LIVREE' => $ligne['DATE_LIVRAISON'],
                'ANNULEE' => $ligne['DATE_ANNULATION'],
            ],
            'lignes' => $this->lignes((int) $ligne['ID']),
        ];
    }

    /** Annule une commande du client ; false si elle n'existe pas ou n'est pas à lui */
    public function annuler(string $numero, int $idClient): bool
    {
        $id = $this->db->valeur(
            'SELECT id FROM commande WHERE numero = :numero AND id_client = :client',
            ['numero' => $numero, 'client' => $idClient],
        );
        if ($id === null) {
            return false;
        }
        $p = ['id' => (int) $id];
        $this->db->appeler('BEGIN pkg_commande.annuler(:id); END;', $p);
        return true;
    }

    /** @return list<array<string, mixed>> */
    private function lignes(int $idCommande): array
    {
        $lignes = $this->db->lignes(
            'SELECT cl.id_produit, cl.nom_produit, cl.prix_unitaire_ht, cl.quantite, cl.total_ligne_ht,
                    pkg_avis.peut_donner_avis(c.id_client, cl.id_produit) AS peut_noter
               FROM commande_ligne cl JOIN commande c ON c.id = cl.id_commande
              WHERE cl.id_commande = :id ORDER BY cl.id',
            ['id' => $idCommande],
        );
        return array_map(static fn (array $l) => [
            'id_produit' => (int) $l['ID_PRODUIT'],
            // Nom COPIÉ au moment de la commande : la facture ne change jamais
            'nom' => $l['NOM_PRODUIT'],
            'prix_unitaire_ht' => (float) $l['PRIX_UNITAIRE_HT'],
            'quantite' => (int) $l['QUANTITE'],
            'total_ligne_ht' => (float) $l['TOTAL_LIGNE_HT'],
            'peut_noter' => (int) $l['PEUT_NOTER'] === 1,
        ], $lignes);
    }

    /**
     * @param array<string, mixed> $c
     * @return array<string, mixed>
     */
    private static function commandeDepuisLigne(array $c): array
    {
        return [
            'id' => (int) $c['ID'],
            'numero' => $c['NUMERO'],
            'statut' => $c['STATUT'],
            'total_ht' => (float) $c['TOTAL_HT'],
            'tva' => (float) $c['TVA'],
            'total_ttc' => (float) $c['TOTAL_TTC'],
            'mode_paiement' => $c['MODE_PAIEMENT'],
            'adresse' => $c['ADRESSE_LIVRAISON'],
            'ville' => $c['VILLE_LIVRAISON'],
            'telephone' => $c['TELEPHONE_LIVRAISON'],
            'date' => $c['DATE_COMMANDE'],
            'boutique' => $c['BOUTIQUE'],
            'ville_boutique' => $c['VILLE_BOUTIQUE'],
            'statut_paiement' => $c['STATUT_PAIEMENT'],
            'carte_4_derniers' => $c['CARTE_4_DERNIERS'],
            // Le client peut annuler tant que la commande n'est pas partie
            'annulable' => in_array($c['STATUT'], ['EN_ATTENTE', 'PAYEE'], true),
        ];
    }
}
