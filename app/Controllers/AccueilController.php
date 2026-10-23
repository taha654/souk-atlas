<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;
use App\Core\Response;
use App\Models\Annonce;
use App\Models\FiltresAnnonces;
use App\Models\FiltresCatalogue;
use App\Models\Produit;

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
        // Vitrine : les produits les mieux notés (en stock) et les annonces les plus récentes
        $produits = (new Produit($this->db))->rechercher(new FiltresCatalogue(tri: 'note', enStock: true))['produits'];
        $annonces = (new Annonce($this->db))->rechercher(new FiltresAnnonces())['annonces'];
        return $this->vue('accueil/index', [
            'chiffres' => $chiffres,
            'produits' => array_slice($produits, 0, 4),
            'annonces' => array_slice($annonces, 0, 4),
        ]);
    }
}
