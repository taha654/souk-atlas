<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Classe mère des contrôleurs : donne accès à la requête et à la base, et
 * quelques raccourcis pour construire une réponse.
 */
abstract class Controller
{
    public function __construct(
        protected readonly Request $request,
        protected readonly Database $db,
    ) {
    }

    /** @param array<string, mixed> $donnees */
    protected function vue(string $gabarit, array $donnees = [], string $titre = 'Souk Atlas',
                           int $statut = 200): Response
    {
        return Response::html(View::rendre($gabarit, $donnees, $titre), $statut);
    }

    protected function rediriger(string $url): Response
    {
        return Response::redirection($url);
    }

    /** Champ de formulaire entier entre $min et $max, ou null s'il est invalide */
    protected function entier(string $champ, int $min, int $max): ?int
    {
        $valeur = filter_var($this->request->champ($champ), FILTER_VALIDATE_INT,
            ['options' => ['min_range' => $min, 'max_range' => $max]]);
        return $valeur === false ? null : $valeur;
    }
}
