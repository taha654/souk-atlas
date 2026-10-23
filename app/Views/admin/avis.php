<?php
/** @var list<array<string, mixed>> $avis */

use App\Core\Csrf;
use App\Core\View;
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/avis']) ?>
<h1>Avis récents</h1>
<ul class="liste-avis carte">
    <?php foreach ($avis as $a): ?>
        <li class="<?= $a['statut'] === 'MASQUE' ? 'avis--masque' : '' ?>">
            <p><span class="etoiles" aria-hidden="true"><?= str_repeat('★', $a['note']) . str_repeat('☆', 5 - $a['note']) ?></span>
                <span class="visuellement-cache"><?= e($a['note']) ?> sur 5</span>
                <a href="/produit/<?= e($a['id_produit']) ?>"><?= e($a['produit']) ?></a> — <?= e($a['auteur']) ?>, <?= e(date_fr($a['date'])) ?>
                <?= $a['statut'] === 'MASQUE' ? '<span class="statut statut--refusee">Masqué</span>' : '' ?></p>
            <p><?= e($a['commentaire']) ?></p>
            <form method="post" action="/admin/avis/<?= e($a['id']) ?>/statut"><?= Csrf::champ() ?>
                <input type="hidden" name="statut" value="<?= $a['statut'] === 'MASQUE' ? 'PUBLIE' : 'MASQUE' ?>">
                <button type="submit" class="bouton-lien"><?= $a['statut'] === 'MASQUE' ? 'Republier' : 'Masquer' ?></button></form>
        </li>
    <?php endforeach; ?>
</ul>
