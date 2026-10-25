<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Config;
use App\Core\Controller;
use App\Core\Response;
use App\Services\PhotosDemo;

/** Page /credits : auteur et lien Pixabay de chaque photo de démonstration */
final class CreditsController extends Controller
{
    public function index(): Response
    {
        return $this->vue('credits/index', [
            'credits' => PhotosDemo::credits(Config::get('dossier_public')),
        ], 'Crédits photos');
    }
}
