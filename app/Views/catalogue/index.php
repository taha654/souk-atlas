<?php
/** @var App\Models\FiltresCatalogue $filtres */
/** @var list<array<string, mixed>> $produits */
/** @var int $total */
/** @var list<array{id: int, nom: string, id_parent: ?int, niveau: int, nb_produits: int}> $arbre */
/** @var list<array{id: int, nom: string}> $chemin */

use App\Core\View;
use App\Models\FiltresCatalogue;

$pages = max(1, (int) ceil($total / FiltresCatalogue::TAILLE_PAGE));
$texteResultats = $total === 0 ? 'Aucun produit trouvé'
    : $total . ' produit' . ($total > 1 ? 's' : '') . ' trouvé' . ($total > 1 ? 's' : '');
?>
<h1 id="titre-catalogue">
    <?= $filtres->texte === '' ? 'Catalogue' : 'Résultats pour « ' . e($filtres->texte) . ' »' ?>
</h1>

<div class="catalogue">
    <?php /* Formulaire GET ordinaire : sans JavaScript, "Appliquer" recharge la page
             avec les filtres dans l'URL. catalogue.js intercepte ces mêmes champs. */ ?>
    <form id="filtres" class="catalogue__filtres" method="get" action="/catalogue" aria-label="Filtres">
      <?php /* <details> : repliable sans JavaScript. Ouvert par défaut ; catalogue.js
               le referme sur petit écran pour montrer les produits tout de suite. */ ?>
      <details class="filtres__bascule" open>
        <summary>Filtres et tri</summary>
        <div class="champ">
            <label for="filtre-q">Mots-clés</label>
            <input id="filtre-q" name="q" type="search" value="<?= e($filtres->texte) ?>" maxlength="100">
        </div>

        <fieldset class="champ arbre-categories">
            <legend>Catégorie</legend>
            <label class="choix">
                <input type="radio" name="categorie" value="" <?= $filtres->categorie === null ? 'checked' : '' ?>>
                Toutes les catégories
            </label>
            <?php foreach ($arbre as $c): ?>
                <?php if ($c['nb_produits'] === 0) { continue; } // catégories propres aux annonces ?>
                <label class="choix niveau-<?= e($c['niveau']) ?>">
                    <input type="radio" name="categorie" value="<?= e($c['id']) ?>"
                        <?= $filtres->categorie === $c['id'] ? 'checked' : '' ?>>
                    <?= e($c['nom']) ?> <span class="compteur">(<?= e($c['nb_produits']) ?>)</span>
                </label>
            <?php endforeach; ?>
        </fieldset>

        <fieldset class="champ">
            <legend>Prix TTC (MAD)</legend>
            <div class="prix-min-max">
                <label for="filtre-prix-min" class="visuellement-cache">Prix minimum</label>
                <input id="filtre-prix-min" name="prix_min" type="number" min="0" step="1" inputmode="numeric"
                       placeholder="Min" value="<?= e($filtres->prixMin === null ? '' : (string) $filtres->prixMin) ?>">
                <span aria-hidden="true">à</span>
                <label for="filtre-prix-max" class="visuellement-cache">Prix maximum</label>
                <input id="filtre-prix-max" name="prix_max" type="number" min="0" step="1" inputmode="numeric"
                       placeholder="Max" value="<?= e($filtres->prixMax === null ? '' : (string) $filtres->prixMax) ?>">
            </div>
        </fieldset>

        <div class="champ">
            <label class="choix">
                <input type="checkbox" name="en_stock" value="1" <?= $filtres->enStock ? 'checked' : '' ?>>
                En stock uniquement
            </label>
        </div>

        <div class="champ">
            <label for="filtre-tri">Trier par</label>
            <select id="filtre-tri" name="tri">
                <?php foreach (FiltresCatalogue::TRIS as $valeur => $libelle): ?>
                    <option value="<?= e($valeur) ?>" <?= $filtres->tri === $valeur ? 'selected' : '' ?>><?= e($libelle) ?></option>
                <?php endforeach; ?>
            </select>
        </div>

        <div class="filtres__actions">
            <button type="submit" class="bouton">Appliquer</button>
            <a href="/catalogue" id="effacer-filtres">Effacer les filtres</a>
        </div>
      </details>
    </form>

    <section class="catalogue__resultats" aria-labelledby="titre-catalogue">
        <div id="zone-fil-ariane">
            <?php if ($chemin !== []): ?>
                <?= View::fragment('partials/fil_ariane', ['chemin' => $chemin]) ?>
            <?php endif; ?>
        </div>

        <?php /* aria-live : un lecteur d'écran annonce le nouveau nombre de résultats
                 quand catalogue.js le met à jour */ ?>
        <p id="nb-resultats" class="nb-resultats" aria-live="polite"><?= e($texteResultats) ?></p>

        <ul id="liste-produits" class="grille-produits">
            <?php foreach ($produits as $p): ?>
                <?= View::fragment('partials/carte_produit', ['p' => $p]) ?>
            <?php endforeach; ?>
        </ul>
        <p id="aucun-resultat" class="aucun-resultat" <?= $produits === [] ? '' : 'hidden' ?>>
            Aucun produit ne correspond à ces critères. Essayez d'élargir votre recherche.
        </p>

        <nav id="pagination" class="pagination" aria-label="Pages de résultats">
            <?= View::fragment('partials/pagination', ['filtres' => $filtres, 'pages' => $pages]) ?>
        </nav>
    </section>
</div>

<?php /* Modèle de carte pour catalogue.js : même structure que partials/carte_produit.php.
         Un <template> n'est pas affiché ; le JS le clone puis remplit les champs. */ ?>
<template id="modele-carte">
    <li class="carte-produit">
        <a class="carte-produit__lien" data-champ="url">
            <span class="carte-produit__image">
                <img alt="" width="600" height="450" loading="lazy" data-champ="photo">
                <span class="badge-promo" data-champ="promo"></span>
            </span>
            <span class="carte-produit__nom" data-champ="nom"></span>
            <span class="carte-produit__boutique" data-champ="boutique"></span>
            <span class="carte-produit__prix">
                <strong data-champ="prix"></strong>
                <s data-champ="ancien-prix"><span class="visuellement-cache">au lieu de </span><span data-champ="ancien-prix-texte"></span></s>
            </span>
            <span class="carte-produit__note" data-champ="note"></span>
            <span class="carte-produit__stock" data-champ="stock"></span>
        </a>
    </li>
</template>

<script type="module" src="/assets/js/catalogue.js"></script>
