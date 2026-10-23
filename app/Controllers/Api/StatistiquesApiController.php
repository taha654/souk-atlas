<?php
declare(strict_types=1);

namespace App\Controllers\Api;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Erreurs\RouteIntrouvable;
use App\Core\Response;
use App\Models\Boutique;
use App\Models\Statistiques;

/** GET /api/vendeur/statistiques?jours=30 : données des graphiques du tableau de bord */
final class StatistiquesApiController extends Controller
{
    private const PERIODES = [7, 30, 90, 365];

    public function vendeur(): Response
    {
        $moi = Auth::exigerRole('VENDEUR');
        $boutique = (new Boutique($this->db))->duVendeur($moi['id']);
        if ($boutique === null) {
            throw new RouteIntrouvable('Aucune boutique');
        }
        $jours = (int) $this->request->parametre('jours');
        $jours = in_array($jours, self::PERIODES, true) ? $jours : 30;
        return Response::json((new Statistiques($this->db))->tableauDeBord($boutique['id'], $jours));
    }
}
