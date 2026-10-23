<?php
/** @var list<array<string, mixed>> $annonces */

use App\Core\Csrf;
use App\Core\View;
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/moderation']) ?>
<h1>Annonces à vérifier (<?= count($annonces) ?>)</h1>
<p class="sous-texte-gauche">Annonces dont le score de risque (calculé par le moteur C++) dépasse le seuil. Les plus risquées d'abord.</p>
<?php if ($annonces === []): ?><p class="carte">Rien à vérifier.</p><?php endif; ?>
<?php foreach ($annonces as $a): ?>
    <article class="carte">
        <h2><?= e($a['titre']) ?> — <?= e(format_prix($a['prix'])) ?></h2>
        <p><?= $a['score'] !== null ? '<span class="statut statut--refusee">Risque ' . e($a['score']) . '/100</span>' : '' ?>
            Par <?= e($a['auteur']) ?> (compte de <?= e($a['compte_jours']) ?> jour(s)), <?= e($a['ville']) ?>, le <?= e(date_fr($a['date'], true)) ?></p>
        <blockquote class="citation"><?= nl2br(e($a['description'])) ?></blockquote>
        <div class="actions">
            <form method="post" action="/admin/annonces/<?= e($a['id']) ?>/moderer"><?= Csrf::champ() ?>
                <input type="hidden" name="decision" value="APPROUVER">
                <button type="submit" class="bouton">Approuver et mettre en ligne</button></form>
            <form method="post" action="/admin/annonces/<?= e($a['id']) ?>/moderer" class="form-en-ligne"><?= Csrf::champ() ?>
                <input type="hidden" name="decision" value="REFUSER">
                <label for="motif-<?= e($a['id']) ?>" class="visuellement-cache">Motif du refus</label>
                <input id="motif-<?= e($a['id']) ?>" name="motif" type="text" required maxlength="500" placeholder="Motif du refus">
                <button type="submit" class="bouton bouton--secondaire">Refuser</button></form>
        </div>
    </article>
<?php endforeach; ?>
