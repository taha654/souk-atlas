<?php
declare(strict_types=1);

namespace App\Controllers\Api;

use App\Core\Controller;
use App\Core\Response;
use App\Models\FiltresCatalogue;
use App\Models\Produit;

/**
 * API JSON du catalogue, appelée par le JavaScript (fetch).
 * Lecture seule (GET) : pas besoin de jeton CSRF, rien n'est modifié.
 */
final class CatalogueApiController extends Controller
{
    /** GET /api/produits?q=…&categorie=…&prix_min=…&prix_max=…&tri=…&page=…&en_stock=1 */
    public function produits(): Response
    {
        $filtres = FiltresCatalogue::depuisRequete($this->request->query);
        $resultat = (new Produit($this->db))->rechercher($filtres);

        // Les prix formatés sont fournis par le serveur : le même format
        // ("3 948,00 MAD") en PHP et en JavaScript, sans dupliquer la règle
        $produits = array_map(static fn (array $p) => $p + [
            'prix_courant_ttc_texte' => format_prix($p['prix_courant_ttc']),
            'prix_ttc_texte' => format_prix($p['prix_ttc']),
        ], $resultat['produits']);

        return Response::json([
            'produits' => $produits,
            'total' => $resultat['total'],
            'page' => $filtres->page,
            'pages' => max(1, (int) ceil($resultat['total'] / FiltresCatalogue::TAILLE_PAGE)),
            'filtres' => $filtres->versQuery(),
            'url' => $filtres->url(),
        ]);
    }

    /** GET /api/suggestions?q=sam → [{"id": 1, "nom": "Smartphone Samsung…"}, …] */
    public function suggestions(): Response
    {
        return Response::json((new Produit($this->db))->suggestions($this->request->parametre('q')));
    }
}
