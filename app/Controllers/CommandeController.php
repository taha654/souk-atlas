<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Config;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Response;
use App\Core\Session;
use App\Core\View;
use App\Models\Commande;
use App\Models\Utilisateur;
use App\Services\Mailer;
use App\Services\Panier;

final class CommandeController extends Controller
{
    // Clients et vendeurs achètent ; l'administrateur n'achète pas avec son compte d'admin
    private const ACHETEURS = ['CLIENT', 'VENDEUR'];

    // ------------------------------------------------------------------ passer commande

    public function formulaire(): Response
    {
        $moi = Auth::exigerRole(...self::ACHETEURS);
        $panier = (new Panier($this->db, $moi['id']))->contenu();
        if ($panier['lignes'] === []) {
            Session::flash('info', 'Votre panier est vide.');
            return $this->rediriger('/panier');
        }
        $compte = (new Utilisateur($this->db))->trouverParId($moi['id']);
        return $this->formulaireAvec($panier, [
            'mode' => 'CARTE', 'adresse' => '', 'ville' => $compte['VILLE'] ?? '',
            'telephone' => $compte['TELEPHONE'] ?? '',
        ], []);
    }

    public function passer(): Response
    {
        $moi = Auth::exigerRole(...self::ACHETEURS);
        $champs = [
            'mode' => $this->request->champ('mode'),
            'adresse' => $this->request->champ('adresse'),
            'ville' => $this->request->champ('ville'),
            'telephone' => $this->request->champ('telephone'),
            // Données de carte : transmises à PKG_PAIEMENT, jamais réaffichées ni journalisées
            'carte' => $this->request->champ('carte'),
            'mois' => $this->request->champ('mois'),
            'annee' => $this->request->champ('annee'),
            'cvv' => $this->request->champ('cvv'),
        ];
        // Ce qui pourra être réaffiché en cas d'erreur : surtout PAS la carte
        $reaffichage = array_intersect_key($champs, array_flip(['mode', 'adresse', 'ville', 'telephone']));

        $erreurs = Commande::validerFormulaire($champs);
        if ($erreurs === []) {
            try {
                $reference = (new Commande($this->db))->passer($moi['id'], $champs);
                $this->db->valider();
            } catch (ErreurMetier $erreur) {
                $this->db->annuler();
                return $this->apresRefus($erreur, $moi['id'], $reaffichage);
            }
            $this->envoyerConfirmation($reference, $moi);
            Session::flash('succes', 'Merci ! Votre commande est enregistrée.');
            return $this->rediriger('/achat/' . rawurlencode($reference));
        }
        return $this->formulaireAvec((new Panier($this->db, $moi['id']))->contenu(), $reaffichage, $erreurs, 422);
    }

    /**
     * Refus métier : un problème de carte se corrige sur place (même formulaire) ;
     * un problème de panier (stock, produit retiré, panier vide) se corrige dans le panier.
     *
     * @param array<string, string> $reaffichage
     */
    private function apresRefus(ErreurMetier $erreur, int $idClient, array $reaffichage): Response
    {
        $erreurCarte = match ($erreur->codeOracle) {
            ErreurMetier::CARTE_REFUSEE, ErreurMetier::CARTE_EXPIREE => 'carte',
            ErreurMetier::DONNEE_INVALIDE => 'general',
            default => null,
        };
        if ($erreurCarte !== null) {
            return $this->formulaireAvec((new Panier($this->db, $idClient))->contenu(), $reaffichage,
                [$erreurCarte => $erreur->getMessage()], 422);
        }
        Session::flash('erreur', $erreur->getMessage());
        return $this->rediriger('/panier');
    }

    /**
     * @param array<string, mixed> $panier
     * @param array<string, string> $valeurs
     * @param array<string, string> $erreurs
     */
    private function formulaireAvec(array $panier, array $valeurs, array $erreurs, int $statut = 200): Response
    {
        return $this->vue('commande/formulaire',
            ['panier' => $panier, 'valeurs' => $valeurs, 'erreurs' => $erreurs], 'Commande', $statut);
    }

    /** Email simulé ; un échec d'écriture ne doit pas faire échouer une commande déjà validée */
    private function envoyerConfirmation(string $reference, array $moi): void
    {
        try {
            $achat = (new Commande($this->db))->achat($reference, $moi['id']);
            $texte = View::fragment('emails/confirmation', [
                'achat' => $achat, 'nom' => $moi['nom'], 'url' => Config::get('url') . '/achat/' . rawurlencode($reference),
            ]);
            (new Mailer(Config::get('dossier_mails')))->envoyer($moi['email'],
                'Souk Atlas — confirmation de votre achat ' . $reference, $texte);
        } catch (\Throwable $erreur) {
            error_log('[Souk Atlas] Email de confirmation non écrit : ' . $erreur->getMessage());
        }
    }

    // ------------------------------------------------------------------ après la commande

    /** GET /achat/{reference} : confirmation et récapitulatif */
    public function achat(string $reference): Response
    {
        $achat = $this->achatDuClient($reference);
        return $this->vue('achat/detail', ['achat' => $achat], 'Achat ' . $achat['reference']);
    }

    /** GET /achat/{reference}/facture : page imprimable, avec son propre layout */
    public function facture(string $reference): Response
    {
        $achat = $this->achatDuClient($reference);
        $compte = (new Utilisateur($this->db))->trouverParId(Auth::utilisateur()['id']);
        return Response::html(View::rendre('achat/facture', ['achat' => $achat, 'client' => $compte],
            'Facture ' . $achat['reference'], 'layouts/impression'));
    }

    /** GET /mes-commandes */
    public function liste(): Response
    {
        $moi = Auth::exigerRole(...self::ACHETEURS);
        return $this->vue('commande/liste',
            ['achats' => (new Commande($this->db))->achatsDuClient($moi['id'])], 'Mes commandes');
    }

    /** GET /commande/{numero} : suivi d'une commande */
    public function detail(string $numero): Response
    {
        $moi = Auth::exigerRole(...self::ACHETEURS);
        $commande = (new Commande($this->db))->commande($numero, $moi['id']);
        if ($commande === null) {
            // 404 et non 403 : on ne confirme pas qu'une commande de ce numéro existe
            throw new RouteIntrouvable('/commande/' . $numero);
        }
        return $this->vue('commande/detail', ['commande' => $commande], 'Commande ' . $commande['numero']);
    }

    /** POST /commande/{numero}/annuler */
    public function annuler(string $numero): Response
    {
        $moi = Auth::exigerRole(...self::ACHETEURS);
        try {
            if (!(new Commande($this->db))->annuler($numero, $moi['id'])) {
                throw new RouteIntrouvable('/commande/' . $numero);
            }
            $this->db->valider();
            Session::flash('succes', 'Commande annulée. Les articles sont remis en stock'
                . ' ; un paiement par carte est remboursé.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/commande/' . rawurlencode($numero));
    }

    /** @return array<string, mixed> */
    private function achatDuClient(string $reference): array
    {
        $moi = Auth::exigerRole(...self::ACHETEURS);
        $achat = (new Commande($this->db))->achat($reference, $moi['id']);
        if ($achat === null) {
            throw new RouteIntrouvable('/achat/' . $reference);
        }
        return $achat;
    }
}
