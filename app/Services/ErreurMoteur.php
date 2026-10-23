<?php
declare(strict_types=1);

namespace App\Services;

/** Le moteur C++ est absent, trop lent, ou a répondu par une erreur */
final class ErreurMoteur extends \RuntimeException
{
}
