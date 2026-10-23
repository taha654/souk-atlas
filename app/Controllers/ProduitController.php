<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Config;
use App\Core\Controller;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Response;
use App\Models\Categorie;
use App\Models\Produit;
use App\Services\Recommandations;

final class ProduitController extends Controller
{
    public function fiche(string $id): Response
    {
        // {id} arrive de l'URL sous forme de texte : "/produit/abc" ou "/produit/0" → 404
        $idProduit = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        $modele = new Produit($this->db);
        $produit = $idProduit === false ? null : $modele->fiche($idProduit);
        if ($produit === null) {
            throw new RouteIntrouvable('/produit/' . $id);
        }

        return $this->vue('produit/fiche', [
            'produit' => $produit,
            'chemin' => (new Categorie($this->db))->chemin($produit['id_categorie']),
            'avis' => $modele->avis($produit['id']),
            // Calculées par le moteur C++ (étape 8)
            'recommandations' => (new Recommandations($this->db, $this->moteur(),
                (float) Config::get('moteur')['recommandations_heures']))->pour($produit['id']),
        ], $produit['nom']);
    }
}
