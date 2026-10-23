<?php
/** @var array<string, mixed> $panier */
/** @var array<string, string> $valeurs */
/** @var array<string, string> $erreurs */

use App\Core\Csrf;

$erreur = static fn (string $champ): string => isset($erreurs[$champ])
    ? '<p class="champ__erreur" id="erreur-' . e($champ) . '">' . e($erreurs[$champ]) . '</p>' : '';
$decrit = static fn (string $champ): string => isset($erreurs[$champ])
    ? ' aria-invalid="true" aria-describedby="erreur-' . e($champ) . '"' : '';
$carte = ($valeurs['mode'] ?? 'CARTE') === 'CARTE';
$anneeCourante = (int) date('Y');
?>
<h1>Livraison et paiement</h1>

<?php if (isset($erreurs['general'])): ?>
    <p class="alerte alerte--erreur" role="alert"><?= e($erreurs['general']) ?></p>
<?php endif; ?>

<div class="commande">
    <form method="post" action="/commande" class="carte" id="formulaire-commande" novalidate>
        <?= Csrf::champ() ?>

        <h2>Adresse de livraison</h2>
        <div class="champ">
            <label for="adresse">Adresse</label>
            <input id="adresse" name="adresse" type="text" required maxlength="400" autocomplete="street-address"
                   value="<?= e($valeurs['adresse'] ?? '') ?>"<?= $decrit('adresse') ?>>
            <?= $erreur('adresse') ?>
        </div>
        <div class="champ">
            <label for="ville">Ville</label>
            <input id="ville" name="ville" type="text" required maxlength="60" autocomplete="address-level2"
                   list="villes" value="<?= e($valeurs['ville'] ?? '') ?>"<?= $decrit('ville') ?>>
            <datalist id="villes">
                <?php foreach (['Agadir', 'Casablanca', 'El Jadida', 'Fès', 'Kénitra', 'Laâyoune', 'Marrakech', 'Meknès',
                                'Oujda', 'Rabat', 'Safi', 'Salé', 'Tanger', 'Tétouan'] as $ville): ?>
                    <option value="<?= e($ville) ?>">
                <?php endforeach; ?>
            </datalist>
            <?= $erreur('ville') ?>
        </div>
        <div class="champ">
            <label for="telephone">Téléphone (pour le livreur)</label>
            <input id="telephone" name="telephone" type="tel" required autocomplete="tel" placeholder="06 12 34 56 78"
                   value="<?= e($valeurs['telephone'] ?? '') ?>"<?= $decrit('telephone') ?>>
            <?= $erreur('telephone') ?>
        </div>

        <fieldset class="champ">
            <legend>Paiement</legend>
            <label class="choix"><input type="radio" name="mode" value="CARTE" <?= $carte ? 'checked' : '' ?>> Carte bancaire</label>
            <label class="choix"><input type="radio" name="mode" value="LIVRAISON" <?= $carte ? '' : 'checked' ?>> Paiement à la livraison (espèces)</label>
            <?= $erreur('mode') ?>
        </fieldset>

        <?php /* Champs de carte : JAMAIS pré-remplis (même après une erreur) ; commande.js
                 les masque si "Paiement à la livraison" est choisi */ ?>
        <fieldset class="champ carte-bancaire" id="champs-carte">
            <legend>Carte bancaire <span class="facultatif">(paiement simulé)</span></legend>
            <p class="alerte alerte--info">Démonstration : aucun paiement réel. Carte de test : 4111 1111 1111 1111,
                une date future et n'importe quel cryptogramme à 3 chiffres.</p>
            <?= $erreur('carte') ?>
            <div class="champ">
                <label for="carte">Numéro de carte</label>
                <input id="carte" name="carte" type="text" inputmode="numeric" autocomplete="cc-number"
                       maxlength="23" placeholder="1234 5678 9012 3456"<?= $decrit('carte') ?>>
            </div>
            <div class="ligne-champs">
                <div class="champ">
                    <label for="mois">Mois</label>
                    <select id="mois" name="mois" autocomplete="cc-exp-month">
                        <option value="">--</option>
                        <?php for ($m = 1; $m <= 12; $m++): ?>
                            <option value="<?= $m ?>"><?= sprintf('%02d', $m) ?></option>
                        <?php endfor; ?>
                    </select>
                </div>
                <div class="champ">
                    <label for="annee">Année</label>
                    <select id="annee" name="annee" autocomplete="cc-exp-year">
                        <option value="">----</option>
                        <?php for ($a = $anneeCourante; $a <= $anneeCourante + 10; $a++): ?>
                            <option value="<?= $a ?>"><?= $a ?></option>
                        <?php endfor; ?>
                    </select>
                </div>
                <div class="champ">
                    <label for="cvv">Cryptogramme</label>
                    <input id="cvv" name="cvv" type="text" inputmode="numeric" autocomplete="cc-csc" maxlength="3"
                           size="4"<?= $decrit('cvv') ?>>
                </div>
            </div>
            <?= $erreur('expiration') ?>
            <?= $erreur('cvv') ?>
        </fieldset>

        <button type="submit" class="bouton" id="bouton-payer">
            Confirmer et payer <?= e(format_prix($panier['total_ttc'])) ?>
        </button>
    </form>

    <aside class="carte recapitulatif" aria-label="Votre panier">
        <h2>Votre panier</h2>
        <ul class="liste-simple">
            <?php foreach ($panier['lignes'] as $l): ?>
                <li><?= e($l['quantite']) ?> × <?= e($l['nom']) ?> <small class="facultatif">(<?= e($l['boutique']) ?>)</small></li>
            <?php endforeach; ?>
        </ul>
        <dl class="fiche">
            <dt>Total HT</dt><dd><?= e(format_prix($panier['total_ht'])) ?></dd>
            <dt>TVA (20 %)</dt><dd><?= e(format_prix($panier['tva'])) ?></dd>
            <dt>Total TTC</dt><dd class="prix-total"><?= e(format_prix($panier['total_ttc'])) ?></dd>
        </dl>
        <p><a href="/panier">Modifier le panier</a></p>
    </aside>
</div>

<script type="module" src="/assets/js/commande.js"></script>
