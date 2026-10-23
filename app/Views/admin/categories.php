<?php
/** @var list<array<string, mixed>> $arbre */
/** @var array<int, int> $annonces */

use App\Core\Csrf;
use App\Core\View;
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/categories']) ?>
<h1>Catégories</h1>
<p class="sous-texte-gauche">Arbre partagé par la place de marché et les annonces (requête CONNECT BY). Une catégorie ne se supprime que vide.</p>

<form method="post" action="/admin/categories" class="carte form-quantite"><?= Csrf::champ() ?>
    <label for="nom-nouvelle">Nouvelle catégorie</label>
    <input id="nom-nouvelle" name="nom" type="text" required minlength="2" maxlength="80">
    <label for="parent">dans</label>
    <select id="parent" name="id_parent">
        <option value="">(racine)</option>
        <?php foreach ($arbre as $c): ?><option value="<?= e($c['id']) ?>"><?= str_repeat('— ', $c['niveau'] - 1) . e($c['nom']) ?></option><?php endforeach; ?>
    </select>
    <button type="submit" class="bouton">Créer</button>
</form>

<ul class="arbre-admin">
    <?php foreach ($arbre as $c): ?>
        <li class="niveau-<?= e($c['niveau']) ?>">
            <form method="post" action="/admin/categories/<?= e($c['id']) ?>" class="form-quantite"><?= Csrf::champ() ?>
                <label for="nom-<?= e($c['id']) ?>" class="visuellement-cache">Nom de la catégorie</label>
                <input id="nom-<?= e($c['id']) ?>" name="nom" type="text" value="<?= e($c['nom']) ?>" required minlength="2" maxlength="80">
                <button type="submit" class="bouton-lien">Renommer</button>
            </form>
            <span class="compteur"><?= e($c['nb_produits']) ?> produit(s), <?= e($annonces[$c['id']] ?? 0) ?> annonce(s)</span>
            <form method="post" action="/admin/categories/<?= e($c['id']) ?>/supprimer" data-confirmer="Supprimer « <?= e($c['nom']) ?> » ?"><?= Csrf::champ() ?>
                <button type="submit" class="bouton-lien">Supprimer<span class="visuellement-cache"> <?= e($c['nom']) ?></span></button></form>
        </li>
    <?php endforeach; ?>
</ul>
