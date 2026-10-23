<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;
use App\Core\Response;

final class AccueilController extends Controller
{
    public function index(): Response
    {
        // Chiffres lus dans Oracle : la page prouve que toute la chaîne fonctionne
        $chiffres = $this->db->ligne(
            "SELECT (SELECT COUNT(*) FROM produit p JOIN boutique b ON b.id = p.id_boutique
                      WHERE p.statut = 'ACTIF' AND b.statut = 'VALIDEE') AS produits,
                    (SELECT COUNT(*) FROM annonce WHERE statut = 'EN_LIGNE') AS annonces,
                    (SELECT COUNT(*) FROM boutique WHERE statut = 'VALIDEE') AS boutiques
               FROM dual",
        );
        return $this->vue('accueil/index', ['chiffres' => $chiffres]);
    }
}
