<?php
/** @var list<array{id: int, nom: string}> $chemin */
/** @var string|null $dernier  libellé final non cliquable (nom du produit) */
$dernier ??= null;
?>
<nav class="fil-ariane" aria-label="Fil d'Ariane">
    <ol>
        <li><a href="/catalogue">Catalogue</a></li>
        <?php foreach ($chemin as $i => $etape): ?>
            <?php $estDernier = $dernier === null && $i === array_key_last($chemin); ?>
            <li><a href="/catalogue?categorie=<?= e($etape['id']) ?>"<?= $estDernier ? ' aria-current="page"' : '' ?>><?= e($etape['nom']) ?></a></li>
        <?php endforeach; ?>
        <?php if ($dernier !== null): ?>
            <li><span aria-current="page"><?= e($dernier) ?></span></li>
        <?php endif; ?>
    </ol>
</nav>
