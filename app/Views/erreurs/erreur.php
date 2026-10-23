<?php
/** @var int $statut */
/** @var string $titre_erreur */
/** @var string $message */
?>
<section class="carte carte--etroite erreur">
    <p class="erreur__code"><?= e($statut) ?></p>
    <h1><?= e($titre_erreur) ?></h1>
    <p><?= e($message) ?></p>
    <p><a class="bouton" href="/">Retour à l'accueil</a></p>
</section>
