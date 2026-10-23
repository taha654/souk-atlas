<?php
/** @var array<string, mixed>|null $boutique */

$statuts = [
    'EN_ATTENTE' => 'en attente de validation par l\'administrateur',
    'VALIDEE' => 'validée : vos produits sont en vente',
    'REFUSEE' => 'refusée',
    'SUSPENDUE' => 'suspendue',
];
?>
<section class="carte">
    <h1>Espace vendeur</h1>
    <?php if ($boutique === null): ?>
        <p>Vous n'avez pas encore de boutique. La création de boutique arrive à l'étape 5.</p>
    <?php else: ?>
        <p>Boutique <strong><?= e($boutique['NOM']) ?></strong> (<?= e($boutique['VILLE']) ?>) :
            <?= e($statuts[$boutique['STATUT']] ?? $boutique['STATUT']) ?>.</p>
        <p><?= e($boutique['NB_PRODUITS']) ?> produit(s) au catalogue.</p>
    <?php endif; ?>
</section>
