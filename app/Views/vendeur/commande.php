<?php
/** @var array<string, mixed> $commande */

use App\Core\Csrf;
use App\Core\View;
use App\Models\Commande;
?>
<?= View::fragment('partials/menu_vendeur', ['actif' => '/vendeur/commandes']) ?>

<p><a href="/vendeur/commandes">← Commandes reçues</a></p>

<div class="commande">
    <section class="carte">
        <h1>Commande <?= e($commande['numero']) ?>
            <span class="statut statut--<?= e(strtolower($commande['statut'])) ?>"><?= e(Commande::STATUTS[$commande['statut']]) ?></span></h1>
        <p>Passée le <?= e(date_fr($commande['date'], true)) ?> ·
            <?= $commande['mode_paiement'] === 'CARTE' ? 'payée par carte' : 'paiement à la livraison' ?>
            (<?= e(strtolower($commande['statut_paiement'] ?? '')) ?>)</p>
        <table class="tableau-panier">
            <thead><tr><th scope="col">Article</th><th scope="col">Qté</th><th scope="col">Prix HT</th><th scope="col">Total HT</th></tr></thead>
            <tbody>
            <?php foreach ($commande['lignes'] as $l): ?>
                <tr><td><?= e($l['NOM_PRODUIT']) ?></td><td><?= e($l['QUANTITE']) ?></td>
                    <td><?= e(format_prix((float) $l['PRIX_UNITAIRE_HT'])) ?></td><td><?= e(format_prix((float) $l['TOTAL_LIGNE_HT'])) ?></td></tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <p class="prix-total">Total : <?= e(format_prix($commande['total_ttc'])) ?> TTC
            <small class="facultatif">(<?= e(format_prix($commande['total_ht'])) ?> HT)</small></p>
    </section>

    <aside class="carte">
        <h2>Livraison</h2>
        <p><?= e($commande['client']) ?><br><?= e($commande['adresse']) ?><br><?= e($commande['ville']) ?><br>
            Tél. <?= e($commande['telephone']) ?></p>
        <?php if ($commande['actions'] !== []): ?>
            <h2>Actions</h2>
            <?php foreach ($commande['actions'] as $cible => $libelle): ?>
                <form method="post" action="/vendeur/commandes/<?= e(rawurlencode($commande['numero'])) ?>/statut"
                      <?= $cible === 'ANNULEE' ? 'data-confirmer="Annuler cette commande ? Le stock sera rendu et le client remboursé."' : '' ?>>
                    <?= Csrf::champ() ?>
                    <input type="hidden" name="statut" value="<?= e($cible) ?>">
                    <button type="submit" class="bouton <?= $cible === 'ANNULEE' ? 'bouton--secondaire' : '' ?>"><?= e($libelle) ?></button>
                </form>
            <?php endforeach; ?>
        <?php endif; ?>
    </aside>
</div>
