<?php
/** @var list<array<string, mixed>> $signalements */
/** @var string $statut */

use App\Core\View;
use App\Models\Moderation;

$onglets = ['OUVERT' => 'Ouverts', 'APPROUVE' => 'Approuvés', 'REJETE' => 'Rejetés'];
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/signalements']) ?>
<h1>Signalements</h1>
<nav class="filtres-statut" aria-label="Statut des signalements">
    <?php foreach ($onglets as $code => $libelle): ?>
        <a href="/admin/signalements?statut=<?= e($code) ?>"<?= $code === $statut ? ' aria-current="page"' : '' ?>><?= e($libelle) ?></a>
    <?php endforeach; ?>
</nav>
<?php if ($signalements === []): ?>
    <p class="carte">Aucun signalement.</p>
<?php else: ?>
    <div class="defilement-horizontal">
        <table class="tableau-panier">
            <caption class="visuellement-cache">Signalements regroupés par contenu signalé</caption>
            <thead><tr><th scope="col">Contenu</th><th scope="col">Type</th><th scope="col">Motif principal</th>
                <th scope="col">Signalements</th><th scope="col">Depuis le</th></tr></thead>
            <tbody>
            <?php foreach ($signalements as $s): ?>
                <tr><td><a href="/admin/signalements/<?= e($s['id']) ?>"><?= e($s['cible'] ?? '(sans texte)') ?></a></td>
                    <td><?= e(ucfirst(strtolower($s['type']))) ?></td><td><?= e(Moderation::MOTIFS[$s['motif']] ?? $s['motif']) ?></td>
                    <td><?= e($s['nb']) ?></td><td><?= e(date_fr($s['date'])) ?></td></tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
<?php endif; ?>
