<?php
declare(strict_types=1);

namespace App\Core;

use App\Core\Erreurs\MethodeNonAutorisee;
use App\Core\Erreurs\RouteIntrouvable;

/**
 * Routeur maison : associe "méthode + motif d'URL" à "Contrôleur@action".
 *
 *   $router->get('/produit/{id}', 'ProduitController@fiche');
 *
 * Un motif est transformé en expression régulière : {id} devient un groupe
 * nommé (?P<id>[^/]+), dont la valeur est passée à l'action.
 */
final class Router
{
    /** @var list<array{methode: string, regex: string, action: string}> */
    private array $routes = [];

    public function get(string $motif, string $action): void
    {
        $this->ajouter('GET', $motif, $action);
    }

    public function post(string $motif, string $action): void
    {
        $this->ajouter('POST', $motif, $action);
    }

    private function ajouter(string $methode, string $motif, string $action): void
    {
        // preg_quote protège les caractères spéciaux du motif ('.' par exemple),
        // puis on remplace chaque \{nom\} par un groupe capturant nommé
        $regex = preg_replace('/\\\\\{([a-z_]+)\\\\\}/', '(?P<$1>[^/]+)', preg_quote($motif, '#'));
        $this->routes[] = ['methode' => $methode, 'regex' => '#^' . $regex . '$#', 'action' => $action];
    }

    /**
     * Trouve la route ; renvoie l'action et les paramètres extraits de l'URL.
     *
     * @return array{action: string, parametres: array<string, string>}
     * @throws RouteIntrouvable    aucune route ne correspond à l'URL (404)
     * @throws MethodeNonAutorisee l'URL existe, mais pas pour cette méthode (405)
     */
    public function trouver(string $methode, string $chemin): array
    {
        // "/compte/" et "/compte" désignent la même page
        $chemin = $chemin === '/' ? '/' : rtrim($chemin, '/');
        $methodesPossibles = [];

        foreach ($this->routes as $route) {
            if (!preg_match($route['regex'], $chemin, $correspondances)) {
                continue;
            }
            if ($route['methode'] !== $methode) {
                $methodesPossibles[] = $route['methode'];
                continue;
            }
            // On ne garde que les groupes nommés (les clés texte)
            $parametres = array_filter($correspondances, 'is_string', ARRAY_FILTER_USE_KEY);
            return ['action' => $route['action'], 'parametres' => $parametres];
        }

        if ($methodesPossibles !== []) {
            throw new MethodeNonAutorisee(array_values(array_unique($methodesPossibles)));
        }
        throw new RouteIntrouvable($chemin);
    }
}
