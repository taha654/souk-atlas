<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Response;
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
}
