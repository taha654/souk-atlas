<?php
/** @var array<string, mixed> $boutique */
/** @var list<array<string, mixed>> $produits */

use App\Core\View;
?>
<?= View::fragment('partials/menu_vendeur', ['actif' => '/vendeur/produits']) ?>

<div class="entete-section">
    <h1>Mes produits (<?= count($produits) ?>)</h1>
    <a class="bouton" href="/vendeur/produits/nouveau">Nouveau produit</a>
</div>

<?php if ($produits === []): ?>
    <p class="carte">Aucun produit pour l'instant. <a href="/vendeur/produits/nouveau">Créer le premier</a></p>
<?php else: ?>
    <div class="defilement-horizontal">
        <table class="tableau-panier">
            <caption class="visuellement-cache">Produits de la boutique</caption>
            <thead><tr><th scope="col">Produit</th><th scope="col">Prix HT</th><th scope="col">Prix TTC affiché</th>
                <th scope="col">Stock</th><th scope="col">Vendus</th><th scope="col">Statut</th></tr></thead>
            <tbody>
            <?php foreach ($produits as $p): ?>
                <tr>
                    <td class="cellule-produit">
                        <img src="<?= e($p['photo'] ?? '/assets/img/aucune-photo.svg') ?>" alt="" width="60" height="45">
                        <a href="/vendeur/produits/<?= e($p['id']) ?>"><?= e($p['nom']) ?></a>
                    </td>
                    <td><?= e(format_prix($p['prix_ht'])) ?></td>
                    <td><?= e(format_prix($p['prix_ttc'])) ?></td>
                    <td class="<?= $p['stock'] <= 5 ? 'stock--epuise' : '' ?>"><?= e($p['stock']) ?></td>
                    <td><?= e($p['vendus']) ?></td>
                    <td><?= $p['statut'] === 'ACTIF' ? 'En vente' : 'Retiré' ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
<?php endif; ?>
