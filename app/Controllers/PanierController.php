<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Response;
use App\Core\Session;
use App\Services\Panier;

/**
 * Panier en HTML classique : fonctionne SANS JavaScript (formulaires POST puis
 * redirection). panier.js utilise les mêmes opérations via /api/panier.
 */
final class PanierController extends Controller
{
    public function index(): Response
    {
        return $this->vue('panier/index', ['panier' => $this->panier()->contenu()], 'Mon panier');
    }

    public function ajouter(): Response
    {
        return $this->modifierPuisRediriger('ajouter', 'Produit ajouté au panier.');
    }

    public function modifier(): Response
    {
        return $this->modifierPuisRediriger('modifier', 'Quantité mise à jour.');
    }

    public function retirer(): Response
    {
        return $this->modifierPuisRediriger('retirer', 'Produit retiré du panier.');
    }

    private function modifierPuisRediriger(string $operation, string $message): Response
    {
        $retour = Auth::retourSur($this->request->champ('retour')) ?? '/panier';
        try {
            appliquer_operation_panier($this->panier(), $operation,
                $this->entier('id_produit', 1, PHP_INT_MAX), $this->request->champ('quantite'));
            $this->db->valider();
            Session::flash('succes', $message);
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger($retour);
    }

    private function panier(): Panier
    {
        return new Panier($this->db, Auth::utilisateur()['id'] ?? null);
    }
}
