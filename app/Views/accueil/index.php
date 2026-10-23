<?php
/** @var array<string, mixed> $chiffres */

use App\Core\Auth;
?>
<section class="bandeau">
    <h1>Achetez neuf, vendez d'occasion, partout au Maroc.</h1>
    <p>La marketplace des boutiques marocaines et les petites annonces entre particuliers, réunies au même endroit.</p>
    <?php if (!Auth::estConnecte()): ?>
        <p><a class="bouton" href="/inscription">Créer un compte gratuit</a></p>
    <?php endif; ?>
</section>

<section class="grille-chiffres" aria-label="Souk Atlas en chiffres">
    <div class="chiffre"><strong><?= e($chiffres['PRODUITS']) ?></strong> produits en vente</div>
    <div class="chiffre"><strong><?= e($chiffres['BOUTIQUES']) ?></strong> boutiques</div>
    <div class="chiffre"><strong><?= e($chiffres['ANNONCES']) ?></strong> annonces en ligne</div>
</section>

<p class="sous-texte">Le catalogue et les annonces arrivent aux étapes 3 et 6.</p>
