<?php
/** @var array<string, mixed>|null $annonce */
/** @var array<string, string> $valeurs */
/** @var array<string, string> $erreurs */
/** @var list<array<string, mixed>> $categories */

use App\Core\Csrf;
use App\Models\Annonce;
use App\Services\Upload;

$creation = $annonce === null;
$erreur = static fn (string $c): string => isset($erreurs[$c]) ? '<p class="champ__erreur" id="erreur-' . e($c) . '">' . e($erreurs[$c]) . '</p>' : '';
$invalide = static fn (string $c): string => isset($erreurs[$c]) ? ' aria-invalid="true" aria-describedby="erreur-' . e($c) . '"' : '';
?>
<p><a href="/mes-annonces">← Mes annonces</a></p>
<h1><?= $creation ? 'Publier une annonce' : 'Modifier mon annonce' ?></h1>
<?php if (!$creation): ?>
    <p>Statut : <strong><?= e(Annonce::STATUTS[$annonce['statut']]) ?></strong>
        <?php if ($annonce['statut'] === 'EN_LIGNE'): ?> · <a href="/annonce/<?= e($annonce['id']) ?>">Voir l'annonce</a><?php endif; ?></p>
<?php endif; ?>
<?php if (isset($erreurs['general'])): ?><p class="alerte alerte--erreur" role="alert"><?= e($erreurs['general']) ?></p><?php endif; ?>

<div class="commande">
    <form method="post" action="<?= $creation ? '/annonces' : '/mes-annonces/' . e($annonce['id']) ?>" class="carte" novalidate data-valider>
        <?= Csrf::champ() ?>
        <div class="champ"><label for="titre">Titre</label>
            <input id="titre" name="titre" type="text" required minlength="5" maxlength="150" value="<?= e($valeurs['titre'] ?? '') ?>"<?= $invalide('titre') ?>>
            <?= $erreur('titre') ?></div>
        <div class="champ"><label for="id_categorie">Catégorie</label>
            <select id="id_categorie" name="id_categorie" required<?= $invalide('id_categorie') ?>>
                <option value="">— Choisir —</option>
                <?php foreach ($categories as $c): ?>
                    <option value="<?= e($c['id']) ?>" <?= (string) $c['id'] === ($valeurs['id_categorie'] ?? '') ? 'selected' : '' ?>><?= str_repeat('— ', $c['niveau'] - 1) . e($c['nom']) ?></option>
                <?php endforeach; ?>
            </select><?= $erreur('id_categorie') ?></div>
        <div class="champ"><label for="prix">Prix (MAD)</label>
            <input id="prix" name="prix" type="text" inputmode="decimal" required value="<?= e($valeurs['prix'] ?? '') ?>"
                   aria-describedby="aide-prix<?= isset($erreurs['prix']) ? ' erreur-prix' : '' ?>"<?= isset($erreurs['prix']) ? ' aria-invalid="true"' : '' ?>>
            <p class="champ__aide" id="aide-prix">0 pour un don. Annonce gratuite, entre particuliers.</p>
            <?= $erreur('prix') ?></div>
        <div class="champ"><label for="ville">Ville</label>
            <input id="ville" name="ville" type="text" required maxlength="60" value="<?= e($valeurs['ville'] ?? '') ?>"<?= $invalide('ville') ?>>
            <?= $erreur('ville') ?></div>
        <div class="champ"><label for="description">Description</label>
            <textarea id="description" name="description" rows="6" required minlength="10" maxlength="4000"<?= $invalide('description') ?>><?= e($valeurs['description'] ?? '') ?></textarea>
            <?= $erreur('description') ?></div>
        <button type="submit" class="bouton"><?= $creation ? 'Publier' : 'Enregistrer' ?></button>
        <?php if ($creation): ?><p class="facultatif">Votre annonce reste en ligne 30 jours ; vous pourrez la renouveler.</p><?php endif; ?>
    </form>

    <?php if (!$creation): ?>
        <aside class="carte" aria-labelledby="titre-photos">
            <h2 id="titre-photos">Photos (<?= count($annonce['photos']) ?>/6)</h2>
            <ul class="photos-vendeur">
                <?php foreach ($annonce['photos'] as $i => $photo): ?>
                    <li><img src="<?= e($photo['chemin']) ?>" alt="Photo <?= $i + 1 ?>" width="120" height="90">
                        <form method="post" action="/mes-annonces/<?= e($annonce['id']) ?>/photos/<?= e($photo['id']) ?>/supprimer" data-confirmer="Supprimer cette photo ?">
                            <?= Csrf::champ() ?><button type="submit" class="bouton-lien">Supprimer<span class="visuellement-cache"> la photo <?= $i + 1 ?></span></button>
                        </form></li>
                <?php endforeach; ?>
            </ul>
            <?php if (count($annonce['photos']) < 6): ?>
                <form method="post" action="/mes-annonces/<?= e($annonce['id']) ?>/photos" enctype="multipart/form-data">
                    <?= Csrf::champ() ?>
                    <label for="photo">Ajouter une photo <span class="facultatif">(JPEG, PNG ou WebP, 5 Mo max. ;
                        les grandes photos sont allégées automatiquement)</span></label>
                    <?php /* data-alleger : réduction dans le navigateur avant l'envoi (photos.js, WebAssembly) */ ?>
                    <input id="photo" name="photo" type="file" accept="image/jpeg,image/png,image/webp" required
                           data-taille-max="<?= Upload::TAILLE_MAX ?>" data-alleger>
                    <button type="submit" class="bouton">Envoyer</button>
                </form>
            <?php endif; ?>
        </aside>
    <?php endif; ?>
</div>
<script type="module" src="/assets/js/photos.js"></script>
