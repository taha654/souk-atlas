<?php
/** @var array<string, mixed> $boutique */
/** @var array<string, mixed> $stats */
/** @var array<string, int> $compteurs */
/** @var list<array<string, mixed>> $alertesStock */

use App\Core\View;
use App\Models\Boutique;

$moisNoms = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
?>
<?= View::fragment('partials/menu_vendeur', ['actif' => '/vendeur']) ?>

<h1><?= e($boutique['nom']) ?></h1>
<p class="statut-boutique statut-boutique--<?= e(strtolower($boutique['statut'])) ?>">
    Boutique <?= e(Boutique::STATUTS[$boutique['statut']] ?? $boutique['statut']) ?>.</p>

<?php if ($compteurs['PAYEE'] + $compteurs['EN_ATTENTE'] > 0): ?>
    <p class="alerte alerte--info">
        <a href="/vendeur/commandes?statut=PAYEE"><?= e($compteurs['PAYEE']) ?> commande(s) payée(s)</a> et
        <a href="/vendeur/commandes?statut=EN_ATTENTE"><?= e($compteurs['EN_ATTENTE']) ?> à la livraison</a> attendent votre expédition.
    </p>
<?php endif; ?>
<?php if ($alertesStock !== []): ?>
    <p class="alerte alerte--erreur">Stock faible :
        <?php foreach ($alertesStock as $i => $p): ?>
            <?= $i > 0 ? ', ' : '' ?><a href="/vendeur/produits/<?= e($p['id']) ?>"><?= e($p['nom']) ?></a> (<?= e($p['stock']) ?>)
        <?php endforeach; ?>
    </p>
<?php endif; ?>

<section aria-labelledby="titre-stats">
    <div class="entete-section">
        <h2 id="titre-stats">Ventes des <span id="libelle-periode"><?= e($stats['jours']) ?> derniers jours</span></h2>
        <?php /* Change la période sans recharger (tableau-de-bord.js) ; sans JS, rien ne change : 30 jours */ ?>
        <label class="choix-periode">Période
            <select id="periode" hidden>
                <?php foreach ([7, 30, 90, 365] as $j): ?>
                    <option value="<?= $j ?>" <?= $j === $stats['jours'] ? 'selected' : '' ?>><?= $j ?> jours</option>
                <?php endforeach; ?>
            </select>
        </label>
    </div>

    <div class="grille-chiffres" id="tuiles">
        <div class="chiffre"><strong data-tuile="ca_ht"><?= e(format_prix($stats['resume']['ca_ht'])) ?></strong> chiffre d'affaires HT</div>
        <div class="chiffre"><strong data-tuile="nb_commandes"><?= e($stats['resume']['nb_commandes']) ?></strong> commandes</div>
        <div class="chiffre"><strong data-tuile="articles_vendus"><?= e($stats['resume']['articles_vendus']) ?></strong> articles vendus</div>
        <div class="chiffre"><strong data-tuile="panier_moyen"><?= e(format_prix($stats['resume']['panier_moyen'])) ?></strong> panier moyen TTC</div>
    </div>

    <div class="grille-graphiques">
        <figure class="carte graphique graphique--large">
            <figcaption>Chiffre d'affaires HT par jour</figcaption>
            <div id="graphique-jours" class="graphique__zone"></div>
            <details>
                <summary>Voir les données</summary>
                <table class="tableau-donnees" id="table-jours">
                    <thead><tr><th scope="col">Jour</th><th scope="col">Commandes</th><th scope="col">CA HT</th></tr></thead>
                    <tbody>
                    <?php foreach ($stats['par_jour'] as $j): ?>
                        <tr><td><?= e(date_fr($j['jour'] . ' 00:00:00')) ?></td><td><?= e($j['nb_commandes']) ?></td><td><?= e(format_prix($j['ca_ht'])) ?></td></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </details>
        </figure>

        <figure class="carte graphique">
            <figcaption>Chiffre d'affaires HT par mois (<?= date('Y') ?>)</figcaption>
            <div id="graphique-mois" class="graphique__zone"></div>
            <details>
                <summary>Voir les données</summary>
                <table class="tableau-donnees">
                    <thead><tr><th scope="col">Mois</th><th scope="col">CA HT</th><th scope="col">Évolution</th></tr></thead>
                    <tbody>
                    <?php foreach ($stats['par_mois'] as $m): ?>
                        <tr><td><?= e($moisNoms[$m['mois'] - 1]) ?></td><td><?= e(format_prix($m['ca_ht'])) ?></td>
                            <td><?= $m['evolution_pct'] === null ? '—' : e(($m['evolution_pct'] > 0 ? '+' : '') . number_format($m['evolution_pct'], 1, ',', '') . ' %') ?></td></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </details>
        </figure>

        <figure class="carte graphique">
            <figcaption>Meilleures ventes (quantités)</figcaption>
            <div id="graphique-produits" class="graphique__zone"></div>
            <details>
                <summary>Voir les données</summary>
                <table class="tableau-donnees">
                    <thead><tr><th scope="col">Rang</th><th scope="col">Produit</th><th scope="col">Quantité</th><th scope="col">CA HT</th></tr></thead>
                    <tbody>
                    <?php foreach ($stats['meilleures_ventes'] as $v): ?>
                        <tr><td><?= e($v['rang']) ?></td><td><?= e($v['nom']) ?></td><td><?= e($v['quantite']) ?></td><td><?= e(format_prix($v['ca_ht'])) ?></td></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </details>
        </figure>
    </div>
</section>

<script type="module" src="/assets/js/tableau-de-bord.js"></script>
