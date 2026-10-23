<?php
declare(strict_types=1);

namespace App\Core\Erreurs;

/**
 * Erreur Oracle technique (connexion perdue, ORA-00942 table inexistante…).
 * Son message reste dans les journaux : l'utilisateur voit une page 500 générique.
 */
final class ErreurBaseDeDonnees extends \RuntimeException
{
}
