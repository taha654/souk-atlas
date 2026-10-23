<?php
/** @var list<array<string, mixed>> $achats */

use App\Models\Commande;
?>
<h1>Mes commandes</h1>

<?php if ($achats === []): ?>
    <p class="carte">Vous n'avez encore rien commandé. <a href="/catalogue">Parcourir le catalogue</a></p>
<?php else: ?>
    <ul class="liste-achats">
        <?php foreach ($achats as $a): ?>
            <li class="carte">
                <p><a href="/achat/<?= e(rawurlencode($a['reference'])) ?>"><strong><?= e($a['reference']) ?></strong></a>
                    — <?= e(date_fr($a['date'])) ?> — <?= e(format_prix($a['total_ttc'])) ?> TTC</p>
                <ul class="liste-simple">
                    <?php foreach ($a['commandes'] as $c): ?>
                        <li><a href="/commande/<?= e(rawurlencode($c['numero'])) ?>"><?= e($c['numero']) ?></a>
                            <span class="statut statut--<?= e(strtolower($c['statut'])) ?>"><?= e(Commande::STATUTS[$c['statut']] ?? $c['statut']) ?></span></li>
                    <?php endforeach; ?>
                </ul>
            </li>
        <?php endforeach; ?>
    </ul>
<?php endif; ?>
