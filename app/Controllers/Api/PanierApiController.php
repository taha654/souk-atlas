<?php
declare(strict_types=1);

namespace App\Controllers\Api;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Response;
use App\Services\Panier;

/**
 * API JSON du panier pour panier.js.
 * Le POST est protégé par le jeton CSRF (en-tête X-CSRF-Token, vérifié par le
 * contrôleur frontal comme pour tout POST).
 */
final class PanierApiController extends Controller
{
    /** GET /api/panier */
    public function etat(): Response
    {
        return Response::json(self::versJson($this->panier()->contenu()));
    }

    /** POST /api/panier : operation = ajouter | modifier | retirer, id_produit, quantite */
    public function operation(): Response
    {
        $panier = $this->panier();
        try {
            appliquer_operation_panier($panier, $this->request->champ('operation'),
                $this->entier('id_produit', 1, PHP_INT_MAX), $this->request->champ('quantite'));
            $this->db->valider();
            return Response::json(self::versJson($panier->contenu()));
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            // 422 : demande comprise mais refusée par une règle métier (stock…)
            return Response::json(['erreur' => 'Action impossible', 'message' => $erreur->getMessage()]
                + self::versJson($panier->contenu()), 422);
        }
    }

    private function panier(): Panier
    {
        return new Panier($this->db, Auth::utilisateur()['id'] ?? null);
    }

    /**
     * Contenu du panier + textes déjà formatés (même format qu'en PHP).
     *
     * @param array<string, mixed> $contenu
     * @return array<string, mixed>
     */
    private static function versJson(array $contenu): array
    {
        return [
            'nb_articles' => $contenu['nb_articles'],
            'lignes' => array_map(static fn (array $l) => [
                'id_produit' => $l['id_produit'],
                'quantite' => $l['quantite'],
                'disponible' => $l['disponible'],
                'total_ligne_ttc_texte' => format_prix(total_ligne_ttc($l)),
            ], $contenu['lignes']),
            'total_ht_texte' => format_prix($contenu['total_ht']),
            'tva_texte' => format_prix($contenu['tva']),
            'total_ttc_texte' => format_prix($contenu['total_ttc']),
        ];
    }
}
