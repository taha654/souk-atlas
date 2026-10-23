<?php
/** @var array<string, mixed> $chiffres */
/** @var list<array<string, mixed>> $produits les mieux notés */
/** @var list<array<string, mixed>> $annonces les plus récentes */

use App\Core\Auth;
use App\Core\View;
?>
<section class="bandeau">
    <h1>Achetez neuf, vendez d'occasion, partout au Maroc.</h1>
    <p>La marketplace des boutiques marocaines et les petites annonces entre particuliers, réunies au même endroit.</p>
    <?php if (!Auth::estConnecte()): ?>
        <p><a class="bouton" href="/inscription">Créer un compte gratuit</a></p>
    <?php endif; ?>
</section>

<section class="grille-chiffres" aria-label="Souk Atlas en chiffres">
    <a class="chiffre chiffre--lien" href="/catalogue"><strong><?= e($chiffres['PRODUITS']) ?></strong> produits en vente</a>
    <div class="chiffre"><strong><?= e($chiffres['BOUTIQUES']) ?></strong> boutiques</div>
    <a class="chiffre chiffre--lien" href="/annonces"><strong><?= e($chiffres['ANNONCES']) ?></strong> annonces en ligne</a>
</section>

<?php if ($produits !== []): ?>
    <section class="vitrine" aria-labelledby="titre-mieux-notes">
        <div class="entete-section">
            <h2 id="titre-mieux-notes">Les mieux notés</h2>
            <a href="/catalogue?tri=note">Tout le catalogue →</a>
        </div>
        <ul class="grille-produits">
            <?php foreach ($produits as $p): ?>
                <?= View::fragment('partials/carte_produit', ['p' => $p]) ?>
            <?php endforeach; ?>
        </ul>
    </section>
<?php endif; ?>

<?php if ($annonces !== []): ?>
    <section class="vitrine" aria-labelledby="titre-annonces">
        <div class="entete-section">
            <h2 id="titre-annonces">Dernières annonces d'occasion</h2>
            <a href="/annonces">Toutes les annonces →</a>
        </div>
        <ul class="grille-produits">
            <?php foreach ($annonces as $a): ?>
                <?= View::fragment('partials/carte_annonce', ['a' => $a]) ?>
            <?php endforeach; ?>
        </ul>
    </section>
<?php endif; ?>
