<?php
/** @var string $contenu HTML de la page, déjà produit (et échappé) par son gabarit */
/** @var string $titre */

use App\Core\Auth;
use App\Core\Csrf;
use App\Core\Session;

$moi = Auth::utilisateur();
$flashs = Session::lireFlashs();
?>
<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($titre) ?> · Souk Atlas</title>
    <link rel="stylesheet" href="/assets/css/style.css">
    <script type="module" src="/assets/js/validation.js"></script>
    <script type="module" src="/assets/js/recherche.js"></script>
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
</footer>
</body>
</html>
