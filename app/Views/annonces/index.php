<?php
/** @var App\Models\FiltresAnnonces $filtres */
/** @var list<array<string, mixed>> $annonces */
/** @var int $total */
/** @var list<string> $villes */
/** @var list<array<string, mixed>> $categories */

use App\Core\Auth;
use App\Core\View;
use App\Models\FiltresAnnonces;

$pages = max(1, (int) ceil($total / FiltresAnnonces::TAILLE_PAGE));
$page = min($filtres->page, $pages);
?>
<div class="entete-section">
    <h1>Annonces Occasion</h1>
    <a class="bouton" href="/annonces/nouvelle"><?= Auth::estConnecte() ? 'Publier une annonce' : 'Publier une annonce (connexion)' ?></a>
</div>
<p class="sous-texte-gauche">Des particuliers vendent leurs objets d'occasion. Pas de panier : contactez le vendeur par la messagerie.</p>

<?php /* Formulaire GET : les filtres sont dans l'URL (partageable). annonces.js
         l'envoie automatiquement à chaque changement. */ ?>
<form method="get" action="/annonces" class="carte filtres-annonces" id="filtres-annonces">
    <div class="champ"><label for="a-q">Mots-clés</label>
        <input id="a-q" name="q" type="search" maxlength="100" value="<?= e($filtres->texte) ?>"></div>
    <div class="champ"><label for="a-categorie">Catégorie</label>
        <select id="a-categorie" name="categorie">
            <option value="">Toutes</option>
            <?php foreach ($categories as $c): ?>
                <option value="<?= e($c['id']) ?>" <?= $filtres->categorie === $c['id'] ? 'selected' : '' ?>><?= str_repeat('— ', $c['niveau'] - 1) . e($c['nom']) ?></option>
            <?php endforeach; ?>
        </select></div>
    <div class="champ"><label for="a-ville">Ville</label>
        <select id="a-ville" name="ville">
            <option value="">Tout le Maroc</option>
            <?php foreach ($villes as $v): ?>
                <option value="<?= e($v) ?>" <?= mb_strtolower($filtres->ville) === mb_strtolower($v) ? 'selected' : '' ?>><?= e($v) ?></option>
            <?php endforeach; ?>
        </select></div>
    <div class="champ"><label for="a-min">Prix min.</label>
        <input id="a-min" name="prix_min" type="number" min="0" inputmode="numeric" value="<?= e($filtres->prixMin === null ? '' : (string) $filtres->prixMin) ?>"></div>
    <div class="champ"><label for="a-max">Prix max.</label>
        <input id="a-max" name="prix_max" type="number" min="0" inputmode="numeric" value="<?= e($filtres->prixMax === null ? '' : (string) $filtres->prixMax) ?>"></div>
    <div class="champ"><label for="a-tri">Trier</label>
        <select id="a-tri" name="tri">
            <?php foreach (FiltresAnnonces::TRIS as $valeur => $libelle): ?>
                <option value="<?= e($valeur) ?>" <?= $filtres->tri === $valeur ? 'selected' : '' ?>><?= e($libelle) ?></option>
            <?php endforeach; ?>
        </select></div>
    <div class="filtres__actions"><button type="submit" class="bouton">Rechercher</button> <a href="/annonces">Effacer</a></div>
</form>

<p class="nb-resultats" aria-live="polite"><?= $total === 0 ? 'Aucune annonce' : $total . ' annonce' . ($total > 1 ? 's' : '') ?></p>
<ul class="grille-produits">
    <?php foreach ($annonces as $a): ?>
        <?= View::fragment('partials/carte_annonce', ['a' => $a]) ?>
    <?php endforeach; ?>
</ul>

<?php if ($pages > 1): ?>
    <nav class="pagination" aria-label="Pages d'annonces">
        <ul class="pagination__liste">
            <?php foreach (pages_a_afficher($page, $pages) as $n): ?>
                <?php if ($n === null): ?><li aria-hidden="true">…</li>
                <?php else: ?><li><a href="<?= e($filtres->url(['page' => $n])) ?>"<?= $n === $page ? ' aria-current="page"' : '' ?>><?= $n ?></a></li><?php endif; ?>
            <?php endforeach; ?>
        </ul>
    </nav>
<?php endif; ?>

<script type="module" src="/assets/js/annonces.js"></script>
