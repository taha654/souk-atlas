<?php
/** @var array<string, mixed> $achat */

use App\Models\Commande;
?>
<section class="carte">
    <h1>Achat <?= e($achat['reference']) ?></h1>
    <p>Passé le <?= e(date_fr($achat['date'], true)) ?>. Paiement :
        <?= $achat['mode_paiement'] === 'CARTE'
            ? 'carte bancaire se terminant par ' . e($achat['carte_4_derniers'])
            : 'à la livraison' ?>.</p>
    <p>Livraison : <?= e($achat['adresse']) ?>, <?= e($achat['ville']) ?> — <?= e($achat['telephone']) ?></p>
    <p class="actions">
        <a class="bouton" href="/achat/<?= e(rawurlencode($achat['reference'])) ?>/facture">Voir la facture</a>
        <a href="/mes-commandes">Toutes mes commandes</a>
    </p>
</section>

<?php foreach ($achat['commandes'] as $c): ?>
    <section class="carte">
        <h2>Commande <a href="/commande/<?= e(rawurlencode($c['numero'])) ?>"><?= e($c['numero']) ?></a>
            <span class="statut statut--<?= e(strtolower($c['statut'])) ?>"><?= e(Commande::STATUTS[$c['statut']]) ?></span></h2>
        <p class="facultatif">Expédiée par <?= e($c['boutique']) ?> (<?= e($c['ville_boutique']) ?>)</p>
        <ul class="liste-simple">
            <?php foreach ($c['lignes'] as $l): ?>
                <li><?= e($l['quantite']) ?> × <?= e($l['nom']) ?></li>
            <?php endforeach; ?>
        </ul>
        <p><strong><?= e(format_prix($c['total_ttc'])) ?> TTC</strong></p>
    </section>
<?php endforeach; ?>

<p class="carte prix-total">Total de l'achat : <?= e(format_prix($achat['total_ttc'])) ?> TTC</p>
