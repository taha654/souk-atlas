<?php
/** @var array<string, mixed>|null $boutique */
/** @var array<string, string> $valeurs */
/** @var array<string, string> $erreurs */

use App\Core\Csrf;
use App\Core\View;
use App\Models\Boutique;

$erreur = static fn (string $c): string => isset($erreurs[$c])
    ? '<p class="champ__erreur" id="erreur-' . e($c) . '">' . e($erreurs[$c]) . '</p>' : '';
?>
<?php if ($boutique !== null): ?>
    <?= View::fragment('partials/menu_vendeur', ['actif' => '/vendeur/boutique']) ?>
<?php endif; ?>

<section class="carte carte--etroite">
    <h1><?= $boutique === null ? 'Ouvrir ma boutique' : 'Ma boutique' ?></h1>
    <?php if ($boutique === null): ?>
        <p>Présentez votre boutique. Elle sera visible des acheteurs après validation par l'administrateur ;
            vous pouvez déjà préparer vos produits.</p>
    <?php else: ?>
        <p>Statut : <?= e(Boutique::STATUTS[$boutique['statut']] ?? $boutique['statut']) ?>.
            <small class="facultatif">Un changement de nom demande une nouvelle validation.</small></p>
    <?php endif; ?>

    <form method="post" action="/vendeur/boutique" novalidate data-valider>
        <?= Csrf::champ() ?>
        <div class="champ">
            <label for="nom">Nom de la boutique</label>
            <input id="nom" name="nom" type="text" required minlength="3" maxlength="100" value="<?= e($valeurs['nom'] ?? '') ?>"
                   <?= isset($erreurs['nom']) ? 'aria-invalid="true" aria-describedby="erreur-nom"' : '' ?>>
            <?= $erreur('nom') ?>
        </div>
        <div class="champ">
            <label for="ville">Ville</label>
            <input id="ville" name="ville" type="text" required maxlength="60" value="<?= e($valeurs['ville'] ?? '') ?>"
                   <?= isset($erreurs['ville']) ? 'aria-invalid="true" aria-describedby="erreur-ville"' : '' ?>>
            <?= $erreur('ville') ?>
        </div>
        <div class="champ">
            <label for="description">Description <span class="facultatif">(facultatif)</span></label>
            <textarea id="description" name="description" rows="4" maxlength="2000"><?= e($valeurs['description'] ?? '') ?></textarea>
            <?= $erreur('description') ?>
        </div>
        <button type="submit" class="bouton"><?= $boutique === null ? 'Créer ma boutique' : 'Enregistrer' ?></button>
    </form>
</section>
