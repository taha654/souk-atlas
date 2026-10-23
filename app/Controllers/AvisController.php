<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Response;
use App\Core\Session;
use App\Models\Avis;

final class AvisController extends Controller
{
    /** POST /produit/{id}/avis — depuis le détail d'une commande livrée */
    public function deposer(string $id): Response
    {
        $moi = Auth::exigerRole('CLIENT', 'VENDEUR');
        $retour = Auth::retourSur($this->request->champ('retour')) ?? '/mes-commandes';
        $idProduit = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        $note = $this->entier('note', 1, 5);
        $commentaire = mb_substr($this->request->champ('commentaire'), 0, 2000);

        if ($idProduit === false || $note === null) {
            Session::flash('erreur', 'Choisissez une note de 1 à 5 étoiles.');
            return $this->rediriger($retour);
        }
        try {
            // Les règles (produit livré, un seul avis) sont vérifiées en base par PKG_AVIS
            (new Avis($this->db))->deposer($moi['id'], $idProduit, $note, $commentaire);
            $this->db->valider();
            Session::flash('succes', 'Merci pour votre avis !');
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            Session::flash('erreur', $erreur->getMessage());
        }
        return $this->rediriger($retour);
    }
}
