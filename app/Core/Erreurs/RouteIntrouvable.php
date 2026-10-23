<?php
declare(strict_types=1);

namespace App\Core\Erreurs;

/** Aucune route pour cette URL : page 404 */
final class RouteIntrouvable extends \RuntimeException
{
    public function __construct(string $chemin)
    {
        parent::__construct('Page introuvable : ' . $chemin);
    }
}
