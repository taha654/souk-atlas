<?php
/** @var string $actif */
/** @var array<string, int>|null $compteurs */
$compteurs ??= null;
$liens = ['/admin' => 'Tableau de bord', '/admin/signalements' => 'Signalements', '/admin/moderation' => 'Annonces à vérifier',
          '/admin/boutiques' => 'Boutiques', '/admin/avis' => 'Avis', '/admin/utilisateurs' => 'Utilisateurs',
          '/admin/categories' => 'Catégories', '/admin/promotions' => 'Promotions', '/admin/journal' => 'Journal d\'audit'];
?>
<nav class="sous-menu" aria-label="Administration">
    <ul>
        <?php foreach ($liens as $url => $libelle): ?>
            <li><a href="<?= e($url) ?>"<?= $url === $actif ? ' aria-current="page"' : '' ?>><?= e($libelle) ?></a></li>
        <?php endforeach; ?>
    </ul>
</nav>
