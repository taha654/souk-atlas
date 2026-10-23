<?php
/** @var array<string, int> $aTraiter */
/** @var array<string, mixed> $stats */

use App\Core\View;
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin']) ?>
<h1>Administration</h1>

<section aria-labelledby="titre-a-traiter">
    <h2 id="titre-a-traiter">À traiter</h2>
    <div class="grille-chiffres">
        <a class="chiffre chiffre--lien" href="/admin/signalements"><strong><?= e($aTraiter['signalements']) ?></strong> signalement(s) ouvert(s)</a>
        <a class="chiffre chiffre--lien" href="/admin/moderation"><strong><?= e($aTraiter['annonces']) ?></strong> annonce(s) à vérifier</a>
        <a class="chiffre chiffre--lien" href="/admin/boutiques?statut=EN_ATTENTE"><strong><?= e($aTraiter['boutiques']) ?></strong> boutique(s) à valider</a>
    </div>
</section>

<section aria-labelledby="titre-activite">
    <div class="entete-section">
        <h2 id="titre-activite">Activité du site — <span id="libelle-periode"><?= e($stats['jours']) ?> derniers jours</span></h2>
        <label class="choix-periode">Période
            <select id="periode" hidden>
                <?php foreach ([7, 30, 90, 365] as $j): ?>
                    <option value="<?= $j ?>" <?= $j === $stats['jours'] ? 'selected' : '' ?>><?= $j ?> jours</option>
                <?php endforeach; ?>
            </select></label>
    </div>
    <div class="grille-chiffres">
        <div class="chiffre"><strong><?= e($aTraiter['utilisateurs']) ?></strong> utilisateurs</div>
        <div class="chiffre"><strong><?= e($aTraiter['produits']) ?></strong> produits actifs</div>
        <div class="chiffre"><strong><?= e($aTraiter['annonces_en_ligne']) ?></strong> annonces en ligne</div>
        <div class="chiffre"><strong id="panier-moyen"><?= e(format_prix($stats['panier_moyen'])) ?></strong> panier moyen TTC</div>
    </div>
    <div class="grille-graphiques">
        <figure class="carte graphique graphique--large">
            <figcaption>Chiffre d'affaires HT de la place de marché, par jour</figcaption>
            <div id="graphique-jours" class="graphique__zone"></div>
        </figure>
        <figure class="carte graphique graphique--large">
            <figcaption>Classement des boutiques (CA HT, rang et part avec RANK et RATIO_TO_REPORT)</figcaption>
            <div id="graphique-vendeurs" class="graphique__zone"></div>
            <details><summary>Voir les données</summary>
                <table class="tableau-donnees">
                    <thead><tr><th scope="col">Rang</th><th scope="col">Boutique</th><th scope="col">Commandes</th>
                        <th scope="col">CA HT</th><th scope="col">Part</th></tr></thead>
                    <tbody>
                    <?php foreach ($stats['par_vendeur'] as $v): ?>
                        <tr><td><?= e($v['rang']) ?></td><td><?= e($v['boutique']) ?></td><td><?= e($v['nb_commandes']) ?></td>
                            <td><?= e(format_prix($v['ca_ht'])) ?></td><td><?= e(number_format($v['part_pct'], 1, ',', '')) ?> %</td></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table></details>
        </figure>
    </div>
</section>
<script type="module" src="/assets/js/tableau-admin.js"></script>
