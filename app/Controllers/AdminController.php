<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Response;

final class AdminController extends Controller
{
    public function index(): Response
    {
        Auth::exigerRole('ADMIN');
        // Ce qui attend l'admin (l'espace complet arrive à l'étape 7)
        $aTraiter = $this->db->ligne(
            "SELECT (SELECT COUNT(*) FROM boutique WHERE statut = 'EN_ATTENTE') AS boutiques,
                    (SELECT COUNT(*) FROM annonce WHERE statut = 'EN_MODERATION') AS annonces,
                    (SELECT COUNT(*) FROM signalement WHERE statut = 'OUVERT') AS signalements,
                    (SELECT COUNT(*) FROM utilisateur) AS utilisateurs
               FROM dual",
        );
        return $this->vue('admin/index', ['aTraiter' => $aTraiter], 'Administration');
    }
}
