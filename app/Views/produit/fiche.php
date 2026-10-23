<?php
/** @var array<string, mixed> $produit */
/** @var list<array{id: int, nom: string}> $chemin */
/** @var list<array{nom: string, note: int, commentaire: string, date: string}> $avis */

use App\Core\Csrf;
use App\Core\View;
use App\Services\Panier;

$enPromo = $produit['pourcentage_promo'] > 0;
$photos = $produit['photos'] !== [] ? $produit['photos'] : ['/assets/img/aucune-photo.svg'];
?>
<?= View::fragment('partials/fil_ariane', ['chemin' => $chemin, 'dernier' => $produit['nom']]) ?>

<article class="fiche-produit">
    <section class="galerie" aria-label="Photos du produit" data-galerie>
        <figure class="galerie__principale">
            <img src="<?= e($photos[0]) ?>" alt="<?= e($produit['nom']) ?>, photo 1 sur <?= count($photos) ?>"
                 width="600" height="450" data-galerie-image>
        </figure>
        <?php if (count($photos) > 1): ?>
            <?php /* Des <button> : focusables et activables au clavier sans code en plus */ ?>
            <ul class="galerie__vignettes">
                <?php foreach ($photos as $i => $photo): ?>
                    <li>
                        <button type="button" class="galerie__vignette" data-src="<?= e($photo) ?>"
                                data-alt="<?= e($produit['nom']) ?>, photo <?= $i + 1 ?> sur <?= count($photos) ?>"
                                aria-label="Afficher la photo <?= $i + 1 ?>" aria-pressed="<?= $i === 0 ? 'true' : 'false' ?>">
                            <img src="<?= e($photo) ?>" alt="" width="120" height="90">
                        </button>
                    </li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </section>

    <section class="fiche-produit__infos">
        <h1><?= e($produit['nom']) ?></h1>
        <p class="fiche-produit__boutique">Vendu par <strong><?= e($produit['boutique']) ?></strong>
            (<?= e($produit['ville_boutique']) ?>)</p>
        <p class="carte-produit__note"><?= e(texte_note($produit['note_moyenne'], $produit['nb_avis'])) ?></p>

        <div class="fiche-produit__prix">
            <?php if ($enPromo): ?>
                <span class="badge-promo">-<?= e((string) (int) $produit['pourcentage_promo']) ?> %</span>
            <?php endif; ?>
            <p class="prix-ttc"><?= e(format_prix($produit['prix_courant_ttc'])) ?> <small>TTC</small></p>
            <?php if ($enPromo): ?>
                <p class="prix-barre"><s><span class="visuellement-cache">Prix habituel : </span><?= e(format_prix($produit['prix_ttc'])) ?></s></p>
            <?php endif; ?>
            <p class="prix-ht"><?= e(format_prix($produit['prix_courant_ht'])) ?> HT · TVA 20 % incluse</p>
        </div>

        <p class="carte-produit__stock <?= $produit['stock'] === 0 ? 'stock--epuise' : '' ?>"><?= e(texte_stock($produit['stock'])) ?></p>

        <?php if ($produit['stock'] > 0): ?>
            <?php /* Sans JS : POST classique puis retour sur la fiche. Avec JS (panier.js) :
                     ajout sans rechargement, badge du panier mis à jour */ ?>
            <form method="post" action="/panier/ajouter" class="ajout-panier" data-panier-ajout>
                <?= Csrf::champ() ?>
                <input type="hidden" name="id_produit" value="<?= e($produit['id']) ?>">
                <input type="hidden" name="retour" value="/produit/<?= e($produit['id']) ?>">
                <label for="quantite">Quantité</label>
                <input id="quantite" name="quantite" type="number" min="1"
                       max="<?= e(min($produit['stock'], Panier::QUANTITE_MAX)) ?>" value="1" inputmode="numeric">
                <button type="submit" class="bouton">Ajouter au panier</button>
            </form>
            <p id="message-panier" class="message-panier" aria-live="polite"></p>
        <?php else: ?>
            <p><button type="button" class="bouton" disabled>Produit épuisé</button></p>
        <?php endif; ?>

        <h2>Description</h2>
        <p><?= nl2br(e($produit['description'])) ?></p>
    </section>
</article>

<section class="avis carte" aria-labelledby="titre-avis">
    <h2 id="titre-avis">Avis des clients (<?= e($produit['nb_avis']) ?>)</h2>
    <?php if ($avis === []): ?>
        <p>Aucun avis pour l'instant.</p>
    <?php else: ?>
        <ul class="liste-avis">
            <?php foreach ($avis as $a): ?>
                <li>
                    <p class="avis__entete">
                        <?php /* Étoiles décoratives pour la vue, texte complet pour les lecteurs d'écran */ ?>
                        <span aria-hidden="true" class="etoiles"><?= str_repeat('★', $a['note']) . str_repeat('☆', 5 - $a['note']) ?></span>
                        <span class="visuellement-cache">Note : <?= e($a['note']) ?> sur 5.</span>
                        <strong><?= e($a['nom']) ?></strong>, le <?= e(date_fr($a['date'])) ?>
                    </p>
                    <p><?= e($a['commentaire']) ?></p>
                </li>
            <?php endforeach; ?>
        </ul>
    <?php endif; ?>
</section>

<script type="module" src="/assets/js/galerie.js"></script>
<script type="module" src="/assets/js/panier.js"></script>
