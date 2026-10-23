<?php
/** @var list<array<string, mixed>> $annonces */

use App\Core\View;
use App\Models\Annonce;
?>
<h1>Mes favoris</h1>
<?php if ($annonces === []): ?>
    <p class="carte">Aucun favori. Ajoutez des annonces avec ☆ depuis leur page.</p>
<?php else: ?>
    <ul class="grille-produits">
        <?php foreach ($annonces as $a): ?>
            <?php if ($a['statut'] === 'EN_LIGNE'): ?>
                <?= View::fragment('partials/carte_annonce', ['a' => $a]) ?>
            <?php else: ?>
                <li class="carte-produit carte-produit--inactive"><span class="carte-produit__lien">
                    <span class="carte-produit__nom"><?= e($a['titre']) ?></span>
                    <span class="statut statut--<?= e(strtolower($a['statut'])) ?>"><?= e(Annonce::STATUTS[$a['statut']]) ?></span></span></li>
            <?php endif; ?>
        <?php endforeach; ?>
    </ul>
<?php endif; ?>
