<?php
/** @var string $actif */
$liens = ['/vendeur' => 'Tableau de bord', '/vendeur/produits' => 'Mes produits',
          '/vendeur/commandes' => 'Commandes reçues', '/vendeur/boutique' => 'Ma boutique'];
?>
<nav class="sous-menu" aria-label="Espace vendeur">
    <ul>
        <?php foreach ($liens as $url => $libelle): ?>
            <li><a href="<?= e($url) ?>"<?= $url === $actif ? ' aria-current="page"' : '' ?>><?= e($libelle) ?></a></li>
        <?php endforeach; ?>
    </ul>
</nav>
