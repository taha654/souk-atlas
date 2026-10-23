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
