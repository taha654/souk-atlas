<?php
/** @var list<array<string, mixed>> $conversations */
?>
<h1>Mes messages</h1>
<?php if ($conversations === []): ?>
    <p class="carte">Aucune conversation. Contactez un vendeur depuis une <a href="/annonces">annonce</a>.</p>
<?php else: ?>
    <ul class="liste-conversations">
        <?php foreach ($conversations as $c): ?>
            <li class="carte<?= $c['non_lus'] > 0 ? ' conversation--non-lue' : '' ?>">
                <a href="/messages/<?= e($c['id']) ?>">
                    <strong><?= e($c['titre']) ?></strong>
                    <?php if ($c['non_lus'] > 0): ?><span class="badge-panier"><?= e($c['non_lus']) ?><span class="visuellement-cache"> non lu(s)</span></span><?php endif; ?>
                </a>
                <p class="facultatif"><?= $c['je_vends'] ? 'Acheteur' : 'Vendeur' ?> : <?= e($c['interlocuteur']) ?> · <?= e(date_fr($c['date'], true)) ?></p>
                <p><?= e($c['apercu'] ?? '') ?></p>
            </li>
        <?php endforeach; ?>
    </ul>
<?php endif; ?>
