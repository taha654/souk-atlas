<?php
/** @var list<array<string, mixed>> $promotions */
/** @var list<array<string, mixed>> $categories */

use App\Core\Csrf;
use App\Core\View;

$etats = ['EN_COURS' => ['En cours', 'en_ligne'], 'A_VENIR' => ['À venir', 'en_moderation'], 'TERMINEE' => ['Terminée', 'expiree']];
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/promotions']) ?>
<h1>Promotions</h1>

<form method="post" action="/admin/promotions" class="carte filtres-annonces"><?= Csrf::champ() ?>
    <div class="champ"><label for="libelle">Libellé</label><input id="libelle" name="libelle" type="text" required maxlength="100"></div>
    <div class="champ"><label for="pourcentage">Remise (%)</label><input id="pourcentage" name="pourcentage" type="number" min="1" max="90" required></div>
    <div class="champ"><label for="cible">Cible</label>
        <select id="cible" name="cible" required>
            <?php foreach ($categories as $c): ?><option value="categorie:<?= e($c['id']) ?>"><?= str_repeat('— ', $c['niveau'] - 1) . e($c['nom']) ?></option><?php endforeach; ?>
        </select></div>
    <div class="champ"><label for="debut">Du</label><input id="debut" name="debut" type="date" required value="<?= date('Y-m-d') ?>"></div>
    <div class="champ"><label for="fin">Au</label><input id="fin" name="fin" type="date" required value="<?= date('Y-m-d', strtotime('+7 days')) ?>"></div>
    <div class="filtres__actions"><button type="submit" class="bouton">Créer la promotion</button></div>
</form>

<div class="defilement-horizontal">
    <table class="tableau-panier">
        <caption class="visuellement-cache">Promotions</caption>
        <thead><tr><th scope="col">Libellé</th><th scope="col">Remise</th><th scope="col">Cible</th><th scope="col">Période</th><th scope="col">État</th><th scope="col"></th></tr></thead>
        <tbody>
        <?php foreach ($promotions as $p): ?>
            <tr><td><?= e($p['libelle']) ?></td><td>-<?= e((int) $p['pourcentage']) ?> %</td><td><?= e($p['cible']) ?></td>
                <td><?= e(date_fr($p['debut'])) ?> → <?= e(date_fr($p['fin'])) ?></td>
                <td><span class="statut statut--<?= e($etats[$p['etat']][1]) ?>"><?= e($etats[$p['etat']][0]) ?></span></td>
                <td><?php if ($p['actif'] && $p['etat'] !== 'TERMINEE'): ?>
                    <form method="post" action="/admin/promotions/<?= e($p['id']) ?>/desactiver" data-confirmer="Arrêter cette promotion ?"><?= Csrf::champ() ?>
                        <button type="submit" class="bouton-lien">Arrêter</button></form><?php endif; ?></td></tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>
