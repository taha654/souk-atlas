<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;
use App\Core\Response;
use App\Models\Categorie;
use App\Models\FiltresCatalogue;
use App\Models\Produit;

final class CatalogueController extends Controller
{
    /**
     * Page complète, rendue côté serveur : elle fonctionne SANS JavaScript.
     * catalogue.js l'améliore ensuite (filtres sans rechargement via /api/produits).
     */
    public function index(): Response
    {
        $filtres = FiltresCatalogue::depuisRequete($this->request->query);
        $resultat = (new Produit($this->db))->rechercher($filtres);
        $categories = new Categorie($this->db);

        return $this->vue('catalogue/index', [
            'filtres' => $filtres,
            'produits' => $resultat['produits'],
            'total' => $resultat['total'],
            'arbre' => $categories->arbre(),
            'chemin' => $filtres->categorie === null ? [] : $categories->chemin($filtres->categorie),
        ], $filtres->texte === '' ? 'Catalogue' : 'Recherche : ' . $filtres->texte);
    }
}
