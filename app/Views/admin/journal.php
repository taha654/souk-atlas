<?php
/** @var list<array<string, mixed>> $entrees */
/** @var string|null $table */

use App\Core\View;
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/journal']) ?>
<h1>Journal d'audit</h1>
<p class="sous-texte-gauche">Écrit automatiquement par les triggers TRG_AUDIT_* ; l'auteur vient du « client identifier » posé par PHP.</p>
<nav class="filtres-statut" aria-label="Table">
    <?php foreach ([null => 'Tout', 'UTILISATEUR' => 'Utilisateurs', 'PRODUIT' => 'Produits', 'COMMANDE' => 'Commandes'] as $code => $libelle): ?>
        <a href="/admin/journal<?= $code ? '?table=' . e($code) : '' ?>"<?= $code === $table ? ' aria-current="page"' : '' ?>><?= e($libelle) ?></a>
    <?php endforeach; ?>
</nav>
<?php if ($entrees === []): ?><p class="carte">Aucune entrée (le journal a été vidé après le chargement des données de démonstration).</p><?php endif; ?>
<div class="defilement-horizontal">
    <table class="tableau-donnees">
        <thead><tr><th scope="col">Date</th><th scope="col">Table</th><th scope="col">Ligne</th><th scope="col">Opération</th>
            <th scope="col">Auteur</th><th scope="col">Avant</th><th scope="col">Après</th></tr></thead>
        <tbody>
        <?php foreach ($entrees as $j): ?>
            <tr><td><?= e(date_fr($j['date'], true)) ?></td><td><?= e($j['table']) ?></td><td><?= e($j['id_ligne']) ?></td>
                <td><?= e($j['operation']) ?></td><td><?= e($j['auteur']) ?></td>
                <td><?= e($j['avant'] ?? '') ?></td><td><?= e($j['apres'] ?? '') ?></td></tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>
