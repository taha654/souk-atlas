<?php
declare(strict_types=1);

namespace App\Models;

/** Filtres de la liste des annonces (?q=…&ville=…&categorie=…), validés comme ceux du catalogue */
final class FiltresAnnonces
{
    public const TRIS = ['recent' => 'Plus récentes', 'prix_asc' => 'Prix croissant', 'prix_desc' => 'Prix décroissant'];
    public const TAILLE_PAGE = 12;

    public function __construct(
        public readonly string $texte = '',
        public readonly ?int $categorie = null,
        public readonly string $ville = '',
        public readonly ?float $prixMin = null,
        public readonly ?float $prixMax = null,
        public readonly string $tri = 'recent',
        public readonly int $page = 1,
    ) {
    }

    /** @param array<string, mixed> $query */
    public static function depuisRequete(array $query): self
    {
        $texte = static fn (string $cle, int $max) => is_string($query[$cle] ?? null) ? mb_substr(trim($query[$cle]), 0, $max) : '';
        $entier = static function (string $cle) use ($query): ?int {
            $v = filter_var($query[$cle] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
            return $v === false ? null : $v;
        };
        $prix = static function (string $cle) use ($query): ?float {
            $brut = $query[$cle] ?? null;
            if (!is_string($brut) || $brut === '') {
                return null;
            }
            $v = filter_var(str_replace([' ', ','], ['', '.'], $brut), FILTER_VALIDATE_FLOAT);
            return $v === false || $v < 0 ? null : $v;
        };
        [$min, $max] = [$prix('prix_min'), $prix('prix_max')];
        if ($min !== null && $max !== null && $min > $max) {
            [$min, $max] = [$max, $min];
        }
        $tri = is_string($query['tri'] ?? null) && isset(self::TRIS[$query['tri']]) ? $query['tri'] : 'recent';
        return new self($texte('q', 100), $entier('categorie'), $texte('ville', 60), $min, $max, $tri,
            min($entier('page') ?? 1, 1000));
    }

    /** @param array<string, mixed> $changements */
    public function url(array $changements = []): string
    {
        $valeurs = array_merge(['q' => $this->texte, 'categorie' => $this->categorie, 'ville' => $this->ville,
            'prix_min' => $this->prixMin, 'prix_max' => $this->prixMax, 'tri' => $this->tri, 'page' => $this->page], $changements);
        if ($valeurs['tri'] === 'recent') {
            $valeurs['tri'] = null;
        }
        if ($valeurs['page'] === 1) {
            $valeurs['page'] = null;
        }
        $query = http_build_query(array_filter($valeurs, static fn ($v) => $v !== null && $v !== ''));
        return '/annonces' . ($query === '' ? '' : '?' . $query);
    }
}
