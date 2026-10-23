<?php
declare(strict_types=1);

/**
 * Échappe un texte pour l'insérer dans du HTML. TOUTE donnée affichée passe
 * par ici : un nom comme <script>…</script> s'affiche tel quel au lieu de
 * s'exécuter (protection contre le XSS).
 * ENT_QUOTES échappe aussi ' et ", indispensable dans un attribut value="…".
 */
function e(string|int|float|null $texte): string
{
    return htmlspecialchars((string) $texte, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** Date Oracle ("2026-10-23 14:05:00") affichée à la française : 23/10/2026 */
function date_fr(?string $dateIso, bool $avecHeure = false): string
{
    if ($dateIso === null || $dateIso === '') {
        return '—';
    }
    $date = DateTimeImmutable::createFromFormat('Y-m-d H:i:s', $dateIso);
    return $date === false ? $dateIso : $date->format($avecHeure ? 'd/m/Y à H:i' : 'd/m/Y');
}

/**
 * Prix en dirhams à la française : 3948 → "3 948,00 MAD".
 * L'espace des milliers est insécable (U+00A0) : "3 948" ne sera jamais coupé
 * en fin de ligne.
 */
function format_prix(float $montant): string
{
    return number_format($montant, 2, ',', "\u{00A0}") . "\u{00A0}MAD";
}

/** "★ 4,5 sur 5 (12 avis)" ou "Pas encore d'avis" */
function texte_note(?float $note, int $nbAvis): string
{
    if ($note === null || $nbAvis === 0) {
        return 'Pas encore d\'avis';
    }
    return '★ ' . number_format($note, 1, ',', '') . ' sur 5 (' . $nbAvis . ' avis)';
}

function texte_stock(int $stock): string
{
    return match (true) {
        $stock === 0 => 'Épuisé',
        $stock <= 5 => 'Plus que ' . $stock . ' en stock',
        default => 'En stock',
    };
}

/**
 * Numéros de pages à afficher : 1 … 4 5 [6] 7 8 … 20 (null = "…").
 * Même algorithme que pagesAAfficher() dans public/assets/js/catalogue.js.
 *
 * @return list<int|null>
 */
function pages_a_afficher(int $page, int $pages): array
{
    $liste = [];
    $precedent = 0;
    for ($n = 1; $n <= $pages; $n++) {
        if ($n === 1 || $n === $pages || abs($n - $page) <= 2) {
            if ($n - $precedent > 1) {
                $liste[] = null;
            }
            $liste[] = $n;
            $precedent = $n;
        }
    }
    return $liste;
}
