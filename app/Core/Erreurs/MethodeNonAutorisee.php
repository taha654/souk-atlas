<?php
declare(strict_types=1);

namespace App\Core\Erreurs;

/** L'URL existe, mais pas pour cette méthode HTTP (ex. GET /deconnexion) : 405 */
final class MethodeNonAutorisee extends \RuntimeException
{
    /** @param list<string> $methodesAutorisees */
    public function __construct(public readonly array $methodesAutorisees)
    {
        parent::__construct('Méthode non autorisée');
    }
}
