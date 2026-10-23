<?php
/** @var string $email */
/** @var string $retour */
/** @var string|null $erreur */

use App\Core\Csrf;
?>
<section class="carte carte--etroite">
    <h1>Connexion</h1>

    <?php if ($erreur !== null): ?>
        <p class="alerte alerte--erreur" role="alert"><?= e($erreur) ?></p>
    <?php endif; ?>

    <form method="post" action="/connexion" data-valider novalidate>
        <?= Csrf::champ() ?>
        <input type="hidden" name="retour" value="<?= e($retour) ?>">

        <div class="champ">
            <label for="email">Email</label>
            <input id="email" name="email" type="email" required autocomplete="username"
                   value="<?= e($email) ?>">
        </div>

        <div class="champ">
            <label for="mot_de_passe">Mot de passe</label>
            <input id="mot_de_passe" name="mot_de_passe" type="password" required
                   autocomplete="current-password">
        </div>

        <button type="submit" class="bouton">Se connecter</button>
    </form>

    <p class="sous-texte">Pas encore de compte ? <a href="/inscription">Créer un compte</a></p>
</section>
