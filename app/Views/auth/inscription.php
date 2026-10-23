<?php
/** @var array<string, string> $valeurs */
/** @var array<string, string> $erreurs */

use App\Core\Csrf;
use App\Models\Utilisateur;

// Affiche le message d'erreur d'un champ, relié au champ par aria-describedby
$erreur = static fn (string $champ): string => isset($erreurs[$champ])
    ? '<p class="champ__erreur" id="erreur-' . e($champ) . '">' . e($erreurs[$champ]) . '</p>'
    : '';
$decrit = static fn (string $champ): string => isset($erreurs[$champ])
    ? ' aria-invalid="true" aria-describedby="erreur-' . e($champ) . '"'
    : '';
?>
<section class="carte carte--etroite">
    <h1>Créer un compte</h1>

    <?php if (isset($erreurs['general'])): ?>
        <p class="alerte alerte--erreur" role="alert"><?= e($erreurs['general']) ?></p>
    <?php endif; ?>

    <form method="post" action="/inscription" data-valider novalidate>
        <?= Csrf::champ() ?>

        <fieldset class="champ">
            <legend>Type de compte</legend>
            <label class="choix">
                <input type="radio" name="role" value="CLIENT" <?= ($valeurs['role'] ?? '') !== 'VENDEUR' ? 'checked' : '' ?>>
                Particulier : acheter et publier des annonces
            </label>
            <label class="choix">
                <input type="radio" name="role" value="VENDEUR" <?= ($valeurs['role'] ?? '') === 'VENDEUR' ? 'checked' : '' ?>>
                Vendeur professionnel : ouvrir une boutique
            </label>
            <?= $erreur('role') ?>
        </fieldset>

        <div class="champ">
            <label for="nom">Nom complet</label>
            <input id="nom" name="nom" type="text" required minlength="2" maxlength="100"
                   autocomplete="name" value="<?= e($valeurs['nom'] ?? '') ?>"<?= $decrit('nom') ?>>
            <?= $erreur('nom') ?>
        </div>

        <div class="champ">
            <label for="email">Email</label>
            <input id="email" name="email" type="email" required maxlength="254"
                   autocomplete="email" value="<?= e($valeurs['email'] ?? '') ?>"<?= $decrit('email') ?>>
            <?= $erreur('email') ?>
        </div>

        <div class="champ">
            <label for="telephone">Téléphone <span class="facultatif">(facultatif)</span></label>
            <input id="telephone" name="telephone" type="tel" autocomplete="tel"
                   placeholder="06 12 34 56 78" value="<?= e($valeurs['telephone'] ?? '') ?>"<?= $decrit('telephone') ?>>
            <?= $erreur('telephone') ?>
        </div>

        <div class="champ">
            <label for="ville">Ville <span class="facultatif">(facultatif)</span></label>
            <input id="ville" name="ville" type="text" maxlength="60" autocomplete="address-level2"
                   value="<?= e($valeurs['ville'] ?? '') ?>">
        </div>

        <div class="champ">
            <label for="mot_de_passe">Mot de passe</label>
            <input id="mot_de_passe" name="mot_de_passe" type="password" required
                   minlength="<?= Utilisateur::MDP_LONGUEUR_MIN ?>" autocomplete="new-password"
                   aria-describedby="aide-mdp<?= isset($erreurs['mot_de_passe']) ? ' erreur-mot_de_passe' : '' ?>"
                   <?= isset($erreurs['mot_de_passe']) ? 'aria-invalid="true"' : '' ?>>
            <p class="champ__aide" id="aide-mdp">Au moins <?= Utilisateur::MDP_LONGUEUR_MIN ?> caractères.</p>
            <?= $erreur('mot_de_passe') ?>
        </div>

        <div class="champ">
            <label for="confirmation">Confirmer le mot de passe</label>
            <input id="confirmation" name="confirmation" type="password" required
                   autocomplete="new-password" data-identique-a="mot_de_passe"<?= $decrit('confirmation') ?>>
            <?= $erreur('confirmation') ?>
        </div>

        <button type="submit" class="bouton">Créer mon compte</button>
    </form>

    <p class="sous-texte">Déjà inscrit ? <a href="/connexion">Se connecter</a></p>
</section>
