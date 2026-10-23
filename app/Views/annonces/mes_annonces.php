<?php
/** @var list<array<string, mixed>> $annonces */

use App\Core\Csrf;
use App\Models\Annonce;
?>
<div class="entete-section">
    <h1>Mes annonces</h1>
    <a class="bouton" href="/annonces/nouvelle">Publier une annonce</a>
</div>
<?php if ($annonces === []): ?>
    <p class="carte">Vous n'avez pas encore publié d'annonce.</p>
<?php else: ?>
    <ul class="liste-achats">
        <?php foreach ($annonces as $a): ?>
            <li class="carte ligne-annonce">
                <img src="<?= e($a['photo'] ?? '/assets/img/aucune-photo.svg') ?>" alt="" width="96" height="72">
                <div>
                    <p><a href="/annonce/<?= e($a['id']) ?>"><strong><?= e($a['titre']) ?></strong></a> — <?= e(format_prix($a['prix'])) ?></p>
                    <p><span class="statut statut--<?= e(strtolower($a['statut'])) ?>"><?= e(Annonce::STATUTS[$a['statut']]) ?></span>
                        <?php if ($a['statut'] === 'EN_LIGNE'): ?> jusqu'au <?= e(date_fr($a['date_expiration'])) ?><?php endif; ?>
                        · <?= e($a['nb_messages']) ?> conversation(s)</p>
                    <div class="actions">
                        <?php if (in_array($a['statut'], ['EN_LIGNE', 'EN_MODERATION'], true)): ?>
                            <a href="/mes-annonces/<?= e($a['id']) ?>">Modifier / photos</a>
                        <?php endif; ?>
                        <?php if (in_array($a['statut'], ['EN_LIGNE', 'EXPIREE'], true)): ?>
                            <form method="post" action="/mes-annonces/<?= e($a['id']) ?>/renouveler"><?= Csrf::champ() ?>
                                <button type="submit" class="bouton-lien">Renouveler 30 jours</button></form>
                        <?php endif; ?>
                        <?php if ($a['statut'] === 'EN_LIGNE'): ?>
                            <form method="post" action="/mes-annonces/<?= e($a['id']) ?>/vendue" data-confirmer="Marquer cette annonce comme vendue ?"><?= Csrf::champ() ?>
                                <button type="submit" class="bouton-lien">Marquer comme vendue</button></form>
                        <?php endif; ?>
                    </div>
                </div>
            </li>
        <?php endforeach; ?>
    </ul>
<?php endif; ?>
