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

/**
 * Applique une opération sur le panier (partagée par la page HTML et l'API JSON).
 * $quantite est le texte reçu : vide = valeur par défaut (1 pour un ajout) ;
 * invalide ("9999", "abc", "-1") = erreur. Surtout pas de valeur par défaut en
 * silence : "9999" ne doit pas devenir "1".
 */
function appliquer_operation_panier(App\Services\Panier $panier, string $operation, ?int $idProduit, string $quantite): void
{
    if ($idProduit === null) {
        throw new App\Core\Erreurs\ErreurMetier(App\Core\Erreurs\ErreurMetier::INTROUVABLE, 'Produit inconnu.');
    }
    $nombre = $quantite === '' ? null : filter_var($quantite, FILTER_VALIDATE_INT,
        ['options' => ['min_range' => 0, 'max_range' => App\Services\Panier::QUANTITE_MAX]]);
    if ($nombre === false || ($operation === 'modifier' && $nombre === null)) {
        throw new App\Core\Erreurs\ErreurMetier(App\Core\Erreurs\ErreurMetier::QUANTITE_INVALIDE,
            'Quantité invalide (0 à ' . App\Services\Panier::QUANTITE_MAX . ').');
    }
    match ($operation) {
        'ajouter' => $panier->ajouter($idProduit, $nombre ?? 1),
        'modifier' => $panier->modifier($idProduit, $nombre),
        'retirer' => $panier->retirer($idProduit),
        default => throw new App\Core\Erreurs\ErreurMetier(App\Core\Erreurs\ErreurMetier::DONNEE_INVALIDE, 'Opération inconnue.'),
    };
}

/**
 * Total TTC d'une ligne, pour l'affichage : prix unitaire TTC (calculé en base)
 * x quantité. Le total de la commande, lui, vient toujours de la base (TVA
 * arrondie par boutique) : la somme des lignes peut différer d'un centime.
 */
function total_ligne_ttc(array $ligne): float
{
    return round($ligne['prix_unitaire_ttc'] * $ligne['quantite'], 2);
}
