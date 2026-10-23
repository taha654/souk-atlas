<?php
/** @var list<array<string, mixed>> $commandes */
/** @var array<string, int> $compteurs */
/** @var string|null $statut */

use App\Core\View;
use App\Models\Commande;
?>
<?= View::fragment('partials/menu_vendeur', ['actif' => '/vendeur/commandes']) ?>

<h1>Commandes reçues</h1>

<nav class="filtres-statut" aria-label="Filtrer par statut">
    <a href="/vendeur/commandes"<?= $statut === null ? ' aria-current="page"' : '' ?>>Toutes (<?= array_sum($compteurs) ?>)</a>
    <?php foreach (Commande::STATUTS as $code => $libelle): ?>
        <a href="/vendeur/commandes?statut=<?= e($code) ?>"<?= $statut === $code ? ' aria-current="page"' : '' ?>>
            <?= e($libelle) ?> (<?= e($compteurs[$code]) ?>)</a>
    <?php endforeach; ?>
</nav>

<?php if ($commandes === []): ?>
    <p class="carte">Aucune commande.</p>
<?php else: ?>
    <div class="defilement-horizontal">
        <table class="tableau-panier">
            <caption class="visuellement-cache">Commandes reçues (100 plus récentes)</caption>
            <thead><tr><th scope="col">Numéro</th><th scope="col">Date</th><th scope="col">Client</th><th scope="col">Ville</th>
                <th scope="col">Articles</th><th scope="col">Total TTC</th><th scope="col">Paiement</th><th scope="col">Statut</th></tr></thead>
            <tbody>
            <?php foreach ($commandes as $c): ?>
                <tr>
                    <td><a href="/vendeur/commandes/<?= e(rawurlencode($c['numero'])) ?>"><?= e($c['numero']) ?></a></td>
                    <td><?= e(date_fr($c['date'])) ?></td>
                    <td><?= e($c['client']) ?></td>
                    <td><?= e($c['ville']) ?></td>
                    <td><?= e($c['articles']) ?></td>
                    <td><?= e(format_prix($c['total_ttc'])) ?></td>
                    <td><?= $c['mode_paiement'] === 'CARTE' ? 'Carte' : 'À la livraison' ?></td>
                    <td><span class="statut statut--<?= e(strtolower($c['statut'])) ?>"><?= e(Commande::STATUTS[$c['statut']]) ?></span></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
<?php endif; ?>
