<?php
/**
 * Pagination accessible : <nav> nommé, page courante marquée aria-current.
 * Même algorithme que pagesAAfficher() dans catalogue.js.
 *
 * @var App\Models\FiltresCatalogue $filtres
 * @var int $pages
 */
if ($pages <= 1) {
    return;
}
$page = min($filtres->page, $pages);
?>
<ul class="pagination__liste">
    <?php if ($page > 1): ?>
        <li><a href="<?= e($filtres->url(['page' => $page - 1])) ?>" data-page="<?= $page - 1 ?>" rel="prev">Précédent</a></li>
    <?php endif; ?>
    <?php foreach (pages_a_afficher($page, $pages) as $numero): ?>
        <?php if ($numero === null): ?>
            <li aria-hidden="true">…</li>
        <?php elseif ($numero === $page): ?>
            <li><a href="<?= e($filtres->url(['page' => $numero])) ?>" aria-current="page"><?= $numero ?></a></li>
        <?php else: ?>
            <li><a href="<?= e($filtres->url(['page' => $numero])) ?>" data-page="<?= $numero ?>"><?= $numero ?></a></li>
        <?php endif; ?>
    <?php endforeach; ?>
    <?php if ($page < $pages): ?>
        <li><a href="<?= e($filtres->url(['page' => $page + 1])) ?>" data-page="<?= $page + 1 ?>" rel="next">Suivant</a></li>
    <?php endif; ?>
</ul>
