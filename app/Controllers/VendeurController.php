<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Controller;
use App\Core\Response;
use App\Models\Boutique;

final class VendeurController extends Controller
{
    public function index(): Response
    {
        $moi = Auth::exigerRole('VENDEUR');
        $boutique = (new Boutique($this->db))->duVendeur($moi['id']);
        return $this->vue('vendeur/index', ['boutique' => $boutique], 'Espace vendeur');
    }
}
