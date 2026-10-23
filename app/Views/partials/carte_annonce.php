<?php
/** @var array<string, mixed> $a annonce (id, titre, prix, ville, photo, date ?) */
?>
<li class="carte-produit">
    <a class="carte-produit__lien" href="/annonce/<?= e($a['id']) ?>">
        <span class="carte-produit__image">
            <img src="<?= e($a['photo'] ?? '/assets/img/aucune-photo.svg') ?>" alt="" width="600" height="450" loading="lazy">
        </span>
        <span class="carte-produit__nom"><?= e($a['titre']) ?></span>
        <span class="carte-produit__prix"><strong><?= $a['prix'] > 0 ? e(format_prix($a['prix'])) : 'Don (gratuit)' ?></strong></span>
        <span class="carte-produit__boutique"><?= e($a['ville']) ?><?= isset($a['date']) ? ' · ' . e(date_fr($a['date'])) : '' ?></span>
    </a>
</li>
