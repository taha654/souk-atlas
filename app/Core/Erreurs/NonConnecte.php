<?php
declare(strict_types=1);

namespace App\Core\Erreurs;

/** Page réservée aux utilisateurs connectés : redirection vers /connexion */
final class NonConnecte extends \RuntimeException
{
}
