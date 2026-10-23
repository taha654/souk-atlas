<?php
/** @var array{lignes: list<array<string, mixed>>, total_ht: float, tva: float, total_ttc: float, nb_articles: int} $panier */

use App\Core\Auth;
use App\Core\Csrf;
use App\Services\Panier;

$indisponible = in_array(false, array_column($panier['lignes'], 'disponible'), true);
?>
<h1>Mon panier</h1>

<?php /* Message mis à jour par panier.js (aria-live : annoncé par les lecteurs d'écran) */ ?>
<p id="message-panier" class="visuellement-cache" aria-live="polite"></p>

<p id="panier-vide" class="carte" <?= $panier['lignes'] === [] ? '' : 'hidden' ?>>
    Votre panier est vide. <a href="/catalogue">Parcourir le catalogue</a>
</p>

<?php if ($panier['lignes'] !== []): ?>
<div class="panier" id="panier">
    <table class="tableau-panier">
        <caption class="visuellement-cache">Articles du panier</caption>
        <thead>
            <tr><th scope="col">Produit</th><th scope="col">Prix unitaire TTC</th>
                <th scope="col">Quantité</th><th scope="col">Total TTC</th><th scope="col"><span class="visuellement-cache">Actions</span></th></tr>
        </thead>
        <tbody>
        <?php foreach ($panier['lignes'] as $l): ?>
            <tr data-ligne="<?= e($l['id_produit']) ?>">
                <td>
                    <a href="<?= e($l['url']) ?>"><?= e($l['nom']) ?></a>
                    <small class="facultatif">Vendu par <?= e($l['boutique']) ?></small>
                    <?php if (!$l['disponible']): ?>
                        <p class="champ__erreur">Indisponible dans cette quantité (stock : <?= e($l['stock']) ?>).</p>
                    <?php endif; ?>
                </td>
                <td><?= e(format_prix($l['prix_unitaire_ttc'])) ?></td>
                <td>
                    <?php /* Sans JS : "Mettre à jour" envoie le formulaire. Avec JS : mise à jour à la saisie */ ?>
                    <form method="post" action="/panier/modifier" class="form-quantite" data-panier-quantite>
                        <?= Csrf::champ() ?>
                        <input type="hidden" name="id_produit" value="<?= e($l['id_produit']) ?>">
                        <label for="quantite-<?= e($l['id_produit']) ?>" class="visuellement-cache">Quantité de <?= e($l['nom']) ?></label>
                        <input id="quantite-<?= e($l['id_produit']) ?>" name="quantite" type="number"
                               min="0" max="<?= Panier::QUANTITE_MAX ?>" value="<?= e($l['quantite']) ?>" inputmode="numeric">
                        <button type="submit" class="bouton-lien" data-sans-js>Mettre à jour</button>
                    </form>
                </td>
                <td data-total-ligne><?= e(format_prix(total_ligne_ttc($l))) ?></td>
                <td>
                    <form method="post" action="/panier/retirer" data-panier-retirer>
                        <?= Csrf::champ() ?>
                        <input type="hidden" name="id_produit" value="<?= e($l['id_produit']) ?>">
                        <button type="submit" class="bouton-lien">Retirer<span class="visuellement-cache"> <?= e($l['nom']) ?></span></button>
                    </form>
                </td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>

    <aside class="carte recapitulatif" aria-label="Récapitulatif">
        <dl class="fiche">
            <dt>Total HT</dt><dd data-total="ht"><?= e(format_prix($panier['total_ht'])) ?></dd>
            <dt>TVA (20 %)</dt><dd data-total="tva"><?= e(format_prix($panier['tva'])) ?></dd>
            <dt>Total TTC</dt><dd data-total="ttc" class="prix-total"><?= e(format_prix($panier['total_ttc'])) ?></dd>
        </dl>
        <p class="facultatif">Livraison offerte. Une commande est créée par boutique.</p>
        <?php if ($indisponible): ?>
            <p class="alerte alerte--erreur">Corrigez les articles indisponibles avant de commander.</p>
        <?php endif; ?>
        <a class="bouton" href="/commande"><?= Auth::estConnecte() ? 'Passer la commande' : 'Se connecter pour commander' ?></a>
    </aside>
</div>
<?php endif; ?>

<script type="module" src="/assets/js/panier.js"></script>
