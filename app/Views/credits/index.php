<?php
/** @var array<string, array<string, mixed>> $credits clé ("produit-12-1") → auteur, lien… */

use App\Services\PhotosDemo;
?>
<h1>Crédits photos</h1>
<p>Les photos des produits et des annonces de démonstration viennent de
    <a href="https://pixabay.com" rel="noopener">Pixabay</a> et sont utilisées selon la
    <a href="https://pixabay.com/service/license-summary/" rel="noopener">licence de contenu Pixabay</a>.
    Elles sont recadrées et hébergées sur ce site. Ce sont des photos génériques du type d'objet :
    elles ne montrent pas les articles réels. Merci à leurs auteurs.</p>

<?php if ($credits === []): ?>
    <p>Aucune photo n'est installée : le site affiche ses illustrations.</p>
<?php else: ?>
    <ul class="grille-credits">
        <?php foreach ($credits as $cle => $c): ?>
            <li class="credit">
                <a href="<?= e($c['url']) ?>" rel="noopener">
                    <img src="<?= e(PhotosDemo::photo($cle)) ?>" alt="<?= e($c['description']) ?>"
                         width="200" height="150" loading="lazy"></a>
                <p><strong><?= e($c['element']) ?></strong><br>
                    Photo de <a href="<?= e($c['auteur_url']) ?>" rel="noopener"><?= e($c['auteur']) ?></a>
                    sur <a href="<?= e($c['url']) ?>" rel="noopener">Pixabay</a></p>
            </li>
        <?php endforeach; ?>
    </ul>
<?php endif; ?>
