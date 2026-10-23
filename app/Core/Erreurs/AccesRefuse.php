<?php
declare(strict_types=1);

namespace App\Core\Erreurs;

/** Connecté, mais sans le rôle requis, ou jeton CSRF invalide : 403 */
final class AccesRefuse extends \RuntimeException
{
}
