<?php
/**
 * Carte d'un produit dans la grille du catalogue.
 * La même structure existe dans <template id="modele-carte"> (catalogue/index.php),
 * que catalogue.js clone : toute modification ici doit être reportée là-bas.
 *
 * @var array<string, mixed> $p produit (Produit::versTableau)
 */
$enPromo = $p['pourcentage_promo'] > 0;
?>
<li class="carte-produit">
    <a class="carte-produit__lien" href="<?= e($p['url']) ?>">
        <span class="carte-produit__image">
            <?php /* alt vide : le nom du produit est déjà lu dans le titre du lien */ ?>
            <img src="<?= e($p['photo'] ?? '/assets/img/aucune-photo.svg') ?>" alt="" width="600" height="450" loading="lazy">
            <?php if ($enPromo): ?>
                <span class="badge-promo">-<?= e((string) (int) $p['pourcentage_promo']) ?> %</span>
            <?php endif; ?>
        </span>
        <span class="carte-produit__nom"><?= e($p['nom']) ?></span>
        <span class="carte-produit__boutique"><?= e($p['boutique']) ?></span>
        <span class="carte-produit__prix">
            <strong><?= e(format_prix($p['prix_courant_ttc'])) ?></strong>
            <?php if ($enPromo): ?>
                <s><span class="visuellement-cache">au lieu de </span><?= e(format_prix($p['prix_ttc'])) ?></s>
            <?php endif; ?>
        </span>
        <span class="carte-produit__note"><?= e(texte_note($p['note_moyenne'], $p['nb_avis'])) ?></span>
        <span class="carte-produit__stock <?= $p['stock'] === 0 ? 'stock--epuise' : '' ?>"><?= e(texte_stock($p['stock'])) ?></span>
    </a>
</li>
