<?php
/** @var list<array<string, mixed>> $boutiques */
/** @var string|null $statut */

use App\Core\Csrf;
use App\Core\View;

$onglets = [null => 'Toutes', 'EN_ATTENTE' => 'À valider', 'VALIDEE' => 'Validées', 'SUSPENDUE' => 'Suspendues', 'REFUSEE' => 'Refusées'];
$actions = ['EN_ATTENTE' => ['VALIDEE' => 'Valider', 'REFUSEE' => 'Refuser'], 'VALIDEE' => ['SUSPENDUE' => 'Suspendre'],
            'SUSPENDUE' => ['VALIDEE' => 'Réactiver'], 'REFUSEE' => ['VALIDEE' => 'Valider finalement']];
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/boutiques']) ?>
<h1>Boutiques des vendeurs</h1>
<nav class="filtres-statut" aria-label="Statut des boutiques">
    <?php foreach ($onglets as $code => $libelle): ?>
        <a href="/admin/boutiques<?= $code ? '?statut=' . e($code) : '' ?>"<?= $code === $statut ? ' aria-current="page"' : '' ?>><?= e($libelle) ?></a>
    <?php endforeach; ?>
</nav>
<?php foreach ($boutiques as $b): ?>
    <article class="carte">
        <h2><?= e($b['nom']) ?> <span class="statut statut--<?= e(strtolower($b['statut'] === 'EN_ATTENTE' ? 'en_moderation' : ($b['statut'] === 'VALIDEE' ? 'en_ligne' : 'refusee'))) ?>"><?= e($b['statut']) ?></span></h2>
        <p><?= e($b['vendeur']) ?> (<?= e($b['email']) ?>) · <?= e($b['ville']) ?> · <?= e($b['nb_produits']) ?> produit(s) · créée le <?= e(date_fr($b['date'])) ?></p>
        <?php if ($b['description'] !== ''): ?><p class="facultatif"><?= e($b['description']) ?></p><?php endif; ?>
        <div class="actions">
            <?php foreach ($actions[$b['statut']] ?? [] as $cible => $libelle): ?>
                <form method="post" action="/admin/boutiques/<?= e($b['id']) ?>/statut"><?= Csrf::champ() ?>
                    <input type="hidden" name="statut" value="<?= e($cible) ?>">
                    <button type="submit" class="bouton <?= in_array($cible, ['REFUSEE', 'SUSPENDUE'], true) ? 'bouton--secondaire' : '' ?>"><?= e($libelle) ?></button></form>
            <?php endforeach; ?>
        </div>
    </article>
<?php endforeach; ?>
