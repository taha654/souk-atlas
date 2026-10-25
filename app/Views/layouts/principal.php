<?php
/** @var string $contenu HTML de la page, déjà produit (et échappé) par son gabarit */
/** @var string $titre */

use App\Core\Auth;
use App\Core\Csrf;
use App\Core\Session;
use App\Core\View;

$moi = Auth::utilisateur();
$flashs = Session::lireFlashs();
?>
<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($titre) ?> · Souk Atlas</title>
    <?php /* Jeton CSRF lu par le JavaScript pour ses requêtes POST (en-tête X-CSRF-Token) */ ?>
    <meta name="csrf-token" content="<?= e(Csrf::jeton()) ?>">
    <link rel="stylesheet" href="/assets/css/style.css">
    <script type="module" src="/assets/js/validation.js"></script>
    <script type="module" src="/assets/js/recherche.js"></script>
    <script type="module" src="/assets/js/confirmation.js"></script>
    <script type="module" src="/assets/js/photos-repli.js"></script>
</head>
<body>
<a class="lien-evitement" href="#contenu">Aller au contenu</a>

<header class="entete">
    <div class="entete__interieur">
        <a class="logo" href="/">Souk <span>Atlas</span></a>

        <?php /* Recherche : formulaire GET ordinaire vers /catalogue ; recherche.js y
                 ajoute l'autocomplétion (motif ARIA "combobox") */ ?>
        <form class="recherche" role="search" method="get" action="/catalogue">
            <label for="recherche" class="visuellement-cache">Rechercher un produit</label>
            <input id="recherche" name="q" type="search" placeholder="Rechercher un produit…" maxlength="100"
                   autocomplete="off" role="combobox" aria-autocomplete="list" aria-expanded="false"
                   aria-controls="suggestions">
            <ul id="suggestions" class="recherche__suggestions" role="listbox" aria-label="Suggestions" hidden></ul>
            <button type="submit" class="bouton bouton--clair">Rechercher</button>
        </form>

        <nav aria-label="Navigation principale">
            <ul class="menu">
                <li><a href="/catalogue">Catalogue</a></li>
                <li><a href="/annonces">Annonces</a></li>
                <?php $nbArticles = (int) View::partage('nb_articles', 0); ?>
                <li><a href="/panier" class="lien-panier">Panier
                    <?php /* Le badge est mis à jour par panier.js ; le texte caché le rend lisible */ ?>
                    <span class="badge-panier" id="badge-panier" <?= $nbArticles === 0 ? 'hidden' : '' ?>><?= $nbArticles ?></span>
                    <span class="visuellement-cache">(articles dans le panier)</span></a></li>
                <?php if ($moi === null): ?>
                    <li><a href="/connexion">Connexion</a></li>
                    <li><a class="bouton bouton--clair" href="/inscription">Créer un compte</a></li>
                <?php else: ?>
                    <?php /* Afficher ou non un lien n'est qu'un confort : le vrai
                             contrôle est fait par Auth::exigerRole() dans le contrôleur */ ?>
                    <?php if ($moi['role'] === 'VENDEUR'): ?>
                        <li><a href="/vendeur">Espace vendeur</a></li>
                    <?php endif; ?>
                    <?php if ($moi['role'] === 'ADMIN'): ?>
                        <li><a href="/admin">Administration</a></li>
                    <?php endif; ?>
                    <?php if (in_array($moi['role'], ['CLIENT', 'VENDEUR'], true)): ?>
                        <?php $nonLus = (int) View::partage('nb_non_lus', 0); ?>
                        <li><a href="/messages">Messages<?php if ($nonLus > 0): ?>
                            <span class="badge-panier"><?= $nonLus ?></span><span class="visuellement-cache"> non lu(s)</span><?php endif; ?></a></li>
                        <li><details class="menu-deroulant"><summary>Mon espace</summary>
                            <ul>
                                <li><a href="/mes-commandes">Mes commandes</a></li>
                                <li><a href="/mes-annonces">Mes annonces</a></li>
                                <li><a href="/favoris">Mes favoris</a></li>
                            </ul></details></li>
                    <?php endif; ?>
                    <li><a href="/compte">Mon compte</a></li>
                    <li>
                        <form method="post" action="/deconnexion" class="form-en-ligne">
                            <?= Csrf::champ() ?>
                            <button type="submit" class="bouton bouton--clair">Déconnexion</button>
                        </form>
                    </li>
                <?php endif; ?>
            </ul>
        </nav>
    </div>
</header>

<main id="contenu" class="page">
    <?php foreach ($flashs as $flash): ?>
        <p class="alerte alerte--<?= e($flash['type']) ?>" role="status"><?= e($flash['message']) ?></p>
    <?php endforeach; ?>

    <?= $contenu ?>
</main>

<footer class="pied">
    <p>Souk Atlas — projet de portfolio. Données de démonstration fictives, paiements simulés.</p>
    <p>Photos : <a href="/credits">Pixabay</a></p>
</footer>
</body>
</html>
