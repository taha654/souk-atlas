<?php
/** @var array<string, mixed> $signalement */

use App\Core\Csrf;
use App\Core\View;
use App\Models\Moderation;

$cible = $signalement['cible'];
$effet = ['ANNONCE' => 'l\'annonce sera retirée (statut REFUSÉE)', 'AVIS' => 'l\'avis sera masqué',
          'PRODUIT' => 'le produit sera retiré de la vente'][$cible['TYPE']];
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/signalements']) ?>
<p><a href="/admin/signalements">← Signalements</a></p>
<div class="commande">
    <section class="carte">
        <h1><?= e(ucfirst(strtolower($cible['TYPE']))) ?> signalé(e) : <?= e($cible['LIBELLE']) ?></h1>
        <p>Par <?= e($cible['AUTEUR']) ?> · statut actuel : <?= e($cible['STATUT']) ?>
            <?= $cible['SCORE_RISQUE'] !== null ? ' · risque ' . e($cible['SCORE_RISQUE']) . '/100' : '' ?>
            · <a href="<?= e($cible['URL']) ?>">voir sur le site</a></p>
        <blockquote class="citation"><?= nl2br(e($cible['TEXTE'] ?? '')) ?></blockquote>
        <h2>Signalements (<?= count($signalement['signalements']) ?>)</h2>
        <ul class="liste-avis">
            <?php foreach ($signalement['signalements'] as $s): ?>
                <li><strong><?= e(Moderation::MOTIFS[$s['MOTIF']] ?? $s['MOTIF']) ?></strong> par <?= e($s['AUTEUR']) ?>,
                    le <?= e(date_fr($s['DATE_SIGNALEMENT'])) ?> (<?= e(strtolower($s['STATUT'])) ?>)
                    <?php if ($s['COMMENTAIRE'] !== null): ?><br>« <?= e($s['COMMENTAIRE']) ?> »<?php endif; ?></li>
            <?php endforeach; ?>
        </ul>
    </section>
    <aside class="carte">
        <?php if ($signalement['statut'] === 'OUVERT'): ?>
            <h2>Décision</h2>
            <p>La décision s'applique à tous les signalements de ce contenu.</p>
            <form method="post" action="/admin/signalements/<?= e($signalement['id']) ?>/traiter"
                  data-confirmer="Approuver : <?= e($effet) ?>. Confirmer ?"><?= Csrf::champ() ?>
                <input type="hidden" name="decision" value="APPROUVER">
                <button type="submit" class="bouton">Approuver : retirer le contenu</button></form>
            <p class="facultatif">Effet : <?= e($effet) ?>.</p>
            <form method="post" action="/admin/signalements/<?= e($signalement['id']) ?>/traiter"><?= Csrf::champ() ?>
                <input type="hidden" name="decision" value="REJETER">
                <button type="submit" class="bouton bouton--secondaire">Rejeter : le contenu reste</button></form>
        <?php else: ?>
            <p>Signalement déjà traité (<?= e(strtolower($signalement['statut'])) ?>).</p>
        <?php endif; ?>
    </aside>
</div>
