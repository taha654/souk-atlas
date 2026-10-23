<?php
/** @var array<string, mixed>|null $produit */
/** @var array<string, string> $valeurs */
/** @var array<string, string> $erreurs */
/** @var list<array<string, mixed>> $categories */

use App\Core\Csrf;
use App\Core\View;
use App\Services\Upload;

$creation = $produit === null;
$erreur = static fn (string $c): string => isset($erreurs[$c])
    ? '<p class="champ__erreur" id="erreur-' . e($c) . '">' . e($erreurs[$c]) . '</p>' : '';
$invalide = static fn (string $c): string => isset($erreurs[$c]) ? ' aria-invalid="true" aria-describedby="erreur-' . e($c) . '"' : '';
?>
<?= View::fragment('partials/menu_vendeur', ['actif' => '/vendeur/produits']) ?>

<h1><?= $creation ? 'Nouveau produit' : e($produit['nom']) ?></h1>
<?php if (!$creation && $produit['statut'] === 'ACTIF'): ?>
    <p><a href="/produit/<?= e($produit['id']) ?>">Voir la fiche publique</a></p>
<?php endif; ?>
<?php if (isset($erreurs['general'])): ?>
    <p class="alerte alerte--erreur" role="alert"><?= e($erreurs['general']) ?></p>
<?php endif; ?>

<div class="commande">
    <form method="post" action="<?= $creation ? '/vendeur/produits' : '/vendeur/produits/' . e($produit['id']) ?>"
          class="carte" novalidate data-valider>
        <?= Csrf::champ() ?>
        <div class="champ">
            <label for="nom">Nom</label>
            <input id="nom" name="nom" type="text" required minlength="3" maxlength="200" value="<?= e($valeurs['nom'] ?? '') ?>"<?= $invalide('nom') ?>>
            <?= $erreur('nom') ?>
        </div>
        <div class="champ">
            <label for="id_categorie">Catégorie</label>
            <select id="id_categorie" name="id_categorie" required<?= $invalide('id_categorie') ?>>
                <option value="">— Choisir —</option>
                <?php foreach ($categories as $c): ?>
                    <option value="<?= e($c['id']) ?>" <?= (string) $c['id'] === ($valeurs['id_categorie'] ?? '') ? 'selected' : '' ?>>
                        <?= str_repeat('— ', $c['niveau'] - 1) . e($c['nom']) ?></option>
                <?php endforeach; ?>
            </select>
            <?= $erreur('id_categorie') ?>
        </div>
        <div class="champ">
            <label for="prix_ht">Prix HT (MAD)</label>
            <input id="prix_ht" name="prix_ht" type="text" inputmode="decimal" required value="<?= e($valeurs['prix_ht'] ?? '') ?>"
                   aria-describedby="aide-prix<?= isset($erreurs['prix_ht']) ? ' erreur-prix_ht' : '' ?>"<?= isset($erreurs['prix_ht']) ? ' aria-invalid="true"' : '' ?>>
            <p class="champ__aide" id="aide-prix">Les acheteurs voient le prix TTC (TVA de 20 % ajoutée).</p>
            <?= $erreur('prix_ht') ?>
        </div>
        <?php if ($creation): ?>
            <div class="champ">
                <label for="stock">Stock initial</label>
                <input id="stock" name="stock" type="number" min="0" required value="<?= e($valeurs['stock'] ?? '') ?>"<?= $invalide('stock') ?>>
                <?= $erreur('stock') ?>
            </div>
        <?php else: ?>
            <fieldset class="champ">
                <legend>Statut</legend>
                <label class="choix"><input type="radio" name="statut" value="ACTIF" <?= ($valeurs['statut'] ?? '') === 'ACTIF' ? 'checked' : '' ?>> En vente</label>
                <label class="choix"><input type="radio" name="statut" value="INACTIF" <?= ($valeurs['statut'] ?? '') === 'INACTIF' ? 'checked' : '' ?>> Retiré de la vente</label>
                <?= $erreur('statut') ?>
            </fieldset>
        <?php endif; ?>
        <div class="champ">
            <label for="description">Description</label>
            <textarea id="description" name="description" rows="6" maxlength="4000"><?= e($valeurs['description'] ?? '') ?></textarea>
            <?= $erreur('description') ?>
        </div>
        <button type="submit" class="bouton"><?= $creation ? 'Créer le produit' : 'Enregistrer' ?></button>
    </form>

    <?php if (!$creation): ?>
    <aside>
        <section class="carte" aria-labelledby="titre-stock">
            <h2 id="titre-stock">Stock : <?= e($produit['stock']) ?></h2>
            <form method="post" action="/vendeur/produits/<?= e($produit['id']) ?>/stock" class="form-quantite">
                <?= Csrf::champ() ?>
                <label for="delta">Ajouter (+) ou retirer (−)</label>
                <input id="delta" name="delta" type="number" value="10" required>
                <button type="submit" class="bouton">Appliquer</button>
            </form>
        </section>

        <section class="carte" aria-labelledby="titre-photos">
            <h2 id="titre-photos">Photos (<?= count($produit['photos']) ?>/6)</h2>
            <ul class="photos-vendeur">
                <?php foreach ($produit['photos'] as $i => $photo): ?>
                    <li>
                        <img src="<?= e($photo['chemin']) ?>" alt="Photo <?= $i + 1 ?>" width="120" height="90">
                        <form method="post" action="/vendeur/produits/<?= e($produit['id']) ?>/photos/<?= e($photo['id']) ?>/supprimer"
                              data-confirmer="Supprimer cette photo ?">
                            <?= Csrf::champ() ?>
                            <button type="submit" class="bouton-lien">Supprimer<span class="visuellement-cache"> la photo <?= $i + 1 ?></span></button>
                        </form>
                    </li>
                <?php endforeach; ?>
            </ul>
            <?php if (count($produit['photos']) < 6): ?>
                <?php /* enctype multipart : obligatoire pour envoyer un fichier */ ?>
                <form method="post" action="/vendeur/produits/<?= e($produit['id']) ?>/photos" enctype="multipart/form-data">
                    <?= Csrf::champ() ?>
                    <label for="photo">Ajouter une photo <span class="facultatif">(JPEG, PNG ou WebP, 5 Mo max. ;
                        les grandes photos sont allégées automatiquement)</span></label>
                    <?php /* data-alleger : réduction dans le navigateur avant l'envoi (photos.js, WebAssembly) */ ?>
                    <input id="photo" name="photo" type="file" accept="image/jpeg,image/png,image/webp" required
                           data-taille-max="<?= Upload::TAILLE_MAX ?>" data-alleger>
                    <button type="submit" class="bouton">Envoyer</button>
                </form>
            <?php endif; ?>
        </section>

        <?php if ($produit['historique_prix'] !== []): ?>
            <section class="carte">
                <h2>Historique des prix HT</h2>
                <?php /* Rempli automatiquement par le trigger TRG_PRODUIT_HISTORIQUE_PRIX */ ?>
                <ul class="liste-simple">
                    <?php foreach ($produit['historique_prix'] as $h): ?>
                        <li><?= e(date_fr($h['DATE_CHANGEMENT'])) ?> : <?= e(format_prix((float) $h['ANCIEN_PRIX_HT'])) ?>
                            → <?= e(format_prix((float) $h['NOUVEAU_PRIX_HT'])) ?></li>
                    <?php endforeach; ?>
                </ul>
            </section>
        <?php endif; ?>
    </aside>
    <?php endif; ?>
</div>
<script type="module" src="/assets/js/photos.js"></script>
