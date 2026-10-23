<?php
declare(strict_types=1);

namespace App\Models;

/**
 * Filtres du catalogue, lus dans l'URL (?q=…&categorie=…&tri=…).
 *
 * L'URL vient du navigateur : tout est validé ici, et une valeur invalide est
 * remplacée par la valeur par défaut (pas d'erreur pour un ?page=abc).
 * La même classe sert à la page HTML et à l'API JSON : mêmes règles partout.
 */
final class FiltresCatalogue
{
    public const TRIS = [
        'pertinence' => 'Pertinence',
        'prix_asc' => 'Prix croissant',
        'prix_desc' => 'Prix décroissant',
        'recent' => 'Nouveautés',
        'note' => 'Mieux notés',
    ];
    public const TAILLE_PAGE = 12;
    private const PAGE_MAX = 1000;
    private const TEXTE_MAX = 100;

    public function __construct(
        public readonly string $texte = '',
        public readonly ?int $categorie = null,
        public readonly ?float $prixMin = null,
        public readonly ?float $prixMax = null,
        public readonly string $tri = 'pertinence',
        public readonly int $page = 1,
        public readonly bool $enStock = false,
    ) {
    }

    /** @param array<string, mixed> $query paramètres de l'URL ($_GET) */
    public static function depuisRequete(array $query): self
    {
        $texte = is_string($query['q'] ?? null) ? trim($query['q']) : '';
        $prixMin = self::nombrePositif($query['prix_min'] ?? null);
        $prixMax = self::nombrePositif($query['prix_max'] ?? null);
        // Bornes inversées par l'utilisateur : on les remet dans l'ordre
        if ($prixMin !== null && $prixMax !== null && $prixMin > $prixMax) {
            [$prixMin, $prixMax] = [$prixMax, $prixMin];
        }
        $tri = is_string($query['tri'] ?? null) && isset(self::TRIS[$query['tri']]) ? $query['tri'] : 'pertinence';
        $page = self::entierPositif($query['page'] ?? null) ?? 1;

        return new self(
            mb_substr($texte, 0, self::TEXTE_MAX),
            self::entierPositif($query['categorie'] ?? null),
            $prixMin,
            $prixMax,
            $tri,
            min($page, self::PAGE_MAX),
            ($query['en_stock'] ?? '') === '1',
        );
    }

    /**
     * Paramètres d'URL, sans les valeurs par défaut (URL courtes et lisibles).
     *
     * @param array<string, mixed> $changements  ex. ['page' => 2]
     * @return array<string, string|int|float>
     */
    public function versQuery(array $changements = []): array
    {
        $valeurs = array_merge([
            'q' => $this->texte,
            'categorie' => $this->categorie,
            'prix_min' => $this->prixMin,
            'prix_max' => $this->prixMax,
            'tri' => $this->tri,
            'en_stock' => $this->enStock ? 1 : null,
            'page' => $this->page,
        ], $changements);
        // Valeurs par défaut retirées APRÈS les changements : url(['page' => 1])
        // donne bien "/catalogue", pas "/catalogue?page=1" (une seule URL par page)
        if ($valeurs['tri'] === 'pertinence') {
            $valeurs['tri'] = null;
        }
        if ($valeurs['page'] === 1) {
            $valeurs['page'] = null;
        }
        return array_filter($valeurs, static fn ($v) => $v !== null && $v !== '');
    }

    public function url(array $changements = []): string
    {
        $query = http_build_query($this->versQuery($changements));
        return '/catalogue' . ($query === '' ? '' : '?' . $query);
    }

    private static function entierPositif(mixed $valeur): ?int
    {
        // FILTER_VALIDATE_INT refuse "12abc", "1.5" et les valeurs négatives (min_range)
        $entier = filter_var($valeur, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        return $entier === false ? null : $entier;
    }

    private static function nombrePositif(mixed $valeur): ?float
    {
        if (!is_string($valeur) && !is_numeric($valeur)) {
            return null;
        }
        // Les francophones écrivent "12,5" : on accepte la virgule
        $nombre = filter_var(str_replace(',', '.', (string) $valeur), FILTER_VALIDATE_FLOAT);
        return $nombre === false || $nombre < 0 || $nombre > 100_000_000 ? null : $nombre;
    }
}
