<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Response;
use App\Core\Session;
use App\Models\JetonApi;
use App\Models\Utilisateur;

final class CompteController extends Controller
{
    public function index(): Response
    {
        // Tout utilisateur connecté a un compte, quel que soit son rôle
        $moi = Auth::exigerRole('CLIENT', 'VENDEUR', 'ADMIN');
        $compte = (new Utilisateur($this->db))->trouverParId($moi['id']);
        return $this->vue('compte/index', ['compte' => $compte], 'Mon compte');
    }

    // ------------------------------------------------------------------ jetons d'API (outil console)

    public function jetons(): Response
    {
        $moi = Auth::exigerRole('VENDEUR', 'ADMIN');
        return $this->pageJetons($moi['id'], null, [], 200);
    }

    public function creerJeton(): Response
    {
        $moi = Auth::exigerRole('VENDEUR', 'ADMIN');
        $libelle = mb_substr($this->request->champ('libelle'), 0, 100);
        $jours = (int) $this->request->champ('jours');
        if (!in_array($jours, JetonApi::DUREES, true)) {
            return $this->pageJetons($moi['id'], null, ['general' => 'Durée de validité invalide.'], 422);
        }
        try {
            $nouveau = (new JetonApi($this->db))->creer($moi['id'], $libelle, $jours);
            $this->db->valider();
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            return $this->pageJetons($moi['id'], null, ['general' => $erreur->getMessage()], 422);
        }
        // Pas de redirection : le jeton en clair ne doit transiter ni par la
        // session (message flash) ni par une URL. Il n'est affiché qu'ici, une fois.
        return $this->pageJetons($moi['id'], $nouveau['jeton'], [], 201);
    }

    public function revoquerJeton(string $id): Response
    {
        $moi = Auth::exigerRole('VENDEUR', 'ADMIN');
        $idJeton = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if ($idJeton === false) {
            throw new RouteIntrouvable($id);
        }
        try {
            (new JetonApi($this->db))->revoquer($idJeton, $moi['id']);
            $this->db->valider();
            Session::flash('succes', 'Jeton révoqué : la console ne peut plus l\'utiliser.');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger('/compte/jetons');
    }

    /** @param array<string, string> $erreurs */
    private function pageJetons(int $idUtilisateur, ?string $nouveauJeton, array $erreurs, int $statut): Response
    {
        $reponse = $this->vue('compte/jetons', [
            'jetons' => (new JetonApi($this->db))->liste($idUtilisateur),
            'nouveau' => $nouveauJeton,
            'erreurs' => $erreurs,
        ], 'Jetons d\'accès', $statut);
        // Page contenant un secret : ni le navigateur ni un proxy ne doivent la garder en cache
        return $nouveauJeton === null ? $reponse : $reponse->avecEntete('Cache-Control', 'no-store');
    }
}
